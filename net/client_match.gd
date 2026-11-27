class_name ClientMatch
extends RefCounted

const SNAPSHOT_CODEC = preload("res://net/snapshot_codec.gd")

var state: Dictionary = {}
var frames: Array[Dictionary] = []
var player_index := 0
var peer_id := 0
var predicted := Vector2.ZERO
var target := Vector2.ZERO
var correction := false
var correction_duration := GameConfig.NET_CORRECTION_SMALL_SECONDS
var clock := 0.0
var last_snapshot_arrival_ms := -1
var jitter_average_ms := 0.0
var interpolation_delay := GameConfig.NET_INTERPOLATION_SECONDS
var seq := 0
var dash_left := 0.0
var pending: Array[Dictionary] = []

func setup(initial: Dictionary, id: int) -> void:
	state = initial.duplicate(true)
	peer_id = id
	for index in state.players.size():
		if int(state.players[index].peer_id) == id: player_index = index
	predicted = state.players[player_index].pos
	target = predicted
	clock = float(state.elapsed)
	frames.clear()
	pending.clear()
	seq = 0

func receive(snapshot: Dictionary) -> void:
	if float(snapshot.elapsed) < float(state.elapsed): return
	var expanded := snapshot.duplicate(true)
	if expanded.has("pv"):
		expanded["players"] = SNAPSHOT_CODEC.expand_players(expanded, state.get("players", []))
		expanded.erase("pv")
	var arrival := Time.get_ticks_msec()
	if last_snapshot_arrival_ms >= 0:
		var jitter := absf(float(arrival - last_snapshot_arrival_ms) - 1000.0 * GameConfig.NET_SNAPSHOT_TICK)
		jitter_average_ms = lerpf(jitter_average_ms, jitter, 0.2)
		interpolation_delay = clampf(GameConfig.NET_INTERPOLATION_SECONDS + jitter_average_ms * GameConfig.NET_SNAPSHOT_JITTER_SCALE / 1000.0, GameConfig.NET_INTERPOLATION_SECONDS, GameConfig.NET_INTERPOLATION_MAX_SECONDS)
	last_snapshot_arrival_ms = arrival
	state.merge(expanded, true)
	frames.append({"time": float(state.elapsed), "players": state.players.duplicate(true)})
	while frames.size() > 12: frames.pop_front()
	clock = maxf(clock, float(state.elapsed))
	var ack := int(snapshot.get("ack", {}).get(peer_id, -1))
	pending = pending.filter(func(input: Dictionary): return int(input.seq) > ack)
	target = state.players[player_index].pos
	for input: Dictionary in pending:
		target = _move(target, input.move, float(input.dt), bool(input.dash))
	var error := predicted.distance_to(target)
	if error > GameConfig.NET_CORRECT_SNAP: predicted = target; correction = false
	elif error >= GameConfig.NET_CORRECT_MIN:
		correction = true
		correction_duration = GameConfig.NET_CORRECTION_SMALL_SECONDS if error < GameConfig.NET_CORRECT_MEDIUM else GameConfig.NET_CORRECTION_MEDIUM_SECONDS

func predict(move: Vector2, delta: float, dash: bool) -> void:
	seq += 1
	if float(state.get("round_wait",0)) > 0: return
	var player: Dictionary = state.players[player_index]
	if dash and float(player.dash_cd) <= 0 and float(player.stun) <= 0: dash_left = GameConfig.DASH_DURATION
	predicted = _move(predicted, move, delta, dash_left > 0)
	dash_left = maxf(0, dash_left - delta)
	pending.append({"seq": seq, "move": move, "dt": delta, "dash": dash_left > 0})
	if pending.size() > 120: pending.pop_front()

func _move(position: Vector2, move: Vector2, delta: float, dashing: bool) -> Vector2:
	var player: Dictionary = state.players[player_index]
	if bool(player.get("ghost",false)):
		return (position + move.limit_length() * delta * GameConfig.PLAYER_SPEED * GameConfig.SURVIVAL_GHOST_SPEED).clamp(Vector2.ZERO,GameConfig.ARENA_SIZE)
	if float(player.stun) > 0 or float(player.rooted_left) > 0: move = Vector2.ZERO
	var speed := GameConfig.PLAYER_SPEED
	if state.mode == "greed": speed *= TeamRules.speed(int(player.coins))
	if SpellRules.is_active(player, "boots"): speed *= 1.6
	if SpellRules.is_active(player, "sheep"): speed *= 0.6
	if not ZoneRules.is_inside(position, int(state.safe_zone_step)): speed *= GameConfig.ZONE_SPEED_MULTIPLIER
	for hazard: Dictionary in state.arena.get("hazards", []):
		if hazard.get("type") == "lodo":
			var center: Array = hazard.get("center", [0,0])
			var radius: Array = hazard.get("radius", [1,1])
			var relative := (position - Vector2(center[0],center[1])) / Vector2(maxf(1,radius[0]),maxf(1,radius[1]))
			if relative.length_squared() <= 1: speed *= 0.6
	if dashing:
		speed *= GameConfig.DASH_MULTIPLIER
		if move.length() < 0.1: move = player.dash_dir
	var feet := position + Vector2(0,GameConfig.PLAYER_FOOT_OFFSET)
	var moved := ArenaPhysics.move_circle(feet, move.limit_length() * speed * delta, GameConfig.PLAYER_FOOT_RADIUS, state.player_hitbox_rects) - Vector2(0,GameConfig.PLAYER_FOOT_OFFSET)
	for hazard: Dictionary in state.arena.get("hazards", []):
		if hazard.get("type") != "cinta": continue
		var direction := Vector2(hazard.get("dir", [1.0, 0.0])[0], hazard.get("dir", [1.0, 0.0])[1]).normalized()
		for tile in hazard.get("tiles", []):
			var conveyor_rect := Rect2(Vector2(float(tile[0]), float(tile[1])), Vector2(float(tile[2]), float(tile[3])))
			if conveyor_rect.has_point(moved):
				var conveyor_feet := moved + Vector2(0,GameConfig.PLAYER_FOOT_OFFSET)
				moved = ArenaPhysics.move_circle(conveyor_feet, direction * GameConfig.CONVEYOR_SPEED * delta, GameConfig.PLAYER_FOOT_RADIUS, state.player_hitbox_rects) - Vector2(0,GameConfig.PLAYER_FOOT_OFFSET)
	return moved

func render(delta: float) -> Dictionary:
	clock += delta
	if correction:
		predicted = predicted.lerp(target, minf(1.0, delta / maxf(0.001, correction_duration)))
		if predicted.distance_to(target) < 1.0: correction = false
	var result := state.duplicate(true)
	var render_time := clock - interpolation_delay
	var before: Dictionary = {}
	var after: Dictionary = {}
	for frame in frames:
		if float(frame.time) <= render_time: before = frame
		else: after = frame; break
	if not before.is_empty() and not after.is_empty():
		var weight := clampf((render_time - float(before.time)) / maxf(0.001, float(after.time) - float(before.time)),0,1)
		for index in result.players.size():
			if index < before.players.size() and index < after.players.size():
				result.players[index].pos = before.players[index].pos.lerp(after.players[index].pos, weight)
	result.players[player_index].pos = predicted
	return result

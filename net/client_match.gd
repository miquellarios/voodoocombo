class_name ClientMatch
extends RefCounted

var state: Dictionary = {}
var frames: Array[Dictionary] = []
var player_index := 0
var peer_id := 0
var predicted := Vector2.ZERO
var target := Vector2.ZERO
var correction := false
var clock := 0.0
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
	state.merge(snapshot.duplicate(true), true)
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
	elif error >= GameConfig.NET_CORRECT_MIN: correction = true

func predict(move: Vector2, delta: float, dash: bool) -> void:
	seq += 1
	var player: Dictionary = state.players[player_index]
	if dash and float(player.dash_cd) <= 0 and float(player.stun) <= 0: dash_left = GameConfig.DASH_DURATION
	predicted = _move(predicted, move, delta, dash_left > 0)
	dash_left = maxf(0, dash_left - delta)
	pending.append({"seq": seq, "move": move, "dt": delta, "dash": dash_left > 0})
	if pending.size() > 120: pending.pop_front()

func _move(position: Vector2, move: Vector2, delta: float, dashing: bool) -> Vector2:
	var player: Dictionary = state.players[player_index]
	if float(player.stun) > 0 or float(player.rooted_left) > 0: return position
	var speed := GameConfig.PLAYER_SPEED
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
	return ArenaPhysics.move_circle(position, move.limit_length() * speed * delta, GameConfig.PLAYER_RADIUS, state.player_hitbox_rects)

func render(delta: float) -> Dictionary:
	clock += delta
	if correction:
		predicted = predicted.lerp(target, minf(1.0, delta * GameConfig.NET_CORRECT_SPEED))
		if predicted.distance_to(target) < 1.0: correction = false
	var result := state.duplicate(true)
	var render_time := clock - GameConfig.NET_INTERPOLATION_SECONDS
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

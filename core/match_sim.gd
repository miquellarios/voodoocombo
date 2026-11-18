class_name MatchSim
extends RefCounted

const OFFSET := Vector2(40, 60)
var mode := "voodoo"
var elapsed := 0.0
var remaining := 90.0
var seed_value := 0
var arena: Dictionary = {}
var safe_zone_step := 0
var safe_zone_warning_step := 0
var chest_fade_alpha: Array[float] = []
var obstacle_rects: Array[Rect2] = []
var player_hitbox_rects: Array[Rect2] = []
var hazard_runtime: Array[Dictionary] = []
var players: Array[Dictionary] = []
var coins: Array[Dictionary] = []
var chests: Array[Vector2] = []
var opened_chests: Array[Dictionary] = []
var rng := RandomNumberGenerator.new()
var roll_time := 0.0
var roll_player := -1
var roll_result := ""
var frenzy_notified := false
var bots_dash_global_left := 0.0
var events: Array[Dictionary] = []
var current_inputs: Array[Dictionary] = []
var finished := false
var achievements := MatchAchievements.new()

func setup(config: Dictionary) -> void:
	seed_value = int(config.get("seed", 1))
	rng.seed = seed_value
	mode = str(config.get("mode", "voodoo"))
	arena = ArenaGen.generate(seed_value, str(config.get("previous_arena", "")), str(config.get("arena_id", "")), mode == "classic")
	obstacle_rects = _get_obstacle_rects(arena.get("obstacles", []))
	player_hitbox_rects = _get_obstacle_hitboxes(arena.get("obstacles", []))
	players.clear()
	coins.clear()
	chests.clear()
	opened_chests.clear()
	chest_fade_alpha.clear()
	events.clear()
	current_inputs.clear()
	elapsed = 0.0
	remaining = float(config.get("duration", GameConfig.CLASSIC_SECONDS if mode == "classic" else GameConfig.MATCH_SECONDS))
	finished = false
	frenzy_notified = false
	bots_dash_global_left = 0.0
	roll_time = 0.0
	roll_player = -1
	roll_result = ""
	safe_zone_step = 0
	safe_zone_warning_step = 0
	_initialize_hazard_runtime()
	var roster: Array = config.get("players", [])
	var names: Array = ["Jugador", "Mordisquitos", "Conde Costura", "Dama del Pantano"]
	var characters: Array = ["mago", "trol", "gnomo", "nigro"]
	var sprite_colors: Array = ["coral", "azul", "lima", "hueso"]
	for i in range(mini(4, roster.size())):
		var entry: Dictionary = roster[i]
		names[i] = str(entry.get("name", names[i]))
		characters[i] = str(entry.get("character", characters[i]))
		players.append({"name": names[i], "character": characters[i], "sprite_color": sprite_colors[i], "pos": arena.spawns[i], "vel": Vector2.ZERO, "color": GameConfig.COLORS[i], "shape": GameConfig.SHAPES[i], "coins": 0, "score": 0, "collected": 0, "combo": 0, "max_combo": 0, "last_pickup": -10.0, "dash_left": 0.0, "dash_cd": 0.0, "dash_dir": Vector2.RIGHT, "stun": 0.0, "invuln": 0.0, "item": "", "item_time": 0.0, "stolen": 0, "dashes": 0, "sheep": 0, "hits": 0, "is_bot": i > 0, "dash_lock": 0.0, "recoil_left": 0.0, "recoil_dir": Vector2.ZERO, "rooted_left": 0.0, "hazard_cooldowns": {}, "bot_repath_left": 0.0, "bot_path": [], "bot_path_index": 0, "bot_goal": Vector2.ZERO, "bot_stuck_left": 0.0, "bot_stuck_position": arena.spawns[i], "bot_escape_left": 0.0, "bot_escape_direction": Vector2.ZERO, "bot_action_left": 0.5, "bot_dash_target": -1, "bot_recent_hit": 0.0, "bot_ignored_peer": -1, "zone_drain_left": GameConfig.ZONE_DRAIN_INTERVAL})
		players[i].is_bot = bool(entry.get("is_bot", i > 0))
		players[i]["peer_id"] = int(entry.get("peer_id", i + 1))
	for coin_pos in arena.coins:
		coins.append({"pos": coin_pos, "owner": -1, "lock": 0.0, "phase": rng.randf_range(0.0, TAU)})
	achievements.setup(players.size())
	for player in players: player["medals"] = []

func step(delta: float, inputs: Array[Dictionary]) -> void:
	if finished or delta <= 0.0 or players.is_empty(): return
	var event_start := events.size()
	current_inputs = inputs.duplicate(true)
	delta = minf(delta, remaining)
	for index in range(players.size()):
		if bool(players[index].get("disconnected", false)): continue
		if bool(players[index].is_bot): continue
		var entry: Dictionary = current_inputs[index] if index < current_inputs.size() else {}
		if bool(entry.get("dash", false)): _start_dash(index)
		if bool(entry.get("spell", false)): _use_spell(index)
	bots_dash_global_left = maxf(0.0, bots_dash_global_left - delta)
	elapsed += delta
	remaining = maxf(0.0, remaining - delta)
	if not frenzy_notified and mode == "voodoo" and remaining <= GameConfig.FRENZY_SECONDS:
		frenzy_notified = true
		events.append({"type": "frenzy_started"})
		_pop(_message("frenzy"), Vector2(640, 150), GameConfig.GOLD)
		_tone(520.0, 0.35)
	var target := GameConfig.FRENZY_COIN_TARGET if remaining <= GameConfig.FRENZY_SECONDS else GameConfig.COIN_RESPAWN_THRESHOLD
	if mode == "voodoo" and int(elapsed / GameConfig.COIN_RESPAWN_INTERVAL) != int((elapsed - delta) / GameConfig.COIN_RESPAWN_INTERVAL) and coins.size() < target: _spawn_coin()
	for coin in coins: coin.lock = maxf(0.0, coin.lock - delta)
	_update_opened_chests(delta)
	if int(elapsed / 8.0) != int((elapsed - delta) / 8.0) and chests.size() < 2:
		chests.append(_random_position_in_safe_zone())
		chest_fade_alpha.append(1.0)
	for index in range(players.size()):
		if bool(players[index].get("disconnected", false)): continue
		if bool(players[index].is_bot): _update_bot(index, delta)
		else: _update_player(index, delta)
	_update_arena_hazards(delta)
	_update_dash_hits()
	_separate_players()
	_update_safe_zone(delta)
	_update_pickups()
	_update_roll(delta)
	events.append_array(achievements.update(players, events.slice(event_start), elapsed))
	if remaining <= 0.000001:
		remaining = 0.0
		_finish_match()

func snapshot() -> Dictionary:
	var result: Dictionary = {}
	for key in ["mode","elapsed","remaining","seed_value","arena","safe_zone_step","safe_zone_warning_step","chest_fade_alpha","obstacle_rects","player_hitbox_rects","hazard_runtime","players","coins","chests","opened_chests","roll_time","roll_player","roll_result","frenzy_notified","bots_dash_global_left"]:
		var value: Variant = get(key)
		result[key] = value.duplicate(true) if value is Array or value is Dictionary else value
	result["finished"] = finished
	return result

func pop_events() -> Array[Dictionary]:
	var result := events.duplicate(true)
	events.clear()
	return result

func _input_move(index: int) -> Vector2:
	if index >= current_inputs.size(): return Vector2.ZERO
	var move: Variant = current_inputs[index].get("move", Vector2.ZERO)
	return (move as Vector2).limit_length() if move is Vector2 and move.is_finite() else Vector2.ZERO

func disconnect_player(peer_id: int) -> void:
	for player: Dictionary in players:
		if int(player.peer_id) == peer_id:
			events.append({"type": "player_left", "peer_id": peer_id, "pos": player.pos})
			player["disconnected"] = true
			player.pos = Vector2(-10000, -10000)
			player.vel = Vector2.ZERO
	var humans: Array[Dictionary] = []
	for player in players:
		if not bool(player.is_bot) and not bool(player.get("disconnected", false)): humans.append(player)
	if humans.size() == 1:
		_finish_match(int(humans[0].peer_id))

func _finish_match(winner_peer: int = 0) -> void:
	if finished: return
	finished = true
	var active: Array[Dictionary] = players.filter(func(player: Dictionary): return not bool(player.get("disconnected", false)))
	var ranking := MatchRanking.rank(active)
	if winner_peer != 0:
		for index in ranking.size():
			if int(ranking[index].peer_id) == winner_peer:
				var winner: Dictionary = ranking.pop_at(index)
				ranking.push_front(winner)
				break
	events.append({"type": "match_over", "ranking": ranking, "awards": MatchRanking.awards(active)})

func _message(key: String) -> String:
	return "{" + key + "}"

func _pop(text: String, position: Vector2, color: Color) -> void:
	events.append({"type": "text", "text": text, "position": position, "color": color})

func _tone(frequency: float, duration: float) -> void:
	events.append({"type": "tone", "frequency": frequency, "duration": duration})

func _hit_feedback() -> void:
	events.append({"type": "hit_feedback"})

func _update_player(index: int, delta: float) -> void:
	var player := players[index]
	var direction := _input_move(index)
	if direction.length() < 0.15: direction = Vector2.ZERO
	if direction.length() > 1.0: direction = direction.normalized()
	player.stun = maxf(0.0, player.stun - delta)
	player.invuln = maxf(0.0, player.invuln - delta)
	player.dash_cd = maxf(0.0, player.dash_cd - delta)
	player.dash_lock = maxf(0.0, player.dash_lock - delta)
	player.rooted_left = maxf(0.0, player.rooted_left - delta)
	if player.rooted_left > 0.0:
		player.vel = Vector2.ZERO
		return
	if player.recoil_left > 0.0:
		var recoil_motion: Vector2 = player.recoil_dir * GameConfig.DASH_CLASH_RECOIL_DISTANCE * delta / GameConfig.DASH_CLASH_RECOIL_SECONDS
		player.pos = _move_player(player.pos, recoil_motion)
		player.recoil_left = maxf(0.0, player.recoil_left - delta)
		player.vel = Vector2.ZERO
		return
	var had_timed_item: bool = float(player.item_time) > 0.0
	player.item_time = maxf(0.0, player.item_time - delta)
	if had_timed_item and player.item_time == 0.0:
		player.item = ""
	if player.stun > 0.0:
		return
	if direction != Vector2.ZERO:
		player.dash_dir = direction
	var zone_speed := GameConfig.ZONE_SPEED_MULTIPLIER if not ZoneRules.is_inside(player.pos, safe_zone_step) else 1.0
	var speed := GameConfig.PLAYER_SPEED * (1.6 if SpellRules.is_active(player, "boots") else 1.0) * _terrain_speed(player.pos) * zone_speed
	if SpellRules.is_active(player, "sheep"): speed *= 0.6
	var motion: Vector2
	if player.dash_left > 0.0:
		player.dash_left = maxf(0.0, player.dash_left - delta)
		motion = player.dash_dir * speed * GameConfig.DASH_MULTIPLIER * delta
	else:
		player.vel = direction * speed
		motion = player.vel * delta
	var previous_position: Vector2 = player.pos
	player.pos = _move_player(player.pos, motion)
	if player.dash_left > 0.0 and player.pos.distance_to(previous_position) + 0.1 < motion.length():
		player.dash_left = 0.0
	if SpellRules.is_active(player, "magnet"):
		for coin in coins:
			if player.pos.distance_to(coin.pos) < GameConfig.SPELL_MAGNET_RADIUS:
				coin.pos = coin.pos.move_toward(player.pos, 260.0 * delta)


func _update_bot(index: int, delta: float) -> void:
	var player := players[index]
	player.stun = maxf(0.0, player.stun - delta)
	player.dash_cd = maxf(0.0, player.dash_cd - delta)
	player.invuln = maxf(0.0, player.invuln - delta)
	player.dash_lock = maxf(0.0, player.dash_lock - delta)
	player.bot_recent_hit = maxf(0.0, player.bot_recent_hit - delta)
	player.rooted_left = maxf(0.0, player.rooted_left - delta)
	if player.rooted_left > 0.0:
		player.vel = Vector2.ZERO
		return
	if player.recoil_left > 0.0:
		var recoil_motion: Vector2 = player.recoil_dir * GameConfig.DASH_CLASH_RECOIL_DISTANCE * delta / GameConfig.DASH_CLASH_RECOIL_SECONDS
		player.pos = _move_player(player.pos, recoil_motion)
		player.recoil_left = maxf(0.0, player.recoil_left - delta)
		player.vel = Vector2.ZERO
		return
	var had_timed_item: bool = float(player.item_time) > 0.0
	player.item_time = maxf(0.0, player.item_time - delta)
	if had_timed_item and player.item_time == 0.0: player.item = ""
	if player.stun > 0.0:
		return
	var coin_positions: Array[Vector2] = []
	for coin in coins: coin_positions.append(coin.pos)
	var chest_positions: Array[Vector2] = []
	if player.item.is_empty():
		for chest in chests:
			chest_positions.append(chest)
	var direction := BotBrain.next_direction(player, coin_positions, chest_positions, arena, players, index, delta, elapsed, rng)
	if not ZoneRules.is_inside(player.pos, safe_zone_step):
		coin_positions = [ZoneRules.safe_rect(safe_zone_step).get_center()]
		chest_positions.clear()
		direction = BotBrain.next_direction(player, coin_positions, chest_positions, arena, players, index, delta, elapsed, rng)
	player.bot_action_left = float(player.bot_action_left) - delta
	if player.bot_action_left <= 0.0:
		player.bot_action_left = rng.randf_range(GameConfig.BOT_DECISION_MIN_SECONDS, GameConfig.BOT_DECISION_MAX_SECONDS)
		_use_spell_for_bot(index)
		player.bot_dash_target = BotBrain.choose_dash_target(player, players, index, obstacle_rects, rng) if bots_dash_global_left <= 0.0 else -1
	if bots_dash_global_left <= 0.0 and player.dash_cd <= 0.0 and int(player.bot_dash_target) >= 0 and player.dash_lock <= 0.0:
		var target_index := int(player.bot_dash_target)
		if target_index < players.size():
			direction = (players[target_index].pos - player.pos).normalized()
			player.dash_dir = direction
			player.dash_left = GameConfig.DASH_DURATION
			player.dash_cd = GameConfig.SPELL_BOOTS_DASH_COOLDOWN if SpellRules.is_active(player, "boots") else GameConfig.DASH_COOLDOWN
			bots_dash_global_left = GameConfig.BOT_TEAM_DASH_INTERVAL
		player.bot_dash_target = -1
	var zone_speed := GameConfig.ZONE_SPEED_MULTIPLIER if not ZoneRules.is_inside(player.pos, safe_zone_step) else 1.0
	var speed_scale := (0.6 if SpellRules.is_active(player, "sheep") else (1.6 if SpellRules.is_active(player, "boots") else 1.0)) * _terrain_speed(player.pos) * zone_speed
	var movement: Vector2 = player.dash_dir
	if player.dash_left <= 0.0:
		movement = direction
		player.vel = direction * GameConfig.PLAYER_SPEED * speed_scale
	var motion := movement * GameConfig.PLAYER_SPEED * speed_scale * delta * (GameConfig.DASH_MULTIPLIER if player.dash_left > 0.0 else 1.0)
	var previous_position: Vector2 = player.pos
	player.pos = _move_player(player.pos, motion)
	if player.dash_left > 0.0 and player.pos.distance_to(previous_position) + 0.1 < motion.length():
		player.dash_left = 0.0
	if player.dash_left > 0.0: player.dash_left = maxf(0.0, player.dash_left - delta)
	if SpellRules.is_active(player, "magnet"):
		for coin in coins:
			if player.pos.distance_to(coin.pos) < GameConfig.SPELL_MAGNET_RADIUS:
				coin.pos = coin.pos.move_toward(player.pos, 260.0 * delta)


func _start_dash(index: int) -> void:
	var player := players[index]
	if player.dash_cd > 0.0 or player.dash_lock > 0.0 or player.stun > 0.0 or SpellRules.is_active(player, "sheep"): return
	player.dash_left = GameConfig.DASH_DURATION
	player.dash_cd = GameConfig.SPELL_BOOTS_DASH_COOLDOWN if SpellRules.is_active(player, "boots") else GameConfig.DASH_COOLDOWN
	if player.vel.length() > 0.1: player.dash_dir = player.vel.normalized()
	_tone(180.0, 0.12)


func _update_pickups() -> void:
	for i in range(players.size()):
		if bool(players[i].get("disconnected", false)): continue
		var player := players[i]
		if SpellRules.is_active(player, "sheep"): continue
		for c in range(coins.size() - 1, -1, -1):
			var coin: Dictionary = coins[c]
			if player.pos.distance_to(coin.pos) > 28.0 or (coin.owner == i and coin.lock > 0.0): continue
			var value := 1
			if mode == "classic":
				player.collected += 1
				player.coins += 1
				player.score = player.coins
			else:
				player.combo = Scoring.next_combo(player.combo, elapsed - player.last_pickup)
				player.max_combo = maxi(player.max_combo, player.combo)
				value = Scoring.coin_value(player.combo, remaining <= GameConfig.FRENZY_SECONDS, SpellRules.is_active(player, "ring"), false)
				player.coins += value
				player.score = player.coins
				player.last_pickup = elapsed
				if player.combo in [5, 12]:
					var text := _message("combo") if player.combo == 5 else _message("voodoo_combo")
					_pop(text, GameConfig.COMBO_NOTICE_POSITION, GameConfig.GOLD)
					_tone(500.0 + player.combo * 14.0, 0.18)
			var combo_multiplier := Scoring.multiplier(player.combo, mode == "classic")
			var pickup_color := GameConfig.FLOAT_COLOR_VOODOO if combo_multiplier >= 3 else (GameConfig.FLOAT_COLOR_FRENZY if combo_multiplier == 2 else GameConfig.FLOAT_COLOR_BASE)
			_pop("+%d" % (1 if mode == "classic" else value), player.pos + OFFSET, pickup_color)
			_tone(600.0 + player.combo * 18.0, 0.09)
			events.append({"type": "coin_taken", "player": i, "value": value, "combo": player.combo, "pos": coin.pos})
			coins.remove_at(c)
			if mode == "classic" and player.coins >= GameConfig.CLASSIC_TARGET:
				_finish_match()
			break
		for chest_i in range(chests.size() - 1, -1, -1):
			if player.item == "" and player.pos.distance_to(chests[chest_i]) < 30.0 and roll_time <= 0.0:
				opened_chests.append({"pos": chests[chest_i], "elapsed": 0.0})
				_start_roll(i)
				chests.remove_at(chest_i)
				chest_fade_alpha.remove_at(chest_i)
				break
		if player.combo > 0 and elapsed - player.last_pickup > GameConfig.COMBO_WINDOW:
			events.append({"type": "combo_lost", "player": i, "combo": player.combo, "pos": player.pos})
			player.combo = 0


func _update_dash_hits() -> void:
	for i in range(players.size()):
		if bool(players[i].get("disconnected", false)): continue
		if players[i].dash_left <= 0.0: continue
		for j in range(players.size()):
			if bool(players[j].get("disconnected", false)): continue
			var distance: float = players[i].pos.distance_to(players[j].pos)
			if i != j and distance > GameConfig.PLAYER_RADIUS * 2 and distance <= GameConfig.PLAYER_RADIUS * 2 + GameConfig.MEDAL_NEAR_PIXELS: events.append({"type": "near_miss", "player": j})
			if i == j or players[j].invuln > 0.0 or players[i].pos.distance_to(players[j].pos) > GameConfig.PLAYER_RADIUS * 2.0: continue
			if players[j].dash_left > 0.0:
				var away: Vector2 = (players[i].pos - players[j].pos).normalized()
				if away == Vector2.ZERO:
					away = Vector2.RIGHT
				players[i].recoil_dir = away
				players[j].recoil_dir = -away
				players[i].recoil_left = GameConfig.DASH_CLASH_RECOIL_SECONDS
				players[j].recoil_left = GameConfig.DASH_CLASH_RECOIL_SECONDS
				players[i].dash_lock = GameConfig.DASH_CLASH_LOCK_SECONDS
				players[j].dash_lock = GameConfig.DASH_CLASH_LOCK_SECONDS
				players[i].dash_left = 0.0
				players[j].dash_left = 0.0
				_hit_feedback()
				_tone(210.0, 0.12)
				break
			var fraction := GameConfig.RING_HIT_DROP_FRACTION if SpellRules.is_active(players[j], "ring") else (GameConfig.CROWN_HIT_DROP_FRACTION if j == _leader_index() else GameConfig.HIT_DROP_FRACTION)
			var result := _apply_hit(j, i, fraction, GameConfig.HIT_DROP_MIN, GameConfig.HIT_DROP_MAX, GameConfig.HIT_STUN_SECONDS, "trap_zap")
			if not result.applied:
				players[i].dash_left = 0.0
				break
			var dropped := int(result.dropped)
			players[i].dashes += 1
			if players[i].is_bot:
				players[i].bot_recent_hit = GameConfig.BOT_RECENT_HIT_LOCK_SECONDS
				players[i].bot_ignored_peer = j
				players[i].bot_repath_left = 0.0
			players[i].dash_left = 0.0
			break


func _update_safe_zone(delta: float) -> void:
	var thresholds: Array = GameConfig.CLASSIC_ZONE_TIMES if mode == "classic" else GameConfig.VOODOO_ZONE_TIMES
	for step_index in range(thresholds.size()):
		var step := step_index + 1
		var threshold := float(thresholds[step_index])
		if safe_zone_warning_step < step and remaining <= threshold + GameConfig.ZONE_WARNING_SECONDS:
			safe_zone_warning_step = step
			_pop(_message("zone_warning"), GameConfig.ZONE_WARNING_POSITION, GameConfig.ZONE_WARNING_COLOR)
			_tone(GameConfig.ZONE_WARNING_TONE_HZ, GameConfig.ZONE_WARNING_TONE_SECONDS)
		if safe_zone_step < step and remaining <= threshold:
			safe_zone_step = step
			events.append({"type": "zone_step", "step": step})
	var safe_rect := ZoneRules.safe_rect(safe_zone_step)
	for coin in coins:
		if not safe_rect.has_point(coin.pos):
			coin.pos = _random_position_in_safe_zone()
			coin.fade_left = GameConfig.ZONE_COIN_FADE_SECONDS
			coin.fade_alpha = 0.0
		elif float(coin.get("fade_left", 0.0)) > 0.0:
			coin.fade_left = maxf(0.0, float(coin.fade_left) - delta)
			coin.fade_alpha = 1.0 - float(coin.fade_left) / GameConfig.ZONE_COIN_FADE_SECONDS
	for chest_index in range(chests.size()):
		if not safe_rect.has_point(chests[chest_index]):
			chests[chest_index] = _random_position_in_safe_zone()
			chest_fade_alpha[chest_index] = 0.0
		elif chest_fade_alpha[chest_index] < 1.0:
			chest_fade_alpha[chest_index] = minf(1.0, chest_fade_alpha[chest_index] + delta / GameConfig.ZONE_COIN_FADE_SECONDS)
	for index in range(players.size()):
		if bool(players[index].get("disconnected", false)): continue
		var player: Dictionary = players[index]
		if safe_rect.has_point(player.pos):
			player.zone_drain_left = GameConfig.ZONE_DRAIN_INTERVAL
			continue
		var drain := ZoneRules.advance_drain(float(player.zone_drain_left), delta, GameConfig.ZONE_DRAIN_INTERVAL)
		player.zone_drain_left = float(drain.remaining)
		for _tick in range(int(drain.ticks)):
			if int(player.coins) <= 0: continue
			player.coins -= 1
			player.score = player.coins
			_pop("-1", player.pos + OFFSET, GameConfig.ZONE_DRAIN_COLOR)

func _random_position_in_safe_zone() -> Vector2:
	var safe_rect := ZoneRules.safe_rect(safe_zone_step)
	var margin := GameConfig.ZONE_PICKUP_MARGIN
	for _attempt in range(GameConfig.ZONE_RANDOM_ATTEMPTS):
		var candidate := Vector2(rng.randf_range(safe_rect.position.x + margin, safe_rect.end.x - margin), rng.randf_range(safe_rect.position.y + margin, safe_rect.end.y - margin))
		if not _coin_position_is_clear(candidate): continue
		var near_coin := false
		for coin in coins:
			if candidate.distance_to(coin.pos) < GameConfig.ZONE_COIN_SEPARATION:
				near_coin = true
				break
		if not near_coin: return candidate
	return safe_rect.get_center()


func _apply_hit(victim_index: int, attacker_index: int, fraction: float, minimum: int, maximum: int, stun_seconds: float, text_key: String = "trap_zap") -> Dictionary:
	var previous_combo := int(players[victim_index].combo)
	var result := HazardRules.resolve_hit(players[victim_index], fraction, minimum, maximum, stun_seconds)
	if result.blocked:
		_pop(_message("trap_blocked"), players[victim_index].pos + OFFSET, Color("7fe7ff"))
		_tone(720.0, 0.08)
		return result
	if not result.applied:
		return result
	players[victim_index] = result.victim
	if previous_combo > 0: events.append({"type": "combo_lost", "player": victim_index, "combo": previous_combo, "pos": players[victim_index].pos})
	var dropped := int(result.dropped)
	events.append({"type": "player_hit", "victim": victim_index, "attacker": attacker_index, "dropped": dropped})
	_drop_coins(victim_index, dropped)
	if attacker_index >= 0:
		players[attacker_index].stolen += dropped
	_hit_feedback()
	var text := _message(text_key)
	if dropped > 0:
		text += " -%d" % dropped
	_pop(text, players[victim_index].pos + OFFSET, Color("ff7474"))
	_tone(140.0, 0.16)
	return result


func _drop_coins(victim_index: int, count: int) -> void:
	if count <= 0:
		return
	for coin_index in range(count):
		var base_angle := rng.randf_range(0.0, TAU)
		var distance := rng.randf_range(GameConfig.DROPPED_COIN_MIN_DISTANCE, GameConfig.DROPPED_COIN_MAX_DISTANCE)
		var position: Vector2 = players[victim_index].pos + Vector2.RIGHT.rotated(base_angle) * distance
		for _attempt in range(8):
			if _coin_position_is_clear(position):
				break
			base_angle += PI / 4.0
			position = players[victim_index].pos + Vector2.RIGHT.rotated(base_angle) * distance
		if not _coin_position_is_clear(position):
			position = _random_position()
		coins.append({"pos": position, "owner": victim_index, "lock": GameConfig.DROPPED_COIN_LOCK_SECONDS, "phase": rng.randf_range(0.0, TAU)})


func _initialize_hazard_runtime() -> void:
	hazard_runtime.clear()
	for hazard in arena.get("hazards", []):
		hazard_runtime.append({"roots_state": "idle", "roots_timer": GameConfig.ROOTS_PERIOD, "roots_position": Vector2.ZERO, "player_cooldowns": [0.0, 0.0, 0.0, 0.0], "last_steam_cycle": -1, "barrel_state": "idle", "barrel_timer": 0.0})


func _update_arena_hazards(delta: float) -> void:
	if players.is_empty():
		return
	var hazards: Array = arena.get("hazards", [])
	for hazard_index in range(hazards.size()):
		var hazard: Dictionary = hazards[hazard_index]
		var runtime: Dictionary = hazard_runtime[hazard_index]
		var kind := String(hazard.get("type", ""))
		match kind:
			"lodo":
				pass
			"raices":
				_update_roots(runtime, delta)
			"pinchos":
				_update_spikes(hazard)
			"fantasma":
				_update_ghost(hazard, runtime, delta)
			"cinta":
				_update_conveyor(hazard, delta)
			"vapor":
				_update_steam(hazard, runtime, delta)
			"barril":
				_update_barrel(hazard, runtime, delta)
			"portal":
				_update_portal(hazard, runtime, delta)
			"rayo":
				_update_ray(hazard)


func _update_roots(runtime: Dictionary, delta: float) -> void:
	runtime.roots_timer = float(runtime.roots_timer) - delta
	var roots_state := String(runtime.roots_state)
	if roots_state == "idle" and runtime.roots_timer <= 0.0:
		runtime.roots_position = _random_position()
		runtime.roots_state = "warn"
		runtime.roots_timer = GameConfig.ROOTS_WARN_SECONDS
	elif roots_state == "warn" and runtime.roots_timer <= 0.0:
		runtime.roots_state = "active"
		runtime.roots_timer = GameConfig.ROOTS_ACTIVE_SECONDS
	elif roots_state == "active" and runtime.roots_timer <= 0.0:
		runtime.roots_state = "idle"
		runtime.roots_timer = GameConfig.ROOTS_PERIOD
	if String(runtime.roots_state) != "active":
		return
	for player_index in range(players.size()):
		if bool(players[player_index].get("disconnected", false)): continue
		if players[player_index].rooted_left > 0.0 or players[player_index].pos.distance_to(runtime.roots_position) > GameConfig.ROOTS_RADIUS:
			continue
		var result := _apply_hit(player_index, -1, GameConfig.TRAP_DROP_PCT, GameConfig.TRAP_DROP_MIN, GameConfig.TRAP_DROP_MAX, 0.0, "trap_root")
		if result.applied:
			players[player_index].rooted_left = GameConfig.ROOTED_SECONDS


func _update_spikes(hazard: Dictionary) -> void:
	var current_state := HazardRules.spike_state(elapsed, float(hazard.get("phase", 0.0)), float(hazard.get("down", GameConfig.SPIKE_DOWN_SECONDS)), float(hazard.get("warn", GameConfig.SPIKE_WARN_SECONDS)), float(hazard.get("up", GameConfig.SPIKE_UP_SECONDS)))
	if current_state != "up":
		return
	for player_index in range(players.size()):
		if bool(players[player_index].get("disconnected", false)): continue
		for tile in hazard.get("tiles", []):
			var rect := _tile_rect(tile).grow(GameConfig.PLAYER_RADIUS)
			if rect.has_point(players[player_index].pos):
				_apply_hit(player_index, -1, GameConfig.TRAP_DROP_PCT, GameConfig.TRAP_DROP_MIN, GameConfig.TRAP_DROP_MAX, GameConfig.HIT_STUN_SECONDS, "trap_zap")
				break


func _update_ghost(hazard: Dictionary, runtime: Dictionary, delta: float) -> void:
	var ghost_pos := _ghost_position(hazard)
	var cooldowns: Array = runtime.player_cooldowns
	for index in range(players.size()):
		if bool(players[index].get("disconnected", false)): continue
		cooldowns[index] = maxf(0.0, float(cooldowns[index]) - delta)
		if cooldowns[index] <= 0.0 and players[index].pos.distance_to(ghost_pos) <= GameConfig.PLAYER_RADIUS + GameConfig.GHOST_RADIUS:
			_apply_hit(index, -1, GameConfig.TRAP_DROP_PCT, GameConfig.TRAP_DROP_MIN, GameConfig.TRAP_DROP_MAX, GameConfig.GHOST_STUN_SECONDS, "trap_ghost")
			cooldowns[index] = GameConfig.GHOST_IGNORE_SECONDS
	runtime.player_cooldowns = cooldowns


func _update_conveyor(hazard: Dictionary, delta: float) -> void:
	var direction := _json_point(hazard.get("dir", [1.0, 0.0])).normalized()
	var motion := direction * GameConfig.CONVEYOR_SPEED * delta
	for tile in hazard.get("tiles", []):
		var rect := _tile_rect(tile)
		for player_index in range(players.size()):
			if bool(players[player_index].get("disconnected", false)): continue
			if rect.has_point(players[player_index].pos):
				players[player_index].pos = _move_player(players[player_index].pos, motion)
		for coin in coins:
			if rect.has_point(coin.pos):
				coin.pos += motion


func _update_steam(hazard: Dictionary, runtime: Dictionary, _delta: float) -> void:
	var state_now := HazardRules.steam_state(elapsed, GameConfig.STEAM_PERIOD, GameConfig.STEAM_WARN_SECONDS, GameConfig.STEAM_BLAST_SECONDS)
	if state_now != "blast":
		return
	var cycle := floori(elapsed / GameConfig.STEAM_PERIOD)
	if int(runtime.last_steam_cycle) == cycle:
		return
	runtime.last_steam_cycle = cycle
	var center := _json_point(hazard.get("center", []))
	for player_index in range(players.size()):
		if bool(players[player_index].get("disconnected", false)): continue
		var offset: Vector2 = players[player_index].pos - center
		if offset.length() > GameConfig.STEAM_RADIUS:
			continue
		var direction := offset.normalized() if offset.length() > 0.01 else Vector2.UP
		var result := _apply_hit(player_index, -1, GameConfig.TRAP_DROP_PCT, GameConfig.TRAP_DROP_MIN, GameConfig.TRAP_DROP_MAX, GameConfig.STEAM_STUN_SECONDS, "trap_steam")
		if result.applied:
			players[player_index].pos = _move_player(players[player_index].pos, direction * GameConfig.STEAM_PUSH_DISTANCE)


func _update_barrel(hazard: Dictionary, runtime: Dictionary, delta: float) -> void:
	var center := _json_point(hazard.get("center", []))
	var state_now := String(runtime.barrel_state)
	if state_now == "idle":
		for player_index in range(players.size()):
			if bool(players[player_index].get("disconnected", false)): continue
			if players[player_index].dash_left > 0.0 and players[player_index].pos.distance_to(center) <= GameConfig.BARREL_CONTACT_RADIUS:
				runtime.barrel_state = "fusing"
				runtime.barrel_timer = GameConfig.BARREL_FUSE_SECONDS
				_pop(_message("trap_barrel"), center + OFFSET, GameConfig.GOLD)
				_tone(330.0, 0.12)
				break
	elif state_now == "fusing":
		runtime.barrel_timer = float(runtime.barrel_timer) - delta
		if runtime.barrel_timer <= 0.0:
			runtime.barrel_state = "exploding"
			runtime.barrel_timer = GameConfig.BARREL_EXPLOSION_SECONDS
			_explode_barrel(center)
	elif state_now == "exploding":
		runtime.barrel_timer = float(runtime.barrel_timer) - delta
		if runtime.barrel_timer <= 0.0:
			runtime.barrel_state = "hidden"
			runtime.barrel_timer = GameConfig.BARREL_RESPAWN_SECONDS
	elif state_now == "hidden":
		runtime.barrel_timer = float(runtime.barrel_timer) - delta
		if runtime.barrel_timer <= 0.0:
			runtime.barrel_state = "idle"


func _explode_barrel(center: Vector2) -> void:
	for player_index in range(players.size()):
		if bool(players[player_index].get("disconnected", false)): continue
		var offset: Vector2 = players[player_index].pos - center
		if offset.length() > GameConfig.BARREL_RADIUS:
			continue
		var direction := offset.normalized() if offset.length() > 0.01 else Vector2.UP
		var result := _apply_hit(player_index, -1, GameConfig.TRAP_DROP_PCT, GameConfig.TRAP_DROP_MIN, GameConfig.TRAP_DROP_MAX, 0.0, "trap_barrel")
		if result.applied:
			players[player_index].pos = _move_player(players[player_index].pos, direction * GameConfig.BARREL_PUSH_DISTANCE)


func _update_portal(hazard: Dictionary, runtime: Dictionary, delta: float) -> void:
	var cooldowns: Array = runtime.player_cooldowns
	for index in range(players.size()):
		if bool(players[index].get("disconnected", false)): continue
		cooldowns[index] = maxf(0.0, float(cooldowns[index]) - delta)
		if cooldowns[index] > 0.0:
			continue
		var a := _json_point(hazard.get("a", []))
		var b := _json_point(hazard.get("b", []))
		var source := a
		var destination := b
		if players[index].pos.distance_to(a) > GameConfig.PORTAL_RADIUS:
			if players[index].pos.distance_to(b) > GameConfig.PORTAL_RADIUS:
				continue
			source = b
			destination = a
		var direction: Vector2 = players[index].vel.normalized()
		if direction == Vector2.ZERO:
			direction = (destination - source).normalized()
		players[index].pos = _move_player(destination + direction * GameConfig.PORTAL_EXIT_DISTANCE, Vector2.ZERO)
		cooldowns[index] = GameConfig.PORTAL_COOLDOWN_SECONDS
		_pop(_message("trap_portal"), players[index].pos + OFFSET, Color("7fe7ff"))
		_tone(760.0, 0.1)
	runtime.player_cooldowns = cooldowns


func _update_ray(hazard: Dictionary) -> void:
	var center := _json_point(hazard.get("center", []))
	var direction := Vector2.RIGHT.rotated(elapsed * TAU / GameConfig.RAY_PERIOD)
	var ends := [center + direction * GameConfig.RAY_LENGTH, center - direction * GameConfig.RAY_LENGTH]
	for player_index in range(players.size()):
		if bool(players[player_index].get("disconnected", false)): continue
		var hit := false
		for endpoint in ends:
			if HazardRules.ray_hits(players[player_index].pos, center, endpoint, GameConfig.RAY_HIT_RADIUS):
				hit = true
				break
		if hit:
			_apply_hit(player_index, -1, GameConfig.TRAP_DROP_PCT, GameConfig.TRAP_DROP_MIN, GameConfig.TRAP_DROP_MAX, GameConfig.HIT_STUN_SECONDS, "trap_ray")


func _start_roll(index: int) -> void:
	roll_player = index
	var order := _score_order()
	var place := order.find(index)
	var player_position := "first" if place == 0 else ("last" if place == order.size() - 1 else "middle")
	roll_result = ItemTable.roll(player_position, rng, mode == "classic")
	roll_time = 0.8
	_tone(420.0, 0.12)


func _update_opened_chests(delta: float) -> void:
	for index in range(opened_chests.size() - 1, -1, -1):
		opened_chests[index].elapsed = float(opened_chests[index].elapsed) + delta
		if opened_chests[index].elapsed >= GameConfig.CHEST_OPEN_SECONDS:
			opened_chests.remove_at(index)


func _update_roll(delta: float) -> void:
	if roll_time <= 0.0: return
	roll_time -= delta
	if roll_time <= 0.0 and roll_player >= 0:
		players[roll_player].item = roll_result
		players[roll_player].item_time = 0.0
		events.append({"type": "item_rolled", "player": roll_player, "item": roll_result})
		_pop(_message("spell_" + roll_result), players[roll_player].pos + OFFSET + Vector2(0, -52), GameConfig.GOLD)
		_tone(880.0, 0.16)


func _use_spell_for_bot(index: int) -> void:
	var player: Dictionary = players[index]
	if not SpellRules.can_activate(player): return
	var item := String(player.item)
	if SpellRules.duration(item) > 0.0:
		var useful := item in ["cloak", "boots", "ring"]
		if item == "magnet":
			for coin in coins:
				if player.pos.distance_to(coin.pos) <= GameConfig.SPELL_MAGNET_RADIUS: useful = true; break
		if useful: player.item_time = SpellRules.duration(item)
	elif _spell_is_useful(index, item):
		_cast_instant_spell(index)


func _spell_is_useful(index: int, item: String) -> bool:
	var player: Dictionary = players[index]
	if item == "frost":
		for j in range(players.size()):
			if bool(players[j].get("disconnected", false)): continue
			if j != index and player.pos.distance_to(players[j].pos) <= GameConfig.SPELL_FROST_RADIUS: return true
	if item == "sheep": return _leader_index() != index
	if item == "pin":
		for j in range(players.size()):
			if bool(players[j].get("disconnected", false)): continue
			if j != index and player.pos.distance_to(players[j].pos) <= GameConfig.SPELL_PIN_RANGE: return true
	return false


func _cast_instant_spell(index: int) -> void:
	var player: Dictionary = players[index]
	events.append({"type": "item_used", "player": index, "item": player.item})
	match String(player.item):
		"frost":
			for j in range(players.size()):
				if bool(players[j].get("disconnected", false)): continue
				if j == index or player.pos.distance_to(players[j].pos) > GameConfig.SPELL_FROST_RADIUS: continue
				if SpellRules.is_active(players[j], "cloak"):
					players[j].item = ""
					players[j].item_time = 0.0
				else: players[j].stun = GameConfig.SPELL_FROST_SECONDS
		"sheep":
			var leader := _leader_index()
			if leader != index:
				if SpellRules.is_active(players[leader], "cloak"):
					players[leader].item = ""
					players[leader].item_time = 0.0
				else:
					players[leader].item = "sheep"
					players[leader].item_time = GameConfig.SPELL_SHEEP_SECONDS
					players[leader].sheep += 1
		"pin":
			var target := -1
			var best := GameConfig.SPELL_PIN_RANGE * GameConfig.SPELL_PIN_RANGE
			for j in range(players.size()):
				if bool(players[j].get("disconnected", false)): continue
				if j != index and player.pos.distance_squared_to(players[j].pos) < best:
					best = player.pos.distance_squared_to(players[j].pos)
					target = j
			if target >= 0:
				var outcome := _apply_hit(target, index, GameConfig.HIT_DROP_FRACTION, GameConfig.HIT_DROP_MIN, GameConfig.HIT_DROP_MAX, GameConfig.HIT_STUN_SECONDS)
				if outcome.applied:
					players[target].pos += player.pos.direction_to(players[target].pos) * GameConfig.SPELL_PIN_PUSH_DISTANCE
	player.item = ""
	player.item_time = 0.0
	_tone(720.0, 0.2)


func _use_spell(index: int) -> void:
	if players.is_empty() or index >= players.size() or not SpellRules.can_activate(players[index]): return
	var item := String(players[index].item)
	if SpellRules.duration(item) > 0.0:
		events.append({"type": "item_used", "player": index, "item": item})
		players[index] = SpellRules.activate(players[index])
		_tone(720.0, 0.2)
	elif _spell_is_useful(index, item):
		_cast_instant_spell(index)

func _json_point(value: Variant) -> Vector2:
	if value is Array and value.size() >= 2:
		return Vector2(float(value[0]), float(value[1]))
	return Vector2.ZERO


func _tile_rect(tile: Variant) -> Rect2:
	var values: Variant = tile if tile is Array else String(tile).split(" ", false)
	if values.size() < 4:
		return Rect2()
	return Rect2(Vector2(float(values[0]), float(values[1])), Vector2(float(values[2]), float(values[3])))


func _terrain_speed(position: Vector2) -> float:
	var speed_multiplier := 1.0
	for hazard in arena.get("hazards", []):
		if String(hazard.get("type", "")) != "lodo":
			continue
		var center := _json_point(hazard.get("center", []))
		var radius: Variant = hazard.get("radius", [0.0, 0.0])
		if radius is Array and radius.size() >= 2:
			var normalized := (position - center) / Vector2(float(radius[0]), float(radius[1]))
			if normalized.length_squared() <= 1.0:
				speed_multiplier = minf(speed_multiplier, float(hazard.get("speed_mult", 0.6)))
	return speed_multiplier


func _ghost_position(hazard: Dictionary) -> Vector2:
	var raw_path: Array = hazard.get("path", [])
	var path: Array[Vector2] = []
	for point in raw_path:
		path.append(_json_point(point) if point is Array else _string_point(point))
	if path.is_empty():
		return Vector2.ZERO
	if path.size() == 1:
		return path[0]
	var total_length := 0.0
	for index in range(path.size()):
		total_length += path[index].distance_to(path[(index + 1) % path.size()])
	var distance := fposmod(elapsed * float(hazard.get("speed", GameConfig.GHOST_SPEED)), total_length)
	for index in range(path.size()):
		var next := path[(index + 1) % path.size()]
		var segment_length := path[index].distance_to(next)
		if distance <= segment_length:
			return path[index].lerp(next, distance / maxf(segment_length, 0.001))
		distance -= segment_length
	return path[0]


func _string_point(value: Variant) -> Vector2:
	var parts: PackedStringArray = String(value).split(" ", false)
	if parts.size() >= 2:
		return Vector2(float(parts[0]), float(parts[1]))
	return Vector2.ZERO


func _coin_position_is_clear(position: Vector2) -> bool:
	if position.x < 16.0 or position.x > GameConfig.ARENA_SIZE.x - 16.0 or position.y < 16.0 or position.y > GameConfig.ARENA_SIZE.y - 16.0:
		return false
	for obstacle in obstacle_rects:
		var closest := Vector2(clampf(position.x, obstacle.position.x, obstacle.end.x), clampf(position.y, obstacle.position.y, obstacle.end.y))
		if closest.distance_to(position) < 16.0:
			return false
	return true


func _random_position() -> Vector2:
	for _attempt in range(100):
		var candidate := Vector2(rng.randf_range(60, 1140), rng.randf_range(60, 540))
		var clear := true
		for cell in arena.get("blocked", {}):
			var rect := Rect2(Vector2(cell) * 40.0, Vector2.ONE * 40.0).grow(18.0)
			if rect.has_point(candidate):
				clear = false
				break
		if clear:
			for coin in coins:
				if candidate.distance_to(coin.pos) < 35.0:
					clear = false
					break
		if clear:
			return candidate
	return Vector2(600.0, 300.0)


func _get_obstacle_rects(obstacles: Array) -> Array[Rect2]:
	var rects: Array[Rect2] = []
	for obstacle in obstacles:
		var values: Array = obstacle.get("rect", [])
		if values.size() >= 4:
			rects.append(Rect2(Vector2(float(values[0]), float(values[1])), Vector2(float(values[2]), float(values[3]))))
	return rects


func _get_obstacle_hitboxes(obstacles: Array) -> Array[Rect2]:
	var rects: Array[Rect2] = []
	for obstacle in obstacles:
		var values: Array = obstacle.get("hitbox", obstacle.get("rect", []))
		if values.size() >= 4:
			rects.append(Rect2(Vector2(float(values[0]), float(values[1])), Vector2(float(values[2]), float(values[3]))))
	return rects


func _move_player(position: Vector2, motion: Vector2) -> Vector2:
	var feet := position + Vector2(0.0, GameConfig.PLAYER_FOOT_OFFSET)
	var moved_feet := ArenaPhysics.move_circle(feet, motion, GameConfig.PLAYER_FOOT_RADIUS, player_hitbox_rects)
	var center := moved_feet - Vector2(0.0, GameConfig.PLAYER_FOOT_OFFSET)
	return Vector2(clampf(center.x, GameConfig.PLAYER_RADIUS, GameConfig.ARENA_SIZE.x - GameConfig.PLAYER_RADIUS), clampf(center.y, GameConfig.PLAYER_RADIUS, GameConfig.ARENA_SIZE.y - GameConfig.PLAYER_RADIUS))


func _separate_players() -> void:
	for first_index in range(players.size()):
		if bool(players[first_index].get("disconnected", false)): continue
		for second_index in range(first_index + 1, players.size()):
			if bool(players[second_index].get("disconnected", false)): continue
			var separated := ArenaPhysics.separate_pair(players[first_index].pos, players[second_index].pos, GameConfig.PLAYER_RADIUS, obstacle_rects)
			players[first_index].pos = separated[0]
			players[second_index].pos = separated[1]


func _spawn_coin() -> void:
	coins.append({"pos": _random_position_in_safe_zone(), "owner": -1, "lock": 0.0, "phase": rng.randf_range(0.0, TAU)})
	events.append({"type": "coin_spawned", "pos": coins.back().pos})


func _leader_index() -> int:
	if players.is_empty(): return -1
	var best := -1
	for i in range(players.size()):
		if bool(players[i].get("disconnected", false)): continue
		if best < 0 or players[i].score > players[best].score: best = i
	return best


func _score_order() -> Array[int]:
	var indices: Array[int] = []
	for i in range(players.size()): indices.append(i)
	indices.sort_custom(func(a: int, b: int) -> bool: return players[a].score > players[b].score)
	return indices

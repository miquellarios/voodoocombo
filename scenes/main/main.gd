extends Node2D

const OFFSET := Vector2(40, 60)
const ITEMS := ["magnet", "boots", "cloak", "pin", "frost", "sheep", "ring"]
const COIN_TEXTURE := preload("res://assets/items/doblon.png")
const COIN_SHADOW_TEXTURE := preload("res://assets/items/doblon_sombra.png")
const CHEST_TEXTURE := preload("res://assets/items/cofre.png")
const SPELL_TEXTURE := preload("res://assets/items/hechizos.png")
const BIOME_COLORS := [[Color("2b3a2a"), Color("243223")], [Color("33402a"), Color("2b3723")], [Color("2a3a4a"), Color("233241")], [Color("3a2a2a"), Color("322323")]]

var state := "menu"
var mode := "voodoo"
var elapsed := 0.0
var remaining := 90.0
var countdown := 0.0
var seed_value := 0
var arena: Dictionary = {}
var previous_arena_id := ""
var obstacle_rects: Array[Rect2] = []
var hazard_runtime: Array[Dictionary] = []
var players: Array[Dictionary] = []
var coins: Array[Dictionary] = []
var chests: Array[Vector2] = []
var opened_chests: Array[Dictionary] = []
var rng := RandomNumberGenerator.new()
var hud: CanvasLayer
var hud_root: Control
var floating: Array[Dictionary] = []
var roll_time := 0.0
var roll_player := -1
var roll_result := ""
var frenzy_notified := false
var arena_background: Texture2D
var character_metadata: Dictionary = {}
var character_sheets: Dictionary = {}
var hazard_sheets: Dictionary = {}
var item_metadata: Dictionary = {}
var spell_atlases: Array[AtlasTexture] = []
var score_name_labels: Array[Label] = []
var score_tag_labels: Array[Label] = []
var score_number_labels: Array[Label] = []
var score_portraits: Array[TextureRect] = []
var score_crowns: Array[TextureRect] = []
var score_values: Array[int] = []
var score_change_times: Array[int] = []
var bots_dash_global_left := 0.0
var end_wait := 0.0
var results_elapsed := 0.0
var results_ranking: Array[Dictionary] = []
var results_awards: Dictionary = {}
var results_xp := 0
var character_preview: TextureRect
var character_preview_id := "mago"
var character_idle := 0.0

func _ready() -> void:
	get_window().title = "VoodooCombo 0.1"
	var metadata: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://assets/characters/characters.json"))
	if metadata is Dictionary:
		character_metadata = metadata
	var items_data: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://assets/items/items.json"))
	if items_data is Dictionary:
		item_metadata = items_data.get("items", {})
	var spell_info: Dictionary = item_metadata.get("hechizos", {})
	for frame in range(ITEMS.size()):
		var atlas := AtlasTexture.new()
		atlas.atlas = SPELL_TEXTURE
		atlas.region = Rect2(frame * int(spell_info.get("frame_w", 128)), 0, int(spell_info.get("frame_w", 128)), int(spell_info.get("frame_h", 128)))
		spell_atlases.append(atlas)
	Fx.floating_text.connect(_on_floating_text)
	Fx.shake.connect(_on_shake)
	_build_menu()

func _process(delta: float) -> void:
	if state == "match_end":
		end_wait = maxf(0.0, end_wait - delta)
		if end_wait == 0.0: _show_results()
		return
	if state == "results":
		results_elapsed += delta
		if results_elapsed >= 10.0: _build_menu()
		return
	if state == "menu":
		if not Settings.reduce_motion: character_idle += delta
		if is_instance_valid(character_preview): _update_character_preview()
		return
	if state == "playing" and Input.is_action_just_pressed("dash"):
		_start_dash(0)
	if state == "playing" and Input.is_action_just_pressed("use_spell"):
		_use_spell(0)
	if state == "countdown":
		countdown -= delta
		if countdown <= 0.0:
			state = "playing"
			Sfx.play_tone(880.0, 0.24)
		_update_hud()
		queue_redraw()
		return
	if state != "playing":
		_animate_floating(delta)
		return
	bots_dash_global_left = maxf(0.0, bots_dash_global_left - delta)
	elapsed += delta
	remaining = maxf(0.0, remaining - delta)
	if not frenzy_notified and mode == "voodoo" and remaining <= 15.0:
		frenzy_notified = true
		Fx.pop("¡FRENESÍ!", Vector2(640, 150), GameConfig.GOLD)
		Sfx.play_tone(520.0, 0.35)
	var coin_target := GameConfig.FRENZY_COIN_TARGET if remaining <= GameConfig.FRENZY_SECONDS else GameConfig.COIN_RESPAWN_THRESHOLD
	if mode == "voodoo" and int(elapsed / GameConfig.COIN_RESPAWN_INTERVAL) != int((elapsed - delta) / GameConfig.COIN_RESPAWN_INTERVAL) and coins.size() < coin_target:
		_spawn_coin()
	for coin in coins:
		coin.lock = maxf(0.0, coin.lock - delta)
	_update_opened_chests(delta)
	var public_players: Array[Dictionary] = []
	for player in players:
		public_players.append({"name": player.name, "score": player.score, "combo": player.combo})
	HttpEndpoint.set_status({"mode": mode, "time": remaining, "players": public_players})
	if int(elapsed / 8.0) != int((elapsed - delta) / 8.0) and chests.size() < 2:
		chests.append(_random_position())
	_update_player(0, delta)
	for i in range(1, players.size()):
		_update_bot(i, delta)
	_update_arena_hazards(delta)
	_update_dash_hits()
	_separate_players()
	_update_pickups()
	_update_roll(delta)
	_update_hud()
	_animate_floating(delta)
	if remaining <= 0.0:
		_finish_match()
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if state == "playing" and event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_SPACE, KEY_SHIFT]:
			_start_dash(0)
		elif event.keycode in [KEY_E, KEY_ENTER, KEY_KP_ENTER]:
			_use_spell(0)
		elif event.keycode == KEY_ESCAPE:
			state = "paused"
			_build_pause()
			get_viewport().set_input_as_handled()
	elif state == "paused" and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		state = "playing"
		_build_hud()

func _begin_match(classic: bool = false) -> void:
	mode = "classic" if classic else "voodoo"
	seed_value = int(Time.get_unix_time_from_system()) + randi()
	rng.seed = seed_value
	arena = ArenaGen.generate(seed_value, previous_arena_id, "", classic)
	previous_arena_id = String(arena.get("map_id", ""))
	obstacle_rects = _get_obstacle_rects(arena.get("obstacles", []))
	_initialize_hazard_runtime()
	arena_background = load("res://assets/arenas/" + String(arena.background)) if not String(arena.background).is_empty() else null
	players.clear()
	coins.clear()
	chests.clear()
	opened_chests.clear()
	floating.clear()
	var names := [Profile.nick, "Mordisquitos", "Conde Costura", "Dama del Pantano"]
	if not ["mago", "trol", "gnomo", "nigro"].has(Profile.character): Profile.character = "mago"
	var characters := [Profile.character, "trol", "gnomo", "nigro"]
	var sprite_colors := ["coral", "azul", "lima", "hueso"]
	for i in range(4):
		var sheet_key := "%s_%s" % [characters[i], sprite_colors[i]]
		if not character_sheets.has(sheet_key):
			character_sheets[sheet_key] = load("res://assets/characters/%s.png" % sheet_key)
		players.append({"name": names[i], "character": characters[i], "sprite_color": sprite_colors[i], "pos": arena.spawns[i], "vel": Vector2.ZERO, "color": GameConfig.COLORS[i], "shape": GameConfig.SHAPES[i], "coins": 0, "score": 0, "collected": 0, "combo": 0, "max_combo": 0, "last_pickup": -10.0, "dash_left": 0.0, "dash_cd": 0.0, "dash_dir": Vector2.RIGHT, "stun": 0.0, "invuln": 0.0, "item": "", "item_time": 0.0, "stolen": 0, "dashes": 0, "sheep": 0, "hits": 0, "is_bot": i > 0, "dash_lock": 0.0, "recoil_left": 0.0, "recoil_dir": Vector2.ZERO, "rooted_left": 0.0, "hazard_cooldowns": {}, "bot_repath_left": 0.0, "bot_path": [], "bot_path_index": 0, "bot_goal": Vector2.ZERO, "bot_stuck_left": 0.0, "bot_stuck_position": arena.spawns[i], "bot_escape_left": 0.0, "bot_escape_direction": Vector2.ZERO, "bot_action_left": 0.5, "bot_dash_target": -1, "bot_recent_hit": 0.0, "bot_ignored_peer": -1})
	for coin_pos in arena.coins:
		coins.append({"pos": coin_pos, "owner": -1, "lock": 0.0, "phase": rng.randf_range(0.0, TAU)})
	elapsed = 0.0
	remaining = GameConfig.CLASSIC_SECONDS if mode == "classic" else GameConfig.MATCH_SECONDS
	frenzy_notified = false
	countdown = 3.0
	state = "countdown"
	_build_hud()
	queue_redraw()

func _update_player(index: int, delta: float) -> void:
	var player := players[index]
	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
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
		player.pos = ArenaPhysics.move_circle(player.pos, recoil_motion, GameConfig.PLAYER_RADIUS, obstacle_rects)
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
	var speed := GameConfig.PLAYER_SPEED * (1.6 if player.item == "boots" else 1.0) * _terrain_speed(player.pos)
	if player.item == "sheep": speed *= 0.6
	var motion: Vector2
	if player.dash_left > 0.0:
		player.dash_left = maxf(0.0, player.dash_left - delta)
		motion = player.dash_dir * speed * GameConfig.DASH_MULTIPLIER * delta
	else:
		player.vel = direction * speed
		motion = player.vel * delta
	var previous_position: Vector2 = player.pos
	player.pos = ArenaPhysics.move_circle(player.pos, motion, GameConfig.PLAYER_RADIUS, obstacle_rects)
	if player.dash_left > 0.0 and player.pos.distance_to(previous_position) + 0.1 < motion.length():
		player.dash_left = 0.0
	if player.item == "magnet":
		for coin in coins:
			if player.pos.distance_to(coin.pos) < 220.0:
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
		player.pos = ArenaPhysics.move_circle(player.pos, recoil_motion, GameConfig.PLAYER_RADIUS, obstacle_rects)
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
	player.bot_action_left = float(player.bot_action_left) - delta
	if player.bot_action_left <= 0.0:
		player.bot_action_left = rng.randf_range(GameConfig.BOT_DECISION_MIN_SECONDS, GameConfig.BOT_DECISION_MAX_SECONDS)
		player.bot_dash_target = BotBrain.choose_dash_target(player, players, index, obstacle_rects, rng) if bots_dash_global_left <= 0.0 else -1
	if bots_dash_global_left <= 0.0 and player.dash_cd <= 0.0 and int(player.bot_dash_target) >= 0 and player.dash_lock <= 0.0:
		var target_index := int(player.bot_dash_target)
		if target_index < players.size():
			direction = (players[target_index].pos - player.pos).normalized()
			player.dash_dir = direction
			player.dash_left = GameConfig.DASH_DURATION
			player.dash_cd = 0.5 if player.item == "boots" else GameConfig.DASH_COOLDOWN
			bots_dash_global_left = GameConfig.BOT_TEAM_DASH_INTERVAL
		player.bot_dash_target = -1
	var speed_scale := (0.6 if player.item == "sheep" else (1.6 if player.item == "boots" else 1.0)) * _terrain_speed(player.pos)
	var movement: Vector2 = player.dash_dir
	if player.dash_left <= 0.0:
		movement = direction
		player.vel = direction * GameConfig.PLAYER_SPEED * speed_scale
	var motion := movement * GameConfig.PLAYER_SPEED * speed_scale * delta * (GameConfig.DASH_MULTIPLIER if player.dash_left > 0.0 else 1.0)
	var previous_position: Vector2 = player.pos
	player.pos = ArenaPhysics.move_circle(player.pos, motion, GameConfig.PLAYER_RADIUS, obstacle_rects)
	if player.dash_left > 0.0 and player.pos.distance_to(previous_position) + 0.1 < motion.length():
		player.dash_left = 0.0
	if player.dash_left > 0.0: player.dash_left = maxf(0.0, player.dash_left - delta)
	if player.item != "" and rng.randf() < delta * 0.4:
		_use_spell_for_bot(index)
	if player.item == "magnet":
		for coin in coins:
			if player.pos.distance_to(coin.pos) < 220.0:
				coin.pos = coin.pos.move_toward(player.pos, 260.0 * delta)

func _start_dash(index: int) -> void:
	var player := players[index]
	if player.dash_cd > 0.0 or player.dash_lock > 0.0 or player.stun > 0.0 or player.item == "sheep": return
	player.dash_left = GameConfig.DASH_DURATION
	player.dash_cd = 0.5 if player.item == "boots" else GameConfig.DASH_COOLDOWN
	if player.vel.length() > 0.1: player.dash_dir = player.vel.normalized()
	Sfx.play_tone(180.0, 0.12)

func _update_pickups() -> void:
	for i in range(players.size()):
		var player := players[i]
		if player.item == "sheep": continue
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
				value = Scoring.coin_value(player.combo, remaining <= GameConfig.FRENZY_SECONDS, player.item == "ring", false)
				player.coins += value
				player.score = player.coins
				player.last_pickup = elapsed
				if player.combo in [5, 12]:
					var text := I18n.t("combo") if player.combo == 5 else I18n.t("voodoo_combo")
					Fx.pop(text, player.pos + OFFSET + Vector2(0, -44), GameConfig.GOLD)
					Sfx.play_tone(500.0 + player.combo * 14.0, 0.18)
			Fx.pop("+%d" % (player.score if mode == "classic" else value), player.pos + OFFSET, GameConfig.GOLD)
			Sfx.play_tone(600.0 + player.combo * 18.0, 0.09)
			coins.remove_at(c)
			if mode == "classic" and player.coins >= GameConfig.CLASSIC_TARGET:
				_finish_match()
			break
		for chest_i in range(chests.size() - 1, -1, -1):
			if player.item == "" and player.pos.distance_to(chests[chest_i]) < 30.0 and roll_time <= 0.0:
				opened_chests.append({"pos": chests[chest_i], "elapsed": 0.0})
				_start_roll(i)
				chests.remove_at(chest_i)
				break
		if player.combo > 0 and elapsed - player.last_pickup > GameConfig.COMBO_WINDOW:
			player.combo = 0

func _update_dash_hits() -> void:
	for i in range(players.size()):
		if players[i].dash_left <= 0.0: continue
		for j in range(players.size()):
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
				Fx.hit()
				Sfx.play_tone(210.0, 0.12)
				break
			var fraction := GameConfig.RING_HIT_DROP_FRACTION if players[j].item == "ring" else (GameConfig.CROWN_HIT_DROP_FRACTION if j == _leader_index() else GameConfig.HIT_DROP_FRACTION)
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

func _apply_hit(victim_index: int, attacker_index: int, fraction: float, minimum: int, maximum: int, stun_seconds: float, text_key: String = "trap_zap") -> Dictionary:
	var result := HazardRules.resolve_hit(players[victim_index], fraction, minimum, maximum, stun_seconds)
	if result.blocked:
		Fx.pop(I18n.t("trap_blocked"), players[victim_index].pos + OFFSET, Color("7fe7ff"))
		Sfx.play_tone(720.0, 0.08)
		return result
	if not result.applied:
		return result
	players[victim_index] = result.victim
	var dropped := int(result.dropped)
	_drop_coins(victim_index, dropped)
	if attacker_index >= 0:
		players[attacker_index].stolen += dropped
	Fx.hit()
	var text := I18n.t(text_key)
	if dropped > 0:
		text += " -%d" % dropped
	Fx.pop(text, players[victim_index].pos + OFFSET, Color("ff7474"))
	Sfx.play_tone(140.0, 0.16)
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
		for tile in hazard.get("tiles", []):
			var rect := _tile_rect(tile).grow(GameConfig.PLAYER_RADIUS)
			if rect.has_point(players[player_index].pos):
				_apply_hit(player_index, -1, GameConfig.TRAP_DROP_PCT, GameConfig.TRAP_DROP_MIN, GameConfig.TRAP_DROP_MAX, GameConfig.HIT_STUN_SECONDS, "trap_zap")
				break

func _update_ghost(hazard: Dictionary, runtime: Dictionary, delta: float) -> void:
	var ghost_pos := _ghost_position(hazard)
	var cooldowns: Array = runtime.player_cooldowns
	for index in range(players.size()):
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
			if rect.has_point(players[player_index].pos):
				players[player_index].pos = ArenaPhysics.move_circle(players[player_index].pos, motion, GameConfig.PLAYER_RADIUS, obstacle_rects)
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
		var offset: Vector2 = players[player_index].pos - center
		if offset.length() > GameConfig.STEAM_RADIUS:
			continue
		var direction := offset.normalized() if offset.length() > 0.01 else Vector2.UP
		var result := _apply_hit(player_index, -1, GameConfig.TRAP_DROP_PCT, GameConfig.TRAP_DROP_MIN, GameConfig.TRAP_DROP_MAX, GameConfig.STEAM_STUN_SECONDS, "trap_steam")
		if result.applied:
			players[player_index].pos = ArenaPhysics.move_circle(players[player_index].pos, direction * GameConfig.STEAM_PUSH_DISTANCE, GameConfig.PLAYER_RADIUS, obstacle_rects)

func _update_barrel(hazard: Dictionary, runtime: Dictionary, delta: float) -> void:
	var center := _json_point(hazard.get("center", []))
	var state_now := String(runtime.barrel_state)
	if state_now == "idle":
		for player_index in range(players.size()):
			if players[player_index].dash_left > 0.0 and players[player_index].pos.distance_to(center) <= GameConfig.BARREL_CONTACT_RADIUS:
				runtime.barrel_state = "fusing"
				runtime.barrel_timer = GameConfig.BARREL_FUSE_SECONDS
				Fx.pop(I18n.t("trap_barrel"), center + OFFSET, GameConfig.GOLD)
				Sfx.play_tone(330.0, 0.12)
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
		var offset: Vector2 = players[player_index].pos - center
		if offset.length() > GameConfig.BARREL_RADIUS:
			continue
		var direction := offset.normalized() if offset.length() > 0.01 else Vector2.UP
		var result := _apply_hit(player_index, -1, GameConfig.TRAP_DROP_PCT, GameConfig.TRAP_DROP_MIN, GameConfig.TRAP_DROP_MAX, 0.0, "trap_barrel")
		if result.applied:
			players[player_index].pos = ArenaPhysics.move_circle(players[player_index].pos, direction * GameConfig.BARREL_PUSH_DISTANCE, GameConfig.PLAYER_RADIUS, obstacle_rects)

func _update_portal(hazard: Dictionary, runtime: Dictionary, delta: float) -> void:
	var cooldowns: Array = runtime.player_cooldowns
	for index in range(players.size()):
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
		players[index].pos = ArenaPhysics.move_circle(destination + direction * GameConfig.PORTAL_EXIT_DISTANCE, Vector2.ZERO, GameConfig.PLAYER_RADIUS, obstacle_rects)
		cooldowns[index] = GameConfig.PORTAL_COOLDOWN_SECONDS
		Fx.pop(I18n.t("trap_portal"), players[index].pos + OFFSET, Color("7fe7ff"))
		Sfx.play_tone(760.0, 0.1)
	runtime.player_cooldowns = cooldowns

func _update_ray(hazard: Dictionary) -> void:
	var center := _json_point(hazard.get("center", []))
	var direction := Vector2.RIGHT.rotated(elapsed * TAU / GameConfig.RAY_PERIOD)
	var ends := [center + direction * GameConfig.RAY_LENGTH, center - direction * GameConfig.RAY_LENGTH]
	for player_index in range(players.size()):
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
	Sfx.play_tone(420.0, 0.12)

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
		players[roll_player].item_time = 8.0 if roll_result == "cloak" else (6.0 if roll_result == "ring" else (5.0 if roll_result == "magnet" else 4.0))
		Fx.pop(roll_result.to_upper(), players[roll_player].pos + OFFSET + Vector2(0, -52), GameConfig.GOLD)
		Sfx.play_tone(880.0, 0.16)

func _use_spell_for_bot(index: int) -> void:
	var player := players[index]
	if player.item == "" or player.item in ["cloak", "boots", "magnet", "ring"]: return
	if player.item == "frost":
		for j in range(players.size()):
			if j != index and player.pos.distance_to(players[j].pos) < 180.0:
				if players[j].item == "cloak": players[j].item = ""
				else: players[j].stun = 1.5
		player.item = ""
	elif player.item == "sheep":
		var leader := _leader_index()
		if leader != index:
			if players[leader].item == "cloak":
				players[leader].item = ""
			else:
				players[leader].item = "sheep"
				players[leader].item_time = 3.0
				players[leader].sheep += 1
			player.item = ""
	elif player.item == "pin":
		var target := -1
		var best := 900.0
		for j in range(players.size()):
			if j != index and player.pos.distance_to(players[j].pos) < best:
				best = player.pos.distance_to(players[j].pos)
				target = j
		if target >= 0:
			player.dash_dir = (players[target].pos - player.pos).normalized()
			player.dash_left = GameConfig.DASH_DURATION
			player.dash_cd = GameConfig.DASH_COOLDOWN
			player.item = ""

func _use_spell(index: int) -> void:
	if players.is_empty() or players[index].item == "": return
	var player := players[index]
	match player.item:
		"cloak", "boots", "magnet", "ring": return
		"frost":
			for j in range(players.size()):
				if j != index and player.pos.distance_to(players[j].pos) <= 180.0:
					if players[j].item == "cloak": players[j].item = ""
					else: players[j].stun = 1.5
		"sheep":
			var leader := _leader_index()
			if leader != index:
				if players[leader].item == "cloak": players[leader].item = ""
				else:
					players[leader].item = "sheep"
					players[leader].item_time = 3.0
					players[leader].sheep += 1
		"pin":
			var target := -1
			var best := INF
			for j in range(players.size()):
				if j != index and player.pos.distance_squared_to(players[j].pos) < best:
					best = player.pos.distance_squared_to(players[j].pos)
					target = j
			if target >= 0 and best < 900.0 * 900.0:
				players[target].pos = player.pos.move_toward(players[target].pos, 60.0)
				players[target].dash_left = GameConfig.DASH_DURATION
	player.item = ""
	Sfx.play_tone(720.0, 0.2)

func _update_hud() -> void:
	if not is_instance_valid(hud_root): return
	var time_label := hud_root.get_node_or_null("Timer") as Label
	if time_label:
		var seconds := maxi(0, ceili(remaining))
		time_label.text = ("3 · 2 · 1" if state == "countdown" else "%d:%02d" % [seconds / 60, seconds % 60])
		time_label.add_theme_color_override("font_color", GameConfig.GOLD if remaining <= 15.0 and mode == "voodoo" else Color.WHITE)
	var leader := _leader_index() if not players.is_empty() else -1
	for slot in range(score_name_labels.size()):
		var active := slot < players.size()
		for control in [score_name_labels[slot], score_tag_labels[slot], score_number_labels[slot], score_portraits[slot]]:
			control.visible = active
		score_crowns[slot].visible = active and slot == leader
		if not active: continue
		var player: Dictionary = players[slot]
		score_name_labels[slot].text = String(player.name)
		score_name_labels[slot].add_theme_color_override("font_color", player.color)
		score_tag_labels[slot].text = "%s%d · %s%s" % [I18n.t("player"), slot + 1, (I18n.t("you") + " · ") if slot == 0 else "", player.shape]
		score_tag_labels[slot].add_theme_color_override("font_color", player.color)
		var portrait_path := "res://assets/ui/retrato_%s_%s.png" % [player.character, player.sprite_color]
		var portrait_texture: Texture2D = load(portrait_path)
		if portrait_texture != null: score_portraits[slot].texture = portrait_texture
		var value := int(player.score)
		if score_values[slot] != value:
			score_values[slot] = value
			score_change_times[slot] = Time.get_ticks_msec()
		var age := Time.get_ticks_msec() - score_change_times[slot]
		var pop := 1.0 + (0.24 * (1.0 - float(age) / 170.0) if age < 170 and not Settings.reduce_motion else 0.0)
		score_number_labels[slot].scale = Vector2.ONE * pop
		score_number_labels[slot].pivot_offset = score_number_labels[slot].size * 0.5
		score_number_labels[slot].text = str(value)
		score_number_labels[slot].add_theme_color_override("font_color", GameConfig.GOLD if age < 170 else Color.WHITE)
	var spell_icon := hud_root.get_node_or_null("SpellIcon") as TextureRect
	var spell_name := hud_root.get_node_or_null("SpellName") as Label
	if spell_icon and not players.is_empty():
		var spell_index := ITEMS.find(String(players[0].item))
		spell_icon.visible = spell_index >= 0
		spell_icon.texture = spell_atlases[spell_index] if spell_index >= 0 else null
	if spell_name and not players.is_empty():
		spell_name.text = String(players[0].item).to_upper() if not String(players[0].item).is_empty() else I18n.t("spell")

func _build_menu() -> void:
	_clear_hud()
	_end_match_cleanup()
	state = "menu"
	var root := _new_overlay()
	var background := TextureRect.new()
	background.texture = load("res://assets/ui/menu_fondo.png")
	background.size = Vector2(1280, 720)
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(background)
	root.move_child(background, 0)
	var logo := TextureRect.new()
	logo.name = "MenuLogo"
	logo.texture = load("res://assets/ui/logo.png")
	logo.position = Vector2(360, 14)
	logo.size = Vector2(560, 253)
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(logo)
	if not Settings.reduce_motion:
		logo.position.y = -230
		var logo_tween := create_tween()
		logo_tween.tween_property(logo, "position:y", 14.0, 0.5).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		logo_tween.tween_property(logo, "position:y", 18.0, 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		logo_tween.set_loops()
	var labels := [I18n.t("play"), I18n.t("classic_mode"), I18n.t("characters"), I18n.t("settings"), I18n.t("history"), I18n.t("exit")]
	var actions: Array[Callable] = [func(): _begin_match(false), func(): _begin_match(true), _build_characters, _build_settings, _build_history, func(): get_tree().quit()]
	for index in range(labels.size()):
		var button := _button(root, labels[index], Vector2(0, 302 + index * 59), actions[index])
		if not Settings.reduce_motion:
			button.modulate.a = 0.0
			var tween := create_tween()
			tween.tween_interval(index * 0.05)
			tween.tween_property(button, "modulate:a", 1.0, 0.2)
	_label(root, "Nivel %d · %d XP" % [Profile.level() + 1, Profile.xp], Vector2(-222, 666), 16, Color("b8a9d1"), false)
	_label(root, "WASD mover · Espacio dash · E hechizo · Esc atrás", Vector2(210, 666), 16, Color("b8a9d1"), false)

func _build_characters() -> void:
	_clear_hud()
	var root := _new_overlay()
	_label(root, I18n.t("characters"), Vector2(0, 65), 42, GameConfig.GOLD, true)
	if not ["mago", "trol", "gnomo", "nigro"].has(Profile.character): Profile.character = "mago"
	character_preview_id = Profile.character
	character_preview = TextureRect.new()
	character_preview.name = "CharacterPreview"
	character_preview.position = Vector2(490, 145)
	character_preview.size = Vector2(300, 300)
	character_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	character_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	root.add_child(character_preview)
	_update_character_preview()
	var display: Dictionary = character_metadata.get("characters", {}).get(character_preview_id, {})
	_label(root, String(display.get("name", character_preview_id.to_upper())), Vector2(0, 420), 34, Color("fff6c2"), true)
	_label(root, String(display.get("role", "")), Vector2(0, 465), 20, Color("b8a9d1"), false)
	var previous_button := _button(root, "◀", Vector2(-210, 265), func(): _cycle_character(-1))
	previous_button.position = Vector2(350, 265)
	previous_button.size = Vector2(64, 54)
	var next_button := _button(root, "▶", Vector2(210, 265), func(): _cycle_character(1))
	next_button.position = Vector2(866, 265)
	next_button.size = Vector2(64, 54)
	_button(root, I18n.t("menu"), Vector2(0, 565), _build_menu)
	character_idle = 0.0

func _cycle_character(direction: int) -> void:
	var keys := ["mago", "trol", "gnomo", "nigro"]
	var index := keys.find(character_preview_id)
	character_preview_id = keys[posmod(index + direction, keys.size())]
	Profile.character = character_preview_id
	Profile.save()
	_build_characters()

func _update_character_preview() -> void:
	if not is_instance_valid(character_preview): return
	var sheet: Texture2D = load("res://assets/characters/%s_coral.png" % character_preview_id)
	if sheet == null: return
	var idle: Dictionary = character_metadata.get("animations", {}).get("idle", {"frames": 6, "fps": 6})
	var width := int(character_metadata.get("frame_w", 224))
	var height := int(character_metadata.get("frame_h", 256))
	var frame := int(character_idle * float(idle.get("fps", 6))) % int(idle.get("frames", 6))
	var atlas := AtlasTexture.new()
	atlas.atlas = sheet
	atlas.region = Rect2(frame * width, int(idle.get("row", 0)) * height, width, height)
	character_preview.texture = atlas

func _build_history() -> void:
	_clear_hud()
	var root := _new_overlay()
	_label(root, "HISTORIAL", Vector2(0, 95), 42, GameConfig.GOLD, true)
	var dir := DirAccess.open("user://matches")
	var y := 170.0
	if dir:
		var files := dir.get_files()
		files.sort()
		files.reverse()
		for filename in files.slice(0, mini(7, files.size())):
			var file := FileAccess.open("user://matches/" + filename, FileAccess.READ)
			if not file: continue
			var data: Variant = JSON.parse_string(file.get_as_text())
			if data is Dictionary:
				_label(root, "%s · %s · %s" % [data.get("date", ""), data.get("mode", ""), data.get("winner", "")], Vector2(0, y), 18, Color.WHITE, false)
				y += 43.0
	if y == 170.0:
		_label(root, "Aún no hay partidas guardadas", Vector2(0, 210), 20, Color("b8a9d1"), false)
	_button(root, I18n.t("menu"), Vector2(0, 590), _build_menu)

func _build_settings() -> void:
	_clear_hud()
	var root := _new_overlay()
	_label(root, I18n.t("settings"), Vector2(0, 130), 44, GameConfig.GOLD, true)
	_button(root, "Reducir movimiento: %s" % ("Sí" if Settings.reduce_motion else "No"), Vector2(0, 235), func():
		Settings.reduce_motion = not Settings.reduce_motion
		Settings.save()
		_build_settings())
	_button(root, "Escala UI: %d%%" % int(Settings.ui_scale * 100.0), Vector2(0, 300), func():
		Settings.ui_scale = 1.0 if Settings.ui_scale >= 1.5 else Settings.ui_scale + 0.25
		Settings.save()
		_build_settings())
	_button(root, "Idioma: %s" % I18n.language, Vector2(0, 365), func():
		I18n.set_language("ca" if I18n.language == "es" else ("en" if I18n.language == "ca" else "es"))
		Settings.save()
		_build_settings())
	_button(root, I18n.t("menu"), Vector2(0, 440), _build_menu)

func _build_pause() -> void:
	_clear_hud()
	var root := _new_overlay()
	_label(root, "PAUSA", Vector2(0, 190), 48, GameConfig.GOLD, true)
	_button(root, "Continuar", Vector2(0, 275), func(): state = "playing"; _build_hud())
	_button(root, I18n.t("menu"), Vector2(0, 345), _build_menu)

func _build_hud() -> void:
	_clear_hud()
	var root := _new_overlay()
	if state == "menu": return
	score_name_labels.clear()
	score_tag_labels.clear()
	score_number_labels.clear()
	score_portraits.clear()
	score_crowns.clear()
	score_values.clear()
	score_change_times.clear()
	var card_x := [8.0, 294.0, 706.0, 992.0]
	for slot in range(4):
		var card := NinePatchRect.new()
		card.texture = load("res://assets/ui/panel.png")
		card.patch_margin_left = 24
		card.patch_margin_top = 24
		card.patch_margin_right = 24
		card.patch_margin_bottom = 24
		card.position = Vector2(card_x[slot], 8)
		card.size = Vector2(280, 54)
		root.add_child(card)
		var portrait := TextureRect.new()
		portrait.position = Vector2(card_x[slot] + 6, 13)
		portrait.size = Vector2(44, 44)
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait.texture = load("res://assets/ui/retrato_mago_coral.png")
		root.add_child(portrait)
		var crown := TextureRect.new()
		crown.position = Vector2(card_x[slot] + 11, 3)
		crown.size = Vector2(34, 20)
		crown.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		crown.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		crown.texture = load("res://assets/characters/crown.png")
		crown.visible = false
		root.add_child(crown)
		var name_label := _hud_label(root, Vector2(card_x[slot] + 58, 9), Vector2(154, 25), 18, HORIZONTAL_ALIGNMENT_LEFT)
		var tag_label := _hud_label(root, Vector2(card_x[slot] + 58, 31), Vector2(158, 22), 13, HORIZONTAL_ALIGNMENT_LEFT)
		tag_label.add_theme_color_override("font_color", Color("b8a9d1"))
		var number := _hud_label(root, Vector2(card_x[slot] + 216, 6), Vector2(58, 48), 32, HORIZONTAL_ALIGNMENT_RIGHT)
		score_name_labels.append(name_label)
		score_tag_labels.append(tag_label)
		score_number_labels.append(number)
		score_portraits.append(portrait)
		score_crowns.append(crown)
		score_values.append(-1)
		score_change_times.append(0)
	var timer := Label.new()
	timer.name = "Timer"
	timer.position = Vector2(574, 2)
	timer.size = Vector2(132, 58)
	timer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timer.add_theme_font_size_override("font_size", roundi(44 * Settings.ui_scale))
	var clock_font := load("res://assets/fonts/LilitaOne-Regular.woff2") as Font
	if clock_font != null: timer.add_theme_font_override("font", clock_font)
	timer.add_theme_color_override("font_color", GameConfig.GOLD)
	root.add_child(timer)
	var slot_texture := TextureRect.new()
	slot_texture.texture = load("res://assets/ui/ranura.png")
	slot_texture.position = Vector2(12, 626)
	slot_texture.size = Vector2(80, 80)
	slot_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	slot_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	root.add_child(slot_texture)
	var spell_icon := TextureRect.new()
	spell_icon.name = "SpellIcon"
	spell_icon.position = Vector2(28, 642)
	spell_icon.size = Vector2(48, 48)
	spell_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	spell_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	spell_icon.visible = false
	root.add_child(spell_icon)
	var spell_key := _hud_label(root, Vector2(65, 675), Vector2(34, 26), 18, HORIZONTAL_ALIGNMENT_CENTER)
	spell_key.text = "E"
	var spell_name := _hud_label(root, Vector2(99, 651), Vector2(170, 30), 17, HORIZONTAL_ALIGNMENT_LEFT)
	spell_name.name = "SpellName"
	var pause := Button.new()
	pause.text = "Ⅱ"
	pause.position = Vector2(1200, 648)
	pause.size = Vector2(48, 44)
	pause.pressed.connect(func(): state = "paused"; _build_pause())
	root.add_child(pause)
	_update_hud()

func _hud_label(root: Control, position: Vector2, label_size: Vector2, font_size: int, alignment: HorizontalAlignment) -> Label:
	var label := Label.new()
	label.position = position
	label.size = label_size
	label.horizontal_alignment = alignment
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", roundi(font_size * Settings.ui_scale))
	var font_path := "res://assets/fonts/LilitaOne-Regular.woff2" if font_size >= 30 else "res://assets/fonts/Baloo2-Regular.woff2"
	var hud_font := load(font_path) as Font
	if hud_font != null: label.add_theme_font_override("font", hud_font)
	root.add_child(label)
	return label

func _finish_match() -> void:
	if state in ["match_end", "results"]: return
	results_ranking = MatchRanking.rank(players)
	var place := 1
	for i in range(results_ranking.size()):
		if results_ranking[i].name == Profile.nick: place = i + 1
	results_xp = Profile.award_match(place, players[0].max_combo)
	results_awards = MatchRanking.awards(players)
	var directory := "user://matches"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	var public_players: Array[Dictionary] = []
	for player in results_ranking:
		public_players.append({"name": player.name, "score": player.score, "shape": player.shape})
	var record := {"date": Time.get_datetime_string_from_system(), "mode": mode, "winner": results_ranking[0].name, "ranking": public_players, "awards": results_awards}
	var file := FileAccess.open("%s/%s.json" % [directory, Time.get_datetime_string_from_system().replace(":", "-")], FileAccess.WRITE)
	if file: file.store_string(JSON.stringify(record, "\t"))
	HttpEndpoint.add_result(record)
	_clear_hud()
	_end_match_cleanup()
	state = "match_end"
	end_wait = 1.0
	var root := _new_overlay()
	_label(root, I18n.t("time_up"), Vector2(0, 285), 64, GameConfig.GOLD, true)

func _show_results() -> void:
	_clear_hud()
	state = "results"
	results_elapsed = 0.0
	var root := _new_overlay()
	root.add_child(_screen_backdrop())
	_label(root, "%s  %s" % [I18n.t("winner"), String(results_ranking[0].get("name", ""))], Vector2(0, 36), 42, GameConfig.GOLD, true)
	for index in range(results_ranking.size()):
		var player: Dictionary = results_ranking[index]
		var pedestal := ColorRect.new()
		var pedestal_height: int = [58, 44, 34, 28][index]
		pedestal.position = Vector2(408 + index * 150, 315 - pedestal_height)
		pedestal.size = Vector2(94, pedestal_height)
		pedestal.color = player.color.darkened(0.35)
		pedestal.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(pedestal)
		var portrait := TextureRect.new()
		portrait.position = Vector2(420 + index * 150, 130)
		portrait.size = Vector2(70, 70)
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait.texture = load("res://assets/ui/retrato_%s_%s.png" % [player.get("character", "mago"), player.get("sprite_color", "coral")])
		root.add_child(portrait)
		_label(root, "%d · %s" % [index + 1, player.name], Vector2(-185 + index * 150, 204), 19, player.color, false)
		_label(root, str(player.score), Vector2(-185 + index * 150, 232), 26, Color.WHITE, true)
	var award_lines := PackedStringArray()
	for award_name in results_awards:
		award_lines.append("%s: %s" % [award_name, results_awards[award_name]])
	_label(root, "  ·  ".join(award_lines), Vector2(0, 328), 16, Color("b8a9d1"), false)
	_label(root, "+%d XP   ·   Nivel %d" % [results_xp, Profile.level() + 1], Vector2(0, 386), 22, Color.WHITE, false)
	_button(root, I18n.t("main_menu"), Vector2(0, 455), _build_menu)
	_button(root, I18n.t("again"), Vector2(0, 519), func(): _begin_match(mode == "classic"))

func _end_match_cleanup() -> void:
	players.clear()
	coins.clear()
	chests.clear()
	opened_chests.clear()
	hazard_runtime.clear()
	obstacle_rects.clear()
	floating.clear()
	arena.clear()
	arena_background = null
	roll_time = 0.0
	roll_player = -1
	roll_result = ""
	elapsed = 0.0
	remaining = 90.0
	countdown = 0.0
	end_wait = 0.0
	bots_dash_global_left = 0.0
	score_name_labels.clear()
	score_tag_labels.clear()
	score_number_labels.clear()
	score_portraits.clear()
	score_crowns.clear()
	score_values.clear()
	score_change_times.clear()
	queue_redraw()

func _screen_backdrop() -> ColorRect:
	var backdrop := ColorRect.new()
	backdrop.color = GameConfig.BACKGROUND
	backdrop.size = Vector2(1280, 720)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return backdrop

func _draw() -> void:
	if state in ["menu", "results", "match_end"]:
		draw_rect(Rect2(Vector2.ZERO, Vector2(1280, 720)), GameConfig.BACKGROUND)
		return
	draw_rect(Rect2(Vector2.ZERO, Vector2(1280, 720)), GameConfig.BACKGROUND)
	draw_set_transform(OFFSET)
	if arena_background != null:
		draw_texture_rect(arena_background, Rect2(-40.0, -40.0, 1280.0, 680.0), false)
	else:
		draw_rect(Rect2(Vector2.ZERO, GameConfig.ARENA_SIZE), Color("2b3a2a"))
	_draw_arena_hazards()
	for coin in coins:
		var pos: Vector2 = coin.pos
		var phase := float(coin.get("phase", 0.0))
		draw_texture_rect(COIN_SHADOW_TEXTURE, Rect2(pos + Vector2(-16.0, 5.0), Vector2(32.0, 12.0)), false)
		var coin_bounce := GameConfig.COIN_BOB_PIXELS * absf(sin(elapsed * GameConfig.COIN_BOB_SPEED + phase))
		var coin_meta: Dictionary = item_metadata.get("doblon", {})
		var coin_size := Vector2(int(coin_meta.get("frame_w", 64)), int(coin_meta.get("frame_h", 64)))
		_draw_strip_frame(COIN_TEXTURE, coin_size, floori(elapsed * float(coin_meta.get("fps", 10.0)) + phase), pos - Vector2(0.0, coin_bounce), float(coin_meta.get("scale", 0.5)), int(coin_meta.get("frames", 8)))
	for chest in chests:
		var chest_meta: Dictionary = item_metadata.get("cofre", {})
		var chest_size := Vector2(int(chest_meta.get("frame_w", 224)), int(chest_meta.get("frame_h", 256)))
		var chest_bounce := GameConfig.CHEST_BOB_PIXELS * sin(elapsed * GameConfig.CHEST_BOB_SPEED)
		_draw_strip_frame(CHEST_TEXTURE, chest_size, 0, chest - Vector2(0.0, chest_bounce), float(chest_meta.get("scale", 0.5)), int(chest_meta.get("frames", 6)))
	for chest in opened_chests:
		var opened_meta: Dictionary = item_metadata.get("cofre", {})
		var opened_size := Vector2(int(opened_meta.get("frame_w", 224)), int(opened_meta.get("frame_h", 256)))
		var progress: float = clampf(float(chest.elapsed) / GameConfig.CHEST_OPEN_SECONDS, 0.0, 0.999)
		var opening_frame := 1 + mini(4, floori(progress * 5.0))
		_draw_strip_frame(CHEST_TEXTURE, opened_size, opening_frame, chest.pos, float(opened_meta.get("scale", 0.5)), int(opened_meta.get("frames", 6)))
	for i in range(players.size()):
		var player: Dictionary = players[i]
		if player.invuln > 0.0 and floori(float(Time.get_ticks_msec()) / 90.0) % 2 == 0: continue
		var pos: Vector2 = player.pos
		var anim_name := "hurt" if player.stun > 0.0 else ("dash" if player.dash_left > 0.0 else ("walk" if player.vel.length() > 10.0 else "idle"))
		var animation: Dictionary = character_metadata.get("animations", {}).get(anim_name, {"row": 0, "frames": 1, "fps": 1})
		var frame_width := int(character_metadata.get("frame_w", 224))
		var frame_height := int(character_metadata.get("frame_h", 256))
		var frame := posmod(floori(elapsed * float(animation.get("fps", 6))), int(animation.get("frames", 1)))
		var sheet: Texture2D = character_sheets.get("%s_%s" % [player.character, player.sprite_color])
		if sheet != null:
			var sprite_scale := 0.37
			var face_left: bool = player.dash_dir.x < -0.1 if player.dash_left > 0.0 else player.vel.x < -0.1
			draw_set_transform(OFFSET + pos, 0.0, Vector2(-sprite_scale if face_left else sprite_scale, sprite_scale))
			draw_texture_rect_region(sheet, Rect2(-112.0, -168.0, frame_width, frame_height), Rect2(frame * frame_width, int(animation.get("row", 0)) * frame_height, frame_width, frame_height))
			draw_set_transform(OFFSET)
		draw_string(ThemeDB.fallback_font, pos + Vector2(-8, 34), player.shape, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color.WHITE)
		if i == 0 and player.combo > 1:
			draw_string(ThemeDB.fallback_font, pos + Vector2(27, -16), "x%d · %d" % [Scoring.multiplier(player.combo, mode == "classic"), player.combo], HORIZONTAL_ALIGNMENT_LEFT, -1, 17, GameConfig.GOLD)
		if i == _leader_index() and mode == "voodoo":
			draw_string(ThemeDB.fallback_font, pos + Vector2(-8, -30), "👑", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, GameConfig.GOLD)
	if roll_time > 0.0 and roll_player >= 0 and roll_player < players.size():
		var spell_meta: Dictionary = item_metadata.get("hechizos", {})
		var spell_size := Vector2(int(spell_meta.get("frame_w", 128)), int(spell_meta.get("frame_h", 128)))
		var roll_frame := posmod(floori(elapsed * 20.0), ITEMS.size())
		_draw_strip_frame(SPELL_TEXTURE, spell_size, roll_frame, players[roll_player].pos + Vector2(0.0, -94.0), 0.5, ITEMS.size())
	for effect in floating:
		draw_string(ThemeDB.fallback_font, effect.pos, effect.text, HORIZONTAL_ALIGNMENT_CENTER, -1, 22, effect.color)
	if mode == "voodoo" and remaining <= 15.0:
		draw_rect(Rect2(Vector2.ZERO, GameConfig.ARENA_SIZE), Color(1.0, 0.72, 0.12, 0.035 + 0.025 * sin(elapsed * 8.0)), false, 7.0)
	if state == "countdown":
		draw_set_transform(Vector2.ZERO)
		var count_text := I18n.t("ready") if countdown < 1.0 else str(ceili(countdown))
		draw_string(ThemeDB.fallback_font, Vector2(570, 370), count_text, HORIZONTAL_ALIGNMENT_CENTER, 160, 68, Color.WHITE)
	else:
		draw_set_transform(Vector2.ZERO)

func _draw_strip_frame(texture: Texture2D, frame_size: Vector2, frame_index: int, center: Vector2, scale_factor: float, frame_count: int) -> void:
	if texture == null or frame_count <= 0:
		return
	var frame := posmod(frame_index, frame_count)
	var draw_size := frame_size * scale_factor
	draw_texture_rect_region(texture, Rect2(center - draw_size * 0.5, draw_size), Rect2(frame * frame_size.x, 0.0, frame_size.x, frame_size.y))

func _draw_arena_hazards() -> void:
	for hazard_index in range(arena.get("hazards", []).size()):
		var hazard: Dictionary = arena.hazards[hazard_index]
		var runtime: Dictionary = hazard_runtime[hazard_index]
		var kind := String(hazard.get("type", ""))
		if kind == "pinchos":
			var spike_state := HazardRules.spike_state(elapsed, float(hazard.get("phase", 0.0)), GameConfig.SPIKE_DOWN_SECONDS, GameConfig.SPIKE_WARN_SECONDS, GameConfig.SPIKE_UP_SECONDS)
			var frame := 0 if spike_state == "down" else (1 if spike_state == "warn" else 2)
			for tile in hazard.get("tiles", []):
				var parts: Variant = tile if tile is Array else String(tile).split(" ", false)
				if parts.size() >= 4:
					_draw_hazard_sprite("pinchos", Vector2(float(parts[0]) + float(parts[2]) * 0.5, float(parts[1]) + float(parts[3]) * 0.5), frame)
		elif kind == "cinta":
			for tile in hazard.get("tiles", []):
				var parts: Variant = tile if tile is Array else String(tile).split(" ", false)
				if parts.size() >= 4:
					_draw_hazard_sprite("cinta", Vector2(float(parts[0]) + float(parts[2]) * 0.5, float(parts[1]) + float(parts[3]) * 0.5), floori(elapsed * 8.0))
		elif kind == "portal":
			var portal_sprite := String(hazard.get("sprite", "portal_cian"))
			_draw_hazard_sprite(portal_sprite, _json_point(hazard.get("a", [])), floori(elapsed * 8.0))
			_draw_hazard_sprite(portal_sprite, _json_point(hazard.get("b", [])), floori(elapsed * 8.0))
		elif kind == "vapor":
			var center := _json_point(hazard.get("center", []))
			var steam_state := HazardRules.steam_state(elapsed, GameConfig.STEAM_PERIOD, GameConfig.STEAM_WARN_SECONDS, GameConfig.STEAM_BLAST_SECONDS)
			_draw_hazard_sprite("vapor_rejilla", center)
			if steam_state == "warn":
				_draw_hazard_sprite("vapor_aviso", center, floori(elapsed * 8.0))
			elif steam_state == "blast":
				_draw_hazard_sprite("vapor_chorro", center, floori(elapsed * 10.0))
		elif kind == "barril":
			if runtime.get("barrel_state", "idle") == "idle":
				_draw_hazard_sprite("barril", _json_point(hazard.get("center", [])))
			elif runtime.barrel_state == "fusing":
				_draw_hazard_sprite("barril_mecha", _json_point(hazard.get("center", [])), floori((GameConfig.BARREL_FUSE_SECONDS - float(runtime.barrel_timer)) * 5.0))
			elif runtime.barrel_state == "exploding":
				_draw_hazard_sprite("barril_explosion", _json_point(hazard.get("center", [])), floori((GameConfig.BARREL_EXPLOSION_SECONDS - float(runtime.barrel_timer)) * 12.0))
		elif kind == "rayo":
			var center := _json_point(hazard.get("center", []))
			_draw_ray_beams(center, elapsed * TAU / GameConfig.RAY_PERIOD)
			_draw_hazard_sprite("rayo_orbe", center, floori(elapsed * 5.0))
		elif kind == "raices" and String(runtime.get("roots_state", "idle")) != "idle":
			var sprite_id := "raices_aviso" if runtime.roots_state == "warn" else "raices_activas"
			_draw_hazard_sprite(sprite_id, runtime.roots_position, floori(elapsed * 8.0))
		elif kind == "fantasma":
			var position := _ghost_position(hazard)
			_draw_hazard_sprite("fantasma", position, floori(elapsed * 8.0))

func _draw_hazard_sprite(sprite_id: String, center: Vector2, frame_index: int = 0) -> void:
	var info: Dictionary = arena.get("sprites", {}).get(sprite_id, {})
	if info.is_empty():
		return
	if not hazard_sheets.has(sprite_id):
		hazard_sheets[sprite_id] = load("res://assets/arenas/" + String(info.file))
	var texture: Texture2D = hazard_sheets[sprite_id]
	if texture == null:
		return
	var frame_width := int(info.get("frame_w", 1))
	var frame_height := int(info.get("frame_h", 1))
	var frame_count := int(info.get("frames", 1))
	var frame := posmod(frame_index, frame_count)
	var scale_factor := float(info.get("scale", 0.5))
	var frame_size := Vector2(frame_width, frame_height) * scale_factor
	draw_texture_rect_region(texture, Rect2(center - frame_size * 0.5, frame_size), Rect2(frame * frame_width, 0, frame_width, frame_height))

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

func _draw_ray_beams(center: Vector2, angle: float) -> void:
	var info: Dictionary = arena.get("sprites", {}).get("rayo_haz", {})
	if info.is_empty():
		return
	if not hazard_sheets.has("rayo_haz"):
		hazard_sheets["rayo_haz"] = load("res://assets/arenas/" + String(info.file))
	var texture: Texture2D = hazard_sheets["rayo_haz"]
	if texture == null:
		return
	var width := int(info.get("frame_w", 584))
	var height := int(info.get("frame_h", 60))
	for arm in range(2):
		draw_set_transform(center, angle + float(arm) * PI, Vector2.ONE * float(info.get("scale", 0.5)))
		draw_texture_rect_region(texture, Rect2(6.0, -float(height) * 0.5, width, height), Rect2(0.0, 0.0, width, height))
	draw_set_transform(OFFSET)

func _new_overlay() -> Control:
	hud = CanvasLayer.new()
	hud.layer = 10
	add_child(hud)
	hud_root = Control.new()
	hud_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud_root.scale = Vector2.ONE
	hud_root.position = Vector2.ZERO
	hud_root.theme = ThemeBuilder.build()
	hud.add_child(hud_root)
	return hud_root

func _clear_hud() -> void:
	if is_instance_valid(hud): hud.queue_free()

func _label(root: Control, text: String, offset: Vector2, size: int, tint: Color, _bold: bool) -> Label:
	var label := Label.new()
	label.text = text
	label.position = Vector2(240, 0) + offset
	label.size = Vector2(800, 52)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", roundi(size * Settings.ui_scale))
	var label_font_path := "res://assets/fonts/LilitaOne-Regular.woff2" if _bold else "res://assets/fonts/Baloo2-Regular.woff2"
	var label_font := load(label_font_path) as Font
	if label_font != null: label.add_theme_font_override("font", label_font)
	label.add_theme_color_override("font_color", tint)
	label.add_theme_color_override("font_shadow_color", Color("160e22"))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 3)
	root.add_child(label)
	return label

func _button(root: Control, text: String, offset: Vector2, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.position = Vector2(470, 0) + offset
	button.size = Vector2(340, 54)
	button.add_theme_font_size_override("font_size", roundi(26 * Settings.ui_scale))
	var menu_font := load("res://assets/fonts/NewRocker-Regular.woff2") as Font
	if menu_font != null: button.add_theme_font_override("font", menu_font)
	button.focus_mode = Control.FOCUS_ALL
	button.pressed.connect(func(): Sfx.play_tone(300.0, 0.07); action.call())
	button.focus_entered.connect(func(): Sfx.play_tone(470.0, 0.045))
	root.add_child(button)
	if not root.has_meta("focus_set"):
		button.grab_focus()
		root.set_meta("focus_set", true)
	return button

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

func _separate_players() -> void:
	for first_index in range(players.size()):
		for second_index in range(first_index + 1, players.size()):
			var separated := ArenaPhysics.separate_pair(players[first_index].pos, players[second_index].pos, GameConfig.PLAYER_RADIUS, obstacle_rects)
			players[first_index].pos = separated[0]
			players[second_index].pos = separated[1]

func _spawn_coin() -> void:
	coins.append({"pos": _random_position(), "owner": -1, "lock": 0.0, "phase": rng.randf_range(0.0, TAU)})

func _leader_index() -> int:
	if players.is_empty(): return -1
	var best := 0
	for i in range(1, players.size()):
		if players[i].score > players[best].score: best = i
	return best

func _score_order() -> Array[int]:
	var indices: Array[int] = []
	for i in range(players.size()): indices.append(i)
	indices.sort_custom(func(a: int, b: int) -> bool: return players[a].score > players[b].score)
	return indices

func _on_floating_text(text: String, world_pos: Vector2, tint: Color) -> void:
	floating.append({"text": text, "pos": world_pos, "color": tint, "time": 0.8})

func _on_shake(amount: float) -> void:
	if not Settings.reduce_motion:
		position = Vector2(randf_range(-amount, amount), randf_range(-amount, amount))
		get_tree().create_timer(0.15).timeout.connect(func(): position = Vector2.ZERO)

func _animate_floating(delta: float) -> void:
	for i in range(floating.size() - 1, -1, -1):
		floating[i].time -= delta
		floating[i].pos.y -= 24.0 * delta
		if floating[i].time <= 0.0: floating.remove_at(i)

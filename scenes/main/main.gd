extends Node2D

const OFFSET := Vector2(40, 60)
const ITEMS := ["magnet", "boots", "cloak", "pin", "frost", "sheep", "ring"]
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
var players: Array[Dictionary] = []
var coins: Array[Dictionary] = []
var chests: Array[Vector2] = []
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

func _ready() -> void:
	get_window().title = "VoodooCombo 0.1"
	var metadata: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://assets/characters/characters.json"))
	if metadata is Dictionary:
		character_metadata = metadata
	Fx.floating_text.connect(_on_floating_text)
	Fx.shake.connect(_on_shake)
	_build_menu()

func _process(delta: float) -> void:
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
	elapsed += delta
	remaining = maxf(0.0, remaining - delta)
	if not frenzy_notified and mode == "voodoo" and remaining <= 15.0:
		frenzy_notified = true
		Fx.pop("¡FRENESÍ!", Vector2(640, 150), GameConfig.GOLD)
		Sfx.play_tone(520.0, 0.35)
	var coin_target := 30 if remaining <= GameConfig.FRENZY_SECONDS else GameConfig.COIN_RESPAWN_THRESHOLD
	if mode == "voodoo" and int(elapsed / GameConfig.COIN_RESPAWN_INTERVAL) != int((elapsed - delta) / GameConfig.COIN_RESPAWN_INTERVAL) and coins.size() < coin_target:
		_spawn_coin()
	for coin in coins:
		coin.lock = maxf(0.0, coin.lock - delta)
	var public_players: Array[Dictionary] = []
	for player in players:
		public_players.append({"name": player.name, "score": player.score, "combo": player.combo})
	HttpEndpoint.set_status({"mode": mode, "time": remaining, "players": public_players})
	if int(elapsed / 8.0) != int((elapsed - delta) / 8.0) and chests.size() < 2:
		chests.append(_random_position())
	_update_player(0, delta)
	for i in range(1, players.size()):
		_update_bot(i, delta)
	_separate_players()
	_update_pickups()
	_update_dash_hits()
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
	arena = ArenaGen.generate(seed_value, previous_arena_id)
	previous_arena_id = String(arena.get("map_id", ""))
	obstacle_rects = _get_obstacle_rects(arena.get("obstacles", []))
	arena_background = load("res://assets/arenas/" + String(arena.background)) if not String(arena.background).is_empty() else null
	players.clear()
	coins.clear()
	chests.clear()
	floating.clear()
	var names := [Profile.nick, "Mordisquitos", "Conde Costura", "Dama del Pantano"]
	var characters := ["mago", "trol", "gnomo", "nigro"]
	var sprite_colors := ["coral", "azul", "lima", "hueso"]
	for i in range(4):
		var sheet_key := "%s_%s" % [characters[i], sprite_colors[i]]
		if not character_sheets.has(sheet_key):
			character_sheets[sheet_key] = load("res://assets/characters/%s.png" % sheet_key)
		players.append({"name": names[i], "character": characters[i], "sprite_color": sprite_colors[i], "pos": arena.spawns[i], "vel": Vector2.ZERO, "color": GameConfig.COLORS[i], "shape": GameConfig.SHAPES[i], "coins": 0, "score": 0, "collected": 0, "combo": 0, "max_combo": 0, "last_pickup": -10.0, "dash_left": 0.0, "dash_cd": 0.0, "dash_dir": Vector2.RIGHT, "stun": 0.0, "invuln": 0.0, "item": "", "item_time": 0.0, "stolen": 0, "dashes": 0, "sheep": 0, "hits": 0, "is_bot": i > 0})
	for coin_pos in arena.coins:
		coins.append({"pos": coin_pos, "owner": -1, "lock": 0.0})
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
	var had_timed_item: bool = float(player.item_time) > 0.0
	player.item_time = maxf(0.0, player.item_time - delta)
	if had_timed_item and player.item_time == 0.0:
		player.item = ""
	if player.stun > 0.0:
		return
	if direction != Vector2.ZERO:
		player.dash_dir = direction
	var speed := GameConfig.PLAYER_SPEED * (1.6 if player.item == "boots" else 1.0)
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
	var had_timed_item: bool = float(player.item_time) > 0.0
	player.item_time = maxf(0.0, player.item_time - delta)
	if had_timed_item and player.item_time == 0.0: player.item = ""
	if player.stun > 0.0:
		return
	var coin_positions: Array[Vector2] = []
	for coin in coins: coin_positions.append(coin.pos)
	var opponents: Array[Vector2] = []
	for j in range(players.size()):
		if j != index: opponents.append(players[j].pos)
	var choice := BotBrain.choose_direction(player.pos, coin_positions, opponents, player.dash_cd <= 0.0, rng)
	var direction: Vector2 = choice.direction
	if choice.dash and direction != Vector2.ZERO and player.item != "sheep":
		player.dash_dir = direction
		player.dash_left = GameConfig.DASH_DURATION
		player.dash_cd = 0.5 if player.item == "boots" else GameConfig.DASH_COOLDOWN
	var speed_scale := 0.6 if player.item == "sheep" else (1.6 if player.item == "boots" else 1.0)
	var movement: Vector2 = player.dash_dir
	if player.dash_left <= 0.0:
		movement = direction
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
	if player.dash_cd > 0.0 or player.stun > 0.0 or player.item == "sheep": return
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
				value = Scoring.coin_value(player.combo, remaining <= 15.0, player.item == "ring", false)
				player.coins += value
				player.score = player.coins
				player.last_pickup = elapsed
				if player.combo in [5, 10, 20]:
					var text := "¡Combo!" if player.combo == 5 else ("¡Vudú!" if player.combo == 10 else "¡VOODOO COMBO!")
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
				_start_roll(i)
				chests.remove_at(chest_i)
				break
		if player.combo > 0 and elapsed - player.last_pickup > GameConfig.COMBO_WINDOW:
			player.combo = 0

func _update_dash_hits() -> void:
	for i in range(players.size()):
		if players[i].dash_left <= 0.0: continue
		for j in range(players.size()):
			if i == j or players[j].invuln > 0.0 or players[i].pos.distance_to(players[j].pos) > 38.0: continue
			if players[j].dash_left > 0.0:
				players[i].dash_left = 0.0
				players[j].dash_left = 0.0
				break
			var victim: Dictionary = players[j]
			if victim.item == "cloak":
				victim.item = ""
				players[i].dash_left = 0.0
				break
			var dropped := Scoring.dropped_coins(victim.coins, j == _leader_index(), victim.item == "ring")
			victim.coins -= dropped
			victim.score = victim.coins
			victim.stun = 0.4
			victim.invuln = 1.5
			victim.combo = 0
			victim.hits += 1
			players[i].dashes += 1
			players[i].stolen += dropped
			for d in range(dropped):
				var angle := TAU * float(d) / maxf(1.0, dropped)
				coins.append({"pos": victim.pos + Vector2.RIGHT.rotated(angle) * rng.randf_range(45.0, 110.0), "owner": j, "lock": 0.6})
			players[i].dash_left = 0.0
			Fx.hit()
			Fx.pop("-%d" % dropped, victim.pos + OFFSET, Color("ff7474"))
			Sfx.play_tone(140.0, 0.16)
			break

func _start_roll(index: int) -> void:
	roll_player = index
	var order := _score_order()
	var place := order.find(index)
	var player_position := "first" if place == 0 else ("last" if place == order.size() - 1 else "middle")
	roll_result = ItemTable.roll(player_position, rng, mode == "classic")
	roll_time = 0.8
	Sfx.play_tone(420.0, 0.12)

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
		time_label.text = str(ceil(remaining)) if state == "playing" else ("3 · 2 · 1" if state == "countdown" else "")
	var score_label := hud_root.get_node_or_null("Scores") as Label
	if score_label:
		var lines := PackedStringArray()
		for index in _score_order():
			var p: Dictionary = players[index]
			lines.append("%s %s  %d%s" % [p.shape, p.name, p.score, "  👑" if index == _leader_index() else ""])
		score_label.text = "     ".join(lines)
	var spell_label := hud_root.get_node_or_null("Spell") as Label
	if spell_label and not players.is_empty():
		spell_label.text = "E  ✦  %s" % (players[0].item.to_upper() if players[0].item != "" else "—")

func _build_menu() -> void:
	_clear_hud()
	state = "menu"
	var root := _new_overlay()
	_label(root, "VOODOO COMBO", Vector2(0, 95), 64, Color("ffd23f"), true)
	_label(root, I18n.t("how"), Vector2(0, 185), 20, Color("b8a9d1"), false)
	_button(root, I18n.t("play") + " · " + I18n.t("voodoo"), Vector2(0, 240), func(): _begin_match(false))
	_button(root, I18n.t("classic"), Vector2(0, 295), func(): _begin_match(true))
	_button(root, I18n.t("settings"), Vector2(0, 350), _build_settings)
	_button(root, "PERSONALIZAR", Vector2(0, 405), _build_customize)
	_button(root, "HISTORIAL", Vector2(0, 460), _build_history)
	_label(root, "WASD / Flechas · Espacio / A dash · E / B hechizo · Esc pausa", Vector2(0, 535), 18, Color("ffffff"), false)
	_label(root, "Nivel %d   ·   %d XP   ·   %d partidas" % [Profile.level() + 1, Profile.xp, Profile.games], Vector2(0, 580), 18, Color("b8a9d1"), false)

func _build_customize() -> void:
	_clear_hud()
	var root := _new_overlay()
	_label(root, "PERSONALIZAR", Vector2(0, 115), 42, GameConfig.GOLD, true)
	var hats := ["none", "witch", "crown"]
	_button(root, "Sombrero: %s" % Profile.cosmetics.hat, Vector2(0, 210), func():
		Profile.cosmetics.hat = hats[(hats.find(Profile.cosmetics.hat) + 1) % hats.size()]
		Profile.save()
		_build_customize())
	var eyes := ["button", "star", "sleepy"]
	_button(root, "Ojos: %s" % Profile.cosmetics.eyes, Vector2(0, 275), func():
		Profile.cosmetics.eyes = eyes[(eyes.find(Profile.cosmetics.eyes) + 1) % eyes.size()]
		Profile.save()
		_build_customize())
	var trails := ["none", "gold", "frost"]
	_button(root, "Estela: %s" % Profile.cosmetics.trail, Vector2(0, 340), func():
		Profile.cosmetics.trail = trails[(trails.find(Profile.cosmetics.trail) + 1) % trails.size()]
		Profile.save()
		_build_customize())
	_button(root, I18n.t("menu"), Vector2(0, 425), _build_menu)

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
	var score := Label.new()
	score.name = "Scores"
	score.position = Vector2(24, 10)
	score.size = Vector2(1232, 44)
	score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score.add_theme_font_size_override("font_size", 19)
	root.add_child(score)
	var timer := Label.new()
	timer.name = "Timer"
	timer.position = Vector2(535, 48)
	timer.size = Vector2(210, 56)
	timer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timer.add_theme_font_size_override("font_size", 38)
	timer.add_theme_color_override("font_color", GameConfig.GOLD)
	root.add_child(timer)
	var spell := Label.new()
	spell.name = "Spell"
	spell.position = Vector2(28, 650)
	spell.size = Vector2(300, 42)
	spell.add_theme_font_size_override("font_size", 21)
	root.add_child(spell)
	var pause := Button.new()
	pause.text = "Ⅱ"
	pause.position = Vector2(1200, 648)
	pause.size = Vector2(48, 44)
	pause.pressed.connect(func(): state = "paused"; _build_pause())
	root.add_child(pause)
	_update_hud()

func _finish_match() -> void:
	if state == "results": return
	state = "results"
	var ranked := MatchRanking.rank(players)
	var place := 1
	for i in range(ranked.size()):
		if ranked[i].name == Profile.nick: place = i + 1
	var gained := Profile.award_match(place, players[0].max_combo)
	var directory := "user://matches"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	var public_players: Array[Dictionary] = []
	for player in ranked:
		public_players.append({"name": player.name, "score": player.score, "shape": player.shape})
	var record := {"date": Time.get_datetime_string_from_system(), "mode": mode, "winner": ranked[0].name, "ranking": public_players, "awards": MatchRanking.awards(players)}
	var file := FileAccess.open("%s/%s.json" % [directory, Time.get_datetime_string_from_system().replace(":", "-")], FileAccess.WRITE)
	if file: file.store_string(JSON.stringify(record, "\t"))
	HttpEndpoint.add_result(record)
	_clear_hud()
	var root := _new_overlay()
	_label(root, "%s  %s" % [I18n.t("winner"), ranked[0].name], Vector2(0, 105), 46, GameConfig.GOLD, true)
	for i in range(ranked.size()):
		_label(root, "%d  %s %s   %d" % [i + 1, ranked[i].shape, ranked[i].name, ranked[i].score], Vector2(0, 190 + i * 43), 24, ranked[i].color, false)
	_label(root, "+%d XP   ·   Nivel %d" % [gained, Profile.level() + 1], Vector2(0, 380), 22, Color.WHITE, false)
	_button(root, I18n.t("again"), Vector2(0, 445), func(): _begin_match(mode == "classic"))
	_button(root, I18n.t("menu"), Vector2(0, 510), _build_menu)

func _draw() -> void:
	if state == "menu":
		draw_rect(Rect2(Vector2.ZERO, Vector2(1280, 720)), GameConfig.BACKGROUND)
		for i in range(18):
			var x := float((i * 83 + 27) % 1280)
			var y := float((i * 131 + 65) % 720)
			draw_circle(Vector2(x, y), 3.0 + float(i % 4), Color(0.42, 0.28, 0.52, 0.28))
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
		draw_circle(pos + Vector2(2, 4), 10.0, Color(0, 0, 0, 0.35))
		draw_circle(pos, 10.0, GameConfig.GOLD)
		draw_circle(pos, 5.0, Color("fff6c2"))
	for chest in chests:
		draw_rect(Rect2(chest - Vector2(13, 10), Vector2(26, 20)), Color("94652e"), true, 3.0)
		draw_circle(chest, 3.0, GameConfig.GOLD)
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

func _draw_arena_hazards() -> void:
	for hazard in arena.get("hazards", []):
		var kind := String(hazard.get("type", ""))
		if kind == "pinchos":
			var cycle := fposmod(elapsed + float(hazard.get("phase", 0.0)), 3.6)
			var frame := 0 if cycle < 2.0 else (1 if cycle < 2.6 else 2)
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
			var cycle := fposmod(elapsed, 4.0)
			_draw_hazard_sprite("vapor_rejilla", center)
			if cycle > 3.4:
				_draw_hazard_sprite("vapor_aviso", center, floori(elapsed * 8.0))
			elif cycle < 0.5:
				_draw_hazard_sprite("vapor_chorro", center, floori(elapsed * 10.0))
		elif kind == "barril":
			_draw_hazard_sprite("barril", _json_point(hazard.get("center", [])))
		elif kind == "rayo":
			_draw_hazard_sprite("rayo_orbe", _json_point(hazard.get("center", [])), floori(elapsed * 5.0))
		elif kind == "fantasma":
			var path: Array = hazard.get("path", [])
			if not path.is_empty():
				var points: Array[Vector2] = []
				for point in path:
					var parts: Variant = point if point is Array else String(point).split(" ", false)
					if parts.size() >= 2:
						points.append(Vector2(float(parts[0]), float(parts[1])))
				if not points.is_empty():
					_draw_hazard_sprite("fantasma", points[posmod(floori(elapsed * 0.5), points.size())], floori(elapsed * 8.0))

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

func _new_overlay() -> Control:
	hud = CanvasLayer.new()
	add_child(hud)
	hud_root = Control.new()
	hud_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud_root.scale = Vector2.ONE * Settings.ui_scale
	hud_root.position = Vector2((1280.0 - 1280.0 * Settings.ui_scale) * 0.5, (720.0 - 720.0 * Settings.ui_scale) * 0.5)
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
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", tint)
	label.add_theme_color_override("font_shadow_color", Color("160e22"))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 3)
	root.add_child(label)
	return label

func _button(root: Control, text: String, offset: Vector2, action: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.position = Vector2(450, 0) + offset
	button.size = Vector2(380, 54)
	button.add_theme_font_size_override("font_size", 22)
	button.focus_mode = Control.FOCUS_ALL
	button.pressed.connect(action)
	root.add_child(button)
	if not root.has_meta("focus_set"):
		button.grab_focus()
		root.set_meta("focus_set", true)

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
	coins.append({"pos": _random_position(), "owner": -1, "lock": 0.0})

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

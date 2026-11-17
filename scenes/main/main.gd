extends Node2D

const OFFSET := Vector2(40, 60)
const ITEMS := ["magnet", "boots", "cloak", "pin", "frost", "sheep", "ring"]
const COIN_TEXTURE := preload("res://assets/items/doblon.png")
const COIN_SHADOW_TEXTURE := preload("res://assets/items/doblon_sombra.png")
const CHEST_TEXTURE := preload("res://assets/items/cofre.png")
const SPELL_TEXTURE := preload("res://assets/items/hechizos.png")
const SPELL_SLOT_TEXTURE := preload("res://assets/ui/hechizo_ranura.png")
const SPELL_GLOW_TEXTURE := preload("res://assets/ui/hechizo_brillo.png")
const SPELL_KEY_E_TEXTURE := preload("res://assets/ui/tecla_e.png")
const SPELL_KEY_B_TEXTURE := preload("res://assets/ui/tecla_b.png")
const TRAP_ICONS_TEXTURE := preload("res://assets/ui/trampas_iconos.png")
const SAFE_ZONE_FOG_TEXTURE := preload("res://assets/ui/zona_niebla.png")
const SAFE_ZONE_FOG_SHADER := preload("res://assets/ui/safe_zone_fog.gdshader")
const BIOME_COLORS := [[Color("2b3a2a"), Color("243223")], [Color("33402a"), Color("2b3723")], [Color("2a3a4a"), Color("233241")], [Color("3a2a2a"), Color("322323")]]

var simulation: MatchSim
var simulation_accumulator := 0.0
var pending_dash := false
var pending_spell := false
var state := "menu"
var mode := "voodoo"
var elapsed := 0.0
var remaining := 90.0
var countdown := 0.0
var seed_value := 0
var arena: Dictionary = {}
var previous_arena_id := ""
var selected_arena_id := ""
var arena_select_classic := false
var safe_zone_step := 0
var safe_zone_warning_step := 0
var fog_material: ShaderMaterial
var chest_fade_alpha: Array[float] = []
var obstacle_rects: Array[Rect2] = []
var player_hitbox_rects: Array[Rect2] = []
var hazard_runtime: Array[Dictionary] = []
var players: Array[Dictionary] = []
var coins: Array[Dictionary] = []
var chests: Array[Vector2] = []
var opened_chests: Array[Dictionary] = []
var rng := RandomNumberGenerator.new()
var hud: CanvasLayer
var hud_root: Control
var floating: Array[Dictionary] = []
var dash_trails: Array[Dictionary] = []
var dash_trail_emit := 0.0
var roll_time := 0.0
var roll_player := -1
var roll_result := ""
var frenzy_notified := false
var arena_background: Texture2D
var character_metadata: Dictionary = {}
var loading_metadata: Dictionary = {}
var character_sheets: Dictionary = {}
var hazard_sheets: Dictionary = {}
var item_metadata: Dictionary = {}
var spell_atlases: Array[AtlasTexture] = []
var score_name_labels: Array[Label] = []
var score_tag_labels: Array[Label] = []
var score_number_labels: Array[Label] = []
var score_portraits: Array[TextureRect] = []
var score_frames: Array[TextureRect] = []
var score_frame_skulls: Array[Label] = []
var score_crowns: Array[TextureRect] = []
var score_values: Array[int] = []
var score_change_times: Array[int] = []
var bots_dash_global_left := 0.0
var end_wait := 0.0
var results_elapsed := 0.0
var results_ranking: Array[Dictionary] = []
var results_awards: Dictionary = {}
var results_xp := 0
var results_characters: Array[TextureRect] = []
var results_bubbles: Array[Dictionary] = []
var results_emote_cooldown := 0.0
var result_bot_emote_at: Array[float] = []
var character_preview: TextureRect
var character_preview_id := "mago"
var character_idle := 0.0
var locker_tab := "character"
var spell_notice_time := 0.0
var spell_notice_item := ""
var last_input_controller := false
var loading_elapsed := 0.0
var loading_tip_index := -1
var nick_line_edit: LineEdit
var nick_error_label: Label
var nick_dialog_returns_to_characters := false
var player_name_font: Font
var floating_coin_font: Font
var floating_notice_font: Font
var menu_logo_tween: Tween
var lobby_return := false
var network_match := false
var local_player := 0
var client_match: ClientMatch
var ping_ms := 0
var ping_clock := 0.0

func _build_online() -> void:
	_clear_hud()
	state = "online"
	var root := _new_overlay()
	var lobby := OnlineLobby.new()
	root.add_child(lobby)
	lobby.exit_requested.connect(_build_menu)
	lobby.online_match_requested.connect(_begin_online_match)
	lobby.locker_requested.connect(func(): lobby_return = true; _build_characters())
	lobby.local_match_requested.connect(func(config: Dictionary): _begin_match(config.mode == "classic", str(config.arena_id), config))

func _locker_back() -> void:
	if lobby_return:
		lobby_return = false
		if not Net.room.is_empty(): Net.lobby_action.rpc_id(1, "cosmetics", {"character": Profile.character, "cosmetics": Profile.cosmetics})
		_build_online()
	else: _build_menu()

func _begin_online_match(room: Dictionary) -> void:
	if network_match and state in ["loading", "countdown", "playing", "paused"]: return
	network_match = true
	simulation = null
	client_match = ClientMatch.new()
	client_match.setup(room.initial, multiplayer.get_unique_id())
	local_player = client_match.player_index
	_read_state(room.initial)
	_load_match_art()
	_build_loading()

func _load_match_art() -> void:
	arena_background = load("res://assets/arenas/" + str(arena.background)) if not str(arena.background).is_empty() else null
	for player in players:
		var key := "%s_%s" % [player.character, player.sprite_color]
		if not character_sheets.has(key): character_sheets[key] = load("res://assets/characters/%s.png" % key)

func _network_snapshot(snapshot: Dictionary) -> void:
	if not network_match or client_match == null or state in ["results", "match_end"]: return
	client_match.receive(snapshot)
	if state in ["loading", "countdown"]:
		state = "playing"
		_build_hud()

func _network_events(events: Array) -> void:
	if network_match: _handle_events(events)

func _network_lost(reason: String) -> void:
	if not network_match: return
	network_match = false
	_build_menu()
	_label(hud_root, I18n.t(reason), Vector2(0, 265), 22, GameConfig.LOSS_TEXT, true)

func _network_process(delta: float) -> void:
	var move := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	simulation_accumulator += minf(delta, GameConfig.NET_MAX_FRAME)
	while simulation_accumulator >= GameConfig.NET_TICK:
		simulation_accumulator -= GameConfig.NET_TICK
		client_match.predict(move, GameConfig.NET_TICK, pending_dash)
		Net.submit_input.rpc_id(1, client_match.seq, move, pending_dash, pending_spell)
		if pending_dash: Net.intent.rpc_id(1, client_match.seq, "dash")
		if pending_spell: Net.intent.rpc_id(1, client_match.seq, "spell")
		pending_dash = false
		pending_spell = false
	_read_state(client_match.render(delta))
	ping_clock += delta
	if ping_clock >= 1.0:
		ping_clock = 0.0
		Net.ping.rpc_id(1, Time.get_ticks_msec())
	_update_hud()
	queue_redraw()

func _ready() -> void:
	Net.snapshot_received.connect(_network_snapshot)
	Net.events_received.connect(_network_events)
	Net.disconnected.connect(_network_lost)
	Net.room_changed.connect(func(room: Dictionary):
		if network_match and room.phase == "lobby" and state in ["results", "match_end"]: _build_online()
	)
	Net.pong_received.connect(func(stamp: int): ping_ms = Time.get_ticks_msec() - stamp)
	get_window().title = "VoodooCombo 0.1"
	Settings.apply_display()
	player_name_font = ThemeBuilder.font("Oswald-Medium.woff2")
	floating_coin_font = ThemeBuilder.font("Oswald-Bold.woff2")
	floating_notice_font = ThemeBuilder.font("Cinzel-Bold.woff2")
	previous_arena_id = Profile.last_arena_id
	var metadata: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://assets/characters/characters.json"))
	if metadata is Dictionary:
		character_metadata = metadata
	var loading_source: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://assets/ui/carga.json"))
	if loading_source is Dictionary:
		loading_metadata = loading_source
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
	if Profile.nick.strip_edges().is_empty():
		_build_nickname_dialog()
	else:
		_build_menu()

func _process(delta: float) -> void:
	if state == "match_end":
		end_wait = maxf(0.0, end_wait - delta)
		if end_wait == 0.0: _show_results()
		return
	if state == "results":
		results_elapsed += delta
		results_emote_cooldown = maxf(0.0, results_emote_cooldown - delta)
		_update_result_emotes(delta)
		if not network_match and results_elapsed >= GameConfig.RESULTS_AUTO_MENU_SECONDS: _build_menu()
		return
	if state == "menu":
		if not Settings.reduce_motion: character_idle += delta
		if is_instance_valid(character_preview): _update_character_preview()
		return
	if state == "loading":
		loading_elapsed = minf(GameConfig.LOADING_SECONDS, loading_elapsed + delta)
		var next_tip := posmod(floori(loading_elapsed / GameConfig.LOADING_TIP_INTERVAL), GameConfig.LOADING_TIP_COUNT)
		if next_tip != loading_tip_index:
			loading_tip_index = next_tip
			var tip_label := hud_root.get_node_or_null("LoadingTip") as Label if is_instance_valid(hud_root) else null
			if tip_label: tip_label.text = I18n.t("loading_tip_%d" % (loading_tip_index + 1))
		var progress := hud_root.get_node_or_null("LoadingProgress") as ProgressBar if is_instance_valid(hud_root) else null
		if progress: progress.value = loading_elapsed / GameConfig.LOADING_SECONDS * GameConfig.LOADING_PERCENT_MAX
		var skip_prompt := hud_root.get_node_or_null("LoadingSkip") as Label if is_instance_valid(hud_root) else null
		if skip_prompt: skip_prompt.visible = loading_elapsed >= GameConfig.LOADING_SKIP_SECONDS and _is_practice_match()
		if loading_elapsed >= GameConfig.LOADING_SECONDS: _start_countdown()
		return
	if state == "playing" and Input.is_action_just_pressed("dash"):
		_start_dash(0)
	if state == "playing" and Input.is_action_just_pressed("use_spell"):
		_use_spell(0)
	if state == "playing":
		_update_dash_trails(delta)
		spell_notice_time = maxf(0.0, spell_notice_time - delta)
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
	if network_match:
		_network_process(delta)
		return
	simulation_accumulator += minf(delta, 0.25)
	while simulation_accumulator >= 1.0 / 30.0 and state == "playing":
		var inputs: Array[Dictionary] = [{"move": Input.get_vector("move_left", "move_right", "move_up", "move_down"), "dash": pending_dash, "spell": pending_spell}]
		simulation.step(1.0 / 30.0, inputs)
		pending_dash = false
		pending_spell = false
		simulation_accumulator -= 1.0 / 30.0
		_read_simulation()
		_show_simulation_events()
	if state == "playing":
		if not players.is_empty() and float(players[local_player].dash_left) > 0.0 and dash_trail_emit <= 0.0:
			_add_dash_trail(players[local_player].pos, players[local_player].color)
			dash_trail_emit = GameConfig.DASH_TRAIL_INTERVAL
		if fog_material != null:
			var safe_rect := ZoneRules.safe_rect(safe_zone_step)
			fog_material.set_shader_parameter("safe_bounds", Vector4(OFFSET.x + safe_rect.position.x, OFFSET.y + safe_rect.position.y, OFFSET.x + safe_rect.end.x, OFFSET.y + safe_rect.end.y))
			fog_material.set_shader_parameter("scroll_time", 0.0 if Settings.reduce_motion else elapsed * GameConfig.ZONE_FOG_SCROLL_SPEED)
		var public_players: Array[Dictionary] = []
		for player in players: public_players.append({"name": player.name, "score": player.score, "combo": player.combo})
		HttpEndpoint.set_status({"mode": mode, "time": remaining, "players": public_players})
		_update_hud()
		_animate_floating(delta)
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == GameConfig.SETTINGS_F11_KEY:
		Settings.toggle_fullscreen()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		last_input_controller = true
	elif event is InputEventKey or event is InputEventMouseButton:
		last_input_controller = false
	if state == "results":
		if event is InputEventKey and event.pressed and not event.echo:
			results_elapsed = 0.0
			if event.keycode >= KEY_1 and event.keycode <= KEY_4:
				_launch_result_emote(int(event.keycode - KEY_1))
				get_viewport().set_input_as_handled()
		elif event is InputEventJoypadButton and event.pressed:
			results_elapsed = 0.0
			var dpad_emote := {JOY_BUTTON_DPAD_UP: 0, JOY_BUTTON_DPAD_RIGHT: 1, JOY_BUTTON_DPAD_DOWN: 2, JOY_BUTTON_DPAD_LEFT: 3}
			if dpad_emote.has(event.button_index):
				_launch_result_emote(int(dpad_emote[event.button_index]))
				get_viewport().set_input_as_handled()
	if state == "playing" and event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_SPACE, KEY_SHIFT]:
			_start_dash(0)
		elif event.keycode == KEY_ESCAPE:
			state = "paused"
			_build_pause()
			get_viewport().set_input_as_handled()
	elif state == "paused" and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		state = "playing"
		_build_hud()
	elif state == "arena_select" and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_build_menu()
	elif state == "loading" and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE and loading_elapsed >= GameConfig.LOADING_SKIP_SECONDS and _is_practice_match():
		_start_countdown()
		get_viewport().set_input_as_handled()

func _begin_match(classic: bool = false, arena_id: String = "", overrides: Dictionary = {}) -> void:
	network_match = false
	local_player = 0
	simulation = MatchSim.new()
	seed_value = int(Time.get_unix_time_from_system()) + randi()
	var roster: Array[Dictionary] = [
		{"name": Profile.nick, "character": Profile.character, "is_bot": false},
		{"name": "Mordisquitos", "character": "trol", "is_bot": true},
		{"name": "Conde Costura", "character": "gnomo", "is_bot": true},
		{"name": "Dama del Pantano", "character": "nigro", "is_bot": true}
	]
	var config := {"seed": seed_value, "mode": "classic" if classic else "voodoo", "arena_id": arena_id, "previous_arena": previous_arena_id, "players": roster}
	config.merge(overrides, true)
	simulation.setup(config)
	_read_simulation()
	rng.seed = seed_value
	simulation_accumulator = 0.0
	pending_dash = false
	pending_spell = false
	previous_arena_id = str(arena.map_id)
	selected_arena_id = previous_arena_id
	Profile.last_arena_id = previous_arena_id
	Profile.save()
	arena_background = load("res://assets/arenas/" + str(arena.background)) if not str(arena.background).is_empty() else null
	for player in players:
		var key := "%s_%s" % [player.character, player.sprite_color]
		if not character_sheets.has(key): character_sheets[key] = load("res://assets/characters/%s.png" % key)
	floating.clear()
	_build_loading()

func _read_simulation() -> void:
	_read_state(simulation.snapshot())

func _read_state(data: Dictionary) -> void:
	for key in data:
		if key not in ["finished", "ack"]: set(key, data[key])

func _start_dash(_index: int) -> void:
	pending_dash = true

func _use_spell(_index: int) -> void:
	pending_spell = true

func _show_simulation_events() -> void:
	_handle_events(simulation.pop_events())

func _handle_events(events: Array) -> void:
	for event: Dictionary in events:
		match str(event.type):
			"player_left":
				Fx.pop("☁", event.pos + OFFSET, Color("b8a9d1"))
			"social":
				if state == "results":
					for index in results_ranking.size():
						if int(results_ranking[index].get("peer_id", 0)) == int(event.peer_id): _add_result_emote(index, str(event.item))
			"text":
				var text: String = event.text
				var expression := RegEx.new()
				expression.compile("\\{([^}]+)\\}")
				for token in expression.search_all(text):
					text = text.replace(token.get_string(), I18n.t(token.get_string(1)))
				Fx.pop(text, event.position, event.color)
			"tone":
				Sfx.play_tone(event.frequency, event.duration)
			"hit_feedback":
				Fx.hit()
			"item_rolled":
				if int(event.player) == local_player:
					spell_notice_item = str(event.item)
					spell_notice_time = GameConfig.SPELL_NOTICE_SECONDS
			"match_over":
				if event.has("snapshot"): _read_state(event.snapshot)
				_finish_match(event.get("ranking", []), event.get("awards", {}))
				break

func _build_loading() -> void:
	state = "loading"
	loading_elapsed = 0.0
	loading_tip_index = -1
	_clear_hud()
	var root := _new_overlay()
	var backdrop := _screen_backdrop()
	root.add_child(backdrop)
	root.move_child(backdrop, 0)
	var title := _label(root, I18n.t("arena_" + String(arena.map_id)), Vector2(0.0, GameConfig.LOADING_TITLE_Y), GameConfig.LOADING_TITLE_SIZE, GameConfig.GOLD, true)
	var title_font := ThemeBuilder.font("Cinzel-Bold.woff2")
	if title_font != null: title.add_theme_font_override("font", title_font)
	var thumbnail := TextureRect.new()
	thumbnail.texture = load(_arena_thumbnail_path(String(arena.map_id)))
	thumbnail.position = GameConfig.LOADING_THUMB_POSITION
	thumbnail.size = GameConfig.LOADING_THUMB_SIZE
	thumbnail.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	thumbnail.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	root.add_child(thumbnail)
	var trap_keys: Array = GameConfig.ARENA_TRAP_KEYS.get(String(arena.map_id), [])
	var trap_icons: Array = GameConfig.ARENA_TRAP_ICONS.get(String(arena.map_id), [])
	for index in range(trap_keys.size()):
		var trap_name := String(trap_keys[index])
		var icon := TextureRect.new()
		var atlas := AtlasTexture.new()
		atlas.atlas = TRAP_ICONS_TEXTURE
		var trap_manifest: Dictionary = loading_metadata.get("trampas_iconos", {})
		var icon_frame := float(trap_manifest.get("frame_w", GameConfig.ARENA_ICON_FRAME_SIZE))
		atlas.region = Rect2(float(trap_icons[index]) * icon_frame, 0.0, icon_frame, float(trap_manifest.get("frame_h", icon_frame)))
		icon.texture = atlas
		icon.position = GameConfig.LOADING_TRAP_POSITION + Vector2(0.0, index * GameConfig.LOADING_TRAP_ROW_GAP)
		icon.size = Vector2.ONE * GameConfig.LOADING_TRAP_ICON_SIZE
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		root.add_child(icon)
		var trap_text := _hud_label(root, icon.position + Vector2(GameConfig.LOADING_TRAP_TEXT_OFFSET, 0.0), GameConfig.LOADING_TRAP_TEXT_SIZE, GameConfig.LOADING_TRAP_TEXT_FONT_SIZE, HORIZONTAL_ALIGNMENT_LEFT)
		trap_text.text = I18n.t("loading_trap_" + trap_name)
	var controls := _hud_label(root, Vector2(48.0, GameConfig.LOADING_CONTROLS_Y), GameConfig.LOADING_CONTROLS_SIZE, GameConfig.LOADING_CONTROLS_FONT_SIZE, HORIZONTAL_ALIGNMENT_CENTER)
	controls.text = I18n.t("loading_controls")
	var tip := _hud_label(root, GameConfig.LOADING_TIP_POSITION, GameConfig.LOADING_TIP_SIZE, GameConfig.LOADING_TIP_FONT_SIZE, HORIZONTAL_ALIGNMENT_LEFT)
	tip.name = "LoadingTip"
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var portrait_path := "res://assets/ui/retrato_%s_coral.png" % String(players[local_player].character)
	var portrait := TextureRect.new()
	portrait.texture = load(portrait_path)
	portrait.position = GameConfig.LOADING_CHARACTER_POSITION
	portrait.size = GameConfig.LOADING_PORTRAIT_SIZE
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	root.add_child(portrait)
	var player_text := _hud_label(root, GameConfig.LOADING_CHARACTER_POSITION + GameConfig.LOADING_PLAYER_TEXT_OFFSET, GameConfig.LOADING_PLAYER_TEXT_SIZE, GameConfig.LOADING_PLAYER_TEXT_FONT_SIZE, HORIZONTAL_ALIGNMENT_CENTER)
	player_text.text = "%s\n%s %d · %s" % [String(players[local_player].name), I18n.t("loading_player"), GameConfig.LOADING_LOCAL_PLAYER_NUMBER, String(players[local_player].character).capitalize()]
	var progress := ProgressBar.new()
	progress.name = "LoadingProgress"
	progress.position = GameConfig.LOADING_PROGRESS_POSITION
	progress.size = GameConfig.LOADING_PROGRESS_SIZE
	progress.max_value = GameConfig.LOADING_PERCENT_MAX
	progress.show_percentage = false
	root.add_child(progress)
	var skip_text := _hud_label(root, GameConfig.LOADING_SKIP_POSITION, GameConfig.LOADING_SKIP_SIZE, GameConfig.LOADING_SKIP_FONT_SIZE, HORIZONTAL_ALIGNMENT_CENTER)
	skip_text.name = "LoadingSkip"
	skip_text.text = I18n.t("loading_skip")
	skip_text.visible = false
	_update_loading_text()

func _update_loading_text() -> void:
	var tip := hud_root.get_node_or_null("LoadingTip") as Label if is_instance_valid(hud_root) else null
	if tip:
		loading_tip_index = posmod(floori(loading_elapsed / GameConfig.LOADING_TIP_INTERVAL), GameConfig.LOADING_TIP_COUNT)
		tip.text = I18n.t("loading_tip_%d" % (loading_tip_index + 1))

func _is_practice_match() -> bool:
	if network_match: return false
	for index in range(1, players.size()):
		if not bool(players[index].is_bot): return false
	return true

func _arena_thumbnail_path(arena_id: String) -> String:
	var manifest: Dictionary = loading_metadata.get("arena_mini", {})
	var filename := String(manifest.get("file", "arena_<id>_mini.png")).replace("<id>", arena_id)
	return "res://assets/ui/" + filename

func _start_countdown() -> void:
	if state != "loading": return
	countdown = 3.0
	state = "countdown"
	_build_hud()
	queue_redraw()

func _update_hud() -> void:
	if not is_instance_valid(hud_root): return
	if network_match:
		var ping := hud_root.get_node_or_null("Ping") as Label
		if ping == null:
			ping = _hud_label(hud_root, Vector2(1150, 78), Vector2(110,28),18, HORIZONTAL_ALIGNMENT_RIGHT)
			ping.name = "Ping"
		ping.text = "%d ms" % ping_ms
		ping.modulate = Color.GREEN if ping_ms < 80 else (Color.YELLOW if ping_ms < 150 else Color.RED)
	var time_label := hud_root.get_node_or_null("Timer") as Label
	if time_label:
		var seconds := maxi(0, ceili(remaining))
		time_label.text = ("3 · 2 · 1" if state == "countdown" else "%d:%02d" % [seconds / 60, seconds % 60])
		time_label.add_theme_color_override("font_color", GameConfig.GOLD if remaining <= 15.0 and mode == "voodoo" else Color.WHITE)
	var leader := _leader_index() if not players.is_empty() else -1
	for slot in range(score_name_labels.size()):
		var active := slot < players.size()
		for control in [score_name_labels[slot], score_tag_labels[slot], score_number_labels[slot], score_portraits[slot], score_frames[slot], score_frame_skulls[slot]]:
			control.visible = active
		score_crowns[slot].visible = active and slot == leader
		if not active: continue
		var player: Dictionary = players[slot]
		score_name_labels[slot].text = String(player.name)
		score_name_labels[slot].add_theme_color_override("font_color", player.color)
		score_tag_labels[slot].text = "%s%d · %s%s" % [I18n.t("player"), slot + 1, (I18n.t("you") + " · ") if slot == local_player else "", player.shape]
		score_tag_labels[slot].add_theme_color_override("font_color", player.color)
		var portrait_path := "res://assets/ui/retrato_%s_%s.png" % [player.character, player.sprite_color]
		var portrait_texture: Texture2D = load(portrait_path)
		if portrait_texture != null: score_portraits[slot].texture = portrait_texture
		var frame_id := String(Profile.cosmetics.get("frame", "madera")) if slot == 0 else "madera"
		var frame_texture: Texture2D = load("res://assets/ui/marco_%s.png" % ("hueso" if frame_id == "calavera" else frame_id))
		if frame_texture != null: score_frames[slot].texture = frame_texture
		score_frame_skulls[slot].visible = slot == 0 and frame_id == "calavera"
		var value := int(player.score)
		if score_values[slot] != value:
			var previous_value := maxi(0, score_values[slot])
			score_values[slot] = value
			score_change_times[slot] = Time.get_ticks_msec()
			_animate_score(score_number_labels[slot], previous_value, value)
	var spell_icon := hud_root.get_node_or_null("SpellIcon") as TextureRect
	var spell_name := hud_root.get_node_or_null("SpellName") as Label
	var spell_glow := hud_root.get_node_or_null("SpellGlow") as TextureRect
	var spell_key := hud_root.get_node_or_null("SpellKey") as TextureRect
	if spell_icon and not players.is_empty():
		var spell_index := ITEMS.find(String(players[local_player].item))
		spell_icon.visible = spell_index >= 0
		spell_icon.texture = spell_atlases[spell_index] if spell_index >= 0 else null
		if spell_glow:
			spell_glow.visible = spell_index >= 0
			spell_glow.modulate.a = 0.65 + 0.25 * sin(Time.get_ticks_msec() / 180.0) if not Settings.reduce_motion else 0.8
		if spell_key: spell_key.texture = SPELL_KEY_B_TEXTURE if last_input_controller else SPELL_KEY_E_TEXTURE
	if spell_name and not players.is_empty():
		var item := String(players[local_player].item)
		var is_active := float(players[local_player].item_time) > 0.0
		spell_name.text = (I18n.t("spell_" + item) + "  %.1f" % float(players[local_player].item_time)) if is_active else (I18n.t("spell_" + item) if not item.is_empty() else I18n.t("spell"))
		spell_name.modulate.a = 1.0 if SpellRules.can_activate(players[local_player]) else 0.72
	var notice := hud_root.get_node_or_null("SpellNotice") as Control
	if notice:
		notice.visible = spell_notice_time > 0.0
		var notice_icon := hud_root.get_node_or_null("SpellNoticeIcon") as TextureRect
		var notice_name := hud_root.get_node_or_null("SpellNoticeName") as Label
		var notice_text := hud_root.get_node_or_null("SpellNoticeText") as Label
		var notice_index := ITEMS.find(spell_notice_item)
		if notice_icon and notice_index >= 0: notice_icon.texture = spell_atlases[notice_index]
		if notice_name: notice_name.text = I18n.t("spell_" + spell_notice_item)
		if notice_text: notice_text.text = I18n.t("spell_desc_" + spell_notice_item)

func _build_menu() -> void:
	if network_match: Net.leave_server()
	network_match = false
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
	logo.texture = load("res://assets/ui/logo_brasa.png")
	logo.position = Vector2(360, 14)
	logo.size = Vector2(560, 253)
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(logo)
	if not Settings.reduce_motion:
		logo.position.y = -230
		menu_logo_tween = create_tween()
		menu_logo_tween.tween_property(logo, "position:y", 14.0, 0.5).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		menu_logo_tween.tween_property(logo, "position:y", 18.0, 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		menu_logo_tween.set_loops()
	var labels := [I18n.t("play"), I18n.t("classic_mode"), I18n.t("characters"), I18n.t("settings"), I18n.t("history"), I18n.t("exit")]
	var actions: Array[Callable] = [_build_online, func(): _build_arena_select(true), _build_characters, _build_settings, _build_history, func(): get_tree().quit()]
	for index in range(labels.size()):
		var button := _button(root, labels[index], Vector2(0, 302 + index * 59), actions[index])
		if not Settings.reduce_motion:
			button.modulate.a = 0.0
			var tween := create_tween()
			tween.tween_interval(index * 0.05)
			tween.tween_property(button, "modulate:a", 1.0, 0.2)
	_label(root, "WASD mover · Espacio dash · E hechizo · Esc atrás", Vector2(210, 666), 16, Color("b8a9d1"), false)

func _build_arena_select(classic: bool) -> void:
	_clear_hud()
	arena_select_classic = classic
	state = "arena_select"
	var root := _new_overlay()
	var backdrop := _screen_backdrop()
	root.add_child(backdrop)
	root.move_child(backdrop, 0)
	_label(root, I18n.t("choose_arena"), Vector2(0, GameConfig.ARENA_SELECT_TITLE_Y), GameConfig.ARENA_SELECT_TITLE_SIZE, GameConfig.GOLD, true)
	var preferred_button: Button
	for index in range(GameConfig.ARENA_IDS.size()):
		var arena_id: String = GameConfig.ARENA_IDS[index]
		var card := Panel.new()
		card.position = Vector2(GameConfig.ARENA_CARD_X + index * (GameConfig.ARENA_CARD_SIZE.x + GameConfig.ARENA_CARD_GAP), GameConfig.ARENA_CARD_Y)
		card.size = GameConfig.ARENA_CARD_SIZE
		var card_style := StyleBoxFlat.new()
		card_style.bg_color = Color("241838")
		card_style.border_color = Color("8A6B45")
		card_style.set_border_width_all(2)
		card_style.set_corner_radius_all(10)
		card.add_theme_stylebox_override("panel", card_style)
		card.gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				_select_arena(arena_id)
		)
		root.add_child(card)
		var thumbnail := TextureRect.new()
		thumbnail.texture = load(_arena_thumbnail_path(arena_id))
		thumbnail.position = Vector2.ONE * GameConfig.ARENA_THUMB_MARGIN
		thumbnail.size = GameConfig.ARENA_THUMB_SIZE
		thumbnail.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		thumbnail.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		thumbnail.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(thumbnail)
		var arena_name := _hud_label(card, Vector2(8, GameConfig.ARENA_NAME_Y), GameConfig.ARENA_NAME_SIZE, GameConfig.ARENA_NAME_FONT_SIZE, HORIZONTAL_ALIGNMENT_CENTER)
		arena_name.text = I18n.t("arena_" + arena_id)
		arena_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for icon_order in range(GameConfig.ARENA_TRAP_ICONS[arena_id].size()):
			var icon := TextureRect.new()
			var icon_atlas := AtlasTexture.new()
			icon_atlas.atlas = TRAP_ICONS_TEXTURE
			var trap_manifest: Dictionary = loading_metadata.get("trampas_iconos", {})
			var icon_frame := float(trap_manifest.get("frame_w", GameConfig.ARENA_ICON_FRAME_SIZE))
			icon_atlas.region = Rect2(float(GameConfig.ARENA_TRAP_ICONS[arena_id][icon_order]) * icon_frame, 0.0, icon_frame, float(trap_manifest.get("frame_h", icon_frame)))
			icon.texture = icon_atlas
			icon.position = Vector2(GameConfig.ARENA_ICON_START.x + icon_order * GameConfig.ARENA_ICON_GAP, GameConfig.ARENA_ICON_START.y)
			icon.size = Vector2.ONE * GameConfig.ARENA_ICON_SIZE
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			card.add_child(icon)
		var select := Button.new()
		select.text = I18n.t("play")
		select.position = Vector2(GameConfig.ARENA_BUTTON_MARGIN, GameConfig.ARENA_BUTTON_Y)
		select.size = GameConfig.ARENA_BUTTON_SIZE
		select.focus_mode = Control.FOCUS_ALL
		select.pressed.connect(_select_arena.bind(arena_id))
		card.add_child(select)
		if Profile.preferred_arena_id == arena_id:
			preferred_button = select
	var random_button := _button(root, I18n.t("random_arena"), Vector2(0, 520), func(): _select_arena(""))
	random_button.size = GameConfig.ARENA_RANDOM_BUTTON_SIZE
	random_button.position = GameConfig.ARENA_RANDOM_BUTTON_POSITION
	if preferred_button != null:
		preferred_button.grab_focus()
	_button(root, I18n.t("menu"), Vector2(0, GameConfig.ARENA_MENU_BUTTON_Y), _build_menu)

func _select_arena(arena_id: String) -> void:
	selected_arena_id = arena_id
	Profile.preferred_arena_id = arena_id if not arena_id.is_empty() else "random"
	Profile.save()
	_begin_match(arena_select_classic, arena_id)

func _build_characters() -> void:
	_build_locker("character")

func _build_locker(tab: String) -> void:
	_clear_hud()
	state = "locker"
	locker_tab = tab
	var root := _new_overlay()
	_label(root, I18n.t("characters"), Vector2(0, 44), 42, GameConfig.GOLD, true)
	var tab_ids := ["character", "frame", "trail", "emotes"]
	var tab_keys := ["locker_character", "locker_frame", "locker_trail", "locker_emotes"]
	for index in range(tab_ids.size()):
		var tab_button := _button(root, I18n.t(tab_keys[index]), Vector2(0, 102), Callable(self, "_build_locker").bind(tab_ids[index]))
		tab_button.position = Vector2(180.0 + index * 235.0, 102.0)
		tab_button.size = Vector2(210.0, 46.0)
	if tab != "character":
		_build_cosmetic_tab(root, tab)
		_button(root, I18n.t("menu"), Vector2(0, 610), _locker_back)
		return
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
	_label(root, Profile.nick, Vector2(0.0, GameConfig.CHARACTER_NICKNAME_Y), GameConfig.CHARACTER_NICKNAME_FONT_SIZE, Color("fff6c2"), false)
	_button(root, I18n.t("name_edit"), Vector2(0.0, GameConfig.NICK_EDIT_BUTTON_Y), func(): _build_nickname_dialog(true))
	var previous_button := _button(root, "◀", Vector2(-210, 265), func(): _cycle_character(-1))
	previous_button.position = Vector2(350, 265)
	previous_button.size = Vector2(64, 54)
	var next_button := _button(root, "▶", Vector2(210, 265), func(): _cycle_character(1))
	next_button.position = Vector2(866, 265)
	next_button.size = Vector2(64, 54)
	_button(root, I18n.t("menu"), Vector2(0, 565), _locker_back)
	character_idle = 0.0

func _build_cosmetic_tab(root: Control, tab: String) -> void:
	if tab == "emotes":
		_build_social_locker(root)
		return
	var ids: Array[String] = []
	var levels: Dictionary = {}
	if tab == "frame":
		ids = ["madera", "hueso", "calavera", "plata", "oro", "almas"]
		levels = GameConfig.FRAME_UNLOCK_LEVELS
	elif tab == "trail":
		ids = ["color", "oro", "escarcha", "almas"]
		levels = GameConfig.TRAIL_UNLOCK_LEVELS
	else:
		ids = ["risa", "enfado", "llanto", "corazon", "gg", "calavera", "pulgar", "fuego"]
		levels = GameConfig.EMOTE_UNLOCK_LEVELS
	var equipped: Array = Profile.cosmetics.get("emotes", [])
	for index in range(ids.size()):
		var item_id := ids[index]
		var col := index % 4
		var row := index / 4
		var card := Panel.new()
		card.position = Vector2(122.0 + col * 264.0, 180.0 + row * 192.0)
		card.size = Vector2(230.0, 166.0)
		var style := StyleBoxFlat.new()
		style.bg_color = Color("241838")
		style.border_color = GameConfig.GOLD if (Profile.cosmetics.get("frame", "madera") == item_id or Profile.cosmetics.get("trail", "color") == item_id or equipped.has(item_id)) else Color("5c496d")
		style.set_border_width_all(2)
		style.set_corner_radius_all(8)
		card.add_theme_stylebox_override("panel", style)
		root.add_child(card)
		var icon := TextureRect.new()
		icon.position = Vector2(82.0, 10.0)
		icon.size = Vector2(66.0, 66.0)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		if tab == "frame":
			icon.texture = load("res://assets/ui/marco_%s.png" % ("hueso" if item_id == "calavera" else item_id))
			card.add_child(icon)
		elif tab == "emotes":
			icon = _result_emote_icon(item_id)
			icon.position = Vector2(82.0, 10.0)
			icon.size = Vector2(66.0, 66.0)
			card.add_child(icon)
		else:
			var swatch := ColorRect.new()
			swatch.position = Vector2(100.0, 16.0)
			swatch.size = Vector2(30.0, 52.0)
			swatch.color = {"color": Color("d9a8ff"), "oro": GameConfig.GOLD, "escarcha": Color("7fe7ff"), "almas": Color("b06bff")}.get(item_id, Color.WHITE)
			card.add_child(swatch)
		var title := _hud_label(card, Vector2(4.0, 80.0), Vector2(222.0, 30.0), 17, HORIZONTAL_ALIGNMENT_CENTER)
		title.text = I18n.t("cosmetic_" + item_id)
		var unlocked := Profile.level() >= int(levels.get(item_id, 99))
		var action_text := I18n.t("locker_equipped") if (Profile.cosmetics.get(tab, "") == item_id or equipped.has(item_id)) else I18n.t("locker_select")
		if not unlocked: action_text = "🔒 " + (I18n.t("unlock_level") % int(levels.get(item_id, 1)))
		var pick := _button(card, action_text, Vector2(0.0, 119.0), Callable(self, "_select_locker_item").bind(tab, item_id))
		pick.position = Vector2(8.0, 118.0)
		pick.size = Vector2(214.0, 40.0)

func _select_locker_item(tab: String, item_id: String) -> void:
	var levels: Dictionary = GameConfig.EMOTE_UNLOCK_LEVELS if tab == "emotes" else (GameConfig.FRAME_UNLOCK_LEVELS if tab == "frame" else GameConfig.TRAIL_UNLOCK_LEVELS)
	if Profile.level() < int(levels.get(item_id, 99)): return
	if tab == "emotes":
		var emotes: Array = Profile.cosmetics.get("emotes", []).duplicate()
		if emotes.has(item_id):
			if emotes.size() > 1: emotes.erase(item_id)
		else:
			if emotes.size() >= 4: emotes.pop_front()
			emotes.append(item_id)
		for default_emote in ["risa", "enfado", "gg", "corazon"]:
			if emotes.size() >= 4: break
			if not emotes.has(default_emote): emotes.append(default_emote)
		Profile.cosmetics.emotes = emotes
	else:
		Profile.cosmetics["frame" if tab == "frame" else "trail"] = item_id
	Profile.save()
	_build_locker(tab)

func _build_social_locker(root: Control) -> void:
	var equipped: Array = Profile.cosmetics.get("social", GameConfig.SOCIAL_DEFAULT)
	var ids: Array = GameConfig.SOCIAL_LEVELS.keys()
	for slot in 8:
		var column := slot % 2
		var row := slot / 2
		var selector := OptionButton.new()
		selector.position = Vector2(150 + column * 510, 190 + row * 90)
		selector.size = Vector2(460, 60)
		for index in ids.size():
			var item: String = str(ids[index])
			var key := item if item.begins_with("dance") or item.begins_with("shout") else "cosmetic_" + item
			selector.add_item("%d · %s" % [slot + 1, I18n.t(key)])
			selector.set_item_disabled(index, Profile.level() < int(GameConfig.SOCIAL_LEVELS[item]))
			if item == str(equipped[slot]): selector.select(index)
		selector.item_selected.connect(func(index: int):
			Profile.cosmetics.social[slot] = ids[index]
			Profile.save()
		)
		root.add_child(selector)

func _build_nickname_dialog(return_to_characters: bool = false) -> void:
	_clear_hud()
	state = "nickname"
	nick_dialog_returns_to_characters = return_to_characters
	var root := _new_overlay()
	var backdrop := _screen_backdrop()
	root.add_child(backdrop)
	root.move_child(backdrop, 0)
	_label(root, I18n.t("name_title"), Vector2(0.0, GameConfig.NICK_DIALOG_TITLE_Y), GameConfig.NICK_DIALOG_TITLE_SIZE, GameConfig.GOLD, true)
	var hint := _hud_label(root, GameConfig.NICK_DIALOG_HINT_POSITION, GameConfig.NICK_DIALOG_HINT_SIZE, GameConfig.NICK_DIALOG_HINT_FONT_SIZE, HORIZONTAL_ALIGNMENT_CENTER)
	hint.text = I18n.t("name_hint")
	nick_line_edit = LineEdit.new()
	nick_line_edit.position = GameConfig.NICK_DIALOG_FIELD_POSITION
	nick_line_edit.size = GameConfig.NICK_DIALOG_FIELD_SIZE
	nick_line_edit.max_length = GameConfig.NICK_MAX_LENGTH
	nick_line_edit.text = Profile.nick
	nick_line_edit.placeholder_text = I18n.t("name_hint")
	nick_line_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	nick_line_edit.focus_mode = Control.FOCUS_ALL
	nick_line_edit.text_submitted.connect(_save_nickname)
	root.add_child(nick_line_edit)
	nick_error_label = _hud_label(root, Vector2(GameConfig.NICK_DIALOG_HINT_POSITION.x, GameConfig.NICK_DIALOG_ERROR_Y), GameConfig.NICK_DIALOG_ERROR_SIZE, GameConfig.NICK_DIALOG_ERROR_FONT_SIZE, HORIZONTAL_ALIGNMENT_CENTER)
	nick_error_label.add_theme_color_override("font_color", Color("ff7474"))
	var save_button := _button(root, I18n.t("name_save"), Vector2(0.0, GameConfig.NICK_DIALOG_BUTTON_Y), func(): _save_nickname(nick_line_edit.text))
	save_button.grab_focus()
	nick_line_edit.grab_focus()
	nick_line_edit.caret_column = nick_line_edit.text.length()

func _save_nickname(value: String) -> void:
	var cleaned := NicknameRules.normalize(value)
	if not NicknameRules.is_valid(cleaned):
		if is_instance_valid(nick_error_label): nick_error_label.text = I18n.t("name_invalid")
		return
	Profile.nick = cleaned
	Profile.save()
	if nick_dialog_returns_to_characters:
		_build_characters()
	else:
		_build_menu()

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
	var server_button := _button(root, I18n.t("server"), Vector2.ZERO, _build_server_settings)
	server_button.position = Vector2(980, 30)
	server_button.size = Vector2(260, 55)
	_button(root, "%s: %s" % [I18n.t("settings_reduce_motion"), I18n.t("settings_yes") if Settings.reduce_motion else I18n.t("settings_no")], Vector2(0, 215), func():
		Settings.reduce_motion = not Settings.reduce_motion
		Settings.save()
		_build_settings())
	_button(root, "%s: %d%%" % [I18n.t("settings_ui_scale"), int(Settings.ui_scale * 100.0)], Vector2(0, 275), func():
		Settings.ui_scale = 1.0 if Settings.ui_scale >= 1.5 else Settings.ui_scale + 0.25
		Settings.save()
		_build_settings())
	var display_mode := I18n.t("settings_fullscreen") if Settings.window_fullscreen else I18n.t("settings_windowed")
	_button(root, "%s: %s" % [I18n.t("settings_display_mode"), display_mode], Vector2(0, GameConfig.SETTINGS_DISPLAY_MODE_Y), func():
		Settings.toggle_fullscreen()
		_build_settings())
	var window_size: Vector2i = GameConfig.WINDOW_SIZE_OPTIONS[Settings.window_size_index]
	_button(root, "%s: %d×%d" % [I18n.t("settings_window_size"), window_size.x, window_size.y], Vector2(0, GameConfig.SETTINGS_WINDOW_SIZE_Y), func():
		Settings.cycle_window_size()
		_build_settings())
	_button(root, "%s: %s" % [I18n.t("settings_language"), I18n.language], Vector2(0, GameConfig.SETTINGS_LANGUAGE_Y), func():
		I18n.set_language("ca" if I18n.language == "es" else ("en" if I18n.language == "ca" else "es"))
		Settings.save()
		_build_settings())
	_button(root, I18n.t("menu"), Vector2(0, GameConfig.SETTINGS_MENU_Y), _build_menu)

func _build_pause() -> void:
	_clear_hud()
	var root := _new_overlay()
	_label(root, "PAUSA", Vector2(0, 190), 48, GameConfig.GOLD, true)
	_button(root, "Continuar", Vector2(0, 275), func(): state = "playing"; _build_hud())
	_button(root, I18n.t("menu"), Vector2(0, 345), _build_menu)

func _build_server_settings() -> void:
	_clear_hud()
	var root := _new_overlay()
	_label(root, I18n.t("server"), Vector2(0, 90), 40, GameConfig.BONE_TEXT, true)
	var choice := OptionButton.new()
	choice.position = Vector2(390, 210)
	choice.size = Vector2(500, 60)
	for key in ["server_oracle", "server_lan", "server_pc"]: choice.add_item(I18n.t(key))
	choice.select(Settings.server_choice)
	root.add_child(choice)
	var address := LineEdit.new()
	address.position = Vector2(390, 310)
	address.size = Vector2(500, 60)
	address.max_length = 253
	address.text = Settings.server_host
	root.add_child(address)
	choice.item_selected.connect(func(index: int):
		Settings.server_choice = index
		address.text = GameConfig.ONLINE_HOST if index == 0 else ("127.0.0.1" if index == 2 else "")
		address.editable = index != 2
	)
	_button(root, I18n.t("name_save"), Vector2(0, 430), func():
		Settings.server_host = address.text.strip_edges()
		Settings.save()
		_build_settings()
	)
	_button(root, I18n.t("menu"), Vector2(0, 530), _build_settings)

func _build_hud() -> void:
	_clear_hud()
	var root := _new_overlay()
	if state == "menu": return
	if state in ["playing", "countdown"]:
		var fog_rect := ColorRect.new()
		fog_rect.position = Vector2.ZERO
		fog_rect.size = Vector2(1280.0, 720.0)
		fog_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fog_rect.z_index = -1
		fog_material = ShaderMaterial.new()
		fog_material.shader = SAFE_ZONE_FOG_SHADER
		fog_material.set_shader_parameter("fog_texture", SAFE_ZONE_FOG_TEXTURE)
		fog_material.set_shader_parameter("logical_size", Vector2(1280.0, 720.0))
		fog_material.set_shader_parameter("tile_size", GameConfig.ZONE_FOG_TILE_SIZE)
		fog_material.set_shader_parameter("fog_alpha", GameConfig.ZONE_FOG_ALPHA)
		fog_material.set_shader_parameter("scroll_y_ratio", GameConfig.ZONE_FOG_SCROLL_Y_RATIO)
		fog_rect.material = fog_material
		root.add_child(fog_rect)
	score_name_labels.clear()
	score_tag_labels.clear()
	score_number_labels.clear()
	score_portraits.clear()
	score_frames.clear()
	score_frame_skulls.clear()
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
		var frame := TextureRect.new()
		frame.position = Vector2(card_x[slot] + 3.0, 10.0)
		frame.size = Vector2(50.0, 50.0)
		frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(frame)
		var skull_overlay := _hud_label(root, Vector2(card_x[slot] + 12.0, 23.0), Vector2(32.0, 28.0), 18, HORIZONTAL_ALIGNMENT_CENTER)
		skull_overlay.text = "☠"
		skull_overlay.visible = false
		score_frame_skulls.append(skull_overlay)
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
		score_frames.append(frame)
		score_crowns.append(crown)
		score_values.append(-1)
		score_change_times.append(0)
	var timer := Label.new()
	timer.name = "Timer"
	timer.position = Vector2(574, 2)
	timer.size = Vector2(132, 58)
	timer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timer.add_theme_font_size_override("font_size", roundi(44 * Settings.ui_scale))
	var clock_font := ThemeBuilder.font("Oswald-Bold.woff2")
	if clock_font != null: timer.add_theme_font_override("font", clock_font)
	timer.add_theme_color_override("font_color", GameConfig.GOLD)
	root.add_child(timer)
	var slot_texture := TextureRect.new()
	slot_texture.name = "SpellSlot"
	slot_texture.texture = SPELL_SLOT_TEXTURE
	slot_texture.position = Vector2(12, 626)
	slot_texture.size = Vector2(80, 80)
	slot_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	slot_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	root.add_child(slot_texture)
	var glow := TextureRect.new()
	glow.name = "SpellGlow"
	glow.texture = SPELL_GLOW_TEXTURE
	glow.position = Vector2(12, 626)
	glow.size = Vector2(80, 80)
	glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glow.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow.visible = false
	root.add_child(glow)
	var spell_icon := TextureRect.new()
	spell_icon.name = "SpellIcon"
	spell_icon.position = Vector2(31, 645)
	spell_icon.size = Vector2(42, 42)
	spell_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	spell_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	spell_icon.visible = false
	root.add_child(spell_icon)
	var spell_key := TextureRect.new()
	spell_key.name = "SpellKey"
	spell_key.texture = SPELL_KEY_E_TEXTURE
	spell_key.position = Vector2(65, 675)
	spell_key.size = Vector2(26, 26)
	spell_key.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	spell_key.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	spell_key.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(spell_key)
	var spell_name := _hud_label(root, Vector2(101, 651), Vector2(180, 34), 17, HORIZONTAL_ALIGNMENT_LEFT)
	spell_name.name = "SpellName"
	var notice := Panel.new()
	notice.name = "SpellNotice"
	notice.position = Vector2(18, 526)
	notice.size = Vector2(330, 86)
	var notice_style := StyleBoxFlat.new()
	notice_style.bg_color = Color("241838")
	notice_style.border_color = GameConfig.GOLD
	notice_style.set_border_width_all(2)
	notice_style.set_corner_radius_all(8)
	notice.add_theme_stylebox_override("panel", notice_style)
	notice.mouse_filter = Control.MOUSE_FILTER_IGNORE
	notice.visible = false
	root.add_child(notice)
	var notice_icon := TextureRect.new()
	notice_icon.name = "SpellNoticeIcon"
	notice_icon.position = Vector2(10, 12)
	notice_icon.size = Vector2(58, 58)
	notice_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	notice_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	notice.add_child(notice_icon)
	var notice_name := _hud_label(notice, Vector2(76, 8), Vector2(238, 31), 20, HORIZONTAL_ALIGNMENT_LEFT)
	notice_name.name = "SpellNoticeName"
	var notice_text := _hud_label(notice, Vector2(76, 42), Vector2(238, 34), 15, HORIZONTAL_ALIGNMENT_LEFT)
	notice_text.name = "SpellNoticeText"
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
	var font_path := "res://assets/fonts/Oswald-Bold.woff2" if font_size >= 30 else "res://assets/fonts/Oswald-Medium.woff2"
	var hud_font := ThemeBuilder.font(font_path.get_file())
	if hud_font != null: label.add_theme_font_override("font", hud_font)
	root.add_child(label)
	return label

func _finish_match(server_ranking: Array = [], server_awards: Dictionary = {}) -> void:
	if state in ["match_end", "results"]: return
	results_ranking.assign(server_ranking if not server_ranking.is_empty() else MatchRanking.rank(players))
	var place := 1
	for i in range(results_ranking.size()):
		if results_ranking[i].name == Profile.nick: place = i + 1
	results_xp = Profile.award_match(place, players[local_player].max_combo)
	results_awards = server_awards if not server_awards.is_empty() else MatchRanking.awards(players)
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
	results_characters.clear()
	results_bubbles.clear()
	results_emote_cooldown = 0.0
	var root := _new_overlay()
	var backdrop := TextureRect.new()
	backdrop.texture = load("res://assets/ui/resultados_fondo.png")
	backdrop.size = Vector2(1280.0, 720.0)
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(backdrop)
	root.move_child(backdrop, 0)
	var podium := TextureRect.new()
	podium.texture = load("res://assets/ui/podio.png")
	podium.position = Vector2(280.0, 413.0)
	podium.size = Vector2(720.0, 267.0)
	podium.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	podium.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(podium)
	_label(root, I18n.t("winner_named") % String(results_ranking[0].get("name", "")), Vector2(0, 26), 44, GameConfig.GOLD, true)
	var podium_rank_for_player: Array[int] = []
	for place_index in range(results_ranking.size()):
		var player: Dictionary = results_ranking[place_index]
		var place := place_index + 1
		var center: Vector2 = GameConfig.RESULTS_PODIUM_TOPS.get(place, Vector2(1100.0, 602.0))
		var sprite := TextureRect.new()
		sprite.name = "ResultCharacter%d" % place_index
		sprite.position = center - Vector2(GameConfig.RESULTS_CHARACTER_SIZE.x * 0.5, GameConfig.RESULTS_CHARACTER_SIZE.y)
		sprite.size = GameConfig.RESULTS_CHARACTER_SIZE
		sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(sprite)
		results_characters.append(sprite)
		podium_rank_for_player.append(place_index)
		_update_result_character(place_index, "win" if place == 1 else ("hurt" if place == 4 else "idle"))
		var plaque_x := center.x - 96.0
		if place == 4: plaque_x = 1000.0
		var plaque := Panel.new()
		plaque.position = Vector2(plaque_x, 590.0 if place < 4 else 555.0)
		plaque.size = Vector2(192.0, 48.0)
		var style := StyleBoxFlat.new()
		style.bg_color = Color("241838", 0.94)
		style.border_color = Color("8a6b45")
		style.set_border_width_all(2)
		style.set_corner_radius_all(8)
		plaque.add_theme_stylebox_override("panel", style)
		root.add_child(plaque)
		var name_label := _hud_label(plaque, Vector2(8.0, 0.0), Vector2(120.0, 48.0), 17, HORIZONTAL_ALIGNMENT_LEFT)
		name_label.text = String(player.get("name", ""))
		var coin_icon := TextureRect.new()
		var coin_atlas := AtlasTexture.new()
		coin_atlas.atlas = COIN_TEXTURE
		coin_atlas.region = Rect2(0.0, 0.0, 64.0, 64.0)
		coin_icon.texture = coin_atlas
		coin_icon.position = Vector2(128.0, 11.0)
		coin_icon.size = Vector2(26.0, 26.0)
		coin_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		coin_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		plaque.add_child(coin_icon)
		var score_label := _hud_label(plaque, Vector2(151.0, 0.0), Vector2(34.0, 48.0), 18, HORIZONTAL_ALIGNMENT_RIGHT)
		score_label.text = str(int(player.get("score", 0)))
		score_label.add_theme_color_override("font_color", GameConfig.GOLD)
		if place == 1:
			var crown := TextureRect.new()
			crown.texture = load("res://assets/characters/crown.png")
			crown.position = center + Vector2(-24.0, -GameConfig.RESULTS_CHARACTER_SIZE.y - 30.0)
			crown.size = Vector2(48.0, 32.0)
			crown.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			crown.mouse_filter = Control.MOUSE_FILTER_IGNORE
			root.add_child(crown)
	if not Profile.new_unlocks.is_empty(): _add_unlock_card(root, Profile.new_unlocks[0])
	_build_result_emote_bar(root)
	var main_button := _button(root, I18n.t("main_menu"), Vector2(0.0, 600.0), _build_menu)
	main_button.position = Vector2(920.0, 632.0)
	main_button.size = Vector2(170.0, 54.0)
	var again_button := _button(root, I18n.t("again"), Vector2(0.0, 600.0), func():
		if network_match: Net.lobby_action.rpc_id(1, "rematch")
		else: _build_online()
	)
	again_button.position = Vector2(1100.0, 632.0)
	again_button.size = Vector2(150.0, 54.0)
	main_button.grab_focus()
	result_bot_emote_at.clear()
	for player in results_ranking:
		result_bot_emote_at.append(rng.randf_range(2.0, 10.0) if bool(player.get("is_bot", false)) else -1.0)
	for index in range(results_characters.size()):
		var character_node := results_characters[index]
		var target_y := character_node.position.y
		character_node.position.y = -150.0 - index * 35.0
		if not Settings.reduce_motion:
			var tween := create_tween()
			tween.tween_interval(index * 0.3)
			tween.tween_property(character_node, "position:y", target_y, 0.65).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		else:
			character_node.position.y = target_y

func _update_result_character(index: int, animation_name: String) -> void:
	if index < 0 or index >= results_characters.size(): return
	var player: Dictionary = results_ranking[index]
	var sheet: Texture2D = character_sheets.get("%s_%s" % [player.get("character", "mago"), player.get("sprite_color", "coral")])
	if sheet == null: return
	var anim: Dictionary = character_metadata.get("animations", {}).get(animation_name, {"row": 0, "frames": 6, "fps": 6})
	var frame_w := int(character_metadata.get("frame_w", 224))
	var frame_h := int(character_metadata.get("frame_h", 256))
	var frame := posmod(floori(results_elapsed * float(anim.get("fps", 6))), int(anim.get("frames", 1)))
	var atlas := AtlasTexture.new()
	atlas.atlas = sheet
	atlas.region = Rect2(frame * frame_w, int(anim.get("row", 0)) * frame_h, frame_w, frame_h)
	results_characters[index].texture = atlas

func _build_result_emote_bar(root: Control) -> void:
	var equipped: Array = Profile.cosmetics.get("emotes", ["risa", "enfado", "gg", "corazon"])
	for index in range(4):
		var emote_id := String(equipped[index]) if index < equipped.size() else "risa"
		var icon := _result_emote_icon(emote_id)
		icon.position = Vector2(20.0 + index * 66.0, GameConfig.RESULTS_EMOTE_BAR_Y)
		icon.size = Vector2(48.0, 48.0)
		root.add_child(icon)
		var key := _hud_label(root, Vector2(20.0 + index * 66.0, 690.0), Vector2(48.0, 24.0), 16, HORIZONTAL_ALIGNMENT_CENTER)
		key.text = str(index + 1)

func _result_emote_icon(emote_id: String) -> TextureRect:
	var icon := TextureRect.new()
	var atlas := AtlasTexture.new()
	atlas.atlas = load("res://assets/ui/emotes.png")
	var ids := ["risa", "enfado", "llanto", "corazon", "gg", "calavera", "pulgar", "fuego"]
	var frame := ids.find(emote_id)
	if frame < 0: frame = 0
	atlas.region = Rect2(frame * 128.0, 0.0, 128.0, 128.0)
	icon.texture = atlas
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon

func _launch_result_emote(index: int) -> void:
	if index < 0 or index >= 4 or results_emote_cooldown > 0.0: return
	var equipped: Array = Profile.cosmetics.get("emotes", ["risa", "enfado", "gg", "corazon"])
	if equipped.is_empty(): return
	var emote_id := String(equipped[posmod(index, equipped.size())])
	if network_match: Net.lobby_action.rpc_id(1, "social", {"item": emote_id})
	else:
		for place in results_ranking.size():
			if str(results_ranking[place].name) == Profile.nick: _add_result_emote(place, emote_id)
	results_emote_cooldown = GameConfig.RESULTS_EMOTE_COOLDOWN
	results_elapsed = 0.0

func _add_result_emote(index: int, emote_id: String) -> void:
	if index < 0 or index >= results_characters.size(): return
	var bubble := _result_emote_icon(emote_id)
	bubble.size = Vector2.ONE * GameConfig.RESULTS_EMOTE_SIZE
	bubble.position = results_characters[index].position + Vector2(24.0, -48.0)
	hud_root.add_child(bubble)
	results_bubbles.append({"node": bubble, "player": index, "time": GameConfig.RESULTS_EMOTE_SECONDS})

func _update_result_emotes(delta: float) -> void:
	for index in range(results_characters.size()): _update_result_character(index, "win" if index == 0 else ("hurt" if index == 3 else "idle"))
	for index in range(results_bubbles.size() - 1, -1, -1):
		var bubble: Dictionary = results_bubbles[index]
		bubble.time = float(bubble.time) - delta
		var char_index := int(bubble.player)
		if char_index < results_characters.size(): (bubble.node as Control).position = results_characters[char_index].position + Vector2(24.0, -48.0)
		if float(bubble.time) <= 0.0:
			(bubble.node as Control).queue_free()
			results_bubbles.remove_at(index)
	for index in range(results_ranking.size()):
		if index < result_bot_emote_at.size() and result_bot_emote_at[index] >= 0.0 and results_elapsed >= result_bot_emote_at[index]:
			var ids := ["risa", "enfado", "llanto", "corazon", "gg", "calavera", "pulgar", "fuego"]
			_add_result_emote(index, ids[rng.randi_range(0, ids.size() - 1)])
			result_bot_emote_at[index] = results_elapsed + rng.randf_range(4.0, 8.0)

func _add_unlock_card(root: Control, unlock: Dictionary) -> void:
	var card := Panel.new()
	card.position = Vector2(24.0, 505.0)
	card.size = Vector2(230.0, 112.0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("241838", 0.96)
	style.border_color = GameConfig.GOLD
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	card.add_theme_stylebox_override("panel", style)
	root.add_child(card)
	var title := _hud_label(card, Vector2(8, 2), Vector2(214, 32), 17, HORIZONTAL_ALIGNMENT_CENTER)
	title.text = I18n.t("unlock_new")
	if String(unlock.type) == "frame":
		var frame := TextureRect.new()
		frame.texture = load("res://assets/ui/marco_%s.png" % ("hueso" if String(unlock.id) == "calavera" else unlock.id))
		frame.position = Vector2(80, 35)
		frame.size = Vector2(68, 68)
		frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(frame)
	elif String(unlock.type) == "emote":
		var emote_icon := _result_emote_icon(String(unlock.id))
		emote_icon.position = Vector2(82, 35)
		emote_icon.size = Vector2(64, 64)
		card.add_child(emote_icon)
	else:
		var trail_swatch := ColorRect.new()
		trail_swatch.position = Vector2(102, 46)
		trail_swatch.size = Vector2(24, 48)
		trail_swatch.color = {"oro": GameConfig.GOLD, "escarcha": Color("7fe7ff"), "almas": Color("b06bff")}.get(String(unlock.id), Color.WHITE)
		card.add_child(trail_swatch)
	var name := _hud_label(card, Vector2(6, 75), Vector2(218, 30), 16, HORIZONTAL_ALIGNMENT_CENTER)
	name.text = I18n.t("cosmetic_" + String(unlock.id))

func _end_match_cleanup() -> void:
	Fx.clear_text()
	players.clear()
	coins.clear()
	chests.clear()
	chest_fade_alpha.clear()
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
	safe_zone_step = 0
	safe_zone_warning_step = 0
	fog_material = null
	end_wait = 0.0
	bots_dash_global_left = 0.0
	score_name_labels.clear()
	score_tag_labels.clear()
	score_number_labels.clear()
	score_portraits.clear()
	score_frames.clear()
	score_frame_skulls.clear()
	score_crowns.clear()
	score_values.clear()
	score_change_times.clear()
	queue_redraw()

func _add_dash_trail(position: Vector2, player_color: Color) -> void:
	var trail_id := String(Profile.cosmetics.get("trail", "color"))
	var trail_color := player_color
	if trail_id == "oro": trail_color = GameConfig.GOLD
	elif trail_id == "escarcha": trail_color = Color("7fe7ff")
	elif trail_id == "almas": trail_color = Color("b06bff")
	dash_trails.append({"pos": position, "color": trail_color, "time": GameConfig.DASH_TRAIL_LIFETIME})

func _update_dash_trails(delta: float) -> void:
	dash_trail_emit = maxf(0.0, dash_trail_emit - delta)
	for index in range(dash_trails.size() - 1, -1, -1):
		dash_trails[index].time = float(dash_trails[index].time) - delta
		if float(dash_trails[index].time) <= 0.0: dash_trails.remove_at(index)

func _screen_backdrop() -> ColorRect:
	var backdrop := ColorRect.new()
	backdrop.color = GameConfig.BACKGROUND
	backdrop.size = Vector2(1280, 720)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return backdrop

func _draw() -> void:
	if state in ["menu", "results", "match_end", "nickname"]:
		draw_rect(Rect2(Vector2.ZERO, Vector2(1280, 720)), GameConfig.BACKGROUND)
		return
	draw_rect(Rect2(Vector2.ZERO, Vector2(1280, 720)), GameConfig.BACKGROUND)
	draw_set_transform(OFFSET)
	if arena_background != null:
		draw_texture_rect(arena_background, Rect2(-40.0, -40.0, 1280.0, 680.0), false)
	else:
		draw_rect(Rect2(Vector2.ZERO, GameConfig.ARENA_SIZE), Color("2b3a2a"))
	_draw_arena_hazards()
	for trail in dash_trails:
		var alpha := clampf(float(trail.time) / GameConfig.DASH_TRAIL_LIFETIME, 0.0, 1.0)
		var color: Color = trail.color
		color.a = alpha * 0.72
		draw_circle(trail.pos, GameConfig.DASH_TRAIL_RADIUS * alpha, color)
	for coin in coins:
		var pos: Vector2 = coin.pos
		var phase := float(coin.get("phase", 0.0))
		draw_texture_rect(COIN_SHADOW_TEXTURE, Rect2(pos + Vector2(-16.0, 5.0), Vector2(32.0, 12.0)), false)
		var coin_bounce := GameConfig.COIN_BOB_PIXELS * absf(sin(elapsed * GameConfig.COIN_BOB_SPEED + phase))
		var coin_meta: Dictionary = item_metadata.get("doblon", {})
		var coin_size := Vector2(int(coin_meta.get("frame_w", 64)), int(coin_meta.get("frame_h", 64)))
		_draw_strip_frame(COIN_TEXTURE, coin_size, floori(elapsed * float(coin_meta.get("fps", 10.0)) + phase), pos - Vector2(0.0, coin_bounce), float(coin_meta.get("scale", 0.5)), int(coin_meta.get("frames", 8)), Color(1.0, 1.0, 1.0, float(coin.get("fade_alpha", 1.0))))
	for chest_index in range(chests.size()):
		var chest: Vector2 = chests[chest_index]
		var chest_meta: Dictionary = item_metadata.get("cofre", {})
		var chest_size := Vector2(int(chest_meta.get("frame_w", 224)), int(chest_meta.get("frame_h", 256)))
		var chest_bounce := GameConfig.CHEST_BOB_PIXELS * sin(elapsed * GameConfig.CHEST_BOB_SPEED)
		_draw_strip_frame(CHEST_TEXTURE, chest_size, 0, chest - Vector2(0.0, chest_bounce), float(chest_meta.get("scale", 0.5)), int(chest_meta.get("frames", 6)), Color(1.0, 1.0, 1.0, chest_fade_alpha[chest_index]))
	for chest in opened_chests:
		var opened_meta: Dictionary = item_metadata.get("cofre", {})
		var opened_size := Vector2(int(opened_meta.get("frame_w", 224)), int(opened_meta.get("frame_h", 256)))
		var progress: float = clampf(float(chest.elapsed) / GameConfig.CHEST_OPEN_SECONDS, 0.0, 0.999)
		var opening_frame := 1 + mini(4, floori(progress * 5.0))
		_draw_strip_frame(CHEST_TEXTURE, opened_size, opening_frame, chest.pos, float(opened_meta.get("scale", 0.5)), int(opened_meta.get("frames", 6)))
	for i in range(players.size()):
		if bool(players[i].get("disconnected", false)): continue
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
		var name_color: Color = player.color if i == local_player else Color.WHITE
		var name_text := (I18n.t("you") + " · " if i == local_player else "") + String(player.name)
		var name_font: Font = player_name_font if player_name_font != null else ThemeDB.fallback_font
		var name_size := GameConfig.PLAYER_LOCAL_NAME_FONT_SIZE if i == local_player else GameConfig.PLAYER_NAME_FONT_SIZE
		var name_position: Vector2 = pos + Vector2(-GameConfig.PLAYER_NAME_WIDTH * 0.5, GameConfig.PLAYER_NAME_Y)
		draw_string_outline(name_font, name_position, name_text, HORIZONTAL_ALIGNMENT_CENTER, GameConfig.PLAYER_NAME_WIDTH, name_size, GameConfig.PLAYER_NAME_OUTLINE_SIZE, GameConfig.PLAYER_NAME_OUTLINE_COLOR)
		draw_string(name_font, name_position, name_text, HORIZONTAL_ALIGNMENT_CENTER, GameConfig.PLAYER_NAME_WIDTH, name_size, name_color)
		if i == local_player:
			var arrow_center: Vector2 = pos + Vector2(0.0, GameConfig.PLAYER_NAME_Y - GameConfig.PLAYER_LOCAL_NAME_FONT_SIZE - GameConfig.PLAYER_ARROW_NAME_GAP)
			draw_colored_polygon(PackedVector2Array([arrow_center + Vector2(-GameConfig.PLAYER_ARROW_HALF_WIDTH, -GameConfig.PLAYER_ARROW_HEAD_HEIGHT), arrow_center + Vector2(GameConfig.PLAYER_ARROW_HALF_WIDTH, -GameConfig.PLAYER_ARROW_HEAD_HEIGHT), arrow_center + Vector2(0.0, GameConfig.PLAYER_ARROW_TIP_LENGTH)]), name_color)
			var aura_center: Vector2 = pos + Vector2(0.0, GameConfig.PLAYER_AURA_CENTER_Y)
			var aura_alpha := GameConfig.PLAYER_AURA_REDUCED_ALPHA if Settings.reduce_motion else (GameConfig.PLAYER_AURA_MIN_ALPHA + GameConfig.PLAYER_AURA_ALPHA_RANGE * (sin(elapsed * GameConfig.PLAYER_AURA_PULSE_SPEED) * 0.5 + 0.5))
			draw_arc(aura_center, GameConfig.PLAYER_AURA_RADIUS, 0.0, TAU, GameConfig.PLAYER_AURA_SEGMENTS, Color(name_color, aura_alpha), GameConfig.PLAYER_AURA_WIDTH, true)
		draw_string(ThemeDB.fallback_font, pos + Vector2(-8, 34), player.shape, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color.WHITE)
		if i == local_player and player.combo > 1:
			var badge_center: Vector2 = pos + GameConfig.COMBO_BADGE_OFFSET
			draw_circle(badge_center, GameConfig.COMBO_BADGE_RADIUS, Color("241838", 0.92))
			draw_arc(badge_center, GameConfig.COMBO_BADGE_RADIUS, 0.0, TAU, GameConfig.PLAYER_AURA_SEGMENTS, GameConfig.GOLD, GameConfig.COMBO_BADGE_OUTLINE_WIDTH, true)
			var badge_text_position := badge_center + Vector2(-GameConfig.COMBO_BADGE_RADIUS, GameConfig.COMBO_BADGE_TEXT_OFFSET_Y)
			var badge_text_width := GameConfig.COMBO_BADGE_RADIUS * GameConfig.COMBO_BADGE_DIAMETER_FACTOR
			draw_string(floating_coin_font if floating_coin_font != null else ThemeDB.fallback_font, badge_text_position, "x%d" % Scoring.multiplier(player.combo, mode == "classic"), HORIZONTAL_ALIGNMENT_CENTER, badge_text_width, GameConfig.COMBO_BADGE_TEXT_SIZE, Color.WHITE)
			draw_string(ThemeDB.fallback_font, badge_center + Vector2(-GameConfig.COMBO_BADGE_RADIUS, GameConfig.COMBO_BADGE_TEXT_BOTTOM_Y), str(player.combo), HORIZONTAL_ALIGNMENT_CENTER, badge_text_width, GameConfig.COMBO_BADGE_COUNT_SIZE, GameConfig.GOLD)
		if i == _leader_index() and mode == "voodoo":
			draw_string(ThemeDB.fallback_font, pos + Vector2(-8, -30), "👑", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, GameConfig.GOLD)
	if safe_zone_warning_step > safe_zone_step:
		var warning_rect := ZoneRules.safe_rect(safe_zone_step + 1)
		var warning_alpha := 0.78 if Settings.reduce_motion else (0.55 + 0.45 * sin(elapsed * GameConfig.ZONE_WARNING_FLASH_SPEED))
		draw_rect(warning_rect, Color(GameConfig.ZONE_WARNING_COLOR, warning_alpha), false, GameConfig.ZONE_WARNING_LINE_WIDTH)
	if roll_time > 0.0 and roll_player >= 0 and roll_player < players.size():
		var spell_meta: Dictionary = item_metadata.get("hechizos", {})
		var spell_size := Vector2(int(spell_meta.get("frame_w", 128)), int(spell_meta.get("frame_h", 128)))
		var roll_frame := posmod(floori(elapsed * 20.0), ITEMS.size())
		_draw_strip_frame(SPELL_TEXTURE, spell_size, roll_frame, players[roll_player].pos + Vector2(0.0, -94.0), 0.5, ITEMS.size())
	if mode == "voodoo" and remaining <= 15.0:
		draw_rect(Rect2(Vector2.ZERO, GameConfig.ARENA_SIZE), Color(1.0, 0.72, 0.12, 0.035 + 0.025 * sin(elapsed * 8.0)), false, 7.0)
	draw_set_transform(Vector2.ZERO)
	for effect in floating:
		var duration := float(effect.duration)
		var age := duration - float(effect.time)
		var pop := 1.0 if Settings.reduce_motion else (GameConfig.FLOAT_POP_SCALE if age <= 0.0 else (1.0 + (GameConfig.FLOAT_POP_SCALE - 1.0) * maxf(0.0, 1.0 - age / GameConfig.FLOAT_POP_SECONDS)))
		var alpha := clampf(float(effect.time) / GameConfig.FLOAT_FADE_SECONDS, 0.0, 1.0)
		var color := Color(effect.color, alpha)
		if bool(effect.is_coin):
			var points := int(String(effect.text).trim_prefix("+"))
			var coin_font_size := GameConfig.FLOAT_COIN_BONUS_FONT_SIZE if points >= 3 else GameConfig.FLOAT_COIN_FONT_SIZE
			var font := floating_coin_font if floating_coin_font != null else ThemeDB.fallback_font
			var text_position: Vector2 = effect.pos - Vector2(GameConfig.FLOAT_COIN_TEXT_WIDTH * 0.5, 0.0)
			draw_string_outline(font, text_position, effect.text, HORIZONTAL_ALIGNMENT_CENTER, GameConfig.FLOAT_COIN_TEXT_WIDTH, roundi(coin_font_size * pop), GameConfig.FLOAT_COIN_OUTLINE_SIZE, Color(GameConfig.PLAYER_NAME_OUTLINE_COLOR, alpha))
			draw_string(font, text_position, effect.text, HORIZONTAL_ALIGNMENT_CENTER, GameConfig.FLOAT_COIN_TEXT_WIDTH, roundi(coin_font_size * pop), color)
		else:
			var notice_font_size := GameConfig.FLOAT_NOTICE_LARGE_FONT_SIZE if String(effect.text) in [I18n.t("voodoo_combo"), I18n.t("frenzy")] else GameConfig.FLOAT_NOTICE_FONT_SIZE
			var font := floating_notice_font if floating_notice_font != null else ThemeDB.fallback_font
			var text_position: Vector2 = effect.pos - Vector2(GameConfig.FLOAT_NOTICE_TEXT_WIDTH * 0.5, 0.0)
			draw_string_outline(font, text_position, effect.text, HORIZONTAL_ALIGNMENT_CENTER, GameConfig.FLOAT_NOTICE_TEXT_WIDTH, roundi(notice_font_size * pop), GameConfig.FLOAT_NOTICE_OUTLINE_SIZE, Color(GameConfig.PLAYER_NAME_OUTLINE_COLOR, alpha))
			draw_string(font, text_position, effect.text, HORIZONTAL_ALIGNMENT_CENTER, GameConfig.FLOAT_NOTICE_TEXT_WIDTH, roundi(notice_font_size * pop), color)
	if state == "countdown":
		var count_text := I18n.t("ready") if countdown < 1.0 else str(ceili(countdown))
		draw_string(ThemeDB.fallback_font, Vector2(570, 370), count_text, HORIZONTAL_ALIGNMENT_CENTER, 160, 68, Color.WHITE)
	else:
		draw_set_transform(Vector2.ZERO)

func _draw_strip_frame(texture: Texture2D, frame_size: Vector2, frame_index: int, center: Vector2, scale_factor: float, frame_count: int, modulate: Color = Color.WHITE) -> void:
	if texture == null or frame_count <= 0:
		return
	var frame := posmod(frame_index, frame_count)
	var draw_size := frame_size * scale_factor
	draw_texture_rect_region(texture, Rect2(center - draw_size * 0.5, draw_size), Rect2(frame * frame_size.x, 0.0, frame_size.x, frame_size.y), modulate)

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
			var belt_tiles: Array = hazard.get("tiles", [])
			var belt_direction := _json_point(hazard.get("dir", [1.0, 0.0]))
			for tile_index in range(belt_tiles.size()):
				var tile: Variant = belt_tiles[tile_index]
				var parts: Variant = tile if tile is Array else String(tile).split(" ", false)
				if parts.size() >= 4:
					var tile_center := Vector2(float(parts[0]) + float(parts[2]) * 0.5, float(parts[1]) + float(parts[3]) * 0.5)
					_draw_hazard_sprite("cinta", tile_center, floori(elapsed * 8.0), belt_direction.x < 0.0)
					if tile_index == 0 or tile_index == belt_tiles.size() - 1:
						_draw_hazard_sprite("cinta_rodillo", tile_center, floori(elapsed * 8.0))
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

func _draw_hazard_sprite(sprite_id: String, center: Vector2, frame_index: int = 0, flip_h: bool = false) -> void:
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
	var source := Rect2(frame * frame_width, 0, frame_width, frame_height)
	if flip_h:
		draw_set_transform(center + OFFSET, 0.0, Vector2(-1.0, 1.0))
		draw_texture_rect_region(texture, Rect2(-frame_size.x * 0.5, -frame_size.y * 0.5, frame_size.x, frame_size.y), source)
		draw_set_transform(OFFSET)
	else:
		draw_texture_rect_region(texture, Rect2(center - frame_size * 0.5, frame_size), source)

func _json_point(value: Variant) -> Vector2:
	if value is Array and value.size() >= 2:
		return Vector2(float(value[0]), float(value[1]))
	return Vector2.ZERO

func _tile_rect(tile: Variant) -> Rect2:
	var values: Variant = tile if tile is Array else String(tile).split(" ", false)
	if values.size() < 4:
		return Rect2()
	return Rect2(Vector2(float(values[0]), float(values[1])), Vector2(float(values[2]), float(values[3])))

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
		draw_set_transform(center + OFFSET, angle + float(arm) * PI, Vector2.ONE * float(info.get("scale", 0.5)))
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
	if menu_logo_tween != null and menu_logo_tween.is_running(): menu_logo_tween.kill()
	menu_logo_tween = null
	if is_instance_valid(hud): hud.queue_free()

func _label(root: Control, text: String, offset: Vector2, size: int, tint: Color, _bold: bool) -> Label:
	var label := Label.new()
	label.text = text
	label.position = Vector2(240, 0) + offset
	label.size = Vector2(800, 52)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", roundi(size * Settings.ui_scale))
	var label_font_path := "res://assets/fonts/Oswald-Bold.woff2" if _bold else "res://assets/fonts/Oswald-Medium.woff2"
	var label_font := ThemeBuilder.title_font(roundi(size * Settings.ui_scale)) if _bold else ThemeBuilder.font("Oswald-Medium.woff2")
	if label_font != null: label.add_theme_font_override("font", label_font)
	label.add_theme_color_override("font_color", GameConfig.BONE_TEXT if tint == GameConfig.GOLD else tint)
	label.add_theme_color_override("font_shadow_color", Color("160e22"))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 3)
	root.add_child(label)
	return label

func _button(root: Control, text: String, offset: Vector2, action: Callable) -> Button:
	var button := Button.new()
	button.set_script(preload("res://ui/widgets/ember_button.gd"))
	button.text = text
	button.position = Vector2(470, 0) + offset
	button.size = Vector2(340, 54)
	button.add_theme_font_size_override("font_size", roundi(26 * Settings.ui_scale))
	var menu_font := ThemeBuilder.title_font(roundi(26 * Settings.ui_scale), true)
	if menu_font != null: button.add_theme_font_override("font", menu_font)
	button.focus_mode = Control.FOCUS_ALL
	button.pressed.connect(func(): Sfx.play_tone(300.0, 0.07); action.call())
	button.focus_entered.connect(func(): Sfx.play_tone(470.0, 0.045))
	root.add_child(button)
	if not root.has_meta("focus_set"):
		button.grab_focus()
		root.set_meta("focus_set", true)
	return button

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
	Fx.render_pop(text, world_pos, Color("7fe7ff") if text == I18n.t("trap_zap") else tint)

func _animate_score(label: Label, old_value: int, value: int) -> void:
	if label.has_meta("score_tween"):
		(label.get_meta("score_tween") as Tween).kill()
	var origin: Vector2 = label.get_meta("score_origin", label.position)
	label.set_meta("score_origin", origin)
	label.position = origin
	label.pivot_offset = label.size * 0.5
	label.scale = Vector2.ONE
	var tint := GameConfig.LOSS_TEXT if value < old_value else GameConfig.EMBER
	label.add_theme_color_override("font_color", GameConfig.BONE_TEXT if tint == GameConfig.GOLD else tint)
	var tween := label.create_tween().set_parallel(true)
	label.set_meta("score_tween", tween)
	tween.tween_method(func(display_value: float): label.text = str(roundi(display_value)), float(old_value), float(value), 0.3)
	tween.tween_method(func(color: Color): label.add_theme_color_override("font_color", color), tint, GameConfig.BONE_TEXT, 0.35)
	if not Settings.reduce_motion:
		label.scale = Vector2.ONE * 1.24
		tween.tween_property(label, "scale", Vector2.ONE, 0.17)
		if value < old_value:
			tween.tween_method(func(t: float): label.position.x = origin.x + sin(t * TAU * 4.0) * 3.0 * (1.0 - t), 0.0, 1.0, 0.2)

func _on_shake(amount: float) -> void:
	if not Settings.reduce_motion:
		position = Vector2(randf_range(-amount, amount), randf_range(-amount, amount))
		get_tree().create_timer(0.15).timeout.connect(func(): position = Vector2.ZERO)

func _animate_floating(delta: float) -> void:
	for i in range(floating.size() - 1, -1, -1):
		floating[i].time -= delta
		if not Settings.reduce_motion:
			floating[i].pos.y -= GameConfig.FLOAT_RISE_PIXELS / float(floating[i].duration) * delta
		if floating[i].time <= 0.0: floating.remove_at(i)

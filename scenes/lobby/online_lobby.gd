class_name OnlineLobby
extends Control

signal exit_requested
signal locker_requested
signal local_match_requested(config: Dictionary)
signal online_match_requested(state: Dictionary)

var local := false
var room: Dictionary = {}
var local_directory := RoomDirectory.new()
var elapsed := 0.0
var social: Dictionary = {}
var sheets: Dictionary = {}
var roster: Array[Dictionary] = []
var view: Control
var notice: Label
var code_field: LineEdit
var ip_field: LineEdit
var wheel: Control
var clock_label: Label
var local_id := 2
var wheel_index := 0
var social_at := -1.0
var connecting_action := ""
var target_address := ""
var connection_pending := false
var connection_elapsed := 0.0
var retry_elapsed := 0.0
var hosting_here := false
var local_host_ip := ""
var pending_mode := "voodoo"
var local_vote: ArenaVote
var vote_view: ArenaVoteView
var background := preload("res://assets/ui/lobby_mazmorra.png")

func _ready() -> void:
	size = Vector2(1280, 720)
	theme = ThemeBuilder.build()
	hosting_here = Net.hosted_server_pid > 0
	local_host_ip = Net.hosted_server_ip
	Net.connected.connect(_connected)
	Net.room_changed.connect(_room_changed)
	Net.room_failed.connect(_error)
	Net.disconnected.connect(_error)
	Net.events_received.connect(_events)
	if not Net.room.is_empty(): _room_changed(Net.room)
	else: _entry()

func _new_view() -> void:
	if is_instance_valid(view): remove_child(view); view.queue_free()
	view = Control.new()
	view.size = size
	add_child(view)
	notice = _label("", Vector2(80, 130), Vector2(1120, 60), 24)

func _label(value: String, at: Vector2, dimensions: Vector2, font_size: int = 24) -> Label:
	var node := Label.new()
	node.text = value
	node.position = at
	node.size = dimensions
	node.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	node.add_theme_font_size_override("font_size", font_size)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.add_child(node)
	return node

func _button(key: String, at: Vector2, dimensions: Vector2, action: Callable) -> Button:
	var node := Button.new()
	node.set_script(load("res://ui/widgets/ember_button.gd"))
	node.text = I18n.t(key)
	node.position = at
	node.size = dimensions
	node.pressed.connect(action)
	view.add_child(node)
	return node

func _entry() -> void:
	_new_view()
	_label(I18n.t("online"), Vector2(0, 55), Vector2(1280, 65), 40)
	_button("host_here", GameConfig.ONLINE_HOST_BUTTON_POSITION, GameConfig.ONLINE_ACTION_BUTTON_SIZE, func(): _mode_select("create")).grab_focus()
	ip_field = LineEdit.new()
	ip_field.max_length = GameConfig.SETTINGS_INPUT_MAX_LENGTH
	ip_field.placeholder_text = I18n.t("host_ip")
	ip_field.text = Settings.join_host
	ip_field.position = GameConfig.ONLINE_IP_FIELD_POSITION
	ip_field.size = GameConfig.ONLINE_IP_FIELD_SIZE
	ip_field.text_submitted.connect(func(value: String) -> void: Settings.join_host = value.strip_edges(); Settings.save(); _connect_to("join"))
	view.add_child(ip_field)
	code_field = LineEdit.new()
	code_field.max_length = GameConfig.ROOM_CODE_LENGTH
	code_field.placeholder_text = I18n.t("room_code")
	code_field.position = GameConfig.ONLINE_CODE_FIELD_POSITION
	code_field.size = GameConfig.ONLINE_CODE_FIELD_SIZE
	code_field.text_changed.connect(func(value: String):
		var caret := code_field.caret_column
		code_field.text = value.to_upper()
		code_field.caret_column = caret
	)
	view.add_child(code_field)
	_button("join_room", Vector2(390, 380), GameConfig.ONLINE_ACTION_BUTTON_SIZE, func(): _connect_to("join"))
	_button("bots", Vector2(390, 455), GameConfig.ONLINE_ACTION_BUTTON_SIZE, func(): _mode_select("bots"))
	_button("network_help", Vector2(390, 528), GameConfig.ONLINE_ACTION_BUTTON_SIZE, _open_network_help)
	_button("menu", Vector2(390, 600), GameConfig.ONLINE_ACTION_BUTTON_SIZE, func(): exit_requested.emit())

func _connect_to(action: String) -> void:
	if connection_pending: return
	connecting_action = action
	local = false
	hosting_here = action == "create"
	if hosting_here:
		local_host_ip = _find_private_ipv4()
		var server_pid := Net.start_host_server(Settings.server_port)
		if server_pid <= 0:
			hosting_here = false
			_error("host_start_failed")
			return
		Net.hosted_server_ip = local_host_ip
		target_address = "127.0.0.1"
	else:
		target_address = ip_field.text.strip_edges()
		if target_address.is_empty(): target_address = Settings.server_host
		Settings.join_host = ip_field.text.strip_edges()
		Settings.save()
	connection_pending = true
	connection_elapsed = 0.0
	retry_elapsed = 0.0
	notice.text = I18n.t("connecting")
	_attempt_connect()

func _attempt_connect() -> void:
	retry_elapsed = 0.0
	Net.join_server(target_address, Settings.server_port)

func _connected() -> void:
	if not connection_pending: return
	connection_pending = false
	local_id = multiplayer.get_unique_id()
	if connecting_action == "create":
		Net.create_room.rpc_id(1, Profile.nick, Profile.character, Profile.cosmetics, GameConfig.NET_VERSION, pending_mode)
	else:
		Net.join_room.rpc_id(1, code_field.text, Profile.nick, Profile.character, Profile.cosmetics, GameConfig.NET_VERSION)

func _mode_select(action: String) -> void:
	_new_view()
	_label(I18n.t("choose_mode"), Vector2(0, 52), Vector2(1280, 62), 42)
	var modes: Array = GameConfig.MODES
	var card_buttons: Array[Button] = []
	for index in modes.size():
		var mode_id := str(modes[index])
		var card := Panel.new()
		card.position = Vector2(GameConfig.MODE_CARD_X[index], GameConfig.MODE_CARD_Y)
		card.size = GameConfig.MODE_CARD_SIZE
		var style := StyleBoxFlat.new()
		style.bg_color = Color("241838")
		style.border_color = Color("5c496d")
		style.set_border_width_all(2)
		style.set_corner_radius_all(12)
		card.add_theme_stylebox_override("panel", style)
		view.add_child(card)
		_add_mode_illustration(mode_id, card.position + Vector2(132, 32))
		var name_label := _label(I18n.t(mode_id), card.position + Vector2(16, 150), Vector2(328, 48), GameConfig.MODE_CARD_TITLE_SIZE)
		name_label.add_theme_font_override("font", ThemeBuilder.title_font(GameConfig.MODE_CARD_TITLE_SIZE))
		name_label.add_theme_color_override("font_color", GameConfig.BONE_TEXT)
		var rules := _label(I18n.t("rules_" + mode_id), card.position + Vector2(24, 208), Vector2(312, 142), GameConfig.MODE_CARD_RULE_SIZE)
		rules.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var players_label := _label(I18n.t("mode_players_" + mode_id), card.position + Vector2(16, 358), Vector2(328, 40), GameConfig.MODE_CARD_PLAYERS_SIZE)
		players_label.add_theme_color_override("font_color", GameConfig.EMBER)
		var button := Button.new()
		button.set_script(load("res://ui/widgets/ember_button.gd"))
		button.position = card.position
		button.size = card.size
		button.text = ""
		button.tooltip_text = I18n.t(mode_id)
		button.focus_mode = Control.FOCUS_ALL
		for state_name in ["normal", "hover", "pressed", "focus", "disabled"]: button.add_theme_stylebox_override(state_name, StyleBoxEmpty.new())
		button.focus_entered.connect(func() -> void: style.border_color = GameConfig.EMBER; style.set_border_width_all(4))
		button.focus_exited.connect(func() -> void: style.border_color = Color("5c496d"); style.set_border_width_all(2))
		button.mouse_entered.connect(button.grab_focus)
		button.pressed.connect(func() -> void:
			pending_mode = mode_id
			if action == "bots": _local_room(mode_id)
			else: _connect_to("create")
		)
		view.add_child(button)
		card_buttons.append(button)
	_button("menu", Vector2(490, 638), Vector2(300, 54), _entry)
	if not card_buttons.is_empty(): card_buttons[0].grab_focus()

func _add_mode_illustration(mode_id: String, at: Vector2, include_detail: bool = true) -> void:
	if mode_id == "voodoo":
		var coin := TextureRect.new()
		coin.position = at
		coin.size = Vector2(GameConfig.MODE_CARD_ICON_SIZE, GameConfig.MODE_CARD_ICON_SIZE)
		coin.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		coin.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var atlas := AtlasTexture.new()
		atlas.atlas = load("res://assets/items/doblon.png")
		atlas.region = Rect2(0, 0, 64, 64)
		coin.texture = atlas
		view.add_child(coin)
		if include_detail:
			var combo := _label("x3", at + Vector2(82, 28), Vector2(110, 48), 34)
			combo.add_theme_color_override("font_color", GameConfig.EMBER)
	elif mode_id == "survival":
		var stitches := TextureRect.new()
		stitches.position = at + Vector2(5, 5)
		stitches.size = Vector2(84, 84)
		stitches.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		var atlas := AtlasTexture.new()
		atlas.atlas = load("res://assets/ui/costuras.png")
		atlas.region = Rect2(0, 0, 128, 128)
		stitches.texture = atlas
		view.add_child(stitches)
		if include_detail:
			var stitch_label := _label("×3", at + Vector2(88, 28), Vector2(80, 48), 32)
			stitch_label.add_theme_color_override("font_color", GameConfig.BONE_TEXT)
	else:
		for team in 2:
			var chest := TextureRect.new()
			chest.position = at + Vector2(team * 48, 7)
			chest.size = Vector2(58, 82)
			chest.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			chest.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			var chest_texture: Texture2D = load("res://assets/items/cofre_equipo_%s.png" % ("coral" if team == 0 else "azul"))
			var chest_atlas := AtlasTexture.new()
			chest_atlas.atlas = chest_texture
			chest_atlas.region = Rect2(0, 0, 224, 256)
			chest.texture = chest_atlas
			view.add_child(chest)

func _local_room(selected_mode: String = "voodoo") -> void:
	local = true
	local_id = 2
	room = local_directory.create(local_id, Profile.nick, Profile.character, Profile.cosmetics, GameConfig.NET_VERSION, selected_mode)
	room.bots = 3
	_room_changed(room)

func _room_changed(value: Dictionary) -> void:
	room = value
	if not local: local_id = multiplayer.get_unique_id()
	roster = LobbyRules.roster(room)
	_load_sheets()
	if room.phase == "voting":
		if not is_instance_valid(vote_view):
			_new_view()
			vote_view = ArenaVoteView.new()
			vote_view.roster = roster
			view.add_child(vote_view)
			vote_view.voted.connect(func(id: String):
				if local: local_vote.vote(local_id, id)
				else: Net.lobby_action.rpc_id(1, "vote", {"arena": id})
			)
		vote_view.update_state(local_vote.snapshot() if local else room.vote_state)
	elif room.phase == "loading":
		if local: local_match_requested.emit({"mode": room.mode, "arena_id": room.arena_id, "seed": local_vote.seed_value, "players": roster, "duration": room.duration})
		else: online_match_requested.emit(room)
	else: _build_room()

func _load_sheets() -> void:
	for index in roster.size():
		var color_index := int(roster[index].team) if room.get("mode") == "greed" else index
		var key := "%s_%s" % [roster[index].character, ["coral", "azul", "lima", "hueso"][color_index]]
		if not sheets.has(key): sheets[key] = load("res://assets/characters/" + key + ".png")

func _build_room() -> void:
	_new_view()
	if local:
		_label(I18n.t("bots_match"), Vector2(20, 30), Vector2(360, 60), 26)
	else:
		_label(I18n.t("room_code") + "  " + str(room.code), Vector2(20, 30), Vector2(360, 60), 26)
		_button("copy", Vector2(35, 94), Vector2(150, 42), func(): DisplayServer.clipboard_set(str(room.code)))
	if hosting_here:
		var address_text := local_host_ip if not local_host_ip.is_empty() else I18n.t("host_ip_none")
		_label(I18n.t("hosting_ip") % address_text, Vector2(20, 144), Vector2(375, 48), 18)
		_button("copy_ip", Vector2(25, 197), Vector2(160, 42), func(): if not local_host_ip.is_empty(): DisplayServer.clipboard_set(local_host_ip))
		_button("network_help", Vector2(195, 197), Vector2(200, 42), _open_network_help)
	var mode_panel := Panel.new()
	mode_panel.position = Vector2(430, 18)
	mode_panel.size = Vector2(408, 158)
	var mode_style := StyleBoxFlat.new()
	mode_style.bg_color = Color("241838")
	mode_style.border_color = GameConfig.EMBER if int(room.host) == local_id else Color("5c496d")
	mode_style.set_border_width_all(2)
	mode_style.set_corner_radius_all(10)
	mode_panel.add_theme_stylebox_override("panel", mode_style)
	view.add_child(mode_panel)
	_add_mode_illustration(str(room.mode), Vector2(445, 42), false)
	_label(I18n.t(str(room.mode)), Vector2(552, 28), Vector2(210, 38), 24).add_theme_font_override("font", ThemeBuilder.title_font(24))
	_label(I18n.t("rules_" + str(room.mode)), Vector2(552, 69), Vector2(210, 76), 17)
	var host_hint := _label("", Vector2(552, 146), Vector2(210, 24), 15)
	if int(room.host) != local_id: host_hint.text = I18n.t("host_chooses_mode")
	var mode_left := Button.new()
	mode_left.text = "‹"
	mode_left.position = Vector2(770, 32)
	mode_left.size = Vector2(28, 35)
	mode_left.pressed.connect(func(): _cycle_room_mode(-1))
	mode_left.disabled = int(room.host) != local_id
	view.add_child(mode_left)
	var mode_right := Button.new()
	mode_right.text = "›"
	mode_right.position = Vector2(805, 32)
	mode_right.size = Vector2(28, 35)
	mode_right.pressed.connect(func(): _cycle_room_mode(1))
	mode_right.disabled = int(room.host) != local_id
	view.add_child(mode_right)
	var duration := _button(str(room.duration) + " s",Vector2(870,40),Vector2(180,55),func(): _action("duration",{"seconds":GameConfig.MATCH_DURATIONS[(GameConfig.MATCH_DURATIONS.find(int(room.duration))+1)%3]}))
	duration.disabled = local_id != int(room.host) or room.mode == "survival"
	var order := _display_order()
	for slot in GameConfig.ROOM_CAPACITY:
		var center: Vector2 = GameConfig.LOBBY_PEDESTALS[slot]
		var index: int = order[slot]
		if index < 0:
			_label(I18n.t("invite"), center + Vector2(-100, -40), Vector2(200, 60))
			if local_id == int(room.host): _button("add_bot", center + Vector2(-110, 50), Vector2(220, 45), func(): _action("bots", {"count": int(room.bots) + 1}))
		else:
			var player: Dictionary = roster[index]
			if room.mode == "greed":
				var team := _button("team_" + str(player.team),center + Vector2(-110,-245),Vector2(220,45),func(): _action("team",{"index":index}))
				team.disabled = local_id != int(room.host) or bool(player.is_bot)
			_label(str(player.name), center + Vector2(-115, 14), Vector2(230, 36), 24)
			_label(I18n.t("lobby_ready") if bool(player.ready) else "…", center + Vector2(-115, 48), Vector2(230, 36), 22).modulate = Color("63a83a") if player.ready else Color.WHITE
			if int(player.peer_id) == int(room.host):
				var crown := TextureRect.new()
				crown.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				crown.texture = load("res://assets/characters/crown.png")
				crown.position = center + Vector2(-24, -190)
				crown.size = Vector2(48, 32)
				crown.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				view.add_child(crown)
	_button("characters", Vector2(40, 635), Vector2(240, 55), func(): locker_requested.emit())
	_button("lobby_ready", Vector2(320, 625), Vector2(350, 70), func(): _action("ready")).grab_focus()
	_button("dances", Vector2(700, 635), Vector2(240, 55), _open_wheel)
	_button("exit", Vector2(990, 635), Vector2(240, 55), _leave)
	_label(I18n.t("wheel"), Vector2(300, 590), Vector2(680, 35), 18)

func _display_order() -> Array[int]:
	if room.get("mode") == "greed":
		var teams: Array[int] = []
		for team in 2:
			for index in roster.size():
				if int(roster[index].team) == team: teams.append(index)
		while teams.size() < 4: teams.append(-1)
		return teams
	var order: Array[int] = [-1, -1, -1, -1]
	var others: Array[int] = []
	for index in roster.size():
		if int(roster[index].peer_id) == local_id: order[1] = index
		else: others.append(index)
	var slots := [0, 2, 3]
	for index in others.size(): order[slots[index]] = others[index]
	return order

func _cycle_room_mode(step: int) -> void:
	if int(room.host) != local_id: return
	var current := GameConfig.MODES.find(str(room.mode))
	var next_index := posmod(current + step, GameConfig.MODES.size())
	_action("mode", {"mode":GameConfig.MODES[next_index]})

func _action(action: String, data: Dictionary = {}) -> void:
	if local:
		if LobbyRules.apply(room, local_id, action, data):
			if LobbyRules.all_ready(room):
				local_vote = ArenaVote.new()
				local_vote.setup(randi(), LobbyRules.roster(room))
				room.phase = "voting"
			_room_changed(room)
	else: Net.lobby_action.rpc_id(1, action, data)

func _leave() -> void:
	if not local and Net.peer != null:
		Net.leave_room.rpc_id(1)
	Net.leave_server()
	Net.stop_host_server()
	hosting_here = false
	exit_requested.emit()

func _error(reason: String) -> void:
	if reason == "connect_failed" and connection_pending: return
	if reason == "host_start_failed":
		notice.text = I18n.t("host_start_failed")
		return
	if reason.begins_with("version:"):
		notice.text = I18n.t("version_mismatch_detail") % [GameConfig.PROJECT_VERSION, reason.trim_prefix("version:")]
		return
	if reason == "server_lost":
		room.clear()
		roster.clear()
		_entry()
		return
	notice.text = I18n.t("room_" + reason)

func _connection_failed() -> void:
	connection_pending = false
	Net.leave_server()
	if hosting_here:
		Net.stop_host_server()
		hosting_here = false
		notice.text = I18n.t("host_start_failed")
	else:
		notice.text = I18n.t("connect_failed_detail") % [target_address, Settings.server_port]

func _find_private_ipv4() -> String:
	for address: String in IP.get_local_addresses():
		var parts := address.split(".")
		if parts.size() != 4: continue
		var valid := true
		for part in parts:
			if not part.is_valid_int() or int(part) < 0 or int(part) > 255: valid = false
		if not valid: continue
		var first := int(parts[0])
		var second := int(parts[1])
		if first == 10 or (first == 172 and second >= 16 and second <= 31) or (first == 192 and second == 168): return address
	return ""

func _open_network_help() -> void:
	var dialog := AcceptDialog.new()
	dialog.title = I18n.t("network_help")
	dialog.dialog_text = I18n.t("network_help_text")
	get_tree().root.add_child(dialog)
	dialog.confirmed.connect(func() -> void: dialog.queue_free())
	dialog.close_requested.connect(func() -> void: dialog.queue_free())
	dialog.popup_centered(Vector2i(700, 440))

func _events(events: Array) -> void:
	for event: Dictionary in events:
		if event.get("type") == "social":
			social[int(event.peer_id)] = {"item": str(event.item), "time": elapsed}

func _social(item: String) -> void:
	if elapsed - social_at < GameConfig.SOCIAL_COOLDOWN: return
	social_at = elapsed
	if local: _events([{"type": "social", "peer_id": local_id, "item": item}])
	else: Net.lobby_action.rpc_id(1, "social", {"item": item})
	Sfx.play_tone(180.0 if item.begins_with("shout") else 440.0, 0.15)

func _open_wheel() -> void:
	if is_instance_valid(wheel): return
	wheel = Control.new()
	wheel.position = Vector2(640, 350)
	view.add_child(wheel)
	var equipped: Array = Profile.cosmetics.get("social", GameConfig.SOCIAL_DEFAULT)
	for index in 8:
		var button := Button.new()
		var item: String = str(equipped[index])
		button.text = I18n.t(item if item.begins_with("dance") or item.begins_with("shout") else "cosmetic_" + item)
		button.position = Vector2.from_angle(index * TAU / 8.0 - PI / 2.0) * 210.0 - Vector2(105, 26)
		button.size = Vector2(210, 52)
		button.pressed.connect(func(): _social(item); _close_wheel())
		wheel.add_child(button)
	(wheel.get_child(0) as Button).grab_focus()

func _close_wheel() -> void:
	if is_instance_valid(wheel): wheel.queue_free()
	wheel = null

func _unhandled_input(event: InputEvent) -> void:
	if room.is_empty() or room.phase != "lobby": return
	if event is InputEventKey and not event.echo:
		if event.keycode == KEY_Q:
			if event.pressed: _open_wheel()
			else: _close_wheel()
		elif event.pressed and event.keycode >= KEY_1 and event.keycode <= KEY_4:
			_social(str(Profile.cosmetics.get("social", GameConfig.SOCIAL_DEFAULT)[event.keycode - KEY_1]))
	if event is InputEventJoypadButton and event.button_index == JOY_BUTTON_Y:
		if event.pressed: _open_wheel()
		else: _close_wheel()
	if Input.get_vector("move_left", "move_right", "move_up", "move_down").length() > 0.1:
		if social.has(local_id) and str(social[local_id].item).begins_with("dance"): _social("stop")

func _process(delta: float) -> void:
	elapsed += delta
	if connection_pending:
		connection_elapsed += delta
		retry_elapsed += delta
		if hosting_here and connection_elapsed >= GameConfig.HOST_START_TIMEOUT_SECONDS:
			_connection_failed()
		elif connection_elapsed >= GameConfig.NET_CONNECT_TIMEOUT_SECONDS:
			_connection_failed()
		elif retry_elapsed >= GameConfig.NET_CONNECT_RETRY_SECONDS:
			_attempt_connect()
	if local and room.get("phase") == "voting":
		if local_vote.step(delta):
			room.arena_id = local_vote.winner
			room.phase = "loading"
		_room_changed(room)
	queue_redraw()

func _exit_tree() -> void:
	if connection_pending and hosting_here: Net.stop_host_server()

func _draw() -> void:
	draw_texture_rect(background, Rect2(Vector2.ZERO, size), false)
	var animation_time := 0.0 if Settings.reduce_motion else elapsed
	for center in [Vector2(125, 245), Vector2(1145, 245)]:
		draw_circle(center, 36.0 + sin(animation_time * 7.0) * 4.0, Color(1, 0.35, 0.08, 0.10))
	for index in 9:
		var dust := Vector2(fposmod(index * 173.0 + animation_time * 12.0, 1280), fposmod(index * 83.0 + animation_time * 24.0, 600))
		draw_circle(dust, 1.5, Color(0.9, 0.8, 0.7, 0.2))
	var spider := Vector2(1110, 100 + sin(animation_time * TAU / 10.0) * 45)
	draw_line(Vector2(1110, 0), spider, Color(0.5, 0.5, 0.5, 0.5), 1)
	draw_circle(spider, 5, Color("0b0710"))
	for index in 5:
		draw_circle(Vector2(fposmod(index * 330.0 + animation_time * 7, 1550) - 130, 580), 160, Color(0.5, 0.4, 0.6, 0.025))
	if room.is_empty(): return
	var order := _display_order()
	for slot in order.size():
		var index := order[slot]
		if index < 0: continue
		var player: Dictionary = roster[index]
		var center: Vector2 = GameConfig.LOBBY_PEDESTALS[slot]
		var color_index := int(player.team) if room.get("mode") == "greed" else index
		var key := "%s_%s" % [player.character, ["coral", "azul", "lima", "hueso"][color_index]]
		var sheet: Texture2D = sheets.get(key)
		if sheet == null: continue
		var pose: Dictionary = social.get(int(player.peer_id), {})
		var item := str(pose.get("item", ""))
		var angle := 0.0
		var scale_value := Vector2.ONE * (1.15 if slot == 1 else 1.0)
		var lift := 0.0
		var row := 0
		if not Settings.reduce_motion:
			match item:
				"dance_0": angle = sin(animation_time * TAU * 4) * deg_to_rad(15); lift = absf(sin(animation_time * 8)) * 8
				"dance_1": scale_value.x *= -1 if int(animation_time / 0.12) % 2 else 1; lift = absf(sin(animation_time * 8)) * 12
				"dance_2": lift = absf(sin(animation_time * 5)) * 35; scale_value *= Vector2(1 - lift / 150, 1 + lift / 150)
				"dance_3": angle = sin(animation_time * 30) * 0.06; row = 4
		draw_set_transform(center + Vector2(0, -lift), angle, scale_value)
		draw_texture_rect_region(sheet, Rect2(-72, -164, 144, 164), Rect2((int(animation_time * 6) % 6) * 224, row * 256, 224, 256))
		draw_set_transform(Vector2.ZERO)
		if item.begins_with("dance"):
			draw_string(ThemeDB.fallback_font, center + Vector2(55, -155 - lift), "♪", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, GameConfig.EMBER)
		if elapsed - float(pose.get("time", -10)) < GameConfig.SOCIAL_SECONDS:
			if item.begins_with("shout"):
				draw_string(ThemeBuilder.title_font(18), center + Vector2(-160, -205), I18n.t(item), HORIZONTAL_ALIGNMENT_CENTER, 320, 18, GameConfig.EMBER)
			else:
				var frame := GameConfig.SOCIAL_EMOTES.find("jaja" if item == "dance_3" else item)
				if frame >= 0:
					var texture: Texture2D = load("res://assets/ui/emotes%s.png" % ("2" if frame >= 8 else ""))
					draw_texture_rect_region(texture, Rect2(center + Vector2(-32, -235), Vector2(64,64)), Rect2((frame % 8) * 128, 0, 128,128))

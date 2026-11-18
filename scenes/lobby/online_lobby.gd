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
var wheel: Control
var clock_label: Label
var local_id := 2
var wheel_index := 0
var social_at := -1.0
var connecting_action := ""
var local_vote: ArenaVote
var vote_view: ArenaVoteView
var background := preload("res://assets/ui/lobby_mazmorra.png")

func _ready() -> void:
	size = Vector2(1280, 720)
	theme = ThemeBuilder.build()
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
	_button("create_room", Vector2(390, 210), Vector2(500, 60), func(): _connect_to("create")).grab_focus()
	code_field = LineEdit.new()
	code_field.max_length = GameConfig.ROOM_CODE_LENGTH
	code_field.placeholder_text = I18n.t("room_code")
	code_field.position = Vector2(490, 292)
	code_field.size = Vector2(300, 52)
	code_field.text_changed.connect(func(value: String):
		var caret := code_field.caret_column
		code_field.text = value.to_upper()
		code_field.caret_column = caret
	)
	view.add_child(code_field)
	_button("join_room", Vector2(390, 360), Vector2(500, 60), func(): _connect_to("join"))
	_button("bots", Vector2(390, 440), Vector2(500, 60), _local_room)
	_button("menu", Vector2(390, 560), Vector2(500, 60), func(): exit_requested.emit())

func _connect_to(action: String) -> void:
	connecting_action = action
	local = false
	notice.text = I18n.t("connecting")
	if Net.join_server(Settings.server_host) != OK: _error("connect_failed")

func _connected() -> void:
	local_id = multiplayer.get_unique_id()
	if connecting_action == "create":
		Net.create_room.rpc_id(1, Profile.nick, Profile.character, Profile.cosmetics, GameConfig.NET_VERSION)
	else:
		Net.join_room.rpc_id(1, code_field.text, Profile.nick, Profile.character, Profile.cosmetics, GameConfig.NET_VERSION)

func _local_room() -> void:
	local = true
	local_id = 2
	room = local_directory.create(local_id, Profile.nick, Profile.character, Profile.cosmetics, GameConfig.NET_VERSION)
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
		var key := "%s_%s" % [roster[index].character, ["coral", "azul", "lima", "hueso"][index]]
		if not sheets.has(key): sheets[key] = load("res://assets/characters/" + key + ".png")

func _build_room() -> void:
	_new_view()
	_label(I18n.t("room_code") + "  " + ("—" if local else str(room.code)), Vector2(20, 30), Vector2(540, 60), 30)
	_button("copy", Vector2(40, 94), Vector2(180, 45), func(): DisplayServer.clipboard_set(str(room.code)))
	var mode_button := _button(str(room.mode), Vector2(850, 40), Vector2(400, 55), func(): _action("mode", {"mode": GameConfig.MODES[(GameConfig.MODES.find(str(room.mode)) + 1) % GameConfig.MODES.size()]}))
	mode_button.disabled = int(room.host) != local_id
	_label(I18n.t("rules_" + str(room.mode)), Vector2(850,105),Vector2(400,120),20)
	var duration := _button(str(room.duration) + " s",Vector2(570,40),Vector2(220,55),func(): _action("duration",{"seconds":GameConfig.MATCH_DURATIONS[(GameConfig.MATCH_DURATIONS.find(int(room.duration))+1)%3]}))
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
	exit_requested.emit()

func _error(reason: String) -> void:
	if reason == "server_lost":
		room.clear()
		roster.clear()
		_entry()
	notice.text = I18n.t(reason if reason in ["server_lost", "connect_failed"] else "room_" + reason)

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
	if local and room.get("phase") == "voting":
		if local_vote.step(delta):
			room.arena_id = local_vote.winner
			room.phase = "loading"
		_room_changed(room)
	queue_redraw()

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
		var key := "%s_%s" % [player.character, ["coral", "azul", "lima", "hueso"][index]]
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

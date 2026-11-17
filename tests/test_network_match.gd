extends SceneTree

var net: Node
var role := ""
var room: Dictionary = {}
var elapsed := 0.0
var ready_sent := false
var vote_sent := false
var saw_snapshot := false
var saw_social := false
var sequence := 0
var input_clock := 0.0
var code_path := "res://.godot-tmp/test-room-code.txt"

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	role = OS.get_cmdline_user_args()[0]
	net = root.get_node("Net")
	net.connected.connect(func():
		if role == "create": net.create_room.rpc_id(1, "Host", "mago", {}, GameConfig.NET_VERSION)
		else: net.join_room.rpc_id(1, FileAccess.get_file_as_string(code_path).strip_edges(), role, "trol", {}, GameConfig.NET_VERSION)
	)
	net.room_changed.connect(_room)
	net.events_received.connect(_events)
	net.snapshot_received.connect(func(snapshot: Dictionary):
		saw_snapshot = true
		for player: Dictionary in snapshot.players: assert((player.vel as Vector2).length() <= GameConfig.PLAYER_SPEED * 1.61)
	)
	net.room_failed.connect(func(reason: String):
		if role == "extra" and reason == "full":
			print("Fifth client rejected: full")
			net.leave_server()
			quit()
		else: push_error(reason); quit(1)
	)
	assert(net.join_server("127.0.0.1", 17777) == OK)

func _room(value: Dictionary) -> void:
	room = value
	if role == "create":
		var file := FileAccess.open(code_path, FileAccess.WRITE)
		file.store_string(str(room.code))
	if room.phase == "voting" and not vote_sent:
		vote_sent = true
		var slot := 0
		for index in room.players.size():
			if int(room.players[index].peer_id) == net.multiplayer.get_unique_id(): slot = index
		net.lobby_action.rpc_id(1, "vote", {"arena": "cienaga" if slot < 2 else "cripta"})
		net.lobby_action.rpc_id(1, "social", {"item": "dance_0"})

func _events(events: Array) -> void:
	for event: Dictionary in events:
		if event.type == "social": saw_social = true
		if event.type == "match_over":
			assert(saw_snapshot and saw_social)
			print("MATCH PASS %s %s" % [role, str(event.ranking.hash())])
			net.leave_server()
			quit()

func _process(delta: float) -> bool:
	elapsed += delta
	if elapsed > 30:
		push_error("Network match timeout: " + role)
		quit(1)
	if room.is_empty(): return false
	if room.phase == "lobby" and not ready_sent and room.players.size() == 4 and elapsed > 4:
		ready_sent = true
		net.lobby_action.rpc_id(1, "ready")
	if room.phase == "playing":
		input_clock += delta
		if input_clock >= GameConfig.NET_TICK:
			input_clock -= GameConfig.NET_TICK
			sequence += 1
			net.submit_input.rpc_id(1, sequence, Vector2(5,0), false, false)
	return false

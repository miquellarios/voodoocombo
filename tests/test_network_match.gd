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
var test_mode := "voodoo"
var mode_sent := false
var jitter_test := false
var bots_sent := false
var prediction: ClientMatch
var delayed_inputs: Array[Dictionary] = []
var jitter_rng := RandomNumberGenerator.new()
var simulated_drops := 0
var simulated_snapshot_count := 0
var prediction_error_sum := 0.0
var prediction_error_samples := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	role = OS.get_cmdline_user_args()[0]
	if OS.get_cmdline_user_args().size() > 1: test_mode = OS.get_cmdline_user_args()[1]
	jitter_test = "jitter" in OS.get_cmdline_user_args()
	jitter_rng.seed = 14014
	net = root.get_node("Net")
	net.connected.connect(func():
		if role == "create": net.create_room.rpc_id(1, "Host", "mago", {}, GameConfig.NET_VERSION, test_mode)
		else: net.join_room.rpc_id(1, FileAccess.get_file_as_string(code_path).strip_edges(), role, "trol", {}, GameConfig.NET_VERSION)
	)
	net.room_changed.connect(_room)
	net.events_received.connect(_events)
	net.snapshot_received.connect(func(snapshot: Dictionary):
		saw_snapshot = true
		for player: Dictionary in snapshot.players: assert((player.vel as Vector2).length() <= GameConfig.PLAYER_SPEED * 1.61)
		if jitter_test and role == "guest1" and prediction != null:
			simulated_snapshot_count += 1
			if simulated_snapshot_count % 20 == 0:
				simulated_drops += 1
				return
			prediction.receive(snapshot)
			prediction_error_sum += prediction.predicted.distance_to(prediction.target)
			prediction_error_samples += 1
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
	if jitter_test and room.phase == "loading" and room.has("initial"):
		prediction = ClientMatch.new()
		prediction.setup(room.initial, net.multiplayer.get_unique_id())
	if role == "create":
		var file := FileAccess.open(code_path, FileAccess.WRITE)
		file.store_string(str(room.code))
		if not mode_sent:
			mode_sent = true
			net.lobby_action.rpc_id(1, "mode", {"mode":test_mode})
		if jitter_test and room.phase == "lobby" and not bots_sent:
			bots_sent = true
			net.lobby_action.rpc_id(1, "bots", {"count":2})
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
			if jitter_test and role == "guest1":
				var average_error := prediction_error_sum / maxf(1.0, float(prediction_error_samples))
				print("JITTER RESULT average reconciled prediction error %.2f px; snapshots dropped %d/%d" % [average_error, simulated_drops, simulated_snapshot_count])
				if average_error >= 6.0 or simulated_drops * 20 != simulated_snapshot_count:
					push_error("Jitter test exceeded 6 px or did not drop snapshots")
					quit(1)
					return
			print("MATCH PASS %s %s" % [role, str(event.ranking.hash())])
			net.leave_server()
			quit()

func _process(delta: float) -> bool:
	elapsed += delta
	if elapsed > (55.0 if jitter_test else 30.0):
		push_error("Network match timeout: " + role)
		quit(1)
	if room.is_empty(): return false
	if room.phase == "lobby" and not ready_sent and room.players.size() + int(room.get("bots", 0)) >= (4 if jitter_test else 4) and elapsed > 4:
		ready_sent = true
		net.lobby_action.rpc_id(1, "ready")
	if room.phase == "playing":
		input_clock += delta
		if input_clock >= GameConfig.NET_TICK:
			input_clock -= GameConfig.NET_TICK
			sequence += 1
			var move := Vector2.RIGHT
			if prediction != null: prediction.predict(move, GameConfig.NET_TICK, false)
			if jitter_test and role == "guest1":
				delayed_inputs.append({"seq":sequence,"move":move,"send_at":Time.get_ticks_msec() + jitter_rng.randi_range(0,60)})
			else: net.submit_input.rpc_id(1, sequence, move, false, false)
		if not delayed_inputs.is_empty():
			delayed_inputs.sort_custom(func(a: Dictionary, b: Dictionary): return int(a.send_at) < int(b.send_at))
			var now := Time.get_ticks_msec()
			while not delayed_inputs.is_empty() and int(delayed_inputs[0].send_at) <= now:
				var input: Dictionary = delayed_inputs.pop_front()
				net.submit_input.rpc_id(1, int(input.seq), input.move, false, false)
		if prediction != null: prediction.render(delta)
	return false

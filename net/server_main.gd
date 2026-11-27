extends Node

const SNAPSHOT_CODEC = preload("res://net/snapshot_codec.gd")

var directory := RoomDirectory.new()
var rooms: Dictionary = directory.rooms
var rate_limits: Dictionary = {}
var vote_publish := 0.0
var accumulator := 0.0
var session_xp: Dictionary = {}
var lan_ad_elapsed := 0.0
var listen_port := GameConfig.NET_PORT

func _ready() -> void:
	Net.request_received.connect(_request)
	Net.peer_left.connect(_depart)
	LanDiscovery.start_discovery(GameConfig.LAN_DISCOVERY_PORT)
	var args := OS.get_cmdline_user_args()
	var arg_index := args.find("--port")
	if arg_index >= 0 and arg_index + 1 < args.size(): listen_port = int(args[arg_index + 1])
	var error := Net.start_server(listen_port)
	if error != OK:
		push_error("ENet: %s" % error_string(error))
		get_tree().quit(1)

func _process(delta: float) -> void:
	for code in directory.step(delta): Net.log_line("room closed %s" % code)
	vote_publish += delta
	accumulator += minf(delta, GameConfig.NET_MAX_FRAME)
	while accumulator >= GameConfig.NET_TICK:
		accumulator -= GameConfig.NET_TICK
		for room: Dictionary in rooms.values():
			if room.phase == "voting":
				if room.vote.step(GameConfig.NET_TICK):
					room.arena_id = room.vote.winner
					room.phase = "loading"
					room["load_left"] = GameConfig.LOADING_SECONDS + 3.0
					_prepare_match(room)
					_publish(room)
				elif vote_publish >= GameConfig.VOTE_PUBLISH_SECONDS: _publish(room)
			elif room.phase == "loading":
				room.load_left -= GameConfig.NET_TICK
				if room.load_left <= 0:
					room.phase = "playing"
					_publish(room)
			elif room.phase == "playing":
				_step_match(room)
	if vote_publish >= GameConfig.VOTE_PUBLISH_SECONDS: vote_publish = 0.0
	var public_rooms: Array[Dictionary] = []
	for room: Dictionary in rooms.values():
		var status := {"code": room.code, "mode": room.mode, "phase": room.phase, "players": []}
		if room.get("sim") is MatchSim:
			status["time"] = room.sim.remaining
			for player: Dictionary in room.sim.players:
				if not bool(player.get("disconnected", false)): status.players.append({"name": player.name, "score": player.score})
		public_rooms.append(status)
	HttpEndpoint.set_status({"rooms": public_rooms})
	lan_ad_elapsed += delta
	if lan_ad_elapsed >= 1.0:
		lan_ad_elapsed = 0.0
		var open_rooms: Array = rooms.values().filter(func(value: Dictionary) -> bool: return value.phase in ["lobby", "voting"])
		if open_rooms.is_empty():
			LanDiscovery.stop_advertising()
		else:
			var addresses := NetworkAddresses.candidates()
			var lan_address := ""
			for candidate: Dictionary in addresses:
				if int(candidate.rank) >= 2:
					lan_address = str(candidate.ip)
					break
			if lan_address.is_empty() and not addresses.is_empty(): lan_address = str(addresses[0].ip)
			if not lan_address.is_empty():
				var advertisements: Array[Dictionary] = []
				for room: Dictionary in open_rooms:
					var host := "VoodooCombo"
					var player_count := 0
					for player: Dictionary in room.players:
						if not bool(player.get("is_bot", false)):
							player_count += 1
							if int(player.peer_id) == int(room.host): host = str(player.name)
					advertisements.append({"code": room.code, "host": host, "mode": room.mode, "players": "%d" % player_count, "player_count": player_count, "version": GameConfig.NET_VERSION, "ip": lan_address, "port": listen_port})
				LanDiscovery.start_advertising({"kind": "rooms", "rooms": advertisements})

func _request(sender: int, action: String, data: Dictionary) -> void:
	if sender <= 1 or var_to_bytes(data).size() > GameConfig.RPC_MAX_BYTES or not _allow(sender, action): return
	var level := mini(GameConfig.PROFILE_MAX_LEVEL, int(session_xp.get(sender, 0)) / GameConfig.PROFILE_XP_PER_LEVEL + 1)
	if not RpcRules.valid(action, data, level):
		if action in ["create", "join", "cosmetics"]: Net.room_error.rpc_id(sender, "cosmetics")
		return
	var room := directory.for_peer(sender)
	match action:
		"ping": Net.pong.rpc_id(sender, int(data.stamp))
		"create", "join":
			if action == "create":
				room = directory.create(sender, data.nick, data.character, data.cosmetics, data.version, str(data.get("mode", "voodoo")))
			else:
				room = directory.join(sender, data.code, data.nick, data.character, data.cosmetics, data.version)
			if room.is_empty():
				var reason := directory.error
				if reason == "version": reason = "version:" + GameConfig.NET_VERSION
				Net.room_error.rpc_id(sender, reason)
			else:
				Net.room_joined.rpc_id(sender, room.code, directory.public_state(room))
				_publish(room)
				Net.log_line("room %s %s %d" % [action, room.code, sender])
		"leave": _depart(sender)
		"rematch":
			if room.is_empty() or room.phase != "results": return
			room.phase = "lobby"
			room.erase("sim")
			room.erase("vote")
			for player: Dictionary in room.players: player.ready = false
			_publish(room)
		"ready", "bots", "mode", "cosmetics", "team", "duration":
			if not room.is_empty() and LobbyRules.apply(room, sender, action, data):
				if LobbyRules.all_ready(room):
					room.phase = "voting"
					room["vote"] = ArenaVote.new()
					room.vote.setup(randi(), LobbyRules.roster(room))
				_publish(room)
		"vote":
			if not room.is_empty() and room.phase == "voting" and room.vote.vote(sender, str(data.get("arena", ""))): _publish(room)
		"input", "intent":
			if not room.is_empty() and room.phase == "playing": _accept_input(room, sender, action, data)
		"social":
			if room.is_empty(): return
			var item := str(data.get("item", ""))
			if not GameConfig.SOCIAL_LEVELS.has(item) and item != "stop": return
			var now := Time.get_ticks_msec()
			var social: Dictionary = room.get("social_times", {})
			if now - int(social.get(sender, -1000)) < int(GameConfig.SOCIAL_COOLDOWN * 1000): return
			social[sender] = now
			room["social_times"] = social
			for player: Dictionary in room.players:
				Net.match_events.rpc_id(int(player.peer_id), [{"type": "social", "peer_id": sender, "item": item}])

func _allow(sender: int, action: String) -> bool:
	var key := str(sender) + ":" + action
	var now := Time.get_ticks_msec()
	var rate: Dictionary = rate_limits.get(key, {"time": now, "count": 0})
	if now - int(rate.time) >= 1000: rate = {"time": now, "count": 0}
	rate.count += 1
	rate_limits[key] = rate
	return int(rate.count) <= (GameConfig.RPC_INPUT_LIMIT if action == "input" else GameConfig.RPC_ACTION_LIMIT)

func _prepare_match(room: Dictionary) -> void:
	room["sim"] = MatchSim.new()
	room.sim.setup({"seed": room.vote.seed_value, "arena_id": room.arena_id, "mode": room.mode, "duration": room.duration, "players": LobbyRules.roster(room)})
	room["inputs"] = {}
	room["sequences"] = {}
	room["applied_sequences"] = {}
	room["input_queue"] = {}
	room["action_sequences"] = {}
	room["snapshot_left"] = 0.0
	room["coin_snapshot_left"] = 0.0
	room["last_coin_marker"] = []
	room["max_snapshot_bytes"] = 0

func _accept_input(room: Dictionary, sender: int, action: String, data: Dictionary) -> void:
	var seq := int(data.get("seq", -1))
	if seq < 0 or seq > 2147483647: return
	if action == "input":
		if seq <= int(room.sequences.get(sender, -1)): return
		var move: Vector2 = data.move
		if not move.is_finite(): return
		var queue: NetInputQueue = room.input_queue.get(sender, NetInputQueue.new())
		queue.enqueue(seq, move, Time.get_ticks_msec())
		room.input_queue[sender] = queue
		room.sequences[sender] = seq
	var input: Dictionary = room.inputs.get(sender, {"dash": false, "spell": false})
	for ability in ["dash", "spell"]:
		var requested: bool = (str(data.action) == ability) if action == "intent" else bool(data.get(ability, false))
		var key := "%d:%s" % [sender, ability]
		if requested and seq > int(room.action_sequences.get(key, -1)):
			input[ability] = true
			room.action_sequences[key] = seq
	room.inputs[sender] = input

func _step_match(room: Dictionary) -> void:
	var inputs: Array[Dictionary] = []
	var now := Time.get_ticks_msec()
	for player: Dictionary in room.sim.players:
		var peer_id := int(player.peer_id)
		var queue: NetInputQueue = room.input_queue.get(peer_id, NetInputQueue.new())
		var queued_input := queue.consume(now)
		if int(queued_input.seq) >= 0: room.applied_sequences[peer_id] = int(queued_input.seq)
		room.input_queue[peer_id] = queue
		var input: Dictionary = room.inputs.get(peer_id, {"dash":false, "spell":false}).duplicate()
		input["move"] = queued_input.move
		inputs.append(input)
	room.sim.step(GameConfig.NET_TICK, inputs)
	for input: Dictionary in room.inputs.values():
		input.dash = false
		input.spell = false
	var events: Array[Dictionary] = room.sim.pop_events()
	if not events.is_empty():
		for event: Dictionary in events:
			if event.type == "match_over":
				event["snapshot"] = room.sim.snapshot()
				room.phase = "results"
				Net.log_line("match over %s; max compressed snapshot %d B" % [str(room.code), int(room.max_snapshot_bytes)])
				_save_result(room, event)
		for player: Dictionary in room.players:
			if Net.can_send(int(player.peer_id)): Net.match_events.rpc_id(int(player.peer_id), events)
	room.snapshot_left -= GameConfig.NET_TICK
	if room.snapshot_left <= 0.0:
		room.snapshot_left += GameConfig.NET_SNAPSHOT_TICK
		room.coin_snapshot_left -= GameConfig.NET_SNAPSHOT_TICK
		var coin_marker: Array = []
		for coin: Dictionary in room.sim.coins:
			coin_marker.append([roundi(coin.pos.x), roundi(coin.pos.y), int(coin.get("owner", -1))])
		var include_coins: bool = coin_marker != room.last_coin_marker or room.coin_snapshot_left <= 0.0
		if include_coins:
			room.last_coin_marker = coin_marker
			room.coin_snapshot_left = GameConfig.NET_COIN_FULL_SNAPSHOT_SECONDS
		var snapshot := SNAPSHOT_CODEC.prepare(room.sim.snapshot(), room.applied_sequences, include_coins)
		var packed_size := var_to_bytes(snapshot).compress(FileAccess.COMPRESSION_ZSTD).size()
		room.max_snapshot_bytes = maxi(int(room.max_snapshot_bytes), packed_size)
		for player: Dictionary in room.players: Net.send_snapshot(int(player.peer_id), snapshot)

func _publish(room: Dictionary) -> void:
	var state := directory.public_state(room)
	for player: Dictionary in room.players:
		if Net.can_send(int(player.peer_id)): Net.room_state.rpc_id(int(player.peer_id), state)

func _depart(sender: int) -> void:
	var room := directory.leave(sender)
	if not room.is_empty():
		if room.get("sim") is MatchSim and room.phase in ["loading", "playing"]:
			room.sim.disconnect_player(sender)
			if room.players.is_empty():
				room.phase = "lobby"
				room.erase("sim")
			else: _step_match(room)
		_publish(room)
	directory.attempts.erase(sender)
	for key: String in rate_limits.keys():
		if key.begins_with(str(sender) + ":"): rate_limits.erase(key)

func _save_result(room: Dictionary, event: Dictionary) -> void:
	var ranking: Array[Dictionary] = []
	for player: Dictionary in event.ranking:
		var id := int(player.peer_id)
		session_xp[id] = int(session_xp.get(id, 0)) + 50 + int(player.max_combo) + int(player.get("challenge_xp",0))
		ranking.append({"name": player.name, "score": player.score, "max_combo": player.max_combo, "peer_id": player.peer_id})
	if ranking.is_empty(): return
	var record := {"date": Time.get_datetime_string_from_system(), "room": room.code, "mode": room.mode, "winner": ranking[0].name, "ranking": ranking, "awards": event.awards}
	DirAccess.make_dir_recursive_absolute("user://matches")
	var file := FileAccess.open("user://matches/%s-%s.json" % [record.date.replace(":", "-"), room.code], FileAccess.WRITE)
	if file: file.store_string(JSON.stringify(record))
	HttpEndpoint.add_result(record)

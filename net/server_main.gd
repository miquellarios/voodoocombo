extends Node

var directory := RoomDirectory.new()
var rooms: Dictionary = directory.rooms
var rate_limits: Dictionary = {}
var vote_publish := 0.0
var accumulator := 0.0

func _ready() -> void:
	Net.request_received.connect(_request)
	Net.peer_left.connect(_depart)
	var port := GameConfig.NET_PORT
	var args := OS.get_cmdline_user_args()
	var index := args.find("--port")
	if index >= 0 and index + 1 < args.size(): port = int(args[index + 1])
	var error := Net.start_server(port)
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
					_publish(room)
				elif vote_publish >= GameConfig.VOTE_PUBLISH_SECONDS: _publish(room)
			if room.get("sim") is MatchSim:
				var inputs: Array[Dictionary] = []
				room.sim.step(GameConfig.NET_TICK, inputs)
	if vote_publish >= GameConfig.VOTE_PUBLISH_SECONDS: vote_publish = 0.0

func _request(sender: int, action: String, data: Dictionary) -> void:
	if sender <= 1 or var_to_bytes(data).size() > GameConfig.RPC_MAX_BYTES or not _allow(sender, action): return
	var room := directory.for_peer(sender)
	match action:
		"ping": Net.pong.rpc_id(sender, int(data.stamp))
		"create", "join":
			if action == "create":
				room = directory.create(sender, data.nick, data.character, data.cosmetics, data.version)
			else:
				room = directory.join(sender, data.code, data.nick, data.character, data.cosmetics, data.version)
			if room.is_empty(): Net.room_error.rpc_id(sender, directory.error)
			else:
				Net.room_joined.rpc_id(sender, room.code, directory.public_state(room))
				_publish(room)
				Net.log_line("room %s %s %d" % [action, room.code, sender])
		"leave": _depart(sender)
		"ready", "bots", "mode", "cosmetics":
			if not room.is_empty() and LobbyRules.apply(room, sender, action, data):
				if LobbyRules.all_ready(room):
					room.phase = "voting"
					room["vote"] = ArenaVote.new()
					room.vote.setup(randi(), LobbyRules.roster(room))
				_publish(room)
		"vote":
			if not room.is_empty() and room.phase == "voting" and room.vote.vote(sender, str(data.get("arena", ""))): _publish(room)
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
	return int(rate.count) <= GameConfig.RPC_ACTION_LIMIT

func _publish(room: Dictionary) -> void:
	var state := directory.public_state(room)
	for player: Dictionary in room.players: Net.room_state.rpc_id(int(player.peer_id), state)

func _depart(sender: int) -> void:
	var room := directory.leave(sender)
	if not room.is_empty(): _publish(room)
	directory.attempts.erase(sender)

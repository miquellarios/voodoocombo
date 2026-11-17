class_name RoomDirectory
extends RefCounted

var rooms: Dictionary = {}
var membership: Dictionary = {}
var attempts: Dictionary = {}
var rng := RandomNumberGenerator.new()
var error := ""
var clock := 0.0

func _init() -> void:
	rng.randomize()

func validate(nick: String, character: String, cosmetics: Dictionary, version: String) -> bool:
	error = ""
	if version != GameConfig.NET_VERSION: error = "version"
	elif not NicknameRules.is_valid(nick) or nick.length() > 12: error = "nickname"
	elif not character in ["mago", "trol", "gnomo", "nigro"]: error = "character"
	elif var_to_bytes(cosmetics).size() > GameConfig.RPC_MAX_BYTES: error = "cosmetics"
	for index in nick.length():
		if nick.unicode_at(index) < 32 or nick.unicode_at(index) == 127: error = "nickname"
	return error.is_empty()

func create(sender: int, nick: String, character: String, cosmetics: Dictionary, version: String) -> Dictionary:
	if not validate(nick, character, cosmetics, version): return {}
	if membership.has(sender): error = "already_joined"; return {}
	if rooms.size() >= GameConfig.NET_MAX_ROOMS: error = "server_full"; return {}
	var code := ""
	while code.is_empty() or rooms.has(code):
		code = ""
		for index in GameConfig.ROOM_CODE_LENGTH:
			code += GameConfig.ROOM_ALPHABET[rng.randi_range(0, GameConfig.ROOM_ALPHABET.length() - 1)]
	rooms[code] = {"code": code, "players": [], "host": sender, "mode": "voodoo", "duration": 90, "phase": "lobby", "empty_since": clock, "arena_id": "", "bots": 0}
	return _insert(sender, code, nick, character, cosmetics)

func join(sender: int, code: String, nick: String, character: String, cosmetics: Dictionary, version: String) -> Dictionary:
	error = ""
	var recent: Array = attempts.get(sender, [])
	recent = recent.filter(func(time: float): return clock - time < GameConfig.ROOM_ATTEMPT_WINDOW)
	attempts[sender] = recent
	if recent.size() >= GameConfig.ROOM_ATTEMPTS: error = "rate"; return {}
	recent.append(clock)
	if not validate(nick, character, cosmetics, version): return {}
	if membership.has(sender): error = "already_joined"; return {}
	if code.length() != GameConfig.ROOM_CODE_LENGTH or not rooms.has(code): error = "missing"; return {}
	var room: Dictionary = rooms[code]
	if room.phase != "lobby": error = "started"; return {}
	if room.players.size() >= GameConfig.ROOM_CAPACITY: error = "full"; return {}
	return _insert(sender, code, nick, character, cosmetics)

func _insert(sender: int, code: String, nick: String, character: String, cosmetics: Dictionary) -> Dictionary:
	var room: Dictionary = rooms[code]
	room.players.append({"peer_id": sender, "name": nick.strip_edges(), "character": character, "cosmetics": cosmetics.duplicate(true), "ready": false, "is_bot": false})
	membership[sender] = code
	room.bots = mini(int(room.bots), GameConfig.ROOM_CAPACITY - room.players.size())
	return room

func leave(sender: int) -> Dictionary:
	var room := for_peer(sender)
	membership.erase(sender)
	if room.is_empty(): return {}
	for index in range(room.players.size() - 1, -1, -1):
		if room.players[index].peer_id == sender: room.players.remove_at(index)
	if room.players.is_empty(): room.empty_since = clock
	elif room.host == sender: room.host = room.players[0].peer_id
	return room

func for_peer(sender: int) -> Dictionary:
	return rooms.get(membership.get(sender, ""), {})

func public_state(room: Dictionary) -> Dictionary:
	var result := {}
	for key in ["code", "players", "host", "mode", "duration", "phase", "arena_id", "bots"]:
		result[key] = room[key]
	return result.duplicate(true)

func step(delta: float) -> Array[String]:
	clock += delta
	var expired: Array[String] = []
	for code: String in rooms.keys():
		var room: Dictionary = rooms[code]
		if room.players.is_empty() and clock - float(room.empty_since) >= GameConfig.ROOM_EMPTY_SECONDS:
			expired.append(code)
			rooms.erase(code)
	return expired

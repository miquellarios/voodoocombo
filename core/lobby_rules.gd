class_name LobbyRules
extends RefCounted

static func apply(room: Dictionary, sender: int, action: String, data: Dictionary) -> bool:
	if room.get("phase") != "lobby": return false
	var index := -1
	for i in room.players.size():
		if int(room.players[i].peer_id) == sender: index = i
	if index < 0: return false
	match action:
		"ready": room.players[index].ready = not bool(room.players[index].ready)
		"bots":
			if sender != int(room.host): return false
			room.bots = clampi(int(data.get("count", 0)), 0, GameConfig.ROOM_CAPACITY - room.players.size())
		"mode":
			if sender != int(room.host) or not data.get("mode") in ["voodoo", "survival"]: return false
			room.mode = data.mode
			for player: Dictionary in room.players: player.ready = false
		"cosmetics":
			var character: String = str(data.get("character", ""))
			if not character in ["mago", "trol", "gnomo", "nigro"]: return false
			room.players[index].character = character
			room.players[index].cosmetics = data.get("cosmetics", {}).duplicate(true)
		_: return false
	return true

static func all_ready(room: Dictionary) -> bool:
	if room.players.size() + int(room.bots) < 2 or room.players.is_empty(): return false
	for player: Dictionary in room.players:
		if not bool(player.ready): return false
	return true

static func roster(room: Dictionary) -> Array[Dictionary]:
	var players: Array[Dictionary] = []
	for player: Dictionary in room.players: players.append(player.duplicate(true))
	for index in int(room.bots):
		players.append({"peer_id": -index - 1, "name": "Bot %d" % (index + 1), "character": ["mago", "trol", "gnomo", "nigro"][players.size()], "is_bot": true, "ready": true, "cosmetics": {}})
	return players

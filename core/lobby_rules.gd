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
			if room.mode == "greed": return false
			room.bots = clampi(int(data.get("count", 0)), 0, GameConfig.ROOM_CAPACITY - room.players.size())
		"duration":
			if sender != int(room.host) or not int(data.get("seconds",0)) in GameConfig.MATCH_DURATIONS: return false
			room.duration = int(data.seconds)
		"mode":
			if sender != int(room.host) or not data.get("mode") in ["voodoo", "survival", "greed"]: return false
			room.mode = data.mode
			if room.mode == "greed": room.bots = 4 - room.players.size()
			for player: Dictionary in room.players: player.ready = false
		"cosmetics":
			var character: String = str(data.get("character", ""))
			if not character in ["mago", "trol", "gnomo", "nigro"]: return false
			room.players[index].character = character
			room.players[index].cosmetics = data.get("cosmetics", {}).duplicate(true)
		"team":
			if sender != int(room.host): return false
			var target := int(data.get("index",-1))
			if target < 0 or target >= room.players.size(): return false
			var team := int(room.players[target].get("team",target / 2))
			for other in room.players.size():
				if other != target and int(room.players[other].get("team",other / 2)) != team:
					room.players[other]["team"] = team
					break
			room.players[target]["team"] = 1 - team
			for player: Dictionary in room.players: player.ready = false
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
	var counts := [0,0]
	for index in players.size():
		var team := clampi(int(players[index].get("team",index / 2)),0,1)
		if counts[team] >= 2: team = 1 - team
		players[index]["team"] = team
		counts[team] += 1
	return players

class_name MatchAchievements
extends RefCounted

var first_hit := false
var tracking: Array[Dictionary] = []

func setup(count: int) -> void:
	first_hit = false
	tracking.clear()
	for index in count:
		tracking.append({"last_attacker": -1, "last_hit": 0.0, "streak": 0, "combo": 0, "peaks": 0, "was_last": false})

func update(players: Array[Dictionary], events: Array[Dictionary], time: float) -> Array[Dictionary]:
	var awarded: Array[Dictionary] = []
	for player in players:
		if not player.has("medals"): player["medals"] = []
	for event in events:
		if event.type == "player_hit":
			var victim := int(event.victim)
			var attacker := int(event.attacker)
			tracking[victim].streak = 0
			tracking[victim].last_hit = time
			tracking[victim].last_attacker = attacker
			if attacker >= 0:
				if not first_hit: _award(players, awarded, attacker, "primera_sangre"); first_hit = true
				if int(tracking[attacker].last_attacker) == victim and time - float(tracking[attacker].last_hit) <= GameConfig.MEDAL_REVENGE_SECONDS: _award(players, awarded, attacker, "venganza")
				tracking[attacker].streak += 1
				if tracking[attacker].streak >= GameConfig.MEDAL_STREAK_HITS: _award(players, awarded, attacker, "racha")
				if int(event.dropped) >= GameConfig.MEDAL_STEAL_COINS: _award(players, awarded, attacker, "robo_maestro")
		elif event.type == "near_miss": _award(players, awarded, int(event.player), "por_los_pelos")
	var maximum := -1
	var minimum := 2147483647
	for player in players:
		if bool(player.get("disconnected", false)): continue
		maximum = maxi(maximum, int(player.score))
		minimum = mini(minimum, int(player.score))
	for index in players.size():
		var player: Dictionary = players[index]
		if bool(player.get("disconnected", false)): continue
		var stats: Dictionary = tracking[index]
		if time - float(stats.last_hit) >= GameConfig.MEDAL_UNTOUCHED_SECONDS: _award(players, awarded, index, "intocable")
		if int(player.combo) >= 12 and int(stats.combo) < 12:
			stats.peaks += 1
			if int(stats.peaks) >= 2: _award(players, awarded, index, "rey_combo")
		stats.combo = player.combo
		if maximum > minimum:
			if bool(stats.was_last) and int(player.score) == maximum: _award(players, awarded, index, "remontada")
			if int(player.score) == minimum: stats.was_last = true
	return awarded

func _award(players: Array[Dictionary], output: Array[Dictionary], index: int, id: String) -> void:
	if id in players[index].medals: return
	players[index].medals.append(id)
	output.append({"type": "medal", "player": index, "medal": id})

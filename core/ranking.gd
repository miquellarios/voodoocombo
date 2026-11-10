class_name MatchRanking
extends RefCounted

static func rank(players: Array[Dictionary]) -> Array[Dictionary]:
	var result := players.duplicate(true)
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a.get("score", 0)) == int(b.get("score", 0)):
			return int(a.get("max_combo", 0)) > int(b.get("max_combo", 0))
		return int(a.get("score", 0)) > int(b.get("score", 0)))
	return result

static func awards(players: Array[Dictionary]) -> Dictionary:
	var result := {}
	for pair in [["combo", "Rey del Combo", true], ["stolen", "Manos Largas", true], ["dashes", "Bala Perdida", true], ["sheep", "Oveja Oficial", true], ["hits", "Intocable", false]]:
		var best: Dictionary = {}
		for player in players:
			if best.is_empty() or (int(player.get(pair[0], 0)) > int(best.get(pair[0], 0))) == bool(pair[2]):
				best = player
		result[str(pair[1])] = best.get("name", "")
	return result

class_name ChallengeRules
extends RefCounted

static func choose(rng: RandomNumberGenerator) -> Array[String]:
	var pool: Array = GameConfig.CHALLENGE_TARGETS.keys()
	var result: Array[String] = []
	while result.size() < 3:
		var index := rng.randi_range(0,pool.size()-1)
		result.append(str(pool.pop_at(index)))
	return result

static func completed(player: Dictionary, selected: Array) -> Array[String]:
	var values := {"steal": int(player.get("stolen",0)), "combo": int(player.get("max_combo",0)), "spells": int(player.get("spells_used",0)), "collect": int(player.get("pickups",0)), "hits": int(player.get("dashes",0))}
	var result: Array[String] = []
	for id: String in selected:
		if int(values[id]) >= int(GameConfig.CHALLENGE_TARGETS[id]): result.append(id)
	return result

static func bonus(completed_ids: Array) -> int:
	var unique := {}
	for id: String in completed_ids:
		if GameConfig.CHALLENGE_TARGETS.has(id): unique[id] = true
	return unique.size() * GameConfig.CHALLENGE_XP

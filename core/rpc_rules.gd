class_name RpcRules
extends RefCounted

static func cosmetics_valid(value: Dictionary, level: int) -> bool:
	for key: Variant in value:
		if key not in ["frame", "trail", "emotes", "social"]: return false
	for key in ["frame", "trail"]:
		if not value.has(key): continue
		if not value[key] is String: return false
		var table: Dictionary = GameConfig.FRAME_UNLOCK_LEVELS if key == "frame" else GameConfig.TRAIL_UNLOCK_LEVELS
		if not table.has(value[key]) or int(table[value[key]]) > level: return false
	for key in ["emotes", "social"]:
		if not value.has(key): continue
		if not value[key] is Array or value[key].size() > 8: return false
		for item: Variant in value[key]:
			if not item is String or not GameConfig.SOCIAL_LEVELS.has(item) or int(GameConfig.SOCIAL_LEVELS[item]) > level: return false
	return true

static func valid(action: String, data: Dictionary, level: int = 1) -> bool:
	if var_to_bytes(data).size() > GameConfig.RPC_MAX_BYTES: return false
	match action:
		"ready", "leave", "rematch": return data.is_empty()
		"ping": return data.get("stamp") is int
		"create", "join":
			return data.get("nick") is String and data.get("character") is String and data.get("version") is String and data.get("cosmetics") is Dictionary and cosmetics_valid(data.cosmetics, level) and (action != "join" or data.get("code") is String)
		"cosmetics": return data.get("character") is String and data.get("cosmetics") is Dictionary and cosmetics_valid(data.cosmetics, level)
		"mode": return data.get("mode") is String
		"bots": return data.get("count") is int
		"team": return data.get("index") is int
		"duration": return data.get("seconds") is int
		"vote": return data.get("arena") is String
		"social": return data.get("item") is String and (data.item == "stop" or (GameConfig.SOCIAL_LEVELS.has(data.item) and int(GameConfig.SOCIAL_LEVELS[data.item]) <= level))
		"input": return data.get("seq") is int and data.get("move") is Vector2 and data.move.is_finite() and data.get("dash") is bool and data.get("spell") is bool
		"intent": return data.get("seq") is int and data.get("action") in ["dash", "spell"]
	return false

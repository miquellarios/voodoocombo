class_name NicknameRules
extends RefCounted

static func normalize(value: String) -> String:
	return value.strip_edges()

static func is_valid(value: String) -> bool:
	var cleaned := normalize(value)
	return cleaned.length() >= GameConfig.NICK_MIN_LENGTH and cleaned.length() <= GameConfig.NICK_MAX_LENGTH

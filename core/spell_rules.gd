class_name SpellRules
extends RefCounted

static func duration(item: String) -> float:
	match item:
		"magnet": return GameConfig.SPELL_MAGNET_SECONDS
		"boots": return GameConfig.SPELL_BOOTS_SECONDS
		"cloak": return GameConfig.SPELL_CLOAK_SECONDS
		"ring": return GameConfig.SPELL_RING_SECONDS
		"sheep": return GameConfig.SPELL_SHEEP_SECONDS
		_: return 0.0

static func can_activate(player: Dictionary) -> bool:
	return not String(player.get("item", "")).is_empty() and float(player.get("item_time", 0.0)) <= 0.0

static func is_active(player: Dictionary, item: String) -> bool:
	return String(player.get("item", "")) == item and float(player.get("item_time", 0.0)) > 0.0

static func activate(player: Dictionary) -> Dictionary:
	var changed := player.duplicate(true)
	if can_activate(changed) and duration(String(changed.item)) > 0.0:
		changed.item_time = duration(String(changed.item))
	return changed

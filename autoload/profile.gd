extends Node

var nick := ""
var character := "mago"
var xp := 0
var games := 0
var wins := 0
var medal_totals: Dictionary = {}
var cosmetics := {"frame": "madera", "trail": "color", "emotes": ["risa", "enfado", "gg", "corazon"]}
var new_unlocks: Array[Dictionary] = []

var preferred_arena_id := "random"
var last_arena_id := ""

func _ready() -> void:
	var config := ConfigFile.new()
	if config.load("user://profile.cfg") == OK:
		medal_totals = config.get_value("profile", "medals", {})
		nick = str(config.get_value("profile", "nick", nick))
		character = str(config.get_value("profile", "character", character))
		xp = int(config.get_value("profile", "xp", 0))
		games = int(config.get_value("profile", "games", 0))
		wins = int(config.get_value("profile", "wins", 0))
		cosmetics = config.get_value("profile", "cosmetics", cosmetics)
		if not cosmetics is Dictionary: cosmetics = {}
		preferred_arena_id = str(config.get_value("profile", "preferred_arena_id", preferred_arena_id))
		last_arena_id = str(config.get_value("profile", "last_arena_id", last_arena_id))
	_normalize_cosmetics()

func award_match(place: int, combo: int, bonus: int = 0) -> int:
	var old_level := level()
	var gained := 50 + (30 if place == 1 else (20 if place == 2 else (10 if place == 3 else 0))) + combo + bonus
	xp += gained
	games += 1
	if place == 1:
		wins += 1
	new_unlocks.clear()
	var all_unlocks: Array[Dictionary] = []
	for cosmetic_id in ["hueso", "calavera", "plata", "oro", "almas"]:
		if int(GameConfig.FRAME_UNLOCK_LEVELS[cosmetic_id]) > old_level and int(GameConfig.FRAME_UNLOCK_LEVELS[cosmetic_id]) <= level(): all_unlocks.append({"type": "frame", "id": cosmetic_id, "level": GameConfig.FRAME_UNLOCK_LEVELS[cosmetic_id]})
	for cosmetic_id in ["oro", "escarcha", "almas"]:
		if int(GameConfig.TRAIL_UNLOCK_LEVELS[cosmetic_id]) > old_level and int(GameConfig.TRAIL_UNLOCK_LEVELS[cosmetic_id]) <= level(): all_unlocks.append({"type": "trail", "id": cosmetic_id, "level": GameConfig.TRAIL_UNLOCK_LEVELS[cosmetic_id]})
	for cosmetic_id in ["calavera", "llanto", "pulgar", "fuego"]:
		if int(GameConfig.EMOTE_UNLOCK_LEVELS[cosmetic_id]) > old_level and int(GameConfig.EMOTE_UNLOCK_LEVELS[cosmetic_id]) <= level(): all_unlocks.append({"type": "emote", "id": cosmetic_id, "level": GameConfig.EMOTE_UNLOCK_LEVELS[cosmetic_id]})
	for cosmetic_id: String in GameConfig.SOCIAL_LEVELS:
		var required := int(GameConfig.SOCIAL_LEVELS[cosmetic_id])
		if required > old_level and required <= level(): all_unlocks.append({"type":"social","id":cosmetic_id,"level":required})
	if not all_unlocks.is_empty(): new_unlocks.append(all_unlocks[0])
	var config := ConfigFile.new()
	config.set_value("profile", "nick", nick)
	config.set_value("profile", "character", character)
	config.set_value("profile", "xp", xp)
	config.set_value("profile", "games", games)
	config.set_value("profile", "wins", wins)
	config.set_value("profile", "cosmetics", cosmetics)
	config.set_value("profile", "preferred_arena_id", preferred_arena_id)
	config.set_value("profile", "last_arena_id", last_arena_id)
	config.save("user://profile.cfg")
	return gained

func level() -> int:
	return mini(GameConfig.PROFILE_MAX_LEVEL, floori(float(xp) / float(GameConfig.PROFILE_XP_PER_LEVEL)) + 1)

func _normalize_cosmetics() -> void:
	var emotes: Variant = cosmetics.get("emotes", ["risa", "enfado", "gg", "corazon"])
	if not emotes is Array: emotes = ["risa", "enfado", "gg", "corazon"]
	var clean: Array[String] = []
	for emote in emotes:
		if GameConfig.EMOTE_UNLOCK_LEVELS.has(str(emote)) and not clean.has(str(emote)): clean.append(str(emote))
	for default_emote in ["risa", "enfado", "gg", "corazon"]:
		if clean.size() >= 4: break
		if not clean.has(default_emote): clean.append(default_emote)
	if clean.size() > 4: clean.resize(4)
	var frame_id := str(cosmetics.get("frame", "madera"))
	var trail_id := str(cosmetics.get("trail", "color"))
	if not GameConfig.FRAME_UNLOCK_LEVELS.has(frame_id) or int(GameConfig.FRAME_UNLOCK_LEVELS[frame_id]) > level(): frame_id = "madera"
	if not GameConfig.TRAIL_UNLOCK_LEVELS.has(trail_id) or int(GameConfig.TRAIL_UNLOCK_LEVELS[trail_id]) > level(): trail_id = "color"
	var social: Array = cosmetics.get("social", GameConfig.SOCIAL_DEFAULT).duplicate()
	if social.size() != 8: social = GameConfig.SOCIAL_DEFAULT.duplicate()
	for index in social.size():
		if not GameConfig.SOCIAL_LEVELS.has(str(social[index])) or int(GameConfig.SOCIAL_LEVELS.get(str(social[index]), 99)) > level():
			social[index] = GameConfig.SOCIAL_DEFAULT[index]
	cosmetics = {"frame": frame_id, "trail": trail_id, "emotes": clean, "social": social}

func save() -> void:
	_normalize_cosmetics()
	var config := ConfigFile.new()
	config.set_value("profile", "medals", medal_totals)
	config.set_value("profile", "nick", nick)
	config.set_value("profile", "character", character)
	config.set_value("profile", "xp", xp)
	config.set_value("profile", "games", games)
	config.set_value("profile", "wins", wins)
	config.set_value("profile", "cosmetics", cosmetics)
	config.set_value("profile", "preferred_arena_id", preferred_arena_id)
	config.set_value("profile", "last_arena_id", last_arena_id)
	config.save("user://profile.cfg")

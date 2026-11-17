extends Node

var nick := ""
var character := "mago"
var xp := 0
var games := 0
var wins := 0
var cosmetics := {"hat": "none", "eyes": "button", "trail": "none", "dance": "bounce"}
var preferred_arena_id := "random"
var last_arena_id := ""

func _ready() -> void:
	var config := ConfigFile.new()
	if config.load("user://profile.cfg") == OK:
		nick = str(config.get_value("profile", "nick", nick))
		character = str(config.get_value("profile", "character", character))
		xp = int(config.get_value("profile", "xp", 0))
		games = int(config.get_value("profile", "games", 0))
		wins = int(config.get_value("profile", "wins", 0))
		cosmetics = config.get_value("profile", "cosmetics", cosmetics)
		preferred_arena_id = str(config.get_value("profile", "preferred_arena_id", preferred_arena_id))
		last_arena_id = str(config.get_value("profile", "last_arena_id", last_arena_id))

func award_match(place: int, combo: int) -> int:
	var gained := 50 + (30 if place == 1 else (20 if place == 2 else (10 if place == 3 else 0))) + combo
	xp += gained
	games += 1
	if place == 1:
		wins += 1
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
	return floori(float(xp) / 300.0)

func save() -> void:
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

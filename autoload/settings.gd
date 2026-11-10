extends Node

var reduce_motion := false
var ui_scale := 1.0
var music_volume := 0.7
var sfx_volume := 0.8

func _ready() -> void:
	var config := ConfigFile.new()
	if config.load("user://settings.cfg") == OK:
		reduce_motion = config.get_value("accessibility", "reduce_motion", false)
		ui_scale = config.get_value("accessibility", "ui_scale", 1.0)
		music_volume = config.get_value("audio", "music", 0.7)
		sfx_volume = config.get_value("audio", "sfx", 0.8)
		I18n.set_language(str(config.get_value("general", "language", "es")))

func save() -> void:
	var config := ConfigFile.new()
	config.set_value("accessibility", "reduce_motion", reduce_motion)
	config.set_value("accessibility", "ui_scale", ui_scale)
	config.set_value("audio", "music", music_volume)
	config.set_value("audio", "sfx", sfx_volume)
	config.set_value("general", "language", I18n.language)
	config.save("user://settings.cfg")

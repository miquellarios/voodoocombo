extends Node

var reduce_motion := false
var reduce_flashes := false
var vibration := true
var server_host := "127.0.0.1"
var join_host := ""
var server_port := GameConfig.SETTINGS_PORT
var server_choice := 2
var ui_scale := 1.0
var music_volume := 0.7
var sfx_volume := 0.8
var window_fullscreen := false
var window_size_index := GameConfig.DEFAULT_WINDOW_SIZE_INDEX

func _ready() -> void:
	var config := ConfigFile.new()
	if config.load("user://settings.cfg") == OK:
		reduce_flashes = bool(config.get_value("accessibility", "reduce_flashes", false))
		vibration = bool(config.get_value("accessibility", "vibration", true))
		server_host = str(config.get_value("network", "host", server_host))
		join_host = str(config.get_value("network", "join_host", join_host))
		server_port = clampi(int(config.get_value("network", "port", server_port)), 1, 65535)
		server_choice = int(config.get_value("network", "choice", server_choice))
		reduce_motion = config.get_value("accessibility", "reduce_motion", false)
		ui_scale = config.get_value("accessibility", "ui_scale", 1.0)
		music_volume = config.get_value("audio", "music", 0.7)
		sfx_volume = config.get_value("audio", "sfx", 0.8)
		window_fullscreen = bool(config.get_value("display", "fullscreen", window_fullscreen))
		window_size_index = clampi(int(config.get_value("display", "window_size_index", window_size_index)), 0, GameConfig.WINDOW_SIZE_OPTIONS.size() - 1)
		I18n.set_language(str(config.get_value("general", "language", "es")))
	ui_scale = _nearest_ui_scale(ui_scale)

func _nearest_ui_scale(value: float) -> float:
	var nearest: float = GameConfig.SETTINGS_UI_SCALE_VALUES[0]
	for candidate: float in GameConfig.SETTINGS_UI_SCALE_VALUES:
		if absf(candidate - value) < absf(nearest - value): nearest = candidate
	return nearest

func save() -> void:
	var config := ConfigFile.new()
	config.set_value("network", "host", server_host)
	config.set_value("network", "join_host", join_host)
	config.set_value("network", "port", server_port)
	config.set_value("network", "choice", server_choice)
	config.set_value("accessibility", "reduce_motion", reduce_motion)
	config.set_value("accessibility", "reduce_flashes", reduce_flashes)
	config.set_value("accessibility", "vibration", vibration)
	config.set_value("accessibility", "ui_scale", ui_scale)
	config.set_value("audio", "music", music_volume)
	config.set_value("audio", "sfx", sfx_volume)
	config.set_value("general", "language", I18n.language)
	config.set_value("display", "fullscreen", window_fullscreen)
	config.set_value("display", "window_size_index", window_size_index)
	config.save("user://settings.cfg")

func apply_display() -> void:
	if window_fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		var size: Vector2i = GameConfig.WINDOW_SIZE_OPTIONS[window_size_index]
		DisplayServer.window_set_size(size)

func toggle_fullscreen() -> void:
	window_fullscreen = not window_fullscreen
	apply_display()
	save()

func cycle_window_size() -> void:
	window_size_index = posmod(window_size_index + 1, GameConfig.WINDOW_SIZE_OPTIONS.size())
	apply_display()
	save()

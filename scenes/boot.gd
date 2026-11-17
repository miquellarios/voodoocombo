extends Node

func _ready() -> void:
	var server := "--server" in OS.get_cmdline_user_args() or OS.has_feature("dedicated_server")
	var path := "res://scenes/server/server.tscn" if server else "res://scenes/main/main.tscn"
	get_tree().change_scene_to_file.call_deferred(path)

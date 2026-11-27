extends Node

func _ready() -> void:
	var editor_args := Net.hosted_server_arguments(7777, "user://logs/servidor.log", true)
	assert(editor_args[0] == "--path" and editor_args[1] == ProjectSettings.globalize_path("res://"))
	assert(editor_args.has("--headless") and editor_args.has("--server") and editor_args.has("7777"))
	var export_args := Net.hosted_server_arguments(8888, "user://logs/servidor.log", false)
	assert(not export_args.has("--path") and export_args.has("8888"))
	assert(GameConfig.LOCKER_SOCIAL_WHEEL_RECT.size == Vector2(360, 360))
	assert(GameConfig.LOCKER_SOCIAL_ICON_SIZE == Vector2(56, 56))
	print("Hosted-server editor arguments and interface dimensions passed")
	get_tree().quit()

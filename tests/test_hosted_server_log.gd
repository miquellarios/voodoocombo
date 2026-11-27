extends Node

func _ready() -> void:
	var pid := Net.start_host_server(47888)
	assert(pid > 0)
	await get_tree().create_timer(1.0).timeout
	var server_log := ProjectSettings.globalize_path("user://logs/servidor.log")
	assert(FileAccess.file_exists(server_log))
	Net.stop_host_server()
	print("Hosted server log test passed")
	get_tree().quit()

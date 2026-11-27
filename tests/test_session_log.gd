extends Node

func _ready() -> void:
	assert(SessionLog.previous_session_crashed)
	assert(DirAccess.dir_exists_absolute(ProjectSettings.globalize_path("user://logs")))
	assert(FileAccess.file_exists("user://running.lock"))
	print("Session log crash-recovery test passed")
	get_tree().quit()

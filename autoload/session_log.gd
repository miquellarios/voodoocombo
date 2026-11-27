extends Node

const LOCK_PATH := "user://running.lock"

var previous_session_crashed := false
var dedicated_server := false

func _init() -> void:
	_migrate_legacy_user_data()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://logs"))
	dedicated_server = "--server" in OS.get_cmdline_user_args() or OS.has_feature("dedicated_server")
	if dedicated_server: return
	previous_session_crashed = FileAccess.file_exists(LOCK_PATH)
	var lock := FileAccess.open(LOCK_PATH, FileAccess.WRITE)
	if lock != null:
		lock.store_string(Time.get_datetime_string_from_system())
		lock.close()

func _migrate_legacy_user_data() -> void:
	var current_dir := ProjectSettings.globalize_path("user://")
	var legacy_dir := current_dir.get_base_dir().path_join("VoodooCombo 0.13.0")
	if not DirAccess.dir_exists_absolute(legacy_dir): return
	for filename in ["settings.cfg", "profile.cfg"]:
		var destination := current_dir.path_join(filename)
		var source := legacy_dir.path_join(filename)
		if FileAccess.file_exists(destination) or not FileAccess.file_exists(source): continue
		var source_file := FileAccess.open(source, FileAccess.READ)
		var destination_file := FileAccess.open(destination, FileAccess.WRITE)
		if source_file != null and destination_file != null: destination_file.store_buffer(source_file.get_buffer(source_file.get_length()))
	var old_matches := legacy_dir.path_join("matches")
	if DirAccess.dir_exists_absolute(old_matches):
		var new_matches := current_dir.path_join("matches")
		DirAccess.make_dir_recursive_absolute(new_matches)
		for filename in DirAccess.get_files_at(old_matches):
			var source := old_matches.path_join(filename)
			var destination := new_matches.path_join(filename)
			if FileAccess.file_exists(destination): continue
			var match_source := FileAccess.open(source, FileAccess.READ)
			var match_destination := FileAccess.open(destination, FileAccess.WRITE)
			if match_source != null and match_destination != null: match_destination.store_buffer(match_source.get_buffer(match_source.get_length()))

func _ready() -> void:
	if not dedicated_server: get_tree().root.tree_exiting.connect(_on_clean_exit, CONNECT_ONE_SHOT)

func _on_clean_exit() -> void:
	if FileAccess.file_exists(LOCK_PATH): DirAccess.remove_absolute(ProjectSettings.globalize_path(LOCK_PATH))

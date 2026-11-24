extends SceneTree

func _initialize() -> void:
	call_deferred("_capture")

func _capture() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	var profile: Node = root.get_node("Profile")
	profile.nick = "Codex"
	profile.character = "mago"
	var game := load("res://scenes/main/main.tscn").instantiate() as Node2D
	root.add_child(game)
	await process_frame
	game.set_process(false)
	var directory := "res://docs/capturas/fase-13"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	game.call("_build_menu")
	await _wait_for_render()
	_save(directory + "/menu_1920.png")
	game.call("_build_online")
	var online: Node = game.hud_root.get_child(0)
	online.call("_mode_select", "bots")
	await _wait_for_render()
	_save(directory + "/elige-modo_1920.png")
	game.call("_begin_match", "cienaga", {"mode": "greed"})
	await _wait_for_render()
	_save(directory + "/carga-codicia_1920.png")
	game.results_ranking.assign(MatchRanking.rank(game.players))
	game.call("_show_results")
	await _wait_for_render()
	_save(directory + "/podio_1920.png")
	print("Captured menu, mode selection, loading and podium at 1920x1080")
	quit(0)

func _wait_for_render() -> void:
	await process_frame
	await process_frame
	await create_timer(0.8).timeout
	await RenderingServer.frame_post_draw

func _save(path: String) -> void:
	var image := root.get_viewport().get_texture().get_image()
	var result := image.save_png(path)
	if result != OK: push_error("Could not save capture: " + path)

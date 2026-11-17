extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game := load("res://scenes/main/main.tscn").instantiate() as Node2D
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.call("_begin_match", false, "cienaga")
	game.call("_start_countdown")
	game.set("countdown", 0.01)
	for _frame in range(61): game.call("_process", 1.0 / 30.0)
	var sim := game.get("simulation") as MatchSim
	if sim == null or sim.elapsed < 1.9 or game.get("players").size() != 4:
		push_error("La vista local no avanza MatchSim")
		quit(1)
		return
	var view: Dictionary = sim.snapshot()
	view.players[0].score = 123456
	if int(sim.players[0].score) == 123456:
		push_error("El snapshot permite modificar la simulación")
		quit(1)
		return
	game.call("_build_menu")
	await process_frame
	game.queue_free()
	await process_frame
	print("Local MatchSim integration passed")
	quit(0)

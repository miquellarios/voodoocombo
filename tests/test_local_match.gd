extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game := load("res://scenes/main/main.tscn").instantiate() as Node2D
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.call("_begin_match", "cienaga")
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
	var players: Array = game.get("players")
	players[0].item = "boots"
	players[0].item_time = GameConfig.SPELL_BOOTS_SECONDS
	game.set("players", players)
	game.call("_update_hud")
	game.call("_handle_events", [{"type":"item_used","player":0,"item":"boots"}])
	var effects: Array = game.get("spell_effects")
	var hud := game.get("hud_root") as Control
	var duration_ring := hud.get_node_or_null("SpellDurationRing") as Control
	if effects.is_empty() or duration_ring == null or not duration_ring.visible:
		push_error("El hechizo no crea su feedback y aro de duración")
		quit(1)
		return
	game.call("_build_menu")
	await process_frame
	game.queue_free()
	await process_frame
	print("Local MatchSim integration passed")
	quit(0)


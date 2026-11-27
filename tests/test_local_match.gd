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
	for _index in range(20):
		game.set("pickup_streak_value", 1)
		game.call("_finish_pickup_streak")
	var fx: Node = root.get_node("Fx")
	for _index in range(20): fx.call("render_pop", "+1", Vector2(640, 360), GameConfig.BONE_TEXT)
	if game.get("hud_floating_labels").size() > GameConfig.MAX_FLOATING_LABELS or fx.get("active_texts").size() > GameConfig.MAX_FLOATING_LABELS:
		push_error("El HUD o Fx supera el límite de textos flotantes")
		quit(1)
		return
	fx.call("clear_text")
	var floating_start := hud.get_child_count()
	for frame in range(90 * 30):
		if frame % 30 == 0 and game.get("state") == "playing":
			sim.players[0].score += 1
			game.call("_handle_events", [{"type":"coin_taken", "player":0, "value":1, "combo":1, "pos":sim.players[0].pos}])
		game.call("_process", 1.0 / 30.0)
		await process_frame
		if frame == 30 * 30 - 1:
			if hud.get_child_count() - floating_start > 40:
				push_error("El HUD acumula más de 40 nodos durante 30 s de recogidas")
				quit(1)
				return
			await create_timer(0.5).timeout
			var score_labels: Array = game.get("score_number_labels")
			var view_players: Array = game.get("players")
			if int(game.get("score_values")[0]) != int(view_players[0].score) or str(score_labels[0].text) != str(view_players[0].score):
				push_error("El marcador local no coincide con players[local].score tras 30 s")
				quit(1)
				return
		if game.get("state") in ["match_end", "results"]: break
	game.call("_build_menu")
	await process_frame
	game.queue_free()
	await process_frame
	print("Local MatchSim integration passed")
	quit(0)


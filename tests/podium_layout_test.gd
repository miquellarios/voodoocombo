extends Node

func _ready() -> void:
	Settings.reduce_motion = true
	var view := (load("res://scenes/main/main.gd") as Script).new() as Node2D
	get_tree().root.add_child.call_deferred(view)
	await get_tree().process_frame
	view.set_process(false)
	for count in [2, 3, 4]:
		view.results_ranking.clear()
		for index in range(count):
			view.results_ranking.append({"name": "Jugador %d" % (index + 1), "score": 20 - index, "character": "mago", "sprite_color": "coral", "medals": []})
		view._show_results()
		await get_tree().process_frame
		var root: Control = view.hud_root
		var buttons := [root.get_node("ResultsMainMenu") as Control, root.get_node("ResultsAgain") as Control]
		var button_rects: Array[Rect2] = []
		for button in buttons:
			button_rects.append(Rect2(button.position, button.size))
			assert(button.position.y >= 640.0 and button.position.y + button.size.y <= 680.0, "Results buttons must use the bottom row")
		var plaques: Array[Rect2] = []
		for place in range(1, count + 1):
			var plaque := root.get_node("ResultPlaque%d" % place) as Control
			var plaque_rect := Rect2(plaque.position, plaque.size)
			plaques.append(plaque_rect)
			assert(plaque_rect.end.y < button_rects[0].position.y, "A podium plaque collides with the button row")
			for rank in range(1, mini(place, 3) + 1):
				var rank_center: Vector2 = GameConfig.RESULTS_PODIUM_TOPS[rank]
				var rank_rect := Rect2(rank_center + Vector2(-38.0, 8.0), Vector2(76.0, 40.0))
				if rank == place:
					assert(not rank_rect.intersects(plaque_rect), "A name plaque covers its podium rank")
			for prior in range(plaques.size() - 1):
				assert(not plaques[prior].intersects(plaque_rect), "Podium plaques overlap with %d players" % count)
		view._clear_hud()
		await get_tree().process_frame
	view.queue_free()
	print("Podium positions and footer row passed for 2, 3 and 4 players")
	get_tree().quit()

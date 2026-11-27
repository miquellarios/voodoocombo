extends Node

func _ready() -> void:
	Settings.reduce_motion = true
	var view := (load("res://scenes/main/main.gd") as Script).new() as Node2D
	get_tree().root.add_child.call_deferred(view)
	await get_tree().process_frame
	view.set_process(false)
	for count in [2, 3, 4]:
		view.mode = "voodoo"
		view.state = "playing"
		view.local_player = 0
		view.players.clear()
		for index in range(count):
			view.players.append({
				"name": "Jugador %d" % (index + 1),
				"color": GameConfig.COLORS[index],
				"shape": ["●", "▲", "■", "◆"][index],
				"character": ["mago", "trol", "gnomo", "nigro"][index],
				"sprite_color": ["coral", "azul", "lima", "hueso"][index],
				"cosmetics": {"frame": "madera"},
				"score": [25, 18, 12, 4][index],
				"combo": 0,
				"item": "",
				"item_time": 0.0,
				"disconnected": false,
				"lives": 3
			})
		view._build_hud()
		view._update_hud()
		await get_tree().process_frame
		var active_order := [0, 1, 2, 3]
		for card_index in range(4):
			var card: Control = view.score_cards[card_index]
			assert(card.visible == (card_index < count), "Unexpected active card count %d" % count)
			for child in [view.score_name_labels[card_index], view.score_tag_labels[card_index], view.score_portraits[card_index], view.score_frames[card_index], view.score_frame_skulls[card_index], view.score_crowns[card_index], view.score_number_labels[card_index]]:
				assert(child.get_parent() == card, "Score-card element escaped its card")
			for stitch in GameConfig.SURVIVAL_LIVES:
				assert(view.score_life_icons[card_index][stitch].get_parent() == card, "Stitch icon escaped its card")
			if card_index < count:
				assert(view.score_values[card_index] == [25, 18, 12, 4][card_index], "Score data mapped to the wrong player")
		view._clear_hud()
		await get_tree().process_frame
	view.mode = "greed"
	view.state = "playing"
	view._build_hud()
	assert(view.team_score_labels.size() == 2)
	assert(view.team_chest_icons.size() == 2)
	assert(view.team_score_labels[0].position.x < 574.0 and view.team_score_labels[1].position.x > 706.0)
	assert(view.score_cards[0].position.y == 72.0)
	view._clear_hud()
	view.queue_free()
	print("HUD score cards and Greed score layout passed")
	get_tree().quit()

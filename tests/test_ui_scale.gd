extends Node

func _ready() -> void:
	Settings.ui_scale = 1.0
	var view := (load("res://scenes/settings/settings_view.gd") as Script).new() as CanvasLayer
	get_tree().root.add_child.call_deferred(view)
	await get_tree().process_frame
	await get_tree().process_frame
	var row := view.page.get_child(0).get_child(0) as HBoxContainer
	var scale_value := row.get_child(2).get_child(0) as Button
	var next := row.get_child(3) as Button
	var previous := row.get_child(1) as Button
	var row_id := row.get_instance_id()
	for _step in range(3): next.pressed.emit()
	assert(is_equal_approx(Settings.ui_scale, 1.5))
	assert(next.disabled and not previous.disabled)
	assert(row.get_instance_id() == row_id and scale_value.text == "150 %")
	var overflow: Array[String] = []
	var pending: Array[Node] = [view]
	while not pending.is_empty():
		var current: Node = pending.pop_back()
		if current is Control and current != view and not current is ColorRect and current.is_visible_in_tree():
			var rect := (current as Control).get_global_rect()
			if rect.position.x < -1.0 or rect.position.y < -1.0 or rect.end.x > GameConfig.VIEWPORT_WIDTH + 1.0 or rect.end.y > GameConfig.VIEWPORT_HEIGHT + 1.0:
				overflow.append("%s %s" % [current.name, rect])
		for child in current.get_children(): pending.append(child)
	assert(overflow.is_empty(), "Visible settings controls overflow at 150%%: " + str(overflow))
	for _step in range(5): previous.pressed.emit()
	assert(is_equal_approx(Settings.ui_scale, 0.75))
	assert(previous.disabled and not next.disabled)
	assert(row.get_instance_id() == row_id and scale_value.text == "75 %")
	var layer := CanvasLayer.new()
	get_tree().root.add_child(layer)
	Settings.scale_canvas_layer(layer)
	assert(is_equal_approx(layer.transform.x.x, 0.75))
	assert(is_equal_approx(layer.transform.origin.x, 160.0))
	layer.queue_free()
	view.queue_free()
	print("UI scale endpoints and stable-row test passed")
	get_tree().quit()

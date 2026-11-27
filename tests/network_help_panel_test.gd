extends Node

func _ready() -> void:
	var lobby := OnlineLobby.new()
	lobby.view = Control.new()
	get_tree().root.add_child.call_deferred(lobby.view)
	await get_tree().process_frame
	lobby._open_network_help()
	var overlay: Control = lobby.network_help_overlay
	assert(overlay != null and overlay.get_parent() == lobby.view)
	var panel := overlay.get_node("NetworkHelpPanel") as Control
	var body := panel.get_node("NetworkHelpBody") as Label
	var back := panel.get_node("NetworkHelpBack") as Button
	assert(body.autowrap_mode == TextServer.AUTOWRAP_WORD_SMART)
	assert(body.size.x > 500 and body.size.y >= 220)
	assert(body.get_theme_color("font_color") == GameConfig.BONE_TEXT)
	assert(back.text == I18n.t("back"))
	back.pressed.emit()
	await get_tree().process_frame
	assert(lobby.network_help_overlay == null)
	lobby.view.queue_free()
	lobby.free()
	await get_tree().process_frame
	await get_tree().process_frame
	print("In-game network help panel layout passed")
	get_tree().quit()

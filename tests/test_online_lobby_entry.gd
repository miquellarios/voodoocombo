extends Node

func _ready() -> void:
	var lobby := OnlineLobby.new()
	get_tree().root.add_child.call_deferred(lobby)
	await get_tree().process_frame
	await get_tree().process_frame
	assert(lobby.lan_list != null)
	assert(lobby.invite_field != null)
	assert(lobby.view.get_child_count() > 15)
	assert(lobby.lan_list.position.x >= 630.0 and lobby.lan_list.position.x + lobby.lan_list.size.x <= 1280.0)
	lobby.queue_free()
	print("Online lobby entry UI test passed")
	get_tree().quit()

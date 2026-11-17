extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.get_node("Profile").nick = "Tester"
	var lobby: Control = load("res://scenes/lobby/online_lobby.gd").new()
	root.add_child(lobby)
	lobby._local_room()
	assert(lobby.roster.size() == 4)
	assert(lobby._display_order()[1] == 0)
	lobby._open_wheel()
	assert(lobby.wheel.get_child_count() == 8)
	lobby._social("dance_0")
	await process_frame
	lobby.queue_free()
	await process_frame
	print("Lobby roster, local pedestal and eight social slots passed")
	quit()

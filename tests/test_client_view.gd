extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var profile := root.get_node("Profile")
	profile.nick = "Tester"
	var scene: Node = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(scene)
	scene.set_process(false)
	var sim := MatchSim.new()
	sim.setup({"seed": 42, "arena_id": "cienaga", "players": [{"name":"Other", "peer_id":9}, {"name":"Tester", "peer_id":1, "is_bot":false}]})
	scene._begin_online_match({"initial":sim.snapshot()})
	assert(scene.local_player == 1)
	var input: Array[Dictionary] = [{}, {"move":Vector2.RIGHT}]
	sim.step(1.0 / 30.0,input)
	scene._network_snapshot(sim.snapshot())
	assert(scene.state == "playing")
	scene.client_match.predict(Vector2.RIGHT,1.0 / 30.0,false)
	scene._read_state(scene.client_match.render(1.0 / 60.0))
	scene._update_hud()
	scene.network_match = false
	scene._build_menu()
	scene.queue_free()
	await process_frame
	print("Online view, second-player identity and snapshot rendering passed")
	quit()

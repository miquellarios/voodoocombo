extends SceneTree

func _initialize() -> void:
	var sim := MatchSim.new()
	sim.setup({"seed": 41, "players": [
		{"name": "One", "peer_id": 2, "is_bot": false},
		{"name": "Two", "peer_id": 3, "is_bot": false},
		{"name": "Three", "peer_id": 4, "is_bot": false}
	]})
	sim.players[0].score = 100
	sim.disconnect_player(2)
	assert(not sim.finished)
	var inputs: Array[Dictionary] = []
	sim.step(GameConfig.NET_TICK, inputs)
	assert(sim.players[0].pos == Vector2(-10000, -10000))
	sim.disconnect_player(3)
	assert(sim.finished)
	var results: Array[Dictionary] = sim.pop_events()
	assert(results.back().type == "match_over")
	assert(results.back().ranking.size() == 1)
	assert(results.back().ranking[0].peer_id == 4)
	print("Disconnect continues with two humans; last human wins despite departed leader")
	quit()

extends SceneTree

func _initialize() -> void:
	var sim := MatchSim.new()
	sim.setup({"seed":99,"mode":"survival","players":[{"name":"One","peer_id":2,"is_bot":false},{"name":"Two","peer_id":3,"is_bot":false}]})
	assert(sim.coins.is_empty())
	for hit in 3:
		sim.players[1].invuln = 0.0
		sim._apply_hit(1,0,0.25,3,12,0.4)
	assert(sim.players[1].ghost and sim.players[1].lives == 0)
	sim._check_survival_round()
	assert(sim.players[0].round_wins == 1 and sim.round_wait == 4)
	var previous: String = sim.arena.map_id
	var inputs: Array[Dictionary] = []
	sim.step(4, inputs)
	assert(sim.round_number == 2 and sim.arena.map_id != previous and sim.players[1].lives == 3)
	sim.players[1].ghost = true
	sim.players[1].lives = 0
	sim._check_survival_round()
	assert(sim.finished and sim.players[0].round_wins == 2)
	assert(ZoneRules.safe_rect(5).size == Vector2(400,200))
	print("Survival elimination, new arena, two round wins and minimum zone passed")
	quit()

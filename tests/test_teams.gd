extends SceneTree

func _initialize() -> void:
	var sim := MatchSim.new()
	sim.setup({"seed":7,"mode":"greed","players":[{"name":"A","is_bot":false},{"name":"B","is_bot":false},{"name":"C","is_bot":false},{"name":"D","is_bot":false}]})
	assert(sim.coins.size() == 40)
	sim.players[0].coins = 10
	sim.players[0].score = 10
	sim.players[0].pos = GameConfig.TEAM_BASES[0]
	sim._deposit(0.5)
	assert(sim.team_scores[0] == 10 and sim.team_scores[1] == 0)
	sim.players[0].coins = 20
	sim.players[0].score = 20
	assert(not sim._apply_hit(0,1,0.25,3,12,0.4).applied)
	var hit := sim._apply_hit(0,2,0.25,3,12,0.4)
	assert(hit.applied and hit.dropped == 20 and sim.players[0].coins == 0 and sim.team_scores[0] == 10)
	assert(is_equal_approx(TeamRules.speed(20),0.6))
	assert(TeamRules.coin_value(true,true) == 4)
	print("Team deposit, protected bank, friendly fire and carry slowdown passed")
	quit()

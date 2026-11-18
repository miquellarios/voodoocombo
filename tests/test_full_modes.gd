extends SceneTree

func _initialize() -> void:
	for mode in GameConfig.MODES:
		var sim := MatchSim.new()
		var roster: Array[Dictionary] = []
		for index in 4: roster.append({"name":"Bot%d" % index,"is_bot":true,"peer_id":index+2})
		sim.setup({"seed":27,"mode":mode,"players":roster})
		var inputs: Array[Dictionary] = []
		for frame in 18000:
			sim.step(GameConfig.NET_TICK,inputs)
			sim.pop_events()
			if sim.finished: break
		if not sim.finished:
			push_error("Mode did not finish: " + mode)
			quit(1)
			return
		print("Full bot match passed: %s, round %d" % [mode,sim.round_number])
	quit()

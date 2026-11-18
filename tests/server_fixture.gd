extends "res://net/server_main.gd"

func _prepare_match(room: Dictionary) -> void:
	super._prepare_match(room)
	room.load_left = 0.3
	room.sim.remaining = 3.0

func _step_match(room: Dictionary) -> void:
	super._step_match(room)
	if room.mode == "survival" and room.phase == "playing" and room.sim.elapsed > 1 and room.sim.round_wait == 0:
		for index in range(1,room.sim.players.size()):
			for hit in 3:
				room.sim.players[index].invuln = 0.0
				room.sim._apply_hit(index,0,0,0,0,0)

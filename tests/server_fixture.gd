extends "res://net/server_main.gd"

func _prepare_match(room: Dictionary) -> void:
	super._prepare_match(room)
	room.load_left = 0.3
	room.sim.remaining = 3.0

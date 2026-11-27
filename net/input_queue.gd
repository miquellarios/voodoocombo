class_name NetInputQueue
extends RefCounted

var pending: Array[Dictionary] = []
var last_move := Vector2.ZERO
var last_input_ms := 0
var applied_sequence := -1

func enqueue(sequence: int, move: Vector2, received_at_ms: int) -> void:
	while pending.size() >= GameConfig.NET_INPUT_QUEUE_MAX: pending.pop_front()
	pending.append({"seq":sequence,"move":move.limit_length(),"received_at":received_at_ms})

func consume(now_ms: int) -> Dictionary:
	if not pending.is_empty():
		var catch_up := pending.size() > GameConfig.NET_INPUT_CATCHUP_THRESHOLD
		var applied: Dictionary = pending.pop_front()
		if catch_up: applied = pending.pop_front()
		last_move = applied.move
		last_input_ms = now_ms
		applied_sequence = int(applied.seq)
	var move := last_move if now_ms - last_input_ms <= int(GameConfig.NET_INPUT_TIMEOUT * 1000.0) else Vector2.ZERO
	return {"seq":applied_sequence,"move":move}

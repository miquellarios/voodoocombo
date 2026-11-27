extends SceneTree

const INPUT_QUEUE = preload("res://net/input_queue.gd")

func _initialize() -> void:
	var queue: NetInputQueue = INPUT_QUEUE.new()
	for sequence in range(5): queue.enqueue(sequence, Vector2.RIGHT, 100)
	if queue.pending.size() != 5 or queue.applied_sequence != -1:
		push_error("Input burst is not queued before its simulation tick")
		quit(1)
		return
	var first := queue.consume(100)
	if int(first.seq) != 1 or first.move != Vector2.RIGHT or queue.pending.size() != 3:
		push_error("Catch-up did not consume and acknowledge two queued inputs")
		quit(1)
		return
	var second := queue.consume(110)
	if int(second.seq) != 2 or queue.pending.size() != 2:
		push_error("Input queue did not consume one entry on a normal tick")
		quit(1)
		return
	for sequence in range(5,12): queue.enqueue(sequence, Vector2.LEFT, 120)
	if queue.pending.size() != GameConfig.NET_INPUT_QUEUE_MAX:
		push_error("Input queue exceeded its six-entry limit")
		quit(1)
		return
	for tick in range(GameConfig.NET_INPUT_QUEUE_MAX): queue.consume(130 + tick)
	if not queue.pending.is_empty() or queue.consume(1000).move != Vector2.ZERO:
		push_error("Stale input was not allowed to time out")
		quit(1)
		return
	print("Queued network input tests passed")
	quit(0)
class_name ZoneRules
extends RefCounted

static func safe_rect(step: int) -> Rect2:
	var bounded_step := clampi(step, 0, GameConfig.ZONE_MAX_STEPS)
	var inset_x := bounded_step * GameConfig.ZONE_COLUMNS_PER_SIDE * GameConfig.CELL_SIZE
	var inset_y := bounded_step * GameConfig.ZONE_ROWS_PER_SIDE * GameConfig.CELL_SIZE
	var width := GameConfig.ARENA_SIZE.x - inset_x * 2.0
	var height := GameConfig.ARENA_SIZE.y - inset_y * 2.0
	return Rect2(Vector2(inset_x, inset_y), Vector2(width, height))

static func is_inside(position: Vector2, step: int) -> bool:
	return safe_rect(step).has_point(position)

static func advance_drain(timer: float, delta: float, interval: float) -> Dictionary:
	var remaining := timer - delta
	var ticks := 0
	while remaining <= 0.0:
		ticks += 1
		remaining += interval
	return {"ticks": ticks, "remaining": remaining}

static func step_for_remaining(remaining: float) -> int:
	var thresholds: Array = GameConfig.VOODOO_ZONE_TIMES
	var step := 0
	for threshold in thresholds:
		if remaining <= float(threshold): step += 1
	return step

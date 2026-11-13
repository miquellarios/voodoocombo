class_name ArenaPhysics
extends RefCounted

static func move_circle(position: Vector2, motion: Vector2, radius: float, obstacles: Array, arena_size: Vector2 = GameConfig.ARENA_SIZE) -> Vector2:
	var result := Vector2(
		clampf(position.x + motion.x, radius, arena_size.x - radius),
		clampf(position.y + motion.y, radius, arena_size.y - radius)
	)
	var x_only := Vector2(result.x, position.y)
	for obstacle in obstacles:
		if _overlaps_rect(x_only, radius, obstacle):
			x_only.x = position.x
			break
	var y_only := Vector2(x_only.x, result.y)
	for obstacle in obstacles:
		if _overlaps_rect(y_only, radius, obstacle):
			y_only.y = position.y
			break
	return y_only

static func separate_pair(first: Vector2, second: Vector2, radius: float, obstacles: Array, arena_size: Vector2 = GameConfig.ARENA_SIZE) -> Array[Vector2]:
	var offset := second - first
	var distance := offset.length()
	var minimum_distance := radius * 2.0
	if distance >= minimum_distance:
		return [first, second]
	var direction := offset / distance if distance > 0.001 else Vector2.RIGHT
	var correction := direction * ((minimum_distance - distance) * 0.5)
	var moved_first := move_circle(first, -correction, radius, obstacles, arena_size)
	var moved_second := move_circle(second, correction, radius, obstacles, arena_size)
	if moved_first.distance_to(moved_second) < minimum_distance - 0.1:
		moved_second = move_circle(moved_second, direction * (minimum_distance - moved_first.distance_to(moved_second)), radius, obstacles, arena_size)
	if moved_first.distance_to(moved_second) < minimum_distance - 0.1:
		moved_first = move_circle(moved_first, -direction * (minimum_distance - moved_first.distance_to(moved_second)), radius, obstacles, arena_size)
	return [moved_first, moved_second]

static func segment_clear(from: Vector2, to: Vector2, obstacles: Array) -> bool:
	var distance := from.distance_to(to)
	var steps := maxi(1, ceili(distance / 8.0))
	for step in range(1, steps):
		var point := from.lerp(to, float(step) / float(steps))
		for obstacle in obstacles:
			if obstacle.has_point(point):
				return false
	return true

static func _overlaps_rect(center: Vector2, radius: float, rect: Rect2) -> bool:
	var closest := Vector2(clampf(center.x, rect.position.x, rect.end.x), clampf(center.y, rect.position.y, rect.end.y))
	return closest.distance_squared_to(center) < radius * radius

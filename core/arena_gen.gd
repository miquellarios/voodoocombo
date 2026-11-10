class_name ArenaGen
extends RefCounted

const W := 30
const H := 15
const SIZE := 40.0

static func generate(seed_value: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var blocked: Dictionary = {}
	var patterns := 2
	for i in range(patterns):
		var x := rng.randi_range(3, 11)
		var y := rng.randi_range(2, 5)
		var length := rng.randi_range(1, 3)
		var width := 1
		var height := 1
		if length > 1 and rng.randf() < 0.5:
			width = length
		else:
			height = length
		for dx in range(width):
			for dy in range(height):
				for sx in [x + dx, W - 1 - x - dx]:
					for sy in [y + dy, H - 1 - y - dy]:
						blocked[Vector2i(sx, sy)] = true
	return {"seed": seed_value, "biome": posmod(seed_value, 4), "blocked": blocked, "spawns": spawn_points(rng), "coins": coin_positions(rng, blocked)}

static func spawn_points(rng: RandomNumberGenerator) -> Array[Vector2]:
	var corners := rng.randf() < 0.5
	var points: Array[Vector2] = []
	if corners:
		points = [Vector2(100, 100), Vector2(1100, 100), Vector2(100, 500), Vector2(1100, 500)]
	else:
		points = [Vector2(600, 100), Vector2(1000, 300), Vector2(600, 500), Vector2(200, 300)]
	return points

static func coin_positions(rng: RandomNumberGenerator, blocked: Dictionary) -> Array[Vector2]:
	var coins: Array[Vector2] = []
	var attempts := 0
	while coins.size() < GameConfig.STARTING_COINS and attempts < 12000:
		attempts += 1
		var p := Vector2(rng.randf_range(55, 1145), rng.randf_range(55, 545))
		var cell := Vector2i(int(p.x / SIZE), int(p.y / SIZE))
		if blocked.has(cell):
			continue
		var clear := true
		for obstacle_cell in blocked:
			var obstacle_rect := Rect2(Vector2(obstacle_cell) * SIZE, Vector2.ONE * SIZE)
			var nearest := Vector2(clampf(p.x, obstacle_rect.position.x, obstacle_rect.end.x), clampf(p.y, obstacle_rect.position.y, obstacle_rect.end.y))
			if nearest.distance_to(p) < 35.0:
				clear = false
				break
		if not clear:
			continue
		for other in coins:
			if p.distance_squared_to(other) < 35.0 * 35.0:
				clear = false
				break
		if clear:
			coins.append(p)
	return coins

static func is_arena_connected(blocked: Dictionary) -> bool:
	var start := Vector2i(0, 0)
	while blocked.has(start) and start.x < W - 1:
		start.x += 1
	var visited: Dictionary = {start: true}
	var queue: Array[Vector2i] = [start]
	var index := 0
	while index < queue.size():
		var cell := queue[index]
		index += 1
		for step in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next: Vector2i = cell + step
			if next.x < 0 or next.y < 0 or next.x >= W or next.y >= H or blocked.has(next) or visited.has(next):
				continue
			visited[next] = true
			queue.append(next)
	return visited.size() == W * H - blocked.size()

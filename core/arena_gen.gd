class_name ArenaGen
extends RefCounted

const W := 30
const H := 15
const SIZE := 40.0
const DATA_PATH := "res://assets/arenas/arenas.json"

static func generate(seed_value: int, previous_arena_id: String = "", arena_id: String = "") -> Dictionary:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	if not data is Dictionary or not data.has("arenas"):
		push_error("No se pudo cargar %s" % DATA_PATH)
		return _fallback_arena(seed_value)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var arena_ids: Array = data.arenas.keys()
	arena_ids.sort()
	var selected_index := posmod(seed_value, arena_ids.size())
	var selected_arena: String = arena_ids[selected_index] if arena_id.is_empty() else arena_id
	if not data.arenas.has(selected_arena):
		selected_arena = arena_ids[selected_index]
	if arena_id.is_empty() and arena_ids.size() > 1 and selected_arena == previous_arena_id:
		selected_arena = arena_ids[(selected_index + 1) % arena_ids.size()]
	var source: Dictionary = data.arenas[selected_arena]
	var map_data: Dictionary = source.duplicate(true)
	var blocked: Dictionary = {}
	for obstacle in map_data.get("obstacles", []):
		var rect: Array = obstacle.rect
		var start_x := int(floor(float(rect[0]) / SIZE))
		var start_y := int(floor(float(rect[1]) / SIZE))
		var end_x := int(ceil((float(rect[0]) + float(rect[2])) / SIZE))
		var end_y := int(ceil((float(rect[1]) + float(rect[3])) / SIZE))
		for x in range(start_x, end_x):
			for y in range(start_y, end_y):
				blocked[Vector2i(x, y)] = true
	var spawn_sets: Array = map_data.get("spawn_sets", [])
	var spawn_set: Array = spawn_sets[rng.randi_range(0, spawn_sets.size() - 1)]
	var spawns: Array[Vector2] = []
	for point in spawn_set:
		spawns.append(Vector2(float(point[0]), float(point[1])))
	_shuffle_points(spawns, rng)
	var coins := coin_positions(rng, map_data, GameConfig.STARTING_COINS)
	return {
		"seed": seed_value,
		"biome": posmod(seed_value, 4),
		"map_id": selected_arena,
		"name": String(map_data.get("name", selected_arena)),
		"background": String(map_data.background.file),
		"obstacles": map_data.get("obstacles", []),
		"hazards": map_data.get("hazards", []),
		"sprites": data.get("sprites", {}),
		"blocked": blocked,
		"spawns": spawns,
		"coins": coins
	}

static func coin_positions(rng: RandomNumberGenerator, map_data: Dictionary, target_count: int = GameConfig.STARTING_COINS) -> Array[Vector2]:
	var coins: Array[Vector2] = []
	var obstacles: Array = map_data.get("obstacles", [])
	var hazards: Array = map_data.get("hazards", [])
	var attempts := 0
	while coins.size() < target_count and attempts < 30000:
		attempts += 1
		var position := Vector2(rng.randf_range(35.0, 1165.0), rng.randf_range(35.0, 565.0))
		var clear := true
		for obstacle in obstacles:
			var values: Array = obstacle.rect
			var rect := Rect2(Vector2(float(values[0]), float(values[1])), Vector2(float(values[2]), float(values[3])))
			var nearest := Vector2(clampf(position.x, rect.position.x, rect.end.x), clampf(position.y, rect.position.y, rect.end.y))
			if nearest.distance_to(position) < 35.0:
				clear = false
				break
		if not clear or _near_fixed_hazard(position, hazards):
			continue
		for other in coins:
			if position.distance_squared_to(other) < 35.0 * 35.0:
				clear = false
				break
		if clear:
			coins.append(position)
	return coins

static func _near_fixed_hazard(position: Vector2, hazards: Array) -> bool:
	for hazard in hazards:
		var kind := String(hazard.get("type", ""))
		if kind == "lodo" or kind == "raices":
			continue
		if hazard.has("tiles"):
			for tile in hazard.tiles:
				var values: Variant = tile if tile is Array else String(tile).split(" ", false)
				if values.size() < 4:
					continue
				var rect := Rect2(Vector2(float(values[0]), float(values[1])), Vector2(float(values[2]), float(values[3])))
				if rect.grow(35.0).has_point(position):
					return true
		for key in ["center", "a", "b"]:
			if hazard.has(key):
				var values: Array = hazard[key]
				var center := Vector2(float(values[0]), float(values[1]))
				var radius := 40.0
				if hazard.has("radius"):
					var raw_radius: Variant = hazard.radius
					radius = float(raw_radius[0]) if raw_radius is Array else float(raw_radius)
				elif kind == "rayo":
					radius = 65.0
				if center.distance_to(position) < radius + 35.0:
					return true
		if hazard.has("path"):
			for point in hazard.path:
				var values: Variant = point if point is Array else String(point).split(" ", false)
				if values.size() >= 2 and Vector2(float(values[0]), float(values[1])).distance_to(position) < 57.0:
					return true
	return false

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

static func _shuffle_points(points: Array[Vector2], rng: RandomNumberGenerator) -> void:
	for index in range(points.size() - 1, 0, -1):
		var other := rng.randi_range(0, index)
		var temporary := points[index]
		points[index] = points[other]
		points[other] = temporary

static func _fallback_arena(seed_value: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var blocked: Dictionary = {}
	var spawns: Array[Vector2] = [Vector2(100, 100), Vector2(1100, 100), Vector2(100, 500), Vector2(1100, 500)]
	_shuffle_points(spawns, rng)
	return {"seed": seed_value, "biome": posmod(seed_value, 4), "map_id": "", "name": "", "background": "", "obstacles": [], "hazards": [], "blocked": blocked, "spawns": spawns, "coins": coin_positions(rng, {}, GameConfig.STARTING_COINS)}

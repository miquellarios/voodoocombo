class_name BotBrain
extends RefCounted

static func choose_direction(position: Vector2, coins: Array[Vector2], opponents: Array[Vector2], dash_ready: bool, rng: RandomNumberGenerator) -> Dictionary:
	var target := position
	var best := INF
	for coin in coins:
		var distance := position.distance_squared_to(coin)
		if distance < best:
			best = distance
			target = coin
	var direction := (target - position).normalized()
	var dash := false
	if dash_ready:
		for opponent in opponents:
			if position.distance_to(opponent) < 120.0 and rng.randf() < 0.3:
				direction = (opponent - position).normalized()
				dash = true
				break
	return {"direction": direction, "dash": dash}

static func choose_dash_target(player: Dictionary, players: Array[Dictionary], player_index: int, obstacles: Array[Rect2], rng: RandomNumberGenerator) -> int:
	if float(player.get("dash_cd", 0.0)) > 0.0 or float(player.get("dash_lock", 0.0)) > 0.0 or float(player.get("bot_recent_hit", 0.0)) > 0.0 or String(player.get("item", "")) == "sheep":
		return -1
	for target_index in range(players.size()):
		if target_index == player_index:
			continue
		var target: Dictionary = players[target_index]
		if float(target.get("invuln", 0.0)) > 0.0 or float(target.get("stun", 0.0)) > 0.0:
			continue
		if player.pos.distance_to(target.pos) >= GameConfig.BOT_DASH_RANGE:
			continue
		if not ArenaPhysics.segment_clear(player.pos, target.pos, obstacles):
			continue
		if rng.randf() < GameConfig.BOT_DASH_CHANCE:
			return target_index
	return -1

static func find_path(position: Vector2, goal: Vector2, arena: Dictionary, elapsed: float = 0.0) -> Array[Vector2]:
	var grid := _build_grid(arena, elapsed)
	var from_cell := _world_to_cell(position)
	var to_cell := _world_to_cell(goal)
	if not _cell_in_bounds(from_cell) or not _cell_in_bounds(to_cell) or grid.is_point_solid(to_cell):
		return []
	var packed_path := grid.get_point_path(from_cell, to_cell)
	var path: Array[Vector2] = []
	for point in packed_path:
		path.append(point)
	if path.is_empty() or path[path.size() - 1].distance_to(goal) > 1.0:
		path.append(goal)
	return path

static func next_direction(player: Dictionary, coins: Array[Vector2], chests: Array[Vector2], arena: Dictionary, players: Array[Dictionary], player_index: int, delta: float, elapsed: float, rng: RandomNumberGenerator) -> Vector2:
	player.bot_repath_left = maxf(0.0, float(player.get("bot_repath_left", 0.0)) - delta)
	player.bot_stuck_left = float(player.get("bot_stuck_left", 0.0)) + delta
	if player.bot_stuck_left >= GameConfig.BOT_STUCK_CHECK_SECONDS:
		var old_position: Vector2 = player.get("bot_stuck_position", player.pos)
		if old_position.distance_to(player.pos) < GameConfig.BOT_STUCK_DISTANCE:
			player.bot_escape_direction = _random_free_direction(player.pos, arena, rng)
			player.bot_escape_left = GameConfig.BOT_ESCAPE_SECONDS
			player.bot_repath_left = 0.0
		player.bot_stuck_position = player.pos
		player.bot_stuck_left = 0.0
	player.bot_escape_left = maxf(0.0, float(player.get("bot_escape_left", 0.0)) - delta)
	if player.bot_escape_left > 0.0:
		return player.bot_escape_direction
	if player.bot_repath_left <= 0.0:
		_plan_path(player, coins, chests, arena, players, player_index, elapsed, rng)
		player.bot_repath_left = GameConfig.BOT_REPATH_SECONDS
	var path: Array = player.bot_path
	var path_index := int(player.get("bot_path_index", 0))
	while path_index < path.size() and player.pos.distance_to(path[path_index]) <= GameConfig.BOT_WAYPOINT_RADIUS:
		path_index += 1
	player.bot_path_index = path_index
	if path_index >= path.size():
		return Vector2.ZERO
	return (path[path_index] - player.pos).normalized()

static func _plan_path(player: Dictionary, coins: Array[Vector2], chests: Array[Vector2], arena: Dictionary, players: Array[Dictionary], player_index: int, elapsed: float, rng: RandomNumberGenerator) -> void:
	var targets: Array[Vector2] = coins.duplicate()
	if String(player.get("item", "")).is_empty():
		targets.append_array(chests)
	var grid := _build_grid(arena, elapsed)
	var from_cell := _world_to_cell(player.pos)
	var best_cost := INF
	var best_path: Array[Vector2] = []
	var best_target: Vector2 = player.pos
	for target in targets:
		var to_cell := _world_to_cell(target)
		if not _cell_in_bounds(to_cell) or grid.is_point_solid(to_cell):
			continue
		if _another_bot_is_closer(players, player_index, target, player.pos):
			continue
		var packed_path := grid.get_point_path(from_cell, to_cell)
		if packed_path.is_empty():
			continue
		var route: Array[Vector2] = []
		var cost := 0.0
		var previous: Vector2 = player.pos
		for point in packed_path:
			route.append(point)
			cost += previous.distance_to(point)
			previous = point
		cost += previous.distance_to(target)
		cost += rng.randf_range(0.0, GameConfig.BOT_TARGET_BIAS)
		if cost < best_cost:
			best_cost = cost
			best_path = route
			best_target = target
	if not best_path.is_empty() and best_path[best_path.size() - 1].distance_to(best_target) > 1.0:
		best_path.append(best_target)
	player.bot_path = best_path
	player.bot_path_index = 0
	player.bot_goal = best_target

static func _another_bot_is_closer(players: Array[Dictionary], player_index: int, target: Vector2, bot_position: Vector2) -> bool:
	for other_index in range(players.size()):
		if other_index == player_index:
			continue
		var other: Dictionary = players[other_index]
		if not bool(other.get("is_bot", false)):
			continue
		var other_goal: Vector2 = other.get("bot_goal", Vector2(-9999.0, -9999.0))
		if other_goal.distance_to(target) < GameConfig.BOT_TARGET_MATCH_DISTANCE and other.pos.distance_to(target) + GameConfig.BOT_TARGET_LEAD < bot_position.distance_to(target):
			return true
	return false

static func _build_grid(arena: Dictionary, elapsed: float) -> AStarGrid2D:
	var grid := AStarGrid2D.new()
	grid.region = Rect2i(Vector2i.ZERO, GameConfig.GRID_SIZE)
	grid.cell_size = Vector2.ONE * GameConfig.CELL_SIZE
	grid.offset = Vector2.ONE * (GameConfig.CELL_SIZE * 0.5)
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.update()
	for cell in arena.get("blocked", {}):
		if _cell_in_bounds(cell):
			grid.set_point_solid(cell)
	for obstacle in arena.get("obstacles", []):
		var values: Array = obstacle.get("rect", [])
		if values.size() < 4:
			continue
		var rect := Rect2(Vector2(float(values[0]), float(values[1])), Vector2(float(values[2]), float(values[3])))
		for x in range(GameConfig.GRID_SIZE.x):
			for y in range(GameConfig.GRID_SIZE.y):
				var cell := Vector2i(x, y)
				if grid.is_point_solid(cell):
					continue
				var center := _cell_center(cell)
				var closest := Vector2(clampf(center.x, rect.position.x, rect.end.x), clampf(center.y, rect.position.y, rect.end.y))
				if closest.distance_squared_to(center) < GameConfig.PLAYER_RADIUS * GameConfig.PLAYER_RADIUS:
					grid.set_point_solid(cell)
	_apply_hazard_costs(grid, arena.get("hazards", []), elapsed)
	return grid

static func _apply_hazard_costs(grid: AStarGrid2D, hazards: Array, elapsed: float) -> void:
	for hazard in hazards:
		var kind := String(hazard.get("type", ""))
		if kind == "pinchos":
			var cycle_length := float(hazard.get("down", 2.0)) + float(hazard.get("warn", 0.6)) + float(hazard.get("up", 1.0))
			var cycle := fposmod(elapsed + float(hazard.get("phase", 0.0)), cycle_length)
			if cycle >= float(hazard.get("down", 2.0)):
				for tile in hazard.get("tiles", []):
					var rect := _tile_rect(tile)
					_set_rect_cost(grid, rect, GameConfig.BOT_HAZARD_COST)
		elif kind == "barril":
			var center := _point(hazard.get("center", []))
			_set_circle_cost(grid, center, float(hazard.get("radius", 110.0)), GameConfig.BOT_HAZARD_COST)
		elif kind == "rayo":
			var center := _point(hazard.get("center", []))
			var angle := elapsed * TAU / maxf(0.01, float(hazard.get("period", 8.0)))
			_set_ray_cost(grid, center, angle, float(hazard.get("length", 280.0)), GameConfig.BOT_RAY_AVOID_DEGREES, GameConfig.BOT_HAZARD_COST)

static func _set_rect_cost(grid: AStarGrid2D, rect: Rect2, cost: float) -> void:
	var start := _world_to_cell(rect.position)
	var end := _world_to_cell(rect.end - Vector2.ONE)
	for x in range(start.x, end.x + 1):
		for y in range(start.y, end.y + 1):
			var cell := Vector2i(x, y)
			if _cell_in_bounds(cell) and not grid.is_point_solid(cell):
				grid.set_point_weight_scale(cell, cost)

static func _set_circle_cost(grid: AStarGrid2D, center: Vector2, radius: float, cost: float) -> void:
	var min_cell := _world_to_cell(center - Vector2.ONE * radius)
	var max_cell := _world_to_cell(center + Vector2.ONE * radius)
	for x in range(min_cell.x, max_cell.x + 1):
		for y in range(min_cell.y, max_cell.y + 1):
			var cell := Vector2i(x, y)
			if _cell_in_bounds(cell) and not grid.is_point_solid(cell) and _cell_center(cell).distance_to(center) <= radius:
				grid.set_point_weight_scale(cell, cost)

static func _set_ray_cost(grid: AStarGrid2D, center: Vector2, angle: float, length: float, avoid_degrees: float, cost: float) -> void:
	var cosine_limit := cos(deg_to_rad(avoid_degrees))
	for x in range(GameConfig.GRID_SIZE.x):
		for y in range(GameConfig.GRID_SIZE.y):
			var cell := Vector2i(x, y)
			if grid.is_point_solid(cell):
				continue
			var offset := _cell_center(cell) - center
			if offset.length() > length or offset.length() < 0.01:
				continue
			var direction := offset.normalized()
			if direction.dot(Vector2.RIGHT.rotated(angle)) >= cosine_limit or direction.dot(Vector2.LEFT.rotated(angle)) >= cosine_limit:
				grid.set_point_weight_scale(cell, cost)

static func _random_free_direction(position: Vector2, arena: Dictionary, rng: RandomNumberGenerator) -> Vector2:
	var directions: Array[Vector2] = [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN, Vector2(1, 1).normalized(), Vector2(-1, 1).normalized(), Vector2(1, -1).normalized(), Vector2(-1, -1).normalized()]
	for index in range(directions.size() - 1, 0, -1):
		var other := rng.randi_range(0, index)
		var temporary := directions[index]
		directions[index] = directions[other]
		directions[other] = temporary
	for direction in directions:
		var next := position + direction * GameConfig.BOT_ESCAPE_PROBE
		var cell := _world_to_cell(next)
		if _cell_in_bounds(cell) and not arena.get("blocked", {}).has(cell):
			return direction
	return Vector2.ZERO

static func _tile_rect(tile: Variant) -> Rect2:
	var values: Variant = tile if tile is Array else String(tile).split(" ", false)
	if values.size() < 4:
		return Rect2()
	return Rect2(Vector2(float(values[0]), float(values[1])), Vector2(float(values[2]), float(values[3])))

static func _point(value: Variant) -> Vector2:
	if value is Array and value.size() >= 2:
		return Vector2(float(value[0]), float(value[1]))
	return Vector2.ZERO

static func _world_to_cell(position: Vector2) -> Vector2i:
	return Vector2i(floori(position.x / GameConfig.CELL_SIZE), floori(position.y / GameConfig.CELL_SIZE))

static func _cell_center(cell: Vector2i) -> Vector2:
	return (Vector2(cell) + Vector2.ONE * 0.5) * GameConfig.CELL_SIZE

static func _cell_in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < GameConfig.GRID_SIZE.x and cell.y < GameConfig.GRID_SIZE.y

extends SceneTree

var failures := 0

func _initialize() -> void:
	_test_scoring()
	_test_drop_limits()
	_test_arena()
	_test_arena_physics()
	_test_bot_pathfinding()
	_test_bot_dash_rate()
	_test_items()
	_test_ranking()
	if failures == 0:
		print("All VoodooCombo core tests passed")
		quit(0)
	else:
		push_error("%d test(s) failed" % failures)
		quit(1)

func _check(condition: bool, label: String) -> void:
	if not condition:
		failures += 1
		push_error("FAILED: " + label)

func _test_scoring() -> void:
	_check(Scoring.multiplier(4) == 1 and Scoring.multiplier(5) == 2, "combo x2 threshold")
	_check(Scoring.multiplier(10) == 3 and Scoring.multiplier(20) == 4, "combo x3/x4 thresholds")
	_check(Scoring.coin_value(5, true, true) == 8, "frenzy and ring value")
	_check(Scoring.coin_value(20, false, false, true) == 1, "classic coin value")
	_check(Scoring.next_combo(7, 1.49) == 8 and Scoring.next_combo(7, 1.5) == 1, "combo timer")

func _test_drop_limits() -> void:
	_check(Scoring.dropped_coins(2, false, false) == 2, "cannot drop more than held")
	_check(Scoring.dropped_coins(40, false, false) == 10, "normal drop percent")
	_check(Scoring.dropped_coins(40, true, false) == 12, "crown drop cap")
	_check(Scoring.dropped_coins(20, false, true) == 8, "ring drop")

func _test_arena() -> void:
	for seed_value in range(1, 30):
		var arena := ArenaGen.generate(seed_value)
		_check(arena.biome == posmod(seed_value, 4), "biome from seed")
		_check(ArenaGen.is_arena_connected(arena.blocked), "arena connectivity")
		_check(arena.coins.size() == 50, "50 starting coins")
		for cell in arena.blocked:
			_check(arena.blocked.has(Vector2i(29 - cell.x, cell.y)), "horizontal obstacle symmetry")
			_check(arena.blocked.has(Vector2i(cell.x, 14 - cell.y)), "vertical obstacle symmetry")
		for i in range(arena.coins.size()):
			for j in range(i + 1, arena.coins.size()):
				_check(arena.coins[i].distance_to(arena.coins[j]) >= 35.0, "coin separation")

func _test_arena_physics() -> void:
	var obstacle: Array[Rect2] = [Rect2(100.0, 100.0, 40.0, 40.0)]
	var start := Vector2(78.0, 89.0)
	var slid := ArenaPhysics.move_circle(start, Vector2(12.0, 12.0), 22.0, obstacle)
	_check(slid.y > start.y and is_equal_approx(slid.x, start.x), "circle slides along obstacle")
	var separated := ArenaPhysics.separate_pair(Vector2(100.0, 100.0), Vector2(100.0, 100.0), 22.0, [])
	_check(separated[0].distance_to(separated[1]) >= 44.0, "overlapping players separate to collision diameter")

func _test_bot_pathfinding() -> void:
	var blocked: Dictionary = {}
	var map_obstacles: Array[Dictionary] = []
	for y in range(8):
		blocked[Vector2i(5, y)] = true
		map_obstacles.append({"rect": [200, y * 40, 40, 40]})
	var arena := {"blocked": blocked, "obstacles": map_obstacles, "hazards": []}
	var goal := Vector2(300.0, 100.0)
	var path := BotBrain.find_path(Vector2(100.0, 100.0), goal, arena)
	_check(not path.is_empty(), "bot finds route around obstacle")
	var obstacle_rects: Array[Rect2] = []
	for cell in blocked:
		obstacle_rects.append(Rect2(Vector2(cell) * 40.0, Vector2.ONE * 40.0))
	var position := Vector2(100.0, 100.0)
	var path_index := 0
	for _frame in range(300):
		while path_index < path.size() and position.distance_to(path[path_index]) <= GameConfig.BOT_WAYPOINT_RADIUS:
			path_index += 1
		if path_index >= path.size() or position.distance_to(goal) < 28.0:
			break
		var direction: Vector2 = (path[path_index] - position).normalized()
		position = ArenaPhysics.move_circle(position, direction * GameConfig.PLAYER_SPEED / 60.0, GameConfig.PLAYER_RADIUS, obstacle_rects)
	_check(position.distance_to(goal) < 28.0, "bot reaches target behind obstacle within five seconds")

func _test_bot_dash_rate() -> void:
	var players: Array[Dictionary] = [
		{"pos": Vector2(300.0, 300.0), "is_bot": true, "dash_cd": 0.0, "dash_lock": 0.0, "bot_recent_hit": 0.0, "item": "", "stun": 0.0, "invuln": 0.0},
		{"pos": Vector2(330.0, 300.0), "is_bot": true, "dash_cd": 0.0, "dash_lock": 0.0, "bot_recent_hit": 0.0, "item": "", "stun": 0.0, "invuln": 0.0}
	]
	var decision_left := [0.0, 0.0]
	var rng := RandomNumberGenerator.new()
	rng.seed = 33
	var dash_count := 0
	var team_dash_left := 0.0
	for _frame in range(600):
		team_dash_left = maxf(0.0, team_dash_left - 1.0 / 60.0)
		for i in range(players.size()):
			players[i].dash_cd = maxf(0.0, players[i].dash_cd - 1.0 / 60.0)
			players[i].bot_recent_hit = maxf(0.0, players[i].bot_recent_hit - 1.0 / 60.0)
			decision_left[i] -= 1.0 / 60.0
			if decision_left[i] <= 0.0 and team_dash_left <= 0.0:
				decision_left[i] = rng.randf_range(GameConfig.BOT_DECISION_MIN_SECONDS, GameConfig.BOT_DECISION_MAX_SECONDS)
				var target := BotBrain.choose_dash_target(players[i], players, i, [], rng)
				if target >= 0:
					dash_count += 1
					players[i].dash_cd = GameConfig.DASH_COOLDOWN
					players[i].bot_recent_hit = GameConfig.BOT_RECENT_HIT_LOCK_SECONDS
					team_dash_left = GameConfig.BOT_TEAM_DASH_INTERVAL
		var separated := ArenaPhysics.separate_pair(players[0].pos, players[1].pos, GameConfig.PLAYER_RADIUS, [])
		players[0].pos = separated[0]
		players[1].pos = separated[1]
	_check(dash_count <= 4, "nearby bots do not spam more than four dashes in ten seconds")
	_check(players[0].pos.distance_to(players[1].pos) >= GameConfig.PLAYER_RADIUS * 2.0, "nearby bots remain separated")

func _test_items() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	for place in ["first", "middle", "last"]:
		_check(ItemTable.probabilities_sum(place) == 100, "item probabilities sum to 100: " + place)
	_check(ItemTable.probabilities_sum("middle", true) == 97, "classic excludes ring weights")
	for _i in range(100):
		_check(ItemTable.roll("first", rng, true) != "ring", "classic excludes ring")

func _test_ranking() -> void:
	var players: Array[Dictionary] = [{"name": "A", "score": 10, "max_combo": 4}, {"name": "B", "score": 10, "max_combo": 9}]
	_check(MatchRanking.rank(players)[0].name == "B", "combo tie-break")

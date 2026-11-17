extends SceneTree

var failures := 0

func _initialize() -> void:
	_test_scoring()
	_test_drop_limits()
	_test_arena()
	_test_arena_physics()
	_test_player_foot_collision()
	_test_bot_pathfinding()
	_test_bot_dash_rate()
	_test_hazard_rules()
	_test_items()
	_test_spell_rules()
	_test_nickname_rules()
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
	_check(Scoring.multiplier(11) == 2 and Scoring.multiplier(12) == 3 and Scoring.multiplier(20) == 3, "combo x3 threshold and cap")
	_check(Scoring.coin_value(0, false, false) == 1, "base coin value")
	_check(Scoring.coin_value(5, false, false) == 2, "combo bonus value")
	_check(Scoring.coin_value(12, false, false) == 3, "high combo value")
	_check(Scoring.coin_value(5, true, false) == 3, "frenzy adds one point")
	_check(Scoring.coin_value(5, false, true) == 3, "ring adds one point")
	_check(Scoring.coin_value(12, true, true) == 5, "maximum coin value is five")
	_check(Scoring.coin_value(99, true, true) <= 5, "coin value never exceeds five")
	_check(Scoring.coin_value(20, false, false, true) == 1, "classic coin value")
	_check(Scoring.next_combo(7, 1.49) == 8 and Scoring.next_combo(7, 1.5) == 1, "combo timer")

func _test_drop_limits() -> void:
	_check(Scoring.dropped_coins(2, false, false) == 2, "cannot drop more than held")
	_check(Scoring.dropped_coins(40, false, false) == 10, "normal drop percent")
	_check(Scoring.dropped_coins(40, true, false) == 12, "crown drop cap")
	_check(Scoring.dropped_coins(20, false, true) == 8, "ring drop")

func _test_arena() -> void:
	for arena_id in GameConfig.ARENA_IDS:
		_check(ArenaGen.generate(41, "", arena_id).map_id == arena_id, "explicit arena selection: " + arena_id)
	for seed_value in range(1, 30):
		var arena := ArenaGen.generate(seed_value)
		_check(arena.biome == posmod(seed_value, 4), "biome from seed")
		_check(ArenaGen.is_arena_connected(arena.blocked), "arena connectivity")
		_check(arena.coins.size() == GameConfig.STARTING_COINS, "Voodoo starts with 30 coins")
		_check(ArenaGen.generate(seed_value, arena.map_id).map_id != arena.map_id, "random arena avoids the previous map")
		_check(ArenaGen.generate(seed_value, "", "", true).coins.size() == GameConfig.CLASSIC_STARTING_COINS, "Classic starts with 50 coins")
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

func _test_player_foot_collision() -> void:
	var obstacle: Array[Rect2] = [Rect2(100.0, 100.0, 40.0, 40.0)]
	var feet := Vector2(78.0, 100.0)
	for _frame in range(60):
		feet = ArenaPhysics.move_circle(feet, Vector2(2.0, 0.0), GameConfig.PLAYER_FOOT_RADIUS, obstacle)
	_check(feet.x > 80.0 and feet.x <= 86.1, "feet reach the obstacle before stopping")
	_check(feet.distance_to(Vector2(100.0, 100.0)) >= GameConfig.PLAYER_FOOT_RADIUS - 0.1, "feet circle does not penetrate obstacle")

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

func _test_hazard_rules() -> void:
	_check(HazardRules.spike_state(0.0, 0.0, 2.0, 0.6, 1.0) == "down", "spikes stay down initially")
	_check(HazardRules.spike_state(2.3, 0.0, 2.0, 0.6, 1.0) == "warn", "spikes warn before rising")
	_check(HazardRules.spike_state(3.0, 0.0, 2.0, 0.6, 1.0) == "up", "spikes rise after warning")
	_check(HazardRules.steam_state(0.0, 4.0, 0.6, 0.5) == "warn", "steam starts with warning")
	_check(HazardRules.steam_state(0.7, 4.0, 0.6, 0.5) == "blast", "steam blast follows warning")
	_check(HazardRules.steam_state(1.2, 4.0, 0.6, 0.5) == "idle", "steam blast ends")
	_check(HazardRules.point_segment_distance(Vector2(5.0, 2.0), Vector2.ZERO, Vector2(10.0, 0.0)) == 2.0, "ray point-to-segment distance")
	_check(HazardRules.ray_hits(Vector2(5.0, 2.0), Vector2.ZERO, Vector2(10.0, 0.0), 2.0), "ray segment detects contact")
	_check(not HazardRules.ray_hits(Vector2(5.0, 3.0), Vector2.ZERO, Vector2(10.0, 0.0), 2.0), "ray segment rejects distant points")
	_check(HazardRules.drop_amount(40, 0.25, 3, 12) == 10, "hit drop percentage")
	_check(HazardRules.drop_amount(100, 0.4, 3, 12) == 12, "hit drop upper limit")
	_check(HazardRules.drop_amount(2, 0.25, 3, 12) == 2, "hit drop cannot exceed coins held")
	_check(HazardRules.drop_amount(0, GameConfig.TRAP_DROP_PCT, GameConfig.TRAP_DROP_MIN, GameConfig.TRAP_DROP_MAX) == 0, "trap cannot drop coins when empty")
	_check(HazardRules.drop_amount(1, GameConfig.TRAP_DROP_PCT, GameConfig.TRAP_DROP_MIN, GameConfig.TRAP_DROP_MAX) == 1, "trap drops only the one held coin")
	_check(HazardRules.drop_amount(10, GameConfig.TRAP_DROP_PCT, GameConfig.TRAP_DROP_MIN, GameConfig.TRAP_DROP_MAX) == 2, "trap minimum is two coins")
	_check(HazardRules.drop_amount(40, GameConfig.TRAP_DROP_PCT, GameConfig.TRAP_DROP_MIN, GameConfig.TRAP_DROP_MAX) == 6, "trap drops fifteen percent")
	_check(HazardRules.drop_amount(200, GameConfig.TRAP_DROP_PCT, GameConfig.TRAP_DROP_MIN, GameConfig.TRAP_DROP_MAX) == 10, "trap maximum is ten coins")
	var shielded := HazardRules.resolve_hit({"coins": 10, "score": 10, "item": "cloak", "item_time": 8.0, "invuln": 0.0, "combo": 5, "stun": 0.0, "hits": 0}, 0.25, 3, 12, 0.4)
	_check(shielded.blocked and shielded.victim.coins == 10 and shielded.victim.item == "", "cloak blocks and consumes a hit")
	var invulnerable := HazardRules.resolve_hit({"coins": 10, "item": "", "invuln": 1.0, "combo": 5, "stun": 0.0, "hits": 0}, 0.25, 3, 12, 0.4)
	_check(not invulnerable.applied and invulnerable.victim.coins == 10, "invulnerability blocks hits")
	var struck := HazardRules.resolve_hit({"coins": 40, "score": 40, "item": "", "invuln": 0.0, "combo": 7, "stun": 0.0, "hits": 0}, 0.25, 3, 12, 0.4)
	_check(struck.applied and struck.dropped == 10 and struck.victim.score == 30 and struck.victim.combo == 0 and struck.victim.stun == 0.4, "shared hit applies damage state")

func _test_items() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	for place in ["first", "middle", "last"]:
		_check(ItemTable.probabilities_sum(place) == 100, "item probabilities sum to 100: " + place)
	_check(ItemTable.probabilities_sum("middle", true) == 97, "classic excludes ring weights")
	for _i in range(100):
		_check(ItemTable.roll("first", rng, true) != "ring", "classic excludes ring")

func _test_spell_rules() -> void:
	var held := {"item": "boots", "item_time": 0.0}
	_check(SpellRules.can_activate(held) and not SpellRules.is_active(held, "boots"), "picked-up spell waits for activation")
	var active := SpellRules.activate(held)
	_check(is_equal_approx(float(active.item_time), GameConfig.SPELL_BOOTS_SECONDS), "activating boots starts its duration")
	_check(not SpellRules.can_activate(active) and SpellRules.is_active(active, "boots"), "active spell cannot be activated twice")
	_check(SpellRules.duration("pin") == 0.0 and SpellRules.duration("frost") == 0.0, "instant spells have no duration")
	var inactive_cloak := HazardRules.resolve_hit({"coins": 10, "score": 10, "item": "cloak", "item_time": 0.0, "invuln": 0.0, "combo": 1, "stun": 0.0, "hits": 0}, 0.25, 3, 12, 0.4)
	_check(inactive_cloak.applied, "held cloak does not block before activation")

func _test_nickname_rules() -> void:
	_check(NicknameRules.is_valid(" Ada ") and NicknameRules.normalize(" Ada ") == "Ada", "nickname trims outside spaces")
	_check(not NicknameRules.is_valid("AB") and not NicknameRules.is_valid("ABCDEFGHIJKLM"), "nickname length is limited to 3-12 characters")

func _test_ranking() -> void:
	var players: Array[Dictionary] = [{"name": "A", "score": 10, "max_combo": 4}, {"name": "B", "score": 10, "max_combo": 9}]
	_check(MatchRanking.rank(players)[0].name == "B", "combo tie-break")

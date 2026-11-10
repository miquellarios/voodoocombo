extends Node

func _ready() -> void:
	var failures := 0
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	if Scoring.multiplier(5) != 2 or Scoring.multiplier(10) != 3 or Scoring.multiplier(20) != 4: failures += 1
	if Scoring.coin_value(5, true, true) != 8: failures += 1
	if Scoring.dropped_coins(40, false, false) != 10 or Scoring.dropped_coins(40, true, false) != 12: failures += 1
	if ItemTable.probabilities_sum("first") != 100 or ItemTable.probabilities_sum("middle") != 100 or ItemTable.probabilities_sum("last") != 100: failures += 1
	for seed_value in range(1, 12):
		var arena := ArenaGen.generate(seed_value)
		if arena.coins.size() != 50 or not ArenaGen.is_arena_connected(arena.blocked): failures += 1
		for cell in arena.blocked:
			if not arena.blocked.has(Vector2i(29 - cell.x, cell.y)) or not arena.blocked.has(Vector2i(cell.x, 14 - cell.y)):
				failures += 1
	if failures > 0:
		push_error("Smoke tests failed: %d" % failures)
	else:
		print("VoodooCombo smoke tests passed")

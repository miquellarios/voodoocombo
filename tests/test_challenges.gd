extends SceneTree

func _initialize() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var first := ChallengeRules.choose(rng)
	rng.seed = 42
	assert(first == ChallengeRules.choose(rng) and first.size() == 3)
	var done := ChallengeRules.completed({"stolen":6,"max_combo":12,"spells_used":2},["steal","combo","spells"])
	assert(done.size() == 3 and ChallengeRules.bonus(done) == 60)
	assert(ChallengeRules.bonus(["steal","steal"]) == 20)
	print("Seeded challenges, completion and XP passed")
	quit()

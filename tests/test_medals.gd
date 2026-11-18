extends SceneTree

func _initialize() -> void:
	var rules := MatchAchievements.new()
	rules.setup(2)
	var players: Array[Dictionary] = [{"score":0,"combo":0},{"score":5,"combo":0}]
	var hits: Array[Dictionary] = [{"type":"player_hit","attacker":0,"victim":1,"dropped":8}]
	rules.update(players,hits,1)
	assert("primera_sangre" in players[0].medals and "robo_maestro" in players[0].medals)
	hits[0].attacker = 1
	hits[0].victim = 0
	rules.update(players,hits,2)
	assert("venganza" in players[1].medals)
	var none: Array[Dictionary] = []
	rules.update(players,none,33)
	assert("intocable" in players[0].medals)
	players[0].combo = 12
	rules.update(players,none,34)
	players[0].combo = 0
	rules.update(players,none,35)
	players[0].combo = 12
	rules.update(players,none,36)
	assert("rey_combo" in players[0].medals)
	print("Authoritative medal conditions passed")
	quit()

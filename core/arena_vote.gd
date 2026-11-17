class_name ArenaVote
extends RefCounted

var rng := RandomNumberGenerator.new()
var voters: Array[Dictionary] = []
var votes: Dictionary = {}
var elapsed := 0.0
var phase := "voting"
var spin_elapsed := 0.0
var winner := ""
var hops: Array[Dictionary] = []
var bot_times: Dictionary = {}
var seed_value := 0

func setup(seed_number: int, players: Array[Dictionary]) -> void:
	seed_value = seed_number
	rng.seed = seed_number
	voters = players.duplicate(true)
	votes.clear()
	hops.clear()
	bot_times.clear()
	elapsed = 0.0
	spin_elapsed = 0.0
	winner = ""
	phase = "voting"
	for player: Dictionary in voters:
		if bool(player.is_bot): bot_times[int(player.peer_id)] = rng.randf_range(0.1, GameConfig.VOTE_BOT_SECONDS)

func vote(sender: int, arena_id: String) -> bool:
	if phase != "voting" or not arena_id in GameConfig.ARENA_IDS: return false
	for player: Dictionary in voters:
		if int(player.peer_id) == sender:
			votes[sender] = arena_id
			return true
	return false

func step(delta: float) -> bool:
	if phase == "voting":
		elapsed += delta
		for id: int in bot_times:
			if elapsed >= float(bot_times[id]) and not votes.has(id): vote(id, GameConfig.ARENA_IDS[rng.randi_range(0, 3)])
		if elapsed >= GameConfig.VOTE_SECONDS or votes.size() == voters.size(): _resolve()
	else:
		spin_elapsed += delta
	return phase != "voting" and spin_elapsed >= (GameConfig.VOTE_SPIN_SECONDS if not hops.is_empty() else 0.0) + GameConfig.VOTE_WINNER_SECONDS

func _resolve() -> void:
	var counts := {}
	for arena_id in GameConfig.ARENA_IDS: counts[arena_id] = 0
	for arena_id: String in votes.values(): counts[arena_id] += 1
	var best := 0
	for count: int in counts.values(): best = maxi(best, count)
	var tied: Array[String] = []
	for arena_id in GameConfig.ARENA_IDS:
		if counts[arena_id] == best: tied.append(arena_id)
	winner = tied[rng.randi_range(0, tied.size() - 1)]
	if tied.size() > 1:
		var step_count := GameConfig.VOTE_SPIN_STEPS
		var start := posmod(tied.find(winner) - step_count + 1, tied.size())
		var total := 0.0
		for index in step_count: total += 0.06 + pow(float(index) / float(step_count - 1), 3.0)
		var at := 0.0
		for index in step_count:
			hops.append({"arena": tied[(start + index) % tied.size()], "at": at})
			at += (0.06 + pow(float(index) / float(step_count - 1), 3.0)) * GameConfig.VOTE_SPIN_SECONDS / total
	phase = "roulette" if not hops.is_empty() else "winner"

func snapshot() -> Dictionary:
	return {"votes": votes.duplicate(), "elapsed": elapsed, "phase": phase, "spin_elapsed": spin_elapsed, "winner": winner, "hops": hops.duplicate(true), "seed": seed_value}

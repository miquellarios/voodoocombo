extends SceneTree

func _initialize() -> void:
	var roster: Array[Dictionary] = []
	for id in 4: roster.append({"peer_id": id + 2, "is_bot": false})
	var first := _vote(roster)
	var second := _vote(roster)
	assert(first == second)
	assert(first.hops.size() > 0 and first.hops.back().arena == first.winner)
	var nobody := ArenaVote.new()
	nobody.setup(4, roster)
	nobody.step(10.1)
	assert(nobody.hops.size() > 0)
	assert(not nobody.vote(2, "cienaga"))
	print("Tied voting, no-vote roulette and seeded timeline passed")
	quit()

func _vote(roster: Array[Dictionary]) -> Dictionary:
	var vote := ArenaVote.new()
	vote.setup(42, roster)
	vote.vote(2, "cienaga")
	vote.vote(3, "cienaga")
	vote.vote(4, "cripta")
	vote.vote(5, "cripta")
	vote.step(0.1)
	assert(not vote.vote(99, "taller"))
	return vote.snapshot()

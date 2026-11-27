extends SceneTree

const SNAPSHOT_CODEC = preload("res://net/snapshot_codec.gd")

func _initialize() -> void:
	var roster: Array[Dictionary] = []
	var acknowledgements := {}
	for index in 4:
		var peer_id := index + 2
		roster.append({"name": "Player%d" % (index + 1), "is_bot": false, "peer_id": peer_id})
		acknowledgements[peer_id] = 299
	var largest_compressed := 0
	for arena_id in GameConfig.ARENA_IDS:
		var sim := MatchSim.new()
		sim.setup({"seed": 13013, "mode": "voodoo", "arena_id": arena_id, "players": roster})
		for _frame in 300: sim.step(GameConfig.NET_TICK, [])
		var packet: Dictionary = SNAPSHOT_CODEC.prepare(sim.snapshot(), acknowledgements)
		var restored: Dictionary = SNAPSHOT_CODEC.restore(packet)
		if restored.hazard_runtime.size() != sim.hazard_runtime.size() or float(restored.roll_time) != 0.0 or int(restored.roll_player) != -1:
			push_error("Compact snapshot did not restore client render defaults")
			quit(1)
			return
		var expanded_players := SNAPSHOT_CODEC.expand_players(restored, sim.players)
		if expanded_players.size() != 4 or expanded_players[0].pos.distance_to(sim.players[0].pos) > 1.0 or expanded_players[0].score != sim.players[0].score:
			push_error("Compact player view did not restore visible values")
			quit(1)
			return
		var coinless := SNAPSHOT_CODEC.prepare(sim.snapshot(), acknowledgements, false)
		if coinless.has("coins"):
			push_error("Coin list was sent during a non-refresh snapshot")
			quit(1)
			return
		var compact_sample: Dictionary = packet.duplicate(true)
		compact_sample.hazard_runtime[0] = [1, 2, 125.0, 275.0]
		compact_sample.hazard_runtime[1] = [2, 3, 0.4]
		var expanded_sample: Dictionary = SNAPSHOT_CODEC.restore(compact_sample)
		if str(expanded_sample.hazard_runtime[0].roots_state) != "active" or Vector2(expanded_sample.hazard_runtime[0].roots_position) != Vector2(125.0, 275.0) or str(expanded_sample.hazard_runtime[1].barrel_state) != "fusing":
			push_error("Compact snapshot lost active hazard visuals")
			quit(1)
			return
		var bytes := var_to_bytes(packet)
		var compressed := bytes.compress(FileAccess.COMPRESSION_ZSTD)
		largest_compressed = maxi(largest_compressed, compressed.size())
		print("%s four-player snapshot: %d B raw, %d B compressed" % [arena_id, bytes.size(), compressed.size()])
	if largest_compressed >= GameConfig.NET_CHUNK_BYTES:
		push_error("Snapshot exceeds one packet: %d B" % largest_compressed)
		quit(1)
		return
	quit(0)

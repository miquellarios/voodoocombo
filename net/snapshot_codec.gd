class_name SnapshotCodec
extends RefCounted

static func prepare(snapshot: Dictionary, acknowledgements: Dictionary, include_coins: bool = true) -> Dictionary:
	var packet := snapshot.duplicate(true)
	var arena: Dictionary = packet.get("arena", {})
	for key in ["players", "mode", "arena", "obstacle_rects", "player_hitbox_rects", "seed_value", "bots_dash_global_left", "round_wait", "frenzy_notified", "pending_sheep", "round_number", "sudden_death", "team_scores", "challenges"]: packet.erase(key)
	packet["rw"] = _round_tenth(snapshot.get("round_wait", 0.0))
	var player_views: Array = []
	for player: Dictionary in snapshot.get("players", []):
		var position: Vector2 = player.get("pos", Vector2.ZERO)
		var velocity: Vector2 = player.get("vel", Vector2.ZERO)
		var facing: Vector2 = player.get("look_dir", Vector2.RIGHT)
		var dash_dir: Vector2 = player.get("dash_dir", facing)
		player_views.append([
			roundi(position.x), roundi(position.y), roundi(velocity.x), roundi(velocity.y),
			roundi(facing.x * 100.0), roundi(facing.y * 100.0), int(player.get("score", 0)), int(player.get("coins", 0)),
			int(player.get("combo", 0)), int(player.get("max_combo", 0)),
			_round_tenth(player.get("dash_left", 0.0)), _round_tenth(player.get("dash_cd", 0.0)),
			roundi(dash_dir.x * 100.0), roundi(dash_dir.y * 100.0),
			_round_tenth(player.get("stun", 0.0)), _round_tenth(player.get("invuln", 0.0)),
			_round_tenth(player.get("rooted_left", 0.0)), str(player.get("item", "")),
			_round_tenth(player.get("item_time", 0.0)), _round_tenth(player.get("frozen_left", 0.0)),
			bool(player.get("ghost", false)), int(player.get("lives", 0)), int(player.get("team", 0)),
			bool(player.get("disconnected", false)), _round_tenth(player.get("last_pickup", -10.0))
		])
	packet["pv"] = player_views
	if not include_coins: packet.erase("coins")
	if float(packet.get("roll_time", 0.0)) <= 0.0:
		for key in ["roll_time", "roll_player", "roll_result"]: packet.erase(key)
	for player: Dictionary in packet.get("players", []):
		for key: String in player.keys():
			if key.begins_with("bot_"): player.erase(key)
	var compact_runtime: Array = []
	var hazard_types: Array = arena.get("hazards", [])
	var runtime_list: Array = packet.get("hazard_runtime", [])
	for index in runtime_list.size():
		var source: Dictionary = runtime_list[index]
		var kind := str(hazard_types[index].get("type", "")) if index < hazard_types.size() else ""
		var compact: Array = []
		if kind == "raices" and str(source.get("roots_state", "idle")) != "idle":
			var root_state := 1 if str(source.roots_state) == "warn" else 2
			var root_position: Vector2 = source.get("roots_position", Vector2.ZERO)
			compact = [1, root_state, root_position.x, root_position.y]
		if kind == "barril" and str(source.get("barrel_state", "idle")) != "idle":
			var barrel_state: int = int({"fusing": 3, "exploding": 4, "hidden": 5}.get(str(source.barrel_state), 0))
			compact = [2, barrel_state, float(source.get("barrel_timer", 0.0))]
		compact_runtime.append(compact)
	packet["hazard_runtime"] = compact_runtime
	packet["ack"] = acknowledgements.duplicate()
	return packet

static func _round_tenth(value: Variant) -> int:
	return roundi(float(value) * 10.0)

static func expand_players(packet: Dictionary, base_players: Array) -> Array[Dictionary]:
	var players: Array[Dictionary] = []
	var fields := ["pos", "vel", "look_dir", "score", "coins", "combo", "max_combo", "dash_left", "dash_cd", "dash_dir", "stun", "invuln", "rooted_left", "item", "item_time", "frozen_left", "ghost", "lives", "team", "disconnected", "last_pickup"]
	for index in packet.get("pv", []).size():
		var player: Dictionary = base_players[index].duplicate(true) if index < base_players.size() else {}
		var view: Array = packet.pv[index]
		if view.size() < fields.size() + 4: continue
		var values: Array = [
			Vector2(float(view[0]), float(view[1])), Vector2(float(view[2]), float(view[3])), Vector2(float(view[4]) / 100.0, float(view[5]) / 100.0),
			int(view[6]), int(view[7]), int(view[8]), int(view[9]), float(view[10]) / 10.0, float(view[11]) / 10.0,
			Vector2(float(view[12]) / 100.0, float(view[13]) / 100.0), float(view[14]) / 10.0, float(view[15]) / 10.0,
			float(view[16]) / 10.0, str(view[17]), float(view[18]) / 10.0, float(view[19]) / 10.0,
			bool(view[20]), int(view[21]), int(view[22]), bool(view[23]), float(view[24]) / 10.0
		]
		for field_index in fields.size(): player[fields[field_index]] = values[field_index]
		players.append(player)
	return players

static func restore(packet: Dictionary) -> Dictionary:
	var decoded := packet.duplicate(true)
	decoded["round_wait"] = float(decoded.get("rw", 0)) / 10.0
	decoded.erase("rw")
	if not decoded.has("roll_time"):
		decoded["roll_time"] = 0.0
		decoded["roll_player"] = -1
		decoded["roll_result"] = ""
	var expanded: Array[Dictionary] = []
	for compact: Array in decoded.get("hazard_runtime", []):
		var runtime: Dictionary = {}
		if compact.size() >= 4 and int(compact[0]) == 1:
			runtime["roots_state"] = "warn" if int(compact[1]) == 1 else "active"
			runtime["roots_position"] = Vector2(float(compact[2]), float(compact[3]))
		elif compact.size() >= 3 and int(compact[0]) == 2:
			runtime["barrel_state"] = {3: "fusing", 4: "exploding", 5: "hidden"}.get(int(compact[1]), "idle")
			runtime["barrel_timer"] = float(compact[2])
		expanded.append(runtime)
	decoded["hazard_runtime"] = expanded
	return decoded

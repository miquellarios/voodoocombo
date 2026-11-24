class_name SnapshotCodec
extends RefCounted

static func prepare(snapshot: Dictionary, acknowledgements: Dictionary) -> Dictionary:
	var packet := snapshot.duplicate(true)
	var arena: Dictionary = packet.get("arena", {})
	for key in ["arena", "obstacle_rects", "player_hitbox_rects", "seed_value", "bots_dash_global_left", "round_wait", "frenzy_notified"]: packet.erase(key)
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

static func restore(packet: Dictionary) -> Dictionary:
	var decoded := packet.duplicate(true)
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

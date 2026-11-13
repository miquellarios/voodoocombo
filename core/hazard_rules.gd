class_name HazardRules
extends RefCounted

static func spike_state(elapsed: float, phase: float, down: float, warn: float, up: float) -> String:
	var cycle := fposmod(elapsed + phase, down + warn + up)
	if cycle < down:
		return "down"
	if cycle < down + warn:
		return "warn"
	return "up"

static func steam_state(elapsed: float, period: float, warn: float, blast: float) -> String:
	var cycle := fposmod(elapsed, period)
	if cycle < warn:
		return "warn"
	if cycle < warn + blast:
		return "blast"
	return "idle"

static func point_segment_distance(point: Vector2, start: Vector2, end: Vector2) -> float:
	var segment := end - start
	var length_squared := segment.length_squared()
	if length_squared <= 0.0001:
		return point.distance_to(start)
	var t := clampf((point - start).dot(segment) / length_squared, 0.0, 1.0)
	return point.distance_to(start + segment * t)

static func ray_hits(point: Vector2, start: Vector2, end: Vector2, hit_radius: float) -> bool:
	return point_segment_distance(point, start, end) <= hit_radius

static func drop_amount(coins: int, fraction: float, minimum: int, maximum: int) -> int:
	if coins <= 0:
		return 0
	return mini(coins, clampi(int(ceil(float(coins) * fraction)), minimum, maximum))

static func can_apply_hit(invulnerability: float, has_cloak: bool) -> bool:
	return invulnerability <= 0.0 and not has_cloak

static func resolve_hit(victim: Dictionary, fraction: float, minimum: int, maximum: int, stun: float) -> Dictionary:
	var changed: Dictionary = victim.duplicate(true)
	if float(changed.get("invuln", 0.0)) > 0.0:
		return {"applied": false, "blocked": false, "dropped": 0, "victim": changed}
	if String(changed.get("item", "")) == "cloak":
		changed.item = ""
		changed.item_time = 0.0
		return {"applied": false, "blocked": true, "dropped": 0, "victim": changed}
	var dropped := drop_amount(int(changed.get("coins", 0)), fraction, minimum, maximum)
	changed.coins = int(changed.get("coins", 0)) - dropped
	changed.score = changed.coins
	changed.stun = maxf(float(changed.get("stun", 0.0)), stun)
	changed.invuln = GameConfig.HIT_INVULN_SECONDS
	changed.combo = 0
	changed.hits = int(changed.get("hits", 0)) + 1
	return {"applied": true, "blocked": false, "dropped": dropped, "victim": changed}

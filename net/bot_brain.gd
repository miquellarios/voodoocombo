class_name BotBrain
extends RefCounted

static func choose_direction(position: Vector2, coins: Array[Vector2], opponents: Array[Vector2], dash_ready: bool, rng: RandomNumberGenerator) -> Dictionary:
	var target := position
	var best := INF
	for coin in coins:
		var distance := position.distance_squared_to(coin)
		if distance < best:
			best = distance
			target = coin
	var direction := (target - position).normalized()
	var dash := false
	if dash_ready:
		for opponent in opponents:
			if position.distance_to(opponent) < 120.0 and rng.randf() < 0.3:
				direction = (opponent - position).normalized()
				dash = true
				break
	return {"direction": direction, "dash": dash}

extends Node2D

var particles: Array[Dictionary] = []
var flights: Array[Dictionary] = []

func _process(delta: float) -> void:
	for index in range(particles.size() - 1, -1, -1):
		var p: Dictionary = particles[index]
		p.time -= delta
		if not Settings.reduce_motion: p.pos += p.vel * delta
		if p.time <= 0: particles.remove_at(index)
	queue_redraw()

func _draw() -> void:
	for p in particles:
		draw_circle(p.pos, p.get("radius", 2.0), Color(p.color, clampf(p.time / GameConfig.JUICE_SPARK_SECONDS, 0, 1)))
	for flight in flights:
		draw_circle(flight.pos, 6, GameConfig.GOLD)
		draw_circle(flight.pos + Vector2(-1,-1), 2, Color("fff6c2"))

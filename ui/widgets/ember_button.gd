extends Button

var phase := 0.0

func _process(delta: float) -> void:
	if not Settings.reduce_motion: phase += delta
	queue_redraw()

func _draw() -> void:
	if not has_focus() and not is_hovered(): return
	var tint := GameConfig.EMBER
	draw_circle(Vector2(12.0, size.y * 0.5), 3.0, tint)
	draw_line(Vector2(28.0, size.y - 6.0), Vector2(size.x - 28.0, size.y - 6.0), tint, 1.0)
	if Settings.reduce_motion: return
	for index in range(4):
		var progress := fposmod(phase * 0.6 + index * 0.25, 1.0)
		draw_circle(Vector2(24.0 + index * (size.x - 48.0) / 4.0, size.y - 8.0 - progress * 24.0), 1.5, Color(tint, 1.0 - progress))

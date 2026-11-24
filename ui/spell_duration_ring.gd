extends Control

var progress := 0.0:
	set(value):
		progress = clampf(value, 0.0, 1.0)
		queue_redraw()

func _draw() -> void:
	if progress <= 0.0: return
	draw_arc(size * 0.5, minf(size.x, size.y) * 0.46, -PI * 0.5, -PI * 0.5 + TAU * progress, 64, GameConfig.EMBER, GameConfig.SPELL_SLOT_RING_WIDTH, true)

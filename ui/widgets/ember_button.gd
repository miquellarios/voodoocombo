extends Button

var phase := 0.0
var feedback_tween: Tween

func _ready() -> void:
	mouse_entered.connect(func(): _feedback(1.05, 700))
	focus_entered.connect(func(): _feedback(1.05, 700))
	mouse_exited.connect(func(): _feedback(1.0, 0))
	focus_exited.connect(func(): _feedback(1.0, 0))
	button_down.connect(func(): _feedback(0.95, 190))
	button_up.connect(func(): _feedback(1.05, 0))

func _feedback(target: float, tone: float) -> void:
	if tone > 0: Sfx.play_tone(tone, 0.035, 0.06)
	if Settings.reduce_motion: return
	if feedback_tween: feedback_tween.kill()
	pivot_offset = size * 0.5
	feedback_tween = create_tween()
	feedback_tween.tween_property(self, "scale", Vector2.ONE * target, 0.1)

func _process(delta: float) -> void:
	if not Settings.reduce_motion: phase += delta
	queue_redraw()

func _draw() -> void:
	if not has_focus() and not is_hovered(): return
	var tint := GameConfig.EMBER
	draw_circle(Vector2(12.0, size.y * 0.5), 3.0, tint)
	draw_line(Vector2(12, size.y * 0.5), Vector2(25, size.y * 0.5 + 13), GameConfig.BONE_TEXT, 2)
	draw_line(Vector2(28.0, size.y - 6.0), Vector2(size.x - 28.0, size.y - 6.0), tint, 1.0)
	if Settings.reduce_motion: return
	for index in range(4):
		var progress := fposmod(phase * 0.6 + index * 0.25, 1.0)
		draw_circle(Vector2(24.0 + index * (size.x - 48.0) / 4.0, size.y - 8.0 - progress * 24.0), 1.5, Color(tint, 1.0 - progress))

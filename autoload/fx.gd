extends Node

signal floating_text(text: String, position: Vector2, tint: Color)
signal shake(amount: float)

var text_layer: CanvasLayer
var canvas: Node2D
var hitstop := 0.0
var squash: Dictionary = {}

func _process(delta: float) -> void:
	hitstop = maxf(0, hitstop - delta)
	for index in squash.keys():
		squash[index] = maxf(0, float(squash[index]) - delta)

func _canvas() -> Node2D:
	if not is_instance_valid(canvas):
		var layer := CanvasLayer.new()
		layer.layer = 19
		add_child(layer)
		canvas = load("res://ui/juice_canvas.gd").new()
		layer.add_child(canvas)
	return canvas

func sparks(at: Vector2, color: Color, count: int = GameConfig.JUICE_SPARK_COUNT) -> void:
	var target := _canvas()
	for index in count:
		target.particles.append({"pos": at, "vel": Vector2.from_angle(TAU * index / count) * randf_range(40,110), "color": color, "time": GameConfig.JUICE_SPARK_SECONDS})

func vibrate(strength: float) -> void:
	if Settings.vibration:
		for device in Input.get_connected_joypads(): Input.start_joy_vibration(device, strength * 0.5, strength, 0.1)

func fly_coin(from: Vector2, to: Vector2) -> void:
	if Settings.reduce_motion:
		sparks(to, GameConfig.GOLD, 2)
		return
	var target := _canvas()
	var flight := {"pos": from}
	target.flights.append(flight)
	var tween := create_tween()
	tween.tween_method(func(t: float): flight.pos = from.lerp(to, t) + Vector2(0, -sin(t * PI) * 70), 0.0, 1.0, GameConfig.JUICE_FLIGHT_SECONDS)
	tween.tween_callback(func():
		target.flights.erase(flight)
		Sfx.play_tone(1200, 0.035)
	)

func squash_scale(index: int) -> Vector2:
	if Settings.reduce_motion: return Vector2.ONE
	return Vector2.ONE.lerp(GameConfig.JUICE_SQUASH, clampf(float(squash.get(index,0)) / GameConfig.JUICE_SQUASH_SECONDS,0,1))

func feedback(event: Dictionary, local_player: int) -> void:
	if event.type == "coin_taken":
		squash[int(event.player)] = GameConfig.JUICE_SQUASH_SECONDS
		sparks(event.pos + Vector2(40,60), GameConfig.GOLD)
		if int(event.combo) >= 12 and not Settings.reduce_motion: shake.emit(4.0)
		if int(event.player) == local_player and int(event.combo) >= 5: vibrate(0.2)
	elif event.type == "player_hit":
		var heavy := int(event.dropped) >= GameConfig.JUICE_HEAVY_COINS
		if not Settings.reduce_motion:
			hitstop = GameConfig.JUICE_TRAP_HITSTOP if int(event.attacker) < 0 else (GameConfig.JUICE_HEAVY_HITSTOP if heavy else GameConfig.JUICE_HITSTOP)
			shake.emit(6.0)
		if int(event.victim) == local_player: vibrate(0.8)
		elif int(event.attacker) == local_player: vibrate(0.5)

func render_pop(text: String, position: Vector2, tint: Color) -> void:
	if not is_instance_valid(text_layer):
		text_layer = CanvasLayer.new()
		text_layer.layer = 20
		add_child(text_layer)
	var numeric := text.begins_with("+") or text.begins_with("-")
	var loss := text.begins_with("-")
	var banner := text in [I18n.t("frenzy"), I18n.t("voodoo_combo")]
	var label := Label.new()
	label.text = text
	var font_size := GameConfig.FLOAT_NOTICE_LARGE_FONT_SIZE if banner else (GameConfig.FLOAT_COIN_FONT_SIZE if numeric else GameConfig.FLOAT_NOTICE_FONT_SIZE)
	label.add_theme_font_override("font", ThemeBuilder.title_font(font_size) if banner else ThemeBuilder.font("Oswald-Bold.woff2"))
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_constant_override("outline_size", GameConfig.FLOAT_NOTICE_OUTLINE_SIZE if banner else GameConfig.FLOAT_COIN_OUTLINE_SIZE)
	label.add_theme_color_override("font_outline_color", Color("0b0710"))
	var color := tint
	if numeric: color = GameConfig.LOSS_TEXT if loss else (GameConfig.BONE_TEXT if int(text) == 1 else GameConfig.EMBER)
	if banner: color = GameConfig.EMBER
	label.add_theme_color_override("font_color", color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.size = Vector2(GameConfig.FLOAT_NOTICE_TEXT_WIDTH, font_size * 2)
	label.position = position - label.size * 0.5
	label.pivot_offset = label.size * 0.5
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_layer.add_child(label)
	var duration := GameConfig.FLOAT_COIN_SECONDS if numeric else GameConfig.FLOAT_NOTICE_SECONDS
	var tween := label.create_tween().set_parallel(true)
	if not Settings.reduce_motion:
		label.scale = Vector2.ONE * (2.4 if banner else 1.8)
		tween.tween_property(label, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(label, "position:y", label.position.y + (20.0 if loss else -50.0), duration)
		if loss:
			var origin_x := label.position.x
			tween.tween_method(func(t: float): label.position.x = origin_x + sin(t * TAU * 4.0) * 3.0 * (1.0 - t), 0.0, 1.0, 0.2)
		elif numeric and int(text) > 1:
			label.rotation = deg_to_rad(6.0 if int(text) % 2 == 0 else -6.0)
			tween.tween_property(label, "rotation", 0.0, 0.15)
		if banner:
			var line := ColorRect.new()
			line.mouse_filter = Control.MOUSE_FILTER_IGNORE
			line.color = GameConfig.EMBER
			line.position = Vector2(0.0, font_size * 1.4)
			line.size = Vector2(0.0, 2.0)
			label.add_child(line)
			tween.tween_property(line, "size:x", label.size.x, 0.3)
			var pulse := label.create_tween()
			pulse.tween_interval(0.15)
			for _beat in range(2):
				pulse.tween_property(label, "scale", Vector2.ONE * 1.08, 0.15)
				pulse.tween_property(label, "scale", Vector2.ONE, 0.15)
		tween.tween_property(label, "scale", Vector2.ONE * 0.6, 0.25).set_delay(duration - 0.25)
	tween.tween_property(label, "modulate:a", 0.0, 0.25).set_delay(duration - 0.25)
	tween.chain().tween_callback(label.queue_free)

func clear_text() -> void:
	if is_instance_valid(text_layer):
		text_layer.queue_free()
		text_layer = null

func pop(text: String, position: Vector2, tint: Color = Color.WHITE) -> void:
	floating_text.emit(text, position, tint)

func hit() -> void:
	if not Settings.reduce_motion:
		shake.emit(6.0)

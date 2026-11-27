extends CanvasLayer

signal closed

const TABS := ["settings_tab_game", "settings_tab_display", "settings_tab_sound", "settings_tab_online"]
const BONE := Color("efe7da")
const EMBER := Color("ff6a2b")
const PANEL := Color("241838")
var selected_tab := 0
var page: VBoxContainer
var focusables: Array[Control] = []
var tab_buttons: Array[Button] = []

func _ready() -> void:
	layer = 30
	Settings.scale_canvas_layer(self)
	_build()

func _build() -> void:
	var backdrop := ColorRect.new()
	backdrop.color = Color("0b0710", 0.97)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	var outer := MarginContainer.new()
	outer.theme = ThemeBuilder.build()
	outer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	outer.add_theme_constant_override("margin_left", 100)
	outer.add_theme_constant_override("margin_right", 100)
	outer.add_theme_constant_override("margin_top", 12)
	outer.add_theme_constant_override("margin_bottom", 12)
	add_child(outer)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 10)
	outer.add_child(layout)
	var title := Label.new()
	title.text = I18n.t("settings")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.custom_minimum_size.y = 58.0
	title.add_theme_font_size_override("font_size", 44)
	title.add_theme_font_override("font", ThemeBuilder.title_font(44))
	title.add_theme_color_override("font_color", EMBER)
	layout.add_child(title)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	layout.add_child(tabs)
	for i in TABS.size():
		var tab := Button.new()
		tab.text = I18n.t(TABS[i])
		tab.custom_minimum_size = Vector2(220.0, 46.0)
		tab.focus_mode = Control.FOCUS_ALL
		tab.add_theme_font_size_override("font_size", 20)
		tab.add_theme_font_override("font", ThemeBuilder.title_font(20, true))
		tab.add_theme_color_override("font_color", EMBER if i == selected_tab else BONE)
		tab.pressed.connect(func() -> void: selected_tab = i; _refresh())
		tabs.add_child(tab)
		tab_buttons.append(tab)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(scroll)
	page = VBoxContainer.new()
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.add_theme_constant_override("separation", 8)
	scroll.add_child(page)
	var footer := HBoxContainer.new()
	footer.custom_minimum_size.y = 48
	layout.add_child(footer)
	var hint := Label.new()
	hint.text = I18n.t("settings_help_controls")
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.add_theme_color_override("font_color", Color("b8a9d1"))
	hint.add_theme_font_size_override("font_size", 16)
	footer.add_child(hint)
	var back := Button.new()
	back.text = I18n.t("menu")
	back.custom_minimum_size = GameConfig.SETTINGS_BACK_SIZE
	back.add_theme_font_size_override("font_size", 20)
	back.pressed.connect(_close)
	footer.add_child(back)
	_refresh()
	if focusables.size() > 0: focusables[0].grab_focus()

func _refresh() -> void:
	if not is_instance_valid(page): return
	focusables.clear()
	for index in tab_buttons.size():
		tab_buttons[index].add_theme_color_override("font_color", EMBER if index == selected_tab else BONE)
		tab_buttons[index].custom_minimum_size = Vector2(220.0, 46.0)
		tab_buttons[index].add_theme_font_size_override("font_size", 20)
	for child in page.get_children(): child.queue_free()
	match selected_tab:
		0:
			_add_choice("settings_ui_scale", ["75 %", "85 %", "100 %", "115 %", "130 %", "150 %"], _get_scale_index, _set_scale_index)
			_add_choice("settings_reduce_motion", ["settings_no", "settings_yes"], func() -> int: return int(Settings.reduce_motion), func(v: int) -> void: Settings.reduce_motion = v == 1)
			_add_choice("settings_reduce_flashes", ["settings_no", "settings_yes"], func() -> int: return int(Settings.reduce_flashes), func(v: int) -> void: Settings.reduce_flashes = v == 1)
			_add_choice("settings_vibration", ["settings_no", "settings_yes"], func() -> int: return int(Settings.vibration), func(v: int) -> void: Settings.vibration = v == 1)
			_add_choice("settings_language", ["settings_language_es", "settings_language_ca", "settings_language_en"], _get_language_index, _set_language_index, true)
		1:
			_add_choice("settings_display_mode", ["settings_windowed", "settings_fullscreen"], func() -> int: return int(Settings.window_fullscreen), func(v: int) -> void: Settings.window_fullscreen = v == 1; Settings.apply_display())
			var sizes: Array[String] = []
			for size: Vector2i in GameConfig.WINDOW_SIZE_OPTIONS: sizes.append("%d × %d" % [size.x, size.y])
			_add_choice("settings_window_size", sizes, func() -> int: return Settings.window_size_index, func(v: int) -> void: Settings.window_size_index = v; Settings.apply_display(), false, Settings.window_fullscreen)
		2:
			_add_slider("settings_music", "music_volume")
			_add_slider("settings_sfx", "sfx_volume")
		3:
			_add_choice("settings_server", ["settings_local", "settings_lan", "settings_oracle"], func() -> int: return Settings.server_choice, _set_server_choice, true)
			_add_text_field("settings_address", "server_host", GameConfig.SETTINGS_INPUT_MAX_LENGTH)
			_add_text_field("settings_port", "server_port", 5, true)
			_add_action("settings_logs", "logs_open", _open_logs_folder)
	if focusables.size() > 0: focusables[0].grab_focus()

func _new_row(key: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0.0, GameConfig.SETTINGS_ROW_SIZE.y)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 12)
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL
	style.border_color = Color("5c496d")
	style.set_border_width_all(1)
	style.set_content_margin_all(12)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", style)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.add_child(panel)
	panel.add_child(row)
	row.set_meta("panel_style", style)
	var label := Label.new()
	label.text = I18n.t(key)
	label.custom_minimum_size.x = minf(GameConfig.SETTINGS_ROW_LABEL_WIDTH, 440.0)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	label.add_theme_font_size_override("font_size", 23)
	label.add_theme_font_override("font", ThemeBuilder.font("Oswald-Medium.woff2"))
	label.add_theme_color_override("font_color", BONE)
	row.add_child(label)
	return row

func _add_choice(key: String, options: Array, getter: Callable, setter: Callable, translated := false, disabled := false) -> void:
	var row := _new_row(key)
	var prev := _arrow("‹")
	row.add_child(prev)
	var value := Button.new()
	value.flat = true
	value.focus_mode = Control.FOCUS_ALL
	value.custom_minimum_size.x = GameConfig.SETTINGS_VALUE_WIDTH
	value.add_theme_font_size_override("font_size", 22)
	value.add_theme_font_override("font", ThemeBuilder.font("Oswald-Medium.woff2"))
	value.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	value.add_theme_color_override("font_color", BONE)
	var value_stack := VBoxContainer.new()
	value_stack.alignment = BoxContainer.ALIGNMENT_CENTER
	value_stack.add_child(value)
	var scale_dots := Label.new()
	scale_dots.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	scale_dots.add_theme_font_size_override("font_size", 12)
	scale_dots.add_theme_color_override("font_color", EMBER)
	scale_dots.visible = key == "settings_ui_scale"
	value_stack.add_child(scale_dots)
	row.add_child(value_stack)
	var next := _arrow("›")
	row.add_child(next)
	prev.disabled = disabled
	value.disabled = disabled
	next.disabled = disabled
	var update := func() -> void:
		var index := posmod(int(getter.call()), options.size())
		var text := str(options[index])
		value.text = I18n.t(text) if translated or text.begins_with("settings_") else text
		if key == "settings_ui_scale":
			var dots := PackedStringArray()
			for dot_index in options.size(): dots.append("●" if dot_index == index else "·")
			scale_dots.text = " ".join(dots)
			prev.disabled = index <= 0
			next.disabled = index >= options.size() - 1
			prev.modulate = Color("817b88") if prev.disabled else Color.WHITE
			next.modulate = Color("817b88") if next.disabled else Color.WHITE
	var change := func(delta: int) -> void:
		var current_index := int(getter.call())
		var index := clampi(current_index + delta, 0, options.size() - 1) if key == "settings_ui_scale" else posmod(current_index + delta, options.size())
		if index == current_index: return
		setter.call(index)
		Settings.save()
		Sfx.play_tone(520.0, 0.04, 0.08)
		update.call()
		if key == "settings_ui_scale": Settings.apply_ui_scale(); return
		if key in ["settings_language", "settings_server", "settings_display_mode"]: _refresh(); return
		if not Settings.reduce_motion: value.scale = Vector2(1.05, 1.05); create_tween().tween_property(value, "scale", Vector2.ONE, 0.12)
	value.focus_entered.connect(func():
		var style: StyleBoxFlat = row.get_meta("panel_style")
		style.border_color = EMBER
		style.set_border_width_all(2)
	)
	value.focus_exited.connect(func():
		var style: StyleBoxFlat = row.get_meta("panel_style")
		style.border_color = Color("5c496d")
		style.set_border_width_all(1)
	)
	prev.pressed.connect(func() -> void: change.call(-1))
	next.pressed.connect(func() -> void: change.call(1))
	update.call()
	value.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventKey and event.pressed:
			if event.keycode == KEY_LEFT: change.call(-1); value.accept_event()
			elif event.keycode == KEY_RIGHT: change.call(1); value.accept_event()
	)
	focusables.append(value)

func _arrow(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = GameConfig.SETTINGS_ARROW_SIZE
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 32)
	button.add_theme_font_override("font", ThemeBuilder.font("Oswald-Bold.woff2"))
	return button

func _add_slider(key: String, setting: String) -> void:
	var row := _new_row(key)
	var slider := HSlider.new()
	var previous := _arrow("‹")
	previous.pressed.connect(func() -> void: slider.value = maxf(0.0, slider.value - GameConfig.SETTINGS_SLIDER_STEP); Sfx.play_tone(520.0, 0.04, 0.08))
	row.add_child(previous)
	slider.custom_minimum_size.x = GameConfig.SETTINGS_SLIDER_WIDTH
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.min_value = 0
	slider.max_value = 100
	slider.step = GameConfig.SETTINGS_SLIDER_STEP
	slider.value = float(Settings.get(setting)) * 100.0
	slider.focus_mode = Control.FOCUS_ALL
	var label := Label.new()
	label.custom_minimum_size.x = 64
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_font_override("font", ThemeBuilder.font("Oswald-Medium.woff2"))
	row.add_child(slider)
	var next := _arrow("›")
	next.pressed.connect(func() -> void: slider.value = minf(100.0, slider.value + GameConfig.SETTINGS_SLIDER_STEP); Sfx.play_tone(520.0, 0.04, 0.08))
	row.add_child(next)
	row.add_child(label)
	slider.value_changed.connect(func(v: float) -> void: Settings.set(setting, v / 100.0); Settings.save(); label.text = "%d%%" % int(v))
	slider.drag_ended.connect(func(_changed: bool) -> void: Sfx.play_tone(660.0, 0.06, 0.12))
	label.text = "%d%%" % int(slider.value)
	focusables.append(slider)

func _add_text_field(key: String, setting: String, max_chars: int, read_only := false) -> void:
	var row := _new_row(key)
	var input := LineEdit.new()
	input.custom_minimum_size = Vector2(400.0, 48.0)
	input.add_theme_font_size_override("font_size", 18)
	input.add_theme_font_override("font", ThemeBuilder.font("Oswald-Medium.woff2"))
	input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	input.max_length = max_chars
	input.text = str(Settings.get(setting))
	input.focus_mode = Control.FOCUS_ALL
	input.editable = not read_only and (setting != "server_host" or Settings.server_choice != 0)
	if read_only: input.focus_mode = Control.FOCUS_NONE
	if not read_only:
		input.text_submitted.connect(func(text: String) -> void: _store_field(setting, text))
		input.focus_exited.connect(func() -> void: _store_field(setting, input.text))
	row.add_child(input)
	if not read_only: focusables.append(input)

func _add_action(label_key: String, button_key: String, action: Callable) -> void:
	var row := _new_row(label_key)
	var button := Button.new()
	button.text = I18n.t(button_key)
	button.custom_minimum_size = Vector2(GameConfig.SETTINGS_VALUE_WIDTH, 48.0)
	button.add_theme_font_size_override("font_size", 19)
	button.add_theme_font_override("font", ThemeBuilder.font("Oswald-Bold.woff2"))
	button.pressed.connect(action)
	row.add_child(button)
	focusables.append(button)

func _open_logs_folder() -> void:
	var logs_path := ProjectSettings.globalize_path("user://logs")
	var error := OS.shell_open(logs_path)
	if error != OK: push_warning("No se pudo abrir la carpeta de registros: %s" % logs_path)

func _store_field(setting: String, text: String) -> void:
	if setting == "server_port":
		if text.is_valid_int(): Settings.server_port = clampi(int(text), 1, 65535)
	else:
		Settings.server_host = text.strip_edges()
	Settings.save()

func _get_scale_index() -> int:
	return GameConfig.SETTINGS_UI_SCALE_VALUES.find(Settings.ui_scale)

func _set_scale_index(index: int) -> void:
	Settings.ui_scale = GameConfig.SETTINGS_UI_SCALE_VALUES[index]

func _get_language_index() -> int:
	return ["es", "ca", "en"].find(I18n.language)

func _set_language_index(index: int) -> void:
	I18n.set_language(["es", "ca", "en"][index])

func _set_server_choice(index: int) -> void:
	Settings.server_choice = index
	if index == 0: Settings.server_host = "127.0.0.1"
	elif index == 2: Settings.server_host = GameConfig.ONLINE_HOST

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE: _close()

func _close() -> void:
	closed.emit()
	queue_free()

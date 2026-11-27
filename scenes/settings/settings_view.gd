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
	_build()

func _build() -> void:
	var backdrop := ColorRect.new()
	backdrop.color = Color("0b0710", 0.97)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	var outer := MarginContainer.new()
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
	title.custom_minimum_size.y = 58.0 * Settings.ui_scale
	title.add_theme_font_size_override("font_size", roundi(44.0 * Settings.ui_scale))
	title.add_theme_color_override("font_color", EMBER)
	layout.add_child(title)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	layout.add_child(tabs)
	for i in TABS.size():
		var tab := Button.new()
		tab.text = I18n.t(TABS[i])
		tab.custom_minimum_size = Vector2(minf(220.0 * Settings.ui_scale, 260.0), 46.0 * Settings.ui_scale)
		tab.focus_mode = Control.FOCUS_ALL
		tab.add_theme_font_size_override("font_size", roundi(20.0 * Settings.ui_scale))
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
	hint.add_theme_font_size_override("font_size", roundi(16.0 * Settings.ui_scale))
	footer.add_child(hint)
	var back := Button.new()
	back.text = I18n.t("menu")
	back.custom_minimum_size = GameConfig.SETTINGS_BACK_SIZE * Settings.ui_scale
	back.add_theme_font_size_override("font_size", roundi(20.0 * Settings.ui_scale))
	back.pressed.connect(_close)
	footer.add_child(back)
	_refresh()
	if focusables.size() > 0: focusables[0].grab_focus()

func _refresh() -> void:
	if not is_instance_valid(page): return
	focusables.clear()
	for index in tab_buttons.size():
		tab_buttons[index].add_theme_color_override("font_color", EMBER if index == selected_tab else BONE)
		tab_buttons[index].custom_minimum_size = Vector2(minf(220.0 * Settings.ui_scale, 260.0), 46.0 * Settings.ui_scale)
		tab_buttons[index].add_theme_font_size_override("font_size", roundi(20.0 * Settings.ui_scale))
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
			_add_action("logs_open", _open_logs_folder)
	if focusables.size() > 0: focusables[0].grab_focus()

func _new_row(key: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0.0, GameConfig.SETTINGS_ROW_SIZE.y * Settings.ui_scale)
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
	var label := Label.new()
	label.text = I18n.t(key)
	label.custom_minimum_size.x = minf(GameConfig.SETTINGS_ROW_LABEL_WIDTH * Settings.ui_scale, 440.0)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	label.add_theme_font_size_override("font_size", roundi(23.0 * Settings.ui_scale))
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
	value.custom_minimum_size.x = GameConfig.SETTINGS_VALUE_WIDTH * Settings.ui_scale
	value.add_theme_font_size_override("font_size", roundi(22.0 * Settings.ui_scale))
	value.add_theme_color_override("font_color", BONE)
	var value_stack := VBoxContainer.new()
	value_stack.alignment = BoxContainer.ALIGNMENT_CENTER
	value_stack.add_child(value)
	var scale_dots := Label.new()
	scale_dots.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	scale_dots.add_theme_font_size_override("font_size", roundi(12.0 * Settings.ui_scale))
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
	var change := func(delta: int) -> void:
		var index := posmod(int(getter.call()) + delta, options.size())
		setter.call(index)
		Settings.save()
		Sfx.play_tone(520.0, 0.04, 0.08)
		update.call()
		if key in ["settings_ui_scale", "settings_language", "settings_server", "settings_display_mode"]: _refresh(); return
		if not Settings.reduce_motion: value.scale = Vector2(1.05, 1.05); create_tween().tween_property(value, "scale", Vector2.ONE, 0.12)
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
	button.custom_minimum_size = GameConfig.SETTINGS_ARROW_SIZE * Settings.ui_scale
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", roundi(32.0 * Settings.ui_scale))
	return button

func _add_slider(key: String, setting: String) -> void:
	var row := _new_row(key)
	var slider := HSlider.new()
	var previous := _arrow("‹")
	previous.pressed.connect(func() -> void: slider.value = maxf(0.0, slider.value - GameConfig.SETTINGS_SLIDER_STEP); Sfx.play_tone(520.0, 0.04, 0.08))
	row.add_child(previous)
	slider.custom_minimum_size.x = maxf(140.0, GameConfig.SETTINGS_SLIDER_WIDTH - (Settings.ui_scale - 1.0) * 180.0)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.min_value = 0
	slider.max_value = 100
	slider.step = GameConfig.SETTINGS_SLIDER_STEP
	slider.value = float(Settings.get(setting)) * 100.0
	slider.focus_mode = Control.FOCUS_ALL
	var label := Label.new()
	label.custom_minimum_size.x = 64
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.add_theme_font_size_override("font_size", roundi(16.0 * Settings.ui_scale))
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
	input.custom_minimum_size = Vector2(400.0 * Settings.ui_scale, 48.0 * Settings.ui_scale)
	input.add_theme_font_size_override("font_size", roundi(18.0 * Settings.ui_scale))
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

func _add_action(key: String, action: Callable) -> void:
	var row := _new_row(key)
	var button := Button.new()
	button.text = I18n.t(key)
	button.custom_minimum_size = Vector2(GameConfig.SETTINGS_VALUE_WIDTH * Settings.ui_scale, 48.0 * Settings.ui_scale)
	button.add_theme_font_size_override("font_size", roundi(19.0 * Settings.ui_scale))
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

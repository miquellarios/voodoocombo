class_name ThemeBuilder
extends RefCounted

static func font(filename: String) -> Font:
	var path := "res://assets/fonts/" + filename
	return load(path) as Font if ResourceLoader.exists(path) else ThemeDB.fallback_font

static func title_font(size: int, button: bool = false) -> Font:
	var variation := FontVariation.new()
	variation.base_font = font("Cinzel-Bold.woff2")
	variation.spacing_glyph = roundi(size * (GameConfig.BUTTON_TRACKING if button else GameConfig.TITLE_TRACKING))
	return variation

static func build() -> Theme:
	var theme := Theme.new()
	theme.default_font = font("Oswald-Medium.woff2")
	theme.default_font_size = 18
	for state in ["normal", "hover", "focus", "pressed", "disabled"]:
		theme.set_stylebox(state, "Button", StyleBoxEmpty.new())
	theme.set_color("font_color", "Button", GameConfig.BONE_TEXT)
	theme.set_color("font_hover_color", "Button", GameConfig.EMBER)
	theme.set_color("font_focus_color", "Button", GameConfig.EMBER)
	theme.set_color("font_pressed_color", "Button", GameConfig.EMBER)
	theme.set_color("font_color", "Label", GameConfig.BONE_TEXT)
	theme.set_font("font", "Button", title_font(26, true))
	return theme

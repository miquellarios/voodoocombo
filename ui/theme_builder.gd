class_name ThemeBuilder
extends RefCounted

static func build() -> Theme:
	var theme := Theme.new()
	var body_font := load("res://assets/fonts/Baloo2-Regular.woff2") as Font
	var button_font := load("res://assets/fonts/NewRocker-Regular.woff2") as Font
	if body_font != null: theme.default_font = body_font
	theme.set_stylebox("normal", "Button", button_box("res://assets/ui/boton.png"))
	theme.set_stylebox("hover", "Button", button_box("res://assets/ui/boton_hover.png"))
	theme.set_stylebox("focus", "Button", button_box("res://assets/ui/boton_hover.png"))
	theme.set_stylebox("pressed", "Button", button_box("res://assets/ui/boton_pulsado.png"))
	theme.set_color("font_color", "Button", Color.WHITE)
	theme.set_color("font_hover_color", "Button", Color("ffd23f"))
	theme.set_color("font_focus_color", "Button", Color("ffd23f"))
	if button_font != null: theme.set_font("font", "Button", button_font)
	return theme

static func button_box(path: String) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = load(path)
	style.set_texture_margin_all(24.0)
	style.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
	style.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
	style.set_content_margin_all(14.0)
	return style

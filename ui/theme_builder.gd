class_name ThemeBuilder
extends RefCounted

static func build() -> Theme:
	var theme := Theme.new()
	var button := StyleBoxFlat.new()
	button.bg_color = Color("443452")
	button.border_color = Color("ffd23f")
	button.set_border_width_all(3)
	button.set_corner_radius_all(14)
	button.content_margin_left = 18
	button.content_margin_right = 18
	button.content_margin_top = 10
	button.content_margin_bottom = 10
	var hover := button.duplicate() as StyleBoxFlat
	hover.bg_color = Color("60466f")
	theme.set_stylebox("normal", "Button", button)
	theme.set_stylebox("hover", "Button", hover)
	theme.set_stylebox("pressed", "Button", hover)
	theme.set_color("font_color", "Button", Color.WHITE)
	theme.set_color("font_hover_color", "Button", Color("ffd23f"))
	return theme

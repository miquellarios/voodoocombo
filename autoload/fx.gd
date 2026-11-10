extends Node

signal floating_text(text: String, position: Vector2, tint: Color)
signal shake(amount: float)

func pop(text: String, position: Vector2, tint: Color = Color.WHITE) -> void:
	floating_text.emit(text, position, tint)

func hit() -> void:
	if not Settings.reduce_motion:
		shake.emit(6.0)

class_name UIStyle
extends RefCounted

const INK := Color(0.035, 0.03, 0.03, 0.9)
const PAPER := Color(0.94, 0.91, 0.84)
const MUTED := Color(0.67, 0.64, 0.58)
const RED := Color(0.68, 0.08, 0.07)


static func panel(fill: Color = INK, radius: int = 10, border: Color = Color(1, 1, 1, 0.08)) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(1)
	box.set_corner_radius_all(radius)
	box.content_margin_left = 22.0
	box.content_margin_right = 22.0
	box.content_margin_top = 18.0
	box.content_margin_bottom = 18.0
	return box


static func apply_button(button: Button, accent: bool = false) -> void:
	button.custom_minimum_size = Vector2(270, 48)
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_font_size_override("font_size", 16)
	button.add_theme_color_override("font_color", PAPER)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	var base := RED if accent else Color(0.08, 0.075, 0.07, 0.78)
	button.add_theme_stylebox_override("normal", panel(base, 6, Color(1, 1, 1, 0.1)))
	button.add_theme_stylebox_override("hover", panel(base.lightened(0.1), 6, Color(1, 1, 1, 0.22)))
	button.add_theme_stylebox_override("pressed", panel(base.darkened(0.08), 6, Color(1, 1, 1, 0.28)))
	button.add_theme_stylebox_override("focus", panel(Color(base, 0.95), 6, Color(PAPER, 0.7)))
	button.add_theme_stylebox_override("disabled", panel(Color(0.06, 0.055, 0.05, 0.5), 6, Color(1, 1, 1, 0.04)))
	button.pivot_offset = button.size * 0.5
	button.mouse_entered.connect(func() -> void: _animate_button(button, 1.018))
	button.mouse_exited.connect(func() -> void: _animate_button(button, 1.0))
	button.button_down.connect(func() -> void: _animate_button(button, 0.985))
	button.button_up.connect(func() -> void: _animate_button(button, 1.018))


static func _animate_button(button: Button, target: float) -> void:
	var tween := button.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(button, "scale", Vector2(target, target), 0.14)


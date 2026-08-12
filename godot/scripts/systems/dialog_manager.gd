class_name DialogManager
extends CanvasLayer

signal dialogue_finished

var _panel: PanelContainer
var _speaker: Label
var _line: Label
var _hint: Label
var _lines: Array[Dictionary] = []
var _index: int = 0
var _visible_chars: float = 0.0
var _typing: bool = false


func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()


func _build() -> void:
	var safe := MarginContainer.new()
	safe.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	safe.add_theme_constant_override("margin_left", 80)
	safe.add_theme_constant_override("margin_right", 80)
	safe.add_theme_constant_override("margin_bottom", 56)
	safe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(safe)
	var bottom := VBoxContainer.new()
	bottom.size_flags_vertical = Control.SIZE_EXPAND_FILL
	safe.add_child(bottom)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_child(spacer)
	_panel = PanelContainer.new()
	_panel.name = "DialoguePanel"
	_panel.custom_minimum_size = Vector2(0, 150)
	_panel.add_theme_stylebox_override("panel", UIStyle.panel(Color(0.025, 0.022, 0.02, 0.9), 8, Color(1, 1, 1, 0.12)))
	_panel.visible = false
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	bottom.add_child(_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	_panel.add_child(box)
	_speaker = Label.new()
	_speaker.add_theme_font_size_override("font_size", 14)
	_speaker.add_theme_color_override("font_color", Color(0.83, 0.23, 0.18))
	box.add_child(_speaker)
	_line = Label.new()
	_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_line.add_theme_font_size_override("font_size", 20)
	_line.add_theme_color_override("font_color", UIStyle.PAPER)
	_line.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(_line)
	_hint = Label.new()
	_hint.text = "ЛКМ / Enter — дальше"
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hint.add_theme_font_size_override("font_size", 11)
	_hint.add_theme_color_override("font_color", UIStyle.MUTED)
	box.add_child(_hint)


func show_dialogue(lines: Array[Dictionary]) -> void:
	if lines.is_empty():
		return
	_lines = lines.duplicate(true)
	_index = 0
	_panel.visible = true
	_show_current()
	_panel.modulate.a = 0.0
	_panel.position.y = 18.0
	var tween := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_parallel(true)
	tween.tween_property(_panel, "modulate:a", 1.0, 0.25)
	tween.tween_property(_panel, "position:y", 0.0, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func is_open() -> bool:
	return _panel != null and _panel.visible


func advance() -> void:
	if not is_open():
		return
	if _typing:
		_typing = false
		_line.visible_characters = -1
		return
	_index += 1
	if _index >= _lines.size():
		_close()
	else:
		_show_current()


func _show_current() -> void:
	var item: Dictionary = _lines[_index]
	_speaker.text = String(item.get("speaker", "РАДИО"))
	_line.text = String(item.get("text", ""))
	_line.visible_characters = 0
	_visible_chars = 0.0
	_typing = true


func _close() -> void:
	_typing = false
	var tween := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(_panel, "modulate:a", 0.0, 0.2)
	tween.finished.connect(func() -> void:
		_panel.visible = false
		dialogue_finished.emit()
	)


func _process(delta: float) -> void:
	if _typing:
		_visible_chars += delta * 38.0
		_line.visible_characters = mini(_line.text.length(), int(_visible_chars))
		if _line.visible_characters >= _line.text.length():
			_typing = false


func _unhandled_input(event: InputEvent) -> void:
	if not is_open() or not event.is_pressed():
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		advance()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and (event.keycode == KEY_ENTER or event.keycode == KEY_SPACE or event.keycode == KEY_E):
		advance()
		get_viewport().set_input_as_handled()

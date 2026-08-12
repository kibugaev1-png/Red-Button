class_name MainMenu
extends CanvasLayer

signal start_requested
signal continue_requested
signal resume_requested
signal save_requested
signal menu_requested
signal volume_changed(bus_name: String, value: float)

var _root: Control
var _photo: TextureRect
var _shade: ColorRect
var _title: Label
var _subtitle: Label
var _button_box: VBoxContainer
var _settings_box: VBoxContainer
var _continue_button: Button
var _mode: String = "start"


func _ready() -> void:
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()


func _build() -> void:
	_root = Control.new()
	_root.name = "MenuRoot"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	_photo = TextureRect.new()
	_photo.name = "ForestPhoto"
	_photo.texture = load("res://backgrounds/forest.jpg")
	_photo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_photo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_photo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_photo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_photo)

	_shade = ColorRect.new()
	_shade.name = "CinematicShade"
	_shade.color = Color(0.025, 0.02, 0.018, 0.56)
	_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_shade)

	var safe := MarginContainer.new()
	safe.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	safe.add_theme_constant_override("margin_left", 72)
	safe.add_theme_constant_override("margin_right", 72)
	safe.add_theme_constant_override("margin_top", 58)
	safe.add_theme_constant_override("margin_bottom", 54)
	_root.add_child(safe)
	var layout := VBoxContainer.new()
	layout.alignment = BoxContainer.ALIGNMENT_CENTER
	layout.add_theme_constant_override("separation", 9)
	safe.add_child(layout)

	var eyebrow := Label.new()
	eyebrow.text = "ПОСЛЕ ТИШИНЫ"
	eyebrow.add_theme_font_size_override("font_size", 13)
	eyebrow.add_theme_color_override("font_color", Color(0.82, 0.24, 0.2))
	layout.add_child(eyebrow)
	_title = Label.new()
	_title.text = "КРАСНАЯ\nКНОПКА"
	_title.add_theme_font_size_override("font_size", 58)
	_title.add_theme_color_override("font_color", UIStyle.PAPER)
	_title.add_theme_constant_override("line_spacing", -8)
	layout.add_child(_title)
	_subtitle = Label.new()
	_subtitle.text = "Мир пережил удар. Ты — пока тоже."
	_subtitle.add_theme_font_size_override("font_size", 17)
	_subtitle.add_theme_color_override("font_color", Color(0.84, 0.81, 0.74))
	layout.add_child(_subtitle)
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 22
	layout.add_child(spacer)
	_button_box = VBoxContainer.new()
	_button_box.add_theme_constant_override("separation", 10)
	_button_box.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	layout.add_child(_button_box)
	_settings_box = VBoxContainer.new()
	_settings_box.add_theme_constant_override("separation", 12)
	_settings_box.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_settings_box.visible = false
	layout.add_child(_settings_box)
	_build_settings()

	var footer := Label.new()
	footer.text = "GODOT 4.7  •  ФОТОГРАФИЧЕСКИЙ МИР"
	footer.add_theme_font_size_override("font_size", 11)
	footer.add_theme_color_override("font_color", Color(0.65, 0.62, 0.57))
	footer.size_flags_vertical = Control.SIZE_EXPAND | Control.SIZE_SHRINK_END
	layout.add_child(footer)


func show_start(can_continue: bool) -> void:
	_mode = "start"
	_root.visible = true
	_photo.visible = true
	_title.text = "КРАСНАЯ\nКНОПКА"
	_subtitle.text = "Мир пережил удар. Ты — пока тоже."
	_rebuild_buttons(can_continue)
	_fade_in()


func show_pause() -> void:
	_mode = "pause"
	_root.visible = true
	_photo.visible = false
	_shade.color = Color(0.015, 0.012, 0.012, 0.82)
	_title.text = "ПАУЗА"
	_subtitle.text = "Передохни. Пустошь подождёт."
	_rebuild_buttons(true)
	_fade_in()


func hide_menu() -> void:
	_root.visible = false


func is_open() -> bool:
	return _root != null and _root.visible


func _rebuild_buttons(can_continue: bool) -> void:
	_settings_box.visible = false
	_button_box.visible = true
	for child: Node in _button_box.get_children():
		child.queue_free()
	if _mode == "start":
		_add_button("НАЧАТЬ НОВУЮ ИГРУ", start_requested.emit, true)
		_continue_button = _add_button("ПРОДОЛЖИТЬ", continue_requested.emit)
		_continue_button.disabled = not can_continue
	else:
		_add_button("ПРОДОЛЖИТЬ", resume_requested.emit, true)
		_add_button("СОХРАНИТЬ", save_requested.emit)
	_add_button("НАСТРОЙКИ", _show_settings)
	if _mode == "pause":
		_add_button("В ГЛАВНОЕ МЕНЮ", menu_requested.emit)
	else:
		_add_button("ВЫХОД", get_tree().quit)
	await get_tree().process_frame
	var buttons := _button_box.get_children()
	if not buttons.is_empty():
		(buttons[0] as Button).grab_focus()


func _add_button(text: String, callback: Callable, accent: bool = false) -> Button:
	var button := Button.new()
	button.text = text
	UIStyle.apply_button(button, accent)
	button.pressed.connect(callback)
	_button_box.add_child(button)
	return button


func _build_settings() -> void:
	var heading := Label.new()
	heading.text = "ЗВУК"
	heading.add_theme_font_size_override("font_size", 24)
	heading.add_theme_color_override("font_color", UIStyle.PAPER)
	_settings_box.add_child(heading)
	for bus_name: String in ["Music", "Ambient", "SFX", "UI"]:
		var row := HBoxContainer.new()
		row.custom_minimum_size = Vector2(360, 42)
		var label := Label.new()
		label.text = {"Music": "Музыка", "Ambient": "Атмосфера", "SFX": "Эффекты", "UI": "Интерфейс"}[bus_name]
		label.custom_minimum_size.x = 120
		label.add_theme_color_override("font_color", UIStyle.PAPER)
		row.add_child(label)
		var slider := HSlider.new()
		slider.min_value = 0.0
		slider.max_value = 1.0
		slider.step = 0.05
		slider.value = 0.8
		slider.custom_minimum_size.x = 220
		slider.value_changed.connect(func(value: float) -> void: volume_changed.emit(bus_name, value))
		row.add_child(slider)
		_settings_box.add_child(row)
	var back := Button.new()
	back.text = "НАЗАД"
	UIStyle.apply_button(back)
	back.pressed.connect(func() -> void:
		_settings_box.visible = false
		_button_box.visible = true
	)
	_settings_box.add_child(back)


func _show_settings() -> void:
	_button_box.visible = false
	_settings_box.visible = true
	var controls := _settings_box.get_children()
	if controls.size() > 1:
		(controls[1].get_child(1) as HSlider).grab_focus()


func _fade_in() -> void:
	_root.modulate.a = 0.0
	var tween := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(_root, "modulate:a", 1.0, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	if _root != null and _root.visible and _photo.visible:
		_photo.scale = Vector2.ONE * (1.035 + sin(Time.get_ticks_msec() * 0.00012) * 0.008)
		_photo.position.x = sin(Time.get_ticks_msec() * 0.00008) * 8.0


func _unhandled_input(event: InputEvent) -> void:
	if not is_open() or _mode != "pause":
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		resume_requested.emit()
		get_viewport().set_input_as_handled()

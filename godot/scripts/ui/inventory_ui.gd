class_name InventoryUI
extends Control

signal slot_selected(index: int)

const SLOT_COUNT: int = 30
const HOTBAR_SIZE: int = 6
const COLUMN_COUNT: int = 6
const SLOT_MIN_SIZE := Vector2(128.0, 64.0)
const UI_STYLE_SCRIPT: Script = preload("res://scripts/ui/ui_style.gd")

var _inventory: RefCounted
var _catalog: RefCounted
var _is_open: bool = false
var _slot_buttons: Array[Button] = []
var _content: MarginContainer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	focus_mode = Control.FOCUS_NONE
	_build_interface()
	set_open(false)


func set_inventory(inventory: RefCounted) -> void:
	_inventory = inventory
	_refresh_slots()


func set_catalog(catalog: RefCounted) -> void:
	_catalog = catalog
	_refresh_slots()


func set_open(open: bool) -> void:
	_is_open = open
	visible = open
	mouse_filter = Control.MOUSE_FILTER_STOP if open else Control.MOUSE_FILTER_IGNORE
	if open:
		_refresh_slots()
		_focus_selected_slot()


func is_open() -> bool:
	return _is_open


func select_slot(index: int) -> bool:
	if index < 0 or index >= HOTBAR_SIZE or _inventory == null:
		return false
	if not bool(_inventory.call("select_hotbar", index)):
		return false
	_refresh_selection()
	slot_selected.emit(index)
	return true


func _build_interface() -> void:
	var shade := ColorRect.new()
	shade.name = "Backdrop"
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.012, 0.011, 0.012, 0.88)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)

	_content = MarginContainer.new()
	_content.name = "ResponsiveMargins"
	_content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_content.add_theme_constant_override("margin_left", 32)
	_content.add_theme_constant_override("margin_right", 32)
	_content.add_theme_constant_override("margin_top", 24)
	_content.add_theme_constant_override("margin_bottom", 24)
	add_child(_content)

	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content.add_child(center)

	var panel := PanelContainer.new()
	panel.name = "InventoryPanel"
	panel.custom_minimum_size = Vector2(880, 0)
	panel.custom_maximum_size = Vector2(1040, -1)
	panel.add_theme_stylebox_override("panel", UI_STYLE_SCRIPT.call("panel",
		Color(0.028, 0.025, 0.024, 0.97), 12, Color(1, 1, 1, 0.12)))
	center.add_child(panel)

	var body := VBoxContainer.new()
	body.name = "InventoryBody"
	body.add_theme_constant_override("separation", 12)
	panel.add_child(body)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 18)
	body.add_child(header)

	var title := Label.new()
	title.name = "TitleLabel"
	title.text = "ИНВЕНТАРЬ"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(0.94, 0.91, 0.84))
	header.add_child(title)

	var capacity_label := Label.new()
	capacity_label.text = "30 ЯЧЕЕК"
	capacity_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	capacity_label.add_theme_font_size_override("font_size", 11)
	capacity_label.add_theme_color_override("font_color", Color(0.67, 0.64, 0.58))
	header.add_child(capacity_label)

	body.add_child(_separator())
	body.add_child(_heading("HotbarHeading", "БЫСТРЫЙ ДОСТУП  ·  1–6"))
	var hotbar_grid := _make_grid("HotbarGrid")
	body.add_child(hotbar_grid)
	for index in HOTBAR_SIZE:
		hotbar_grid.add_child(_make_slot(index, true))

	body.add_child(_heading("BackpackHeading", "РЮКЗАК  ·  24 ЯЧЕЙКИ"))
	var inventory_grid := _make_grid("InventoryGrid")
	body.add_child(inventory_grid)
	for index in range(HOTBAR_SIZE, SLOT_COUNT):
		inventory_grid.add_child(_make_slot(index, false))

	body.add_child(_separator())
	var help := Label.new()
	help.name = "HelpLabel"
	help.text = "I / TAB — ЗАКРЫТЬ     1–6 — ВЫБРАТЬ БЫСТРЫЙ СЛОТ     E — ИСПОЛЬЗОВАТЬ / ВЗАИМОДЕЙСТВОВАТЬ"
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help.add_theme_font_size_override("font_size", 11)
	help.add_theme_color_override("font_color", Color(0.67, 0.64, 0.58))
	body.add_child(help)


func _make_grid(node_name: String) -> GridContainer:
	var grid := GridContainer.new()
	grid.name = node_name
	grid.columns = COLUMN_COUNT
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	return grid


func _make_slot(index: int, hotbar: bool) -> Button:
	var button := Button.new()
	button.name = ("HotbarSlot%d" if hotbar else "InventorySlot%d") % index
	button.custom_minimum_size = SLOT_MIN_SIZE
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.toggle_mode = hotbar
	button.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
	button.focus_mode = Control.FOCUS_ALL if hotbar else Control.FOCUS_NONE
	button.disabled = not hotbar
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if hotbar else Control.CURSOR_ARROW
	button.add_theme_font_size_override("font_size", 12)
	button.add_theme_color_override("font_color", Color(0.88, 0.85, 0.78))
	button.add_theme_color_override("font_disabled_color", Color(0.72, 0.69, 0.63))
	_apply_slot_style(button, hotbar)
	if hotbar:
		button.pressed.connect(_on_hotbar_pressed.bind(index))
	_slot_buttons.append(button)
	return button


func _apply_slot_style(button: Button, hotbar: bool) -> void:
	var normal_fill := Color(0.065, 0.06, 0.055, 0.92) if hotbar else Color(0.05, 0.047, 0.045, 0.8)
	button.add_theme_stylebox_override("normal", UI_STYLE_SCRIPT.call("panel", normal_fill, 6, Color(1, 1, 1, 0.08)))
	button.add_theme_stylebox_override("disabled", UI_STYLE_SCRIPT.call("panel", normal_fill, 6, Color(1, 1, 1, 0.06)))
	button.add_theme_stylebox_override("hover", UI_STYLE_SCRIPT.call("panel", normal_fill.lightened(0.08), 6, Color(0.94, 0.91, 0.84, 0.28)))
	button.add_theme_stylebox_override("pressed", UI_STYLE_SCRIPT.call("panel", Color(0.16, 0.055, 0.045, 0.95), 6, Color(0.85, 0.18, 0.14, 0.7)))
	button.add_theme_stylebox_override("focus", UI_STYLE_SCRIPT.call("panel", Color(0.1, 0.075, 0.06, 0.96), 6, Color(0.94, 0.91, 0.84, 0.65)))


func _heading(node_name: String, text: String) -> Label:
	var label := Label.new()
	label.name = node_name
	label.text = text
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", Color(0.67, 0.64, 0.58))
	return label


func _separator() -> HSeparator:
	var separator := HSeparator.new()
	separator.add_theme_color_override("separator", Color(1, 1, 1, 0.1))
	return separator


func _refresh_slots() -> void:
	if _slot_buttons.size() != SLOT_COUNT:
		return
	for index in SLOT_COUNT:
		var slot: Dictionary = _inventory.call("get_slot", index) if _inventory != null else {}
		_slot_buttons[index].text = _slot_text(index, slot)
	_refresh_selection()


func _slot_text(index: int, slot: Dictionary) -> String:
	var prefix := "%d\n" % (index + 1) if index < HOTBAR_SIZE else ""
	if slot.is_empty():
		return prefix + "—"
	var item_id := StringName(slot.get("id", ""))
	var item: Dictionary = _catalog.call("get_item", item_id) if _catalog != null else {}
	var display_name := String(item.get("name", item_id))
	return "%s%s\n×%d" % [prefix, display_name, int(slot.get("quantity", 0))]


func _refresh_selection() -> void:
	var selected := int(_inventory.call("selected_hotbar")) if _inventory != null else 0
	for index in HOTBAR_SIZE:
		_slot_buttons[index].set_pressed_no_signal(index == selected)


func _focus_selected_slot() -> void:
	if _inventory == null or _slot_buttons.is_empty():
		return
	var selected := clampi(int(_inventory.call("selected_hotbar")), 0, HOTBAR_SIZE - 1)
	_slot_buttons[selected].grab_focus()


func _on_hotbar_pressed(index: int) -> void:
	select_slot(index)

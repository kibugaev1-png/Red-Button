extends SceneTree

const UI_PATH := "res://scripts/ui/inventory_ui.gd"
const INVENTORY_PATH := "res://scripts/items/inventory.gd"
const CATALOG_PATH := "res://scripts/items/item_catalog.gd"

var failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var ui_script: Script = load(UI_PATH)
	_expect(ui_script != null, "inventory UI script loads")
	if ui_script == null:
		_finish()
		return
	_expect(ui_script.can_instantiate(), "inventory UI script can instantiate")
	if not ui_script.can_instantiate():
		_finish()
		return

	var inventory_script: Script = load(INVENTORY_PATH)
	var catalog_script: Script = load(CATALOG_PATH)
	var inventory: RefCounted = inventory_script.new()
	var catalog: RefCounted = catalog_script.new()
	inventory.call("add", &"axe", 1)
	inventory.call("add", &"ammo9", 25)

	var ui: Control = ui_script.new()
	root.add_child(ui)
	await process_frame
	ui.call("set_inventory", inventory)
	ui.call("set_catalog", catalog)

	_expect(ui.process_mode == Node.PROCESS_MODE_ALWAYS, "overlay continues processing while the game is paused")
	_expect(ui.anchor_left == 0.0 and ui.anchor_top == 0.0 and ui.anchor_right == 1.0 and ui.anchor_bottom == 1.0,
		"overlay uses full-rect anchors")
	_expect(ui.has_method("set_open") and ui.has_method("is_open"), "overlay exposes open and close API")

	ui.call("set_open", true)
	await process_frame
	_expect(ui.call("is_open"), "set_open(true) opens the inventory")
	_expect(ui.visible, "open inventory is visible")
	_expect(ui.mouse_filter == Control.MOUSE_FILTER_STOP, "open overlay catches pointer input")

	var slot_buttons: Array[Node] = ui.find_children("*Slot*", "Button", true, false)
	_expect(slot_buttons.size() == 30, "overlay builds exactly 30 inventory slots")
	var hotbar_heading := ui.find_child("HotbarHeading", true, false) as Label
	var backpack_heading := ui.find_child("BackpackHeading", true, false) as Label
	_expect(hotbar_heading != null and "БЫСТРЫЙ ДОСТУП" in hotbar_heading.text,
		"the first six slots are explicitly labelled as quick access")
	_expect(backpack_heading != null and "24" in backpack_heading.text,
		"the remaining 24 slots are explicitly labelled as the backpack")

	var first_slot := ui.find_child("HotbarSlot0", true, false) as Button
	var first_backpack_slot := ui.find_child("InventorySlot6", true, false) as Button
	_expect(first_slot != null and "Металлический топор" in first_slot.text and "×1" in first_slot.text,
		"slot text uses the Russian catalog name and quantity")
	_expect(first_slot != null and first_slot.button_pressed, "the selected hotbar slot is visibly selected")
	_expect(first_backpack_slot != null and first_backpack_slot.disabled,
		"backpack slots are display-only while hotbar slots are clickable")

	var selected_events: Array[int] = []
	ui.connect("slot_selected", func(index: int) -> void: selected_events.append(index))
	_expect(ui.call("select_slot", 2), "a hotbar slot can be selected through the controller API")
	_expect(selected_events == [2], "selecting a slot emits slot_selected")
	_expect(inventory.call("selected_hotbar") == 2, "UI selection updates the inventory model")
	_expect(not ui.call("select_slot", 6), "slots outside quick access cannot be selected")
	_expect(selected_events == [2], "rejected selection emits no signal")

	var help := ui.find_child("HelpLabel", true, false) as Label
	_expect(help != null and "I / TAB" in help.text and "E" in help.text and "1–6" in help.text,
		"footer explains I/Tab, E and hotbar controls")

	ui.call("set_open", false)
	_expect(not ui.call("is_open"), "set_open(false) closes the inventory")
	_expect(not ui.visible, "closed inventory is hidden")
	_expect(ui.mouse_filter == Control.MOUSE_FILTER_IGNORE, "closed overlay does not block gameplay input")

	ui.queue_free()
	await process_frame
	_finish()


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("[PASS] ", message)
	else:
		failures += 1
		printerr("[FAIL] ", message)


func _finish() -> void:
	print("[tests] failures: ", failures)
	quit(failures)

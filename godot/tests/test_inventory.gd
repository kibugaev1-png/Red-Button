extends SceneTree

const CATALOG_PATH := "res://scripts/items/item_catalog.gd"
const INVENTORY_PATH := "res://scripts/items/inventory.gd"

var failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var catalog_script: Script = load(CATALOG_PATH)
	var inventory_script: Script = load(INVENTORY_PATH)
	_expect(catalog_script != null, "item catalog script loads")
	_expect(inventory_script != null, "inventory script loads")
	if catalog_script == null or inventory_script == null:
		_finish()
		return
	_expect(catalog_script.can_instantiate(), "item catalog script can instantiate")
	_expect(inventory_script.can_instantiate(), "inventory script can instantiate")
	if not catalog_script.can_instantiate() or not inventory_script.can_instantiate():
		_finish()
		return

	_test_catalog(catalog_script)
	_test_capacity_and_stacking(inventory_script)
	_test_removal(inventory_script)
	_test_hotbar_selection(inventory_script)
	_test_serialization(inventory_script)
	_finish()


func _test_catalog(catalog_script: Script) -> void:
	var catalog: RefCounted = catalog_script.new()
	var required_ids: Array[StringName] = [
		&"gasmask", &"filter", &"axe", &"pick", &"bandage", &"pistol",
		&"ammo9", &"canteen", &"can", &"dirt", &"clay", &"stone", &"coal",
		&"iron_ore", &"copper_ore", &"wood", &"stick", &"concrete", &"plank",
		&"scrap", &"ladder",
	]
	for item_id: StringName in required_ids:
		_expect(catalog.call("has_item", item_id), "catalog contains %s" % item_id)
		var item: Dictionary = catalog.call("get_item", item_id)
		_expect(not String(item.get("name", "")).is_empty(), "%s has a Russian display name" % item_id)
		_expect(int(item.get("max_stack", 0)) > 0, "%s has a positive stack limit" % item_id)


func _test_capacity_and_stacking(inventory_script: Script) -> void:
	var inventory: RefCounted = inventory_script.new()
	_expect(inventory.call("capacity") == 30, "inventory has 30 slots")
	_expect(inventory.call("hotbar_size") == 6, "the first six slots form the hotbar")
	_expect(inventory.call("add", &"ammo9", 250) == 0, "valid items are added without loss when space exists")
	_expect(inventory.call("count", &"ammo9") == 250, "count totals multiple stacks")
	var first: Dictionary = inventory.call("get_slot", 0)
	var second: Dictionary = inventory.call("get_slot", 1)
	_expect(first == {"id": "ammo9", "quantity": 240}, "the first stack stops at the catalog limit")
	_expect(second == {"id": "ammo9", "quantity": 10}, "overflow continues in the next slot")
	_expect(inventory.call("add", &"unknown_item", 3) == 3, "unknown items are rejected")


func _test_removal(inventory_script: Script) -> void:
	var inventory: RefCounted = inventory_script.new()
	inventory.call("add", &"bandage", 23)
	_expect(inventory.call("remove", &"bandage", 21), "remove reports success when the full amount existed")
	_expect(inventory.call("count", &"bandage") == 2, "remove consumes across stacks")
	_expect(not inventory.call("remove", &"bandage", 3), "remove reports a shortfall")
	_expect(inventory.call("count", &"bandage") == 0, "a short removal still removes what was available")


func _test_hotbar_selection(inventory_script: Script) -> void:
	var inventory: RefCounted = inventory_script.new()
	inventory.call("add", &"axe", 1)
	_expect(inventory.call("select_hotbar", 0), "hotbar slot zero can be selected")
	_expect(inventory.call("selected_hotbar") == 0, "selected hotbar index is exposed")
	_expect(inventory.call("get_selected") == {"id": "axe", "quantity": 1}, "selected item comes from the hotbar")
	_expect(inventory.call("select_hotbar", 5), "last hotbar slot can be selected")
	_expect(not inventory.call("select_hotbar", 6), "selection outside slots 0 through 5 is rejected")
	_expect(inventory.call("selected_hotbar") == 5, "invalid selection preserves the previous slot")


func _test_serialization(inventory_script: Script) -> void:
	var source: RefCounted = inventory_script.new()
	source.call("add", &"axe", 1)
	source.call("add", &"ammo9", 250)
	source.call("select_hotbar", 2)
	var state: Dictionary = source.call("serialize_state")
	_expect(state.get("version", 0) == 1, "serialized inventory is versioned")
	_expect(state.get("slots", []).size() == 30, "serialization preserves all slot positions")

	var restored: RefCounted = inventory_script.new()
	_expect(restored.call("restore_state", state), "a valid inventory state restores")
	_expect(restored.call("serialize_state") == state, "inventory state round-trips exactly")
	_expect(restored.call("count", &"ammo9") == 250, "restored stacks remain countable")
	_expect(restored.call("selected_hotbar") == 2, "selected hotbar slot restores")

	var before_invalid: Dictionary = restored.call("serialize_state")
	_expect(not restored.call("restore_state", {"version": 99, "slots": []}), "unknown save versions are rejected")
	_expect(restored.call("serialize_state") == before_invalid, "rejected state does not mutate the inventory")


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("[PASS] ", message)
	else:
		failures += 1
		printerr("[FAIL] ", message)


func _finish() -> void:
	print("[tests] failures: ", failures)
	quit(failures)

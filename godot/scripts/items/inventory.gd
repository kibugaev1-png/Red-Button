class_name PlayerInventory
extends RefCounted

const SLOT_COUNT: int = 30
const HOTBAR_SLOT_COUNT: int = 6
const SAVE_VERSION: int = 1
const ITEM_CATALOG_SCRIPT: Script = preload("res://scripts/items/item_catalog.gd")

var _catalog: RefCounted = ITEM_CATALOG_SCRIPT.new()
var _slots: Array[Dictionary] = []
var _selected_hotbar: int = 0


func _init() -> void:
	_slots.resize(SLOT_COUNT)
	for index in SLOT_COUNT:
		_slots[index] = {}


func capacity() -> int:
	return SLOT_COUNT


func hotbar_size() -> int:
	return HOTBAR_SLOT_COUNT


func get_slot(index: int) -> Dictionary:
	if index < 0 or index >= SLOT_COUNT:
		return {}
	return _slots[index].duplicate(true)


func add(item_id: StringName, quantity: int = 1) -> int:
	if quantity <= 0:
		return 0
	var limit: int = int(_catalog.call("max_stack", item_id))
	if limit <= 0:
		return quantity
	var remaining := quantity
	for slot: Dictionary in _slots:
		if remaining <= 0:
			break
		if StringName(slot.get("id", "")) != item_id:
			continue
		var current := int(slot.get("quantity", 0))
		var added: int = mini(limit - current, remaining)
		if added > 0:
			slot["quantity"] = current + added
			remaining -= added
	for slot: Dictionary in _slots:
		if remaining <= 0:
			break
		if not slot.is_empty():
			continue
		var added: int = mini(limit, remaining)
		slot["id"] = String(item_id)
		slot["quantity"] = added
		remaining -= added
	return remaining


func count(item_id: StringName) -> int:
	var total := 0
	for slot: Dictionary in _slots:
		if StringName(slot.get("id", "")) == item_id:
			total += int(slot.get("quantity", 0))
	return total


func remove(item_id: StringName, quantity: int = 1) -> bool:
	if quantity <= 0:
		return true
	var remaining := quantity
	for index in range(SLOT_COUNT - 1, -1, -1):
		if remaining <= 0:
			break
		var slot: Dictionary = _slots[index]
		if StringName(slot.get("id", "")) != item_id:
			continue
		var current := int(slot.get("quantity", 0))
		var removed: int = mini(current, remaining)
		current -= removed
		remaining -= removed
		if current <= 0:
			_slots[index] = {}
		else:
			slot["quantity"] = current
	return remaining == 0


func select_hotbar(index: int) -> bool:
	if index < 0 or index >= HOTBAR_SLOT_COUNT:
		return false
	_selected_hotbar = index
	return true


func selected_hotbar() -> int:
	return _selected_hotbar


func get_selected() -> Dictionary:
	return get_slot(_selected_hotbar)


func serialize_state() -> Dictionary:
	var serialized_slots: Array[Dictionary] = []
	for slot: Dictionary in _slots:
		serialized_slots.append(slot.duplicate(true))
	return {
		"version": SAVE_VERSION,
		"selected_hotbar": _selected_hotbar,
		"slots": serialized_slots,
	}


func restore_state(state: Dictionary) -> bool:
	if int(state.get("version", 0)) != SAVE_VERSION:
		return false
	var raw_slots: Variant = state.get("slots", null)
	if not raw_slots is Array or raw_slots.size() != SLOT_COUNT:
		return false
	var selected := int(state.get("selected_hotbar", 0))
	if selected < 0 or selected >= HOTBAR_SLOT_COUNT:
		return false
	var restored: Array[Dictionary] = []
	restored.resize(SLOT_COUNT)
	for index in SLOT_COUNT:
		var raw_slot: Variant = raw_slots[index]
		if not raw_slot is Dictionary:
			return false
		if raw_slot.is_empty():
			restored[index] = {}
			continue
		var item_id := StringName(raw_slot.get("id", ""))
		var quantity := int(raw_slot.get("quantity", 0))
		var limit: int = int(_catalog.call("max_stack", item_id))
		if limit <= 0 or quantity <= 0 or quantity > limit:
			return false
		restored[index] = {"id": String(item_id), "quantity": quantity}
	_slots = restored
	_selected_hotbar = selected
	return true

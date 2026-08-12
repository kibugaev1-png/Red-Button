extends SceneTree

const COORDINATOR_PATH := "res://scripts/interactions/interaction_coordinator.gd"
const WORLD_ITEM_PATH := "res://scripts/interactions/world_item.gd"
const LOOT_CRATE_PATH := "res://scripts/interactions/loot_crate.gd"

var failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if not ResourceLoader.exists(COORDINATOR_PATH):
		_fail("InteractionCoordinator script exists")
		_finish()
		return
	_test_adapter_selection()
	if not ResourceLoader.exists(WORLD_ITEM_PATH):
		_fail("WorldItem script exists")
		_finish()
		return
	if not ResourceLoader.exists(LOOT_CRATE_PATH):
		_fail("LootCrate script exists")
		_finish()
		return
	_test_world_item_and_loot_crate()
	_finish()


func _test_adapter_selection() -> void:

	var coordinator_script := load(COORDINATOR_PATH) as Script
	var coordinator := coordinator_script.new() as Node
	root.add_child(coordinator)

	var actor := Node2D.new()
	actor.position = Vector2.ZERO
	root.add_child(actor)
	coordinator.call("set_actor", actor)

	var low_priority := Node2D.new()
	low_priority.name = "LowPriority"
	low_priority.position = Vector2(-20.0, 0.0)
	root.add_child(low_priority)
	var high_priority := Node2D.new()
	high_priority.name = "HighPriority"
	high_priority.position = Vector2(20.0, 0.0)
	root.add_child(high_priority)

	var interactions: Array[String] = []
	coordinator.call("register_adapter", low_priority, "E  LOW", 1, 100.0, Callable(),
		func(_actor: Node2D) -> void: interactions.append("low"))
	coordinator.call("register_adapter", high_priority, "E  HIGH", 5, 100.0, Callable(),
		func(_actor: Node2D) -> void: interactions.append("high"))

	_expect(coordinator.call("update_target") == high_priority,
		"higher priority wins when candidates are equally near")
	_expect(coordinator.call("get_current_prompt") == "E  HIGH",
		"selected adapter exposes its prompt")

	high_priority.position = Vector2(150.0, 0.0)
	_expect(coordinator.call("update_target") == low_priority,
		"an out-of-range candidate is skipped")
	_expect(bool(coordinator.call("interact_current")),
		"current adapter can be interacted with")
	_expect(interactions == ["low"],
		"interaction is routed to the selected adapter exactly once")

	coordinator.call("unregister_interactable", low_priority)
	_expect(coordinator.call("update_target") == null,
		"unregistered and out-of-range candidates leave no target")
	coordinator.free()
	actor.free()
	low_priority.free()
	high_priority.free()


func _test_world_item_and_loot_crate() -> void:
	var actor := Node2D.new()
	actor.position = Vector2.ZERO
	root.add_child(actor)

	var item_script := load(WORLD_ITEM_PATH) as Script
	var item := item_script.new() as Node2D
	item.set("stable_id", "starter.gasmask")
	item.set("item_id", "gasmask")
	item.set("display_name", "Противогаз ГП-1")
	item.set("count", 1)
	item.position = Vector2(-24.0, 0.0)
	root.add_child(item)

	var pickup_payloads: Array[Dictionary] = []
	item.connect("pickup_requested", func(source: Node) -> void:
		pickup_payloads.append({
			"stable_id": source.get("stable_id"),
			"item_id": source.get("item_id"),
			"count": source.get("count"),
		})
		source.call("collect", int(source.get("count")))
	)
	_expect(String(item.call("get_interaction_prompt", actor)).contains("Противогаз ГП-1"),
		"world item prompt names the item")
	_expect(bool(item.call("interact", actor)), "world item accepts one pickup interaction")
	_expect(pickup_payloads == [{"stable_id": "starter.gasmask", "item_id": "gasmask", "count": 1}],
		"world item emits its stable pickup payload")
	_expect(not bool(item.call("is_interaction_available", actor)),
		"fully collected world item is no longer available")

	var saved_item: Dictionary = item.call("serialize_state")
	var restored_item := item_script.new() as Node2D
	restored_item.set("stable_id", "starter.gasmask")
	restored_item.set("item_id", "gasmask")
	restored_item.set("count", 99)
	root.add_child(restored_item)
	_expect(bool(restored_item.call("restore_state", saved_item)),
		"world item restores state with the same stable id")
	_expect(int(restored_item.get("count")) == 0 and bool(restored_item.get("collected")),
		"world item restores collected state")

	var crate_script := load(LOOT_CRATE_PATH) as Script
	var crate := crate_script.new() as Node2D
	crate.set("stable_id", "starter.tools")
	crate.set("display_name", "ящик с инструментами")
	var fixed_loot: Array[Dictionary] = [
		{"item_id": "axe", "count": 1},
		{"item_id": "pick", "count": 1},
		{"item_id": "bandage", "count": 3},
	]
	crate.set("loot", fixed_loot)
	crate.position = Vector2(24.0, 0.0)
	root.add_child(crate)

	var loot_payloads: Array[Array] = []
	crate.connect("loot_requested", func(source: Node, requested_loot: Array[Dictionary]) -> void:
		loot_payloads.append([source.get("stable_id"), requested_loot])
		requested_loot[0]["count"] = 999
	)
	_expect(bool(crate.call("interact", actor)), "closed loot crate opens")
	_expect(not bool(crate.call("interact", actor)), "opened loot crate cannot open twice")
	_expect(loot_payloads.size() == 1, "loot crate requests loot exactly once")
	_expect(int((crate.get("loot") as Array)[0].get("count")) == 1,
		"loot request receives a copy and cannot mutate fixed crate loot")

	var saved_crate: Dictionary = crate.call("serialize_state")
	var restored_crate := crate_script.new() as Node2D
	restored_crate.set("stable_id", "starter.tools")
	root.add_child(restored_crate)
	_expect(bool(restored_crate.call("restore_state", saved_crate)),
		"loot crate restores state with the same stable id")
	_expect(bool(restored_crate.get("opened")), "loot crate restores opened state")
	_expect(not bool(restored_crate.call("is_interaction_available", actor)),
		"restored opened crate is unavailable")

	item.free()
	restored_item.free()
	crate.free()
	restored_crate.free()
	actor.free()


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("[PASS] ", message)
	else:
		_fail(message)


func _fail(message: String) -> void:
	failures += 1
	printerr("[FAIL] ", message)


func _finish() -> void:
	print("[tests] failures: ", failures)
	quit(failures)

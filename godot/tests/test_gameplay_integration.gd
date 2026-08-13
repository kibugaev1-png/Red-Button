extends SceneTree

const GAME_PATH := "res://scripts/game.gd"
var failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game_script := load(GAME_PATH) as Script
	var game := game_script.new() as Node2D
	root.add_child(game)
	await process_frame
	game.call("_begin_game", false, false)
	await process_frame

	# Ожидаемое число берём из самой спецификации, а не держим числом в тесте:
	# иначе каждый добавленный в мир ящик ломает тест, который стережёт совсем
	# другое — что сущности создаются ровно по описанию и не двоятся.
	var spec: Dictionary = game.call("get_start_gameplay_spec")
	var expected: int = (spec.get("crates", []) as Array).size() \
		+ (spec.get("world_items", []) as Array).size()
	_expect(game.get("gameplay_entities").get_child_count() == expected,
		"new game instantiates every crate and world item from the spec (%d)" % expected)
	_expect(game.get("enemies").get_child_count() == 1,
		"new game instantiates one starter enemy")
	game.call("reset_gameplay_state")
	_expect(game.get("gameplay_entities").get_child_count() == expected,
		"repeated reset does not duplicate starter entities")
	_expect(game.get("enemies").get_child_count() == 1,
		"repeated reset does not duplicate starter enemy")

	var inventory: RefCounted = game.get("inventory")
	# Полный рюкзак не уничтожает содержимое ящика: остаток появляется рядом.
	inventory.call("add", &"axe", 30)
	var survival_crate: LootCrate
	for child: Node in game.get("gameplay_entities").get_children():
		if child is LootCrate and (child as LootCrate).stable_id == "starter.survival":
			survival_crate = child
	if survival_crate:
		survival_crate.interact(game.get("player"))
	_expect(game.get("gameplay_entities").get_child_count() > 3,
		"loot spills into registered world items when inventory is full")
	game.call("reset_gameplay_state")
	inventory = game.get("inventory")

	# Координатор реально выбирает и подбирает противогаз, а предмет исчезает.
	var gasmask: WorldItem
	for child: Node in game.get("gameplay_entities").get_children():
		if child is WorldItem and (child as WorldItem).item_id == "gasmask":
			gasmask = child
	if gasmask:
		game.get("player").position = gasmask.position
		game.get("interaction_coordinator").call("update_target")
		game.get("interaction_coordinator").call("interact_current")
	_expect(bool(game.get("player").mask), "gas mask pickup equips the player")
	_expect(gasmask != null and gasmask.collected, "picked gas mask is no longer available")

	# Открываем оба ящика через их публичный контракт.
	for child: Node in game.get("gameplay_entities").get_children():
		if child is LootCrate:
			child.call("interact", game.get("player"))
	_expect(inventory.call("count", &"axe") == 1 and inventory.call("count", &"pick") == 1,
		"tool crate feeds the inventory")
	_expect(inventory.call("count", &"pistol") == 1 and inventory.call("count", &"ammo9") == 10,
		"survival crate feeds weapon and ammunition")

	var state: Dictionary = game.call("capture_gameplay_state")
	inventory.call("clear")
	game.call("apply_gameplay_state", state)
	_expect(inventory.call("count", &"pistol") == 1 and inventory.call("count", &"ammo9") == 10,
		"inventory survives gameplay state round-trip")
	var reopened := false
	for child: Node in game.get("gameplay_entities").get_children():
		if child is LootCrate:
			reopened = reopened or bool(child.call("interact", game.get("player")))
	_expect(not reopened, "opened crates remain one-shot after state restore")

	var before_count: int = (game.get("gameplay_entities") as Node).get_child_count()
	game.call("apply_gameplay_state", state)
	_expect(game.get("gameplay_entities").get_child_count() == before_count,
		"applying the same state is idempotent")

	game.queue_free()
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

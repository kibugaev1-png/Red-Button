extends SceneTree

var failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game_script := load("res://scripts/game.gd") as Script
	_expect(game_script != null and game_script.can_instantiate(), "game script loads")
	if game_script == null or not game_script.can_instantiate():
		_finish()
		return
	var game := game_script.new() as Node2D
	for method: String in [
		"get_start_gameplay_spec", "reset_gameplay_state", "capture_gameplay_state",
		"apply_gameplay_state", "use_selected_item", "reload_selected_weapon",
	]:
		_expect(game.has_method(method), "game exposes %s" % method)
	if game.has_method("get_start_gameplay_spec"):
		var spec: Dictionary = game.call("get_start_gameplay_spec")
		var crates: Array = spec.get("crates", [])
		var items: Array = spec.get("world_items", [])
		_expect(crates.size() == 2, "new game has exactly two starter crates")
		_expect(items.size() == 1 and items[0].get("item_id") == "gasmask",
			"new game places one gas mask next to spawn")
		if crates.size() == 2:
			_expect(crates[0].get("loot") == [
				{"item_id": "axe", "count": 1},
				{"item_id": "pick", "count": 1},
				{"item_id": "bandage", "count": 3},
			], "left crate matches the original tool loot")
			_expect(crates[1].get("loot") == [
				{"item_id": "pistol", "count": 1},
				{"item_id": "ammo9", "count": 10},
				{"item_id": "filter", "count": 2},
				{"item_id": "canteen", "count": 1},
				{"item_id": "can", "count": 1},
			], "right crate matches the original survival loot")
	game.free()
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

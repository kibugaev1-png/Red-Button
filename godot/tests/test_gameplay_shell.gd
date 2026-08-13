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
		# Проверяем ящики по опознавателю, а не по количеству: каждый новый ящик
		# в мире не должен ронять тест, который на самом деле стережёт другое —
		# что стартовый набор на месте и лут в нём тот, что задуман.
		var by_id: Dictionary = {}
		for crate: Dictionary in crates:
			by_id[String(crate.get("stable_id", ""))] = crate
		_expect(by_id.has("starter.tools"), "the starter tool crate exists")
		_expect(by_id.has("starter.survival"), "the starter survival crate exists")
		_expect(items.size() == 1 and items[0].get("item_id") == "gasmask",
			"new game places one gas mask next to spawn")
		_expect(by_id.get("starter.tools", {}).get("loot") == [
			{"item_id": "axe", "count": 1},
			{"item_id": "pick", "count": 1},
			{"item_id": "bandage", "count": 3},
		], "the tool crate matches the original tool loot")
		_expect(by_id.get("starter.survival", {}).get("loot") == [
			{"item_id": "pistol", "count": 1},
			{"item_id": "ammo9", "count": 10},
			{"item_id": "filter", "count": 2},
			{"item_id": "canteen", "count": 1},
			{"item_id": "can", "count": 1},
		], "the survival crate matches the original survival loot")

		# Ручной бур лежит в руинах небоскрёбов и нигде больше: найденный у
		# старта, он обесценил бы кирку и всю раннюю игру.
		var armory: Dictionary = by_id.get("towers.armory", {})
		_expect(not armory.is_empty(), "the skyscraper armoury crate exists")
		_expect(int(armory.get("offset_cells", 0)) > 3000,
			"the armoury sits far east of the spawn")
		var drill_here := false
		for entry: Dictionary in armory.get("loot", []):
			if String(entry.get("item_id", "")) == "handheld_drill":
				drill_here = true
		_expect(drill_here, "the armoury holds the handheld drill")
		for crate_id: Variant in by_id:
			if String(crate_id) == "towers.armory":
				continue
			for entry: Dictionary in (by_id[crate_id] as Dictionary).get("loot", []):
				_expect(String(entry.get("item_id", "")) != "handheld_drill",
					"crate %s does not hand out the drill early" % String(crate_id))
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

# Стережёт дерево крафта. Две вещи, которые ломают игру молча и обнаруживаются
# только за игрой: рецепт ссылается на предмет, которого нет в каталоге, и
# замкнутый круг, когда для А нужно Б, а для Б нужно А.
extends SceneTree

const CATALOG_PATH := "res://scripts/items/item_catalog.gd"
const RECIPES_PATH := "res://scripts/items/recipes.gd"

var failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var catalog_script: Script = load(CATALOG_PATH)
	var recipes_script: Script = load(RECIPES_PATH)
	_expect(catalog_script != null, "item catalog script loads")
	_expect(recipes_script != null, "recipes script loads")
	if catalog_script == null or recipes_script == null:
		_finish()
		return

	var catalog: RefCounted = catalog_script.new()
	_test_items_exist(catalog, recipes_script)
	_test_no_cycles(recipes_script)
	_test_hand_lookup(recipes_script)
	_test_machine_matching(recipes_script)
	_test_fuel(recipes_script)
	_finish()


# Каждый item_id — и на выходе, и во входах — обязан существовать в каталоге.
func _test_items_exist(catalog: RefCounted, recipes: Script) -> void:
	var missing: Array[String] = []
	for recipe: Dictionary in recipes.call("all"):
		var produced := StringName(recipe.get("id", ""))
		if not bool(catalog.call("has_item", produced)):
			missing.append("выход %s" % String(produced))
		for item_id: Variant in recipe.get("inputs", {}):
			if not bool(catalog.call("has_item", StringName(item_id))):
				missing.append("вход %s в рецепте %s" % [String(item_id), String(produced)])
	_expect(missing.is_empty(), "every recipe item exists in the catalog (%s)" % ", ".join(missing))


# Обход в глубину по дереву крафта. Если предмет встречается сам в себе через
# цепочку входов — игра встанет намертво, и лучше узнать это здесь.
func _test_no_cycles(recipes: Script) -> void:
	var produced_by: Dictionary = {}
	for recipe: Dictionary in recipes.call("all"):
		var id := StringName(recipe.get("id", ""))
		if not produced_by.has(id):
			produced_by[id] = []
		for item_id: Variant in recipe.get("inputs", {}):
			(produced_by[id] as Array).append(StringName(item_id))

	var cycles: Array[String] = []
	for start: Variant in produced_by:
		var seen: Dictionary = {}
		if _reaches(produced_by, StringName(start), StringName(start), seen, true):
			cycles.append(String(start))
	_expect(cycles.is_empty(), "the crafting tree has no cycles (%s)" % ", ".join(cycles))


func _reaches(graph: Dictionary, from: StringName, target: StringName, seen: Dictionary, first: bool) -> bool:
	if not first and from == target:
		return true
	if seen.has(from):
		return false
	seen[from] = true
	for next: Variant in graph.get(from, []):
		if _reaches(graph, StringName(next), target, seen, false):
			return true
	return false


func _test_hand_lookup(recipes: Script) -> void:
	var bow: Dictionary = recipes.call("hand_recipe", &"bow")
	_expect(not bow.is_empty(), "the bow has a hand recipe")
	_expect(int(bow.get("inputs", {}).get(&"rag", 0)) == 2, "the bow costs two rags")
	_expect(int(bow.get("inputs", {}).get(&"plank", 0)) == 6, "the bow costs six planks")
	var arrows: Dictionary = recipes.call("hand_recipe", &"arrow")
	_expect(int(arrows.get("count", 0)) == 8, "one arrow recipe yields eight arrows")
	_expect(recipes.call("hand_recipe", &"nonexistent").is_empty(), "unknown hand recipes return empty")

	# Печь обязана делаться без слитков, иначе её не из чего сделать на старте.
	var furnace: Dictionary = recipes.call("hand_recipe", &"machine_furnace")
	var furnace_inputs: Dictionary = furnace.get("inputs", {})
	_expect(not furnace_inputs.has(&"iron_ingot"), "the furnace needs no ingots to build")
	_expect(not furnace_inputs.has(&"wire"), "the furnace needs no wire to build")

	# Волочильный станок обязан делаться без проводов — он их и производит.
	var drawer_inputs: Dictionary = recipes.call("hand_recipe", &"machine_wire_drawer").get("inputs", {})
	_expect(not drawer_inputs.has(&"wire"), "the wire drawer needs no wire to build")


func _test_machine_matching(recipes: Script) -> void:
	var matched: Dictionary = recipes.call("match_recipe", &"furnace", {&"copper_ore": 3})
	_expect(String(matched.get("id", "")) == "copper_ingot", "copper ore matches the ingot recipe")
	_expect(recipes.call("match_recipe", &"furnace", {&"copper_ore": 0}).is_empty(),
		"an empty input box matches nothing")
	_expect(recipes.call("match_recipe", &"assembler", {&"lead_ingot": 4, &"acid": 1, &"plank": 2}).size() > 0,
		"the assembler matches the battery recipe")
	_expect(recipes.call("match_recipe", &"assembler", {&"lead_ingot": 4, &"acid": 1}).is_empty(),
		"a partial battery recipe does not match")
	_expect(recipes.call("match_recipe", &"unknown_machine", {&"stone": 99}).is_empty(),
		"unknown machine types match nothing")


func _test_fuel(recipes: Script) -> void:
	_expect(is_equal_approx(float(recipes.call("fuel_seconds", &"coal")), 8.0), "coal burns for eight seconds")
	_expect(is_zero_approx(float(recipes.call("fuel_seconds", &"stone"))), "stone is not fuel")


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("[PASS] ", message)
	else:
		failures += 1
		printerr("[FAIL] ", message)


func _finish() -> void:
	print("[tests] failures: ", failures)
	quit(failures)

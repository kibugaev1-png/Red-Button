# Проверяет ломание породы удержанием. Механика зависит от времени и удержания
# кнопки, поэтому руками её толком не проверить: тест подсовывает поддельную
# породу и прогоняет время шагами.
extends SceneTree

const MINING_PATH := "res://scripts/systems/mining.gd"

var failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var mining_script: Script = load(MINING_PATH)
	_expect(mining_script != null, "mining script loads")
	if mining_script == null:
		_finish()
		return

	_test_grouping(mining_script)
	_test_hand_cannot_break_stone(mining_script)
	_test_pick_breaks_stone_over_time(mining_script)
	_test_hardness_matters(mining_script)
	_test_drill_is_four_times_faster(mining_script)
	_test_empty_air(mining_script)
	_test_group_switch_and_decay(mining_script)
	_test_whole_group_breaks(mining_script)
	_finish()


# Блоки должны стоять на месте, а не ездить вместе с прицелом: иначе прогресс
# сбрасывается на каждом дрожании мыши.
func _test_grouping(m: Script) -> void:
	_expect(m.call("group_of", 0, 0) == Vector2i(0, 0), "cell 0,0 belongs to group 0,0")
	_expect(m.call("group_of", 1, 1) == Vector2i(0, 0), "cell 1,1 belongs to the same group")
	_expect(m.call("group_of", 2, 3) == Vector2i(2, 2), "cell 2,3 belongs to group 2,2")
	_expect(m.call("group_of", -1, -1) == Vector2i(-2, -2), "negative cells group correctly")
	_expect(m.call("group_of", -2, -2) == Vector2i(-2, -2), "negative group origin is stable")
	_expect(m.call("cells_of", Vector2i(4, 4)).size() == 4, "a group holds four cells")


func _test_hand_cannot_break_stone(m: Script) -> void:
	var terrain := _terrain({Vector2i(0, 0): Core.STONE})
	_expect(not bool(m.call("can_break", terrain, Vector2i(0, 0), &"")),
		"bare hands cannot break stone")
	var mining: RefCounted = m.new()
	var result: Dictionary = mining.call("advance", 10.0, terrain, Vector2i(0, 0), &"")
	_expect(String(result.get("state", "")) == "too_hard", "stone reports too hard for hands")
	_expect(terrain.materials.get(Vector2i(0, 0), Core.AIR) == Core.STONE,
		"stone survives ten seconds of bare hands")
	terrain.free()


# Земля рукой берётся — иначе игрок без инструмента вообще ничего не может.
func _test_pick_breaks_stone_over_time(m: Script) -> void:
	var terrain := _terrain({
		Vector2i(0, 0): Core.STONE, Vector2i(1, 0): Core.STONE,
		Vector2i(0, 1): Core.STONE, Vector2i(1, 1): Core.STONE,
	})
	var mining: RefCounted = m.new()
	var needed: float = m.call("seconds_for", terrain, Vector2i(0, 0))
	_expect(needed > 0.5, "stone takes noticeable time (%.2f s)" % needed)

	# Один короткий шаг ломать не должен — это и был баг «как в креативе».
	var first: Dictionary = mining.call("advance", 0.1, terrain, Vector2i(0, 0), &"pick")
	_expect(String(first.get("state", "")) == "digging", "one short press does not break stone")
	_expect(mining.get("fraction") != null, "progress is observable")
	_expect(float(mining.call("fraction")) > 0.0, "progress accumulates")
	_expect(float(mining.call("fraction")) < 1.0, "progress is not instantly complete")

	var broke := false
	for _i in 100:
		var step: Dictionary = mining.call("advance", 0.05, terrain, Vector2i(0, 0), &"pick")
		if String(step.get("state", "")) == "broken":
			broke = true
			_expect(int(step.get("drops", {}).get("stone", 0)) == 4,
				"breaking a full stone group drops four stone")
			break
	_expect(broke, "held mining eventually breaks the block")
	_expect(is_zero_approx(float(mining.call("fraction"))), "progress resets after breaking")
	terrain.free()


# Твёрдость обязана влиять: бетон должен занимать заметно больше времени, чем
# земля, иначе поле hard в таблице пород снова окажется декорацией.
func _test_hardness_matters(m: Script) -> void:
	var dirt := _terrain({Vector2i(0, 0): Core.DIRT})
	var concrete := _terrain({Vector2i(0, 0): Core.CONCRETE})
	var dirt_time: float = m.call("seconds_for", dirt, Vector2i(0, 0))
	var concrete_time: float = m.call("seconds_for", concrete, Vector2i(0, 0))
	_expect(concrete_time > dirt_time * 4.0,
		"concrete takes far longer than dirt (%.2f vs %.2f)" % [concrete_time, dirt_time])
	dirt.free()
	concrete.free()

	# Самая твёрдая порода в блоке задаёт время целиком.
	var mixed := _terrain({Vector2i(0, 0): Core.DIRT, Vector2i(1, 1): Core.CONCRETE})
	_expect(is_equal_approx(float(m.call("seconds_for", mixed, Vector2i(0, 0))), concrete_time),
		"the hardest material in a group sets the time")
	mixed.free()


func _test_drill_is_four_times_faster(m: Script) -> void:
	var by_pick := _count_steps(m, &"pick")
	var by_drill := _count_steps(m, &"handheld_drill")
	_expect(by_drill > 0 and by_pick > 0, "both tools eventually break stone")
	var ratio := float(by_pick) / float(by_drill)
	_expect(ratio > 3.5 and ratio < 4.5,
		"the drill is about four times faster (measured %.2f×)" % ratio)


func _count_steps(m: Script, item_id: StringName) -> int:
	var terrain := _terrain({
		Vector2i(0, 0): Core.STONE, Vector2i(1, 0): Core.STONE,
		Vector2i(0, 1): Core.STONE, Vector2i(1, 1): Core.STONE,
	})
	var mining: RefCounted = m.new()
	var steps := 0
	for _i in 4000:
		steps += 1
		var step: Dictionary = mining.call("advance", 0.01, terrain, Vector2i(0, 0), item_id)
		if String(step.get("state", "")) == "broken":
			break
	terrain.free()
	return steps


func _test_empty_air(m: Script) -> void:
	var terrain := _terrain({})
	var mining: RefCounted = m.new()
	var result: Dictionary = mining.call("advance", 1.0, terrain, Vector2i(0, 0), &"pick")
	_expect(String(result.get("state", "")) == "empty", "an air-only group reports empty")
	_expect(not bool(m.call("can_break", terrain, Vector2i(0, 0), &"pick")), "air cannot be mined")
	terrain.free()


# Уход прицела не должен обнулять работу мгновенно — дрожь руки не наказывается.
func _test_group_switch_and_decay(m: Script) -> void:
	var terrain := _terrain({
		Vector2i(0, 0): Core.STONE, Vector2i(1, 0): Core.STONE,
		Vector2i(2, 0): Core.STONE, Vector2i(3, 0): Core.STONE,
	})
	var mining: RefCounted = m.new()
	mining.call("advance", 0.5, terrain, Vector2i(0, 0), &"pick")
	var before := float(mining.call("fraction"))
	_expect(before > 0.0, "progress exists before switching")
	mining.call("advance", 0.05, terrain, Vector2i(2, 0), &"pick")
	_expect(float(mining.call("fraction")) < before, "switching groups restarts progress")

	var again: RefCounted = m.new()
	again.call("advance", 0.5, terrain, Vector2i(0, 0), &"pick")
	var held := float(again.call("fraction"))
	again.call("decay", 0.05)
	var decayed := float(again.call("fraction"))
	_expect(decayed < held and decayed > 0.0, "progress decays gradually, not instantly")
	again.call("decay", 100.0)
	_expect(is_zero_approx(float(again.call("fraction"))), "long decay clears progress")
	terrain.free()


# Ломается весь блок 2×2, а не одна частица.
func _test_whole_group_breaks(m: Script) -> void:
	var terrain := _terrain({
		Vector2i(0, 0): Core.DIRT, Vector2i(1, 0): Core.DIRT,
		Vector2i(0, 1): Core.DIRT, Vector2i(1, 1): Core.DIRT,
		Vector2i(2, 0): Core.DIRT,
	})
	var mining: RefCounted = m.new()
	for _i in 2000:
		var step: Dictionary = mining.call("advance", 0.02, terrain, Vector2i(0, 0), &"pick")
		if String(step.get("state", "")) == "broken":
			break
	for cell: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
		_expect(terrain.materials.get(cell, Core.AIR) == Core.AIR,
			"cell %s of the group is gone" % cell)
	_expect(terrain.materials.get(Vector2i(2, 0), Core.AIR) == Core.DIRT,
		"the neighbouring cell outside the group survives")
	terrain.free()


# Поддельная порода: тот же интерфейс, что у Terrain, но без генерации мира.
func _terrain(materials: Dictionary) -> Node:
	var stub := FakeTerrain.new()
	stub.materials = materials.duplicate()
	return stub


class FakeTerrain extends Node:
	var materials: Dictionary = {}

	func get_mat(cx: int, cy: int) -> int:
		return int(materials.get(Vector2i(cx, cy), Core.AIR))

	func dig(cx: int, cy: int, radius: int, max_hard: float) -> Dictionary:
		var drops: Dictionary = {}
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				if dx * dx + dy * dy > radius * radius:
					continue
				var cell := Vector2i(cx + dx, cy + dy)
				var m := int(materials.get(cell, Core.AIR))
				if m == Core.AIR:
					continue
				if float(Core.MATS[m].hard) > max_hard:
					continue
				materials[cell] = Core.AIR
				var d: String = Core.MATS[m].drop
				if d != "":
					drops[d] = int(drops.get(d, 0)) + 1
		return drops


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("[PASS] ", message)
	else:
		failures += 1
		printerr("[FAIL] ", message)


func _finish() -> void:
	print("[tests] failures: ", failures)
	quit(failures)

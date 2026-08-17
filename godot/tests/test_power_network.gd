# Проверяет реестр построек и электросеть: кто с кем соединён, кому сколько
# тока досталось, и что аккумулятор действительно спасает при просадке.
extends SceneTree

var failures: int = 0
var _made: Array = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_grid()
	_test_grouping()
	_test_full_supply()
	_test_shortage_slows_everyone()
	_test_battery_covers_the_gap()
	_test_dead_generator_gives_nothing()
	_test_dirty_flag()
	_test_battery_save()
	_cleanup()
	_finish()


func _test_grid() -> void:
	var grid := MachineGrid.new()
	var furnace := _machine(&"furnace", Vector2i(0, 0))
	_expect(grid.register(furnace), "a machine registers into the grid")
	_expect(grid.count() == 1, "the grid holds one machine")
	_expect(grid.at(Vector2i(0, 0)) == furnace, "the grid answers by cell")
	_expect(grid.at(Vector2i(5, 4)) == furnace, "the grid answers for every cell of the footprint")
	_expect(grid.at(Vector2i(6, 0)) == null, "cells outside the footprint stay empty")
	_expect(grid.is_free(Vector2i(99, 99)), "far away cells are free")

	# Наложение построек друг на друга запрещено — иначе база превращается в кашу.
	var overlapping := _machine(&"furnace", Vector2i(2, 2))
	_expect(not grid.register(overlapping), "an overlapping machine is rejected")
	_expect(grid.count() == 1, "a rejected machine does not enter the grid")

	grid.unregister(furnace)
	_expect(grid.count() == 0, "unregistering empties the grid")
	_expect(grid.at(Vector2i(0, 0)) == null, "unregistered cells are released")


func _test_grouping() -> void:
	var grid := MachineGrid.new()
	# Две постройки вплотную и одна далеко: должно получиться две сети.
	var hydro := _machine(&"hydro", Vector2i(0, 0))
	var wire := _machine(&"wire", Vector2i(6, 0))
	var far := _machine(&"furnace", Vector2i(80, 0))
	grid.register(hydro)
	grid.register(wire)
	grid.register(far)

	var network := PowerNetwork.new()
	network.rebuild(grid)
	_expect(network.groups().size() == 2, "touching machines form one network, distant ones another")

	# Диагональ соединением не считается: по картинке это неочевидно.
	var diagonal_grid := MachineGrid.new()
	diagonal_grid.register(_machine(&"wire", Vector2i(0, 0)))
	diagonal_grid.register(_machine(&"wire", Vector2i(1, 1)))
	var diagonal_network := PowerNetwork.new()
	diagonal_network.rebuild(diagonal_grid)
	_expect(diagonal_network.groups().size() == 2, "diagonal wires do not connect")


# Генерация покрывает спрос — все работают в полную силу.
func _test_full_supply() -> void:
	var grid := MachineGrid.new()
	var hydro := _machine(&"hydro", Vector2i(0, 0))          # +30
	var drawer := _machine(&"wire_drawer", Vector2i(6, 0))   # -12
	grid.register(hydro)
	grid.register(drawer)
	var network := PowerNetwork.new()
	network.rebuild(grid)
	var report: Array = network.distribute(0.1)
	_expect(report.size() == 1, "one connected network reports once")
	_expect(is_equal_approx(float(report[0].generation), 30.0), "the hydro generator supplies 30 W")
	_expect(is_equal_approx(float(report[0].demand), 12.0), "the wire drawer demands 12 W")
	_expect(is_equal_approx(float(drawer.power_satisfaction), 1.0), "a supplied machine runs at full speed")


# Дефицит должен замедлять всех пропорционально, а не гасить машины по очереди.
func _test_shortage_slows_everyone() -> void:
	var grid := MachineGrid.new()
	grid.register(_machine(&"hydro", Vector2i(0, 0)))          # +30
	var drill := _machine(&"drill", Vector2i(6, 0))            # -20
	var drawer := _machine(&"wire_drawer", Vector2i(10, 0))    # -12
	grid.register(drill)
	grid.register(drawer)
	var network := PowerNetwork.new()
	network.rebuild(grid)
	network.distribute(0.1)
	# 30 доступно на 32 спроса — примерно 0,94 у каждого.
	_expect(float(drill.power_satisfaction) < 1.0, "a starved drill slows down")
	_expect(is_equal_approx(drill.power_satisfaction, drawer.power_satisfaction),
		"every machine in a starved network slows down equally")
	_expect(drill.power_satisfaction > 0.9, "a small shortage only slightly slows the factory")


func _test_battery_covers_the_gap() -> void:
	var grid := MachineGrid.new()
	# Аккумулятор занимает 4 клетки в ширину, поэтому бур ставим вплотную на
	# четвёртую: щель хотя бы в одну клетку — это уже две разные сети.
	var drill := _machine(&"drill", Vector2i(4, 0))            # -20, генерации нет
	var battery := _machine(&"battery", Vector2i(0, 0)) as BatteryBlock
	battery.stored = BatteryBlock.CAPACITY
	grid.register(battery)
	grid.register(drill)
	var network := PowerNetwork.new()
	network.rebuild(grid)
	network.distribute(0.5)
	_expect(is_equal_approx(float(drill.power_satisfaction), 1.0),
		"a full battery keeps the drill running with no generator")
	_expect(battery.stored < BatteryBlock.CAPACITY, "the battery loses charge while covering demand")

	# Пустой аккумулятор ничего не спасает.
	battery.stored = 0.0
	network.distribute(0.5)
	_expect(float(drill.power_satisfaction) <= 0.01, "an empty battery cannot power anything")

	# Излишек генерации уходит в заряд.
	var charging := MachineGrid.new()
	var spare := _machine(&"battery", Vector2i(0, 0)) as BatteryBlock
	charging.register(spare)
	charging.register(_machine(&"hydro", Vector2i(4, 0)))
	var charger := PowerNetwork.new()
	charger.rebuild(charging)
	charger.distribute(1.0)
	_expect(spare.stored > 0.0, "surplus generation charges the battery")
	_expect(spare.stored <= PowerNetwork.CHARGE_RATE + 0.001, "charging respects its rate limit")


# Гидрогенератор без воды не должен врать, что даёт ток.
func _test_dead_generator_gives_nothing() -> void:
	var grid := MachineGrid.new()
	var hydro := DeadGenerator.new()
	hydro.setup(&"hydro", Vector2i(0, 0))
	var drawer := _machine(&"wire_drawer", Vector2i(6, 0))
	grid.register(hydro)
	grid.register(drawer)
	_made.append(hydro)
	var network := PowerNetwork.new()
	network.rebuild(grid)
	var report: Array = network.distribute(0.1)
	_expect(is_zero_approx(float(report[0].generation)), "a generator that cannot run supplies nothing")
	_expect(is_zero_approx(float(drawer.power_satisfaction)), "machines get nothing from a dead generator")


func _test_dirty_flag() -> void:
	var network := PowerNetwork.new()
	_expect(network.is_dirty(), "a fresh network needs building")
	network.rebuild(MachineGrid.new())
	_expect(not network.is_dirty(), "rebuilding clears the dirty flag")
	network.mark_dirty()
	_expect(network.is_dirty(), "building or demolishing marks the network dirty")


func _test_battery_save() -> void:
	var battery := _machine(&"battery", Vector2i(3, 4)) as BatteryBlock
	battery.stored = 1234.0
	var state: Dictionary = battery.serialize_state()
	var restored := BatteryBlock.new()
	_made.append(restored)
	_expect(restored.restore_state(state), "a battery restores from its own state")
	_expect(is_equal_approx(restored.stored, 1234.0), "stored charge survives a save")
	_expect(restored.cell == Vector2i(3, 4), "the cell survives a save")
	_expect(not restored.restore_state({"type": "nonexistent"}), "an unknown machine type is rejected")

	# Отрицательные количества из правленого руками сейва не должны проходить.
	var dirty := BatteryBlock.new()
	_made.append(dirty)
	dirty.restore_state({"type": "battery", "cell": {"x": 0, "y": 0}, "inputs": {"coal": -5, "stone": 3}})
	_expect(not dirty.inputs.has(&"coal"), "negative amounts are dropped when loading")
	_expect(int(dirty.inputs.get(&"stone", 0)) == 3, "valid amounts survive loading")


func _machine(type_id: StringName, at: Vector2i) -> Node2D:
	var made: Node2D = MachineCatalog.create(type_id, at)
	if made == null:
		made = Machine.new()
		made.call("setup", type_id, at)
	_made.append(made)
	return made


func _cleanup() -> void:
	for made: Variant in _made:
		if is_instance_valid(made):
			(made as Node).free()
	_made.clear()


# Генератор, который не может работать: у настоящего гидрогенератора так бывает,
# когда рядом не осталось воды.
class DeadGenerator extends Machine:
	func can_generate() -> bool:
		return false


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("[PASS] ", message)
	else:
		failures += 1
		printerr("[FAIL] ", message)


func _finish() -> void:
	print("[tests] failures: ", failures)
	quit(failures)

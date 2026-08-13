# machine_catalog.gd — таблица построек: размер, ток, из какого предмета ставится.
#
# Числа лежат отдельно от поведения намеренно. Размер печи нужен и превью
# стройки, и реестру клеток, и сохранению — если бы он жил внутри furnace.gd,
# каждому из них пришлось бы создавать печь, чтобы спросить её размер.
#
# Знак у "power" читается как в жизни: минус — потребление, плюс — генерация.
# Отдельного поля "генератор" нет, потому что оно повторяло бы знак.
class_name MachineCatalog
extends RefCounted

const DIR := "res://scripts/machines/"

# size — основание в клетках, power — ватты, support — обязана ли постройка
# опираться на твёрдую породу. Провод и лента от опоры освобождены: провод
# должен уметь идти по стене, иначе разводка по базе невозможна.
const TYPES: Dictionary = {
	&"wire": {
		"name": "Провод", "item": &"wire", "size": Vector2i(1, 1), "power": 0.0,
		"support": false, "script": "machine.gd", "color": Color(0.72, 0.45, 0.22),
	},
	&"belt": {
		"name": "Лента", "item": &"machine_belt", "size": Vector2i(2, 1), "power": 0.0,
		"support": false, "script": "belt.gd", "color": Color(0.38, 0.36, 0.34),
	},
	&"furnace": {
		"name": "Печь", "item": &"machine_furnace", "size": Vector2i(6, 5), "power": 0.0,
		"support": true, "script": "furnace.gd", "color": Color(0.42, 0.30, 0.24),
	},
	&"wire_drawer": {
		"name": "Волочильный станок", "item": &"machine_wire_drawer", "size": Vector2i(6, 4),
		"power": -12.0, "support": true, "script": "wire_drawer.gd", "color": Color(0.40, 0.42, 0.46),
	},
	&"drill": {
		"name": "Бур", "item": &"machine_drill", "size": Vector2i(4, 6), "power": -20.0,
		"support": true, "script": "drill.gd", "color": Color(0.46, 0.40, 0.28),
	},
	&"assembler": {
		"name": "Сборочная станция", "item": &"machine_assembler", "size": Vector2i(8, 5),
		"power": -18.0, "support": true, "script": "assembler.gd", "color": Color(0.34, 0.42, 0.44),
	},
	&"hydro": {
		"name": "Гидрогенератор", "item": &"machine_hydro", "size": Vector2i(6, 6), "power": 30.0,
		"support": true, "script": "hydro_generator.gd", "color": Color(0.28, 0.44, 0.50),
	},
	&"battery": {
		"name": "Аккумуляторный блок", "item": &"machine_battery", "size": Vector2i(4, 5),
		"power": 0.0, "support": true, "script": "battery_block.gd", "color": Color(0.30, 0.36, 0.30),
	},
	&"purifier": {
		"name": "Очиститель воды", "item": &"machine_purifier", "size": Vector2i(5, 5),
		"power": -10.0, "support": true, "script": "water_purifier.gd", "color": Color(0.32, 0.46, 0.42),
	},
	&"fence": {
		"name": "Электрозабор", "item": &"machine_fence", "size": Vector2i(1, 5), "power": -5.0,
		"support": true, "script": "electric_fence.gd", "color": Color(0.50, 0.46, 0.20),
	},
}


static func has_type(machine_type: StringName) -> bool:
	return TYPES.has(machine_type)


static func get_type(machine_type: StringName) -> Dictionary:
	return TYPES.get(machine_type, {}).duplicate(true)


static func size_of(machine_type: StringName) -> Vector2i:
	return TYPES.get(machine_type, {}).get("size", Vector2i.ONE)


static func power_of(machine_type: StringName) -> float:
	return float(TYPES.get(machine_type, {}).get("power", 0.0))


static func display_name(machine_type: StringName) -> String:
	return String(TYPES.get(machine_type, {}).get("name", ""))


static func item_of(machine_type: StringName) -> StringName:
	return TYPES.get(machine_type, {}).get("item", &"")


static func needs_support(machine_type: StringName) -> bool:
	return bool(TYPES.get(machine_type, {}).get("support", true))


# Обратный поиск: игрок держит в руке предмет, а поставить надо постройку.
static func type_for_item(item_id: StringName) -> StringName:
	for machine_type: StringName in TYPES:
		if TYPES[machine_type].item == item_id:
			return machine_type
	return &""


# Скрипт грузится по строке, а не через preload: preload завязал бы каталог на
# печь, печь — на базовый класс, а базовый класс — обратно на каталог, и разбор
# кольца пришлось бы объяснять компилятору.
static func create(machine_type: StringName, at_cell: Vector2i = Vector2i.ZERO, facing: int = 1) -> Node2D:
	if not TYPES.has(machine_type):
		return null
	var script: Script = load(DIR + String(TYPES[machine_type].script))
	if script == null:
		return null
	var node: Node2D = script.new()
	node.call("setup", machine_type, at_cell, facing)
	return node


# Сейв из будущей версии может содержать тип, которого в сборке нет. Такая
# запись пропускается — остальной сейв обязан загрузиться.
static func from_save(state: Dictionary) -> Node2D:
	var machine_type := StringName(String(state.get("type", "")))
	if not TYPES.has(machine_type):
		push_warning("Неизвестный тип машины в сохранении: %s" % machine_type)
		return null
	var machine := create(machine_type)
	if machine == null:
		return null
	if not bool(machine.call("restore_state", state)):
		machine.free()
		return null
	return machine

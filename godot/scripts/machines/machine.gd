# machine.gd — общий предок всех построек.
#
# Держит то, что одинаково у печи, бура и забора: место в сетке частиц, входной
# и выходной ящик, доля питания и сохранение. Что машина делает за тик — дело
# наследника, здесь этого нет намеренно: иначе базовый класс знал бы про рецепты
# печи, добычу бура и урон забора одновременно.
#
# Устройство сохранения повторяет loot_crate.gd: stable_id, serialize_state,
# restore_state. Второй способ хранить состояние в проекте заводить незачем.
class_name Machine
extends Node2D

const CELL := 8

@export var stable_id: String = ""

var machine_type: StringName = &""
var cell: Vector2i = Vector2i.ZERO
var facing: int = 1

# Входной и выходной ящики раздельные. Общий привёл бы к тому, что печь
# переплавляла бы собственные слитки обратно, а лента, забирающая результат,
# вытаскивала бы непереплавленную руду.
var inputs: Dictionary = {}
var outputs: Dictionary = {}

# Доля питания от нуля до единицы: её выставляет электросеть. При дефиците все
# машины замедляются пропорционально, а не встают по очереди.
var power_satisfaction: float = 1.0

# Сколько предметов влезает в один ящик. Предел нужен, чтобы затор на выходе
# останавливал машину, а не копил бесконечную гору внутри неё.
const BOX_LIMIT := 200

var _progress: float = 0.0


func setup(type_id: StringName, at_cell: Vector2i, look: int = 1) -> void:
	machine_type = type_id
	cell = at_cell
	facing = 1 if look >= 0 else -1
	if stable_id.is_empty():
		stable_id = "%s.%d.%d" % [String(type_id), at_cell.x, at_cell.y]
	position = Vector2(at_cell.x * CELL, at_cell.y * CELL)


func size() -> Vector2i:
	return MachineCatalog.size_of(machine_type)


func power_draw() -> float:
	return MachineCatalog.power_of(machine_type)


# Все клетки, которые занимает постройка. Нужны и реестру, и проверке стройки,
# и поиску соседей.
func occupied_cells() -> Array:
	var cells: Array = []
	var s := size()
	for dy in s.y:
		for dx in s.x:
			cells.append(Vector2i(cell.x + dx, cell.y + dy))
	return cells


# Клетки по периметру снаружи — с ними машина соприкасается с проводами и
# лентами. Углы не считаем: соединение по диагонали читается неоднозначно.
func border_cells() -> Array:
	var cells: Array = []
	var s := size()
	for dx in s.x:
		cells.append(Vector2i(cell.x + dx, cell.y - 1))
		cells.append(Vector2i(cell.x + dx, cell.y + s.y))
	for dy in s.y:
		cells.append(Vector2i(cell.x - 1, cell.y + dy))
		cells.append(Vector2i(cell.x + s.x, cell.y + dy))
	return cells


# ---- ящики ----

func total_in(box: Dictionary) -> int:
	var sum := 0
	for item_id: Variant in box:
		sum += int(box[item_id])
	return sum


# Возвращает, сколько НЕ влезло: тот же договор, что у inventory.add.
func insert(item_id: StringName, count: int) -> int:
	if count <= 0 or not accepts(item_id):
		return maxi(0, count)
	var free := BOX_LIMIT - total_in(inputs)
	var taken := mini(free, count)
	if taken <= 0:
		return count
	inputs[item_id] = int(inputs.get(item_id, 0)) + taken
	return count - taken


# По умолчанию машина принимает всё: сузить приём — дело наследника, который
# знает свои рецепты.
func accepts(_item_id: StringName) -> bool:
	return true


func output_full() -> bool:
	return total_in(outputs) >= BOX_LIMIT


# Забрать одну единицу с выхода — этим пользуется лента и рука игрока.
func take_one() -> StringName:
	for item_id: Variant in outputs:
		var left := int(outputs[item_id]) - 1
		if left <= 0:
			outputs.erase(item_id)
		else:
			outputs[item_id] = left
		return StringName(item_id)
	return &""


func push_output(item_id: StringName, count: int) -> void:
	if count <= 0:
		return
	outputs[item_id] = int(outputs.get(item_id, 0)) + count


# ---- работа ----

# Наследник переопределяет. Здесь пусто, а не «абстрактно с ошибкой»: провод и
# аккумуляторный блок ничего не делают за тик, и заставлять их писать пустышку
# было бы шумом.
func tick(_dt: float) -> void:
	pass


# ---- сохранение ----

func serialize_state() -> Dictionary:
	return {
		"stable_id": stable_id,
		"type": String(machine_type),
		"cell": {"x": cell.x, "y": cell.y},
		"facing": facing,
		"inputs": inputs.duplicate(),
		"outputs": outputs.duplicate(),
		"progress": _progress,
	}


func restore_state(saved: Dictionary) -> bool:
	var type_id := StringName(String(saved.get("type", "")))
	if not MachineCatalog.has_type(type_id):
		return false
	var raw_cell: Variant = saved.get("cell", {})
	var at := Vector2i.ZERO
	if raw_cell is Dictionary:
		at = Vector2i(int(raw_cell.get("x", 0)), int(raw_cell.get("y", 0)))
	stable_id = String(saved.get("stable_id", ""))
	setup(type_id, at, int(saved.get("facing", 1)))
	inputs = _clean_box(saved.get("inputs", {}))
	outputs = _clean_box(saved.get("outputs", {}))
	_progress = maxf(0.0, float(saved.get("progress", 0.0)))
	return true


# Сейв мог быть поправлен руками: отрицательные и нулевые количества выкидываем,
# иначе они разъедутся по всей игре и вылезут где-нибудь в инвентаре.
func _clean_box(raw: Variant) -> Dictionary:
	var box: Dictionary = {}
	if not raw is Dictionary:
		return box
	for item_id: Variant in raw:
		var count := int((raw as Dictionary)[item_id])
		if count > 0:
			box[StringName(item_id)] = count
	return box

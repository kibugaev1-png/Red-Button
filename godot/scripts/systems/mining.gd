# mining.gd — ломание породы с удержанием.
#
# Раньше копание работало так: один клик — и круг радиусом четыре частицы
# исчезает мгновенно, независимо от породы. Играть в это невозможно: бетонная
# стена сносится так же легко, как трава, и мир не сопротивляется вообще.
#
# Теперь порода ломается блоками 2×2 частицы с накоплением прогресса, пока
# держишь кнопку. Время зависит от твёрдости — поле "hard" в Core.MATS всё это
# время лежало в таблице без применения: земля 0,4, камень 1,1, бетон 2,2,
# арматура 2,6. Инструмент решает, что вообще берётся: рукой камень не
# выковырять, и это правильно.
#
# Класс намеренно не знает про сцену и ввод — только про породу и время. Поэтому
# его можно проверить тестом без запуска игры, что для механики, зависящей от
# удержания кнопки, единственный разумный способ.
class_name Mining
extends RefCounted

# Сторона блока в частицах. Двойка, а не четвёрка: 2×2 при частице 8 пикселей
# даёт кусок 16×16 — заметный на глаз, но не превращающий рельеф в лестницу.
const GROUP := 2

# Секунд на единицу твёрдости при инструменте со скоростью 1. Камень (1,1)
# киркой выходит примерно за секунду — достаточно, чтобы почувствовать породу,
# и не настолько долго, чтобы это утомляло.
const SECONDS_PER_HARD := 0.9

# Скорость и предел твёрдости по инструменту. Предел важнее скорости: он решает,
# что игрок вообще может сломать, и потому задаёт порядок освоения мира.
const TOOLS: Dictionary = {
	&"": {"rate": 0.45, "max_hard": 0.5, "name": "руками"},
	&"pick": {"rate": 1.0, "max_hard": 3.0, "name": "киркой"},
	&"axe": {"rate": 1.0, "max_hard": 0.8, "name": "топором"},
	&"handheld_drill": {"rate": 4.0, "max_hard": 3.0, "name": "буром"},
}

# Прогресс сбрасывается не мгновенно при уходе прицела, а угасает: иначе дрожь
# руки на границе двух блоков обнуляет работу и это ощущается как поломка.
const DECAY_PER_SECOND := 2.5

var group: Vector2i = Vector2i(2147483647, 2147483647)
var progress: float = 0.0
var required: float = 0.0


# Блок, которому принадлежит частица. Выравнивание по чётным клеткам, а не «блок
# вокруг курсора»: иначе границы блоков ездят вместе с прицелом и прогресс
# сбрасывается на каждом движении мыши.
static func group_of(cx: int, cy: int) -> Vector2i:
	return Vector2i(cx - posmod(cx, GROUP), cy - posmod(cy, GROUP))


static func cells_of(origin: Vector2i) -> Array:
	var cells: Array = []
	for dy in GROUP:
		for dx in GROUP:
			cells.append(Vector2i(origin.x + dx, origin.y + dy))
	return cells


static func tool_of(item_id: StringName) -> Dictionary:
	return TOOLS.get(item_id, TOOLS[&""]).duplicate()


# Самая твёрдая порода в блоке задаёт время. Блок ломается целиком, поэтому
# считать по среднему было бы обманом: игрок видит бетон и ждёт, что будет тяжело.
static func hardest(terrain: Node, origin: Vector2i) -> float:
	var worst := -1.0
	for cell: Vector2i in cells_of(origin):
		var m: int = terrain.call("get_mat", cell.x, cell.y)
		if m == Core.AIR:
			continue
		worst = maxf(worst, float(Core.MATS[m].hard))
	return worst


static func seconds_for(terrain: Node, origin: Vector2i) -> float:
	var worst := hardest(terrain, origin)
	if worst < 0.0:
		return 0.0
	return maxf(0.05, worst * SECONDS_PER_HARD)


# Пустой блок ломать нечего, слишком твёрдый — нечем.
static func can_break(terrain: Node, origin: Vector2i, item_id: StringName) -> bool:
	var worst := hardest(terrain, origin)
	if worst < 0.0:
		return false
	return worst <= float(tool_of(item_id).max_hard)


func reset() -> void:
	group = Vector2i(2147483647, 2147483647)
	progress = 0.0
	required = 0.0


# Доля выполненного от нуля до единицы — для трещин на блоке в интерфейсе.
func fraction() -> float:
	if required <= 0.0:
		return 0.0
	return clampf(progress / required, 0.0, 1.0)


# Прицел ушёл, но кнопка ещё держится: гасим прогресс, а не обнуляем.
func decay(dt: float) -> void:
	progress = maxf(0.0, progress - dt * DECAY_PER_SECOND)
	if is_zero_approx(progress):
		reset()


# Главный шаг. Возвращает:
#   {"state": "empty"}    — в блоке нет породы
#   {"state": "too_hard", "tool": "руками"} — инструмент не берёт
#   {"state": "digging"}  — копаем, прогресс идёт
#   {"state": "broken", "drops": {...}} — блок сломан, вот добыча
func advance(dt: float, terrain: Node, origin: Vector2i, item_id: StringName) -> Dictionary:
	var worst := hardest(terrain, origin)
	if worst < 0.0:
		reset()
		return {"state": "empty"}

	var tool: Dictionary = tool_of(item_id)
	if worst > float(tool.max_hard):
		reset()
		return {"state": "too_hard", "tool": String(tool.name)}

	if origin != group:
		group = origin
		progress = 0.0
	required = maxf(0.05, worst * SECONDS_PER_HARD)
	progress += dt * float(tool.rate)
	if progress < required:
		return {"state": "digging"}

	# Ломаем по одной частице через существующий terrain.dig с радиусом ноль:
	# он уже умеет запоминать изменение для сохранения и пересчитывать свет.
	var drops: Dictionary = {}
	for cell: Vector2i in cells_of(origin):
		var got: Dictionary = terrain.call("dig", cell.x, cell.y, 0, float(tool.max_hard))
		for item: Variant in got:
			drops[item] = int(drops.get(item, 0)) + int(got[item])
	reset()
	return {"state": "broken", "drops": drops}

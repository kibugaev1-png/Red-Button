# power_network.gd — кто с кем соединён и кому сколько тока досталось.
#
# Граф пересчитывается ТОЛЬКО когда что-то построили или снесли, по флагу
# «испорчен». Считать связность каждый кадр незачем: провода сами по себе не
# двигаются, а обход графа на сорока машинах в кадре — это работа впустую
# шестьдесят раз в секунду.
#
# Напряжений, фаз и раздельных подсетей здесь нет сознательно. На девяти типах
# машин разница между «умной» энергетикой и честным делением не почувствуется, а
# кода и способов ошибиться прибавится втрое.
class_name PowerNetwork
extends RefCounted

# Заряд и разряд аккумулятора за секунду, в ваттах. Разряд быстрее заряда:
# аккумулятор должен спасать в пик, а копиться неспешно.
const CHARGE_RATE := 20.0
const DISCHARGE_RATE := 45.0

var _dirty: bool = true
# Группы связанных построек: каждая — отдельная сеть. Две базы на разных концах
# карты не должны делить один ток.
var _groups: Array = []
# Что досталось каждой сети в последний расчёт — для интерфейса.
var _reports: Array = []


func mark_dirty() -> void:
	_dirty = true


func is_dirty() -> bool:
	return _dirty


func groups() -> Array:
	return _groups.duplicate()


func reports() -> Array:
	return _reports.duplicate()


# Обход в ширину по соседям. Соединяет всё, что стоит вплотную: провод к
# проводу, провод к машине, машина к машине. Отдельного правила «только через
# провод» нет — прижатые друг к другу машины и в жизни соединяются шиной.
func rebuild(grid: MachineGrid) -> void:
	_groups.clear()
	var seen: Dictionary = {}
	for machine: Node2D in grid.machines():
		if seen.has(machine):
			continue
		var group: Array = []
		var queue: Array = [machine]
		seen[machine] = true
		while not queue.is_empty():
			var current: Node2D = queue.pop_back()
			group.append(current)
			for other: Node2D in grid.neighbours_of(current):
				if not seen.has(other):
					seen[other] = true
					queue.append(other)
		_groups.append(group)
	_dirty = false


# Раздаёт ток за шаг. Возвращает отчёт по каждой сети — его показывает интерфейс,
# чтобы игрок понимал, почему завод замедлился.
func distribute(dt: float) -> Array:
	_reports.clear()
	for group: Array in _groups:
		_reports.append(_distribute_group(group, dt))
	return _reports.duplicate()


func _distribute_group(group: Array, dt: float) -> Dictionary:
	var generation := 0.0
	var demand := 0.0
	var batteries: Array = []
	for machine: Node2D in group:
		if not is_instance_valid(machine):
			continue
		if machine.has_method("stored_energy"):
			batteries.append(machine)
		var draw: float = machine.call("power_draw")
		if draw > 0.0:
			# Генератор может быть не в состоянии работать: гидрогенератор без
			# воды рядом не даёт ничего, и врать об этом нельзя.
			if machine.has_method("can_generate") and not bool(machine.call("can_generate")):
				continue
			generation += draw
		elif draw < 0.0:
			demand += -draw

	var stored := 0.0
	for battery: Node2D in batteries:
		stored += float(battery.call("stored_energy"))

	# Аккумулятор отдаёт не весь запас разом, а с ограниченной скоростью.
	var from_battery := minf(maxf(0.0, demand - generation), minf(DISCHARGE_RATE, stored / maxf(dt, 0.0001)))
	var available := generation + from_battery
	var satisfaction := 1.0 if demand <= 0.0 else clampf(available / demand, 0.0, 1.0)

	for machine: Node2D in group:
		if is_instance_valid(machine):
			machine.set("power_satisfaction", satisfaction)

	# Излишек уходит в заряд, нехватку добираем из запаса.
	var surplus := generation - demand
	if surplus > 0.0:
		_charge(batteries, minf(surplus, CHARGE_RATE) * dt)
	elif from_battery > 0.0:
		_drain(batteries, from_battery * dt)

	return {
		"generation": generation,
		"demand": demand,
		"stored": stored,
		"satisfaction": satisfaction,
		"machines": group.size(),
	}


func _charge(batteries: Array, energy: float) -> void:
	if batteries.is_empty() or energy <= 0.0:
		return
	var share := energy / float(batteries.size())
	for battery: Node2D in batteries:
		if is_instance_valid(battery):
			battery.call("charge", share)


func _drain(batteries: Array, energy: float) -> void:
	if batteries.is_empty() or energy <= 0.0:
		return
	# Тянем по кругу, а не поровну: часть аккумуляторов может быть уже пустой, и
	# равная доля с них просто потерялась бы.
	var left := energy
	for battery: Node2D in batteries:
		if not is_instance_valid(battery) or left <= 0.0:
			continue
		left -= float(battery.call("drain", left))

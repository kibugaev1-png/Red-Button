# battery_block.gd — запас тока на ночь.
#
# Сам ничего не потребляет и не производит: он буфер. Днём гидрогенератор отдаёт
# излишек сюда, ночью, когда напор падает, завод доедает отсюда и не встаёт.
# Без него любая просадка генерации мгновенно останавливает всю базу, и игрок
# видит только «всё сломалось», не понимая почему.
class_name BatteryBlock
extends Machine

# Ватт-секунды. Три тысячи — это примерно полторы минуты работы бура со станком
# при полностью потерянной генерации: достаточно, чтобы пережить ночь или дойти
# и починить, но не настолько много, чтобы генераторы стали необязательными.
const CAPACITY := 3000.0

var stored: float = 0.0


func stored_energy() -> float:
	return stored


func fraction() -> float:
	return clampf(stored / CAPACITY, 0.0, 1.0)


func charge(energy: float) -> float:
	if energy <= 0.0:
		return 0.0
	var taken := minf(energy, CAPACITY - stored)
	stored += taken
	return taken


# Возвращает, сколько реально удалось отдать: сеть по этому числу понимает,
# добрала она нехватку или нет.
func drain(energy: float) -> float:
	if energy <= 0.0:
		return 0.0
	var given := minf(energy, stored)
	stored -= given
	return given


func serialize_state() -> Dictionary:
	var state := super.serialize_state()
	state["stored"] = stored
	return state


func restore_state(saved: Dictionary) -> bool:
	if not super.restore_state(saved):
		return false
	stored = clampf(float(saved.get("stored", 0.0)), 0.0, CAPACITY)
	return true

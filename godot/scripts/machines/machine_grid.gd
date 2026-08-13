# machine_grid.gd — реестр «клетка → постройка».
#
# Без него любой вопрос вроде «что стоит в этой клетке» или «кто мой сосед»
# превращался бы в обход всех построек на базе. При сорока машинах и ленте,
# которая спрашивает соседа каждый тик, это ощутимо: словарь отвечает за одно
# обращение независимо от размера базы.
#
# Реестр намеренно ничего не знает про породу и питание — только про то, что где
# стоит. Проверку опоры делает стройка, ток считает электросеть.
class_name MachineGrid
extends RefCounted

var _by_cell: Dictionary = {}
var _machines: Array = []


func clear() -> void:
	_by_cell.clear()
	_machines.clear()


func machines() -> Array:
	return _machines.duplicate()


func count() -> int:
	return _machines.size()


func at(cell: Vector2i) -> Node2D:
	return _by_cell.get(cell, null)


func is_free(cell: Vector2i) -> bool:
	return not _by_cell.has(cell)


# Заняты ли хоть какие-то из клеток. Пользуется стройка перед установкой.
func any_occupied(cells: Array) -> bool:
	for cell: Vector2i in cells:
		if _by_cell.has(cell):
			return true
	return false


func register(machine: Node2D) -> bool:
	if machine == null:
		return false
	var cells: Array = machine.call("occupied_cells")
	if any_occupied(cells):
		return false
	for cell: Vector2i in cells:
		_by_cell[cell] = machine
	_machines.append(machine)
	return true


func unregister(machine: Node2D) -> void:
	if machine == null:
		return
	# Идём по записям реестра, а не по occupied_cells: постройку могли сдвинуть
	# после регистрации, и тогда часть клеток осталась бы висеть навсегда.
	for cell: Variant in _by_cell.keys():
		if _by_cell[cell] == machine:
			_by_cell.erase(cell)
	_machines.erase(machine)


# Соседи по стороне: всё, что стоит вплотную к периметру. Диагонали не считаются
# соединением — по картинке это неочевидно, и игрок будет спорить с правилом.
func neighbours_of(machine: Node2D) -> Array:
	var found: Array = []
	if machine == null:
		return found
	for cell: Vector2i in machine.call("border_cells"):
		var other: Node2D = _by_cell.get(cell, null)
		if other != null and other != machine and not found.has(other):
			found.append(other)
	return found


# Всё, что стоит в перечисленных клетках, без повторов.
func machines_in(cells: Array) -> Array:
	var found: Array = []
	for cell: Vector2i in cells:
		var machine: Node2D = _by_cell.get(cell, null)
		if machine != null and not found.has(machine):
			found.append(machine)
	return found

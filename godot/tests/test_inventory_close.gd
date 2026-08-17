# Проверка, что из инвентаря можно выйти.
#
# Жалоба игрока: инвентарь открывается, а закрыть его нечем — ни I, ни Tab, ни
# Escape. Тест поднимает настоящую сцену игры и подаёт настоящие события клавиш,
# поэтому ловит именно то, с чем сталкивается игрок: перехват клавиши кнопкой,
# которая получила фокус, или обработчик, до которого событие не доходит.
#
# Запуск:  godot --headless --path godot -- --test-inventory
extends Node

var game: Node
var log_lines: PackedStringArray = []


func _ready() -> void:
	game = load("res://main.tscn").instantiate()
	add_child(game)
	await get_tree().process_frame
	await get_tree().process_frame
	# мир генерируется в _ready, ждём пока игра встанет на ноги
	for _i in 20:
		await get_tree().process_frame
	# Игра открывается главным меню, а инвентарь работает только в игре.
	# Начинаем партию без затемнения, иначе тест ждал бы анимацию.
	game._begin_game(false, false)
	for _i in 10:
		await get_tree().process_frame
	await _run()
	for line in log_lines:
		print(line)
	get_tree().quit(0 if not log_lines.has("ПРОВАЛ") else 1)


func _press(code: Key) -> void:
	var down := InputEventKey.new()
	down.physical_keycode = code
	down.keycode = code
	down.pressed = true
	Input.parse_input_event(down)
	await get_tree().process_frame
	var up := InputEventKey.new()
	up.physical_keycode = code
	up.keycode = code
	up.pressed = false
	Input.parse_input_event(up)
	await get_tree().process_frame
	await get_tree().process_frame


func _open() -> bool:
	return bool(game.inventory_ui.is_open())


func _check(name: String, ok: bool) -> void:
	log_lines.append(("  ок   " if ok else "  ПРОВАЛ  ") + name)
	if not ok:
		log_lines.append("ПРОВАЛ")


func _run() -> void:
	_check("сначала инвентарь закрыт", not _open())

	# ---- закрытие той же клавишей, которой открыли ----
	await _press(KEY_I)
	_check("I открывает инвентарь", _open())
	await _press(KEY_I)
	_check("I закрывает инвентарь", not _open())

	# ---- Escape ----
	await _press(KEY_I)
	_check("инвентарь снова открыт", _open())
	await _press(KEY_ESCAPE)
	_check("Escape закрывает инвентарь", not _open())

	# ---- Tab ----
	await _press(KEY_TAB)
	_check("Tab открывает инвентарь", _open())
	await _press(KEY_TAB)
	_check("Tab закрывает инвентарь", not _open())

	# ---- после закрытия игрок снова управляем ----
	if _open():
		await _press(KEY_ESCAPE)
	_check("после закрытия игрок снова ходит", game.player.is_physics_processing())

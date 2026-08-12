class_name GameManager
extends Node

const SAVE_VERSION: int = 1
@export var save_path: String = "user://savegame.json"


func has_save() -> bool:
	return FileAccess.file_exists(save_path) and not load_state().is_empty()


func save_state(state: Dictionary) -> bool:
	var payload: Dictionary = state.duplicate(true)
	payload["version"] = SAVE_VERSION
	payload["saved_at"] = Time.get_datetime_string_from_system(false, true)
	var absolute_dir := ProjectSettings.globalize_path(save_path).get_base_dir()
	var dir_error := DirAccess.make_dir_recursive_absolute(absolute_dir)
	if dir_error != OK:
		push_error("[сохранение] не удалось создать каталог: %s" % error_string(dir_error))
		return false
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		push_error("[сохранение] не удалось открыть файл: %s" % error_string(FileAccess.get_open_error()))
		return false
	file.store_string(JSON.stringify(payload, "\t"))
	file.close()
	return true


func load_state() -> Dictionary:
	if not FileAccess.file_exists(save_path):
		return {}
	var file := FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		push_warning("[сохранение] файл недоступен: %s" % error_string(FileAccess.get_open_error()))
		return {}
	var text := file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(text) != OK or not json.data is Dictionary:
		push_warning("[сохранение] повреждённый файл проигнорирован")
		return {}
	var state: Dictionary = json.data
	var version := int(state.get("version", 0))
	if version != SAVE_VERSION:
		push_warning("[сохранение] неподдерживаемая версия %d" % version)
		return {}
	if not state.get("player", null) is Dictionary or not state.get("world", null) is Dictionary:
		push_warning("[сохранение] отсутствуют обязательные разделы")
		return {}
	return state


func capture_game(game: Node) -> Dictionary:
	if game == null or game.get("player") == null:
		return {}
	var player: Node = game.get("player")
	var pos: Vector2 = player.get("position")
	return {
		"player": {
			"x": pos.x, "y": pos.y,
			"hp": player.get("hp"), "food": player.get("food"),
			"water": player.get("water"), "rad": player.get("rad"),
			"mask": player.get("mask"),
		},
		"world": {"day": game.get("day"), "zoom": game.get("zoom_target")},
	}


func save_game(game: Node) -> bool:
	var state := capture_game(game)
	return not state.is_empty() and save_state(state)


func load_game(game: Node) -> bool:
	var state := load_state()
	if state.is_empty() or game == null or game.get("player") == null:
		return false
	var player: Node = game.get("player")
	var p: Dictionary = state.player
	player.set("position", Vector2(float(p.get("x", 0.0)), float(p.get("y", 0.0))))
	player.set("hp", clampf(float(p.get("hp", 100.0)), 0.0, 100.0))
	player.set("food", clampf(float(p.get("food", Core.FOOD_MAX)), 0.0, Core.FOOD_MAX))
	player.set("water", clampf(float(p.get("water", Core.WATER_MAX)), 0.0, Core.WATER_MAX))
	player.set("rad", maxf(0.0, float(p.get("rad", 0.0))))
	player.set("mask", bool(p.get("mask", true)))
	var world: Dictionary = state.world
	game.set("day", clampf(float(world.get("day", 0.8)), 0.0, 1.0))
	game.set("zoom_target", clampf(float(world.get("zoom", 1.6)), 0.5, 6.0))
	return true


func new_game(game: Node) -> void:
	if game == null or game.get("player") == null or game.get("terrain") == null:
		return
	var player: Node = game.get("player")
	var terrain: Node = game.get("terrain")
	player.set("position", terrain.get("spawn") - Vector2(0.0, 4.0))
	player.set("hp", 100.0)
	player.set("food", Core.FOOD_MAX)
	player.set("water", Core.WATER_MAX)
	player.set("rad", 0.0)
	player.set("mask", true)

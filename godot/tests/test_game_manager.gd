extends SceneTree

const TEST_SAVE := "user://cinematic_test_save.json"
var failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var script: Script = load("res://scripts/managers/game_manager.gd")
	if script == null:
		_fail("GameManager script must load")
		_finish()
		return
	var manager: Node = script.new()
	manager.set("save_path", TEST_SAVE)
	root.add_child(manager)
	_cleanup()
	_expect(not manager.call("has_save"), "missing save is reported as absent")
	var state := {
		"player": {"x": 128.5, "y": 42.25, "hp": 73.0, "food": 201.0, "water": 155.0, "rad": 4.0, "mask": false},
		"world": {"day": 0.35, "zoom": 1.8},
		"gameplay": {
			"inventory": {"selected": 2, "slots": [{"id": "bandage", "count": 3}]},
			"entities": {"opened_crates": ["start_left"]},
		},
	}
	_expect(manager.call("save_state", state), "valid state is written")
	var loaded: Dictionary = manager.call("load_state")
	_expect(is_equal_approx(float(loaded.player.x), 128.5), "position round-trips")
	_expect(loaded.player.mask == false, "boolean state round-trips")
	_expect(int(loaded.version) == 2, "current save schema is version 2")
	_expect(int(loaded.gameplay.inventory.selected) == 2, "gameplay state round-trips")

	# Версия 1 — сохранение уже опубликованной Godot-оболочки. После добавления
	# игрового цикла оно должно получить безопасные значения по умолчанию, а не
	# исчезнуть из меню «Продолжить».
	var legacy := {
		"version": 1,
		"player": {"x": 9.0, "y": 11.0, "hp": 90.0, "food": 220.0, "water": 210.0, "rad": 0.0, "mask": true},
		"world": {"day": 0.5, "zoom": 1.6, "terrain_changes": []},
	}
	var file := FileAccess.open(TEST_SAVE, FileAccess.WRITE)
	file.store_string(JSON.stringify(legacy))
	file.close()
	loaded = manager.call("load_state")
	_expect(int(loaded.get("version", 0)) == 2, "version 1 save migrates to version 2")
	_expect(loaded.get("gameplay", null) is Dictionary, "migration supplies gameplay section")
	_expect(loaded.gameplay.get("inventory", null) is Dictionary, "migration supplies inventory defaults")

	file = FileAccess.open(TEST_SAVE, FileAccess.WRITE)
	file.store_string("{ definitely broken")
	file.close()
	_expect(manager.call("load_state").is_empty(), "malformed saves are rejected")
	_cleanup()
	manager.queue_free()
	_finish()


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("[PASS] ", message)
	else:
		_fail(message)


func _fail(message: String) -> void:
	failures += 1
	printerr("[FAIL] ", message)


func _cleanup() -> void:
	if FileAccess.file_exists(TEST_SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))


func _finish() -> void:
	print("[tests] failures: ", failures)
	quit(failures)

extends SceneTree

var failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_check_script("res://scripts/managers/transition_manager.gd", ["fade_from_black", "fade_to_black"])
	_check_script("res://scripts/ui/main_menu.gd", ["show_start", "show_pause", "hide_menu"])
	_check_script("res://scripts/systems/dialog_manager.gd", ["show_dialogue", "is_open"])
	_check_script("res://scripts/interactions/interaction_beacon.gd", ["set_player", "interact"])
	print("[tests] failures: ", failures)
	quit(failures)


func _check_script(path: String, methods: Array[String]) -> void:
	var script: Script = load(path)
	if script == null:
		_fail("script loads: " + path)
		return
	var instance: Object = script.new()
	for method: String in methods:
		_expect(instance.has_method(method), "%s exposes %s" % [path.get_file(), method])
	instance.free()


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("[PASS] ", message)
	else:
		_fail(message)


func _fail(message: String) -> void:
	failures += 1
	printerr("[FAIL] ", message)

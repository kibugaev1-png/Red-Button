extends SceneTree

var failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var terrain := Terrain.new()
	root.add_child(terrain)
	terrain.build(1337)
	var cx := 3250
	var cy := int(terrain.surface[cx]) + 6
	var original := terrain.get_mat(cx, cy)
	terrain.set_mat(cx, cy, Core.AIR)
	_expect(terrain.get_mat(cx, cy) == Core.AIR, "world edit is applied")
	var changes := terrain.get_changes()
	_expect(changes.size() == 1, "world edit is recorded once")
	terrain.reset_changes()
	_expect(terrain.get_mat(cx, cy) == original, "new game restores original world cell")
	terrain.apply_changes(changes)
	_expect(terrain.get_mat(cx, cy) == Core.AIR, "continue reapplies saved world edit")
	terrain.queue_free()
	print("[tests] failures: ", failures)
	quit(failures)


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("[PASS] ", message)
	else:
		failures += 1
		printerr("[FAIL] ", message)

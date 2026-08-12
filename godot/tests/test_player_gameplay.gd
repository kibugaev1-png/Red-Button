extends SceneTree

var failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var player := Player.new()
	root.add_child(player)
	_expect(player.has_method("take_damage"), "player exposes damage API")
	_expect(player.has_method("heal"), "player exposes healing API")
	_expect(player.has_method("equip_mask"), "player exposes mask equipment API")
	_expect(player.has_method("unequip_mask"), "player exposes mask removal API")

	if player.has_method("take_damage"):
		player.hp = 50.0
		player.call("take_damage", 12.0)
		_expect(is_equal_approx(player.hp, 38.0), "damage reduces health")
	if player.has_method("heal"):
		player.hp = 38.0
		player.call("heal", 10.0)
		_expect(is_equal_approx(player.hp, 48.0), "healing is clamped and applied")
	if player.has_method("equip_mask") and player.has_method("unequip_mask"):
		player.mask = false
		player.call("equip_mask")
		_expect(player.mask, "mask can be equipped")
		player.call("unequip_mask")
		_expect(not player.mask, "mask can be removed")

	player.queue_free()
	print("[tests] failures: ", failures)
	quit(failures)


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("[PASS] ", message)
	else:
		failures += 1
		printerr("[FAIL] ", message)

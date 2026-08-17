extends SceneTree

const BULLET_PATH := "res://scripts/combat/bullet.gd"
const ENEMY_PATH := "res://scripts/combat/enemy.gd"

var failures: int = 0


class TestTerrain:
	extends Node

	var wall_x: float = 44.0

	func solid_at_px(x: float, _y: float) -> bool:
		return x >= wall_x and x < wall_x + 8.0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var bullet_script: Script = load(BULLET_PATH)
	_expect(bullet_script != null, "bullet script loads")
	if bullet_script == null:
		_finish()
		return
	_expect(bullet_script.can_instantiate(), "bullet script can instantiate")
	if not bullet_script.can_instantiate():
		_finish()
		return

	_test_setup_normalizes_direction(bullet_script)
	_test_segment_hit_damages_enemy_once(bullet_script)
	_test_range_and_lifetime_expiry(bullet_script)
	_test_terrain_segment_does_not_tunnel(bullet_script)
	_finish()


func _test_setup_normalizes_direction(bullet_script: Script) -> void:
	var shooter := Node2D.new()
	var bullet: Node2D = bullet_script.new()
	bullet.set("speed", 500.0)
	bullet.call("setup", Vector2(12.0, 34.0), Vector2(3.0, 4.0), 18.0, shooter)
	var velocity: Vector2 = bullet.get("velocity")
	_expect(bullet.position.is_equal_approx(Vector2(12.0, 34.0)), "setup places the bullet at its origin")
	_expect(velocity.is_equal_approx(Vector2(300.0, 400.0)), "setup normalizes direction before applying speed")
	_expect(is_equal_approx(float(bullet.get("damage")), 18.0), "setup stores non-negative damage")
	bullet.free()
	shooter.free()


func _test_segment_hit_damages_enemy_once(bullet_script: Script) -> void:
	var enemy_script: Script = load(ENEMY_PATH)
	var enemy: Node2D = enemy_script.new()
	enemy.position = Vector2(55.0, 24.0)
	root.add_child(enemy)
	var shooter := Node2D.new()
	root.add_child(shooter)
	var bullet: Node2D = bullet_script.new()
	bullet.set("speed", 1200.0)
	bullet.set("range", 300.0)
	bullet.set("lifetime", 2.0)
	root.add_child(bullet)
	bullet.call("setup", Vector2(0.0, 0.0), Vector2.RIGHT, 20.0, shooter)
	bullet.call("set_target", enemy)

	bullet.call("_physics_process", 0.1)
	_expect(is_equal_approx(float(enemy.get("hp")), 35.0), "a swept segment delivers damage when it crosses Enemy")
	_expect(bullet.is_queued_for_deletion(), "bullet expires immediately after a hit")
	bullet.call("_physics_process", 0.1)
	_expect(is_equal_approx(float(enemy.get("hp")), 35.0), "a spent bullet cannot damage the same target twice")
	enemy.queue_free()
	shooter.queue_free()


func _test_range_and_lifetime_expiry(bullet_script: Script) -> void:
	var shooter := Node2D.new()
	root.add_child(shooter)
	var ranged: Node2D = bullet_script.new()
	ranged.set("speed", 100.0)
	ranged.set("range", 30.0)
	ranged.set("lifetime", 5.0)
	root.add_child(ranged)
	ranged.call("setup", Vector2.ZERO, Vector2.RIGHT, 1.0, shooter)
	ranged.call("_physics_process", 0.2)
	_expect(not ranged.is_queued_for_deletion(), "bullet remains active before reaching maximum range")
	ranged.call("_physics_process", 0.2)
	_expect(ranged.is_queued_for_deletion(), "bullet expires at maximum range")
	_expect(is_equal_approx(ranged.position.x, 30.0), "range expiry clamps movement to the configured distance")

	var timed: Node2D = bullet_script.new()
	timed.set("speed", 100.0)
	timed.set("range", 500.0)
	timed.set("lifetime", 0.1)
	root.add_child(timed)
	timed.call("setup", Vector2.ZERO, Vector2.RIGHT, 1.0, shooter)
	timed.call("_physics_process", 0.2)
	_expect(timed.is_queued_for_deletion(), "bullet also expires when lifetime elapses")
	_expect(is_equal_approx(timed.position.x, 10.0), "lifetime clamps travel to time actually remaining")
	shooter.queue_free()


func _test_terrain_segment_does_not_tunnel(bullet_script: Script) -> void:
	var terrain := TestTerrain.new()
	root.add_child(terrain)
	var shooter := Node2D.new()
	root.add_child(shooter)
	var bullet: Node2D = bullet_script.new()
	bullet.set("speed", 1200.0)
	bullet.set("range", 300.0)
	bullet.set("lifetime", 2.0)
	root.add_child(bullet)
	bullet.call("setup", Vector2.ZERO, Vector2.RIGHT, 5.0, shooter)
	bullet.call("set_terrain", terrain)
	bullet.call("_physics_process", 0.1)
	_expect(bullet.is_queued_for_deletion(), "swept terrain check expires a fast bullet at a wall")
	_expect(bullet.position.x >= 44.0 and bullet.position.x < 52.0, "terrain collision stops inside the first solid cell")
	terrain.queue_free()
	shooter.queue_free()


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("[PASS] ", message)
	else:
		failures += 1
		printerr("[FAIL] ", message)


func _finish() -> void:
	print("[tests] failures: ", failures)
	quit(failures)

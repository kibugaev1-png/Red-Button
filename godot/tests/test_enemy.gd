extends SceneTree

const ENEMY_SCRIPT_PATH := "res://scripts/combat/enemy.gd"

var failures: int = 0
var attack_count: int = 0
var last_attack_damage: float = 0.0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var script: Script = load(ENEMY_SCRIPT_PATH)
	if script == null:
		_fail("Enemy script loads")
		_finish()
		return

	_test_damage_death_and_state_roundtrip(script)
	_test_melee_attack_respects_cooldown(script)
	_finish()


func _test_damage_death_and_state_roundtrip(script: Script) -> void:
	var enemy: Node2D = script.new()
	_expect(is_equal_approx(float(enemy.get("hp")), 55.0), "enemy starts with 55 hp")
	enemy.set("stable_id", "raider-17")
	enemy.position = Vector2(140.5, 260.25)
	enemy.call("damage", 20.0)
	_expect(is_equal_approx(float(enemy.get("hp")), 35.0), "damage reduces hp")
	enemy.set("state", 1)

	var snapshot: Dictionary = enemy.call("serialize_state")
	var restored: Node2D = script.new()
	restored.call("restore_state", snapshot)
	_expect(str(restored.get("stable_id")) == "raider-17", "stable id round-trips")
	_expect(is_equal_approx(float(restored.get("hp")), 35.0), "hp round-trips")
	_expect(restored.position.is_equal_approx(Vector2(140.5, 260.25)), "position round-trips")
	_expect(int(restored.get("state")) == 1, "fsm state round-trips")

	restored.call("damage", 1000.0)
	_expect(is_zero_approx(float(restored.get("hp"))), "lethal damage clamps hp to zero")
	_expect(int(restored.get("state")) == 3, "lethal damage enters DEAD")
	var malformed_alive := snapshot.duplicate(true)
	malformed_alive["hp"] = 20.0
	malformed_alive["state"] = 3
	var normalized: Node2D = script.new()
	normalized.call("restore_state", malformed_alive)
	_expect(int(normalized.get("state")) == 0, "positive hp cannot restore as permanently DEAD")
	enemy.free()
	restored.free()
	normalized.free()


func _test_melee_attack_respects_cooldown(script: Script) -> void:
	attack_count = 0
	last_attack_damage = 0.0
	var target := Node2D.new()
	target.position = Vector2(20.0, 0.0)
	var enemy: Node2D = script.new()
	enemy.set("melee_damage", 9.0)
	enemy.set("melee_cooldown", 0.75)
	enemy.set("attack_range", 40.0)
	enemy.call("set_target", target)
	enemy.connect("player_damage_requested", _on_player_damage_requested)

	enemy.call("_physics_process", 0.01)
	_expect(attack_count == 1, "enemy requests melee damage in ATTACK")
	_expect(is_equal_approx(last_attack_damage, 9.0), "attack signal carries melee damage")
	_expect(int(enemy.get("state")) == 2, "nearby target enters ATTACK")

	enemy.call("_physics_process", 0.20)
	_expect(attack_count == 1, "cooldown blocks an immediate second attack")
	enemy.call("_physics_process", 0.56)
	_expect(attack_count == 2, "enemy attacks again after cooldown")
	enemy.free()
	target.free()


func _on_player_damage_requested(amount: float) -> void:
	attack_count += 1
	last_attack_damage = amount


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("[PASS] ", message)
	else:
		_fail(message)


func _fail(message: String) -> void:
	failures += 1
	printerr("[FAIL] ", message)


func _finish() -> void:
	print("[tests] failures: ", failures)
	quit(failures)

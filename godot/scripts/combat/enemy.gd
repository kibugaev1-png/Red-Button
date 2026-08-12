class_name Enemy
extends Node2D

signal player_damage_requested(amount: float)
signal damaged(amount: float, remaining_hp: float)
signal died(stable_id: String)

enum State { IDLE, CHASE, ATTACK, DEAD }

const MAX_HP: float = 55.0
const BODY_WIDTH: float = 18.0
const BODY_HEIGHT: float = 44.0
const CELL_SIZE: float = 8.0
const GRAVITY: float = 900.0
const MAX_FALL_SPEED: float = 520.0

@export var stable_id: String = ""
@export var move_speed: float = 72.0
@export var detection_range: float = 420.0
@export var attack_range: float = 40.0
@export var melee_damage: float = 8.0
@export var melee_cooldown: float = 0.75

var hp: float = MAX_HP
var state: State = State.IDLE
var velocity: Vector2 = Vector2.ZERO

var _target: Node2D
var _terrain: Node
var _attack_cooldown_left: float = 0.0
var _facing: float = 1.0


func set_target(player: Node2D) -> void:
	_target = player


func set_terrain(terrain: Node) -> void:
	_terrain = terrain


func damage(amount: float) -> void:
	if amount <= 0.0 or state == State.DEAD:
		return
	hp = maxf(0.0, hp - amount)
	damaged.emit(amount, hp)
	if hp <= 0.0:
		_transition_to(State.DEAD)
	queue_redraw()


func serialize_state() -> Dictionary:
	return {
		"stable_id": stable_id,
		"hp": hp,
		"state": int(state),
		"position": {"x": position.x, "y": position.y},
		"facing": _facing,
		"attack_cooldown_left": _attack_cooldown_left,
	}


func restore_state(saved: Dictionary) -> void:
	stable_id = str(saved.get("stable_id", stable_id))
	hp = clampf(float(saved.get("hp", MAX_HP)), 0.0, MAX_HP)
	var saved_position: Variant = saved.get("position", {})
	if saved_position is Dictionary:
		position = Vector2(
			float(saved_position.get("x", position.x)),
			float(saved_position.get("y", position.y))
		)
	_facing = signf(float(saved.get("facing", _facing)))
	if is_zero_approx(_facing):
		_facing = 1.0
	_attack_cooldown_left = maxf(0.0, float(saved.get("attack_cooldown_left", 0.0)))
	var saved_state: int = clampi(int(saved.get("state", State.IDLE)), State.IDLE, State.DEAD)
	if hp <= 0.0:
		state = State.DEAD
	elif saved_state == State.DEAD:
		state = State.IDLE
	else:
		state = saved_state as State
	if state == State.DEAD:
		velocity = Vector2.ZERO
	queue_redraw()


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	_attack_cooldown_left = maxf(0.0, _attack_cooldown_left - delta)
	_update_state()

	match state:
		State.IDLE:
			velocity.x = 0.0
		State.CHASE:
			_chase_target()
		State.ATTACK:
			velocity.x = 0.0
			_try_melee_attack()
		State.DEAD:
			velocity = Vector2.ZERO
		_:
			_transition_to(State.IDLE)

	_move(delta)
	queue_redraw()


func _update_state() -> void:
	if not is_instance_valid(_target):
		_transition_to(State.IDLE)
		return
	var distance: float = global_position.distance_to(_target.global_position)
	if distance <= attack_range:
		_transition_to(State.ATTACK)
	elif distance <= detection_range:
		_transition_to(State.CHASE)
	else:
		_transition_to(State.IDLE)


func _transition_to(next_state: State) -> void:
	if state == next_state or state == State.DEAD:
		return
	state = next_state
	if state == State.DEAD:
		velocity = Vector2.ZERO
		died.emit(stable_id)


func _chase_target() -> void:
	if not is_instance_valid(_target):
		return
	var dx: float = _target.global_position.x - global_position.x
	if absf(dx) <= 1.0:
		velocity.x = 0.0
		return
	_facing = signf(dx)
	velocity.x = _facing * move_speed
	# Мир из клеток меняется во время игры, поэтому навмеш здесь не подходит.
	# Если прямо перед заражённым короткий уступ, пробуем тот же небольшой
	# автоподъём, что и игрок, — иначе он навсегда упирался даже в один блок.
	if _terrain and _terrain.has_method("is_solid_cell"):
		var ahead := position + Vector2(_facing * (BODY_WIDTH * 0.5 + 2.0), -2.0)
		var cx := int(floor(ahead.x / CELL_SIZE))
		var foot_y := int(floor(ahead.y / CELL_SIZE))
		if bool(_terrain.call("is_solid_cell", cx, foot_y)) and not bool(_terrain.call("is_solid_cell", cx, foot_y - 1)):
			position.y -= CELL_SIZE


func _try_melee_attack() -> void:
	if _attack_cooldown_left > 0.0:
		return
	_attack_cooldown_left = maxf(0.0, melee_cooldown)
	player_damage_requested.emit(maxf(0.0, melee_damage))


func _move(delta: float) -> void:
	if not is_instance_valid(_terrain) or not _terrain.has_method("is_solid_cell"):
		position += velocity * delta
		return

	velocity.y = minf(velocity.y + GRAVITY * delta, MAX_FALL_SPEED)
	_move_axis(Vector2(velocity.x * delta, 0.0))
	_move_axis(Vector2(0.0, velocity.y * delta))


func _move_axis(offset: Vector2) -> void:
	var remaining: float = offset.length()
	if remaining <= 0.0:
		return
	var direction: Vector2 = offset / remaining
	while remaining > 0.0:
		var step_size: float = minf(1.0, remaining)
		var candidate: Vector2 = position + direction * step_size
		if _hits_terrain(candidate):
			if not is_zero_approx(direction.x):
				velocity.x = 0.0
			if not is_zero_approx(direction.y):
				velocity.y = 0.0
			return
		position = candidate
		remaining -= step_size


func _hits_terrain(at: Vector2) -> bool:
	var x0: int = int(floor((at.x - BODY_WIDTH * 0.5) / CELL_SIZE))
	var x1: int = int(floor((at.x + BODY_WIDTH * 0.5 - 1.0) / CELL_SIZE))
	var y0: int = int(floor((at.y - BODY_HEIGHT) / CELL_SIZE))
	var y1: int = int(floor((at.y - 1.0) / CELL_SIZE))
	for cy: int in range(y0, y1 + 1):
		for cx: int in range(x0, x1 + 1):
			if bool(_terrain.call("is_solid_cell", cx, cy)):
				return true
	return false


func _draw() -> void:
	if state == State.DEAD:
		_draw_dead()
		return

	var pulse: float = 0.82 + sin(Time.get_ticks_msec() * 0.006) * 0.08
	var body_color := Color(0.40 * pulse, 0.12 * pulse, 0.10 * pulse)
	var dark := Color(0.12, 0.07, 0.065)
	var metal := Color(0.47, 0.45, 0.40)
	var eye := Color(1.0, 0.20, 0.10)
	var f: float = _facing

	draw_set_transform(Vector2(0.0, -1.0), 0.0, Vector2(1.0, 0.25))
	draw_circle(Vector2.ZERO, 12.0, Color(0.0, 0.0, 0.0, 0.32))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-8.0, -7.0), Vector2(-7.0, -31.0), Vector2(-4.0, -39.0),
		Vector2(5.0, -39.0), Vector2(8.0, -28.0), Vector2(7.0, -7.0),
	]), body_color)
	draw_line(Vector2(-6.0, -28.0), Vector2(7.0, -25.0), dark, 3.0, true)
	draw_circle(Vector2(0.0, -43.0), 7.5, dark)
	draw_circle(Vector2(2.6 * f, -44.0), 3.7, metal)
	draw_circle(Vector2(3.4 * f, -44.0), 1.6, eye)
	draw_line(Vector2(-4.0, -6.0), Vector2(-6.0, 0.0), dark, 4.0, true)
	draw_line(Vector2(4.0, -6.0), Vector2(7.0, 0.0), dark, 4.0, true)
	draw_line(Vector2(5.0 * f, -29.0), Vector2(12.0 * f, -19.0), metal, 3.0, true)


func _draw_dead() -> void:
	draw_set_transform(Vector2(0.0, -2.0), 0.0, Vector2(1.0, 0.28))
	draw_circle(Vector2.ZERO, 17.0, Color(0.0, 0.0, 0.0, 0.38))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-19.0, -7.0), Vector2(-12.0, -13.0), Vector2(12.0, -12.0),
		Vector2(19.0, -6.0), Vector2(13.0, -2.0), Vector2(-15.0, -2.0),
	]), Color(0.19, 0.09, 0.08))
	draw_line(Vector2(-7.0, -10.0), Vector2(7.0, -4.0), Color(0.08, 0.05, 0.05), 2.0)

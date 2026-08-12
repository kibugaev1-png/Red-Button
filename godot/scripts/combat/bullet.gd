class_name Bullet
extends Node2D

signal hit_requested(target: Node, damage: float)

const TARGET_HALF_WIDTH: float = 10.0
const TARGET_HEIGHT: float = 48.0
const TERRAIN_SAMPLE_STEP: float = 4.0

@export var speed: float = 1200.0
@export var range: float = 900.0
@export var lifetime: float = 1.2
@export var tracer_length: float = 18.0

var velocity: Vector2 = Vector2.ZERO
var damage: float = 0.0
var owner_node: Node

var _target: Node2D
var _terrain: Node
var _distance_travelled: float = 0.0
var _time_left: float = 0.0
var _spent: bool = false


func setup(origin: Vector2, direction: Vector2, damage_amount: float, owner: Node) -> void:
	position = origin
	owner_node = owner
	damage = maxf(0.0, damage_amount)
	var normalized_direction := direction.normalized()
	if normalized_direction.is_zero_approx():
		normalized_direction = Vector2.RIGHT
	velocity = normalized_direction * maxf(0.0, speed)
	_distance_travelled = 0.0
	_time_left = maxf(0.0, lifetime)
	_spent = false
	rotation = normalized_direction.angle()
	queue_redraw()


func set_target(target: Node2D) -> void:
	_target = target


func set_terrain(terrain: Node) -> void:
	_terrain = terrain


func _physics_process(delta: float) -> void:
	if _spent or delta <= 0.0:
		return
	var remaining_range := maxf(0.0, range - _distance_travelled)
	var active_time := minf(delta, _time_left)
	var travel_distance := minf(velocity.length() * active_time, remaining_range)
	var from := global_position
	var to := from + velocity.normalized() * travel_distance if travel_distance > 0.0 else from

	var target_hit := _segment_target_hit(from, to)
	var terrain_hit := _segment_terrain_hit(from, to)
	var hit_point: Vector2
	var has_target_hit := not target_hit.is_empty()
	var has_terrain_hit := not terrain_hit.is_empty()
	if has_target_hit and (not has_terrain_hit or float(target_hit.t) <= float(terrain_hit.t)):
		hit_point = target_hit.point
		global_position = hit_point
		_distance_travelled += from.distance_to(hit_point)
		_deliver_damage(_target)
		_expire()
		return
	if has_terrain_hit:
		hit_point = terrain_hit.point
		global_position = hit_point
		_distance_travelled += from.distance_to(hit_point)
		_expire()
		return

	global_position = to
	_distance_travelled += travel_distance
	_time_left = maxf(0.0, _time_left - delta)
	if _distance_travelled >= range or _time_left <= 0.0:
		_expire()


func _segment_target_hit(from: Vector2, to: Vector2) -> Dictionary:
	if not is_instance_valid(_target) or _target == owner_node or _target.is_queued_for_deletion():
		return {}
	var target_rect := Rect2(
		_target.global_position - Vector2(TARGET_HALF_WIDTH, TARGET_HEIGHT),
		Vector2(TARGET_HALF_WIDTH * 2.0, TARGET_HEIGHT)
	)
	var t := _segment_rect_hit_time(from, to, target_rect)
	if t < 0.0:
		return {}
	var closest := from.lerp(to, t)
	return {"point": closest, "t": t}


func _segment_rect_hit_time(from: Vector2, to: Vector2, rect: Rect2) -> float:
	var delta := to - from
	var t_enter := 0.0
	var t_exit := 1.0
	for axis in 2:
		var origin := from[axis]
		var step := delta[axis]
		var edge_min := rect.position[axis]
		var edge_max := rect.end[axis]
		if is_zero_approx(step):
			if origin < edge_min or origin > edge_max:
				return -1.0
			continue
		var near_time := (edge_min - origin) / step
		var far_time := (edge_max - origin) / step
		if near_time > far_time:
			var swap := near_time
			near_time = far_time
			far_time = swap
		t_enter = maxf(t_enter, near_time)
		t_exit = minf(t_exit, far_time)
		if t_enter > t_exit:
			return -1.0
	return t_enter


func _segment_terrain_hit(from: Vector2, to: Vector2) -> Dictionary:
	if not is_instance_valid(_terrain) or not _terrain.has_method("solid_at_px"):
		return {}
	var length := from.distance_to(to)
	if length <= 0.0:
		return {}
	var steps := maxi(1, ceili(length / TERRAIN_SAMPLE_STEP))
	for index in range(1, steps + 1):
		var t := float(index) / float(steps)
		var point := from.lerp(to, t)
		if bool(_terrain.call("solid_at_px", point.x, point.y)):
			return {"point": point, "t": t}
	return {}


func _deliver_damage(target: Node) -> void:
	if damage <= 0.0 or not is_instance_valid(target):
		return
	if target.has_method("damage"):
		target.call("damage", damage)
	elif target.has_method("take_damage"):
		target.call("take_damage", damage)
	else:
		hit_requested.emit(target, damage)


func _expire() -> void:
	if _spent:
		return
	_spent = true
	set_physics_process(false)
	queue_free()


func _draw() -> void:
	var tail := Vector2(-tracer_length, 0.0)
	draw_line(tail, Vector2.ZERO, Color(1.0, 0.74, 0.28, 0.22), 5.0, true)
	draw_line(tail * 0.8, Vector2.ZERO, Color(1.0, 0.9, 0.62, 0.92), 1.6, true)
	draw_circle(Vector2.ZERO, 1.8, Color(1.0, 0.97, 0.82))

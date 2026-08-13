# projectile.gd — обобщение bullet.gd.
#
# Пуля умела лететь в одну цель, переданную через set_target. Снаряд ищет
# попадание среди ВСЕХ живых целей: иначе стрела мародёра не могла бы попасть в
# зомби, а стая, приведённая на лагерь, не подралась бы с его хозяевами.
#
# Здесь же гравитация: стрела летит по дуге, пуля — по прямой, и это одна и та
# же дуга с нулевым ускорением.
class_name Projectile
extends Node2D

signal hit_target(target: Node, damage: float, projectile: Node)
signal hit_terrain(point: Vector2, projectile: Node)
signal expired(projectile: Node)
# Промахнувшаяся стрела торчит из земли и подбирается обратно.
signal pickup_dropped(item_id: StringName, at: Vector2)

const TARGET_HALF_WIDTH: float = 10.0
const TARGET_HEIGHT: float = 48.0
const TERRAIN_SAMPLE_STEP: float = 4.0

@export var speed: float = 1200.0
@export var max_range: float = 900.0
@export var lifetime: float = 3.0
@export var gravity: float = 0.0
@export var tracer_length: float = 18.0

var kind: StringName = &"bullet"
var damage: float = 0.0
var shooter: Node = null
var shooter_faction: StringName = &""
var pickup_item: StringName = &""
var velocity: Vector2 = Vector2.ZERO
var spent: bool = false
# Снаряды из пула не удаляют себя: их забирает пул и выдаёт заново.
var pooled: bool = false

var _targets: Array[Node] = []
var _terrain: Node
var _distance_travelled: float = 0.0
var _time_left: float = 0.0


# config — то, что отдаёт WeaponCatalog.projectile_config, плюс любые правки.
func setup(origin: Vector2, direction: Vector2, config: Dictionary, from_shooter: Node = null) -> void:
	position = origin
	shooter = from_shooter
	shooter_faction = StringName(config.get("faction", faction_of(from_shooter)))
	kind = StringName(config.get("kind", &"bullet"))
	damage = maxf(0.0, float(config.get("damage", 0.0)))
	speed = maxf(1.0, float(config.get("speed", speed)))
	gravity = maxf(0.0, float(config.get("gravity", gravity)))
	max_range = maxf(0.0, float(config.get("range", max_range)))
	lifetime = maxf(0.0, float(config.get("lifetime", lifetime)))
	pickup_item = StringName(config.get("pickup", &""))
	var normalized := direction.normalized()
	if normalized.is_zero_approx():
		normalized = Vector2.RIGHT
	velocity = normalized * speed
	_distance_travelled = 0.0
	_time_left = lifetime
	spent = false
	rotation = normalized.angle()
	set_physics_process(true)
	queue_redraw()


func set_targets(targets: Array) -> void:
	_targets.clear()
	for target: Variant in targets:
		if target is Node:
			_targets.append(target as Node)


func add_target(target: Node) -> void:
	if target != null and not _targets.has(target):
		_targets.append(target)


func set_terrain(terrain: Node) -> void:
	_terrain = terrain


# Кто чей: у актёров есть поле faction, у игрока его нет — он сам по себе.
static func faction_of(node: Node) -> StringName:
	if node == null or not is_instance_valid(node):
		return &""
	var value: Variant = node.get("faction")
	if value != null and String(value) != "":
		return StringName(value)
	return &"player"


static func is_alive(node: Node) -> bool:
	if node == null or not is_instance_valid(node) or node.is_queued_for_deletion():
		return false
	var hp: Variant = node.get("hp")
	if hp != null and float(hp) <= 0.0:
		return false
	return true


func _physics_process(delta: float) -> void:
	if spent or delta <= 0.0:
		return
	# Дуга считается тем же шагом, что и полёт: сначала ускорение, потом отрезок.
	velocity.y += gravity * delta
	if not velocity.is_zero_approx():
		rotation = velocity.angle()
	var remaining_range := maxf(0.0, max_range - _distance_travelled)
	var active_time := minf(delta, _time_left)
	var travel := minf(velocity.length() * active_time, remaining_range)
	var from := global_position
	var to := from + velocity.normalized() * travel if travel > 0.0 else from

	var target_hit := _segment_target_hit(from, to)
	var terrain_hit := _segment_terrain_hit(from, to)
	var has_target := not target_hit.is_empty()
	var has_terrain := not terrain_hit.is_empty()
	if has_target and (not has_terrain or float(target_hit.t) <= float(terrain_hit.t)):
		global_position = target_hit.point
		_distance_travelled += from.distance_to(target_hit.point)
		_deliver_damage(target_hit.target as Node)
		_expire(false)
		return
	if has_terrain:
		global_position = terrain_hit.point
		_distance_travelled += from.distance_to(terrain_hit.point)
		hit_terrain.emit(terrain_hit.point as Vector2, self)
		_expire(true)
		return

	global_position = to
	_distance_travelled += travel
	_time_left = maxf(0.0, _time_left - delta)
	if _distance_travelled >= max_range or _time_left <= 0.0:
		_expire(true)


# Попадание ищется среди всех целей, ближайшее по времени выигрывает.
func _segment_target_hit(from: Vector2, to: Vector2) -> Dictionary:
	var best: Dictionary = {}
	for target: Node in _targets:
		if not _is_hostile(target):
			continue
		var node := target as Node2D
		if node == null:
			continue
		var rect := Rect2(
			node.global_position - Vector2(TARGET_HALF_WIDTH, TARGET_HEIGHT),
			Vector2(TARGET_HALF_WIDTH * 2.0, TARGET_HEIGHT)
		)
		var t := _segment_rect_hit_time(from, to, rect)
		if t < 0.0:
			continue
		if best.is_empty() or t < float(best.t):
			best = {"target": target, "t": t, "point": from.lerp(to, t)}
	return best


func _is_hostile(target: Node) -> bool:
	if not is_alive(target) or target == shooter:
		return false
	# Свои не стреляют в своих: зомби не разбирают стаю, мародёры — лагерь.
	var other := faction_of(target)
	return other.is_empty() or shooter_faction.is_empty() or other != shooter_faction


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


# Стрелявший мог умереть, пока летело. Урон всё равно доходит — просто некому
# его записать.
func _deliver_damage(target: Node) -> void:
	if damage <= 0.0 or not is_instance_valid(target):
		return
	hit_target.emit(target, damage, self)
	if target.has_method("damage"):
		target.call("damage", damage)
	elif target.has_method("take_damage"):
		target.call("take_damage", damage)


func _expire(drop_pickup: bool) -> void:
	if spent:
		return
	spent = true
	set_physics_process(false)
	if drop_pickup and not pickup_item.is_empty():
		pickup_dropped.emit(pickup_item, global_position)
	expired.emit(self)
	if not pooled:
		queue_free()


func _draw() -> void:
	if kind == &"arrow":
		draw_line(Vector2(-16.0, 0.0), Vector2(6.0, 0.0), Color(0.42, 0.31, 0.19), 1.8, true)
		draw_colored_polygon(PackedVector2Array([
			Vector2(9.0, 0.0), Vector2(2.0, -2.4), Vector2(2.0, 2.4),
		]), Color(0.72, 0.72, 0.68))
		draw_line(Vector2(-16.0, 0.0), Vector2(-11.0, -3.0), Color(0.78, 0.76, 0.7, 0.85), 1.2, true)
		draw_line(Vector2(-16.0, 0.0), Vector2(-11.0, 3.0), Color(0.78, 0.76, 0.7, 0.85), 1.2, true)
		return
	var tail := Vector2(-tracer_length, 0.0)
	draw_line(tail, Vector2.ZERO, Color(1.0, 0.74, 0.28, 0.22), 5.0, true)
	draw_line(tail * 0.8, Vector2.ZERO, Color(1.0, 0.9, 0.62, 0.92), 1.6, true)
	draw_circle(Vector2.ZERO, 1.8, Color(1.0, 0.97, 0.82))

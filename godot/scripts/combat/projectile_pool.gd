# projectile_pool.gd — переиспользование снарядов.
#
# Дробовик мародёра — пять дробин за выстрел, а мародёров может быть десяток.
# Создавать и удалять узлы в таком темпе дороже, чем держать их наготове:
# отработавший снаряд гасится и возвращается в пул, а не уходит в queue_free.
class_name ProjectilePool
extends Node

signal projectile_hit_target(target: Node, damage: float, projectile: Node)
signal projectile_hit_terrain(point: Vector2, projectile: Node)
signal projectile_pickup_dropped(item_id: StringName, at: Vector2)

const PROJECTILE_SCRIPT := preload("res://scripts/combat/projectile.gd")
const DEFAULT_CAPACITY: int = 64

var capacity: int = DEFAULT_CAPACITY

var _idle: Array[Node2D] = []
var _active: Array[Node2D] = []
var _host: Node
var _terrain: Node
var _created: int = 0


func set_host(host: Node) -> void:
	_host = host


func set_terrain(terrain: Node) -> void:
	_terrain = terrain


func active_count() -> int:
	_prune()
	return _active.size()


func idle_count() -> int:
	return _idle.size()


func created_count() -> int:
	return _created


# Выдаёт снаряд: сначала из отложенных, и только потом создаёт новый.
func acquire() -> Node2D:
	_prune()
	var projectile: Node2D = null
	while not _idle.is_empty() and projectile == null:
		var candidate: Node2D = _idle.pop_back()
		if is_instance_valid(candidate):
			projectile = candidate
	if projectile == null:
		if _active.size() >= capacity:
			return null
		projectile = _create()
	projectile.visible = true
	_active.append(projectile)
	return projectile


func spawn(
	origin: Vector2,
	direction: Vector2,
	config: Dictionary,
	shooter: Node,
	targets: Array = []
) -> Node2D:
	var projectile := acquire()
	if projectile == null:
		return null
	projectile.call("set_terrain", _terrain)
	projectile.call("set_targets", targets)
	projectile.call("setup", origin, direction, config, shooter)
	return projectile


func release(projectile: Node2D) -> void:
	if projectile == null or not is_instance_valid(projectile):
		return
	_active.erase(projectile)
	if _idle.has(projectile):
		return
	projectile.set("spent", true)
	projectile.set_physics_process(false)
	projectile.visible = false
	_idle.append(projectile)


func clear() -> void:
	for projectile: Node2D in _active:
		if is_instance_valid(projectile):
			release(projectile)


func _create() -> Node2D:
	var projectile: Node2D = PROJECTILE_SCRIPT.new()
	projectile.set("pooled", true)
	projectile.set_physics_process(false)
	projectile.connect("expired", _on_expired)
	projectile.connect("hit_target", _on_hit_target)
	projectile.connect("hit_terrain", _on_hit_terrain)
	projectile.connect("pickup_dropped", _on_pickup_dropped)
	var parent: Node = _host if is_instance_valid(_host) else self
	parent.add_child(projectile)
	_created += 1
	return projectile


func _prune() -> void:
	for index in range(_active.size() - 1, -1, -1):
		if not is_instance_valid(_active[index]):
			_active.remove_at(index)
	for index in range(_idle.size() - 1, -1, -1):
		if not is_instance_valid(_idle[index]):
			_idle.remove_at(index)


func _on_expired(projectile: Node) -> void:
	release(projectile as Node2D)


func _on_hit_target(target: Node, damage: float, projectile: Node) -> void:
	projectile_hit_target.emit(target, damage, projectile)


func _on_hit_terrain(point: Vector2, projectile: Node) -> void:
	projectile_hit_terrain.emit(point, projectile)


func _on_pickup_dropped(item_id: StringName, at: Vector2) -> void:
	projectile_pickup_dropped.emit(item_id, at)

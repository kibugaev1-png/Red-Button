class_name InteractionBeacon
extends Area2D

signal interacted
signal proximity_changed(nearby: bool, prompt: String)

@export var activation_distance: float = 95.0
var _player: Node2D
var _nearby: bool = false
var _pulse: float = 0.0


func _ready() -> void:
	name = "EmergencyBeacon"
	z_index = 9
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = activation_distance
	shape.shape = circle
	add_child(shape)
	queue_redraw()


func set_player(player: Node2D) -> void:
	_player = player


func interact() -> void:
	if _nearby:
		interacted.emit()


func is_nearby() -> bool:
	return _nearby


func _process(delta: float) -> void:
	_pulse += delta
	queue_redraw()
	if _player == null:
		return
	var near_now := global_position.distance_to(_player.global_position + Vector2(0, -25)) <= activation_distance
	if near_now == _nearby:
		return
	_nearby = near_now
	proximity_changed.emit(_nearby, "E  СЛУШАТЬ СИГНАЛ" if _nearby else "")


func _draw() -> void:
	var glow := 0.5 + sin(_pulse * 2.2) * 0.18
	draw_circle(Vector2(0, -23), 18.0 + glow * 5.0, Color(0.72, 0.08, 0.055, 0.07 + glow * 0.05))
	draw_rect(Rect2(-7, -31, 14, 29), Color(0.13, 0.12, 0.11))
	draw_rect(Rect2(-5, -29, 10, 20), Color(0.25, 0.23, 0.2))
	draw_circle(Vector2(0, -23), 3.2, Color(1.0, 0.12, 0.08, 0.65 + glow * 0.3))
	draw_line(Vector2(0, -31), Vector2(0, -47), Color(0.28, 0.27, 0.24), 2.0)
	draw_line(Vector2(-8, -1), Vector2(8, -1), Color(0.16, 0.14, 0.12), 3.0)

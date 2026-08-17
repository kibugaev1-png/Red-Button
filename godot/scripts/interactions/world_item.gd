class_name WorldItem
extends "res://scripts/interactions/world_interactable.gd"

signal pickup_requested(item: WorldItem)

@export var item_id: String = ""
@export var display_name: String = "Предмет":
	set(value):
		display_name = value
@export_range(1, 999, 1, "or_greater") var count: int = 1

var collected: bool = false
var _pulse: float = 0.0


func _ready() -> void:
	z_index = 8
	_apply_visual_state()


func _process(delta: float) -> void:
	if collected:
		return
	_pulse += delta
	queue_redraw()


func get_interaction_prompt(_actor: Node2D) -> String:
	var suffix := " ×%d" % count if count > 1 else ""
	return "E  ВЗЯТЬ: %s%s" % [display_name, suffix]


func is_interaction_available(_actor: Node2D) -> bool:
	return not stable_id.is_empty() and not item_id.is_empty() and not collected and count > 0


func interact(actor: Node2D) -> bool:
	if not is_interaction_available(actor):
		return false
	pickup_requested.emit(self)
	return true


func collect(amount: int) -> int:
	if collected or amount <= 0:
		return 0
	var taken := mini(amount, count)
	count -= taken
	if count <= 0:
		count = 0
		collected = true
	_apply_visual_state()
	return taken


func serialize_state() -> Dictionary:
	return {
		"stable_id": stable_id,
		"item_id": item_id,
		"count": count,
		"collected": collected,
	}


func restore_state(state: Dictionary) -> bool:
	if not _state_matches(state):
		return false
	var saved_item_id := String(state.get("item_id", item_id))
	if not item_id.is_empty() and saved_item_id != item_id:
		return false
	count = maxi(0, int(state.get("count", count)))
	collected = bool(state.get("collected", count <= 0)) or count <= 0
	if collected:
		count = 0
	_apply_visual_state()
	return true


func _apply_visual_state() -> void:
	visible = not collected
	set_process(not collected)
	queue_redraw()


func _draw() -> void:
	if collected:
		return
	var breathe := 0.5 + 0.5 * sin(_pulse * 2.4)
	var lift := sin(_pulse * 1.7) * 1.4
	draw_set_transform(Vector2(0.0, lift))
	draw_circle(Vector2(0.0, 1.5), 14.0 + breathe * 2.0, Color(0.82, 0.72, 0.42, 0.035 + breathe * 0.025))
	draw_set_transform(Vector2(0.0, 2.0), 0.0, Vector2(1.0, 0.28))
	draw_circle(Vector2.ZERO, 10.5, Color(0.025, 0.02, 0.015, 0.34))
	draw_set_transform(Vector2(0.0, lift))
	if item_id == "gasmask":
		_draw_gasmask()
	else:
		_draw_bundle()
	draw_set_transform(Vector2.ZERO)


# ПРОТИВОГАЗ, ЛЕЖАЩИЙ НА ЗЕМЛЕ.
#
# Раньше он был 18 пикселей высотой — крупнее головы самого героя (11), стоял
# вертикально и смотрел единственным круглым стеклом прямо в камеру. Получался
# не предмет, а циклоп, уставившийся на игрока.
#
# Теперь это вещь: вдвое меньше, брошена набок с наклоном, стёкол два — те же,
# что у героя на лице, — а фильтр смотрит в сторону. Сразу читается, что на
# земле лежит снаряжение, которое надо подобрать.
func _draw_gasmask() -> void:
	var rubber := Color(0.19, 0.21, 0.18)
	var rubber_dark := Color(0.095, 0.105, 0.09)
	var glass := Color(0.39, 0.52, 0.48)

	# наклон: маска валяется, а не стоит по стойке смирно
	draw_set_transform(Vector2(0.0, -1.0), 0.34, Vector2.ONE)

	# корпус маски
	draw_colored_polygon(PackedVector2Array([
		Vector2(-4.6, -7.4), Vector2(-1.4, -9.4), Vector2(3.0, -8.8),
		Vector2(5.2, -5.4), Vector2(4.6, -1.4), Vector2(1.6, 0.6),
		Vector2(-2.4, 0.2), Vector2(-5.0, -3.2),
	]), rubber)

	# дальнее стекло — частично за переносицей
	draw_circle(Vector2(-1.1, -5.6), 1.7, rubber_dark)
	draw_circle(Vector2(-1.1, -5.6), 1.25, glass * Color(0.8, 0.8, 0.8, 1.0))
	# переносица
	draw_line(Vector2(0.4, -7.0), Vector2(0.7, -3.8), rubber_dark, 1.3, true)
	# ближнее стекло
	draw_circle(Vector2(2.4, -5.2), 2.3, rubber_dark)
	draw_circle(Vector2(2.4, -5.2), 1.75, glass)
	draw_circle(Vector2(1.7, -5.9), 0.6, Color(0.92, 0.96, 0.9, 0.65))
	draw_arc(Vector2(2.4, -5.2), 2.3, 0.0, TAU, 16, Color(0.07, 0.08, 0.07), 0.8, true)

	# фильтр-коробка сбоку, а не под глазом
	draw_rect(Rect2(1.2, -2.4, 4.4, 3.6), Color(0.14, 0.16, 0.135))
	for y in [-1.4, 0.0]:
		draw_line(Vector2(1.6, y), Vector2(5.2, y), Color(0.07, 0.08, 0.07), 0.7, true)

	# обвисшие ремни
	draw_line(Vector2(-4.2, -6.6), Vector2(-7.6, -8.0), rubber_dark, 1.4, true)
	draw_line(Vector2(-4.6, -3.4), Vector2(-8.0, -2.2), rubber_dark, 1.2, true)
	draw_line(Vector2(-3.0, -8.4), Vector2(0.6, -9.0), Color(0.82, 0.7, 0.42, 0.4), 0.8, true)

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_bundle() -> void:
	draw_colored_polygon(PackedVector2Array([
		Vector2(-9.0, -12.0), Vector2(7.0, -14.0), Vector2(10.0, -3.0),
		Vector2(4.0, 1.0), Vector2(-8.0, -1.0),
	]), Color(0.35, 0.31, 0.24))
	draw_line(Vector2(-8.0, -8.0), Vector2(8.0, -10.0), Color(0.68, 0.55, 0.32), 2.0, true)
	draw_line(Vector2(-2.0, -13.0), Vector2(1.0, 0.0), Color(0.14, 0.12, 0.1), 1.4, true)

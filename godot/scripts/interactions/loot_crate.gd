class_name LootCrate
extends "res://scripts/interactions/world_interactable.gd"

signal loot_requested(crate: LootCrate, loot: Array[Dictionary])

@export var display_name: String = "ящик"
@export var military: bool = false
@export var loot: Array[Dictionary] = []

var opened: bool = false
var _pulse: float = 0.0


func _ready() -> void:
	z_index = 7
	queue_redraw()


func _process(delta: float) -> void:
	_pulse += delta
	if not opened:
		queue_redraw()


func get_interaction_prompt(_actor: Node2D) -> String:
	return "E  ВСКРЫТЬ: %s" % display_name.to_upper()


func is_interaction_available(_actor: Node2D) -> bool:
	return not stable_id.is_empty() and not opened


func interact(actor: Node2D) -> bool:
	if not is_interaction_available(actor):
		return false
	opened = true
	queue_redraw()
	loot_requested.emit(self, _copy_loot())
	return true


func serialize_state() -> Dictionary:
	return {
		"stable_id": stable_id,
		"opened": opened,
	}


func restore_state(state: Dictionary) -> bool:
	if not _state_matches(state):
		return false
	opened = bool(state.get("opened", false))
	queue_redraw()
	return true


func _copy_loot() -> Array[Dictionary]:
	var copy: Array[Dictionary] = []
	for entry: Dictionary in loot:
		copy.append(entry.duplicate(true))
	return copy


func _draw() -> void:
	var body := Color(0.26, 0.29, 0.22) if military else Color(0.39, 0.27, 0.15)
	var edge := Color(0.12, 0.14, 0.105) if military else Color(0.21, 0.135, 0.07)
	var metal := Color(0.49, 0.48, 0.39) if military else Color(0.39, 0.34, 0.25)

	draw_set_transform(Vector2(0.0, 1.0), 0.0, Vector2(1.0, 0.28))
	draw_circle(Vector2.ZERO, 18.0, Color(0.025, 0.02, 0.015, 0.42))
	draw_set_transform(Vector2.ZERO)

	# Скошенные углы дают ящику объём без растровой текстуры.
	draw_colored_polygon(PackedVector2Array([
		Vector2(-18.0, -15.0), Vector2(-14.0, -19.0), Vector2(14.0, -19.0),
		Vector2(18.0, -15.0), Vector2(18.0, 0.0), Vector2(14.0, 4.0),
		Vector2(-14.0, 4.0), Vector2(-18.0, 0.0),
	]), body.darkened(0.08) if opened else body)
	draw_line(Vector2(-17.0, -7.0), Vector2(17.0, -7.0), edge, 2.0, true)
	draw_line(Vector2(-13.0, -18.0), Vector2(-13.0, 3.0), edge, 3.0, true)
	draw_line(Vector2(13.0, -18.0), Vector2(13.0, 3.0), edge, 3.0, true)
	draw_rect(Rect2(-3.0, -9.0, 6.0, 5.0), metal)

	if opened:
		draw_colored_polygon(PackedVector2Array([
			Vector2(-16.0, -18.0), Vector2(-12.0, -29.0), Vector2(13.0, -29.0),
			Vector2(17.0, -18.0),
		]), body.darkened(0.18))
		draw_line(Vector2(-12.0, -28.0), Vector2(13.0, -28.0), body.lightened(0.14), 1.2, true)
		return

	draw_colored_polygon(PackedVector2Array([
		Vector2(-18.0, -15.0), Vector2(-14.0, -20.0), Vector2(14.0, -20.0),
		Vector2(18.0, -15.0),
	]), body.lightened(0.08))
	if military:
		draw_string(ThemeDB.fallback_font, Vector2(-8.5, -10.0), "ARMY", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 6, Color(0.72, 0.68, 0.42))
	var glow := 0.18 + (0.5 + 0.5 * sin(_pulse * 2.6)) * 0.22
	draw_polyline(PackedVector2Array([
		Vector2(-18.5, -14.0), Vector2(-14.0, -20.5), Vector2(14.0, -20.5),
		Vector2(18.5, -14.0), Vector2(18.5, 0.0), Vector2(14.0, 4.5),
		Vector2(-14.0, 4.5), Vector2(-18.5, 0.0), Vector2(-18.5, -14.0),
	]), Color(0.88, 0.78, 0.48, glow), 1.0, true)

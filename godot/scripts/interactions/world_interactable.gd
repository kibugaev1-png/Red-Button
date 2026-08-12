class_name WorldInteractable
extends Node2D

@export var stable_id: String = ""
@export_range(0.0, 512.0, 1.0, "or_greater") var interaction_range: float = 92.0
@export var interaction_priority: int = 0
@export var interaction_offset: Vector2 = Vector2(0.0, -20.0)


func get_interaction_position() -> Vector2:
	return global_transform * interaction_offset


func get_interaction_range() -> float:
	return maxf(0.0, interaction_range)


func get_interaction_priority() -> int:
	return interaction_priority


func get_interaction_prompt(_actor: Node2D) -> String:
	return ""


func is_interaction_available(_actor: Node2D) -> bool:
	return not stable_id.is_empty()


func interact(_actor: Node2D) -> bool:
	return false


func serialize_state() -> Dictionary:
	return {"stable_id": stable_id}


func restore_state(state: Dictionary) -> bool:
	return _state_matches(state)


func _state_matches(state: Dictionary) -> bool:
	return not stable_id.is_empty() and String(state.get("stable_id", "")) == stable_id

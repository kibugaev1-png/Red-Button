class_name InteractionCoordinator
extends Node

signal target_changed(target: Node2D, prompt: String)

var _actor: Node2D
var _entries: Array[Dictionary] = []
var _current_target: Node2D
var _current_entry: Dictionary = {}
var _next_registration_order: int = 0


func set_actor(actor: Node2D) -> void:
	_actor = actor
	update_target()


func register_interactable(interactable: Node2D) -> void:
	if interactable == null or _find_entry_index(interactable) >= 0:
		return
	_entries.append({
		"target": interactable,
		"prompt": "",
		"priority": 0,
		"range": 0.0,
		"availability": Callable(),
		"interaction": Callable(),
		"adapter": false,
		"order": _take_registration_order(),
	})
	interactable.tree_exiting.connect(_on_target_tree_exiting.bind(interactable), CONNECT_ONE_SHOT)


func register_adapter(
	target: Node2D,
	prompt: String,
	priority: int,
	interaction_range: float,
	availability: Callable = Callable(),
	interaction: Callable = Callable()
) -> void:
	if target == null:
		return
	unregister_interactable(target)
	_entries.append({
		"target": target,
		"prompt": prompt,
		"priority": priority,
		"range": maxf(0.0, interaction_range),
		"availability": availability,
		"interaction": interaction,
		"adapter": true,
		"order": _take_registration_order(),
	})
	target.tree_exiting.connect(_on_target_tree_exiting.bind(target), CONNECT_ONE_SHOT)


func unregister_interactable(interactable: Node2D) -> void:
	var index := _find_entry_index(interactable)
	if index < 0:
		return
	_entries.remove_at(index)
	if _current_target == interactable:
		_set_current({})


func update_target() -> Node2D:
	_prune_invalid_entries()
	var best: Dictionary = {}
	var best_distance_squared := INF
	for entry: Dictionary in _entries:
		var target := entry.get("target") as Node2D
		if not _is_available(entry, target):
			continue
		var distance_squared := _actor.global_position.distance_squared_to(_interaction_position(entry, target))
		var interaction_range := _interaction_range(entry, target)
		if distance_squared > interaction_range * interaction_range:
			continue
		if _is_better_candidate(entry, distance_squared, best, best_distance_squared):
			best = entry
			best_distance_squared = distance_squared
	_set_current(best)
	return _current_target


func get_current_target() -> Node2D:
	return _current_target


func get_current_prompt() -> String:
	if _current_entry.is_empty() or not is_instance_valid(_current_target):
		return ""
	if bool(_current_entry.get("adapter", false)):
		return String(_current_entry.get("prompt", ""))
	if _current_target.has_method("get_interaction_prompt"):
		return String(_current_target.call("get_interaction_prompt", _actor))
	return ""


func interact_current() -> bool:
	update_target()
	if _current_entry.is_empty() or _current_target == null:
		return false
	if bool(_current_entry.get("adapter", false)):
		var callback: Callable = _current_entry.get("interaction", Callable())
		if not callback.is_valid():
			return false
		callback.call(_actor)
		return true
	if not _current_target.has_method("interact"):
		return false
	var result: Variant = _current_target.call("interact", _actor)
	return true if result == null else bool(result)


func _is_available(entry: Dictionary, target: Node2D) -> bool:
	if _actor == null or target == null or not is_instance_valid(target) or not target.is_inside_tree():
		return false
	if bool(entry.get("adapter", false)):
		var callback: Callable = entry.get("availability", Callable())
		return true if not callback.is_valid() else bool(callback.call(_actor))
	if target.has_method("is_interaction_available"):
		return bool(target.call("is_interaction_available", _actor))
	return target.has_method("interact")


func _interaction_position(entry: Dictionary, target: Node2D) -> Vector2:
	if not bool(entry.get("adapter", false)) and target.has_method("get_interaction_position"):
		return target.call("get_interaction_position") as Vector2
	return target.global_position


func _interaction_range(entry: Dictionary, target: Node2D) -> float:
	if not bool(entry.get("adapter", false)) and target.has_method("get_interaction_range"):
		return maxf(0.0, float(target.call("get_interaction_range")))
	return maxf(0.0, float(entry.get("range", 0.0)))


func _priority(entry: Dictionary) -> int:
	var target := entry.get("target") as Node2D
	if not bool(entry.get("adapter", false)) and target != null and target.has_method("get_interaction_priority"):
		return int(target.call("get_interaction_priority"))
	return int(entry.get("priority", 0))


func _is_better_candidate(
	candidate: Dictionary,
	candidate_distance_squared: float,
	best: Dictionary,
	best_distance_squared: float
) -> bool:
	if best.is_empty():
		return true
	var candidate_priority := _priority(candidate)
	var best_priority := _priority(best)
	if candidate_priority != best_priority:
		return candidate_priority > best_priority
	if not is_equal_approx(candidate_distance_squared, best_distance_squared):
		return candidate_distance_squared < best_distance_squared
	return int(candidate.get("order", 0)) < int(best.get("order", 0))


func _set_current(entry: Dictionary) -> void:
	var next_target := entry.get("target") as Node2D if not entry.is_empty() else null
	var previous_target := _current_target
	var previous_prompt := get_current_prompt()
	_current_entry = entry
	_current_target = next_target
	var next_prompt := get_current_prompt()
	if previous_target != _current_target or previous_prompt != next_prompt:
		target_changed.emit(_current_target, next_prompt)


func _find_entry_index(target: Node2D) -> int:
	for index in _entries.size():
		if _entries[index].get("target") == target:
			return index
	return -1


func _take_registration_order() -> int:
	var order := _next_registration_order
	_next_registration_order += 1
	return order


func _prune_invalid_entries() -> void:
	for index in range(_entries.size() - 1, -1, -1):
		var target: Variant = _entries[index].get("target")
		if target == null or not is_instance_valid(target):
			_entries.remove_at(index)


func _on_target_tree_exiting(target: Node2D) -> void:
	unregister_interactable(target)

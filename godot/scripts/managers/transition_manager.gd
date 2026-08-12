class_name TransitionManager
extends CanvasLayer

var _veil: ColorRect
var _busy: bool = false


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_veil = ColorRect.new()
	_veil.name = "TransitionVeil"
	_veil.color = Color(0.015, 0.012, 0.012, 1.0)
	_veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_veil.visible = false
	_veil.modulate.a = 0.0
	add_child(_veil)


func fade_from_black(duration: float = 0.7) -> void:
	if _busy:
		return
	_busy = true
	_veil.visible = true
	_veil.modulate.a = 1.0
	var tween := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tween.tween_property(_veil, "modulate:a", 0.0, duration)
	tween.finished.connect(func() -> void:
		_veil.visible = false
		_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_busy = false
	)


func fade_to_black(callback: Callable = Callable(), duration: float = 0.5) -> void:
	if _busy:
		return
	_busy = true
	_veil.visible = true
	_veil.mouse_filter = Control.MOUSE_FILTER_STOP
	_veil.modulate.a = 0.0
	var tween := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
	tween.tween_property(_veil, "modulate:a", 1.0, duration)
	tween.finished.connect(func() -> void:
		_busy = false
		if callback.is_valid():
			callback.call()
	)


func is_busy() -> bool:
	return _busy

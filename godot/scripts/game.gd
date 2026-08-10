# game.gd — корень сцены. Собирает мир, игрока, камеру, небо, свет и HUD.
#
# Сцена строится кодом, а не в редакторе: так вся настройка видна в одном месте
# и правится обычным дифом, а не бинарным файлом сцены.
extends Node2D

const SEED := 1337

var terrain: Terrain
var player: Player
var cam: Camera2D
var sky_rect: ColorRect
var post_rect: ColorRect
var lamp: PointLight2D
var hud: CanvasItem
var day := 1.0
var zoom_target := 1.6
var t := 0.0


func _ready() -> void:
	_bind_input()
	_make_environment()
	_make_sky()

	terrain = Terrain.new()
	terrain.name = "Terrain"
	add_child(terrain)
	terrain.build(SEED)

	player = Player.new()
	player.name = "Player"
	add_child(player)
	player.setup(terrain, terrain.spawn - Vector2(0, 4))
	player.z_index = 10

	_make_lamp()
	_make_dust()

	cam = Camera2D.new()
	cam.zoom = Vector2(zoom_target, zoom_target)
	cam.position_smoothing_enabled = true
	cam.position_smoothing_speed = 8.0
	add_child(cam)
	cam.make_current()

	_make_post()

	hud = preload("res://scripts/hud.gd").new()
	var layer := CanvasLayer.new()
	layer.layer = 10
	layer.add_child(hud)
	add_child(layer)
	hud.set("game", self)

	print("[игра] готова, появление: ", player.position)
	_debug_args()


# Отладочные ключи запуска. Нужны, чтобы проверять картинку и кадры без рук:
#   godot -- --shot=/путь/к.png --frames=60 --at=3250 --zoom=2
var _shot_path := ""
var _shot_frames := 60
var _frame := 0


func _debug_args() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot="):
			_shot_path = a.substr(7)
		elif a.begins_with("--frames="):
			_shot_frames = int(a.substr(9))
		elif a.begins_with("--at="):
			# перенос игрока в частицах по X — чтобы посмотреть другую локацию
			var cx := int(a.substr(5))
			player.position = Vector2(cx * Core.CELL, terrain.surface_px(cx * Core.CELL) - Core.CELL)
			cam.position = player.position
			cam.reset_smoothing()
		elif a.begins_with("--zoom="):
			zoom_target = float(a.substr(7))
			cam.zoom = Vector2(zoom_target, zoom_target)
		elif a == "--dig":
			_test_dig = true
		elif a.begins_with("--day="):
			_day_fixed = float(a.substr(6))


var _day_fixed := -1.0
var _test_dig := false


func _capture() -> void:
	_frame += 1
	# Проверка копания без рук: роем яму под ногами и убеждаемся, что свет
	# пересчитался, тайлы перезалились и ничего не упало.
	if _test_dig and _frame == 20:
		var cx := int(player.position.x / Core.CELL)
		var cy := int(player.position.y / Core.CELL) + 3
		var before := terrain.get_mat(cx, cy)
		var got: Dictionary = terrain.dig(cx, cy, 5, 3.0)
		print("[проверка] копали породу ", before, ", выпало ", got,
			", стало ", terrain.get_mat(cx, cy),
			", свет ", terrain.light_at_px(player.position.x, player.position.y + 24.0))
	if _shot_path == "" or _frame < _shot_frames:
		return
	var img := get_viewport().get_texture().get_image()
	img.save_png(_shot_path)
	print("[снимок] ", _shot_path, "  кадров в секунду: ", Engine.get_frames_per_second())
	_shot_path = ""
	get_tree().quit()


func _bind_input() -> void:
	var binds := {
		"left": [KEY_A, KEY_LEFT], "right": [KEY_D, KEY_RIGHT],
		"up": [KEY_W, KEY_UP, KEY_SPACE], "down": [KEY_S, KEY_DOWN],
		"sprint": [KEY_SHIFT], "quality": [KEY_F1],
	}
	for action in binds:
		var a := StringName(action)
		if not InputMap.has_action(a):
			InputMap.add_action(a)
		for k in binds[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event(a, ev)


# Свечение. В 2D его даёт Environment, а пересветы приходят из шейдера породы:
# освещённые кромки и стекло противогаза светят чуть выше единицы.
func _make_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_CANVAS
	env.glow_enabled = true
	env.glow_intensity = 0.5
	env.glow_bloom = 0.12
	env.glow_strength = 1.05
	env.glow_hdr_threshold = 0.95
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	env.adjustment_enabled = true
	env.adjustment_brightness = 1.02
	env.adjustment_contrast = 1.06
	env.adjustment_saturation = 0.94    # выжженный, чуть обесцвеченный мир
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)


func _make_sky() -> void:
	var layer := CanvasLayer.new()
	layer.layer = -100
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/sky.gdshader")
	mat.set_shader_parameter("horizon_y", float(Core.SURFACE_Y * Core.CELL))
	sky_rect = ColorRect.new()
	sky_rect.material = mat
	sky_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	sky_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(sky_rect)
	add_child(layer)


# Лампа игрока: без неё пещеры честно чёрные, потому что свет неба туда не идёт
func _make_lamp() -> void:
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
	grad.colors = PackedColorArray([
		Color(1.0, 0.92, 0.72, 1.0), Color(1.0, 0.82, 0.55, 0.35), Color(0, 0, 0, 0),
	])
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 512
	tex.height = 512
	lamp = PointLight2D.new()
	lamp.texture = tex
	lamp.energy = 1.15
	lamp.texture_scale = 1.6
	lamp.blend_mode = Light2D.BLEND_MODE_ADD
	add_child(lamp)


# Финишный слой: виньетка, тёплая тонировка, зерно, лёгкая аберрация по краям.
# Он лежит поверх мира, но под интерфейсом — HUD трогать не надо.
func _make_post() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 5
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/post.gdshader")
	post_rect = ColorRect.new()
	post_rect.material = mat
	post_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	post_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(post_rect)
	add_child(layer)


# Пыль в воздухе: дешёвый приём, который сразу добавляет глубины
func _make_dust() -> void:
	var p := CPUParticles2D.new()
	p.amount = 220
	p.lifetime = 9.0
	p.preprocess = 4.0
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(900, 500)
	p.gravity = Vector2(6, -2)
	p.initial_velocity_min = 2.0
	p.initial_velocity_max = 14.0
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.8
	p.color = Color(1.0, 0.94, 0.8, 0.14)
	p.z_index = 20
	p.name = "Dust"
	add_child(p)


func _process(dt: float) -> void:
	t += dt
	# сутки: 0 — ночь, 1 — полдень. Держим вечерний свет, он самый выразительный
	day = 0.55 + 0.45 * sin(t / Core.DAY_LEN * TAU + 1.2)
	if _day_fixed >= 0.0:
		day = _day_fixed

	cam.position = player.position + Vector2(0, -20)
	cam.zoom = cam.zoom.lerp(Vector2(zoom_target, zoom_target), minf(1.0, dt * 8.0))
	lamp.position = player.position + Vector2(0, -34)
	# Днём лампа не нужна: на солнце она только выжигала фигуру в белое пятно.
	# Гасим её по общей освещённости и по тому, сколько света в этом месте.
	var here := terrain.light_at_px(player.position.x, player.position.y - 30.0)
	lamp.energy = lerpf(1.35, 0.12, clampf(day * here * 1.4, 0.0, 1.0))
	var dust := get_node_or_null("Dust")
	if dust:
		(dust as CPUParticles2D).position = cam.position

	var sm: ShaderMaterial = sky_rect.material
	# Линию горизонта берём по земле под игроком, а не по среднему уровню мира:
	# иначе солнце и силуэты города уезжают за землю и небо выглядит заливкой.
	sm.set_shader_parameter("horizon_y", terrain.surface_px(player.position.x))
	sm.set_shader_parameter("cam_pos", cam.get_screen_center_position())
	sm.set_shader_parameter("zoom", cam.zoom.x)
	sm.set_shader_parameter("screen_size", get_viewport_rect().size)
	sm.set_shader_parameter("day", day)
	sm.set_shader_parameter("time_s", t)

	var pm: ShaderMaterial = post_rect.material
	pm.set_shader_parameter("day", day)
	pm.set_shader_parameter("time_s", t)

	terrain.set_uniform("day", day)
	terrain.set_uniform("time_s", t)

	_dig()
	hud.queue_redraw()
	_capture()


func mouse_world() -> Vector2:
	return get_global_mouse_position()


# Копание: кирка берёт круг радиусом 4 частицы, как 9×9 в браузерной версии
func _dig() -> void:
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		return
	if player.dig_cool > 0.0:
		return
	var w := mouse_world()
	if w.distance_to(player.position + Vector2(0, -28)) > 220.0:
		return
	var cx := int(floor(w.x / Core.CELL))
	var cy := int(floor(w.y / Core.CELL))
	var got: Dictionary = terrain.dig(cx, cy, 4, 3.0)
	player.dig_cool = 0.12
	if not got.is_empty():
		_dig_puff(w)


func _dig_puff(at: Vector2) -> void:
	var p := CPUParticles2D.new()
	p.amount = 14
	p.lifetime = 0.7
	p.one_shot = true
	p.explosiveness = 0.9
	p.position = at
	p.direction = Vector2(0, -1)
	p.spread = 60.0
	p.gravity = Vector2(0, 320)
	p.initial_velocity_min = 40.0
	p.initial_velocity_max = 130.0
	p.scale_amount_min = 1.0
	p.scale_amount_max = 2.6
	p.color = Color(0.55, 0.45, 0.34, 0.9)
	p.z_index = 15
	add_child(p)
	p.emitting = true
	get_tree().create_timer(1.2).timeout.connect(p.queue_free)


func _unhandled_input(e: InputEvent) -> void:
	# приближение колесом и щипком на трекпаде — как в браузерной версии
	if e is InputEventMouseButton and e.pressed:
		if e.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom_target = clampf(zoom_target * 1.12, 0.5, 6.0)
		elif e.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_target = clampf(zoom_target / 1.12, 0.5, 6.0)
	elif e is InputEventMagnifyGesture:
		zoom_target = clampf(zoom_target * e.factor, 0.5, 6.0)
	elif e is InputEventKey and e.pressed and not e.echo:
		if e.physical_keycode == KEY_F1:
			# F1 переключает детализацию породы, если кадры просядут
			var d: float = 0.0 if terrain_detail() > 0.5 else 1.0
			terrain.set_uniform("detail", d)
			_detail = d
		elif e.physical_keycode == KEY_M:
			player.mask = not player.mask


var _detail := 1.0


func terrain_detail() -> float:
	return _detail

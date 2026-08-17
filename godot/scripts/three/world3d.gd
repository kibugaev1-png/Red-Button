# world3d.gd — трёхмерная версия «Красной кнопки».
#
# Мир, породы и физика те же, что в двумерной версии: та же сетка 8000×720
# частиц из WorldGen, те же скорости, те же столкновения по клеткам. Игра
# осталась игрой сбоку — движение по X и Y, глубина только для картинки.
# Меняется способ показать мир: настоящая геометрия, настоящее солнце с тенями,
# небо-панорама, которая ещё и освещает сцену.
#
# Почему именно так, а не свободное движение по трём осям: весь смысл игры —
# копать породу по частицам. Свободное 3D означало бы воксельный мир с нуля,
# то есть выбросить всё, что уже сделано. Здесь наоборот: старая механика
# работает как была, а картинка становится объёмной.
extends Node3D

const SEED := 1337
const SPAWN_CELL := 3250

var grid: Grid                    # сетка частиц
var chunker: Chunker3D
var player: Player3D
var cam: Camera3D
var sun: DirectionalLight3D
var env: Environment
var day := 0.82
var t := 0.0
var _zone_id := ""

# Обёртка над сеткой: кускам геометрии и физике нужен только доступ к частицам,
# без спрайтов и текстур двумерной версии.
class Grid:
	var data := PackedByteArray()
	var surface := PackedInt32Array()
	var spawn := Vector2.ZERO

	func get_mat(cx: int, cy: int) -> int:
		if cx < 0 or cy < 0 or cx >= Core.WW or cy >= Core.WH:
			return Core.STONE
		return data[(cy * Core.WW + cx) * 2]

	func is_solid_cell(cx: int, cy: int) -> bool:
		return Core.is_solid(get_mat(cx, cy))

	func set_mat(cx: int, cy: int, m: int) -> void:
		if cx < 0 or cy < 0 or cx >= Core.WW or cy >= Core.WH:
			return
		data[(cy * Core.WW + cx) * 2] = m

	func surface_px(x: float) -> float:
		var cx := clampi(int(floor(x / Core.CELL)), 0, Core.WW - 1)
		return float(surface[cx]) * Core.CELL


func _ready() -> void:
	_bind_input()

	var g := WorldGen.generate(SEED)
	grid = Grid.new()
	grid.data = g.data
	grid.surface = g.surface
	grid.spawn = g.spawn

	_make_environment()
	_make_sun()

	chunker = Chunker3D.new()
	chunker.name = "Chunker"
	add_child(chunker)
	chunker.setup(grid)

	player = Player3D.new()
	player.name = "Player"
	add_child(player)
	player.setup(grid, SPAWN_CELL)

	cam = Camera3D.new()
	cam.fov = 46.0
	cam.near = 0.05
	cam.far = 220.0
	add_child(cam)
	cam.make_current()

	chunker.update_around(player.position)
	_place_camera(true)
	_apply_zone_sky(true)
	print("[3D] мир готов, игрок в ", player.position)
	_debug_args()


func _bind_input() -> void:
	var binds := {
		"left": [KEY_A, KEY_LEFT], "right": [KEY_D, KEY_RIGHT],
		"up": [KEY_W, KEY_UP, KEY_SPACE], "down": [KEY_S, KEY_DOWN],
		"sprint": [KEY_SHIFT],
	}
	for action in binds:
		var a := StringName(action)
		if not InputMap.has_action(a):
			InputMap.add_action(a)
		for k in binds[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event(a, ev)


# ОСВЕЩЕНИЕ И АТМОСФЕРА.
# Здесь наконец доступно всё, чего в 2D не существует: тональная компрессия,
# затенение в углах, объёмный туман, отражения неба. Значения подобраны под
# закатный свет — он выразительнее всего для выжженного мира.
func _make_environment() -> void:
	env = Environment.new()
	env.background_mode = Environment.BG_SKY

	var sky := Sky.new()
	sky.sky_material = PanoramaSkyMaterial.new()
	env.sky = sky
	# небо освещает сцену: тени становятся синими, а не чёрными
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 1.0
	env.ambient_light_energy = 1.0
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY

	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.0
	env.tonemap_white = 6.0

	env.ssao_enabled = true
	env.ssao_radius = 0.6
	env.ssao_intensity = 2.4
	env.ssao_power = 1.6
	env.ssao_detail = 0.6

	env.ssil_enabled = false          # красиво, но дорого — включим при запасе кадров

	env.glow_enabled = true
	env.glow_intensity = 0.45
	env.glow_bloom = 0.12
	env.glow_strength = 1.0
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	env.glow_hdr_threshold = 1.0      # в 3D пересветы настоящие, порог держим высоко

	# Воздушная перспектива: даль тонет в пыли. В 2D это рисовалось вручную,
	# здесь туман честно зависит от расстояния.
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = Color(0.62, 0.53, 0.44)
	env.fog_light_energy = 1.0
	env.fog_sun_scatter = 0.25
	env.fog_density = 0.012
	env.fog_depth_begin = 18.0
	env.fog_depth_end = 190.0
	env.fog_sky_affect = 0.15

	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.014
	env.volumetric_fog_albedo = Color(0.75, 0.68, 0.58)
	env.volumetric_fog_emission_energy = 0.0
	env.volumetric_fog_length = 60.0
	env.volumetric_fog_gi_inject = 0.4

	env.adjustment_enabled = true
	env.adjustment_brightness = 1.0
	env.adjustment_contrast = 1.05
	env.adjustment_saturation = 0.95

	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)


func _make_sun() -> void:
	sun = DirectionalLight3D.new()
	# низкое закатное солнце слева: длинные тени вдоль породы
	sun.rotation_degrees = Vector3(-22.0, 38.0, 0.0)
	sun.light_color = Color(1.0, 0.82, 0.62)
	sun.light_energy = 2.1
	sun.light_angular_distance = 1.2      # мягкая граница тени, как у настоящего солнца
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = 90.0
	sun.directional_shadow_split_1 = 0.06
	sun.directional_shadow_split_2 = 0.18
	sun.directional_shadow_split_3 = 0.45
	sun.directional_shadow_blend_splits = true
	sun.shadow_bias = 0.02
	sun.shadow_normal_bias = 1.4
	add_child(sun)


# Небо локации: те же панорамы, что в двумерной версии рисовались полосой,
# здесь работают целиком и заодно освещают сцену.
func _apply_zone_sky(force: bool) -> void:
	var zone: Dictionary = Core.zone_at_px(player.position.x / Chunker3D.SCALE)
	var id: String = zone.id
	if id == _zone_id and not force:
		return
	_zone_id = id
	var path := "res://skies/%s.jpg" % id
	if not ResourceLoader.exists(path):
		path = "res://skies/waste.jpg"
	var mat: PanoramaSkyMaterial = env.sky.sky_material
	mat.panorama = load(path)
	mat.energy_multiplier = 1.0


func _process(dt: float) -> void:
	t += dt
	chunker.update_around(player.position)
	_place_camera(false)
	_apply_zone_sky(false)
	_capture()


# Камера сбоку, но с перспективой: у мира появляется глубина, а игра остаётся
# двумерной по управлению. Камера ведёт игрока с запаздыванием.
func _place_camera(instant: bool) -> void:
	var target := player.position + Vector3(0.0, 1.35, 8.4)
	if instant:
		cam.position = target
	else:
		cam.position = cam.position.lerp(target, 0.12)
	cam.look_at(player.position + Vector3(0.0, 0.85, 0.0), Vector3.UP)


# ---- отладка: снимок и перенос по локациям ----
var _shot_path := ""
var _shot_frames := 90
var _frame := 0


func _debug_args() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot="):
			_shot_path = a.substr(7)
		elif a.begins_with("--frames="):
			_shot_frames = int(a.substr(9))
		elif a.begins_with("--at="):
			player.teleport_cell(int(a.substr(5)))
			chunker.update_around(player.position)
			_place_camera(true)
			_apply_zone_sky(true)


func _capture() -> void:
	_frame += 1
	if _shot_path == "":
		return
	# ждём, пока куски геометрии успеют построиться
	if _frame < _shot_frames:
		return
	var img := get_viewport().get_texture().get_image()
	img.save_png(_shot_path)
	print("[снимок] ", _shot_path, "  к/с: ", Engine.get_frames_per_second(),
		"  кусков: ", chunker.chunk_count())
	_shot_path = ""
	get_tree().quit()

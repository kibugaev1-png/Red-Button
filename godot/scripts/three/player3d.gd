# player3d.gd — герой в трёхмерном мире.
#
# Физика намеренно та же, что в двумерной версии, и намеренно не движковая:
# столкновения считаются по частицам породы, как раньше. Причина простая — мир
# разрушаемый, и держать для 5,7 миллиона частиц коллизионные тела нельзя.
# Скорости совпадают до цифры: шаг 1,65 частицы за кадр, прыжок −5,4, тяга 0,42.
# Поэтому управление ощущается ровно как в 2D, хотя мир стал объёмным.
#
# Движение идёт по X и Y, глубина Z всегда нулевая: игра осталась игрой сбоку.
extends Node3D
class_name Player3D

const SPEED := 1.65               # частиц за кадр
const JUMP := -5.4
const SPRINT := 1.55
const W := 13.0                   # тело в пикселях, как в 2D
const H := 54.0

var grid
var vx := 0.0
var vy := 0.0
var on_ground := false
var face := 1
var phase := 0.0

# положение храним в пикселях мира, как в 2D, и переводим в метры для сцены
var px := 0.0
var py := 0.0

var _body: Node3D
var _legs: Array[Node3D] = []
var _arms: Array[Node3D] = []


func setup(g, spawn_cell: int) -> void:
	grid = g
	_build_model()
	teleport_cell(spawn_cell)


func teleport_cell(cell_x: int) -> void:
	px = float(cell_x) * Core.CELL
	py = grid.surface_px(px) - Core.CELL
	_sync()


func _physics_process(dt: float) -> void:
	var ax := 0.0
	if Input.is_action_pressed(&"left"):
		ax -= 1.0
	if Input.is_action_pressed(&"right"):
		ax += 1.0
	var sprint: float = SPRINT if Input.is_action_pressed(&"sprint") else 1.0

	vx = ax * SPEED * sprint
	if ax != 0.0:
		face = int(sign(ax))
		phase += dt * (7.0 + absf(vx) * 3.2)
	else:
		phase += dt * 0.8

	if Input.is_action_pressed(&"up") and on_ground:
		vy = JUMP
		on_ground = false
	vy += Core.GRAV
	vy = minf(vy, 14.0)

	_unstuck()
	_move_x(vx)
	_move_y(vy)
	_sync()
	_animate()


# ---- столкновения по частицам, как в 2D ----
func hits(x: float, y: float) -> bool:
	var x0 := int(floor((x - W * 0.5) / Core.CELL))
	var x1 := int(floor((x + W * 0.5 - 1.0) / Core.CELL))
	var y0 := int(floor((y - H) / Core.CELL))
	var y1 := int(floor((y - 1.0) / Core.CELL))
	for cy in range(y0, y1 + 1):
		for cx in range(x0, x1 + 1):
			if grid.is_solid_cell(cx, cy):
				return true
	return false


func _move_x(dx: float) -> void:
	var nx := px + dx
	if not hits(nx, py):
		px = nx
		return
	for up in range(1, 3):
		var ny := py - up * Core.CELL
		if hits(nx, ny) or hits(px, ny):
			continue
		px = nx
		py = ny
		return
	vx = 0.0


func _move_y(dy: float) -> void:
	var ny := py + dy
	if not hits(px, ny):
		py = ny
		on_ground = false
		return
	if dy > 0.0:
		while not hits(px, py + 1.0) and hits(px, ny):
			py += 1.0
		on_ground = true
	vy = 0.0


func _unstuck() -> void:
	if not hits(px, py):
		return
	for up in range(1, 15):
		if not hits(px, py - up * Core.CELL):
			py -= up * Core.CELL
			vy = 0.0
			return
	py = grid.surface_px(px) - Core.CELL
	vy = 0.0


# пиксели мира в метры сцены: Y вверх, поэтому знак меняется
func _sync() -> void:
	var s := Chunker3D.SCALE / Core.CELL
	position = Vector3(px * s, -py * s, 0.0)


# ---- модель ----
# Человек из простых объёмов: так он читается силуэтом и правильно принимает
# свет и тени. Пропорции те же, что у двумерного героя: рост 54 частицы, то есть
# 1,7 метра при масштабе 0,25 метра на частицу.
func _build_model() -> void:
	var unit := Chunker3D.SCALE / Core.CELL      # метров на пиксель тела
	_body = Node3D.new()
	add_child(_body)

	var skin := _mat(Color(0.68, 0.52, 0.4), 0.75)
	var tank := _mat(Color(0.83, 0.82, 0.76), 0.8)
	var pants := _mat(Color(0.17, 0.18, 0.22), 0.85)
	var boot := _mat(Color(0.18, 0.15, 0.12), 0.7)
	var rubber := _mat(Color(0.26, 0.28, 0.25), 0.6)
	var glass := _mat(Color(0.35, 0.45, 0.42), 0.15, 0.0, true)

	# торс
	_box(_body, Vector3(11.0, 20.0, 7.0) * unit, Vector3(0, -34.0, 0) * unit, tank)
	# бёдра
	_box(_body, Vector3(10.0, 4.0, 7.0) * unit, Vector3(0, -23.0, 0) * unit, pants)
	# ноги
	for i in 2:
		var leg := Node3D.new()
		leg.position = Vector3((-3.0 + i * 6.0) * unit, -22.0 * unit, 0.0)
		_body.add_child(leg)
		_box(leg, Vector3(4.4, 18.0, 5.0) * unit, Vector3(0, -9.0, 0) * unit, pants)
		_box(leg, Vector3(5.2, 4.0, 8.0) * unit, Vector3(0, -19.5, 1.0) * unit, boot)
		_legs.append(leg)
	# руки
	for i in 2:
		var arm := Node3D.new()
		arm.position = Vector3((-6.0 + i * 12.0) * unit, -40.0 * unit, 0.0)
		_body.add_child(arm)
		_box(arm, Vector3(3.6, 17.0, 3.6) * unit, Vector3(0, -8.5, 0) * unit, skin)
		_arms.append(arm)
	# шея и голова
	_box(_body, Vector3(4.0, 3.0, 4.0) * unit, Vector3(0, -44.5, 0) * unit, skin)
	var head := Node3D.new()
	head.position = Vector3(0, -49.0 * unit, 0)
	_body.add_child(head)
	_box(head, Vector3(9.0, 9.5, 9.0) * unit, Vector3.ZERO, rubber)
	# два стекла: то же решение, что в 2D — один круглый глаз читается циклопом
	for i in 2:
		var lens := MeshInstance3D.new()
		var sph := SphereMesh.new()
		sph.radius = 2.1 * unit
		sph.height = 3.4 * unit
		lens.mesh = sph
		lens.material_override = glass
		lens.position = Vector3((-2.4 + i * 4.8) * unit, 0.8 * unit, 4.6 * unit)
		head.add_child(lens)
	# фильтр у рта
	_box(head, Vector3(4.2, 4.2, 5.0) * unit, Vector3(0, -3.6, 4.0) * unit,
		_mat(Color(0.2, 0.22, 0.2), 0.55))


func _mat(c: Color, rough: float, metal: float = 0.0, shiny: bool = false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	if shiny:
		m.metallic = 0.6
		m.metallic_specular = 0.9
	return m


func _box(parent: Node3D, size: Vector3, at: Vector3, mat: StandardMaterial3D) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = at
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(mi)


func _animate() -> void:
	var moving: bool = absf(vx) > 0.05
	var swing: float = sin(phase) * (0.55 if moving else 0.0)
	_legs[0].rotation.x = swing
	_legs[1].rotation.x = -swing
	_arms[0].rotation.x = -swing * 0.8
	_arms[1].rotation.x = swing * 0.8
	# разворот всей фигуры по направлению шага
	_body.rotation.y = lerp_angle(_body.rotation.y, 0.0 if face > 0 else PI, 0.25)
	var bob: float = (absf(sin(phase * 2.0)) * 1.0) if moving else 0.0
	_body.position.y = bob * Chunker3D.SCALE / Core.CELL

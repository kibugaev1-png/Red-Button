# chunker3d.gd — превращает сетку частиц в трёхмерную геометрию.
#
# Мир тот же самый: 8000×720 частиц из WorldGen, те же породы из Core. Меняется
# только способ показать их — вместо шейдера по текстуре строим настоящие
# полигоны, чтобы солнце давало настоящие тени, а не нарисованные.
#
# Всю сетку в геометрию превратить нельзя: 5,7 миллиона частиц это десятки
# миллионов полигонов. Поэтому мир нарезан на куски по 32×32 частицы, и живут
# только те, что рядом с игроком; остальные удаляются. Куски строятся по
# несколько за кадр, иначе движение давало бы рывки.
#
# Порода — не кубики. Каждая частица это участок плиты толщиной SLAB, и боковые
# грани появляются только там, где рядом пусто. Внутри массива граней нет вовсе,
# поэтому полигонов уходит в разы меньше, чем на честные кубы.
extends Node3D
class_name Chunker3D

const CHUNK := 32                  # частиц в куске по каждой оси
const SCALE := 0.25               # метров на частицу: человек в 54 частицы = 1,7 м
const SLAB := 10                   # толщина породы в частицах
const BUILD_PER_FRAME := 2         # кусков за кадр
const RADIUS_X := 5                # сколько кусков держать вокруг игрока
const RADIUS_Y := 4

# Породы, сведённые к материалам: у похожих один и тот же камень или дерево,
# иначе на каждый кусок пришлось бы по тридцать поверхностей.
const GROUPS := {
	"grass": [Core.GRASS],
	"dirt": [Core.DIRT, Core.FARM],
	"clay": [Core.CLAY],
	"rock": [Core.STONE, Core.COAL, Core.IRON, Core.COPPER, Core.GALENA, Core.SULFUR],
	"gravel": [Core.ASH],
	"concrete": [Core.CONCRETE, Core.BUILD_S, Core.GLASSW, Core.BG_CONC],
	"wood": [Core.PLANK, Core.WALL_W, Core.FLOOR_W, Core.ROOF_W, Core.DOOR,
		Core.DOOR_OPEN, Core.LADDER, Core.BUILD_W, Core.BG_WOOD, Core.LEAF],
	"bark": [Core.TRUNK],
	"metal": [Core.METAL, Core.REBAR, Core.BUILD_M, Core.BG_METAL],
}

var terrain                        # источник частиц: у него нужен только get_mat
var _materials := {}
var _mat_of_cell := {}             # id породы -> имя материала
var _chunks := {}                  # Vector2i -> MeshInstance3D
var _queue: Array[Vector2i] = []
var _center := Vector2i(-9999, -9999)


func setup(t) -> void:
	terrain = t
	_load_materials()
	for name in GROUPS:
		for id in GROUPS[name]:
			_mat_of_cell[id] = name


# Материалы из тех же фотографических текстур, что и в двумерной версии, но
# здесь они наконец работают как задумано: с картой нормалей, шероховатостью
# и настоящим отражением неба.
func _load_materials() -> void:
	for name in GROUPS:
		var mat := StandardMaterial3D.new()
		var color_path := "res://textures/%s_color.jpg" % name
		var normal_path := "res://textures/%s_normal.jpg" % name
		if ResourceLoader.exists(color_path):
			mat.albedo_texture = load(color_path)
		else:
			mat.albedo_color = Color(0.5, 0.45, 0.4)
		if ResourceLoader.exists(normal_path):
			mat.normal_enabled = true
			mat.normal_texture = load(normal_path)
			mat.normal_scale = 1.4
		# Текстура ложится по мировым координатам, а не по частице: иначе на
		# каждой частице был бы виден отдельный квадратик текстуры.
		mat.uv1_scale = Vector3(1.4, 1.4, 1.4)
		mat.uv1_world_triplanar = true
		mat.uv1_triplanar_sharpness = 1.0
		mat.roughness = 0.92
		mat.metallic = 0.0
		mat.ao_enabled = false
		if name == "metal":
			mat.metallic = 0.55
			mat.roughness = 0.55
		if name == "grass":
			mat.roughness = 0.85
		_materials[name] = mat


func _process(_dt: float) -> void:
	var built := 0
	while built < BUILD_PER_FRAME and not _queue.is_empty():
		var key: Vector2i = _queue.pop_front()
		if not _chunks.has(key):
			_build_chunk(key)
		built += 1


# Игрок сдвинулся — пересматриваем, какие куски нужны
func update_around(world_pos: Vector3) -> void:
	var cx := int(floor(world_pos.x / SCALE / CHUNK))
	var cy := int(floor(-world_pos.y / SCALE / CHUNK))
	var c := Vector2i(cx, cy)
	if c == _center:
		return
	_center = c

	var need := {}
	for dy in range(-RADIUS_Y, RADIUS_Y + 1):
		for dx in range(-RADIUS_X, RADIUS_X + 1):
			var k := Vector2i(cx + dx, cy + dy)
			if k.x < 0 or k.y < 0 or k.x * CHUNK >= Core.WW or k.y * CHUNK >= Core.WH:
				continue
			need[k] = true
			if not _chunks.has(k) and not _queue.has(k):
				_queue.append(k)

	# лишние куски убираем, иначе память уедет в потолок
	for k in _chunks.keys():
		if not need.has(k):
			(_chunks[k] as Node).queue_free()
			_chunks.erase(k)
	# ближние куски строим первыми
	_queue.sort_custom(func(a, b): return a.distance_squared_to(c) < b.distance_squared_to(c))


func _build_chunk(key: Vector2i) -> void:
	var tools := {}
	var x0 := key.x * CHUNK
	var y0 := key.y * CHUNK
	var depth := float(SLAB) * SCALE

	for ly in CHUNK:
		var cy := y0 + ly
		if cy >= Core.WH:
			break
		for lx in CHUNK:
			var cx := x0 + lx
			if cx >= Core.WW:
				break
			var m: int = terrain.get_mat(cx, cy)
			if m == Core.AIR or not _mat_of_cell.has(m):
				continue
			var group: String = _mat_of_cell[m]
			if not tools.has(group):
				var st := SurfaceTool.new()
				st.begin(Mesh.PRIMITIVE_TRIANGLES)
				tools[group] = st
			var st: SurfaceTool = tools[group]

			# координаты частицы в метрах: Y вверх, поэтому переворачиваем
			var px := float(cx) * SCALE
			var py := -float(cy) * SCALE
			var s := SCALE

			# Передняя грань есть всегда — она и видна камере. Её глубина у каждой
			# частицы своя: ровная плоскость выглядела бы залитой краской, а
			# щербатая поверхность ловит свет и читается как порода.
			var bump := (_hash(cx, cy) - 0.5) * SCALE * 0.55
			_quad(st,
				Vector3(px, py, bump), Vector3(px + s, py, bump),
				Vector3(px + s, py - s, bump), Vector3(px, py - s, bump),
				Vector3(0, 0, 1))

			# Боковые грани только там, где рядом пусто: внутри массива породы
			# они никому не видны, а полигоны бы съели
			if not _solid(cx, cy - 1):
				_quad(st,
					Vector3(px, py, -depth), Vector3(px + s, py, -depth),
					Vector3(px + s, py, 0.0), Vector3(px, py, 0.0),
					Vector3(0, 1, 0))
			if not _solid(cx, cy + 1):
				_quad(st,
					Vector3(px, py - s, 0.0), Vector3(px + s, py - s, 0.0),
					Vector3(px + s, py - s, -depth), Vector3(px, py - s, -depth),
					Vector3(0, -1, 0))
			if not _solid(cx - 1, cy):
				_quad(st,
					Vector3(px, py, 0.0), Vector3(px, py, -depth),
					Vector3(px, py - s, -depth), Vector3(px, py - s, 0.0),
					Vector3(-1, 0, 0))
			if not _solid(cx + 1, cy):
				_quad(st,
					Vector3(px + s, py, -depth), Vector3(px + s, py, 0.0),
					Vector3(px + s, py - s, 0.0), Vector3(px + s, py - s, -depth),
					Vector3(1, 0, 0))

	if tools.is_empty():
		_chunks[key] = Node3D.new()          # пустой кусок: помним, что он пуст
		add_child(_chunks[key])
		return

	var mesh := ArrayMesh.new()
	var surface := 0
	for group in tools:
		var st: SurfaceTool = tools[group]
		st.generate_tangents()
		st.commit(mesh)
		mesh.surface_set_material(surface, _materials[group])
		surface += 1

	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(mi)
	_chunks[key] = mi


# Разброс глубины по частице: одинаковый при каждой перестройке куска,
# иначе порода бы дрожала после каждого копания.
func _hash(cx: int, cy: int) -> float:
	var h := cx * 374761393 + cy * 668265263
	h = (h ^ (h >> 13)) * 1274126177
	return float((h ^ (h >> 16)) & 0xFFFF) / 65535.0


func _solid(cx: int, cy: int) -> bool:
	var m: int = terrain.get_mat(cx, cy)
	return m != Core.AIR and _mat_of_cell.has(m)


# Один четырёхугольник двумя треугольниками, с нормалью и развёрткой
func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, n: Vector3) -> void:
	var uv_a := Vector2(0, 0)
	var uv_b := Vector2(1, 0)
	var uv_c := Vector2(1, 1)
	var uv_d := Vector2(0, 1)
	for v in [[a, uv_a], [b, uv_b], [c, uv_c]]:
		st.set_normal(n)
		st.set_uv(v[1])
		st.add_vertex(v[0])
	for v in [[a, uv_a], [c, uv_c], [d, uv_d]]:
		st.set_normal(n)
		st.set_uv(v[1])
		st.add_vertex(v[0])


func chunk_count() -> int:
	return _chunks.size()


# Порода изменилась (копали) — перестроить затронутый кусок
func invalidate(cx: int, cy: int) -> void:
	var key := Vector2i(cx / CHUNK, cy / CHUNK)
	for k in [key, key + Vector2i(-1, 0), key + Vector2i(1, 0), key + Vector2i(0, -1), key + Vector2i(0, 1)]:
		if _chunks.has(k):
			(_chunks[k] as Node).queue_free()
			_chunks.erase(k)
			if not _queue.has(k):
				_queue.push_front(k)

# terrain.gd — хранение породы и её отрисовка тайлами.
#
# Мир — 8000×720 частиц, это 5,7 миллиона штук. Рисовать их по одной, как делал
# canvas, невозможно, поэтому сетка лежит в текстуре (R — порода, G — свет), а
# всю картинку считает shaders/terrain.gdshader на видеокарте.
#
# Текстура разбита на тайлы: при копании перезаливается только затронутый тайл,
# а не весь мир. У каждого тайла есть поля в две частицы по краям — иначе шейдер
# не знает соседа за границей и на стыках появлялись бы швы в обводке.
extends Node2D
class_name Terrain

const TILE_W := 512
const TILE_H := 384
const PAD := 2

var data := PackedByteArray()          # 2 байта на частицу: [порода, свет]
var surface := PackedInt32Array()
var spawn := Vector2.ZERO

var _tiles: Array = []                 # {sprite, image, texture, rect, dirty}
var _dirty_tiles := {}
var _shader: Shader = preload("res://shaders/terrain.gdshader")

# Фотографические текстуры пород (наборы CC0 с ambientCG). Лежат слоями в
# Texture2DArray: у массива работает обычное заворачивание и мип-уровни, поэтому
# нет ни швов, как было бы в атласе, ни ряби при отдалении.
# Порядок задаёт номер слоя, на который ссылаются породы.
const TEX_LAYERS := ["grass", "dirt", "clay", "rock", "concrete", "wood", "bark", "gravel", "metal"]
const L_GRASS := 0
const L_DIRT := 1
const L_CLAY := 2
const L_ROCK := 3
const L_CONC := 4
const L_WOOD := 5
const L_BARK := 6
const L_GRAVEL := 7
const L_METAL := 8

var _layer_of := {}                    # имя слоя -> номер в массиве
var _tex_color: Texture2DArray
var _tex_normal: Texture2DArray


func build(seed_v: int) -> void:
	var g := WorldGen.generate(seed_v)
	data = g.data
	surface = g.surface
	spawn = g.spawn
	_make_tiles()


# ---- доступ к породе ----
func get_mat(cx: int, cy: int) -> int:
	if cx < 0 or cy < 0 or cx >= Core.WW or cy >= Core.WH:
		return Core.STONE          # за краем мира — камень, чтобы не выпасть
	return data[(cy * Core.WW + cx) * 2]


func is_solid_cell(cx: int, cy: int) -> bool:
	return Core.is_solid(get_mat(cx, cy))


func solid_at_px(x: float, y: float) -> bool:
	return is_solid_cell(int(floor(x / Core.CELL)), int(floor(y / Core.CELL)))


func set_mat(cx: int, cy: int, m: int) -> void:
	if cx < 0 or cy < 0 or cx >= Core.WW or cy >= Core.WH:
		return
	data[(cy * Core.WW + cx) * 2] = m
	WorldGen.relight_column(data, cx)   # свет ниже правки надо пересчитать
	_mark_dirty_column(cx, cy)


# Копание кистью, как кирка 9×9 в браузерной версии. Возвращает, что выпало:
# {"dirt": 12, "stone": 3}
func dig(cx: int, cy: int, radius: int, max_hard: float) -> Dictionary:
	var drops := {}
	var cols := {}
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			if dx * dx + dy * dy > radius * radius:
				continue
			var x := cx + dx
			var y := cy + dy
			var m := get_mat(x, y)
			if m == Core.AIR:
				continue
			var info: Dictionary = Core.MATS[m]
			if float(info.hard) > max_hard:
				continue               # инструмент не берёт эту породу
			data[(y * Core.WW + x) * 2] = Core.AIR
			cols[x] = true
			var d: String = info.drop
			if d != "":
				drops[d] = int(drops.get(d, 0)) + 1
	for x in cols.keys():
		WorldGen.relight_column(data, x)
		_mark_dirty_column(x, cy)
	return drops


func place(cx: int, cy: int, m: int) -> bool:
	if get_mat(cx, cy) != Core.AIR:
		return false
	set_mat(cx, cy, m)
	return true


# Высота поверхности в пикселях — нужна камере и появлению игрока
func surface_px(x: float) -> float:
	var cx := clampi(int(floor(x / Core.CELL)), 0, Core.WW - 1)
	return float(surface[cx]) * Core.CELL


# ---- тайлы ----
func _make_tiles() -> void:
	var t0 := Time.get_ticks_msec()
	_load_textures()
	var mats := _material_arrays()
	var across := int(ceil(float(Core.WW) / TILE_W))
	var down := int(ceil(float(Core.WH) / TILE_H))
	for ty in down:
		for tx in across:
			var ox := tx * TILE_W
			var oy := ty * TILE_H
			var tw := mini(TILE_W, Core.WW - ox)
			var th := mini(TILE_H, Core.WH - oy)
			# поля обрезаем на границах мира: за ними данных нет
			var px0 := maxi(ox - PAD, 0)
			var py0 := maxi(oy - PAD, 0)
			var px1 := mini(ox + tw + PAD, Core.WW)
			var py1 := mini(oy + th + PAD, Core.WH)
			var iw := px1 - px0
			var ih := py1 - py0

			var img := Image.create_from_data(iw, ih, false, Image.FORMAT_RG8, _tile_bytes(px0, py0, px1, py1))
			var tex := ImageTexture.create_from_image(img)

			var mat := ShaderMaterial.new()
			mat.shader = _shader
			mat.set_shader_parameter("tex_cells", Vector2(iw, ih))
			mat.set_shader_parameter("inner_from", Vector2(ox - px0, oy - py0))
			mat.set_shader_parameter("inner_to", Vector2(ox - px0 + tw, oy - py0 + th))
			mat.set_shader_parameter("tile_origin", Vector2(ox, oy))
			mat.set_shader_parameter("mat_col", mats.col)
			mat.set_shader_parameter("mat_ore", mats.ore)
			mat.set_shader_parameter("mat_meta", mats.meta)
			mat.set_shader_parameter("mat_tex", mats.tex)
			mat.set_shader_parameter("tex_color", _tex_color)
			mat.set_shader_parameter("tex_normal", _tex_normal)
			mat.set_shader_parameter("grid", tex)
			# та же текстура вторым входом, но со сглаживанием: так читается свет
			mat.set_shader_parameter("grid_lin", tex)

			var spr := Sprite2D.new()
			spr.texture = tex
			spr.centered = false
			spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			spr.position = Vector2(px0 * Core.CELL, py0 * Core.CELL)
			spr.scale = Vector2(Core.CELL, Core.CELL)
			spr.material = mat
			add_child(spr)

			_tiles.append({
				"sprite": spr, "image": img, "texture": tex, "material": mat,
				"px0": px0, "py0": py0, "px1": px1, "py1": py1,
				"ox": ox, "oy": oy, "tw": tw, "th": th,
			})
	print("[мир] тайлов: ", _tiles.size(), ", собраны за ", Time.get_ticks_msec() - t0, " мс")


# Строки тайла — непрерывные куски общего массива, поэтому копируются срезами,
# а не по пикселю: сборка тайла выходит в доли миллисекунды.
func _tile_bytes(px0: int, py0: int, px1: int, py1: int) -> PackedByteArray:
	var out := PackedByteArray()
	var row_bytes := (px1 - px0) * 2
	for y in range(py0, py1):
		var from := (y * Core.WW + px0) * 2
		out.append_array(data.slice(from, from + row_bytes))
	return out


# Правка одной частицы гасит или открывает свет во всей колонке ниже, поэтому
# перезалить надо каждый тайл, который эту колонку содержит — включая поля.
func _mark_dirty_column(cx: int, _cy: int) -> void:
	for i in _tiles.size():
		var t: Dictionary = _tiles[i]
		if cx >= int(t.px0) and cx < int(t.px1):
			_dirty_tiles[i] = true


func _process(_dt: float) -> void:
	if _dirty_tiles.is_empty():
		return
	for i in _dirty_tiles.keys():
		var t: Dictionary = _tiles[i]
		var img: Image = t.image
		img.set_data(t.px1 - t.px0, t.py1 - t.py0, false, Image.FORMAT_RG8,
			_tile_bytes(t.px0, t.py0, t.px1, t.py1))
		(t.texture as ImageTexture).update(img)
	_dirty_tiles.clear()


func set_uniform(name: String, value: Variant) -> void:
	for t in _tiles:
		(t.material as ShaderMaterial).set_shader_parameter(name, value)


# Собирает слои текстур в два массива: цвет и нормали. Если какого-то файла нет,
# слой заменяется ближайшим по смыслу, чтобы игра всё равно запустилась.
func _load_textures() -> void:
	var colors: Array[Image] = []
	var normals: Array[Image] = []
	var fallback := {"metal": "concrete", "gravel": "clay", "bark": "wood"}
	for lname: String in TEX_LAYERS:
		var use: String = lname
		if not FileAccess.file_exists("res://textures/%s_color.jpg" % use):
			use = str(fallback.get(lname, "rock"))
			print("[текстуры] нет «", lname, "», беру «", use, "»")
		_layer_of[lname] = colors.size()
		colors.append(_load_image("res://textures/%s_color.jpg" % use))
		normals.append(_load_image("res://textures/%s_normal.jpg" % use))
	_tex_color = Texture2DArray.new()
	_tex_color.create_from_images(colors)
	_tex_normal = Texture2DArray.new()
	_tex_normal.create_from_images(normals)
	print("[текстуры] слоёв: ", colors.size(), " по ", colors[0].get_width(), "×", colors[0].get_height())


func _load_image(path: String) -> Image:
	var tex: Texture2D = load(path)
	var img := tex.get_image()
	# в массив идут только несжатые кадры одного формата
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGB8)
	img.generate_mipmaps()
	return img


func _material_arrays() -> Dictionary:
	var col := PackedVector4Array()
	var ore := PackedVector4Array()
	var meta := PackedVector4Array()
	var tex := PackedVector4Array()
	for i in 32:
		if i < Core.MAT_COUNT:
			var m: Dictionary = Core.MATS[i]
			var o: Color = m.ore
			var kind: int = m.kind
			var t: Color = _tint(m.c)
			col.append(Vector4(t.r, t.g, t.b, 1.0))
			ore.append(Vector4(o.r, o.g, o.b, 1.0))
			meta.append(Vector4(float(m["var"]) / 255.0 * 2.0, float(kind),
				_gloss(kind), _relief(kind)))
			var lt: Array = _layer_for(i)
			tex.append(Vector4(float(lt[0]), float(lt[1]), 0.0, 0.0))
		else:
			col.append(Vector4(1, 1, 1, 1))
			ore.append(Vector4(0, 0, 0, 1))
			meta.append(Vector4(0, 0, 0, 0))
			tex.append(Vector4(0, 12, 0, 0))
	return {"col": col, "ore": ore, "meta": meta, "tex": tex}


# Подкраска текстуры. Фотография сама несёт яркость и контраст, поэтому от цвета
# породы берём только оттенок: делим на собственную светлоту и наполовину
# смешиваем с белым. Иначе прежняя тусклая палитра погасила бы всю текстуру.
func _tint(c: Color) -> Color:
	var luma: float = maxf(0.08, 0.299 * c.r + 0.587 * c.g + 0.114 * c.b)
	var hue := Color(c.r / luma, c.g / luma, c.b / luma)
	return Color(1, 1, 1).lerp(hue, 0.55)


# Какой слой текстуры и сколько частиц занимает одна плитка.
# Крупная плитка — спокойная поверхность, мелкая — частая деталь.
func _layer_for(m: int) -> Array:
	match m:
		Core.GRASS: return [_layer_of.grass, 10]
		Core.DIRT, Core.FARM: return [_layer_of.dirt, 12]
		Core.CLAY: return [_layer_of.clay, 14]
		Core.STONE, Core.COAL, Core.IRON, Core.COPPER: return [_layer_of.rock, 16]
		Core.CONCRETE, Core.BUILD_S, Core.BG_CONC, Core.GLASSW: return [_layer_of.concrete, 20]
		Core.PLANK, Core.LADDER, Core.WALL_W, Core.FLOOR_W, Core.ROOF_W, \
		Core.DOOR, Core.DOOR_OPEN, Core.BUILD_W, Core.BG_WOOD: return [_layer_of.wood, 8]
		Core.TRUNK: return [_layer_of.bark, 10]
		Core.LEAF: return [_layer_of.grass, 6]
		Core.METAL, Core.REBAR, Core.BUILD_M, Core.BG_METAL: return [_layer_of.metal, 10]
		Core.ASH: return [_layer_of.gravel, 12]
		Core.WATER: return [_layer_of.rock, 18]
		_: return [_layer_of.rock, 14]


# Блеск: насколько порода даёт солнечный блик
func _gloss(kind: int) -> float:
	match kind:
		Core.K_WATER: return 1.0
		Core.K_GLASS: return 0.9
		Core.K_METAL: return 0.55
		Core.K_ORE: return 0.4
		Core.K_CRACK: return 0.18
		Core.K_WOOD, Core.K_BARK: return 0.12
		_: return 0.06


# Рельеф: насколько сильно шум мнёт нормаль. Камень шершавый, стекло гладкое.
func _relief(kind: int) -> float:
	match kind:
		Core.K_CRACK: return 1.15
		Core.K_BARK: return 1.1
		Core.K_ASH, Core.K_LEAF: return 0.95
		Core.K_PLAIN, Core.K_ORE: return 0.9
		Core.K_GRASS: return 0.75
		Core.K_WOOD: return 0.6
		Core.K_METAL: return 0.45
		Core.K_WATER: return 0.3
		Core.K_GLASS: return 0.2
		Core.K_BG: return 0.3
		_: return 0.8


# Освещённость точки от неба — нужна лампе игрока и подсветке фигуры
func light_at_px(x: float, y: float) -> float:
	var cx := clampi(int(floor(x / Core.CELL)), 0, Core.WW - 1)
	var cy := clampi(int(floor(y / Core.CELL)), 0, Core.WH - 1)
	return float(data[(cy * Core.WW + cx) * 2 + 1]) / 255.0

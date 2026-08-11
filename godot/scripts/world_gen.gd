# world_gen.gd — генерация мира. Перенос World.generate из js/world.js:
# рельеф по локациям, слои породы, пещеры, рудные жилы, лес и руины дома,
# в которых игрок просыпается.
class_name WorldGen

# Сглаженный одномерный шум — тот же приём, что makeNoise1 в браузерной версии
class Noise1:
	var grad := PackedFloat32Array()

	func _init(seed_v: int) -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_v
		grad.resize(4096)
		for i in 4096:
			grad[i] = rng.randf() * 2.0 - 1.0

	func at(x: float) -> float:
		var i := int(floor(x))
		var f := x - float(i)
		var a := grad[i & 4095]
		var b := grad[(i + 1) & 4095]
		var t := f * f * (3.0 - 2.0 * f)
		return a + (b - a) * t


# Возвращает {"data": PackedByteArray, "surface": PackedInt32Array, "spawn": Vector2}
static func generate(seed_v: int) -> Dictionary:
	var t0 := Time.get_ticks_msec()
	var n1 := Noise1.new(seed_v)
	var n2 := Noise1.new(seed_v + 7)
	var n3 := Noise1.new(seed_v + 31)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v + 5

	var cave := FastNoiseLite.new()
	cave.seed = seed_v + 99
	cave.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	cave.frequency = 0.022
	cave.fractal_octaves = 2

	var data := PackedByteArray()
	data.resize(Core.WW * Core.WH * 2)   # 2 байта на частицу: порода и свет

	# ---- рельеф ----
	var surface := PackedInt32Array()
	surface.resize(Core.WW)
	for x in Core.WW:
		var z := Core.zone_at_cell(x)
		var amp: float = z.amp
		var h := float(Core.SURFACE_Y) + (n1.at(x / 210.0) * 26.0 + n1.at(x / 74.0) * 11.0 + n2.at(x / 23.0) * 4.5 + n3.at(x / 8.0) * 1.5) * amp
		surface[x] = int(round(h))
	# сглаживание: на пиле игрок цепляется ногами
	for _pass in 2:
		var cp := surface.duplicate()
		for x in range(1, Core.WW - 1):
			surface[x] = int(round((cp[x - 1] + cp[x] * 2 + cp[x + 1]) / 4.0))

	# ---- слои породы ----
	for x in Core.WW:
		var s: int = surface[x]
		var dirt_d := 4 + int(n2.at(x / 14.0) * 2.0)
		var clay_d := 14 + int(n1.at(x / 40.0) * 5.0)
		var i := (s * Core.WW + x) * 2
		for y in range(s, Core.WH):
			var d := y - s
			var m := Core.STONE
			if d == 0:
				m = Core.GRASS
			elif d < dirt_d:
				m = Core.DIRT
			elif d < clay_d:
				m = Core.CLAY
			data[i] = m
			i += Core.WW * 2

	# ---- пещеры: их не копали, они уже есть ----
	for x in Core.WW:
		var y0: int = surface[x] + 70
		var i := (y0 * Core.WW + x) * 2
		for y in range(y0, Core.WH - 4):
			var v := cave.get_noise_2d(float(x), float(y) * 1.5)
			if v > 0.18:
				data[i] = Core.AIR
			i += Core.WW * 2

	# ---- рудные жилы ----
	var veins := [
		{"m": Core.COAL, "count": 220, "min_y": 16, "len": 26},
		{"m": Core.IRON, "count": 150, "min_y": 34, "len": 20},
		{"m": Core.COPPER, "count": 120, "min_y": 26, "len": 18},
	]
	for v in veins:
		for _i in int(v.count):
			var x := rng.randi_range(0, Core.WW - 1)
			var span: int = Core.WH - surface[x] - int(v.min_y) - 6
			if span <= 1:
				continue
			var fx := float(x)
			var fy := float(surface[x] + int(v.min_y) + rng.randi_range(0, span))
			var ang := rng.randf() * TAU
			var steps := 6 + int(rng.randf() * float(v.len))
			for _s in steps:
				ang += (rng.randf() - 0.5) * 0.8
				fx += cos(ang)
				fy += sin(ang)
				var r := 1.0 + rng.randf() * 1.6
				for dx in range(-2, 3):
					for dy in range(-2, 3):
						if float(dx * dx + dy * dy) > r * r:
							continue
						var cx := int(fx) + dx
						var cy := int(fy) + dy
						if cx < 0 or cy < 0 or cx >= Core.WW or cy >= Core.WH:
							continue
						var idx := (cy * Core.WW + cx) * 2
						if data[idx] == Core.STONE:
							data[idx] = int(v.m)

	_scatter_surface(data, surface, rng)
	_grow_forest(data, surface, rng)
	_place_ruins(data, surface, 3250)
	_bake_light(data)

	var spawn_x := 3250
	var spawn := Vector2(spawn_x * Core.CELL, (surface[spawn_x] - 1) * Core.CELL)
	print("[мир] сгенерирован за ", Time.get_ticks_msec() - t0, " мс")
	return {"data": data, "surface": surface, "spawn": spawn}


# Поверхность не должна быть ровной линией: раскидываем валуны, гравийные
# наносы, обломки бетона и сухие кусты. Именно эта мелочь отличает землю от
# закрашенной плиты, особенно рядом с фотографическим фоном.
static func _scatter_surface(data: PackedByteArray, surface: PackedInt32Array, rng: RandomNumberGenerator) -> void:
	var x := 4
	while x < Core.WW - 4:
		x += rng.randi_range(6, 26)
		var top: int = surface[x]
		var roll := rng.randf()
		if roll < 0.3:
			# валун: несколько частиц камня горкой
			var r := rng.randi_range(1, 3)
			for dy in range(-r, 1):
				for dx in range(-r, r + 1):
					if dx * dx + dy * dy * 2 <= r * r:
						_put_if_air(data, x + dx, top - 1 + dy, Core.STONE)
		elif roll < 0.5:
			# гравийный нанос — широкий и низкий
			var w := rng.randi_range(3, 9)
			for dx in range(-w, w + 1):
				var hh := int(round(float(w - absi(dx)) * 0.35))
				for dy in range(0, hh):
					_put_if_air(data, x + dx, top - 1 - dy, Core.ASH)
		elif roll < 0.62:
			# обломок бетонной плиты, лежит косо
			var l := rng.randi_range(4, 11)
			var dir := 1 if rng.randf() < 0.5 else -1
			for i in l:
				var yy := top - 1 - int(float(i) * 0.4)
				_put_if_air(data, x + i * dir, yy, Core.CONCRETE)
				_put_if_air(data, x + i * dir, yy + 1, Core.CONCRETE)
		elif roll < 0.72:
			# ржавая арматура торчком
			var hgt := rng.randi_range(3, 8)
			for dy in hgt:
				_put_if_air(data, x, top - 1 - dy, Core.REBAR)
		elif roll < 0.86:
			# сухой куст
			var hgt2 := rng.randi_range(2, 5)
			for dy in hgt2:
				_put_if_air(data, x, top - 1 - dy, Core.TRUNK)
			for dx in range(-2, 3):
				for dy in range(-2, 1):
					if rng.randf() < 0.45:
						_put_if_air(data, x + dx, top - hgt2 + dy, Core.LEAF)


# ЛЕС.
#
# Раньше здесь стояли одиночные стволы с редкими кронами — потому и выглядело
# палками, торчащими из земли. Настоящий лес читается не отдельными деревьями,
# а сплошной массой: кроны перекрываются и смыкаются в полог, стволы стоят
# плотно и на разной глубине, между ними подлесок, а сквозь полог пробиваются
# отдельные просветы. Поэтому:
#   - деревья через каждые 3-7 частиц, а не через 9-18;
#   - три яруса по высоте, чтобы полог был толстым, а не плоской строчкой;
#   - кроны широкие и сросшиеся, ствол 2-3 частицы с расширением у корня;
#   - подлесок и кусты по всей земле.
static func _grow_forest(data: PackedByteArray, surface: PackedInt32Array, rng: RandomNumberGenerator) -> void:
	for z in Core.ZONES:
		if z.id != "forest":
			continue
		var x0: int = int(z.x0)
		var x1: int = int(z.x1)

		# ---- подлесок по всей земле: кусты, поросль, валежник ----
		var ux := x0
		while ux < x1:
			ux += rng.randi_range(1, 3)
			var utop: int = surface[ux]
			var uh := rng.randi_range(1, 4)
			for dy in uh:
				_put_if_air(data, ux, utop - 1 - dy, Core.TRUNK)
			for dx in range(-2, 3):
				for dy in range(-3, 1):
					if rng.randf() < 0.5:
						_put_if_air(data, ux + dx, utop - uh + dy, Core.LEAF)

		# ---- деревья: три яруса, кроны смыкаются в полог ----
		var x := x0 + 4
		while x < x1 - 4:
			x += rng.randi_range(3, 7)
			var top: int = surface[x]
			# ярус решает высоту: подрост, средние, вышедшие в первый ярус
			var tier := rng.randf()
			var hgt: int
			if tier < 0.32:
				hgt = rng.randi_range(18, 30)
			elif tier < 0.78:
				hgt = rng.randi_range(34, 52)
			else:
				hgt = rng.randi_range(56, 78)
			var half := 1 if hgt < 34 else (1 if rng.randf() < 0.5 else 2)

			# ствол: к корню расширяется, выше сужается и слегка ведёт в сторону
			var lean := (rng.randf() - 0.5) * 0.06
			for y in range(top - hgt, top + 1):
				var up_frac := float(top - y) / float(hgt)
				var w := half
				if up_frac < 0.12:
					w = half + 1            # комель
				elif up_frac > 0.8:
					w = maxi(0, half - 1)   # вершина
				var sx := x + int(round(lean * float(top - y)))
				for dx in range(-w, w + 1):
					_put(data, sx + dx, y, Core.TRUNK)

			# сучья: от них полог выглядит связанным, а не набором шаров
			var branches := rng.randi_range(3, 7)
			for _b in branches:
				var by := top - rng.randi_range(int(float(hgt) * 0.45), hgt - 2)
				var dir := 1 if rng.randf() < 0.5 else -1
				var blen := rng.randi_range(4, 11)
				for i in blen:
					var bx := x + dir * i
					var byy := by - int(float(i) * rng.randf_range(0.15, 0.5))
					_put_if_air(data, bx, byy, Core.TRUNK)
					# листва вокруг сука
					for dx in range(-2, 3):
						for dy in range(-2, 3):
							if rng.randf() < 0.55:
								_put_if_air(data, bx + dx, byy + dy, Core.LEAF)

			# крона: широкая, вытянутая, с рваным краем и просветами
			var cy := top - hgt
			var rx := rng.randi_range(7, 14)
			var ry := rng.randi_range(6, 11)
			for dy in range(-ry, ry + 2):
				for dx in range(-rx, rx + 1):
					var d := sqrt(pow(float(dx) / float(rx), 2.0) + pow(float(dy) / float(ry), 2.0))
					# край рвём шумом, внутри оставляем редкие окна
					if d < 0.72 + rng.randf() * 0.42 and rng.randf() > 0.06:
						_put_if_air(data, x + dx, cy + dy, Core.LEAF)
			# нижняя бахрома кроны, чтобы полог не обрывался ровной линией
			for dx in range(-rx, rx + 1):
				var fringe := rng.randi_range(0, 4)
				for dy in fringe:
					_put_if_air(data, x + dx, cy + ry + dy, Core.LEAF)


# Руины дома, в которых мужик просыпается: часть стен стоит, крыша обвалилась
static func _place_ruins(data: PackedByteArray, surface: PackedInt32Array, cx: int) -> void:
	var w := 26
	var hgt := 16
	var x0 := cx - w / 2
	var base: int = surface[cx]
	# выравниваем пятно под дом, иначе стены висят в воздухе
	for x in range(x0 - 2, x0 + w + 2):
		for y in range(base, base + 3):
			_put(data, x, y, Core.DIRT)
		_put(data, x, base, Core.ASH)

	for x in range(x0, x0 + w):
		for y in range(base - hgt, base):
			var edge: bool = x == x0 or x == x0 + w - 1
			# правая половина обрушена — виден срез
			var broken: bool = x > x0 + w * 2 / 3 and y < base - hgt / 2
			if broken:
				continue
			if edge:
				_put(data, x, y, Core.CONCRETE)
			else:
				_put(data, x, y, Core.BG_WOOD)
	# пол и остатки перекрытия
	for x in range(x0 + 1, x0 + w - 1):
		_put(data, x, base - 1, Core.PLANK)
		if x < x0 + w * 2 / 3:
			_put(data, x, base - hgt, Core.PLANK)
	# завал обломков внутри
	for x in range(x0 + w * 2 / 3, x0 + w):
		for y in range(base - 4, base):
			_put(data, x, y, Core.ASH)


static func _put(data: PackedByteArray, x: int, y: int, m: int) -> void:
	if x < 0 or y < 0 or x >= Core.WW or y >= Core.WH:
		return
	data[(y * Core.WW + x) * 2] = m


static func _put_if_air(data: PackedByteArray, x: int, y: int, m: int) -> void:
	if x < 0 or y < 0 or x >= Core.WW or y >= Core.WH:
		return
	var i := (y * Core.WW + x) * 2
	if data[i] == Core.AIR:
		data[i] = m


# Свет от неба. Считаем один раз при генерации и потом обновляем колонками при
# копании: столб света идёт сверху вниз и гаснет в породе. Именно поэтому
# пещеры выходят чёрными, а у входа в них светло.
static func _bake_light(data: PackedByteArray) -> void:
	for x in Core.WW:
		var l := 1.0
		var i := x * 2 + 1
		for _y in Core.WH:
			data[i] = int(clamp(maxf(l, 0.14), 0.0, 1.0) * 255.0)
			var m := data[i - 1]
			if m == Core.AIR:
				l *= 0.9985
			elif m == Core.LEAF:
				l *= 0.985
			elif m == Core.WATER:
				l *= 0.972
			elif m == Core.GLASSW:
				l *= 0.97
			elif Core.is_solid(m):
				l *= 0.915
			else:
				l *= 0.95
			i += Core.WW * 2


# Пересчёт одной колонки — вызывается после копания
static func relight_column(data: PackedByteArray, x: int) -> void:
	var l := 1.0
	var i := x * 2 + 1
	for _y in Core.WH:
		data[i] = int(clamp(maxf(l, 0.14), 0.0, 1.0) * 255.0)
		var m := data[i - 1]
		if m == Core.AIR:
			l *= 0.9985
		elif m == Core.LEAF:
			l *= 0.985
		elif m == Core.WATER:
			l *= 0.972
		elif m == Core.GLASSW:
			l *= 0.97
		elif Core.is_solid(m):
			l *= 0.915
		else:
			l *= 0.95
		i += Core.WW * 2

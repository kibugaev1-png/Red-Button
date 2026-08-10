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
		var h := float(Core.SURFACE_Y) + (n1.at(x / 90.0) * 16.0 + n2.at(x / 28.0) * 5.0 + n3.at(x / 9.0) * 1.6) * amp
		surface[x] = int(round(h))
	# сглаживание: на пиле игрок цепляется ногами
	for _pass in 5:
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

	_grow_forest(data, surface, rng)
	_place_ruins(data, surface, 3250)
	_bake_light(data)

	var spawn_x := 3250
	var spawn := Vector2(spawn_x * Core.CELL, (surface[spawn_x] - 1) * Core.CELL)
	print("[мир] сгенерирован за ", Time.get_ticks_msec() - t0, " мс")
	return {"data": data, "surface": surface, "spawn": spawn}


# Лес: мёртвые сосны стоят стеной, древесину берут только здесь
static func _grow_forest(data: PackedByteArray, surface: PackedInt32Array, rng: RandomNumberGenerator) -> void:
	for z in Core.ZONES:
		if z.id != "forest":
			continue
		var x: int = int(z.x0) + 6
		while x < int(z.x1) - 6:
			x += rng.randi_range(9, 18)
			var top: int = surface[x]
			var hgt := rng.randi_range(26, 58)
			for y in range(top - hgt, top):
				_put(data, x, y, Core.TRUNK)
				if rng.randf() < 0.35:
					_put(data, x + (1 if rng.randf() < 0.5 else -1), y, Core.TRUNK)
			# сухие ветки и остатки кроны
			var cy := top - hgt
			var rad := rng.randi_range(5, 9)
			for dy in range(-rad, rad + 1):
				for dx in range(-rad, rad + 1):
					var d := sqrt(float(dx * dx) + float(dy * dy) * 1.7)
					if d < float(rad) * (0.7 + rng.randf() * 0.4):
						_put_if_air(data, x + dx, cy + dy, Core.LEAF)


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
			data[i] = int(clamp(l, 0.0, 1.0) * 255.0)
			var m := data[i - 1]
			if m == Core.AIR:
				l *= 0.9985
			elif m == Core.LEAF:
				l *= 0.93
			elif m == Core.WATER:
				l *= 0.96
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
		data[i] = int(clamp(l, 0.0, 1.0) * 255.0)
		var m := data[i - 1]
		if m == Core.AIR:
			l *= 0.9985
		elif m == Core.LEAF:
			l *= 0.93
		elif m == Core.WATER:
			l *= 0.96
		elif m == Core.GLASSW:
			l *= 0.97
		elif Core.is_solid(m):
			l *= 0.915
		else:
			l *= 0.95
		i += Core.WW * 2

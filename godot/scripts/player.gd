# player.gd — физика и отрисовка мужика в противогазе.
#
# Физика перенесена из js/player.js один в один: те же 13×54 пикселя тела, тот
# же шаг 1,65 пикселя за кадр и прыжок −5,4, те же столкновения по частицам, а
# не через движковые тела. Поэтому ощущение управления не меняется, но выводим
# персонажа уже векторной отрисовкой со сглаживанием.
extends Node2D
class_name Player

signal health_changed(current: float, maximum: float)
signal damaged(amount: float)
signal died

const W := 13.0
const H := 54.0
const SPEED := 1.65
const JUMP := -5.4
const SPRINT := 1.55

var terrain: Terrain
var vx := 0.0
var vy := 0.0
var on_ground := false
var on_ladder := false
var face := 1
var phase := 0.0
var fall_start := -1.0
var aim := 0.0
var dig_cool := 0.0

var hp := 100.0
var food := Core.FOOD_MAX
var water := Core.WATER_MAX
var rad := 0.0
var mask := false             # в начале противогаз лежит рядом со стартом
var filter_wear := 100.0
var _death_emitted := false


func setup(t: Terrain, at: Vector2) -> void:
	terrain = t
	position = at


func take_damage(amount: float) -> void:
	if amount <= 0.0 or hp <= 0.0:
		return
	hp = clampf(hp - amount, 0.0, 100.0)
	damaged.emit(amount)
	health_changed.emit(hp, 100.0)
	if hp <= 0.0 and not _death_emitted:
		_death_emitted = true
		died.emit()


func heal(amount: float) -> void:
	if amount <= 0.0 or hp <= 0.0:
		return
	hp = clampf(hp + amount, 0.0, 100.0)
	health_changed.emit(hp, 100.0)


func equip_mask() -> void:
	mask = true


func unequip_mask() -> void:
	mask = false


func reset_survivor() -> void:
	hp = 100.0
	food = Core.FOOD_MAX
	water = Core.WATER_MAX
	rad = 0.0
	mask = false
	filter_wear = 100.0
	_death_emitted = false
	health_changed.emit(hp, 100.0)


func _physics_process(dt: float) -> void:
	if hp <= 0.0:
		vx = 0.0
		return
	var ax := 0.0
	if Input.is_action_pressed(&"left"):
		ax -= 1.0
	if Input.is_action_pressed(&"right"):
		ax += 1.0
	var sprint: float = SPRINT if Input.is_action_pressed(&"sprint") else 1.0
	var in_water := terrain.get_mat(_cx(), _cy_at(-10.0)) == Core.WATER

	vx = ax * SPEED * sprint * (0.6 if in_water else 1.0)
	if ax != 0.0:
		face = int(sign(ax))
		phase += dt * (7.0 + abs(vx) * 3.2)
	else:
		phase += dt * 0.6

	on_ladder = terrain.get_mat(_cx(), _cy_at(-20.0)) == Core.LADDER \
		or terrain.get_mat(_cx(), _cy_at(-44.0)) == Core.LADDER
	if on_ladder:
		var up := Input.is_action_pressed(&"up")
		var dn := Input.is_action_pressed(&"down")
		vy = (-1.5 if up else (1.9 if dn else 0.0))
		vx *= 0.5
		phase += dt * 5.0
	else:
		if Input.is_action_pressed(&"up") and on_ground:
			vy = JUMP
			on_ground = false
		vy += Core.GRAV * (0.35 if in_water else 1.0)
		if in_water:
			vy = minf(vy, 1.2)
		vy = minf(vy, 14.0)

	_unstuck()
	_move_x(vx)
	_move_y(vy)
	_needs(dt)

	if dig_cool > 0.0:
		dig_cool -= dt
	queue_redraw()


func _cx() -> int:
	return int(floor(position.x / Core.CELL))


func _cy_at(dy: float) -> int:
	return int(floor((position.y + dy) / Core.CELL))


# ---- столкновения по частицам ----
func hits(x: float, y: float) -> bool:
	var x0 := int(floor((x - W * 0.5) / Core.CELL))
	var x1 := int(floor((x + W * 0.5 - 1.0) / Core.CELL))
	var y0 := int(floor((y - H) / Core.CELL))
	var y1 := int(floor((y - 1.0) / Core.CELL))
	for cy in range(y0, y1 + 1):
		for cx in range(x0, x1 + 1):
			if terrain.is_solid_cell(cx, cy):
				return true
	return false


func _move_x(dx: float) -> void:
	var nx := position.x + dx
	if not hits(nx, position.y):
		position.x = nx
		return
	# авто-подъём на уступ, но только если над головой есть куда встать:
	# иначе игрока заталкивало в перекрытие, как было в браузерной версии
	for up in range(1, 3):
		var ny := position.y - up * Core.CELL
		if hits(nx, ny) or hits(position.x, ny):
			continue
		position.x = nx
		position.y = ny
		return
	vx = 0.0


func _move_y(dy: float) -> void:
	var ny := position.y + dy
	if not hits(position.x, ny):
		position.y = ny
		on_ground = false
		if on_ladder:
			fall_start = -1.0
		elif dy > 0.0 and fall_start < 0.0:
			fall_start = position.y - dy
		return
	if dy > 0.0:
		while not hits(position.x, position.y + 1.0) and hits(position.x, ny):
			position.y += 1.0
		if fall_start >= 0.0:
			var fall := (position.y - fall_start) / Core.CELL
			if fall > 13.0:
				take_damage((fall - 10.0) * 1.5)
			fall_start = -1.0
		on_ground = true
	vy = 0.0


# страховка от застревания: тело внутри породы выдавливаем наружу
func _unstuck() -> void:
	if not hits(position.x, position.y):
		return
	for up in range(1, 15):
		if not hits(position.x, position.y - up * Core.CELL):
			position.y -= up * Core.CELL
			vy = 0.0
			return
	for dx in [-1, 1, -2, 2, -3, 3]:
		if not hits(position.x + dx * Core.CELL, position.y):
			position.x += dx * Core.CELL
			vy = 0.0
			return
	position.y = terrain.surface_px(position.x) - Core.CELL
	vy = 0.0


func _needs(dt: float) -> void:
	var before_hp := hp
	var sprinting: float = 1.5 if Input.is_action_pressed(&"sprint") and abs(vx) > 0.1 else 1.0
	food -= dt * (1.0 / 15.0) * sprinting
	water -= dt * (1.0 / 13.0) * sprinting
	food = clampf(food, 0.0, Core.FOOD_MAX)
	water = clampf(water, 0.0, Core.WATER_MAX)
	if not mask:
		rad += dt * 4.0
	else:
		if filter_wear > 0.0:
			filter_wear = maxf(0.0, filter_wear - dt * 0.22)
			rad = maxf(0.0, rad - dt * 0.5)
		else:
			rad += dt * 1.1
	var environmental_damage := 0.0
	if rad > 30.0:
		environmental_damage += dt * (rad - 30.0) * 0.02
	if food <= 0.0:
		environmental_damage += dt * 1.2
	if water <= 0.0:
		environmental_damage += dt * 1.8
	if environmental_damage > 0.0:
		take_damage(environmental_damage)
	if food > 120.0 and water > 120.0 and rad < 15.0:
		heal(dt * 0.8)
	if not is_equal_approx(before_hp, hp):
		queue_redraw()


# ---- отрисовка ----
# Мужик в противогазе: белая майка, тёмные штаны, армейские ботинки. Фигура
# небольшая — 54 пикселя, — поэтому важен силуэт и свет, а не мелкие детали:
# рисуем плотные формы с растяжкой цвета, кромочный свет со стороны солнца и
# тень под ногами. Вся фигура домножается на освещённость места, иначе в пещере
# персонаж светился бы сам по себе.

const SKIN := Color(0.72, 0.56, 0.44)
const SKIN_D := Color(0.5, 0.37, 0.29)
const TANK := Color(0.84, 0.83, 0.78)
const TANK_D := Color(0.5, 0.49, 0.47)
const PANTS := Color(0.19, 0.2, 0.24)
const PANTS_D := Color(0.1, 0.11, 0.14)
const BOOT := Color(0.21, 0.17, 0.14)
const BOOT_D := Color(0.11, 0.09, 0.08)
const MASK := Color(0.3, 0.32, 0.29)
const MASK_D := Color(0.16, 0.18, 0.16)
const LENS := Color(0.42, 0.5, 0.48)
const RIM := Color(1.0, 0.82, 0.55)      # солнце слева сверху

var _tint := Color(1, 1, 1)


func _draw() -> void:
	# освещённость места: в пещере фигура должна темнеть вместе с породой
	var lit: float = 0.34
	if terrain:
		lit = 0.3 + 0.7 * terrain.light_at_px(position.x, position.y - 30.0)
	_tint = Color(lit, lit * 0.98, lit * 0.94)

	var f := float(face)
	var moving: bool = abs(vx) > 0.05
	var walk: float = sin(phase) if moving else 0.0
	var walk2: float = sin(phase + PI) if moving else 0.0
	var bob: float = (abs(sin(phase * 2.0)) * 1.1) if moving else 0.0
	var breathe := sin(phase * 0.5) * 0.4

	var hip: float = -23.0 + bob
	var chest: float = -34.0 + bob
	var shoulder: float = -41.0 + bob + breathe * 0.3
	var head: float = -49.0 + bob + breathe * 0.3

	_shadow(lit)

	# дальняя нога и рука уходят в тень — так читается объём
	_leg(f, hip, walk2, 0.62)
	_arm(f, shoulder, walk, 0.6, true)
	_torso(f, chest, shoulder, hip)
	_leg(f, hip, walk, 1.0)
	_arm(f, shoulder, walk2, 1.0, false)
	_head(f, head, shoulder)


func _c(base: Color, k: float = 1.0) -> Color:
	return Color(base.r * _tint.r * k, base.g * _tint.g * k, base.b * _tint.b * k, base.a)


# Тень под ногами: без неё фигура висит в воздухе, даже если стоит на земле
func _shadow(lit: float) -> void:
	var w := 11.0 - absf(vy) * 0.1
	draw_set_transform(Vector2(0, -1), 0.0, Vector2(1, 0.28))
	draw_circle(Vector2.ZERO, w, Color(0.03, 0.02, 0.02, 0.34 * lit))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _leg(f: float, hip: float, swing: float, depth: float) -> void:
	var knee := Vector2((swing * 3.4) * f, hip * 0.42)
	var ankle := Vector2((swing * 6.2) * f, -3.0)
	# штанина: расширяется к низу, с продольной складкой
	var pts := PackedVector2Array([
		Vector2(-3.6 * f, hip), Vector2(2.6 * f, hip),
		knee + Vector2(2.9 * f, 0), ankle + Vector2(3.1 * f, 0),
		ankle + Vector2(-3.1 * f, 0), knee + Vector2(-3.0 * f, 0),
	])
	draw_colored_polygon(pts, _c(PANTS, depth))
	# складка и тень по заднему краю
	draw_line(Vector2(-0.4 * f, hip + 1.0), ankle + Vector2(-0.2 * f, -1.0), _c(PANTS_D, depth), 1.1)
	draw_line(Vector2(-3.4 * f, hip), ankle + Vector2(-2.9 * f, 0), _c(PANTS_D, depth * 0.9), 1.3)
	_boot(ankle, f, depth)


func _boot(at: Vector2, f: float, depth: float) -> void:
	# армейский ботинок: высокое голенище, выступающий носок, толстая подошва
	var top := at + Vector2(0, -1.0)
	var shaft := PackedVector2Array([
		top + Vector2(-3.4 * f, -3.0), top + Vector2(3.2 * f, -3.0),
		top + Vector2(3.6 * f, 1.4), top + Vector2(-3.6 * f, 1.4),
	])
	draw_colored_polygon(shaft, _c(BOOT, depth))
	var foot := PackedVector2Array([
		top + Vector2(-3.6 * f, 1.4), top + Vector2(5.6 * f, 1.4),
		top + Vector2(6.0 * f, 3.4), top + Vector2(-3.8 * f, 3.4),
	])
	draw_colored_polygon(foot, _c(BOOT, depth * 0.92))
	# подошва и рант
	draw_line(top + Vector2(-3.8 * f, 3.0), top + Vector2(6.0 * f, 3.0), _c(BOOT_D, depth), 1.6)
	draw_line(top + Vector2(-3.4 * f, 1.5), top + Vector2(5.4 * f, 1.5), _c(BOOT_D, depth * 0.8), 1.0)
	# шнуровка
	for i in 2:
		var y := top.y - 2.0 + i * 2.2
		draw_line(Vector2(top.x - 2.6 * f, y), Vector2(top.x + 2.4 * f, y), _c(BOOT_D, depth * 1.3), 0.9)
	# блик по носку со стороны солнца
	if f > 0.0:
		draw_line(top + Vector2(-3.6 * f, 1.6), top + Vector2(-3.6 * f, 3.2), _c(RIM, depth * 0.5), 1.0)


func _torso(f: float, chest: float, shoulder: float, hip: float) -> void:
	# майка: плечи шире бёдер, силуэт сужается к поясу
	var body := PackedVector2Array([
		Vector2(-5.4 * f, shoulder), Vector2(5.4 * f, shoulder),
		Vector2(6.0 * f, chest), Vector2(4.6 * f, hip + 1.0),
		Vector2(-4.6 * f, hip + 1.0), Vector2(-6.0 * f, chest),
	])
	draw_colored_polygon(body, _c(TANK))
	# тень по правому краю и складка на поясе
	draw_colored_polygon(PackedVector2Array([
		Vector2(2.4 * f, shoulder), Vector2(5.4 * f, shoulder),
		Vector2(6.0 * f, chest), Vector2(4.6 * f, hip + 1.0), Vector2(2.0 * f, hip + 1.0),
	]), _c(TANK_D, 0.85))
	# кромочный свет по левому краю — солнце
	draw_line(Vector2(-5.4 * f, shoulder + 0.5), Vector2(-5.9 * f, chest), _c(RIM, 0.9), 1.2)
	# бретели майки и вырез
	draw_line(Vector2(-3.4 * f, shoulder), Vector2(-2.6 * f, chest + 2.0), _c(TANK_D, 1.05), 1.0)
	draw_line(Vector2(3.2 * f, shoulder), Vector2(2.4 * f, chest + 2.0), _c(TANK_D, 0.9), 1.0)
	# ремень
	draw_line(Vector2(-4.6 * f, hip + 0.5), Vector2(4.6 * f, hip + 0.5), _c(BOOT), 2.0)
	draw_rect(Rect2(Vector2(-0.8 * f - 1.0, hip - 0.6), Vector2(2.2, 2.4)), _c(Color(0.42, 0.36, 0.24)))


func _arm(f: float, shoulder: float, swing: float, depth: float, back: bool) -> void:
	var sx := (-1.2 if back else 3.2) * f
	var elbow := Vector2(sx + (2.2 + swing * 2.6) * f, shoulder + 8.5)
	var hand := Vector2(sx + (1.4 + swing * 5.0) * f, shoulder + 17.0)
	# плечо и предплечье — голые, майка без рукавов
	draw_polyline(PackedVector2Array([Vector2(sx, shoulder + 1.5), elbow, hand]),
		_c(SKIN_D, depth * 0.7), 4.6, true)
	draw_polyline(PackedVector2Array([Vector2(sx, shoulder + 1.5), elbow, hand]),
		_c(SKIN, depth), 3.4, true)
	draw_circle(hand, 2.1, _c(SKIN, depth))          # кисть
	# перчаточная обмотка на кисти
	draw_line(hand + Vector2(-2.0 * f, -1.6), hand + Vector2(2.0 * f, -1.6), _c(BOOT, depth), 1.2)


# Противогаз — главный узнаваемый силуэт игры, поэтому он детальнее всего
func _head(f: float, head: float, shoulder: float) -> void:
	# шея
	draw_line(Vector2(0.4 * f, shoulder + 1.0), Vector2(0.8 * f, head + 4.0), _c(SKIN_D), 4.0)

	# капюшон-маска: скруглённая форма, вытянутая вперёд
	var hood := PackedVector2Array([
		Vector2(-4.6 * f, head - 3.4), Vector2(-1.6 * f, head - 5.4),
		Vector2(3.0 * f, head - 5.0), Vector2(5.8 * f, head - 1.8),
		Vector2(5.4 * f, head + 2.6), Vector2(2.2 * f, head + 5.2),
		Vector2(-2.6 * f, head + 4.6), Vector2(-5.0 * f, head + 1.4),
	])
	draw_colored_polygon(hood, _c(MASK))
	# затылок в тени, лоб на свету
	draw_colored_polygon(PackedVector2Array([
		Vector2(-4.6 * f, head - 3.4), Vector2(-2.8 * f, head - 4.6),
		Vector2(-2.2 * f, head + 4.6), Vector2(-5.0 * f, head + 1.4),
	]), _c(MASK_D, 1.0))
	draw_line(Vector2(-1.6 * f, head - 5.2), Vector2(3.0 * f, head - 4.8), _c(RIM, 0.85), 1.3)

	# СТЁКЛА.
	#
	# Раньше здесь было одно большое круглое стекло по центру лица — и человек
	# читался циклопом, потому что круглый глаз в середине головы это и есть
	# силуэт циклопа. У настоящего противогаза два стекла в отдельных обоймах,
	# разделённых переносицей. В профиль дальнее стекло видно частично, и именно
	# оно убирает «один глаз»: сразу понятно, что лицо повёрнуто.
	var near_eye := Vector2(3.2 * f, head - 0.9)
	var far_eye := Vector2(-0.5 * f, head - 1.4)

	# дальнее стекло: меньше, темнее, уходит за переносицу
	draw_set_transform(far_eye, 0.0, Vector2(1.0, 0.86))
	draw_circle(Vector2.ZERO, 2.3, _c(MASK_D, 0.7))
	draw_circle(Vector2.ZERO, 1.8, _c(LENS, 0.72))
	draw_circle(Vector2(-0.5 * f, -0.5), 0.6, Color(1, 1, 1, 0.22))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# переносица между обоймами
	draw_line(Vector2(1.1 * f, head - 2.6), Vector2(1.5 * f, head + 1.4), _c(MASK_D, 1.15), 1.8)

	# ближнее стекло: чуть овальное, с обоймой и двумя бликами
	draw_set_transform(near_eye, 0.0, Vector2(1.0, 0.88))
	draw_circle(Vector2.ZERO, 3.0, _c(MASK_D, 0.85))
	draw_circle(Vector2.ZERO, 2.4, _c(LENS, 1.12))
	draw_circle(Vector2(-0.9 * f, -0.9), 0.95, Color(1, 1, 1, 0.55 * _tint.r + 0.2))
	draw_circle(Vector2(1.0 * f, 0.9), 0.45, Color(1, 1, 1, 0.26))
	draw_arc(Vector2.ZERO, 3.0, 0.0, TAU, 18, _c(MASK_D, 0.55), 1.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# фильтр-коробка у рта и гофрированный шланг к груди
	var flt := Vector2(2.0 * f, head + 4.2)
	draw_colored_polygon(PackedVector2Array([
		flt + Vector2(-2.2 * f, -1.6), flt + Vector2(2.4 * f, -1.6),
		flt + Vector2(2.0 * f, 2.2), flt + Vector2(-1.8 * f, 2.2),
	]), _c(Color(0.24, 0.26, 0.23)))
	draw_line(flt + Vector2(-2.2 * f, -1.4), flt + Vector2(2.3 * f, -1.4), _c(RIM, 0.4), 0.9)
	for i in 3:
		var y := flt.y + 2.6 + i * 1.5
		draw_line(Vector2(flt.x - 1.6 * f, y), Vector2(flt.x + 1.4 * f, y + 0.6), _c(MASK_D, 1.2), 1.3)

	# ремни крепления назад
	draw_line(Vector2(-4.4 * f, head - 1.6), Vector2(-6.2 * f, head + 1.6), _c(MASK, 0.8), 1.5)
	draw_line(Vector2(-4.2 * f, head + 1.8), Vector2(-6.0 * f, head + 3.4), _c(MASK, 0.7), 1.3)

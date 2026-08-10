# hud.gd — шкалы и подписи. Рисуется вручную, чтобы вид совпадал с браузерной
# версией: здоровье, сытость и вода до 300, радиация появляется только когда есть.
extends Control

var game: Node

const PAD := 18.0
const BAR_W := 210.0
const BAR_H := 13.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	if game == null or game.player == null:
		return
	var p = game.player
	var font := ThemeDB.fallback_font
	var y := PAD

	_bar(Vector2(PAD, y), p.hp / 100.0, Color(0.78, 0.24, 0.22), "Здоровье", "%d" % roundi(p.hp))
	y += BAR_H + 8.0
	_bar(Vector2(PAD, y), p.food / Core.FOOD_MAX, Color(0.72, 0.56, 0.24), "Сытость", "%d" % roundi(p.food))
	y += BAR_H + 8.0
	_bar(Vector2(PAD, y), p.water / Core.WATER_MAX, Color(0.28, 0.56, 0.7), "Вода", "%d" % roundi(p.water))
	if p.rad > 0.5:
		y += BAR_H + 8.0
		_bar(Vector2(PAD, y), clampf(p.rad / 100.0, 0.0, 1.0), Color(0.5, 0.72, 0.2), "Радиация", "%d" % roundi(p.rad))

	# локация и часы — справа сверху
	var zone: Dictionary = Core.zone_at_px(p.position.x)
	var w := size.x
	var title: String = zone.name
	draw_string(font, Vector2(w - PAD - font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x, PAD + 12.0),
		title, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.9, 0.88, 0.84))
	var sub := "%d к/с   приближение %.2f" % [Engine.get_frames_per_second(), game.cam.zoom.x]
	draw_string(font, Vector2(w - PAD - font.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x, PAD + 30.0),
		sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.72, 0.7, 0.66))

	# подсказки внизу
	var help := "A/D — идти    W — прыжок и лестница вверх    S — вниз    Shift — бегом    ЛКМ — копать    колесо или щипок — приближение    M — противогаз    F1 — детализация"
	draw_string(font, Vector2(PAD, size.y - PAD), help, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.62, 0.6, 0.57))

	if not p.mask:
		var warn := "ПРОТИВОГАЗ СНЯТ"
		var ws := font.get_string_size(warn, HORIZONTAL_ALIGNMENT_LEFT, -1, 22)
		draw_string(font, Vector2((size.x - ws.x) * 0.5, size.y * 0.22), warn,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(0.85, 0.2, 0.16))


func _bar(at: Vector2, frac: float, col: Color, label: String, value: String) -> void:
	var font := ThemeDB.fallback_font
	var r := Rect2(at, Vector2(BAR_W, BAR_H))
	draw_rect(r.grow(1.0), Color(0, 0, 0, 0.55))
	draw_rect(r, Color(0.11, 0.11, 0.12, 0.9))
	var f := clampf(frac, 0.0, 1.0)
	if f > 0.0:
		draw_rect(Rect2(at, Vector2(BAR_W * f, BAR_H)), col)
		# блик по верху шкалы, чтобы она не выглядела плоской полосой
		draw_rect(Rect2(at, Vector2(BAR_W * f, BAR_H * 0.4)), Color(1, 1, 1, 0.12))
	draw_string(font, at + Vector2(6.0, BAR_H - 2.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.94, 0.93, 0.9))
	draw_string(font, at + Vector2(BAR_W - 30.0, BAR_H - 2.0), value, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.94, 0.93, 0.9))

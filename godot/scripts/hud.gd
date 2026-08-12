# hud.gd — шкалы и подписи. Рисуется вручную, чтобы вид совпадал с браузерной
# версией: здоровье, сытость и вода до 300, радиация появляется только когда есть.
extends Control

var game: Node

const PAD := 26.0
const BAR_W := 230.0
const BAR_H := 7.0

var interaction_prompt: String = ""
var notification: String = ""
var zone_title: String = ""
var _notification_alpha: float = 0.0
var _zone_alpha: float = 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS


func set_interaction_prompt(text: String) -> void:
	interaction_prompt = text
	queue_redraw()


func notify(text: String) -> void:
	notification = text
	_notification_alpha = 1.0
	queue_redraw()


func show_zone(text: String) -> void:
	zone_title = text
	_zone_alpha = 1.0
	queue_redraw()


func _process(delta: float) -> void:
	_notification_alpha = maxf(0.0, _notification_alpha - delta * 0.38)
	_zone_alpha = maxf(0.0, _zone_alpha - delta * 0.16)
	if _notification_alpha > 0.0 or _zone_alpha > 0.0:
		queue_redraw()


func _draw() -> void:
	if game == null or game.player == null:
		return
	var p = game.player
	var font := ThemeDB.fallback_font
	var y := PAD + 19.0
	# Тихая стеклянная подложка объединяет показатели, не превращая их в
	# стандартные прогресс-бары Godot.
	draw_style_box(UIStyle.panel(Color(0.025, 0.022, 0.02, 0.62), 8, Color(1, 1, 1, 0.08)), Rect2(PAD - 12, PAD - 10, BAR_W + 24, 104))
	draw_string(font, Vector2(PAD, PAD + 3), "СОСТОЯНИЕ", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.72, 0.68, 0.61))

	_bar(Vector2(PAD, y), p.hp / 100.0, Color(0.78, 0.24, 0.22), "Здоровье", "%d" % roundi(p.hp))
	y += BAR_H + 18.0
	_bar(Vector2(PAD, y), p.food / Core.FOOD_MAX, Color(0.72, 0.56, 0.24), "Сытость", "%d" % roundi(p.food))
	y += BAR_H + 18.0
	_bar(Vector2(PAD, y), p.water / Core.WATER_MAX, Color(0.28, 0.56, 0.7), "Вода", "%d" % roundi(p.water))
	if p.rad > 0.5:
		y += BAR_H + 18.0
		_bar(Vector2(PAD, y), clampf(p.rad / 100.0, 0.0, 1.0), Color(0.5, 0.72, 0.2), "Радиация", "%d" % roundi(p.rad))

	# локация и часы — справа сверху
	var zone: Dictionary = Core.zone_at_px(p.position.x)
	var w := size.x
	var title: String = zone.name.to_upper()
	draw_string(font, Vector2(w - PAD - font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x, PAD + 12.0),
		title, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.91, 0.88, 0.8))
	var sub := "%02d:%02d   •   %d к/с" % [int(game.day * 18.0 + 5.0) % 24, int(game.t * 4.0) % 60, Engine.get_frames_per_second()]
	draw_string(font, Vector2(w - PAD - font.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x, PAD + 31.0),
		sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.62, 0.59, 0.54))

	# подсказки внизу
	var help := "A D  ДВИЖЕНИЕ   W  ПРЫЖОК   SHIFT  БЕГ   E  ВЗЯТЬ/ИСПОЛЬЗОВАТЬ   I  ИНВЕНТАРЬ   1–6  ХОТБАР   R  ПЕРЕЗАРЯДКА"
	draw_string(font, Vector2(PAD, size.y - PAD), help, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.65, 0.62, 0.56, 0.78))
	_draw_hotbar(font)

	if interaction_prompt != "":
		var prompt_size := font.get_string_size(interaction_prompt, HORIZONTAL_ALIGNMENT_LEFT, -1, 14)
		var prompt_rect := Rect2((size.x - prompt_size.x) * 0.5 - 20, size.y * 0.78 - 22, prompt_size.x + 40, 42)
		draw_style_box(UIStyle.panel(Color(0.025, 0.02, 0.018, 0.84), 6, Color(0.78, 0.18, 0.14, 0.5)), prompt_rect)
		draw_string(font, Vector2((size.x - prompt_size.x) * 0.5, size.y * 0.78 + 5), interaction_prompt, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, UIStyle.PAPER)

	if _zone_alpha > 0.0:
		var alpha := minf(1.0, _zone_alpha) * minf(1.0, (1.0 - _zone_alpha) * 6.0 + 0.2)
		var zs := font.get_string_size(zone_title.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 28)
		draw_string(font, Vector2((size.x - zs.x) * 0.5, size.y * 0.25), zone_title.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color(0.94, 0.91, 0.84, alpha))
		draw_line(Vector2(size.x * 0.5 - 70, size.y * 0.25 + 13), Vector2(size.x * 0.5 + 70, size.y * 0.25 + 13), Color(0.7, 0.12, 0.09, alpha * 0.8), 1.0)

	if _notification_alpha > 0.0:
		var ns := font.get_string_size(notification, HORIZONTAL_ALIGNMENT_LEFT, -1, 13)
		draw_string(font, Vector2((size.x - ns.x) * 0.5, PAD + 12), notification, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.92, 0.88, 0.8, minf(1.0, _notification_alpha * 2.0)))

	if not p.mask:
		var warn := "ПРОТИВОГАЗ СНЯТ"
		var ws := font.get_string_size(warn, HORIZONTAL_ALIGNMENT_LEFT, -1, 22)
		draw_string(font, Vector2((size.x - ws.x) * 0.5, size.y * 0.22), warn,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(0.85, 0.2, 0.16))
	else:
		var filter_text := "ФИЛЬТР %d%%" % roundi(p.filter_wear)
		var fs := font.get_string_size(filter_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10)
		draw_string(font, Vector2(size.x - PAD - fs.x, PAD + 51), filter_text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.63, 0.7, 0.59))


func _draw_hotbar(font: Font) -> void:
	if game.get("inventory") == null or game.get("item_catalog") == null:
		return
	var inventory: RefCounted = game.get("inventory")
	var catalog: RefCounted = game.get("item_catalog")
	var selected := int(inventory.call("selected_hotbar"))
	var slot_size := Vector2(84.0, 48.0)
	var gap := 7.0
	var total := slot_size.x * 6.0 + gap * 5.0
	var start_x := (size.x - total) * 0.5
	var y := size.y - 86.0
	for index in 6:
		var rect := Rect2(start_x + index * (slot_size.x + gap), y, slot_size.x, slot_size.y)
		var active := index == selected
		draw_style_box(UIStyle.panel(
			Color(0.12, 0.045, 0.038, 0.9) if active else Color(0.025, 0.022, 0.02, 0.72),
			6, Color(0.85, 0.18, 0.14, 0.8) if active else Color(1, 1, 1, 0.1)
		), rect)
		draw_string(font, rect.position + Vector2(6, 13), str(index + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.64, 0.61, 0.55))
		var slot: Dictionary = inventory.call("get_slot", index)
		if slot.is_empty():
			continue
		var definition: Dictionary = catalog.call("get_item", StringName(slot.get("id", "")))
		var name := String(definition.get("name", slot.get("id", "")))
		if name.length() > 13:
			name = name.left(12) + "…"
		draw_string(font, rect.position + Vector2(7, 31), name, HORIZONTAL_ALIGNMENT_LEFT, slot_size.x - 14, 9, Color(0.9, 0.86, 0.78))
		var quantity := "×%d" % int(slot.get("quantity", 0))
		var qs := font.get_string_size(quantity, HORIZONTAL_ALIGNMENT_LEFT, -1, 9)
		draw_string(font, rect.end - Vector2(qs.x + 6, 7), quantity, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.78, 0.7, 0.53))
	if game.get("_pistol_magazine") != null:
		var selected_slot: Dictionary = inventory.call("get_selected")
		if StringName(selected_slot.get("id", "")) == &"pistol":
			var ammo := "%d / 12   •   запас %d" % [int(game.get("_pistol_magazine")), int(inventory.call("count", &"ammo9"))]
			var asize := font.get_string_size(ammo, HORIZONTAL_ALIGNMENT_LEFT, -1, 11)
			draw_string(font, Vector2((size.x - asize.x) * 0.5, y - 9), ammo, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.9, 0.8, 0.54))


func _bar(at: Vector2, frac: float, col: Color, label: String, value: String) -> void:
	var font := ThemeDB.fallback_font
	var r := Rect2(at, Vector2(BAR_W, BAR_H))
	draw_rect(r, Color(0.17, 0.16, 0.145, 0.88))
	var f := clampf(frac, 0.0, 1.0)
	if f > 0.0:
		draw_rect(Rect2(at, Vector2(BAR_W * f, BAR_H)), col)
	draw_string(font, at + Vector2(0, -5), label.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.78, 0.74, 0.68))
	var vs := font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, 10)
	draw_string(font, at + Vector2(BAR_W - vs.x, -5), value, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.9, 0.87, 0.8))

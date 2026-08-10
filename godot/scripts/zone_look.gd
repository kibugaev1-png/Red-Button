# zone_look.gd — вид каждой локации в одном месте.
#
# Здесь и только здесь настраивается, как выглядит локация: какой у неё фон,
# насколько густа дымка, каким цветом отдаёт земля и из каких текстур она
# сложена. Разнесено по локациям специально: над каждой можно работать
# независимо, не задевая соседние.
#
# Поля:
#   bg          — файл фона в backgrounds/ (полоса фотографической панорамы)
#   bg_exposure — яркость фона; больше 1 — светлее
#   bg_fog      — насколько даль тонет в дымке у горизонта, 0..1
#   bg_haze     — цвет этой дымки
#   bg_parallax — насколько фон отстаёт от камеры; меньше — дальше
#   bg_span     — мировых пикселей на оборот панорамы; больше — крупнее детали
#   ground_tint — общий оттенок породы в локации
#   layers      — чем заменить слои текстур: {"dirt": "clay"} и так далее
class_name ZoneLook

const LOOK := {
	"waste": {
		"bg": "waste", "bg_exposure": 1.0, "bg_fog": 0.42,
		"bg_haze": Color(0.68, 0.56, 0.46), "bg_parallax": 0.085, "bg_span": 9000.0,
		"ground_tint": Color(1.06, 0.98, 0.86), "layers": {},
	},
	"dead": {
		"bg": "dead", "bg_exposure": 0.92, "bg_fog": 0.55,
		"bg_haze": Color(0.6, 0.5, 0.44), "bg_parallax": 0.08, "bg_span": 9000.0,
		"ground_tint": Color(0.95, 0.88, 0.8), "layers": {"dirt": "gravel"},
	},
	"city": {
		"bg": "city", "bg_exposure": 0.98, "bg_fog": 0.38,
		"bg_haze": Color(0.62, 0.6, 0.58), "bg_parallax": 0.1, "bg_span": 8000.0,
		"ground_tint": Color(0.98, 0.98, 0.98), "layers": {},
	},
	"forest": {
		"bg": "forest", "bg_exposure": 1.0, "bg_fog": 0.34,
		"bg_haze": Color(0.6, 0.58, 0.46), "bg_parallax": 0.11, "bg_span": 7000.0,
		"ground_tint": Color(0.94, 1.0, 0.86), "layers": {},
	},
	"mine": {
		"bg": "mine", "bg_exposure": 0.95, "bg_fog": 0.4,
		"bg_haze": Color(0.58, 0.56, 0.56), "bg_parallax": 0.075, "bg_span": 10000.0,
		"ground_tint": Color(0.92, 0.93, 0.96), "layers": {"dirt": "rock", "clay": "gravel"},
	},
	"towers": {
		"bg": "towers", "bg_exposure": 0.95, "bg_fog": 0.46,
		"bg_haze": Color(0.6, 0.58, 0.6), "bg_parallax": 0.09, "bg_span": 8500.0,
		"ground_tint": Color(0.96, 0.95, 0.96), "layers": {"dirt": "gravel"},
	},
	"gap": {
		"bg": "waste", "bg_exposure": 1.0, "bg_fog": 0.42,
		"bg_haze": Color(0.66, 0.57, 0.48), "bg_parallax": 0.085, "bg_span": 9000.0,
		"ground_tint": Color(1.0, 0.97, 0.9), "layers": {},
	},
}


static func of(zone_id: String) -> Dictionary:
	return LOOK.get(zone_id, LOOK.gap)

# core.gd — размеры мира, породы, локации. Перенос js/core.js и таблицы MATS
# из js/world.js. Значения совпадают с браузерной версией, чтобы мир выглядел
# и ощущался так же, а разница была только в качестве картинки.
class_name Core

const CELL := 8          # размер частицы породы в пикселях
const WW := 8000         # ширина мира в частицах
const WH := 720          # высота мира в частицах
const GRAV := 0.42       # на кадр при 60 к/с, как в браузерной версии
const DAY_LEN := 600.0   # секунд в сутках
const FOOD_MAX := 300.0
const WATER_MAX := 300.0
const SURFACE_Y := 520   # средний уровень земли в частицах

# ---- породы ----
# Порядок обязан совпадать с M из js/world.js: id частицы идёт в текстуру
# как есть, и шейдер читает по нему цвет из массива.
const AIR := 0
const GRASS := 1
const DIRT := 2
const CLAY := 3
const STONE := 4
const COAL := 5
const IRON := 6
const COPPER := 7
const TRUNK := 8
const LEAF := 9
const CONCRETE := 10
const PLANK := 11
const WATER := 12
const FARM := 13
const REBAR := 14
const ASH := 15
const LADDER := 16
const WALL_W := 17
const FLOOR_W := 18
const ROOF_W := 19
const DOOR := 20
const DOOR_OPEN := 21
const METAL := 22
const BG_WOOD := 23
const BG_METAL := 24
const BUILD_W := 25
const BUILD_S := 26
const BUILD_M := 27
const GLASSW := 28
const BG_CONC := 29
const MAT_COUNT := 30

# Вид породы для шейдера: он решает, какую процедурную деталь рисовать.
const K_PLAIN := 0
const K_GRASS := 1
const K_CRACK := 2   # камень, бетон — трещины
const K_ORE := 3     # руда — вкрапления
const K_WOOD := 4    # доски, стены — продольные волокна
const K_BARK := 5    # ствол — вертикальная кора
const K_LEAF := 6    # листва — рваный край
const K_METAL := 7   # профлист — вертикальные рёбра
const K_GLASS := 8   # окно — блик
const K_WATER := 9
const K_ASH := 10
const K_BG := 11     # фоновая обшивка — тёмная, без объёма

# name, цвет, разброс тона, секунд копать, что падает, твёрдый ли, вид, цвет вкраплений
const MATS := [
	{"name": "Воздух", "c": Color8(0, 0, 0), "var": 0.0, "hard": 0.0, "drop": "", "solid": false, "kind": K_PLAIN, "ore": Color8(0, 0, 0)},
	{"name": "Трава", "c": Color8(82, 90, 48), "var": 22.0, "hard": 0.35, "drop": "dirt", "solid": true, "kind": K_GRASS, "ore": Color8(0, 0, 0)},
	{"name": "Земля", "c": Color8(66, 48, 32), "var": 18.0, "hard": 0.4, "drop": "dirt", "solid": true, "kind": K_PLAIN, "ore": Color8(0, 0, 0)},
	{"name": "Глина", "c": Color8(100, 66, 46), "var": 15.0, "hard": 0.6, "drop": "clay", "solid": true, "kind": K_PLAIN, "ore": Color8(0, 0, 0)},
	{"name": "Камень", "c": Color8(76, 78, 84), "var": 17.0, "hard": 1.1, "drop": "stone", "solid": true, "kind": K_CRACK, "ore": Color8(0, 0, 0)},
	{"name": "Уголь", "c": Color8(74, 74, 78), "var": 16.0, "hard": 1.3, "drop": "coal", "solid": true, "kind": K_ORE, "ore": Color8(34, 32, 36)},
	{"name": "Железная руда", "c": Color8(98, 92, 92), "var": 16.0, "hard": 1.7, "drop": "iron_ore", "solid": true, "kind": K_ORE, "ore": Color8(162, 104, 66)},
	{"name": "Медная руда", "c": Color8(94, 96, 94), "var": 16.0, "hard": 1.6, "drop": "copper_ore", "solid": true, "kind": K_ORE, "ore": Color8(92, 148, 120)},
	{"name": "Ствол", "c": Color8(78, 58, 42), "var": 18.0, "hard": 0.7, "drop": "wood", "solid": false, "kind": K_BARK, "ore": Color8(0, 0, 0)},
	{"name": "Листва", "c": Color8(74, 88, 52), "var": 30.0, "hard": 0.2, "drop": "stick", "solid": false, "kind": K_LEAF, "ore": Color8(0, 0, 0)},
	{"name": "Бетон", "c": Color8(124, 122, 116), "var": 14.0, "hard": 2.2, "drop": "concrete", "solid": true, "kind": K_CRACK, "ore": Color8(0, 0, 0)},
	{"name": "Доски", "c": Color8(126, 96, 62), "var": 14.0, "hard": 0.5, "drop": "plank", "solid": true, "kind": K_WOOD, "ore": Color8(0, 0, 0)},
	{"name": "Вода", "c": Color8(58, 96, 82), "var": 10.0, "hard": 0.0, "drop": "", "solid": false, "kind": K_WATER, "ore": Color8(0, 0, 0)},
	{"name": "Грядка", "c": Color8(62, 44, 30), "var": 16.0, "hard": 0.3, "drop": "dirt", "solid": true, "kind": K_PLAIN, "ore": Color8(0, 0, 0)},
	{"name": "Арматура", "c": Color8(104, 74, 58), "var": 12.0, "hard": 2.6, "drop": "scrap", "solid": true, "kind": K_METAL, "ore": Color8(0, 0, 0)},
	{"name": "Пепел", "c": Color8(96, 92, 88), "var": 24.0, "hard": 0.25, "drop": "", "solid": true, "kind": K_ASH, "ore": Color8(0, 0, 0)},
	{"name": "Лестница", "c": Color8(122, 92, 58), "var": 12.0, "hard": 0.3, "drop": "ladder", "solid": false, "kind": K_WOOD, "ore": Color8(0, 0, 0)},
	{"name": "Деревянная стена", "c": Color8(124, 92, 56), "var": 13.0, "hard": 0.55, "drop": "wood", "solid": true, "kind": K_WOOD, "ore": Color8(0, 0, 0)},
	{"name": "Деревянный пол", "c": Color8(132, 100, 62), "var": 13.0, "hard": 0.5, "drop": "wood", "solid": true, "kind": K_WOOD, "ore": Color8(0, 0, 0)},
	{"name": "Деревянная крыша", "c": Color8(110, 80, 50), "var": 14.0, "hard": 0.55, "drop": "wood", "solid": true, "kind": K_WOOD, "ore": Color8(0, 0, 0)},
	{"name": "Дверь", "c": Color8(118, 86, 52), "var": 10.0, "hard": 0.7, "drop": "", "solid": true, "kind": K_WOOD, "ore": Color8(0, 0, 0)},
	{"name": "Открытая дверь", "c": Color8(118, 86, 52), "var": 10.0, "hard": 0.7, "drop": "", "solid": false, "kind": K_WOOD, "ore": Color8(0, 0, 0)},
	{"name": "Профлист", "c": Color8(126, 128, 130), "var": 14.0, "hard": 2.0, "drop": "scrap", "solid": true, "kind": K_METAL, "ore": Color8(0, 0, 0)},
	{"name": "Обшивка", "c": Color8(64, 47, 30), "var": 10.0, "hard": 0.4, "drop": "", "solid": false, "kind": K_BG, "ore": Color8(0, 0, 0)},
	{"name": "Обшивка железом", "c": Color8(62, 64, 68), "var": 10.0, "hard": 0.4, "drop": "", "solid": false, "kind": K_BG, "ore": Color8(0, 0, 0)},
	{"name": "Деревянная постройка", "c": Color8(138, 98, 56), "var": 8.0, "hard": 0.9, "drop": "", "solid": true, "kind": K_WOOD, "ore": Color8(0, 0, 0)},
	{"name": "Каменная постройка", "c": Color8(124, 127, 132), "var": 8.0, "hard": 1.8, "drop": "", "solid": true, "kind": K_CRACK, "ore": Color8(0, 0, 0)},
	{"name": "Металлическая постройка", "c": Color8(110, 116, 122), "var": 8.0, "hard": 3.0, "drop": "", "solid": true, "kind": K_METAL, "ore": Color8(0, 0, 0)},
	{"name": "Окно", "c": Color8(96, 122, 132), "var": 10.0, "hard": 0.3, "drop": "", "solid": true, "kind": K_GLASS, "ore": Color8(0, 0, 0)},
	{"name": "Внутренняя стена", "c": Color8(58, 58, 60), "var": 8.0, "hard": 0.5, "drop": "", "solid": false, "kind": K_BG, "ore": Color8(0, 0, 0)},
]

# ---- локации ----
const ZONES := [
	{"id": "dead", "name": "Мёртвая зона", "x0": 200, "x1": 1000, "amp": 1.5, "build": false},
	{"id": "city", "name": "Мирный город", "x0": 1500, "x1": 2300, "amp": 0.0, "build": false},
	{"id": "waste", "name": "Пустошь", "x0": 2800, "x1": 3700, "amp": 1.1, "build": true},
	{"id": "forest", "name": "Лес", "x0": 4200, "x1": 5000, "amp": 1.3, "build": false},
	{"id": "mine", "name": "Шахта", "x0": 5500, "x1": 6300, "amp": 1.8, "build": true},
	{"id": "towers", "name": "Руины небоскрёбов", "x0": 6800, "x1": 7700, "amp": 1.2, "build": false},
]
const GAP_ZONE := {"id": "gap", "name": "Ничейная земля", "x0": 0, "x1": 0, "amp": 1.2, "build": true}

static func zone_at_cell(cx: int) -> Dictionary:
	for z in ZONES:
		if cx >= int(z.x0) and cx <= int(z.x1):
			return z
	return GAP_ZONE


static func zone_at_px(px: float) -> Dictionary:
	return zone_at_cell(int(floor(px / CELL)))


static func is_solid(m: int) -> bool:
	return m != AIR and bool(MATS[m].solid)

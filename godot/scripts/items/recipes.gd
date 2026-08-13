# recipes.gd — что из чего делается.
#
# Рецепты лежат таблицей, а не разбросаны по машинам: так дерево крафта видно
# целиком в одном месте, и тест целостности может пройти по нему и убедиться,
# что нигде нет ссылки на несуществующий предмет и нет замкнутого круга.
#
# Замкнутый круг — главная ловушка таких систем. Если волочильный станок делать
# из проводов, а провода — только на станке, игра встаёт намертво, и выясняется
# это уже за игрой. Порядок здесь выстроен так: печь топится углём и делается из
# голого камня, станок — из железа и камня без проводов, и только после него
# появляются провода. Тест это стережёт.
class_name Recipes

# Верстак не нужен: рецепты этой группы игрок собирает руками по клавише C.
# Иначе первую печь не из чего было бы сделать.
const HAND: Array[Dictionary] = [
	{
		"id": &"machine_furnace", "name": "Печь", "count": 1,
		"inputs": {&"stone": 20},
		"hint": "Топится углём. Плавит руду в слитки.",
	},
	{
		"id": &"machine_wire_drawer", "name": "Волочильный станок", "count": 1,
		"inputs": {&"iron_ingot": 6, &"stone": 8},
		"hint": "Тянет из медного слитка провода.",
	},
	{
		"id": &"machine_belt", "name": "Лента", "count": 2,
		"inputs": {&"plank": 2, &"scrap": 1},
		"hint": "Возит предметы. Тока не требует.",
	},
	{
		"id": &"machine_hydro", "name": "Гидрогенератор", "count": 1,
		"inputs": {&"iron_ingot": 8, &"wire": 6, &"plank": 4},
		"hint": "Ставится у воды. Даёт 30 Вт.",
	},
	{
		"id": &"machine_drill", "name": "Бур", "count": 1,
		"inputs": {&"iron_ingot": 10, &"wire": 4, &"plank": 2},
		"hint": "Грызёт породу под собой. 20 Вт.",
	},
	{
		"id": &"machine_assembler", "name": "Сборочная станция", "count": 1,
		"inputs": {&"iron_ingot": 10, &"wire": 6, &"plank": 4},
		"hint": "Кислота, аккумуляторы, снаряжение. 18 Вт.",
	},
	{
		"id": &"machine_purifier", "name": "Очиститель воды", "count": 1,
		"inputs": {&"iron_ingot": 6, &"wire": 4, &"plank": 2},
		"hint": "Ставится у воды. Даёт чистую воду. 10 Вт.",
	},
	{
		"id": &"machine_battery", "name": "Аккумуляторный блок", "count": 1,
		"inputs": {&"battery": 1, &"iron_ingot": 4, &"wire": 2},
		"hint": "Копит ток днём, отдаёт ночью.",
	},
	{
		"id": &"machine_fence", "name": "Электрозабор", "count": 4,
		"inputs": {&"iron_ingot": 2, &"wire": 2},
		"hint": "Бьёт того, кто коснётся. 5 Вт.",
	},
	{
		"id": &"bow", "name": "Лук", "count": 1,
		"inputs": {&"rag": 2, &"plank": 6},
		"hint": "Тихий. Урон растёт с натяжением.",
	},
	{
		"id": &"arrow", "name": "Стрелы", "count": 8,
		"inputs": {&"plank": 2, &"stone": 1},
		"hint": "Подбираются после промаха.",
	},
	{
		"id": &"ladder", "name": "Лестница", "count": 4,
		"inputs": {&"plank": 2},
		"hint": "Ставится на стену, по ней лазают.",
	},
]

# Печь топится углём и тока не требует. Это и разрывает круг «для тока нужен
# слиток, для слитка нужен ток», и даёт углю смысл — раньше он копался впустую.
const FURNACE: Array[Dictionary] = [
	{"id": &"copper_ingot", "inputs": {&"copper_ore": 1}, "count": 1, "seconds": 4.0},
	{"id": &"iron_ingot", "inputs": {&"iron_ore": 1}, "count": 1, "seconds": 5.0},
	{"id": &"lead_ingot", "inputs": {&"galena_ore": 1}, "count": 1, "seconds": 4.0},
]

const WIRE_DRAWER: Array[Dictionary] = [
	{"id": &"wire", "inputs": {&"copper_ingot": 1}, "count": 3, "seconds": 3.0},
]

const ASSEMBLER: Array[Dictionary] = [
	{"id": &"acid", "inputs": {&"sulfur": 2, &"clean_water": 1}, "count": 1, "seconds": 6.0},
	{"id": &"battery", "inputs": {&"lead_ingot": 4, &"acid": 1, &"plank": 2}, "count": 1, "seconds": 10.0},
]

# Сколько секунд работы печи даёт одна единица топлива.
const FUEL_SECONDS: Dictionary = {
	&"coal": 8.0,
	&"wood": 3.0,
	&"plank": 2.0,
	&"stick": 1.0,
}


static func hand_recipe(item_id: StringName) -> Dictionary:
	for recipe in HAND:
		if recipe.id == item_id:
			return recipe.duplicate(true)
	return {}


static func for_machine(machine_type: StringName) -> Array[Dictionary]:
	match machine_type:
		&"furnace":
			return FURNACE.duplicate(true)
		&"wire_drawer":
			return WIRE_DRAWER.duplicate(true)
		&"assembler":
			return ASSEMBLER.duplicate(true)
		_:
			return [] as Array[Dictionary]


# Первый рецепт, чьи входы целиком лежат во входном ящике машины.
static func match_recipe(machine_type: StringName, available: Dictionary) -> Dictionary:
	for recipe in for_machine(machine_type):
		var enough := true
		for item_id: Variant in recipe.inputs:
			if int(available.get(item_id, 0)) < int(recipe.inputs[item_id]):
				enough = false
				break
		if enough:
			return recipe
	return {}


static func fuel_seconds(item_id: StringName) -> float:
	return float(FUEL_SECONDS.get(item_id, 0.0))


# Все рецепты одним списком — для теста целостности.
static func all() -> Array[Dictionary]:
	var everything: Array[Dictionary] = []
	everything.append_array(HAND)
	everything.append_array(FURNACE)
	everything.append_array(WIRE_DRAWER)
	everything.append_array(ASSEMBLER)
	return everything

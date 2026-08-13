class_name ItemCatalog
extends RefCounted

const ITEMS: Dictionary = {
	&"gasmask": {"name": "Противогаз ГП-1", "max_stack": 1, "type": &"mask"},
	&"filter": {"name": "Фильтр", "max_stack": 8, "type": &"filter"},
	&"axe": {"name": "Металлический топор", "max_stack": 1, "type": &"tool"},
	&"pick": {"name": "Металлическая кирка", "max_stack": 1, "type": &"tool"},
	&"bandage": {"name": "Бинт", "max_stack": 20, "type": &"med"},
	&"pistol": {"name": "Пистолет 9 мм", "max_stack": 1, "type": &"gun"},
	&"ammo9": {"name": "Патроны 9 мм", "max_stack": 240, "type": &"ammo"},
	&"canteen": {"name": "Фляга", "max_stack": 4, "type": &"canteen"},
	&"can": {"name": "Тушёнка", "max_stack": 20, "type": &"food"},
	&"dirt": {"name": "Земля", "max_stack": 200, "type": &"material"},
	&"clay": {"name": "Глина", "max_stack": 200, "type": &"material"},
	&"stone": {"name": "Камень", "max_stack": 200, "type": &"material"},
	&"coal": {"name": "Уголь", "max_stack": 200, "type": &"material"},
	&"iron_ore": {"name": "Железная руда", "max_stack": 200, "type": &"material"},
	&"copper_ore": {"name": "Медная руда", "max_stack": 200, "type": &"material"},
	&"wood": {"name": "Древесина", "max_stack": 200, "type": &"material"},
	&"stick": {"name": "Палка", "max_stack": 200, "type": &"material"},
	&"concrete": {"name": "Бетон", "max_stack": 200, "type": &"material"},
	&"plank": {"name": "Доски", "max_stack": 200, "type": &"material"},
	&"scrap": {"name": "Металлолом", "max_stack": 200, "type": &"material"},
	&"ladder": {"name": "Лестница", "max_stack": 100, "type": &"place"},

	# ---- сырьё под электричество ----
	&"galena_ore": {"name": "Галенит", "max_stack": 200, "type": &"material"},
	&"sulfur": {"name": "Сера", "max_stack": 200, "type": &"material"},
	&"rag": {"name": "Тряпьё", "max_stack": 100, "type": &"material"},

	# ---- передел ----
	&"copper_ingot": {"name": "Медный слиток", "max_stack": 100, "type": &"material"},
	&"iron_ingot": {"name": "Железный слиток", "max_stack": 100, "type": &"material"},
	&"lead_ingot": {"name": "Свинцовый слиток", "max_stack": 100, "type": &"material"},
	&"wire": {"name": "Провод", "max_stack": 200, "type": &"place"},
	&"acid": {"name": "Серная кислота", "max_stack": 20, "type": &"material"},
	&"clean_water": {"name": "Чистая вода", "max_stack": 20, "type": &"drink"},
	&"battery": {"name": "Аккумулятор", "max_stack": 4, "type": &"material"},

	# ---- машины как предметы ----
	&"machine_furnace": {"name": "Печь", "max_stack": 8, "type": &"machine"},
	&"machine_belt": {"name": "Лента", "max_stack": 100, "type": &"machine"},
	&"machine_wire_drawer": {"name": "Волочильный станок", "max_stack": 8, "type": &"machine"},
	&"machine_drill": {"name": "Бур", "max_stack": 8, "type": &"machine"},
	&"machine_assembler": {"name": "Сборочная станция", "max_stack": 8, "type": &"machine"},
	&"machine_hydro": {"name": "Гидрогенератор", "max_stack": 8, "type": &"machine"},
	&"machine_battery": {"name": "Аккумуляторный блок", "max_stack": 8, "type": &"machine"},
	&"machine_purifier": {"name": "Очиститель воды", "max_stack": 8, "type": &"machine"},
	&"machine_fence": {"name": "Электрозабор", "max_stack": 50, "type": &"machine"},

	# ---- инструменты ----
	# Ручной бур лежит в руинах небоскрёбов уже заряженным: он ускоряет ломание
	# вчетверо, и давать его на старте значило бы обесценить кирку.
	&"handheld_drill": {"name": "Ручной бур", "max_stack": 1, "type": &"tool"},

	# ---- оружие ----
	&"bow": {"name": "Лук", "max_stack": 1, "type": &"bow"},
	&"arrow": {"name": "Стрелы", "max_stack": 120, "type": &"ammo"},
	&"shotgun": {"name": "Дробовик", "max_stack": 1, "type": &"gun"},
	&"rifle": {"name": "Винтовка", "max_stack": 1, "type": &"gun"},
	&"heavy": {"name": "Тяжёлое оружие", "max_stack": 1, "type": &"gun"},
	&"ammo_shell": {"name": "Дробь", "max_stack": 120, "type": &"ammo"},
	&"ammo_rifle": {"name": "Патроны 7,62", "max_stack": 120, "type": &"ammo"},
	&"ammo_heavy": {"name": "Патроны тяжёлые", "max_stack": 240, "type": &"ammo"},
}


func has_item(item_id: StringName) -> bool:
	return ITEMS.has(item_id)


func get_item(item_id: StringName) -> Dictionary:
	return ITEMS.get(item_id, {}).duplicate(true)


func max_stack(item_id: StringName) -> int:
	return int(ITEMS.get(item_id, {}).get("max_stack", 0))


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
}


func has_item(item_id: StringName) -> bool:
	return ITEMS.has(item_id)


func get_item(item_id: StringName) -> Dictionary:
	return ITEMS.get(item_id, {}).duplicate(true)


func max_stack(item_id: StringName) -> int:
	return int(ITEMS.get(item_id, {}).get("max_stack", 0))


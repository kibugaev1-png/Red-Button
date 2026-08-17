# weapon_catalog.gd — таблица оружия из спеки боя.
#
# Одна таблица на всех: игрок стреляет из подобранного дробовика ровно так же,
# как стрелял мародёр, у которого его сняли. Числа держатся здесь, а не в
# зомби, мародёре и игроке порознь, иначе они разъедутся при первой же правке.
class_name WeaponCatalog
extends RefCounted

# Перезарядка одна на всех: 1,8 секунды — то самое окно, ради которого игрок
# считает чужие выстрелы.
const RELOAD_TIME: float = 1.8
# Прицеливание мародёра перед выстрелом. Мгновенный огонь — не сложность, а
# несправедливость.
const AIM_TIME: float = 0.4
# Лук набирает полный урон за 0,55 с; отпущенный сразу бьёт вчетверо слабее.
const BOW_DRAW_TIME: float = 0.55
const BOW_MIN_DRAW_FACTOR: float = 0.25

const WEAPONS: Dictionary = {
	&"bow": {
		"name": "Лук",
		"damage": 26.0,
		"pellets": 1,
		"magazine": 1,
		"cooldown": 0.35,
		"noise": 60.0,
		"ammo": &"arrow",
		"projectile": &"arrow",
		"speed": 760.0,
		"gravity": 620.0,
		"spread": 0.0,
		"range": 1400.0,
		"pickup": &"arrow",
		"draw_time": BOW_DRAW_TIME,
	},
	&"pistol": {
		"name": "Пистолет 9 мм",
		"damage": 18.0,
		"pellets": 1,
		"magazine": 12,
		"cooldown": 0.24,
		"noise": 520.0,
		"ammo": &"ammo9",
		"projectile": &"bullet",
		"speed": 1200.0,
		"gravity": 0.0,
		"spread": 0.02,
		"range": 900.0,
		"pickup": &"",
		"draw_time": 0.0,
	},
	&"shotgun": {
		"name": "Дробовик",
		"damage": 12.0,
		"pellets": 5,
		"magazine": 4,
		"cooldown": 0.9,
		"noise": 700.0,
		"ammo": &"ammo_shell",
		"projectile": &"bullet",
		"speed": 1050.0,
		"gravity": 0.0,
		"spread": 0.16,
		"range": 420.0,
		"pickup": &"",
		"draw_time": 0.0,
	},
	&"rifle": {
		"name": "Винтовка",
		"damage": 45.0,
		"pellets": 1,
		"magazine": 5,
		"cooldown": 1.1,
		"noise": 620.0,
		"ammo": &"ammo_rifle",
		"projectile": &"bullet",
		"speed": 1600.0,
		"gravity": 0.0,
		"spread": 0.006,
		"range": 1600.0,
		"pickup": &"",
		"draw_time": 0.0,
	},
	&"heavy": {
		"name": "Тяжёлое оружие",
		"damage": 30.0,
		"pellets": 1,
		"magazine": 30,
		"cooldown": 0.12,
		"noise": 800.0,
		"ammo": &"ammo_heavy",
		"projectile": &"bullet",
		"speed": 1300.0,
		"gravity": 0.0,
		"spread": 0.05,
		"range": 1100.0,
		"pickup": &"",
		"draw_time": 0.0,
	},
}


static func has_weapon(weapon_id: StringName) -> bool:
	return WEAPONS.has(weapon_id)


static func get_weapon(weapon_id: StringName) -> Dictionary:
	return (WEAPONS.get(weapon_id, {}) as Dictionary).duplicate(true)


static func damage_of(weapon_id: StringName) -> float:
	return float((WEAPONS.get(weapon_id, {}) as Dictionary).get("damage", 0.0))


static func pellets_of(weapon_id: StringName) -> int:
	return maxi(1, int((WEAPONS.get(weapon_id, {}) as Dictionary).get("pellets", 1)))


static func magazine_of(weapon_id: StringName) -> int:
	return maxi(0, int((WEAPONS.get(weapon_id, {}) as Dictionary).get("magazine", 0)))


static func cooldown_of(weapon_id: StringName) -> float:
	return maxf(0.0, float((WEAPONS.get(weapon_id, {}) as Dictionary).get("cooldown", 0.0)))


static func noise_of(weapon_id: StringName) -> float:
	return maxf(0.0, float((WEAPONS.get(weapon_id, {}) as Dictionary).get("noise", 0.0)))


static func ammo_of(weapon_id: StringName) -> StringName:
	return StringName((WEAPONS.get(weapon_id, {}) as Dictionary).get("ammo", &""))


static func reload_time(_weapon_id: StringName = &"") -> float:
	return RELOAD_TIME


# Урон лука растёт с натяжением. Отпустил рано — слабее, но не впустую: полный
# ноль читался бы как поломка, а не как выбор.
static func damage_for_draw(weapon_id: StringName, draw_seconds: float) -> float:
	var weapon: Dictionary = WEAPONS.get(weapon_id, {})
	if weapon.is_empty():
		return 0.0
	var full_draw := float(weapon.get("draw_time", 0.0))
	var base := float(weapon.get("damage", 0.0))
	if full_draw <= 0.0:
		return base
	var ratio := clampf(draw_seconds / full_draw, 0.0, 1.0)
	return base * lerpf(BOW_MIN_DRAW_FACTOR, 1.0, ratio)


# Готовая настройка снаряда: projectile.gd принимает её как есть.
static func projectile_config(weapon_id: StringName, damage_override: float = -1.0) -> Dictionary:
	var weapon: Dictionary = WEAPONS.get(weapon_id, {})
	if weapon.is_empty():
		return {}
	return {
		"kind": StringName(weapon.get("projectile", &"bullet")),
		"damage": float(weapon.get("damage", 0.0)) if damage_override < 0.0 else maxf(0.0, damage_override),
		"speed": float(weapon.get("speed", 1200.0)),
		"gravity": float(weapon.get("gravity", 0.0)),
		"range": float(weapon.get("range", 900.0)),
		"pickup": StringName(weapon.get("pickup", &"")),
		"weapon": weapon_id,
	}

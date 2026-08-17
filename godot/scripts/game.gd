# game.gd — корень сцены. Собирает мир, игрока, камеру, небо, свет и HUD.
#
# Сцена строится кодом, а не в редакторе: так вся настройка видна в одном месте
# и правится обычным дифом, а не бинарным файлом сцены.
extends Node2D

const SEED := 1337

var terrain: Terrain
var player: Player
var cam: Camera2D
var sky_rect: ColorRect
var post_rect: ColorRect
var lamp: PointLight2D
var hud: CanvasItem
var game_manager: GameManager
var audio_manager: AudioManager
var transition_manager: TransitionManager
var dialog_manager: DialogManager
var main_menu: MainMenu
var beacon: InteractionBeacon
var inventory: PlayerInventory
var item_catalog: ItemCatalog
var inventory_ui: InventoryUI
var interaction_coordinator: InteractionCoordinator
var gameplay_entities: Node2D
var enemies: Node2D
var starter_enemy: Enemy
var day := 1.0
var zoom_target := 1.6
var t := 0.0
var gameplay_active: bool = false
var _camera_ahead := Vector2.ZERO
var _last_zone_id: String = ""
var _autosave_elapsed: float = 0.0
var _pistol_magazine: int = 0
var _combat_cooldown: float = 0.0
var _enemy_defeated: bool = false
var _drop_serial: int = 0
var mining := Mining.new()
# Заряд ручного бура в блоках. Найденный в небоскрёбах бур уже заряжен.
const DRILL_CHARGE_FULL := 120.0
var _drill_charge: float = 0.0
var _mining_hint_cooldown: float = 0.0


func _ready() -> void:
	_bind_input()
	_make_managers()
	_make_environment()
	_make_sky()

	terrain = Terrain.new()
	terrain.name = "Terrain"
	add_child(terrain)
	terrain.build(SEED)

	player = Player.new()
	player.name = "Player"
	add_child(player)
	player.setup(terrain, terrain.spawn - Vector2(0, 4))
	player.z_index = 10
	_make_beacon()
	_make_gameplay_systems()

	_make_lamp()
	_make_dust()

	cam = Camera2D.new()
	cam.zoom = Vector2(zoom_target, zoom_target)
	cam.position_smoothing_enabled = true
	cam.position_smoothing_speed = 8.0
	add_child(cam)
	cam.make_current()

	_make_post()

	hud = preload("res://scripts/hud.gd").new()
	var layer := CanvasLayer.new()
	layer.layer = 10
	layer.add_child(hud)
	add_child(layer)
	hud.set("game", self)
	beacon.interacted.connect(_on_beacon_interacted)
	dialog_manager.dialogue_finished.connect(_on_dialogue_finished)

	# Ограничение разрешения отрисовки. Без него игра рисует в разрешении
	# ретина-экрана — 2560×1440 вместо 1280×720, вчетверо больше пикселей. На
	# замере это стоило 39 к/с против 176. Мир из частиц всё равно не выигрывает
	# от такой плотности, а интерфейс остаётся резким за счёт режима растяжки.
	_base_size = Vector2i(1280, 720)
	_set_render_scale(1.0)

	print("[игра] готова, появление: ", player.position)
	_debug_args()
	if _shot_path != "":
		_begin_game(false, false)
	else:
		_show_start_menu()


func _make_managers() -> void:
	game_manager = GameManager.new()
	game_manager.name = "GameManager"
	add_child(game_manager)
	audio_manager = AudioManager.new()
	audio_manager.name = "AudioManager"
	add_child(audio_manager)
	dialog_manager = DialogManager.new()
	dialog_manager.name = "DialogManager"
	add_child(dialog_manager)
	main_menu = MainMenu.new()
	main_menu.name = "MainMenu"
	add_child(main_menu)
	transition_manager = TransitionManager.new()
	transition_manager.name = "TransitionManager"
	add_child(transition_manager)
	main_menu.start_requested.connect(func() -> void: _begin_game(false, true))
	main_menu.continue_requested.connect(func() -> void: _begin_game(true, true))
	main_menu.resume_requested.connect(_resume_game)
	main_menu.save_requested.connect(_save_game)
	main_menu.menu_requested.connect(_return_to_menu)
	main_menu.volume_changed.connect(audio_manager.set_bus_volume)


func _make_beacon() -> void:
	beacon = InteractionBeacon.new()
	beacon.position = terrain.spawn + Vector2(104, 0)
	beacon.position.y = terrain.surface_px(beacon.position.x)
	beacon.set_player(player)
	add_child(beacon)


func _make_gameplay_systems() -> void:
	item_catalog = ItemCatalog.new()
	inventory = PlayerInventory.new()
	interaction_coordinator = InteractionCoordinator.new()
	interaction_coordinator.name = "InteractionCoordinator"
	add_child(interaction_coordinator)
	interaction_coordinator.set_actor(player)
	interaction_coordinator.target_changed.connect(_on_interaction_target_changed)
	interaction_coordinator.register_adapter(
		beacon, "E  СЛУШАТЬ СИГНАЛ", 1, 95.0,
		func(_actor: Node2D) -> bool: return beacon.is_nearby(),
		func(_actor: Node2D) -> void: beacon.interact()
	)

	gameplay_entities = Node2D.new()
	gameplay_entities.name = "GameplayEntities"
	add_child(gameplay_entities)
	enemies = Node2D.new()
	enemies.name = "Enemies"
	add_child(enemies)

	var ui_layer := CanvasLayer.new()
	ui_layer.name = "InventoryLayer"
	ui_layer.layer = 25
	inventory_ui = InventoryUI.new()
	ui_layer.add_child(inventory_ui)
	add_child(ui_layer)
	inventory_ui.set_inventory(inventory)
	inventory_ui.set_catalog(item_catalog)
	inventory_ui.slot_selected.connect(func(_index: int) -> void: hud.queue_redraw())
	player.died.connect(_on_player_died)
	reset_gameplay_state()


func get_start_gameplay_spec() -> Dictionary:
	return {
		"world_items": [
			{"stable_id": "starter.gasmask", "item_id": "gasmask", "count": 1, "offset_cells": 3},
		],
		"crates": [
			{
				"stable_id": "starter.tools", "display_name": "ящик с инструментами", "offset_cells": -7,
				"loot": [
					{"item_id": "axe", "count": 1},
					{"item_id": "pick", "count": 1},
					{"item_id": "bandage", "count": 3},
				],
			},
			{
				"stable_id": "starter.survival", "display_name": "ящик выжившего", "offset_cells": 9,
				"loot": [
					{"item_id": "pistol", "count": 1},
					{"item_id": "ammo9", "count": 10},
					{"item_id": "filter", "count": 2},
					{"item_id": "canteen", "count": 1},
					{"item_id": "can", "count": 1},
				],
			},
			# Руины небоскрёбов, 3600 клеток на восток от старта. Ручной бур уже
			# заряжен, рядом пулемёт. Дорога туда долгая и опасная — это и есть
			# цена за инструмент, который ускоряет ломание вчетверо.
			{
				"stable_id": "towers.armory", "display_name": "оружейный ящик", "military": true,
				"offset_cells": 3600,
				"loot": [
					{"item_id": "handheld_drill", "count": 1},
					{"item_id": "heavy", "count": 1},
					{"item_id": "ammo_heavy", "count": 90},
				],
			},
		],
	}


func reset_gameplay_state() -> void:
	if inventory == null or gameplay_entities == null or enemies == null:
		return
	inventory.clear()
	_pistol_magazine = 0
	_enemy_defeated = false
	_drill_charge = 0.0
	mining.reset()
	_clear_gameplay_nodes()
	_spawn_default_gameplay()
	if inventory_ui:
		inventory_ui.set_open(false)


func _clear_gameplay_nodes() -> void:
	for child in gameplay_entities.get_children():
		interaction_coordinator.unregister_interactable(child as Node2D)
		child.free()
	for child in enemies.get_children():
		child.free()
	starter_enemy = null


func _spawn_default_gameplay() -> void:
	var spec := get_start_gameplay_spec()
	for entry: Dictionary in spec.world_items:
		_spawn_world_item(entry)
	for entry: Dictionary in spec.crates:
		_spawn_loot_crate(entry)
	_spawn_starter_enemy()


func _ground_at_offset(offset_cells: int) -> Vector2:
	var x := terrain.spawn.x + float(offset_cells * Core.CELL)
	return Vector2(x, terrain.surface_px(x))


func _spawn_world_item(entry: Dictionary, saved: Dictionary = {}) -> WorldItem:
	var item := WorldItem.new()
	item.stable_id = String(entry.get("stable_id", "item.%d" % gameplay_entities.get_child_count()))
	item.item_id = String(entry.get("item_id", ""))
	item.interaction_priority = 10
	var definition := item_catalog.get_item(StringName(item.item_id))
	item.display_name = String(definition.get("name", item.item_id))
	item.count = maxi(1, int(entry.get("count", 1)))
	if entry.has("position"):
		var pos: Dictionary = entry.position
		item.position = Vector2(float(pos.get("x", terrain.spawn.x)), float(pos.get("y", terrain.spawn.y)))
	else:
		item.position = _ground_at_offset(int(entry.get("offset_cells", 0)))
	item.pickup_requested.connect(_on_world_item_pickup)
	gameplay_entities.add_child(item)
	interaction_coordinator.register_interactable(item)
	if not saved.is_empty():
		item.restore_state(saved)
	return item


func _spawn_loot_crate(entry: Dictionary, saved: Dictionary = {}) -> LootCrate:
	var crate := LootCrate.new()
	crate.stable_id = String(entry.get("stable_id", "crate.%d" % gameplay_entities.get_child_count()))
	crate.display_name = String(entry.get("display_name", "ящик"))
	crate.military = bool(entry.get("military", false))
	crate.interaction_priority = 5
	var source_loot: Array = entry.get("loot", [])
	var typed_loot: Array[Dictionary] = []
	for loot_entry: Variant in source_loot:
		if loot_entry is Dictionary:
			typed_loot.append((loot_entry as Dictionary).duplicate(true))
	crate.loot = typed_loot
	if entry.has("position"):
		var pos: Dictionary = entry.position
		crate.position = Vector2(float(pos.get("x", terrain.spawn.x)), float(pos.get("y", terrain.spawn.y)))
	else:
		crate.position = _ground_at_offset(int(entry.get("offset_cells", 0)))
	crate.loot_requested.connect(_on_crate_loot_requested)
	gameplay_entities.add_child(crate)
	interaction_coordinator.register_interactable(crate)
	if not saved.is_empty():
		crate.restore_state(saved)
	return crate


func _spawn_starter_enemy(saved: Dictionary = {}) -> Enemy:
	starter_enemy = Enemy.new()
	starter_enemy.stable_id = "waste.shambler.1"
	starter_enemy.position = _ground_at_offset(54)
	starter_enemy.set_target(player)
	starter_enemy.set_terrain(terrain)
	starter_enemy.player_damage_requested.connect(player.take_damage)
	starter_enemy.died.connect(_on_enemy_died)
	enemies.add_child(starter_enemy)
	if not saved.is_empty():
		starter_enemy.restore_state(saved)
	return starter_enemy


func _on_interaction_target_changed(_target: Node2D, prompt: String) -> void:
	hud.call("set_interaction_prompt", prompt)


func _on_world_item_pickup(item: WorldItem) -> void:
	var remaining := inventory.add(StringName(item.item_id), item.count)
	var accepted := item.count - remaining
	if accepted <= 0:
		hud.call("notify", "Инвентарь полон")
		return
	item.collect(accepted)
	if item.item_id == "gasmask" and not player.mask:
		inventory.remove(&"gasmask", 1)
		player.equip_mask()
		hud.call("notify", "Противогаз надет. Теперь можно дышать.")
	else:
		var definition := item_catalog.get_item(StringName(item.item_id))
		hud.call("notify", "+%d %s" % [accepted, String(definition.get("name", item.item_id))])
		_charge_drill_if_taken(StringName(item.item_id))
	interaction_coordinator.update_target()
	_refresh_inventory_ui()


func _on_crate_loot_requested(crate: LootCrate, loot: Array[Dictionary]) -> void:
	var dropped := 0
	for index in loot.size():
		var entry: Dictionary = loot[index]
		var item_id := StringName(entry.get("item_id", ""))
		var count := maxi(0, int(entry.get("count", 0)))
		var remaining := inventory.add(item_id, count)
		if remaining > 0:
			dropped += remaining
			_spawn_world_item({
				"stable_id": "%s.overflow.%d.%s" % [crate.stable_id, index, String(item_id)],
				"item_id": String(item_id), "count": remaining,
				"position": {"x": crate.position.x + randf_range(-12.0, 12.0), "y": crate.position.y},
			})
	for entry: Dictionary in loot:
		_charge_drill_if_taken(StringName(entry.get("item_id", "")))
	hud.call("notify", "Ящик вскрыт" + (" — часть вещей осталась рядом" if dropped > 0 else ""))
	_refresh_inventory_ui()


# Бур из руин достаётся уже заряженным: искать к нему источник питания там же,
# где его нашёл, — лишний шаг, который ничего не добавляет.
func _charge_drill_if_taken(item_id: StringName) -> void:
	if item_id != &"handheld_drill":
		return
	_drill_charge = DRILL_CHARGE_FULL
	hud.call("notify", "Ручной бур заряжен: %d блоков" % int(DRILL_CHARGE_FULL))


func _refresh_inventory_ui() -> void:
	if inventory_ui:
		inventory_ui.set_inventory(inventory)
	hud.queue_redraw()


func capture_gameplay_state() -> Dictionary:
	var world_items: Array[Dictionary] = []
	var crates: Array[Dictionary] = []
	for child: Node in gameplay_entities.get_children():
		if child is WorldItem:
			var item_state: Dictionary = (child as WorldItem).serialize_state()
			item_state["position"] = {"x": (child as Node2D).position.x, "y": (child as Node2D).position.y}
			world_items.append(item_state)
		elif child is LootCrate:
			var crate := child as LootCrate
			var crate_state: Dictionary = crate.serialize_state()
			crate_state["position"] = {"x": crate.position.x, "y": crate.position.y}
			crate_state["display_name"] = crate.display_name
			crate_state["military"] = crate.military
			var saved_loot: Array[Dictionary] = []
			for entry: Dictionary in crate.loot:
				saved_loot.append(entry.duplicate(true))
			crate_state["loot"] = saved_loot
			crates.append(crate_state)
	world_items.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return String(a.stable_id) < String(b.stable_id))
	crates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return String(a.stable_id) < String(b.stable_id))
	var saved_enemies: Array[Dictionary] = []
	for child: Node in enemies.get_children():
		if child is Enemy:
			saved_enemies.append((child as Enemy).serialize_state())
	return {
		"inventory": inventory.serialize_state(),
		"entities": {
			"world_items": world_items,
			"crates": crates,
			"enemies": saved_enemies,
		},
		"combat": {
			"pistol_magazine": _pistol_magazine,
			"enemy_defeated": _enemy_defeated,
			"drop_serial": _drop_serial,
			"drill_charge": _drill_charge,
		},
	}


func apply_gameplay_state(state: Dictionary) -> void:
	if bool(state.get("legacy_migration", false)):
		reset_gameplay_state()
		return
	inventory.clear()
	var inventory_state: Variant = state.get("inventory", {})
	if inventory_state is Dictionary:
		inventory.restore_state(inventory_state)
	_clear_gameplay_nodes()
	var entity_state: Variant = state.get("entities", {})
	if entity_state is Dictionary:
		var raw_items: Variant = entity_state.get("world_items", [])
		if raw_items is Array:
			for raw: Variant in raw_items:
				if raw is Dictionary and not String(raw.get("stable_id", "")).is_empty() and not String(raw.get("item_id", "")).is_empty():
					_spawn_world_item(raw, raw)
		var raw_crates: Variant = entity_state.get("crates", [])
		if raw_crates is Array:
			for raw: Variant in raw_crates:
				if raw is Dictionary and not String(raw.get("stable_id", "")).is_empty():
					_spawn_loot_crate(raw, raw)
		var raw_enemies: Variant = entity_state.get("enemies", [])
		if raw_enemies is Array:
			for raw: Variant in raw_enemies:
				if raw is Dictionary and String(raw.get("stable_id", "")) == "waste.shambler.1":
					_spawn_starter_enemy(raw)
					break
	var combat: Variant = state.get("combat", {})
	if combat is Dictionary:
		_pistol_magazine = clampi(int(combat.get("pistol_magazine", 0)), 0, 12)
		_enemy_defeated = bool(combat.get("enemy_defeated", false))
		_drop_serial = maxi(0, int(combat.get("drop_serial", 0)))
		_drill_charge = clampf(float(combat.get("drill_charge", 0.0)), 0.0, DRILL_CHARGE_FULL)
	else:
		_pistol_magazine = 0
		_enemy_defeated = false
		_drill_charge = 0.0
	mining.reset()
	interaction_coordinator.update_target()
	_refresh_inventory_ui()


func _on_enemy_died(_stable_id: String) -> void:
	_enemy_defeated = true
	hud.call("notify", "Заражённый уничтожен. Путь свободен.")
	if starter_enemy:
		_drop_serial += 1
		_spawn_world_item({
			"stable_id": "enemy.drop.%d.bandage" % _drop_serial,
			"item_id": "bandage", "count": 1,
			"position": {"x": starter_enemy.position.x, "y": starter_enemy.position.y},
		})


func _on_player_died() -> void:
	if not gameplay_active:
		return
	gameplay_active = false
	player.set_physics_process(false)
	_set_enemy_processing(false)
	hud.call("set_interaction_prompt", "")
	hud.call("notify", "Вы погибли. Возвращение к аварийному маяку…")
	get_tree().create_timer(1.25).timeout.connect(func() -> void:
		transition_manager.fade_to_black(func() -> void:
			player.position = terrain.spawn - Vector2(0.0, 4.0)
			player.hp = 65.0
			player.food = maxf(player.food, 80.0)
			player.water = maxf(player.water, 80.0)
			player.rad = 0.0
			player.set("_death_emitted", false)
			gameplay_active = true
			player.set_physics_process(true)
			_set_enemy_processing(true)
			transition_manager.fade_from_black(0.55)
		, 0.28)
	)


func use_selected_item() -> bool:
	var slot := inventory.get_selected()
	if slot.is_empty():
		return false
	var item_id := StringName(slot.get("id", ""))
	match item_id:
		&"bandage":
			if player.hp >= 100.0:
				hud.call("notify", "Здоровье уже в порядке")
				return false
			player.heal(24.0)
			inventory.remove_from_slot(inventory.selected_hotbar(), 1)
			hud.call("notify", "Рана перевязана")
		&"can":
			if player.food >= Core.FOOD_MAX:
				hud.call("notify", "Вы не голодны")
				return false
			player.food = minf(Core.FOOD_MAX, player.food + 48.0)
			inventory.remove_from_slot(inventory.selected_hotbar(), 1)
			hud.call("notify", "Тушёнка съедена")
		&"gasmask":
			if player.mask:
				return false
			inventory.remove_from_slot(inventory.selected_hotbar(), 1)
			player.equip_mask()
			hud.call("notify", "Противогаз надет")
		&"filter":
			if not player.mask:
				hud.call("notify", "Сначала наденьте противогаз")
				return false
			if player.filter_wear > 90.0:
				hud.call("notify", "Фильтр ещё свежий")
				return false
			inventory.remove_from_slot(inventory.selected_hotbar(), 1)
			player.filter_wear = 100.0
			hud.call("notify", "Фильтр заменён")
		_:
			return false
	_refresh_inventory_ui()
	return true


func reload_selected_weapon() -> bool:
	var slot := inventory.get_selected()
	if StringName(slot.get("id", "")) != &"pistol":
		return false
	var needed := 12 - _pistol_magazine
	var available := inventory.count(&"ammo9")
	var loaded := mini(needed, available)
	if loaded <= 0:
		hud.call("notify", "Нет патронов 9 мм")
		return false
	inventory.remove(&"ammo9", loaded)
	_pistol_magazine += loaded
	hud.call("notify", "Пистолет: %d / 12" % _pistol_magazine)
	_refresh_inventory_ui()
	return true


func _toggle_mask_equipment() -> bool:
	if player.mask:
		if inventory.add(&"gasmask", 1) > 0:
			hud.call("notify", "В инвентаре нет места для противогаза")
			return false
		player.unequip_mask()
		hud.call("notify", "Противогаз снят")
	else:
		if not inventory.remove(&"gasmask", 1):
			hud.call("notify", "Противогаз не найден")
			return false
		player.equip_mask()
		hud.call("notify", "Противогаз надет")
	_refresh_inventory_ui()
	return true


func _show_start_menu() -> void:
	gameplay_active = false
	player.set_physics_process(false)
	_set_enemy_processing(false)
	get_tree().paused = true
	main_menu.show_start(game_manager.has_save())


func _begin_game(load_saved: bool, animated: bool) -> void:
	var begin := func() -> void:
		if load_saved:
			if not game_manager.load_game(self):
				game_manager.new_game(self)
		elif animated or _shot_path == "":
			game_manager.new_game(self)
		cam.position = player.position
		cam.reset_smoothing()
		main_menu.hide_menu()
		get_tree().paused = false
		gameplay_active = true
		player.set_physics_process(true)
		_set_enemy_processing(true)
		_last_zone_id = ""
		if animated:
			transition_manager.fade_from_black(0.75)
	if animated:
		get_tree().paused = true
		transition_manager.fade_to_black(begin, 0.38)
	else:
		begin.call()


func _pause_game() -> void:
	if not gameplay_active or dialog_manager.is_open():
		return
	gameplay_active = false
	_set_enemy_processing(false)
	get_tree().paused = true
	main_menu.show_pause()


func _resume_game() -> void:
	main_menu.hide_menu()
	get_tree().paused = false
	gameplay_active = true
	_set_enemy_processing(true)


func _save_game() -> void:
	if game_manager.save_game(self):
		hud.call("notify", "Игра сохранена")


func _return_to_menu() -> void:
	game_manager.save_game(self)
	transition_manager.fade_to_black(func() -> void:
		main_menu.show_start(game_manager.has_save())
		gameplay_active = false
		_set_enemy_processing(false)
		get_tree().paused = true
		transition_manager.fade_from_black(0.55)
	, 0.35)


func _on_beacon_interacted() -> void:
	if dialog_manager.is_open():
		return
	gameplay_active = false
	player.set_physics_process(false)
	_set_enemy_processing(false)
	dialog_manager.show_dialogue([
		{"speaker": "АВАРИЙНЫЙ КАНАЛ 04", "text": "...если кто-нибудь слышит: город к востоку ещё держится. Ищи красную башню."},
		{"speaker": "НЕИЗВЕСТНЫЙ ГОЛОС", "text": "В лесу есть вода. В шахте — руда. Но после заката на открытом месте не оставайся."},
		{"speaker": "СИСТЕМА", "text": "Сигнал повторяется. На корпусе маяка выцарапано: «Не снимай противогаз»."},
	])


func _on_dialogue_finished() -> void:
	if not main_menu.is_open():
		gameplay_active = true
		player.set_physics_process(true)
		_set_enemy_processing(true)


func _set_enemy_processing(enabled: bool) -> void:
	if enemies == null:
		return
	for child: Node in enemies.get_children():
		child.set_physics_process(enabled)


# Отладочные ключи запуска. Нужны, чтобы проверять картинку и кадры без рук:
#   godot -- --shot=/путь/к.png --frames=60 --at=3250 --zoom=2
var _shot_path := ""
var _shot_frames := 60
var _frame := 0
var _menu_shot_path := ""
var _interaction_smoke := false
var _save_smoke := false


func _debug_args() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot="):
			_shot_path = a.substr(7)
		elif a.begins_with("--menu-shot="):
			_menu_shot_path = a.substr(12)
		elif a.begins_with("--frames="):
			_shot_frames = int(a.substr(9))
		elif a.begins_with("--at="):
			# перенос игрока в частицах по X — чтобы посмотреть другую локацию
			var cx := int(a.substr(5))
			player.position = Vector2(cx * Core.CELL, terrain.surface_px(cx * Core.CELL) - Core.CELL)
			cam.position = player.position
			cam.reset_smoothing()
		elif a.begins_with("--zoom="):
			zoom_target = float(a.substr(7))
			cam.zoom = Vector2(zoom_target, zoom_target)
		elif a == "--dig":
			_test_dig = true
		elif a == "--interact-smoke":
			_interaction_smoke = true
		elif a == "--save-smoke":
			_save_smoke = true
			game_manager.save_path = "user://cinematic_smoke_save.json"
		elif a.begins_with("--day="):
			_day_fixed = float(a.substr(6))
	if _menu_shot_path != "":
		get_tree().create_timer(0.8, true).timeout.connect(_capture_menu)


func _capture_menu() -> void:
	var img := get_viewport().get_texture().get_image()
	img.save_png(_menu_shot_path)
	print("[снимок меню] ", _menu_shot_path)
	get_tree().quit()


var _day_fixed := -1.0
var _auto_off := false
var _test_dig := false


func _capture() -> void:
	_frame += 1
	if _interaction_smoke and _frame == 20:
		player.position = beacon.position
		beacon.set("_nearby", true)
		beacon.interact()
		print("[проверка] диалог открыт: ", dialog_manager.is_open())
	if _save_smoke and _frame == 24:
		var expected := player.position
		var saved := game_manager.save_game(self)
		player.position += Vector2(333, -111)
		var loaded := game_manager.load_game(self)
		var restored := player.position.is_equal_approx(expected)
		print("[проверка] сохранение: ", saved, ", загрузка: ", loaded, ", позиция: ", restored)
		if not saved or not loaded or not restored:
			push_error("[проверка] сохранение игры не прошло")
	# Проверка копания без рук: роем яму под ногами и убеждаемся, что свет
	# пересчитался, тайлы перезалились и ничего не упало.
	if _test_dig and _frame == 20:
		var cx := int(player.position.x / Core.CELL)
		var cy := int(player.position.y / Core.CELL) + 3
		var before := terrain.get_mat(cx, cy)
		var got: Dictionary = terrain.dig(cx, cy, 5, 3.0)
		print("[проверка] копали породу ", before, ", выпало ", got,
			", стало ", terrain.get_mat(cx, cy),
			", свет ", terrain.light_at_px(player.position.x, player.position.y + 24.0))
	if _shot_path == "" or _frame < _shot_frames:
		return
	if DisplayServer.get_name() == "headless":
		push_warning("[снимок] видеокадр пропущен в headless-режиме")
		if _save_smoke and FileAccess.file_exists(game_manager.save_path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(game_manager.save_path))
		_shot_path = ""
		get_tree().quit()
		return
	var texture := get_viewport().get_texture()
	if texture == null:
		push_warning("[снимок] видеотекстура недоступна в headless-режиме")
		_shot_path = ""
		get_tree().quit()
		return
	var img := texture.get_image()
	if img == null:
		push_warning("[снимок] кадр недоступен в headless-режиме")
		_shot_path = ""
		get_tree().quit()
		return
	img.save_png(_shot_path)
	print("[снимок] ", _shot_path, "  кадров в секунду: ", Engine.get_frames_per_second())
	if _save_smoke and FileAccess.file_exists(game_manager.save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(game_manager.save_path))
	_shot_path = ""
	get_tree().quit()


func _bind_input() -> void:
	var binds := {
		"left": [KEY_A, KEY_LEFT], "right": [KEY_D, KEY_RIGHT],
		"up": [KEY_W, KEY_UP, KEY_SPACE], "down": [KEY_S, KEY_DOWN],
		"sprint": [KEY_SHIFT], "quality": [KEY_F1], "interact": [KEY_E],
	}
	for action in binds:
		var a := StringName(action)
		if not InputMap.has_action(a):
			InputMap.add_action(a)
		for k in binds[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event(a, ev)

	# Tab отдаём инвентарю целиком.
	#
	# По умолчанию Tab у движка — это переход к следующему элементу интерфейса.
	# Как только открытый инвентарь ставил фокус на слот, второй Tab уходил на
	# перевод фокуса и до игры не доходил: инвентарь открывался и не закрывался.
	# Фокус между слотами водят стрелки, отдельная клавиша для этого не нужна.
	for action in [&"ui_focus_next", &"ui_focus_prev"]:
		if not InputMap.has_action(action):
			continue
		for ev in InputMap.action_get_events(action):
			if ev is InputEventKey and (ev.physical_keycode == KEY_TAB or ev.keycode == KEY_TAB):
				InputMap.action_erase_event(action, ev)


# Свечение. В 2D его даёт Environment, а пересветы приходят из шейдера породы:
# освещённые кромки и стекло противогаза светят чуть выше единицы.
func _make_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_CANVAS
	env.glow_enabled = true
	env.glow_intensity = 0.5
	env.glow_bloom = 0.12
	env.glow_strength = 1.05
	env.glow_hdr_threshold = 0.95
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	env.adjustment_enabled = true
	env.adjustment_brightness = 1.02
	env.adjustment_contrast = 1.06
	env.adjustment_saturation = 0.94    # выжженный, чуть обесцвеченный мир
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)


# Фоны локаций: полосы фотографических панорам. Порядок совпадает с ZONES,
# ничейная земля между локациями берёт фон соседа, к которому ближе.
var _bg := {}


func _load_backgrounds() -> void:
	for zid: String in ZoneLook.LOOK.keys():
		var name: String = ZoneLook.LOOK[zid].bg
		if _bg.has(name):
			continue
		var path := "res://backgrounds/%s.jpg" % name
		if ResourceLoader.exists(path):
			_bg[name] = load(path)
		else:
			print("[фон] нет файла ", path)


# Какой фон показывать и насколько он смешан с соседним. Возвращает
# [текстура A, текстура B, доля B]. Смешивание идёт в полосе перед локацией,
# поэтому местность меняется постепенно, а не щелчком на границе.
func _bg_for(px: float) -> Array:
	var cx := px / Core.CELL
	var best := "waste"
	var next := "waste"
	var mix := 0.0
	# ближайшая локация слева и справа по центрам
	var prev_id := "waste"
	var prev_c := -100000.0
	for z in Core.ZONES:
		var c: float = (float(z.x0) + float(z.x1)) * 0.5
		if c <= cx:
			prev_id = z.id
			prev_c = c
		else:
			# мы между prev_c и c: смешиваем в последней четверти промежутка
			var t: float = (cx - prev_c) / maxf(1.0, c - prev_c)
			best = prev_id
			next = z.id
			mix = clampf((t - 0.6) / 0.4, 0.0, 1.0)
			return [_bg.get(best), _bg.get(next), mix]
	return [_bg.get(prev_id), _bg.get(prev_id), 0.0]


func _make_sky() -> void:
	_load_backgrounds()
	var layer := CanvasLayer.new()
	layer.layer = -100
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/sky.gdshader")
	mat.set_shader_parameter("horizon_y", float(Core.SURFACE_Y * Core.CELL))
	sky_rect = ColorRect.new()
	sky_rect.material = mat
	sky_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	sky_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(sky_rect)
	add_child(layer)


# Лампа игрока: без неё пещеры честно чёрные, потому что свет неба туда не идёт
func _make_lamp() -> void:
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
	grad.colors = PackedColorArray([
		Color(1.0, 0.92, 0.72, 1.0), Color(1.0, 0.82, 0.55, 0.35), Color(0, 0, 0, 0),
	])
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 512
	tex.height = 512
	lamp = PointLight2D.new()
	lamp.texture = tex
	lamp.energy = 1.15
	lamp.texture_scale = 1.6
	lamp.blend_mode = Light2D.BLEND_MODE_ADD
	add_child(lamp)


# Финишный слой: виньетка, тёплая тонировка, зерно, лёгкая аберрация по краям.
# Он лежит поверх мира, но под интерфейсом — HUD трогать не надо.
func _make_post() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 5
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/post.gdshader")
	post_rect = ColorRect.new()
	post_rect.material = mat
	post_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	post_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(post_rect)
	add_child(layer)


# Пыль в воздухе: дешёвый приём, который сразу добавляет глубины
func _make_dust() -> void:
	var p := CPUParticles2D.new()
	p.amount = 220
	p.lifetime = 9.0
	p.preprocess = 4.0
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(900, 500)
	p.gravity = Vector2(6, -2)
	p.initial_velocity_min = 2.0
	p.initial_velocity_max = 14.0
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.8
	p.color = Color(1.0, 0.94, 0.8, 0.14)
	p.z_index = 20
	p.name = "Dust"
	add_child(p)


func _process(dt: float) -> void:
	t += dt
	_combat_cooldown = maxf(0.0, _combat_cooldown - dt)
	if interaction_coordinator and gameplay_active and not inventory_ui.is_open() and not dialog_manager.is_open():
		interaction_coordinator.update_target()
	# сутки: 0 — ночь, 1 — полдень. Держим вечерний свет, он самый выразительный
	day = 0.55 + 0.45 * sin(t / Core.DAY_LEN * TAU + 1.2)
	if _day_fixed >= 0.0:
		day = _day_fixed

	var desired_ahead := Vector2(clampf(player.vx * 22.0, -48.0, 48.0), 0.0)
	_camera_ahead = _camera_ahead.lerp(desired_ahead, clampf(dt * 2.5, 0.0, 1.0))
	var idle_drift := Vector2(sin(t * 0.19) * 2.2, sin(t * 0.13) * 1.4) if absf(player.vx) < 0.05 else Vector2.ZERO
	cam.position = player.position + Vector2(0, -20) + _camera_ahead + idle_drift
	cam.zoom = cam.zoom.lerp(Vector2(zoom_target, zoom_target), minf(1.0, dt * 8.0))
	lamp.position = player.position + Vector2(0, -34)
	# Днём лампа не нужна: на солнце она только выжигала фигуру в белое пятно.
	# Гасим её по общей освещённости и по тому, сколько света в этом месте.
	var here := terrain.light_at_px(player.position.x, player.position.y - 30.0)
	lamp.energy = lerpf(1.35, 0.12, clampf(day * here * 1.4, 0.0, 1.0))
	var dust := get_node_or_null("Dust")
	if dust:
		(dust as CPUParticles2D).position = cam.position

	var sm: ShaderMaterial = sky_rect.material
	# Линию горизонта берём по земле под игроком, а не по среднему уровню мира:
	# иначе солнце и силуэты города уезжают за землю и небо выглядит заливкой.
	sm.set_shader_parameter("horizon_y", terrain.surface_px(player.position.x))
	var bgs: Array = _bg_for(player.position.x)
	if bgs[0] != null:
		sm.set_shader_parameter("bg_a", bgs[0])
		sm.set_shader_parameter("bg_b", bgs[1] if bgs[1] != null else bgs[0])
		sm.set_shader_parameter("bg_mix", bgs[2])
	# дымка, яркость и параллакс фона — свои у каждой локации
	var current_zone: Dictionary = Core.zone_at_px(player.position.x)
	var look: Dictionary = ZoneLook.of(current_zone.id)
	sm.set_shader_parameter("exposure", look.bg_exposure)
	sm.set_shader_parameter("fog_amount", look.bg_fog)
	sm.set_shader_parameter("haze", look.bg_haze)
	sm.set_shader_parameter("parallax", look.bg_parallax)
	sm.set_shader_parameter("span", look.bg_span)
	sm.set_shader_parameter("cam_pos", cam.get_screen_center_position())
	sm.set_shader_parameter("zoom", cam.zoom.x)
	sm.set_shader_parameter("screen_size", get_viewport_rect().size)
	sm.set_shader_parameter("day", day)
	sm.set_shader_parameter("time_s", t)

	var pm: ShaderMaterial = post_rect.material
	pm.set_shader_parameter("day", day)
	pm.set_shader_parameter("time_s", t)

	terrain.set_uniform("day", day)
	terrain.set_uniform("time_s", t)

	var zone_id: String = current_zone.id
	if gameplay_active and zone_id != _last_zone_id:
		_last_zone_id = zone_id
		hud.call("show_zone", String(current_zone.name))
	_autosave_elapsed += dt
	if gameplay_active and _autosave_elapsed >= 45.0:
		_autosave_elapsed = 0.0
		game_manager.save_game(self)

	_auto_quality(dt)
	_mining_hint_cooldown = maxf(0.0, _mining_hint_cooldown - dt)
	if not _combat_action():
		_dig(dt)
	else:
		mining.reset()
	queue_redraw()
	hud.queue_redraw()
	_capture()


func mouse_world() -> Vector2:
	return get_global_mouse_position()


func _combat_action() -> bool:
	if not gameplay_active or inventory_ui.is_open() or dialog_manager.is_open() or main_menu.is_open():
		return false
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or _combat_cooldown > 0.0:
		return false
	var slot := inventory.get_selected()
	var item_id := StringName(slot.get("id", ""))
	if item_id == &"pistol":
		if _pistol_magazine <= 0:
			_combat_cooldown = 0.32
			hud.call("notify", "Пистолет пуст — нажмите R")
			return true
		_fire_pistol()
		return true
	if item_id != &"axe" and item_id != &"pick":
		return false
	if starter_enemy == null or starter_enemy.state == Enemy.State.DEAD:
		return false
	var target_point := starter_enemy.position + Vector2(0, -24)
	if target_point.distance_to(player.position + Vector2(0, -28)) > 66.0:
		return false
	if target_point.distance_to(mouse_world()) > 42.0:
		return false
	starter_enemy.damage(34.0 if item_id == &"axe" else 20.0)
	_combat_cooldown = 0.48
	hud.call("notify", "Удар: %d урона" % (34 if item_id == &"axe" else 20))
	return true


func _fire_pistol() -> void:
	var muzzle := player.position + Vector2(float(player.face) * 12.0, -38.0)
	var direction := (mouse_world() - muzzle).normalized()
	if is_zero_approx(direction.x) and is_zero_approx(direction.y):
		direction = Vector2(float(player.face), 0.0)
	player.face = 1 if direction.x >= 0.0 else -1
	var bullet := Bullet.new()
	add_child(bullet)
	bullet.set_target(starter_enemy if starter_enemy and starter_enemy.state != Enemy.State.DEAD else null)
	bullet.set_terrain(terrain)
	bullet.setup(muzzle, direction, 26.0, player)
	_pistol_magazine -= 1
	_combat_cooldown = 0.24
	hud.call("notify", "Пистолет: %d / 12" % _pistol_magazine)


# Ломание породы: блок 2×2 с удержанием кнопки. Вся логика времени и твёрдости
# живёт в scripts/systems/mining.gd и покрыта тестом — здесь только ввод,
# дистанция, добыча в инвентарь и расход заряда бура.
func _dig(dt: float) -> void:
	if not gameplay_active or dialog_manager.is_open() or main_menu.is_open():
		mining.reset()
		return
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		mining.reset()
		return

	var selected_id := StringName(inventory.get_selected().get("id", ""))
	# Рукой тоже можно — медленно и только мягкую породу. Пустая рука, которая
	# не делает вообще ничего, читается как поломка управления.
	if selected_id != &"pick" and selected_id != &"axe" and selected_id != &"handheld_drill":
		selected_id = &""
	if selected_id == &"handheld_drill" and _drill_charge <= 0.0:
		selected_id = &""     # разряженный бур работает как рука

	var w := mouse_world()
	if w.distance_to(player.position + Vector2(0, -28)) > 220.0:
		mining.decay(dt)
		return

	var origin: Vector2i = Mining.group_of(int(floor(w.x / Core.CELL)), int(floor(w.y / Core.CELL)))
	var result: Dictionary = mining.advance(dt, terrain, origin, selected_id)
	match String(result.get("state", "")):
		"too_hard":
			if _mining_hint_cooldown <= 0.0:
				_mining_hint_cooldown = 1.5
				hud.call("notify", "Эту породу %s не взять" % String(result.get("tool", "руками")))
		"broken":
			var got: Dictionary = result.get("drops", {})
			if selected_id == &"handheld_drill":
				_drill_charge = maxf(0.0, _drill_charge - 1.0)
				if _drill_charge <= 0.0:
					hud.call("notify", "Бур разряжен")
			var lost := 0
			for item_id: Variant in got:
				lost += inventory.add(StringName(item_id), int(got[item_id]))
			if lost > 0:
				hud.call("notify", "Инвентарь полон — часть добычи потеряна")
			_refresh_inventory_ui()
			_dig_puff(w)


# Трещины на блоке, который сейчас ломают. Без обратной связи удержание кнопки
# ощущается как «ничего не происходит», и игрок отпускает раньше времени.
func _draw() -> void:
	if not gameplay_active or mining.fraction() <= 0.0:
		return
	var origin := mining.group

	var rect := Rect2(
		Vector2(origin.x * Core.CELL, origin.y * Core.CELL),
		Vector2(Mining.GROUP * Core.CELL, Mining.GROUP * Core.CELL)
	)
	var done := mining.fraction()
	draw_rect(rect, Color(0.0, 0.0, 0.0, 0.18 + 0.3 * done), true)
	draw_rect(rect, Color(1.0, 0.86, 0.6, 0.35 + 0.45 * done), false, 1.0)
	# полоска снизу блока — сколько осталось
	var bar := Rect2(rect.position + Vector2(0, rect.size.y + 1.0), Vector2(rect.size.x * done, 1.6))
	draw_rect(bar, Color(1.0, 0.78, 0.42, 0.9), true)


func _dig_puff(at: Vector2) -> void:
	var p := CPUParticles2D.new()
	p.amount = 14
	p.lifetime = 0.7
	p.one_shot = true
	p.explosiveness = 0.9
	p.position = at
	p.direction = Vector2(0, -1)
	p.spread = 60.0
	p.gravity = Vector2(0, 320)
	p.initial_velocity_min = 40.0
	p.initial_velocity_max = 130.0
	p.scale_amount_min = 1.0
	p.scale_amount_max = 2.6
	p.color = Color(0.55, 0.45, 0.34, 0.9)
	p.z_index = 15
	add_child(p)
	p.emitting = true
	get_tree().create_timer(1.2).timeout.connect(p.queue_free)


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo and (e.physical_keycode == KEY_I or e.physical_keycode == KEY_TAB):
		if gameplay_active or inventory_ui.is_open():
			inventory_ui.set_open(not inventory_ui.is_open())
			player.set_physics_process(not inventory_ui.is_open())
			_set_enemy_processing(not inventory_ui.is_open())
			hud.call("set_interaction_prompt", "" if inventory_ui.is_open() else interaction_coordinator.get_current_prompt())
			get_viewport().set_input_as_handled()
			return
	if e is InputEventKey and e.pressed and not e.echo and e.keycode == KEY_ESCAPE:
		if inventory_ui.is_open():
			inventory_ui.set_open(false)
			player.set_physics_process(true)
			_set_enemy_processing(true)
			get_viewport().set_input_as_handled()
			return
		if main_menu.is_open() and get_tree().paused and gameplay_active == false and main_menu.get("_mode") == "pause":
			_resume_game()
		elif gameplay_active:
			_pause_game()
		get_viewport().set_input_as_handled()
		return
	if not gameplay_active:
		return
	if inventory_ui.is_open():
		return
	if e.is_action_pressed(&"interact"):
		if not interaction_coordinator.interact_current():
			use_selected_item()
		get_viewport().set_input_as_handled()
		return
	# приближение колесом и щипком на трекпаде — как в браузерной версии
	if e is InputEventMouseButton and e.pressed:
		if e.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom_target = clampf(zoom_target * 1.12, 0.5, 6.0)
		elif e.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_target = clampf(zoom_target / 1.12, 0.5, 6.0)
	elif e is InputEventMagnifyGesture:
		zoom_target = clampf(zoom_target * e.factor, 0.5, 6.0)
	elif e is InputEventKey and e.pressed and not e.echo:
		if e.physical_keycode >= KEY_1 and e.physical_keycode <= KEY_6:
			inventory.select_hotbar(int(e.physical_keycode - KEY_1))
			_refresh_inventory_ui()
		elif e.physical_keycode == KEY_R:
			reload_selected_weapon()
		elif e.physical_keycode == KEY_F1:
			# F1 переключает детализацию породы, если кадры просядут
			var d: float = 0.0 if terrain_detail() > 0.5 else 1.0
			terrain.set_uniform("detail", d)
			_detail = d
		elif e.physical_keycode == KEY_M:
			_toggle_mask_equipment()


var _detail := 1.0


func terrain_detail() -> float:
	return _detail


# АВТОМАТИЧЕСКОЕ КАЧЕСТВО.
#
# Порода считается процедурно на видеокарте, и на слабой машине или в браузере
# это может не уложиться в кадр. Ждать, что игрок сам нажмёт F1, нельзя — он
# просто решит, что игра лагает. Поэтому следим за кадрами сами: держим среднее
# по секунде и понижаем детализацию ступенями, а когда становится легче —
# возвращаем обратно. Возврат делаем с запасом, иначе качество будет дёргаться
# туда-сюда на границе.
var _fps_avg := 60.0
var _quality_hold := 0.0
var _quality_step := 0        # 0 — полная детализация, 1 — упрощённая, 2 — минимум


func _auto_quality(dt: float) -> void:
	# Прогрев. Первые секунды уходят на генерацию мира и сборку тайлов, и кадры
	# там низкие не из-за картинки. Без этой паузы качество падало на старте
	# ни за что и обратно уже не поднималось.
	if t < 3.0 or _auto_off:
		return
	var fps := Engine.get_frames_per_second()
	if fps <= 0.0:
		return
	_fps_avg = lerp(_fps_avg, float(fps), clampf(dt * 1.5, 0.0, 1.0))
	_quality_hold -= dt
	if _quality_hold > 0.0:
		return
	var step := _quality_step
	if _fps_avg < 32.0:
		step = 2
	elif _fps_avg < 46.0:
		step = maxi(step, 1)
	elif _fps_avg > 52.0 and step > 0:
		step -= 1          # стало легко — отдаём детализацию назад
	if step == _quality_step:
		return
	_quality_step = step
	_quality_hold = 3.0   # пауза, чтобы качество не дёргалось на границе
	_apply_quality()


func _apply_quality() -> void:
	match _quality_step:
		0:
			_set_render_scale(1.0)
			terrain.set_uniform("detail", 1.0)
			terrain.set_uniform("fbm_octaves", 3)
			_detail = 1.0
			_set_glow(true)
		1:
			_set_render_scale(1.0)
			# убираем мелкую процедурную деталь: трещины, волокна, зерно
			terrain.set_uniform("detail", 0.35)
			terrain.set_uniform("fbm_octaves", 2)
			_detail = 0.35
			_set_glow(true)
		_:
			terrain.set_uniform("detail", 0.0)
			terrain.set_uniform("fbm_octaves", 1)
			_detail = 0.0
			_set_glow(false)
			# Самый сильный рычаг: рисовать меньше пикселей. Порода считается на
			# каждый пиксель экрана, поэтому 960×540 вместо 1280×720 — это в 1,8
			# раза меньше работы, а растянутая картинка на такой графике почти
			# не отличается. Математику на пиксель урезать бесполезно: замер
			# показал, что упираемся в число пикселей.
			_set_render_scale(0.75)
	print("[кадры] среднее ", int(_fps_avg), " к/с — детализация ступень ", _quality_step)


func _set_glow(on: bool) -> void:
	var we := get_node_or_null("WorldEnvironment") as WorldEnvironment
	if we and we.environment:
		we.environment.glow_enabled = on


# Разрешение отрисовки. Окно остаётся тем же, а мир рисуется в меньший буфер и
# растягивается — интерфейс при этом остаётся резким, потому что режим растяжки
# canvas_items масштабирует всё вместе.
var _base_size := Vector2i.ZERO


func _set_render_scale(k: float) -> void:
	var w := get_window()
	if _base_size == Vector2i.ZERO:
		_base_size = w.content_scale_size
		if _base_size == Vector2i.ZERO:
			_base_size = Vector2i(1280, 720)
	var want := Vector2i(int(float(_base_size.x) * k), int(float(_base_size.y) * k))
	if w.content_scale_size != want:
		w.content_scale_size = want
		print("[кадры] разрешение отрисовки ", want)

# Проверяет, что новые руды действительно попадают в мир и именно туда, куда
# задумано. Добавить породу в таблицу и сгенерировать её — разные вещи: жила
# кладётся только в камень, и если слой на нужной глубине оказался пещерой или
# землёй, руда молча не появится нигде.
extends SceneTree

const WORLD_GEN_PATH := "res://scripts/world_gen.gd"
const SEED := 1337

var failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var gen: Script = load(WORLD_GEN_PATH)
	_expect(gen != null, "world generator loads")
	if gen == null:
		_finish()
		return

	var world: Dictionary = gen.call("generate", SEED)
	var data: PackedByteArray = world.data
	var counts := _count_by_zone(data)

	var galena: Dictionary = counts.get(Core.GALENA, {})
	var sulfur: Dictionary = counts.get(Core.SULFUR, {})

	_expect(_total(galena) > 0, "galena is generated somewhere (%d cells)" % _total(galena))
	_expect(_total(sulfur) > 0, "sulfur is generated somewhere (%d cells)" % _total(sulfur))

	# Галенит только в шахте: если свинец лежит под ногами на старте, идти в
	# шахту незачем, и весь смысл локации пропадает.
	_expect(int(galena.get("mine", 0)) > 0, "galena appears in the mine")
	for zone_id: Variant in galena:
		_expect(String(zone_id) == "mine",
			"galena stays out of %s" % String(zone_id))

	_expect(int(sulfur.get("mine", 0)) > 0 or int(sulfur.get("waste", 0)) > 0,
		"sulfur appears in the mine or the wasteland")
	for zone_id: Variant in sulfur:
		_expect(String(zone_id) == "mine" or String(zone_id) == "waste",
			"sulfur stays out of %s" % String(zone_id))

	# Старые руды не должны были пострадать от добавления новых.
	_expect(_total(counts.get(Core.COAL, {})) > 0, "coal still generates")
	_expect(_total(counts.get(Core.IRON, {})) > 0, "iron still generates")
	_expect(_total(counts.get(Core.COPPER, {})) > 0, "copper still generates")

	_finish()


# Считаем клетки каждой руды по локациям за один проход: мир — восемь тысяч на
# семьсот двадцать, и ходить по нему отдельно ради каждой породы слишком долго.
func _count_by_zone(data: PackedByteArray) -> Dictionary:
	var wanted := [Core.COAL, Core.IRON, Core.COPPER, Core.GALENA, Core.SULFUR]
	var counts: Dictionary = {}
	for m: int in wanted:
		counts[m] = {}
	for x in Core.WW:
		var zone_id := String(Core.zone_at_cell(x).id)
		for y in Core.WH:
			var m := int(data[(y * Core.WW + x) * 2])
			if not counts.has(m):
				continue
			var per_zone: Dictionary = counts[m]
			per_zone[zone_id] = int(per_zone.get(zone_id, 0)) + 1
	return counts


func _total(per_zone: Dictionary) -> int:
	var sum := 0
	for zone_id: Variant in per_zone:
		sum += int(per_zone[zone_id])
	return sum


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("[PASS] ", message)
	else:
		failures += 1
		printerr("[FAIL] ", message)


func _finish() -> void:
	print("[tests] failures: ", failures)
	quit(failures)

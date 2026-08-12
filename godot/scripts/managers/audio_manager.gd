class_name AudioManager
extends Node

const BUS_NAMES: Array[String] = ["Music", "Ambient", "SFX", "UI"]


func _ready() -> void:
	ensure_buses()


func ensure_buses() -> void:
	for bus_name: String in BUS_NAMES:
		if AudioServer.get_bus_index(bus_name) >= 0:
			continue
		AudioServer.add_bus()
		var index := AudioServer.bus_count - 1
		AudioServer.set_bus_name(index, bus_name)
		AudioServer.set_bus_send(index, "Master")


func set_bus_volume(bus_name: String, linear: float) -> void:
	var index := AudioServer.get_bus_index(bus_name)
	if index < 0:
		return
	var safe := clampf(linear, 0.0, 1.0)
	AudioServer.set_bus_mute(index, safe <= 0.001)
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(safe, 0.001)))

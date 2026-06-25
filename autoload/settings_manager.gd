extends Node

## Central store for user-configurable settings. Loads from disk on startup,
## applies them to the engine, and persists changes immediately.

const SAVE_PATH := "user://settings.cfg"
const AUDIO_BUSES: Array[String] = ["Master", "Music", "SFX"]
const MUTE_DB := -80.0

var fullscreen: bool = false
var vsync: bool = true
var bus_volumes: Dictionary = {
	"Master": 1.0,
	"Music": 1.0,
	"SFX": 1.0,
}

func _ready() -> void:
	_load()
	apply_all()

func apply_all() -> void:
	_apply_fullscreen()
	_apply_vsync()
	for bus_name: String in AUDIO_BUSES:
		_apply_bus_volume(bus_name)

func set_fullscreen(enabled: bool) -> void:
	fullscreen = enabled
	_apply_fullscreen()
	_save()

func set_vsync(enabled: bool) -> void:
	vsync = enabled
	_apply_vsync()
	_save()

func set_bus_volume(bus_name: String, linear: float) -> void:
	bus_volumes[bus_name] = clampf(linear, 0.0, 1.0)
	_apply_bus_volume(bus_name)
	_save()

func get_bus_volume(bus_name: String) -> float:
	return bus_volumes.get(bus_name, 1.0)

func _apply_fullscreen() -> void:
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	DisplayServer.window_set_mode(mode)

func _apply_vsync() -> void:
	var mode := DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED
	DisplayServer.window_set_vsync_mode(mode)

func _apply_bus_volume(bus_name: String) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx < 0:
		return
	var linear: float = bus_volumes[bus_name]
	AudioServer.set_bus_mute(idx, linear <= 0.0)
	AudioServer.set_bus_volume_db(idx, linear_to_db(linear) if linear > 0.0 else MUTE_DB)

func _load() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return
	fullscreen = config.get_value("display", "fullscreen", fullscreen)
	vsync = config.get_value("display", "vsync", vsync)
	for bus_name: String in AUDIO_BUSES:
		bus_volumes[bus_name] = config.get_value("audio", bus_name, bus_volumes[bus_name])

func _save() -> void:
	var config := ConfigFile.new()
	config.set_value("display", "fullscreen", fullscreen)
	config.set_value("display", "vsync", vsync)
	for bus_name: String in AUDIO_BUSES:
		config.set_value("audio", bus_name, bus_volumes[bus_name])
	config.save(SAVE_PATH)

# The player's options (game design, "Menus"): full screen, music and effects volume and the
# strength of the screen shake. Kept in user://settings.cfg, saved on every change and applied at
# start. Only the view uses this; the simulation never reads files.
extends RefCounted

const SECTION := "options"
const DEFAULTS := {"fullscreen": false, "music": 100, "effects": 100, "shake": 2}
const SHAKE_NAMES := ["Off", "Low", "Normal"]
const SHAKE_SCALES := [0.0, 0.5, 1.0]
const BUSES := {"music": "Music", "effects": "SFX"}  # Volume key -> audio bus.
const VOLUME_STEP := 10

static var path := "user://settings.cfg"  # Tests point this elsewhere.
static var _values := {}


static func value(key: String) -> Variant:
	if _values.is_empty():
		load_file()
	return _values[key]


# Sets an option, saves it and applies it at once.
static func change(key: String, new_value: Variant) -> void:
	if _values.is_empty():
		load_file()
	_values[key] = _valid(key, new_value)
	save_file()
	apply()


# Reads the file; a missing file, key or a value of the wrong type keeps the default.
static func load_file() -> void:
	_values = DEFAULTS.duplicate()
	var config := ConfigFile.new()
	if not FileAccess.file_exists(path) or config.load(path) != OK:
		return
	for key in DEFAULTS:
		_values[key] = _valid(key, config.get_value(SECTION, key, DEFAULTS[key]))


static func save_file() -> Error:
	var config := ConfigFile.new()
	for key in _values:
		config.set_value(SECTION, key, _values[key])
	return config.save(path)


static func apply() -> void:
	var full: bool = value("fullscreen")
	if (DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN) != full:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if full
				else DisplayServer.WINDOW_MODE_WINDOWED)
	for key in BUSES:
		var bus := bus_index(BUSES[key])
		var percent: int = value(key)
		AudioServer.set_bus_mute(bus, percent == 0)
		if percent > 0:
			AudioServer.set_bus_volume_db(bus, linear_to_db(percent / 100.0))


# The share of the camera's shake and zoom punch: 0 (off), 0.5 (low) or 1.
static func shake_scale() -> float:
	return SHAKE_SCALES[value("shake")]


# The index of the bus with this name, made (sending to Master) when it is missing.
static func bus_index(bus_name: String) -> int:
	var bus := AudioServer.get_bus_index(bus_name)
	if bus == -1:
		AudioServer.add_bus()
		bus = AudioServer.bus_count - 1
		AudioServer.set_bus_name(bus, bus_name)
		AudioServer.set_bus_send(bus, "Master")
	return bus


# The value made safe: the default's type, a volume in whole steps, a known shake level.
static func _valid(key: String, raw: Variant) -> Variant:
	var fallback: Variant = DEFAULTS[key]
	if key == "fullscreen":
		return raw if raw is bool else fallback
	if not (raw is int or raw is float):
		return fallback
	if key == "shake":
		return clampi(int(raw), 0, SHAKE_NAMES.size() - 1)
	return clampi(roundi(float(raw) / VOLUME_STEP) * VOLUME_STEP, 0, 100)

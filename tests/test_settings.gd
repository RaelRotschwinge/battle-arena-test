# Tests of the saved options (settings.gd): a change survives a reload, a broken file falls back to
# safe values, the audio buses are made once and a volume of 0 mutes. They use a file of their own,
# never the player's settings.
extends "res://tests/base_test.gd"

const Settings := preload("res://scripts/view/settings.gd")

const TEST_PATH := "user://test_settings.cfg"


func test_a_change_is_saved_and_loaded_again() -> void:
	_start()
	assert_eq(Settings.value("shake"), 2, "the default is Normal")
	Settings.change("music", 40)
	Settings.change("shake", 0)
	Settings.load_file()
	assert_eq(Settings.value("music"), 40, "music loaded")
	assert_eq(Settings.value("shake"), 0, "shake loaded")
	assert_eq(Settings.shake_scale(), 0.0, "off means no shake")
	_end()


func test_a_broken_file_falls_back_to_safe_values() -> void:
	_start()
	var config := ConfigFile.new()
	config.set_value(Settings.SECTION, "music", "loud")
	config.set_value(Settings.SECTION, "effects", 73)
	config.set_value(Settings.SECTION, "shake", 9)
	config.set_value(Settings.SECTION, "fullscreen", 1)
	config.save(TEST_PATH)
	Settings.load_file()
	assert_eq(Settings.value("music"), 100, "a text is no volume")
	assert_eq(Settings.value("effects"), 70, "rounded to a step")
	assert_eq(Settings.value("shake"), 2, "clamped to a known level")
	assert_eq(Settings.value("fullscreen"), false, "only a bool switches")
	_end()


func test_the_buses_are_made_once_and_zero_mutes() -> void:
	_start()
	Settings.change("effects", 0)
	var count := AudioServer.bus_count
	Settings.apply()
	assert_eq(AudioServer.bus_count, count, "no second set of buses")
	var sfx := AudioServer.get_bus_index("SFX")
	assert_true(sfx != -1 and AudioServer.get_bus_index("Music") != -1, "both buses exist")
	assert_true(AudioServer.is_bus_mute(sfx), "0 % mutes the effects")
	assert_eq(AudioServer.get_bus_send(sfx), &"Master", "sent to Master")
	_end()


func _start() -> void:
	Settings.path = TEST_PATH
	DirAccess.remove_absolute(TEST_PATH)
	Settings.load_file()


func _end() -> void:
	DirAccess.remove_absolute(TEST_PATH)
	Settings.path = "user://settings.cfg"
	Settings._values = {}

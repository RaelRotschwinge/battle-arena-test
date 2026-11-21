# Saves and loads the tuned values of each fighter in user://tuning.cfg, so tuning survives a
# restart. Only the view uses this; the simulation never reads files.
extends RefCounted

const FighterStats := preload("res://scripts/sim/fighter_stats.gd")

const PATH := "user://tuning.cfg"


static func load_into(stats, fighter_id: String = "test") -> void:
	if not FileAccess.file_exists(PATH):
		return
	var config := ConfigFile.new()
	if config.load(PATH) != OK:
		return
	var section := _section(fighter_id)
	for entry in FighterStats.TUNABLE:
		var key: String = entry[0]
		if config.has_section_key(section, key):
			stats.set_value(key, float(config.get_value(section, key)))


static func save(stats, fighter_id: String = "test") -> Error:
	var config := ConfigFile.new()
	if FileAccess.file_exists(PATH):
		config.load(PATH)
	for entry in FighterStats.TUNABLE:
		config.set_value(_section(fighter_id), entry[0], stats.get(entry[0]))
	return config.save(PATH)


static func _section(fighter_id: String) -> String:
	return "fighter_" + fighter_id

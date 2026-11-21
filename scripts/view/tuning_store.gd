# Saves and loads the tuned movement values in user://tuning.cfg, so tuning survives a restart.
# Only the view uses this; the simulation never reads files.
extends RefCounted

const FighterStats := preload("res://scripts/sim/fighter_stats.gd")

const PATH := "user://tuning.cfg"
const SECTION := "fighter"


static func load_into(stats) -> void:
	if not FileAccess.file_exists(PATH):
		return
	var config := ConfigFile.new()
	if config.load(PATH) != OK:
		return
	for entry in FighterStats.TUNABLE:
		var key: String = entry[0]
		if config.has_section_key(SECTION, key):
			stats.set_value(key, float(config.get_value(SECTION, key)))


static func save(stats) -> Error:
	var config := ConfigFile.new()
	for entry in FighterStats.TUNABLE:
		config.set_value(SECTION, entry[0], stats.get(entry[0]))
	return config.save(PATH)

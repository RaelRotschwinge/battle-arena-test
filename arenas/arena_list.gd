# The arenas to choose from (game design, "Arenas"). The test arena stays for training.
extends RefCounted

const ARENAS := {
	"pebble": preload("res://arenas/pebble.gd"),
	"terraces": preload("res://arenas/terraces.gd"),
	"ferry": preload("res://arenas/ferry.gd"),
	"test": preload("res://arenas/test_arena.gd"),
}


static func ids() -> Array:
	return ARENAS.keys()


static func make(id: String):
	return ARENAS.get(id, ARENAS["test"]).new()


static func display_name(id: String) -> String:
	return make(id).arena_name

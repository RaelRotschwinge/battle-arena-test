# The arenas to choose from (game design, "Arenas").
extends RefCounted

const ARENAS := {
	"test": preload("res://arenas/test_arena.gd"),
}


static func ids() -> Array:
	return ARENAS.keys()


static func make(id: String):
	return ARENAS.get(id, ARENAS["test"]).new()


static func display_name(id: String) -> String:
	return make(id).arena_name

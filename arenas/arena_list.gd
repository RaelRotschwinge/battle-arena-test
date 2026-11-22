# The arenas to choose from (game design, "Arenas"), in the order of the arena select screen. The
# test arena stays for training; a random pick leaves it out.
extends RefCounted

const ARENAS := {
	"pebble": preload("res://arenas/pebble.gd"),
	"terraces": preload("res://arenas/terraces.gd"),
	"ferry": preload("res://arenas/ferry.gd"),
	"flatiron": preload("res://arenas/flatiron.gd"),
	"cistern": preload("res://arenas/cistern.gd"),
	"windlass": preload("res://arenas/windlass.gd"),
	"kettle": preload("res://arenas/kettle.gd"),
	"test": preload("res://arenas/test_arena.gd"),
}


static func ids() -> Array:
	return ARENAS.keys()


static func make(id: String):
	return ARENAS.get(id, ARENAS["test"]).new()


static func display_name(id: String) -> String:
	return make(id).arena_name


static func description(id: String) -> String:
	return make(id).description


# Size, platforms and moving parts in two short lines, from the layout itself.
static func facts(id: String) -> String:
	var arena = make(id)
	var width: float = arena.solids[0].size.x if not arena.solids.is_empty() else 0.0
	for r: Rect2 in arena.solids:
		width = maxf(width, r.size.x)
	var size := "Small" if width < 900.0 else ("Medium" if width < 1350.0 else "Large")
	var lines := ["%s,  %d px wide" % [size, int(width)]]
	var parts := ["no platforms" if arena.thin.is_empty() else "%d platform%s" % [
			arena.thin.size(), "" if arena.thin.size() == 1 else "s"]]
	if arena.solids.size() > 1:
		parts.append("walls")
	if arena.has_moving_parts():
		parts.append("moving parts")
	if arena.has_hazards():
		parts.append("hazards")
	lines.append(",  ".join(parts))
	return "\n".join(lines)


# A random arena for a match: never the test arena, and not the last one when there is a choice.
# n picks among the rest (the caller passes something that changes, like the time).
static func pick_random(last: String, n: int) -> String:
	var choices := ids()
	choices.erase("test")
	if choices.size() > 1:
		choices.erase(last)
	return choices[posmod(n, choices.size())]

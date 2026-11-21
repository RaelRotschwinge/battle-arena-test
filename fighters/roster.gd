# The fighters to choose from (game design, "Fighters"). make() builds a fighter's stats: the test
# fighter's values with the fighter's own changes and moves. "test" is the plain test fighter,
# kept for tests and tuning; it is not offered in the menus.
extends RefCounted

const FighterStats := preload("res://scripts/sim/fighter_stats.gd")

const FIGHTERS := {
	"kade": preload("res://fighters/kade.gd"),
	"pip": preload("res://fighters/pip.gd"),
	"brum": preload("res://fighters/brum.gd"),
}


static func ids() -> Array:
	return FIGHTERS.keys()


static func make(id: String) -> FighterStats:
	var stats := FighterStats.new()
	var kind = FIGHTERS.get(id)
	if kind != null:
		kind.apply(stats)
	return stats


static func display_name(id: String) -> String:
	return make(id).fighter_name

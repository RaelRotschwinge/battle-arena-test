# The fighters to choose from (game design, "Fighters"). make() builds a fighter's stats: the test
# fighter's values with the fighter's own changes and moves.
extends RefCounted

const FighterStats := preload("res://scripts/sim/fighter_stats.gd")

const FIGHTERS := {
	"test": null,
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

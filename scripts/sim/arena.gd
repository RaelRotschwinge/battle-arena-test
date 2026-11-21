# The layout of an arena: solid platforms, thin platforms, blast zone and spawn points.
# Pixels, y points down. Thin platforms hold a fighter from above only; down drops through them.
extends RefCounted

var solids: Array[Rect2] = []
var thin: Array[Rect2] = []
# Corners a fighter can hang on: {"point": the corner, "side": -1 when the fighter hangs on the
# left of it, 1 on the right}.
var ledges: Array[Dictionary] = []
var blast_zone := Rect2()
var spawns: Array[Vector2] = []  # Feet positions at the start of a match, one per player.
var respawn_point := Vector2.ZERO  # Above the arena; several fighters respawn side by side.
var arena_name := "Test arena"


# Moves what moves in the arena to where it is at this tick, carrying the fighters on it. Only
# arenas with moving parts change this; the position must follow from the tick alone.
func update(_tick: int, _fighters: Array) -> void:
	pass

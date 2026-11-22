# The layout of an arena: solid platforms, thin platforms, ledges, blast zone, spawn points and
# colors. Pixels, y points down. Thin platforms hold a fighter from above only; down drops
# through them.
extends RefCounted

const Mode = preload("res://scripts/sim/fighter_state.gd").Mode

var solids: Array[Rect2] = []
var thin: Array[Rect2] = []
# Corners a fighter can hang on: {"point": the corner, "side": -1 when the fighter hangs on the
# left of it, 1 on the right}.
var ledges: Array[Dictionary] = []
var blast_zone := Rect2()
var spawns: Array[Vector2] = []  # Feet positions at the start of a match, one per player.
var respawn_point := Vector2.ZERO  # Above the arena; several fighters respawn side by side.
var arena_name := "Test arena"
var description := ""  # One line for the arena select screen: what makes it play differently.
# The paths of moving thin platforms, for drawing: {"thin": index in thin, "a": Vector2, "b":
# Vector2}, the middle of the platform's top at both ends of its way.
var paths: Array[Dictionary] = []
# Colors for the view: sky from top to bottom, ground, the ground's top edge, thin platforms.
var colors := {"sky": [Color("1b1e27"), Color("1b1e27")], "ground": Color("3a3f4b"),
		"ground_top": Color("5b6275"), "thin": Color("8a93a8")}


var hazards_on := true  # The match rule "Hazards"; only arenas with hazards look at it.


# Moves what moves in the arena to where it is at this tick, carrying the fighters on it. Only
# arenas with moving parts or hazards change this; everything must follow from the tick alone.
func update(_tick: int, _fighters: Array) -> void:
	pass


func has_hazards() -> bool:
	return false


# The hazards that hit at the current tick: [{"box": Rect2, "data": attack data}].
func hazard_hits() -> Array:
	return []


# True when a hazard warns of a hit soon in the box (computer players step away).
func hazard_warns(_box: Rect2) -> bool:
	return false


func has_moving_parts() -> bool:
	return not paths.is_empty()


func is_moving(thin_index: int) -> bool:
	for path in paths:
		if path["thin"] == thin_index:
			return true
	return false


# The part of the arena worth showing in a preview: its platforms with some sky around them.
func view_rect() -> Rect2:
	var area: Rect2 = solids[0] if not solids.is_empty() else Rect2(spawns[0], Vector2.ONE)
	for r in solids + thin:
		area = area.merge(r)
	for path in paths:
		area = area.expand(path["a"]).expand(path["b"])
	return area.grow_individual(160.0, 260.0, 160.0, 0.0)


# Ledges at both top corners of each solid platform.
func add_ledges_of_solids() -> void:
	for r in solids:
		ledges.append({"point": r.position, "side": -1})
		ledges.append({"point": Vector2(r.end.x, r.position.y), "side": 1})


# Moves thin platform i to rect and carries the fighters standing on it along.
func move_thin(i: int, rect: Rect2, fighters: Array) -> void:
	var old: Rect2 = thin[i]
	var shift := rect.position - old.position
	thin[i] = rect
	for f in fighters:
		var standing: bool = f.mode not in [Mode.AIR, Mode.HITSTUN, Mode.LEDGE, Mode.CLIMB,
				Mode.RESPAWN, Mode.HELD]
		var half: float = f.stats.width / 2.0
		var over: bool = f.position.x + half > old.position.x and f.position.x - half < old.end.x
		if standing and over and is_equal_approx(f.position.y, old.position.y):
			f.position += shift

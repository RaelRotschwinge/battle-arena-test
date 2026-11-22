# Ferry (game design, "Arenas"): a medium island with two thin platforms and a third that sails
# slowly from side to side above them and carries whoever stands on it. Its place follows from
# the tick alone.
extends "res://scripts/sim/arena.gd"

const MOVING := 2  # Index of the moving platform in thin.
const MIDDLE := 960.0
const SWING := 220.0  # Pixels to each side.
const PERIOD := 720  # Ticks for one way there and back (12 seconds).
const WIDTH := 300.0
const HEIGHT_Y := 450.0


func _init() -> void:
	arena_name = "Ferry"
	description = "A deck sails from side to side above the island: the best spot keeps moving."
	solids.assign([Rect2(410, 800, 1100, 300)])
	thin.assign([Rect2(520, 640, 240, 16), Rect2(1160, 640, 240, 16), _moving_rect(0)])
	add_ledges_of_solids()
	paths.assign([{"thin": MOVING, "a": Vector2(MIDDLE - SWING, HEIGHT_Y),
			"b": Vector2(MIDDLE + SWING, HEIGHT_Y)}])
	blast_zone = Rect2(-640, -800, 3200, 2400)
	spawns.assign([Vector2(600, 800), Vector2(1320, 800), Vector2(840, 800), Vector2(1080, 800)])
	respawn_point = Vector2(960, 250)
	colors = {"sky": [Color("0b3954"), Color("087e8b")], "ground": Color("bfd7ea"),
			"ground_top": Color("f4f1de"), "thin": Color("f4f1de"), "moving": Color("ff5a5f")}


func update(tick: int, fighters: Array) -> void:
	move_thin(MOVING, _moving_rect(tick), fighters)


func _moving_rect(tick: int) -> Rect2:
	var middle := MIDDLE + SWING * sin(TAU * float(tick % PERIOD) / PERIOD)
	return Rect2(middle - WIDTH / 2.0, HEIGHT_Y, WIDTH, 16.0)

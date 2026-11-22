# Windlass (game design, "Arenas"): a medium island with a thin platform on each side and a lift
# in the middle that rises and sinks (14 seconds up and down) and carries whoever stands on it.
# Its place follows from the tick alone.
extends "res://scripts/sim/arena.gd"

const LIFT := 2  # Index of the lift in thin.
const MIDDLE_Y := 530.0
const SWING := 150.0  # Pixels up and down.
const PERIOD := 840
const WIDTH := 280.0


func _init() -> void:
	arena_name = "Windlass"
	description = "The middle goes up and down: ride it high to threaten, drop low to hold the floor."
	solids.assign([Rect2(460, 800, 1000, 300)])
	thin.assign([Rect2(480, 640, 220, 16), Rect2(1220, 640, 220, 16), _lift_rect(0)])
	add_ledges_of_solids()
	paths.assign([{"thin": LIFT, "a": Vector2(960, MIDDLE_Y - SWING),
			"b": Vector2(960, MIDDLE_Y + SWING)}])
	blast_zone = Rect2(-540, -800, 3000, 2350)
	spawns.assign([Vector2(620, 800), Vector2(1300, 800), Vector2(800, 800), Vector2(1120, 800)])
	respawn_point = Vector2(960, 250)
	colors = {"sky": [Color("8ecae6"), Color("e9f5ff")], "ground": Color("6d597a"),
			"ground_top": Color("b56576"), "thin": Color("e56b6f"), "moving": Color("ffb703")}


func update(tick: int, fighters: Array) -> void:
	move_thin(LIFT, _lift_rect(tick), fighters)


func _lift_rect(tick: int) -> Rect2:
	var y := MIDDLE_Y + SWING * sin(TAU * float(tick % PERIOD) / PERIOD)
	return Rect2(960.0 - WIDTH / 2.0, y, WIDTH, 16.0)

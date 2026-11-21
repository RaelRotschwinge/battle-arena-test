# The test arena of M1 (game design, "Arenas"): one solid main platform with open edges, ledges
# and walls high enough for wall jumps, and two thin platforms above it. Kept for training.
extends "res://scripts/sim/arena.gd"


func _init() -> void:
	arena_name = "Test arena"
	solids.assign([Rect2(360, 800, 1200, 300)])
	thin.assign([Rect2(560, 620, 300, 16), Rect2(1060, 620, 300, 16)])
	ledges.assign([
		{"point": Vector2(360, 800), "side": -1},
		{"point": Vector2(1560, 800), "side": 1},
	])
	blast_zone = Rect2(-640, -800, 3200, 2400)
	spawns.assign([Vector2(660, 800), Vector2(1260, 800), Vector2(860, 800), Vector2(1060, 800)])
	respawn_point = Vector2(960, 300)

# Flatiron (game design, "Arenas"): one flat island and nothing else. Nowhere to hide: spacing,
# Sparks and Swoops in the open. The arena to learn the game on.
extends "res://scripts/sim/arena.gd"


func _init() -> void:
	arena_name = "Flatiron"
	description = "Nowhere to hide: one flat island, pure spacing. The place to learn the game."
	solids.assign([Rect2(310, 820, 1300, 280)])
	add_ledges_of_solids()
	blast_zone = Rect2(-560, -850, 3040, 2400)
	spawns.assign([Vector2(560, 820), Vector2(1360, 820), Vector2(780, 820), Vector2(1140, 820)])
	respawn_point = Vector2(960, 260)
	colors = {"sky": [Color("0f0e17"), Color("3d2c8d")], "ground": Color("241b4a"),
			"ground_top": Color("7f5af0"), "thin": Color("7f5af0")}

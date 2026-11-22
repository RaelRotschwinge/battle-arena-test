# Terraces (game design, "Arenas"): a wide stage with three thin platforms on two levels, for
# long fights and play up and down.
extends "res://scripts/sim/arena.gd"


func _init() -> void:
	arena_name = "Terraces"
	description = "A wide stage with platforms on two levels, for long fights up and down."
	solids.assign([Rect2(200, 820, 1520, 300)])
	thin.assign([Rect2(300, 640, 260, 16), Rect2(1360, 640, 260, 16), Rect2(760, 480, 400, 16)])
	add_ledges_of_solids()
	blast_zone = Rect2(-740, -900, 3400, 2550)
	spawns.assign([Vector2(420, 820), Vector2(1500, 820), Vector2(760, 820), Vector2(1160, 820)])
	respawn_point = Vector2(960, 250)
	colors = {"sky": [Color("2d1e2f"), Color("e8a87c")], "ground": Color("5c4033"),
			"ground_top": Color("8a6a4f"), "thin": Color("c38d6b")}

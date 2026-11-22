# Pebble (game design, "Arenas"): a small island with one thin platform. Short distances and
# early knockouts: whoever guards the edges wins.
extends "res://scripts/sim/arena.gd"


func _init() -> void:
	arena_name = "Pebble"
	description = "Short distances and early knockouts: whoever guards the edges wins."
	solids.assign([Rect2(610, 800, 700, 250)])
	thin.assign([Rect2(810, 610, 300, 16)])
	add_ledges_of_solids()
	blast_zone = Rect2(-290, -700, 2500, 2150)
	spawns.assign([Vector2(710, 800), Vector2(1210, 800), Vector2(880, 800), Vector2(1040, 800)])
	respawn_point = Vector2(960, 330)
	colors = {"sky": [Color("1b2a41"), Color("324a5f")], "ground": Color("c9b79c"),
			"ground_top": Color("f2e9dc"), "thin": Color("8fb8a8")}

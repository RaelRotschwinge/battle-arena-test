# Cistern (game design, "Arenas"): a stone bowl. A floor between two pillars that stand 260 px
# higher; their inner faces are walls to jump off, their tops room for one, the ledges are on
# their outer corners. One thin platform in the middle.
extends "res://scripts/sim/arena.gd"


func _init() -> void:
	arena_name = "Cistern"
	description = "A stone bowl: jump off the walls, ambush from the pillar tops, fight up close."
	# The floor first: computer players treat solids[0] as the stage.
	solids.assign([Rect2(390, 840, 1140, 260), Rect2(310, 580, 80, 520),
			Rect2(1530, 580, 80, 520)])
	thin.assign([Rect2(810, 640, 300, 16)])
	ledges.assign([{"point": Vector2(310, 580), "side": -1},
			{"point": Vector2(1610, 580), "side": 1}])
	blast_zone = Rect2(-600, -800, 3120, 2350)
	spawns.assign([Vector2(600, 840), Vector2(1320, 840), Vector2(780, 840), Vector2(1140, 840)])
	respawn_point = Vector2(960, 260)
	colors = {"sky": [Color("0c1f1a"), Color("1e5245")], "ground": Color("2b3a35"),
			"ground_top": Color("6fae8f"), "thin": Color("a3cfb7")}

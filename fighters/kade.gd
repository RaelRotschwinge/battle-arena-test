# Kade, the all-rounder (game design, "Fighters"): the test fighter's values and moves, a round
# head and a scarf. No weakness and no tricks; the longest up-air lift and the strongest forward
# air.
extends RefCounted


static func apply(stats) -> void:
	stats.fighter_name = "Kade"
	stats.weight = 96.0
	stats.look = {"shape": "kade", "colors": [Color("4caf6a"), Color("e0c097"), Color("6b4a2f")]}

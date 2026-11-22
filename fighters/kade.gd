# Kade, the all-rounder (game design, "Fighters"): the test fighter's values and moves, a round
# head and a scarf. No weakness and no tricks; the longest up-air lift and the strongest forward
# air. Special: Spark, a slow orb thrown forward, one at a time.
extends RefCounted

const Attacks := preload("res://scripts/sim/attacks.gd")

# The orb flies 9 px per tick (slower than Kade runs) for 50 ticks; it pokes, it does not knock
# out. A fresh up or down aims it 45 degrees (in the air also down).
const SPARK := {"at": 11, "offset": Vector2(46, -62), "speed": 9.0, "life": 50,
		"size": Vector2(36, 36), "damage": 5.0, "base": 4.0, "growth": 3.0, "angle": 25.0}
const MOVES := {
	"special": {"startup": 10, "active": 1, "recovery": 18, "box": Rect2(), "damage": 5.0,
			"base": 4.0, "growth": 3.0, "angle": 25.0, "aim": "slant", "shot": SPARK},
	"special_air": {"startup": 10, "active": 1, "recovery": 14, "box": Rect2(), "damage": 5.0,
			"base": 4.0, "growth": 3.0, "angle": 25.0, "aim": "slant", "shot": SPARK},
}


static func apply(stats) -> void:
	stats.fighter_name = "Kade"
	stats.weight = 96.0
	stats.look = {"shape": "kade", "colors": [Color("4caf6a"), Color("e0c097"), Color("6b4a2f")]}
	stats.info = {"role": "All-rounder", "difficulty": 1,
			"line": "No weakness, no tricks. The one to learn the game with.",
			"special": "Spark", "special_how": "throws a slow orb, one at a time; up or down aims"}
	var moves: Dictionary = Attacks.ATTACKS.duplicate(true)
	moves.merge(MOVES, true)
	stats.attacks = moves

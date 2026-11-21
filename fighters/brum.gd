# Brum, the heavy one (game design, "Fighters"): wide, slow and strong. Its side attack shrugs
# off light hits while it winds up (armor). A weak up-air lift and a short recovery: Brum must
# not be pushed far out.
extends RefCounted

const Attacks := preload("res://scripts/sim/attacks.gd")

const MOVES := {
	"jab": {"startup": 4, "active": 3, "recovery": 6, "box": Rect2(14, -87, 70, 35),
			"damage": 4.0, "base": 6.2, "growth": 5.3, "angle": 30.0},
	# Hits under 12 % in ticks 5 to 9 deal their damage but do not launch Brum.
	"side": {"startup": 8, "active": 5, "recovery": 16, "box": Rect2(14, -75, 95, 39),
			"damage": 13.0, "base": 10.0, "growth": 20.0, "angle": 38.0,
			"armor": [5, 9], "armor_below": 12.0},
	"up": {"startup": 4, "active": 6, "recovery": 12, "box": Rect2(-42, -174, 119, 157),
			"damage": 11.0, "base": 8.0, "growth": 18.0, "angle": 88.0},
	"down": {"startup": 5, "active": 4, "recovery": 10, "box": Rect2(-90, -35, 180, 35),
			"damage": 9.0, "base": 9.3, "growth": 10.7, "angle": 18.0, "away": true},
	"dash": {"startup": 8, "active": 5, "recovery": 16, "box": Rect2(19, -81, 83, 52),
			"damage": 11.0, "base": 7.5, "growth": 16.0, "angle": 45.0},
	"getup": {"startup": 7, "active": 4, "recovery": 12, "box": Rect2(-70, -46, 141, 42),
			"damage": 9.0, "base": 6.0, "growth": 8.0, "angle": 50.0, "away": true},
	"grab": {"startup": 7, "active": 2, "recovery": 16, "box": Rect2(14, -100, 75, 70),
			"damage": 0.0, "base": 0.0, "growth": 0.0, "angle": 0.0, "grab": true},
	"nair": {"startup": 5, "active": 8, "recovery": 8, "box": Rect2(-60, -118, 120, 120),
			"damage": 9.0, "base": 7.2, "growth": 10.7, "angle": 45.0, "away": true},
	"fair": {"startup": 7, "active": 4, "recovery": 16, "box": Rect2(14, -93, 100, 60),
			"damage": 12.0, "base": 10.0, "growth": 18.0, "angle": 40.0},
	"bair": {"startup": 7, "active": 4, "recovery": 14, "box": Rect2(-110, -93, 92, 52),
			"damage": 11.0, "base": 9.0, "growth": 18.0, "angle": 145.0},
	"up_air": {"startup": 3, "active": 8, "recovery": 10, "box": Rect2(-58, -174, 116, 139),
			"damage": 7.0, "base": 6.5, "growth": 8.0, "angle": 80.0, "away": true},
	"ground_pound": {"startup": 8, "active": 0, "recovery": 16, "box": Rect2(-64, -46, 128, 70),
			"damage": 13.0, "base": 11.1, "growth": 12.5, "angle": -80.0},
}


static func apply(stats) -> void:
	stats.fighter_name = "Brum"
	stats.look = {"shape": "brum", "colors": [Color("9c4a3a"), Color("8d9199"), Color("e0b84a")]}
	stats.width = 74.0
	stats.height = 116.0
	stats.weight = 108.0
	stats.walk_speed = 4.5
	stats.run_speed = 7.5
	stats.ground_accel = 0.9
	stats.air_speed = 4.5
	stats.air_accel = 0.4
	stats.gravity = 0.85
	stats.max_fall_speed = 14.5
	stats.fast_fall_speed = 24.0
	stats.jump_speed = 17.0
	stats.double_jump_speed = 18.0
	stats.max_wall_jumps = 2
	stats.lift_speed = 10.0
	stats.lift_ticks = 8
	var moves: Dictionary = Attacks.ATTACKS.duplicate(true)
	moves.merge(MOVES, true)
	for throw in ["throw_forward", "throw_back", "throw_up", "throw_down"]:
		moves[throw]["damage"] *= 1.2
	stats.attacks = moves

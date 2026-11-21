# Pip, the light one (game design, "Fighters"): small, quick and floaty, with two jumps in the
# air and a neutral air that hits three times. Light hits and a light body: Pip flies early.
extends RefCounted

const Attacks := preload("res://scripts/sim/attacks.gd")

const MOVES := {
	"jab": {"startup": 2, "active": 2, "recovery": 4, "box": Rect2(8, -63, 52, 25),
			"damage": 2.5, "base": 3.8, "growth": 4.0, "angle": 30.0},
	"side": {"startup": 4, "active": 3, "recovery": 9, "box": Rect2(8, -55, 78, 29),
			"damage": 8.0, "base": 7.5, "growth": 17.0, "angle": 38.0},
	"up": {"startup": 2, "active": 5, "recovery": 8, "box": Rect2(-24, -126, 68, 113),
			"damage": 7.0, "base": 6.5, "growth": 15.0, "angle": 88.0},
	"down": {"startup": 3, "active": 3, "recovery": 5, "box": Rect2(-60, -25, 120, 25),
			"damage": 6.0, "base": 6.7, "growth": 6.7, "angle": 18.0, "away": true},
	"dash": {"startup": 5, "active": 4, "recovery": 10, "box": Rect2(12, -59, 53, 38),
			"damage": 8.0, "base": 6.1, "growth": 11.7, "angle": 45.0},
	"getup": {"startup": 5, "active": 4, "recovery": 9, "box": Rect2(-54, -34, 108, 30),
			"damage": 7.0, "base": 5.0, "growth": 7.0, "angle": 50.0, "away": true},
	"grab": {"startup": 5, "active": 2, "recovery": 12, "box": Rect2(8, -72, 50, 50),
			"damage": 0.0, "base": 0.0, "growth": 0.0, "angle": 0.0, "grab": true},
	# Three hits: two light ones that keep the target close, then one that launches.
	"nair": {"startup": 3, "active": 10, "recovery": 4, "box": Rect2(-47, -88, 93, 92),
			"damage": 3.0, "base": 7.2, "growth": 9.3, "angle": 45.0, "away": true,
			"multi": [
				{"at": 0, "damage": 2.0, "base": 2.0, "growth": 0.0, "angle": 90.0, "away": false},
				{"at": 4, "damage": 2.0, "base": 2.0, "growth": 0.0, "angle": 90.0, "away": false},
				{"at": 8},
			]},
	"fair": {"startup": 4, "active": 3, "recovery": 8, "box": Rect2(8, -67, 74, 46),
			"damage": 9.0, "base": 7.5, "growth": 16.0, "angle": 40.0},
	"bair": {"startup": 4, "active": 3, "recovery": 8, "box": Rect2(-82, -67, 70, 38),
			"damage": 9.0, "base": 7.6, "growth": 17.0, "angle": 145.0},
	"up_air": {"startup": 2, "active": 7, "recovery": 6, "box": Rect2(-35, -126, 71, 101),
			"damage": 4.0, "base": 4.0, "growth": 5.0, "angle": 80.0, "away": true},
	"ground_pound": {"startup": 3, "active": 0, "recovery": 6, "box": Rect2(-32, -34, 64, 50),
			"damage": 8.0, "base": 8.9, "growth": 8.8, "angle": -80.0},
}


static func apply(stats) -> void:
	stats.fighter_name = "Pip"
	stats.look = {"shape": "pip", "colors": [Color("6ec6ff"), Color("f6e7c1"), Color("ff9f43")]}
	stats.width = 50.0
	stats.height = 84.0
	stats.weight = 98.0
	stats.walk_speed = 7.0
	stats.run_speed = 12.5
	stats.ground_accel = 1.5
	stats.air_speed = 7.0
	stats.air_accel = 0.6
	stats.gravity = 0.75
	stats.max_fall_speed = 12.5
	stats.fast_fall_speed = 19.0
	stats.jump_speed = 16.0
	stats.double_jump_speed = 15.0
	stats.air_jumps = 2
	stats.lift_speed = 11.0
	stats.lift_ticks = 8
	var moves: Dictionary = Attacks.ATTACKS.duplicate(true)
	moves.merge(MOVES, true)
	for throw in ["throw_forward", "throw_back", "throw_up", "throw_down"]:
		moves[throw]["damage"] *= 0.85
	stats.attacks = moves

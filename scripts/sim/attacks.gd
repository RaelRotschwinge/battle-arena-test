# The test fighter's attacks (game design, "Combat"). Ticks at 60 per second: startup, active and
# recovery. The box is the hitbox relative to the feet of a fighter facing right (x forward,
# negative y up); it is mirrored for a fighter facing left. Angle of the launch in degrees:
# 0 forward, 90 straight up, negative downward. "away": the launch points away from the attacker
# instead of the way it faces. Starting values, tuned in play.
extends RefCounted

const ATTACKS := {
	# On the ground.
	"jab": {"startup": 3, "active": 3, "recovery": 8, "box": Rect2(25, -75, 55, 30),
			"damage": 3.0, "base": 5.0, "growth": 4.0, "angle": 30.0},
	"side": {"startup": 6, "active": 4, "recovery": 16, "box": Rect2(25, -65, 75, 34),
			"damage": 9.0, "base": 9.0, "growth": 18.0, "angle": 38.0},
	"up": {"startup": 5, "active": 5, "recovery": 13, "box": Rect2(-55, -140, 110, 70),
			"damage": 8.0, "base": 10.0, "growth": 21.0, "angle": 88.0},
	"down": {"startup": 4, "active": 3, "recovery": 12, "box": Rect2(20, -24, 85, 24),
			"damage": 6.0, "base": 8.0, "growth": 8.0, "angle": 18.0},
	# In the air.
	"nair": {"startup": 4, "active": 8, "recovery": 10, "box": Rect2(-60, -105, 120, 110),
			"damage": 6.0, "base": 6.0, "growth": 8.0, "angle": 45.0, "away": true},
	"fair": {"startup": 6, "active": 4, "recovery": 14, "box": Rect2(25, -80, 70, 55),
			"damage": 10.0, "base": 8.0, "growth": 17.0, "angle": 40.0},
	# Up and attack in the air: an upward attack that carries the fighter up, once per air time.
	"recovery": {"startup": 2, "active": 10, "recovery": 10, "box": Rect2(-45, -140, 90, 90),
			"damage": 5.0, "base": 8.0, "growth": 6.0, "angle": 80.0, "away": true},
	# Down and attack in the air: hovers for its startup, then drops and stays active until it
	# lands; the recovery is its landing lag.
	"ground_pound": {"startup": 6, "active": 0, "recovery": 12, "box": Rect2(-40, -40, 80, 60),
			"damage": 10.0, "base": 10.0, "growth": 10.0, "angle": -80.0},
}

const GROUND_ATTACKS := ["jab", "side", "up", "down"]

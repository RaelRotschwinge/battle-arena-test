# The test fighter's attacks (game design, "Combat"). Ticks at 60 per second: startup, active and
# recovery. The box is the hitbox relative to the feet of a fighter facing right (x forward,
# negative y up); it is mirrored for a fighter facing left. Angle of the launch in degrees:
# 0 forward, 90 straight up, negative downward. "away": the launch points away from the attacker
# instead of the way it faces. Starting values, tuned in play.
extends RefCounted

const ATTACKS := {
	# On the ground.
	"jab": {"startup": 2, "active": 3, "recovery": 6, "box": Rect2(10, -75, 70, 30),
			"damage": 3.0, "base": 5.0, "growth": 4.0, "angle": 30.0},
	"side": {"startup": 5, "active": 4, "recovery": 10, "box": Rect2(10, -65, 90, 34),
			"damage": 9.0, "base": 9.0, "growth": 18.0, "angle": 38.0},
	# The uppercut: the fist rises from the chest to above the head, so it hits a fighter standing
	# in the attacker too.
	"up": {"startup": 2, "active": 6, "recovery": 10, "box": Rect2(-30, -150, 85, 135),
			"damage": 8.0, "base": 10.0, "growth": 21.0, "angle": 88.0},
	# The low kick sweeps both sides at once, so fighters standing in each other can hit.
	"down": {"startup": 4, "active": 4, "recovery": 8, "box": Rect2(-80, -30, 160, 30),
			"damage": 6.0, "base": 8.0, "growth": 8.0, "angle": 18.0, "away": true},
	# In the air.
	"nair": {"startup": 3, "active": 8, "recovery": 6, "box": Rect2(-60, -105, 120, 110),
			"damage": 6.0, "base": 6.0, "growth": 8.0, "angle": 45.0, "away": true},
	"fair": {"startup": 5, "active": 4, "recovery": 9, "box": Rect2(10, -80, 85, 55),
			"damage": 10.0, "base": 8.0, "growth": 17.0, "angle": 40.0},
	# Up and attack in the air: an upward hit. The first one in a time in the air also carries the
	# fighter up while its hitbox is out.
	"up_air": {"startup": 2, "active": 8, "recovery": 7, "box": Rect2(-45, -150, 90, 120),
			"damage": 5.0, "base": 8.0, "growth": 6.0, "angle": 80.0, "away": true},
	# Down and attack in the air: hovers for its startup, then drops and stays active until it
	# lands; the recovery is its landing lag.
	"ground_pound": {"startup": 4, "active": 0, "recovery": 6, "box": Rect2(-40, -40, 80, 60),
			"damage": 10.0, "base": 10.0, "growth": 10.0, "angle": -80.0},
}

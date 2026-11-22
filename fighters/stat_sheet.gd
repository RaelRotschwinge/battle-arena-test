# The stat sheet of a fighter (game design, "Fighters"): four stats from 1 to 5 pips, each worked
# out from the fighter's own values by a fixed rule, so the sheet follows any change of the data
# and a new fighter fits in without hand-tuning.
extends RefCounted

const NAMES := ["Power", "Speed", "Weight", "Recovery"]


# [power, speed, weight, recovery] for fighter stats s.
static func pips(s) -> Array:
	var power := 0.0
	for move in ["side", "fair", "up"]:
		power += s.attacks[move]["damage"] / 3.0
	var recovery: int = s.air_jumps + 1
	if s.lift_speed * s.lift_ticks >= 130.0:
		recovery += 1
	if s.air_speed >= 6.0:
		recovery += 1
	if s.attacks.has("special_air") and s.attacks["special_air"].has("move"):
		recovery += 1
	return [_scale(power, 6.0, 12.0), _scale(s.run_speed, 7.5, 12.5), _scale(s.weight, 85.0, 110.0),
			clampi(recovery, 1, 5)]


# 1 pip at low, 5 at high, linear between.
static func _scale(value: float, low: float, high: float) -> int:
	return clampi(roundi(1.0 + (value - low) / (high - low) * 4.0), 1, 5)

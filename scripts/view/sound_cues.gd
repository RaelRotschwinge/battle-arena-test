# Watches the fighters every tick and plays the sounds of what they do (sounds.gd): jumps, double
# jumps, landings by weight, dodges and rolls, ledge grabs, the return after a knockout, soft
# steps while running, each fighter's special, and the Kettle's vents bursting; it also tells the
# music how hard the match is going (intensity()). View only: it reads the simulation and changes
# nothing. Make a new one for every match.
extends RefCounted

const FighterState := preload("res://scripts/sim/fighter_state.gd")
const Mode = FighterState.Mode

const CHIME_TICK := 30  # The return chimes this long after the knockout, past its boom.
const DAMAGE_FULL := 150.0  # The damage at which the music is at full intensity.
const STEP := 0.15  # The intensity steps of a close end (two fighters left, a last life).
# Per roster id: the sound a special starts with, and the one when it throws its shot.
const SPECIALS := {"kade": ["spark_charge", "spark_zap"], "pip": ["swoop", ""],
		"brum": ["whirl", ""]}

var _air := []  # Per fighter: in the air in the last tick.
var _modes := []
var _jumps := []
var _fall := []  # Per fighter: its fall speed in the last tick.
var _chimed := []  # Per fighter: the respawn count the return chime played for.


func watch(sim, ids: Array, sounds) -> void:
	if _modes.size() != sim.fighters.size():
		for f in sim.fighters:
			_air.append(_airborne(f))
			_modes.append(f.mode)
			_jumps.append(f.jumps_left)
			_fall.append(0.0)
			_chimed.append(f.respawns)
	for i in sim.fighters.size():
		var f = sim.fighters[i]
		if not f.out:
			_fighter(i, f, ids[i], sounds)
		_air[i] = _airborne(f)
		_modes[i] = f.mode
		_jumps[i] = f.jumps_left
		_fall[i] = f.velocity.y
	sounds.set_intensity(intensity(sim))
	if sim.arena.has_hazards():
		for v in sim.arena.VENTS.size():
			var phase: Array = sim.arena.vent_phase(v)
			if phase[0] == "burst" and phase[1] == 0:
				sounds.play("steam")


func _fighter(i: int, f, id: String, sounds) -> void:
	var was: int = _modes[i]
	if f.mode == Mode.AIR and was == Mode.JUMP_SQUAT:
		sounds.play("jump")
	elif f.mode == Mode.AIR and f.jumps_left < _jumps[i]:
		sounds.play("double_jump")
	if _air[i] and _grounded(f):
		sounds.land(f.stats.weight, _fall[i])
	if f.mode == Mode.DODGE and was != Mode.DODGE:
		sounds.play("roll" if f.dodge == "roll" else "dodge")
	elif f.mode == Mode.TECH and was != Mode.TECH:
		sounds.play("roll")
	if f.mode == Mode.LEDGE and was != Mode.LEDGE:
		sounds.play("ledge")
	if f.respawns != _chimed[i] and (f.mode != Mode.RESPAWN or f.mode_ticks >= CHIME_TICK):
		_chimed[i] = f.respawns
		sounds.play("respawn")
	if f.mode == Mode.GROUND and f.running and f.mode_ticks % 9 == 4 and f.hitlag == 0:
		sounds.play("step", -3.0, 1.1 - 0.15 * clampf((f.stats.weight - 96.0) / 14.0, 0.0, 1.0))
	if f.attack.begins_with("special") and f.hitlag == 0:
		var pair: Array = SPECIALS.get(id, ["special", ""])
		var shot: Dictionary = f.stats.attacks.get(f.attack, {}).get("shot", {})
		if f.attack_ticks == 1:
			sounds.play(pair[0])
		elif pair[1] != "" and f.attack_ticks == shot.get("at", -1):
			sounds.play(pair[1])


# How hard the match is going, for the music: the highest damage of the fighters still in, 0 % to
# 150 % as 0 to 1, a step up when only two fighters are left and another when one of them is on
# its last life.
static func intensity(sim) -> float:
	var top := 0.0
	var left := []
	for f in sim.fighters:
		if not f.out:
			top = maxf(top, f.damage)
			left.append(f)
	var x := top / DAMAGE_FULL
	if left.size() == 2 and sim.fighters.size() >= 2:
		x += STEP
		if left[0].stocks == 1 or left[1].stocks == 1:
			x += STEP
	return clampf(x, 0.0, 1.0)


static func _airborne(f) -> bool:
	return f.mode == Mode.AIR or f.mode == Mode.HITSTUN \
			or (f.mode == Mode.DODGE and f.dodge == "air")


static func _grounded(f) -> bool:
	return f.mode == Mode.GROUND or f.mode == Mode.TECH \
			or (f.mode == Mode.DODGE and f.dodge != "air")

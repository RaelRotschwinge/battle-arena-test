# The attacks of one fighter (game design, "Combat"): which attack an input starts, the phases of
# an attack, its hitbox, and what a hit does to its target. Every fighter has its own moves, in its
# stats (stats.attacks). Parameters: f a fighter state.
extends RefCounted

const Mode = preload("res://scripts/sim/fighter_state.gd").Mode

const PICK_TICKS := 2  # A direction pressed this many ticks after attack still picks the attack.
const UP_FRESH_TICKS := 6  # Up counts for an attack only this many ticks after it was pressed.
const AIM_TICKS := 3  # A direction pressed this many ticks after the special still aims it.
const HITLAG_BASE := 3.0  # Hit pause in ticks: this plus HITLAG_PER_DAMAGE per point of damage.
const HITLAG_PER_DAMAGE := 0.5
const COMBO_GUARD_FROM := 4  # From the fourth hit in a row in hitstun, hitstun gets shorter.
const COMBO_GUARD_STEP := 0.15
const COMBO_GUARD_MIN := 0.4
# A weak hit (launch slower than this) stuns at least WEAK_STUN_BASE plus WEAK_STUN_PER_DAMAGE
# ticks per point of damage, so light hits can start combos at low damage; launching hits are not
# touched.
const WEAK_LAUNCH := 12.0
const WEAK_STUN_BASE := 12.0
const WEAK_STUN_PER_DAMAGE := 1.5
# A strong hit (launch at least this fast) holds both fighters this much longer in the hit pause.
const STRONG_LAUNCH := 25.0
const STRONG_HITLAG := 6


# The data of an attack of the fighter, by default of its current attack.
static func data(f, name: String = "") -> Dictionary:
	return f.stats.attacks[name if name != "" else f.attack]


static func has(f, name: String) -> bool:
	return f.stats.attacks.has(name)


# The data of the hit the current attack deals now. An attack with several hits ("multi": parts
# that start "at" a tick of its active time) uses the values of the current part.
static func hit_data(f) -> Dictionary:
	var a := data(f)
	if not a.has("multi"):
		return a
	var t: int = f.attack_ticks - a["startup"] - 1
	var part := {}
	for hit in a["multi"]:
		if t >= hit["at"]:
			part = hit
	var merged := a.duplicate()
	merged.merge(part, true)
	return merged


# True when the fighter's current attack shrugs off a hit of attack data a (armor): the hit deals
# its damage but does not launch.
static func armored(f, a: Dictionary) -> bool:
	if f.attack == "" or a.get("grab", false):
		return false
	var own := data(f)
	if not own.has("armor"):
		return false
	var window: Array = own["armor"]
	var in_window: bool = f.attack_ticks >= window[0] and f.attack_ticks <= window[1]
	return in_window and a["damage"] < own.get("armor_below", 0.0)


# The ground attack for the held direction: up, down, side (the fighter turns to it) or neutral;
# attack while running is the dash attack. Up counts only when pressed shortly before, so up still
# held from a jump does not count.
static func ground_attack(f, input) -> String:
	if input.up and f.ticks_since_up <= UP_FRESH_TICKS:
		return "up"
	if input.down:
		return "down"
	if f.running and input.left != input.right and has(f, "dash"):
		return "dash"
	if input.left != input.right:
		return "side"
	return "jab"


# The air attack for the held direction, the same way. Left or right against the way the fighter
# faces gives the back air.
static func air_attack(f, input) -> String:
	if input.up and f.ticks_since_up <= UP_FRESH_TICKS:
		return "up_air"
	if input.down:
		return "ground_pound"
	if input.left != input.right:
		var dir := int(input.right) - int(input.left)
		return "bair" if dir == -f.facing and has(f, "bair") else "fair"
	return "nair"


# The special move for where the fighter is: "special" on the ground, "special_air" in the air.
# "" when it has none or may not use it now: its shot still flies, or the air special is limited
# to once per time in the air and was used.
static func special_for(f, in_air: bool) -> String:
	var name := "special_air" if in_air else "special"
	if not has(f, name):
		return ""
	var a := data(f, name)
	if a.has("shot") and f.shot_out:
		return ""
	if in_air and a.get("once_per_air", false) and f.special_used:
		return ""
	return name


static func start_special(f, name: String, input, in_air: bool) -> void:
	start(f, name, input.dir())
	f.special_buffer = 0
	if in_air and data(f).get("once_per_air", false):
		f.special_used = true
	f.special_aim = special_aim(f, input, in_air)


# The way the special goes from the held direction: "eight" any of 8 directions, "slant" forward,
# 45 degrees up or down, "side" left or right; else the way the fighter faces. Up counts only when
# pressed shortly before, as for attacks; on the ground nothing aims down.
static func special_aim(f, input, in_air: bool) -> Vector2:
	var x: int = input.dir()
	var up: bool = input.up and f.ticks_since_up <= UP_FRESH_TICKS
	var y: int = int(input.down) - int(up)
	if not in_air:
		y = mini(y, 0)
	match data(f).get("aim", ""):
		"eight":
			if x == 0 and y == 0:
				return Vector2(f.facing, 0.0)
			return Vector2(x, y).normalized()
		"slant":
			return Vector2(f.facing, y).normalized()
	return Vector2(f.facing, 0.0)


# In the first ticks of a special a newly held direction still aims and turns it.
static func reaim(f, input, in_air: bool) -> void:
	if not f.attack.begins_with("special") or f.attack_ticks > AIM_TICKS:
		return
	if input.dir() != 0:
		f.facing = input.dir()
	f.special_aim = special_aim(f, input, in_air)


static func start(f, name: String, dir: int) -> void:
	f.attack = name
	f.attack_ticks = 0
	f.hit_mask = 0
	f.attack_hits = 0
	f.attack_buffer = 0
	f.lifting = false
	_begin(f, name, dir)


# In the first ticks of an attack a newly pressed direction still changes it, so attack and
# direction need not be pressed in the same tick.
static func repick(f, name: String, dir: int) -> void:
	if f.attack == "" or f.attack_ticks > PICK_TICKS or name == f.attack:
		return
	if f.attack in ["grab", "getup"] or name == "fair" and f.attack == "bair" \
			or f.attack.begins_with("special"):
		return  # A grab, a getup attack and a special stay what they are; a back air too.
	if f.lifting:  # The lift was not used after all.
		f.lifting = false
		f.lift_used = false
	f.attack = name
	_begin(f, name, dir)


static func _begin(f, name: String, dir: int) -> void:
	if dir != 0 and (name in ["side", "fair", "up_air", "dash"] or name.begins_with("special")):
		f.facing = dir
	if name == "up" or name == "up_air":
		f.jump_buffer = 0  # The up press belongs to the attack, not to a jump.
	if name == "up_air" and not f.lift_used and f.stats.lift_ticks > 0:
		f.lifting = true
		f.lift_used = true
		f.fast_falling = false
		f.jump_rising = false


# The up air carries the fighter up during its first lift_ticks ticks.
static func lifts(f) -> bool:
	return f.lifting and f.attack == "up_air" and f.attack_ticks <= f.stats.lift_ticks


# Counts the ticks of the current attack and ends it after its recovery. The ground pound ends
# only on landing.
static func advance(f) -> void:
	if f.attack == "":
		return
	f.attack_ticks += 1
	if f.attack == "ground_pound":
		return
	var a := data(f)
	if a.has("multi"):  # Each new hit of the attack may hit the same fighters again.
		var t: int = f.attack_ticks - a["startup"] - 1
		for hit in a["multi"]:
			if hit["at"] > 0 and hit["at"] == t:
				f.hit_mask = 0
	if f.attack_ticks > a["startup"] + a["active"] + a["recovery"]:
		f.attack = ""


# Jumps to the end of the active time of the current attack, minus cut ticks of its recovery: a
# dash that hits, is blocked or reaches a wall stops there.
static func end_active(f, cut: int) -> void:
	var a := data(f)
	f.attack_ticks = maxi(f.attack_ticks, a["startup"] + a["active"] + cut)


static func in_startup(f) -> bool:
	return f.attack != "" and f.attack_ticks <= data(f)["startup"]


static func is_active(f) -> bool:
	if f.attack == "":
		return false
	var a := data(f)
	if f.attack_ticks <= a["startup"]:
		return false
	return f.attack == "ground_pound" or f.attack_ticks <= a["startup"] + a["active"]


static func ticks_left(f) -> int:
	if f.attack == "":
		return 0
	var a := data(f)
	return maxi(a["startup"] + a["active"] + a["recovery"] - f.attack_ticks, 0)


# The hitbox in the arena, an empty Rect2 when no hitbox is active.
static func hitbox(f) -> Rect2:
	if not is_active(f):
		return Rect2()
	return box_in_arena(f, data(f)["box"])


# A box given relative to the feet of a fighter facing right, placed for the fighter's facing.
static func box_in_arena(f, box: Rect2) -> Rect2:
	var x: float = box.position.x if f.facing > 0 else -box.end.x
	return Rect2(f.position + Vector2(x, box.position.y), box.size)


# Launch speed in pixels per tick (game design, "Core rules"), from the damage after the hit.
static func launch_speed(a: Dictionary, damage: float, s, scale: float = 1.0) -> float:
	return (a["base"] + a["growth"] * damage / 100.0 * 100.0 / s.weight) * s.knockback_scale \
			* scale


static func hitlag_ticks(a: Dictionary) -> int:
	return int(HITLAG_BASE + a["damage"] * HITLAG_PER_DAMAGE)


# The side the attack launches the target to: the way the attacker faces, or away from the
# attacker for attacks marked "away".
static func launch_side(attacker, target, a: Dictionary) -> int:
	if a.get("away", false) and target.position.x != attacker.position.x:
		return 1 if target.position.x > attacker.position.x else -1
	return attacker.facing


# Applies a hit of attack data a, launching to side, on target. damage_scale and knockback_scale
# come from stale moves. The launch itself waits for the end of the hit pause, where the target's
# held direction bends it (DI). Returns the launch speed.
static func apply_hit(target, a: Dictionary, side: int, damage_scale: float = 1.0,
		knockback_scale: float = 1.0) -> float:
	var s = target.stats
	var in_combo: bool = target.mode == Mode.HITSTUN or target.launch_pending
	target.combo_hits = target.combo_hits + 1 if in_combo else 1
	target.damage += a["damage"] * damage_scale
	var speed := launch_speed(a, target.damage, s, knockback_scale)
	var angle := deg_to_rad(a["angle"])
	target.velocity = Vector2(cos(angle) * side, -sin(angle)) * speed
	var guard := 1.0
	if target.combo_hits >= COMBO_GUARD_FROM:
		guard = maxf(1.0 - COMBO_GUARD_STEP * (target.combo_hits - COMBO_GUARD_FROM + 1),
				COMBO_GUARD_MIN)
	var stun: float = speed * s.hitstun_factor
	if speed < WEAK_LAUNCH:
		stun = maxf(stun, WEAK_STUN_BASE + WEAK_STUN_PER_DAMAGE * a["damage"] * damage_scale)
	target.hitstun = roundi(stun * guard)
	target.hitstun_total = target.hitstun
	var pause: int = hitlag_ticks(a) + (STRONG_HITLAG if speed >= STRONG_LAUNCH else 0)
	target.hitlag = maxi(target.hitlag, pause)
	target.launch_pending = true
	target.mode = Mode.HITSTUN
	target.mode_ticks = 0
	target.facing = -side if side != 0 else target.facing
	target.attack = ""
	target.lag = 0
	target.ledge = -1
	target.running = false
	target.fast_falling = false
	target.jump_rising = false
	target.lifting = false
	target.lift_used = false  # A hit gives the lift of the up air back,
	target.air_dodge_used = false  # the air dodge, the air special
	target.ledge_invuln_ok = true  # and the invulnerability of the next ledge grab.
	target.special_used = false
	target.special_buffer = 0
	target.dodge = ""
	target.shield_stun = 0
	target.shield_drop = 0
	target.holding = -1
	target.held_by = -1
	target.climb_next = ""
	return speed

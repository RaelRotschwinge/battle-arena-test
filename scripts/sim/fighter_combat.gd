# The attacks of one fighter (game design, "Combat"): which attack an input starts, the phases of
# an attack, its hitbox, and what a hit does to its target. Parameters: f a fighter state, s the
# fighter stats.
extends RefCounted

const Attacks := preload("res://scripts/sim/attacks.gd")
const Mode = preload("res://scripts/sim/fighter_state.gd").Mode

const PICK_TICKS := 2  # A direction pressed this many ticks after attack still picks the attack.
const UP_FRESH_TICKS := 6  # Up counts for an attack only this many ticks after it was pressed.
const HITLAG_BASE := 3.0  # Hit pause in ticks: this plus HITLAG_PER_DAMAGE per point of damage.
const HITLAG_PER_DAMAGE := 0.5


static func data(name: String) -> Dictionary:
	return Attacks.ATTACKS[name]


# The ground attack for the held direction: up, down, side (the fighter turns to it) or neutral.
# Up counts only when pressed shortly before, so up still held from a jump does not count.
static func ground_attack(f, input) -> String:
	if input.up and f.ticks_since_up <= UP_FRESH_TICKS:
		return "up"
	if input.down:
		return "down"
	if input.left != input.right:
		return "side"
	return "jab"


# The air attack for the held direction, the same way.
static func air_attack(f, input) -> String:
	if input.up and f.ticks_since_up <= UP_FRESH_TICKS:
		return "up_air"
	if input.down:
		return "ground_pound"
	if input.left != input.right:
		return "fair"
	return "nair"


static func start(f, name: String, dir: int) -> void:
	f.attack = name
	f.attack_ticks = 0
	f.hit_mask = 0
	f.attack_buffer = 0
	f.lifting = false
	_begin(f, name, dir)


# In the first ticks of an attack a newly pressed direction still changes it, so attack and
# direction need not be pressed in the same tick.
static func repick(f, name: String, dir: int) -> void:
	if f.attack == "" or f.attack_ticks > PICK_TICKS or name == f.attack:
		return
	if f.lifting:  # The lift was not used after all.
		f.lifting = false
		f.lift_used = false
	f.attack = name
	_begin(f, name, dir)


static func _begin(f, name: String, dir: int) -> void:
	if dir != 0 and (name == "side" or name == "fair" or name == "up_air"):
		f.facing = dir
	if name == "up" or name == "up_air":
		f.jump_buffer = 0  # The up press belongs to the attack, not to a jump.
	if name == "up_air" and not f.lift_used:
		f.lifting = true
		f.lift_used = true
		f.fast_falling = false
		f.jump_rising = false


# The up air carries the fighter up while its hitbox is out.
static func lifts(f) -> bool:
	if not f.lifting or f.attack != "up_air":
		return false
	var a := data("up_air")
	return f.attack_ticks <= a["startup"] + a["active"]


# Counts the ticks of the current attack and ends it after its recovery. The ground pound ends
# only on landing.
static func advance(f) -> void:
	if f.attack == "":
		return
	f.attack_ticks += 1
	if f.attack == "ground_pound":
		return
	var a := data(f.attack)
	if f.attack_ticks > a["startup"] + a["active"] + a["recovery"]:
		f.attack = ""


static func in_startup(f) -> bool:
	return f.attack != "" and f.attack_ticks <= data(f.attack)["startup"]


static func is_active(f) -> bool:
	if f.attack == "":
		return false
	var a := data(f.attack)
	if f.attack_ticks <= a["startup"]:
		return false
	return f.attack == "ground_pound" or f.attack_ticks <= a["startup"] + a["active"]


static func ticks_left(f) -> int:
	if f.attack == "":
		return 0
	var a := data(f.attack)
	return maxi(a["startup"] + a["active"] + a["recovery"] - f.attack_ticks, 0)


# The hitbox in the arena, an empty Rect2 when no hitbox is active.
static func hitbox(f) -> Rect2:
	if not is_active(f):
		return Rect2()
	var box: Rect2 = data(f.attack)["box"]
	var x: float = box.position.x if f.facing > 0 else -box.end.x
	return Rect2(f.position + Vector2(x, box.position.y), box.size)


# Launch speed in pixels per tick (game design, "Core rules"), from the damage after the hit.
static func launch_speed(a: Dictionary, damage: float, s) -> float:
	return (a["base"] + a["growth"] * damage / 100.0 * 100.0 / s.weight) * s.knockback_scale


static func hitlag_ticks(a: Dictionary) -> int:
	return int(HITLAG_BASE + a["damage"] * HITLAG_PER_DAMAGE)


# The side the attack launches the target to: the way the attacker faces, or away from the
# attacker for attacks marked "away".
static func launch_side(attacker, target, a: Dictionary) -> int:
	if a.get("away", false) and target.position.x != attacker.position.x:
		return 1 if target.position.x > attacker.position.x else -1
	return attacker.facing


# Applies a hit of the attack name, launching to side, on target. Returns the launch speed.
static func apply_hit(target, name: String, side: int, s) -> float:
	var a := data(name)
	target.damage += a["damage"]
	var speed := launch_speed(a, target.damage, s)
	var angle := deg_to_rad(a["angle"])
	target.velocity = Vector2(cos(angle) * side, -sin(angle)) * speed
	target.hitstun = roundi(speed * s.hitstun_factor)
	target.hitlag = maxi(target.hitlag, hitlag_ticks(a))
	target.mode = Mode.HITSTUN
	target.mode_ticks = 0
	target.facing = -side
	target.attack = ""
	target.lag = 0
	target.ledge = -1
	target.running = false
	target.fast_falling = false
	target.jump_rising = false
	target.lifting = false
	target.lift_used = false  # A hit gives the lift of the up air back.
	return speed

# The attacks of one fighter (game design, "Combat"): which attack an input starts, the phases of
# an attack, its hitbox, and what a hit does to its target. Parameters: f a fighter state, s the
# fighter stats.
extends RefCounted

const Attacks := preload("res://scripts/sim/attacks.gd")
const Mode = preload("res://scripts/sim/fighter_state.gd").Mode

const HITLAG_BASE := 3.0  # Hit pause in ticks: this plus HITLAG_PER_DAMAGE per point of damage.
const HITLAG_PER_DAMAGE := 0.5


static func data(name: String) -> Dictionary:
	return Attacks.ATTACKS[name]


# The ground attack for the held direction: up, down, side (the fighter turns to it) or neutral.
static func ground_attack(input) -> String:
	if input.up:
		return "up"
	if input.down:
		return "down"
	if input.left != input.right:
		return "side"
	return "jab"


# The air attack for the held direction, "" when there is none: up is the recovery move, once
# per time in the air.
static func air_attack(f, input) -> String:
	if input.up:
		return "" if f.recovery_used else "recovery"
	if input.down:
		return "ground_pound"
	if input.left != input.right:
		return "fair"
	return "nair"


static func start(f, name: String, dir: int) -> void:
	f.attack = name
	f.attack_ticks = 0
	f.hit_mask = 0
	if dir != 0 and (name == "side" or name == "fair" or name == "recovery"):
		f.facing = dir
	if name == "recovery":
		f.recovery_used = true
	f.fast_falling = false
	f.jump_rising = false


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
	target.recovery_used = false  # A hit gives the recovery move back.
	return speed

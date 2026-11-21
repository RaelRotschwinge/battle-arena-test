# Defence and the ways out of combos (game design, "Defence"): the shield with parry and break,
# spot dodge, roll and air dodge, directional influence, drift, techs, the early way out of
# hitstun, and stale moves. Parameters: f a fighter state.
extends RefCounted

const Mode = preload("res://scripts/sim/fighter_state.gd").Mode
const FighterCombat := preload("res://scripts/sim/fighter_combat.gd")

const SHIELD_MAX := 100.0
const SHIELD_DECAY := 0.25  # Per tick while held.
const SHIELD_REGEN := 0.15  # Per tick, from SHIELD_REGEN_WAIT ticks after letting go.
const SHIELD_REGEN_WAIT := 30
const SHIELD_DROP_TICKS := 6  # Lowering the shield; a jump, dodge or new shield cuts it short.
const SHIELD_BREAK_TICKS := 120
const SHIELD_AFTER_BREAK := 40.0
const SHIELD_STUN_BASE := 4.0  # Ticks a hit shield cannot act: base plus per point of damage.
const SHIELD_STUN_PER_DAMAGE := 0.6
const SHIELD_PUSH_BASE := 3.0  # Slide of a hit shield in pixels per tick, fading each tick.
const SHIELD_PUSH_PER_DAMAGE := 0.4
const SHIELD_PUSH_FADE := 0.8
const PARRY_TICKS := 5  # A shield pressed this short before a hit parries it.
const PARRY_FREEZE := 12  # The parried attacker stands frozen this long.
const FLICK_TICKS := 3  # A direction pressed this short before the shield key dodges at once.
# Dodges: total ticks, invulnerable from and to (ticks of the dodge), distance in pixels.
const SPOT_DODGE := {"total": 22, "from": 3, "to": 16, "distance": 0.0}
const ROLL := {"total": 28, "from": 3, "to": 18, "distance": 150.0}
const AIR_DODGE := {"total": 30, "from": 3, "to": 20, "distance": 130.0}
const AIR_DODGE_MOVE_TICKS := 14
const DODGE_STREAK_TICKS := 90  # A dodge this soon after the last one has less invulnerability,
const DODGE_STREAK_CUT := 3  # this many ticks less per dodge in a row,
const DODGE_MIN_INVULN := 6  # but never less than this.
const WAVELAND_LAG := 6  # Landing during an air dodge: the fighter slides on with this lag.
const TECH_WINDOW := 10  # The shield pressed this short before hitting the ground in hitstun.
const TECH_LOCKOUT := 30  # After such a press, a new press opens no window for this long.
const TECH_IN_PLACE := {"total": 20, "invuln": 14, "distance": 0.0}
const TECH_ROLL := {"total": 30, "invuln": 18, "distance": 120.0}
const WALL_TECH_INVULN := 10
const DI_DEGREES := 15.0  # The held direction bends a launch by at most this much.
const DRIFT_ACCEL := 0.3  # Steering in hitstun, up to DRIFT_MAX pixels per tick.
const DRIFT_MAX := 3.0
const HITSTUN_CANCEL := 0.8  # After this share of hitstun, a double jump or air dodge ends it.
const STALE_QUEUE := 8  # The last attacks of a fighter that hit.
const STALE_STEP := 0.07  # Damage lost per copy of the same attack in the queue,
const STALE_MIN := 0.6  # down to this share. Knockback loses a third as much.
const LEDGE_INVULN := 30
const GRAB_HOLD_TICKS := 20  # The holder throws at the latest after this long (forward).
const GRAB_MIN_TICKS := 3  # A direction before this does not throw yet.
const GRAB_IMMUNE_TICKS := 40  # A released or thrown fighter cannot be grabbed this long.


# Called every tick for every fighter that is not frozen: timers and shield regeneration.
static func tick(f) -> void:
	if f.ticks_since_dodge < 1000:
		f.ticks_since_dodge += 1
	if f.tech_window > 0:
		f.tech_window -= 1
	if f.tech_lockout > 0:
		f.tech_lockout -= 1
	if f.mode == Mode.SHIELD:
		f.shield_rest = 0
	else:
		f.shield_rest += 1
		if f.shield_rest >= SHIELD_REGEN_WAIT:
			f.shield_hp = minf(f.shield_hp + SHIELD_REGEN, SHIELD_MAX)


# A shield press in hitstun opens the tech window, unless an earlier press locks it.
static func press_in_hitstun(f) -> void:
	if f.tech_lockout == 0:
		f.tech_window = TECH_WINDOW
		f.tech_lockout = TECH_LOCKOUT


# The shield shrinks with its health: radius from 100 % down to half.
static func shield_radius(f) -> float:
	var s = f.stats
	var full := maxf(s.width, s.height) * 0.62
	return full * (0.5 + 0.5 * clampf(f.shield_hp / SHIELD_MAX, 0.0, 1.0))


static func start_shield(f) -> void:
	f.mode = Mode.SHIELD
	f.mode_ticks = 0
	f.running = false
	f.shield_drop = 0
	f.shield_stun = 0
	f.shield_push = 0.0


# kind "spot", "roll" or "air"; direction: the roll's side, or the air dodge's direction (zero
# for one in place).
static func start_dodge(f, kind: String, direction: Vector2) -> void:
	f.dodge_streak = f.dodge_streak + 1 if f.ticks_since_dodge < DODGE_STREAK_TICKS else 0
	f.ticks_since_dodge = 0
	f.mode = Mode.DODGE
	f.mode_ticks = 0
	f.dodge = kind
	f.dodge_dir = direction.normalized() if direction != Vector2.ZERO else Vector2.ZERO
	f.attack = ""
	f.running = false
	f.shield_drop = 0
	f.shield_buffer = 0
	f.fast_falling = false
	f.jump_rising = false
	f.lifting = false
	if kind == "air":
		f.air_dodge_used = true
	elif kind == "roll":
		f.facing = -int(signf(direction.x))  # Rolled past: faces back the way it came.


static func dodge_data(f) -> Dictionary:
	match f.dodge:
		"spot":
			return SPOT_DODGE
		"roll":
			return ROLL
	return AIR_DODGE


# True while a dodge makes the fighter untouchable. Dodges in a row lose invulnerable ticks.
static func intangible(f) -> bool:
	if f.mode != Mode.DODGE:
		return false
	var d := dodge_data(f)
	var last: int = maxi(d["to"] - DODGE_STREAK_CUT * f.dodge_streak,
			d["from"] + DODGE_MIN_INVULN - 1)
	return f.mode_ticks >= d["from"] and f.mode_ticks <= last


# Moves a dodging fighter by one tick. Returns true when the dodge is over.
static func dodge_control(f, s) -> bool:
	var d := dodge_data(f)
	var t: int = f.mode_ticks
	if f.dodge == "air":
		if t <= AIR_DODGE_MOVE_TICKS:
			f.velocity = f.dodge_dir * (d["distance"] / AIR_DODGE_MOVE_TICKS)
		elif t == AIR_DODGE_MOVE_TICKS + 1:  # The dash ends sharply.
			f.velocity = f.dodge_dir * (d["distance"] / AIR_DODGE_MOVE_TICKS) * 0.25
		else:
			f.velocity.y = minf(f.velocity.y + s.gravity, s.max_fall_speed)
			f.velocity.x = move_toward(f.velocity.x, 0.0, s.air_friction * 4.0)
	elif f.dodge == "roll":
		var moving: bool = t >= d["from"] and t <= d["to"]
		var speed: float = d["distance"] / float(d["to"] - d["from"] + 1)
		f.velocity.x = f.dodge_dir.x * speed if moving else 0.0
	else:
		f.velocity.x = move_toward(f.velocity.x, 0.0, s.ground_friction)
	return t >= d["total"]


# The early way out of hitstun: after most of it, a buffered double jump or air dodge ends it.
static func can_cancel_hitstun(f) -> bool:
	if f.hitstun <= 0 or f.hitstun_total <= 0:
		return false
	var elapsed: int = f.hitstun_total - f.hitstun
	if elapsed < ceili(HITSTUN_CANCEL * f.hitstun_total):
		return false
	return (f.jump_buffer > 0 and f.jumps_left > 0) \
			or (f.shield_buffer > 0 and not f.air_dodge_used)


# Directional influence at the end of the hit pause: the held direction bends the launch by up to
# DI_DEGREES, the most when it points across the launch.
static func apply_di(f, input) -> void:
	f.launch_pending = false
	var held := Vector2(input.dir(), int(input.down) - int(input.up))
	if held == Vector2.ZERO or f.velocity == Vector2.ZERO:
		return
	var launch: Vector2 = f.velocity.normalized()
	var across := launch.cross(held.normalized())
	f.velocity = f.velocity.rotated(deg_to_rad(DI_DEGREES) * across)


# Steering in hitstun: a little, toward the held side.
static func drift(f, dir: int) -> void:
	if dir != 0 and f.velocity.x * dir < DRIFT_MAX:
		f.velocity.x = dir * minf(f.velocity.x * dir + DRIFT_ACCEL, DRIFT_MAX)


# Teching on the ground: a direction rolls, none stays in place. Invulnerable for a while.
static func ground_tech(f, dir: int) -> void:
	var d := TECH_ROLL if dir != 0 else TECH_IN_PLACE
	f.mode = Mode.TECH
	f.mode_ticks = 0
	f.hitstun = 0
	f.tech_window = 0
	f.velocity = Vector2.ZERO
	f.dodge = "roll" if dir != 0 else "spot"
	f.dodge_dir = Vector2(dir, 0.0)
	f.invuln = maxi(f.invuln, d["invuln"])
	f.combo_hits = 0
	f.jumps_left = f.stats.air_jumps
	f.air_dodge_used = false


# Moves a teching fighter. Returns true when the tech is over.
static func tech_control(f) -> bool:
	var d := TECH_ROLL if f.dodge == "roll" else TECH_IN_PLACE
	if f.dodge == "roll" and f.mode_ticks < d["total"] - 6:
		f.velocity.x = f.dodge_dir.x * d["distance"] / float(d["total"] - 6)
	else:
		f.velocity.x = 0.0
	return f.mode_ticks >= d["total"]


static func wall_tech(f) -> void:
	f.mode = Mode.AIR
	f.mode_ticks = 0
	f.hitstun = 0
	f.tech_window = 0
	f.velocity = Vector2.ZERO
	f.invuln = maxi(f.invuln, WALL_TECH_INVULN)
	f.combo_hits = 0


# A hit on a raised shield: a parry when the shield was pressed just before, else the shield takes
# the damage and slides back; at zero it breaks. Returns "parry", "block" or "break".
static func hit_shield(target, a: Dictionary, side: int) -> String:
	if target.ticks_since_shield <= PARRY_TICKS:
		return "parry"
	target.shield_hp -= a["damage"]
	if target.shield_hp <= 0.0:
		break_shield(target)
		return "break"
	target.shield_stun = roundi(SHIELD_STUN_BASE + SHIELD_STUN_PER_DAMAGE * a["damage"])
	target.shield_push = side * (SHIELD_PUSH_BASE + SHIELD_PUSH_PER_DAMAGE * a["damage"])
	target.hitlag = maxi(target.hitlag, FighterCombat.hitlag_ticks(a))
	return "block"


static func break_shield(f) -> void:
	f.mode = Mode.SHIELD_BREAK
	f.mode_ticks = 0
	f.shield_hp = 0.0
	f.shield_stun = 0
	f.shield_push = 0.0
	f.velocity = Vector2(0.0, -8.0)  # Pops up a little.


# Stale moves: the share of damage and knockback an attack keeps, from how often it is among the
# attacker's last hits.
static func stale_scales(attacker, name: String) -> Vector2:
	var copies: int = attacker.stale.count(name)
	var damage_scale := maxf(1.0 - STALE_STEP * copies, STALE_MIN)
	return Vector2(damage_scale, 1.0 - (1.0 - damage_scale) / 3.0)


static func add_stale(attacker, name: String) -> void:
	attacker.stale.append(name)
	while attacker.stale.size() > STALE_QUEUE:
		attacker.stale.pop_front()


static func can_be_grabbed(f) -> bool:
	return f.grab_immune == 0 and f.held_by < 0 and f.holding < 0 \
			and f.mode != Mode.LEDGE and f.mode != Mode.CLIMB


# The throw a holder picks with its held direction, "" while it still waits.
static func pick_throw(f, input) -> String:
	if f.mode_ticks < GRAB_MIN_TICKS:
		return ""
	if input.up:
		return "throw_up"
	if input.down:
		return "throw_down"
	var dir: int = input.dir()
	if dir == -f.facing:
		return "throw_back"
	if dir == f.facing or f.mode_ticks >= GRAB_HOLD_TICKS:
		return "throw_forward"
	return ""

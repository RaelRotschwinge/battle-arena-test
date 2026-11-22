# The pose of a fighter in one tick, worked out from its state (plus a few timers of the view):
# where the hands and feet are, how the body leans, squashes and turns, how the eyes look. All in
# the fighter's own space: feet at the origin, facing right, y down. The attacks and specials are
# posed in fighter_strike.gd. Drawing only.
extends RefCounted

const Mode = preload("res://scripts/sim/fighter_state.gd").Mode

enum Eyes { OPEN, SHUT, HURT, DIZZY, FOCUS }

# Pinned limbs are given where they must show (the hitbox, the ledge, the ground), not on the
# leaning body: finalize() moves them onto it.
const PIN_HAND_F := 1
const PIN_HAND_B := 2
const PIN_FOOT_F := 4
const PIN_FOOT_B := 8
const PIN_HANDS := 3
const PIN_FEET := 12

# Where the limbs sit on each shape, as shares of width and height: the front shoulder and hip,
# the front hand and foot at rest (the back ones mirror them). Pip's hands are its wing tips.
const RIGS := {
	"kade": {"shoulder": Vector2(0.27, -0.6), "hip": Vector2(0.15, -0.27),
			"hand": Vector2(0.44, -0.36), "foot": Vector2(0.2, 0.0)},
	"pip": {"shoulder": Vector2(0.3, -0.5), "hip": Vector2(0.17, -0.14),
			"hand": Vector2(0.62, -0.32), "foot": Vector2(0.18, 0.0)},
	"brum": {"shoulder": Vector2(0.47, -0.64), "hip": Vector2(0.2, -0.22),
			"hand": Vector2(0.62, -0.3), "foot": Vector2(0.25, 0.0)},
	"test": {"shoulder": Vector2(0.3, -0.6), "hip": Vector2(0.16, -0.25),
			"hand": Vector2(0.46, -0.36), "foot": Vector2(0.2, 0.0)},
}
const LEDGE_HAND_ABOVE := 10.0  # As in fighter_motion.gd: the box top above the ledge.
const TUMBLE_SPEED := 9.0  # Launched faster than this, a fighter tumbles.


class Pose:
	var shape := "test"
	var w := 60.0
	var h := 100.0
	var shoulder := Vector2.ZERO  # The front shoulder; the back one mirrors it.
	var hip := Vector2.ZERO
	var rest_hand := Vector2.ZERO
	var rest_foot := Vector2.ZERO
	var hand_f := Vector2.ZERO
	var hand_b := Vector2.ZERO
	var foot_f := Vector2.ZERO
	var foot_b := Vector2.ZERO
	var head := Vector2.ZERO  # Shift of the head from its place.
	var offset := Vector2.ZERO  # Shift of the whole figure.
	var stretch := Vector2.ONE  # Squash and stretch about the feet.
	var tilt := 0.0  # Turn about the pivot; positive leans forward.
	var pivot := Vector2.ZERO
	var flip := false  # Shown mirrored (the back of a spin).
	var eyes := Eyes.OPEN
	var gaze := Vector2(1.0, 0.0)  # Where the pupils look.
	var beak := 0.0  # Pip's beak, 0 shut to 1 wide open.
	var ball := 0.0  # Curled up into a ball, 0 to 1 (the shape of its afterimages).
	var pins := 0
	var snap := 0.45  # How fast the view blends into this pose (1: at once).
	var smears: Array = []  # Trails of fast limbs, see fighter_look.gd.
	# Filled by finalize(): the limbs on the body as drawn.
	var hf := Vector2.ZERO
	var hb := Vector2.ZERO
	var ff := Vector2.ZERO
	var fb := Vector2.ZERO

	func back(v: Vector2) -> Vector2:
		return Vector2(-v.x, v.y)


static func make(f, ticks: int, anim: Dictionary) -> Pose:
	var s = f.stats
	var p := Pose.new()
	p.shape = s.look.get("shape", "test")
	if not RIGS.has(p.shape):
		p.shape = "test"
	p.w = s.width
	p.h = s.height
	var rig: Dictionary = RIGS[p.shape]
	var size := Vector2(p.w, p.h)
	p.shoulder = rig["shoulder"] * size
	p.hip = rig["hip"] * size
	p.rest_hand = rig["hand"] * size
	p.rest_foot = rig["foot"] * size
	p.hand_f = p.rest_hand
	p.hand_b = p.back(p.rest_hand)
	p.foot_f = p.rest_foot
	p.foot_b = p.back(p.rest_foot)
	p.pivot = Vector2(0.0, -p.h * 0.5)
	if (ticks + int(anim.get("seed", 0))) % 197 >= 190:
		p.eyes = Eyes.SHUT
	match f.mode:
		Mode.GROUND:
			_ground(p, f, ticks, anim)
		Mode.JUMP_SQUAT:
			_crouch(p, 1.0)
		Mode.AIR:
			_air(p, f, ticks, anim)
		Mode.LEDGE:
			_ledge(p, ticks)
		Mode.CLIMB:
			_climb(p, f)
		Mode.HITSTUN:
			_hitstun(p, f, ticks, anim)
		Mode.RESPAWN:
			_idle(p, ticks)
			p.hand_f = Vector2(p.w * 0.36, -p.h * 0.3)
			p.hand_b = p.back(p.hand_f)
		Mode.SHIELD:
			_shield(p, f)
		Mode.DODGE, Mode.TECH:
			_dodge(p, f)
		Mode.SHIELD_BREAK:
			_dizzy(p, ticks)
		Mode.GRAB:
			_holding(p)
		Mode.HELD:
			_held(p, ticks)
	return p


static func ease_out(k: float) -> float:
	k = clampf(k, 0.0, 1.0)
	return 1.0 - (1.0 - k) * (1.0 - k) * (1.0 - k)


static func ease_in_out(k: float) -> float:
	k = clampf(k, 0.0, 1.0)
	return k * k * (3.0 - 2.0 * k)


# Standing, walking and running. The feet swing with the distance walked, so they never slide.
static func _ground(p: Pose, f, ticks: int, anim: Dictionary) -> void:
	var s = f.stats
	_idle(p, ticks)
	p.pins |= PIN_FEET
	p.pivot = p.hip
	var forward: float = f.velocity.x * f.facing
	var speed := absf(forward)
	if f.lag > 0 and f.attack == "":
		_crouch(p, 0.6)
	elif speed > 0.5:
		var run: bool = f.running
		var amp: float = p.w * (0.4 if run else 0.26)
		var phase: float = f.position.x * f.facing / amp
		var blend := clampf(speed / s.walk_speed, 0.0, 1.0)
		var lift: float = p.h * (0.13 if run else 0.06)
		p.foot_f += Vector2(sin(phase) * amp, -maxf(cos(phase), 0.0) * lift) * blend
		p.foot_b += Vector2(-sin(phase) * amp, -maxf(-cos(phase), 0.0) * lift) * blend
		p.offset.y -= absf(cos(phase)) * p.h * (0.045 if run else 0.02) * blend
		var arm: float = amp * (0.7 if run else 0.5) * blend
		p.hand_f += Vector2(-sin(phase) * arm, -absf(sin(phase)) * arm * 0.3)
		p.hand_b += Vector2(sin(phase) * arm, -absf(sin(phase)) * arm * 0.3)
		if run:
			p.hand_f.y -= p.h * 0.08
			p.hand_b.y -= p.h * 0.08
		p.tilt = clampf(forward / s.run_speed, -1.0, 1.0) * (0.2 if run else 0.08)
	var land: int = anim.get("land", 99)
	if land < 8:  # Squashed for a moment after landing.
		var k := 1.0 - land / 8.0
		k *= k
		p.stretch *= Vector2(1.0 + 0.22 * k, 1.0 - 0.24 * k)
		p.hand_f.y += p.h * 0.1 * k
		p.hand_b.y += p.h * 0.1 * k
	var turn: int = anim.get("turn", 99)
	if turn < 5:  # A quick squeeze sells the turn.
		p.stretch.x *= lerpf(0.55, 1.0, ease_out(turn / 5.0))
	var throw: String = anim.get("throw", "")
	if throw != "" and int(anim.get("throw_t", 99)) < 14:
		_thrown(p, throw, 1.0 - ease_in_out(int(anim["throw_t"]) / 14.0))


# Breathing: a slow rise and fall of the chest and hands.
static func _idle(p: Pose, ticks: int) -> void:
	var breath := sin(ticks * TAU / 150.0)
	p.stretch = Vector2(1.0 - 0.012 * breath, 1.0 + 0.022 * breath)
	p.hand_f.y -= breath * 1.5
	p.hand_b.y -= breath * 1.5


static func _crouch(p: Pose, k: float) -> void:
	p.pins |= PIN_FEET
	p.stretch = Vector2(1.0 + 0.16 * k, 1.0 - 0.2 * k)
	p.hand_f = p.hand_f.lerp(Vector2(p.w * 0.5, -p.h * 0.2), k)
	p.hand_b = p.hand_b.lerp(Vector2(-p.w * 0.5, -p.h * 0.2), k)
	p.foot_f.x *= 1.0 + 0.3 * k
	p.foot_b.x *= 1.0 + 0.3 * k


# The follow-through of a throw, fading out with k.
static func _thrown(p: Pose, throw: String, k: float) -> void:
	var hand := Vector2.ZERO
	match throw:
		"throw_forward":
			hand = Vector2(p.w * 0.95, -p.h * 0.52)
			p.tilt += 0.22 * k
		"throw_back":
			hand = Vector2(-p.w * 0.9, -p.h * 0.62)
			p.tilt -= 0.25 * k
		"throw_up":
			hand = Vector2(p.w * 0.1, -p.h * 1.12)
			p.stretch *= Vector2(1.0 - 0.06 * k, 1.0 + 0.08 * k)
		_:
			hand = Vector2(p.w * 0.6, -p.h * 0.08)
			p.stretch *= Vector2(1.0 + 0.1 * k, 1.0 - 0.14 * k)
			p.tilt += 0.18 * k
	p.hand_f = p.hand_f.lerp(hand, k)
	p.hand_b = p.hand_b.lerp(hand + Vector2(-p.w * 0.15, p.h * 0.05), k)
	p.pins |= PIN_HANDS
	p.snap = 0.8


# In the air: one knee up and an arm reaching while rising, arms up and legs hanging while
# falling, everything pulled in for a fast fall. A double jump turns a flip (Pip flaps instead).
static func _air(p: Pose, f, ticks: int, anim: Dictionary) -> void:
	var s = f.stats
	var w := p.w
	var h := p.h
	var u := clampf(f.velocity.y / 7.0, -1.0, 1.0)  # -1 rising fast, 1 falling.
	var rise := maxf(-u, 0.0)
	var fall := maxf(u, 0.0)
	var hand_f := Vector2(w * 0.48, -h * 0.5)
	var hand_b := Vector2(-w * 0.5, -h * 0.46)
	var foot_f := Vector2(w * 0.2, -h * 0.04)
	var foot_b := Vector2(-w * 0.16, 0.0)
	hand_f = hand_f.lerp(Vector2(w * 0.36, -h * 0.8), rise).lerp(Vector2(w * 0.52, -h * 0.72), fall)
	hand_b = hand_b.lerp(Vector2(-w * 0.52, -h * 0.36), rise).lerp(Vector2(-w * 0.52, -h * 0.7),
			fall)
	foot_f = foot_f.lerp(Vector2(w * 0.3, -h * 0.17), rise).lerp(Vector2(w * 0.16, h * 0.02), fall)
	foot_b = foot_b.lerp(Vector2(-w * 0.1, h * 0.02), rise).lerp(Vector2(-w * 0.18, -h * 0.02),
			fall)
	p.stretch = Vector2(1.0 - 0.05 * rise, 1.0 + 0.1 * rise + 0.05 * fall)
	if f.fast_falling:
		hand_f = Vector2(w * 0.28, -h * 1.02)
		hand_b = Vector2(-w * 0.28, -h * 1.0)
		foot_f = Vector2(w * 0.08, h * 0.03)
		foot_b = Vector2(-w * 0.08, h * 0.03)
		p.stretch = Vector2(0.86, 1.18)
	if p.shape == "pip" and not f.fast_falling:  # Wings: flap while rising, spread to glide.
		var beat := sin(ticks * 0.7)
		var up := rise * 0.8 + 0.2
		hand_f = Vector2(w * 0.78, -h * (0.5 + 0.3 * beat * up) - h * 0.12 * fall)
		hand_b = Vector2(-w * 0.78, hand_f.y)
	p.hand_f = hand_f
	p.hand_b = hand_b
	p.foot_f = foot_f
	p.foot_b = foot_b
	p.tilt = clampf(f.velocity.x * f.facing / s.air_speed, -1.0, 1.0) * 0.1
	var flip: int = anim.get("flip", 99)
	if flip < 20:
		var k := flip / 20.0
		if p.shape == "pip":  # A big flap.
			var down := sin(k * PI)
			p.hand_f = Vector2(w * 0.7, -h * (0.85 - 0.6 * down))
			p.hand_b = Vector2(-w * 0.7, p.hand_f.y)
		elif p.shape == "brum":  # Too heavy to flip: a mighty heave of both arms.
			var lift := sin(k * PI)
			p.hand_f = p.hand_f.lerp(Vector2(w * 0.4, -h * 1.0), lift)
			p.hand_b = p.hand_b.lerp(Vector2(-w * 0.4, -h * 1.0), lift)
		else:
			var tuck := sin(k * PI)
			p.tilt += ease_in_out(k) * TAU
			p.hand_f = p.hand_f.lerp(Vector2(w * 0.3, -h * 0.45), tuck)
			p.hand_b = p.hand_b.lerp(Vector2(-w * 0.1, -h * 0.42), tuck)
			p.foot_f = p.foot_f.lerp(Vector2(w * 0.25, -h * 0.3), tuck)
			p.foot_b = p.foot_b.lerp(Vector2(-w * 0.05, -h * 0.28), tuck)
			p.snap = 1.0


# Hanging on the ledge (in front, at the top of the box): both hands on it, legs dangling.
static func _ledge(p: Pose, ticks: int) -> void:
	var top := -p.h + LEDGE_HAND_ABOVE
	var sway := sin(ticks * 0.05)
	p.hand_f = Vector2(p.w * 0.5, top - 3.0)
	p.hand_b = Vector2(p.w * 0.3, top - 5.0)
	p.pins |= PIN_HANDS
	p.pivot = Vector2(p.w * 0.4, top)
	p.tilt = 0.08 + 0.04 * sway
	p.foot_f = Vector2(p.w * 0.12, p.h * 0.02)
	p.foot_b = Vector2(-p.w * 0.06, p.h * 0.05)
	p.gaze = Vector2(0.6, -1.0)
	p.stretch = Vector2(0.96, 1.05)


# Climbing up: the hands stay on the ledge while the body goes up and over it, a knee first.
static func _climb(p: Pose, f) -> void:
	var ticks: float = 8.0 if f.climb_next != "" else float(f.stats.ledge_climb_ticks)
	var t := clampf(f.mode_ticks / ticks, 0.0, 1.0)
	# Where the ledge is, from the way the simulation moves the fighter (fighter_motion.gd).
	var ledge := Vector2(p.w * 0.5 * (1.0 - t) - (p.w * 0.5 + 4.0) * t,
			-(p.h - LEDGE_HAND_ABOVE) * (1.0 - t))
	var grip := 1.0 - ease_in_out((t - 0.5) * 2.0)
	p.hand_f = p.rest_hand.lerp(ledge + Vector2(4.0, -3.0), grip)
	p.hand_b = p.back(p.rest_hand).lerp(ledge + Vector2(-8.0, -5.0), grip)
	p.pins |= PIN_HANDS
	var knee := sin(t * PI)
	p.foot_f = p.rest_foot.lerp(Vector2(p.w * 0.35, -p.h * 0.32), knee)
	p.tilt = 0.3 * knee
	p.pivot = p.hip
	p.stretch = Vector2(1.0 + 0.08 * knee, 1.0 - 0.12 * knee)
	p.snap = 0.8


static func _hitstun(p: Pose, f, ticks: int, anim: Dictionary) -> void:
	var w := p.w
	var h := p.h
	p.eyes = Eyes.HURT
	p.beak = 1.0
	if f.hitlag > 0:  # The hit pause: flung open, helpless.
		p.hand_f = Vector2(w * 0.62, -h * 0.92)
		p.hand_b = Vector2(-w * 0.55, -h * 0.86)
		p.foot_f = Vector2(w * 0.32, h * 0.02)
		p.foot_b = Vector2(-w * 0.3, h * 0.0)
		p.stretch = Vector2(1.1, 0.93)
		p.tilt = -0.18
		p.snap = 1.0
		return
	var speed: float = f.velocity.length()
	var tumble: float = anim.get("tumble", 0.0)
	if speed > TUMBLE_SPEED or absf(tumble) > 0.05:  # Tumbling: spread out and spinning.
		var flail := sin(ticks * 0.5)
		p.tilt = tumble
		p.hand_f = Vector2(w * 0.6, -h * (0.72 + 0.08 * flail))
		p.hand_b = Vector2(-w * 0.58, -h * (0.68 - 0.08 * flail))
		p.foot_f = Vector2(w * 0.34, -h * 0.06)
		p.foot_b = Vector2(-w * 0.32, -h * 0.02)
		p.snap = 1.0
	else:  # A light hit: a flinch, leaning away with the hands up.
		p.tilt = -0.2
		p.hand_f = Vector2(w * 0.3, -h * 0.84)
		p.hand_b = Vector2(-w * 0.05, -h * 0.8)
		p.foot_f = Vector2(w * 0.26, -h * 0.02)
		p.foot_b = Vector2(-w * 0.22, 0.0)


static func _shield(p: Pose, f) -> void:
	_crouch(p, 0.45)
	p.hand_f = Vector2(p.w * 0.36, -p.h * 0.6)
	p.hand_b = Vector2(p.w * 0.16, -p.h * 0.52)
	p.eyes = Eyes.FOCUS
	if f.shield_stun > 0:
		p.tilt = -0.1
		p.pivot = Vector2.ZERO


# Dodges: a spot dodge turns sideways, a roll curls into a ball and rolls along, an air dodge
# tucks and slips the way it goes. Techs use the same poses.
static func _dodge(p: Pose, f) -> void:
	var t: int = f.mode_ticks
	var w := p.w
	var h := p.h
	p.pivot = Vector2(0.0, -h * 0.45)
	match f.dodge:
		"roll":
			var total := 17.0 if f.mode == Mode.DODGE else 24.0
			var k := ease_in_out((t - 2) / total)
			var curl := sin(clampf((t - 1) / (total + 3.0), 0.0, 1.0) * PI)
			var side := signf(f.dodge_dir.x * f.facing)
			p.tilt = k * TAU * (side if side != 0.0 else 1.0)
			tuck(p, curl)
			p.stretch = Vector2(1.0 + 0.05 * curl, 1.0 - 0.18 * curl)
			p.eyes = Eyes.SHUT if curl > 0.5 else p.eyes
			p.snap = 1.0
		"air":
			var k := sin(clampf(t / 20.0, 0.0, 1.0) * PI)
			var dir := Vector2(f.dodge_dir.x * f.facing, f.dodge_dir.y)
			p.tilt = dir.x * 0.4 * k
			tuck(p, k * 0.7)
			p.stretch = Vector2(1.0 - 0.1 * k, 1.0 + 0.06 * k)
		_:
			var k := sin(clampf(t / 18.0, 0.0, 1.0) * PI)
			p.stretch = Vector2(1.0 - 0.4 * k, 1.0 - 0.05 * k)
			p.hand_f = p.hand_f.lerp(Vector2(w * 0.2, -h * 0.5), k)
			p.hand_b = p.hand_b.lerp(Vector2(-w * 0.2, -h * 0.5), k)
			p.pins |= PIN_FEET


# Pulls the hands and feet in toward the middle of the body: a ball.
static func tuck(p: Pose, k: float) -> void:
	var w := p.w
	var h := p.h
	p.ball = maxf(p.ball, k)
	p.hand_f = p.hand_f.lerp(Vector2(w * 0.32, -h * 0.4), k)
	p.hand_b = p.hand_b.lerp(Vector2(-w * 0.18, -h * 0.44), k)
	p.foot_f = p.foot_f.lerp(Vector2(w * 0.22, -h * 0.2), k)
	p.foot_b = p.foot_b.lerp(Vector2(-w * 0.12, -h * 0.16), k)


static func _dizzy(p: Pose, ticks: int) -> void:
	p.pins |= PIN_FEET
	p.tilt = sin(ticks * 0.09) * 0.16
	p.pivot = Vector2.ZERO
	p.hand_f = Vector2(p.w * 0.34, -p.h * 0.14)
	p.hand_b = Vector2(-p.w * 0.3, -p.h * 0.16)
	p.head = Vector2(2.0, 3.0)
	p.stretch = Vector2(1.04, 0.95)
	p.eyes = Eyes.DIZZY
	p.beak = 0.5


# Holding a grabbed fighter in front with both hands.
static func _holding(p: Pose) -> void:
	p.pins |= PIN_FEET | PIN_HANDS
	p.hand_f = Vector2(p.w * 0.6, -p.h * 0.52)
	p.hand_b = Vector2(p.w * 0.5, -p.h * 0.66)
	p.tilt = -0.08
	p.pivot = p.hip
	p.eyes = Eyes.FOCUS


static func _held(p: Pose, ticks: int) -> void:
	var flail := sin(ticks * 0.55) * 4.0
	p.hand_f = Vector2(p.w * 0.42, -p.h * 0.95 + flail)
	p.hand_b = Vector2(-p.w * 0.4, -p.h * 0.92 - flail)
	p.foot_f = Vector2(p.w * 0.14, p.h * 0.02 - flail * 0.5)
	p.foot_b = Vector2(-p.w * 0.12, p.h * 0.03 + flail * 0.5)
	p.tilt = -0.12
	p.offset.y = -4.0
	p.eyes = Eyes.HURT
	p.beak = 1.0


# Moves the pose part of the way from the last one shown, so poses flow into each other.
static func blend(p: Pose, last: Pose, k: float) -> void:
	p.hand_f = last.hand_f.lerp(p.hand_f, k)
	p.hand_b = last.hand_b.lerp(p.hand_b, k)
	p.foot_f = last.foot_f.lerp(p.foot_f, k)
	p.foot_b = last.foot_b.lerp(p.foot_b, k)
	p.head = last.head.lerp(p.head, k)
	p.offset = last.offset.lerp(p.offset, k)
	p.stretch = last.stretch.lerp(p.stretch, k)
	p.tilt = lerp_angle(last.tilt, p.tilt, k)
	p.beak = lerpf(last.beak, p.beak, k)
	p.gaze = last.gaze.lerp(p.gaze, k)


# The body's own transform (stretch about the feet, tilt about the pivot), without the facing.
static func body_transform(p: Pose) -> Transform2D:
	var pivot := p.pivot * p.stretch
	return Transform2D(p.tilt, pivot) * Transform2D(0.0, -pivot) \
			* Transform2D(0.0, p.stretch, 0.0, p.stretch * p.offset)


# Places the limbs on the body as drawn: pinned ones are moved back through the body's transform,
# so they show exactly where the pose put them.
static func finalize(p: Pose) -> void:
	var inverse := body_transform(p).affine_inverse()
	p.hf = inverse * p.hand_f if p.pins & PIN_HAND_F else p.hand_f
	p.hb = inverse * p.hand_b if p.pins & PIN_HAND_B else p.hand_b
	p.ff = inverse * p.foot_f if p.pins & PIN_FOOT_F else p.foot_f
	p.fb = inverse * p.foot_b if p.pins & PIN_FOOT_B else p.foot_b

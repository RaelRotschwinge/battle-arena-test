# The poses of the attacks and specials: a wind-up in the startup, a limb that reaches the hitbox
# in the active time with a smear behind it, and the way back in the recovery. Limbs are placed
# from the attack's own hitbox, so every fighter's moves fit. Drawing only.
extends RefCounted

const FighterCombat := preload("res://scripts/sim/fighter_combat.gd")
const FighterPose := preload("res://scripts/view/fighter_pose.gd")
const Pose = FighterPose.Pose
const Eyes = FighterPose.Eyes

const SMEAR_FADE := 0.45  # Share of the recovery in which a smear fades out.


# Poses fighter f in its current attack, over the pose p of its mode.
static func apply(p: Pose, f, ticks: int) -> void:
	var a: Dictionary = FighterCombat.data(f)
	var ph := _phase(f, a)
	p.snap = 1.0 if ph.x == 1.0 else 0.75
	if ph.x == 0.0:
		p.eyes = Eyes.FOCUS
	if f.attack.begins_with("special"):
		if a.has("shot"):
			_spark(p, f, a, ph)
		elif a.has("multi"):
			_whirl(p, f, a, ph, ticks)
		elif a.has("move"):
			_swoop(p, f, a, ph, ticks)
		return
	var box: Rect2 = a["box"]
	match f.attack:
		"jab":
			_jab(p, box, ph)
		"side", "fair":
			_swing(p, box, ph, f.attack == "fair")
		"up":
			_uppercut(p, box, ph)
		"up_air":
			_up_air(p, box, ph)
		"down", "getup":
			_sweep(p, box, ph)
		"dash":
			_kick(p, box, ph, true)
		"bair":
			_kick(p, box, ph, false)
		"nair":
			_spin(p, box, ph, a)
		"ground_pound":
			_pound(p, f, ph)
		"grab":
			_grab(p, box, ph)
	if ph.x == 0.0 and ph.y >= 0.5:  # A glint on the limb about to strike.
		var limb := p.hand_f
		if f.attack in ["down", "getup", "dash"]:
			limb = p.foot_f
		elif f.attack == "bair":
			limb = p.foot_b
		if f.attack not in ["nair", "grab", "ground_pound"]:
			p.smears.append(["glint", limb, (ph.y - 0.5) * 2.0])


# x: 0 startup, 1 active, 2 recovery; y: progress in it from 0 to 1. The ground pound stays
# active until it lands; its progress then counts on past 1.
static func _phase(f, a: Dictionary) -> Vector2:
	var t: int = f.attack_ticks
	var startup: int = a["startup"]
	var active: int = a["active"]
	if t <= startup and startup > 0:
		return Vector2(0.0, float(t) / startup)
	if f.attack == "ground_pound":
		return Vector2(1.0, (t - startup) / 8.0)
	if t <= startup + active:
		return Vector2(1.0, float(t - startup) / maxf(active, 1.0))
	return Vector2(2.0, float(t - startup - active) / maxf(a["recovery"], 1.0))


# A limb from its rest to the wind-up in the startup, to the strike at once in the active time,
# and back in the recovery.
static func _track(rest: Vector2, wind: Vector2, strike: Vector2, ph: Vector2) -> Vector2:
	match int(ph.x):
		0:
			return rest.lerp(wind, FighterPose.ease_out(ph.y))
		1:
			return wind.lerp(strike, FighterPose.ease_out(ph.y * 3.0))
	return strike.lerp(rest, FighterPose.ease_in_out(ph.y))


# The same for an angle (a swing about a shoulder).
static func _turn(wind: float, strike: float, ph: Vector2) -> float:
	if ph.x == 0.0:
		return wind
	if ph.x == 1.0:
		return lerpf(wind, strike, FighterPose.ease_out(ph.y * 2.5))
	return strike


# 1 in the active time, fading to 0 early in the recovery.
static func _smear_alpha(ph: Vector2) -> float:
	if ph.x == 1.0:
		return 1.0
	if ph.x == 2.0:
		return clampf(1.0 - ph.y / SMEAR_FADE, 0.0, 1.0)
	return 0.0


# A value that leans one way in the startup, the other in the active time, and settles back.
static func _lean(wind: float, strike: float, ph: Vector2) -> float:
	match int(ph.x):
		0:
			return wind * FighterPose.ease_out(ph.y)
		1:
			return lerpf(wind, strike, FighterPose.ease_out(ph.y * 3.0))
	return strike * (1.0 - FighterPose.ease_in_out(ph.y))


static func _jab(p: Pose, box: Rect2, ph: Vector2) -> void:
	var y := box.get_center().y
	var wind := Vector2(p.shoulder.x * 0.3, y + 6.0)
	var strike := Vector2(box.end.x - 10.0, y)
	p.hand_f = _track(p.hand_f, wind, strike, ph)
	p.hand_b = _track(p.hand_b, Vector2(-p.w * 0.05, -p.h * 0.55), Vector2(-p.w * 0.3, -p.h * 0.5),
			ph)
	p.pins |= FighterPose.PIN_HANDS
	p.tilt = _lean(-0.06, 0.14, ph)
	p.offset.x = _lean(-2.0, 5.0, ph)
	p.beak = 0.6 if ph.x == 1.0 else 0.0
	_thrust(p, wind, p.hand_f, 12.0, ph)


# The side attack swings over the top from behind; the forward air chops down from above.
static func _swing(p: Pose, box: Rect2, ph: Vector2, chop: bool) -> void:
	var c := box.get_center()
	var target := Vector2(box.end.x - 14.0, c.y + (box.size.y * 0.2 if chop else 0.0))
	var pivot := p.shoulder
	var radius := pivot.distance_to(target)
	var strike := (target - pivot).angle()
	var wind := strike - (2.7 if chop else 2.3)
	var turn := _turn(wind, strike + 0.2, ph)
	var hand := pivot + Vector2.from_angle(turn) * radius
	if ph.x == 0.0:
		hand = p.hand_f.lerp(pivot + Vector2.from_angle(wind) * radius * 0.75,
				FighterPose.ease_out(ph.y))
	elif ph.x == 2.0:
		hand = hand.lerp(p.rest_hand, FighterPose.ease_in_out(ph.y))
	p.hand_f = hand
	p.hand_b = _track(p.hand_b, Vector2(-p.w * 0.45, -p.h * 0.4),
			hand + Vector2(-p.w * 0.25, p.h * 0.06) if chop else Vector2(-p.w * 0.5, -p.h * 0.42), ph)
	p.pins |= FighterPose.PIN_HANDS
	p.tilt = _lean(-0.16, 0.22, ph)
	p.offset.x = _lean(-3.0, 6.0, ph)
	_arc(p, pivot, radius, wind + 0.5, turn, 16.0, ph)


static func _uppercut(p: Pose, box: Rect2, ph: Vector2) -> void:
	var pivot := p.shoulder
	var target := Vector2(clampf(box.get_center().x, 0.0, p.w * 0.4), box.position.y + 22.0)
	var radius := pivot.distance_to(target)
	var strike := (target - pivot).angle()
	var wind := strike + 2.2
	var turn := _turn(wind, strike - 0.1, ph)
	var hand := pivot + Vector2.from_angle(turn) * radius
	if ph.x == 0.0:
		hand = p.hand_f.lerp(Vector2(p.w * 0.35, -p.h * 0.22), FighterPose.ease_out(ph.y))
	elif ph.x == 2.0:
		hand = hand.lerp(p.rest_hand, FighterPose.ease_in_out(ph.y))
	p.hand_f = hand
	p.hand_b = _track(p.hand_b, Vector2(-p.w * 0.4, -p.h * 0.3), Vector2(-p.w * 0.45, -p.h * 0.25),
			ph)
	p.pins |= FighterPose.PIN_HANDS
	var up := _lean(-1.0, 1.0, ph)
	p.stretch *= Vector2(1.0 - 0.06 * up, 1.0 + 0.1 * up)
	p.offset.y = -6.0 * maxf(up, 0.0)
	p.tilt = _lean(0.12, -0.05, ph)
	p.gaze = Vector2(0.5, -1.0)
	_arc(p, pivot, radius, wind - 0.3, turn, 15.0, ph)


static func _up_air(p: Pose, box: Rect2, ph: Vector2) -> void:
	var pivot := p.shoulder
	var target := Vector2(p.w * 0.05, box.position.y + 20.0)
	var radius := pivot.distance_to(target)
	var strike := (target - pivot).angle()
	var wind := strike + 1.5
	var turn := _turn(wind, strike - 0.7, ph)
	var hand := pivot + Vector2.from_angle(turn) * radius
	if ph.x == 0.0:
		hand = p.hand_f.lerp(pivot + Vector2.from_angle(wind) * radius * 0.6,
				FighterPose.ease_out(ph.y))
	elif ph.x == 2.0:
		hand = hand.lerp(p.hand_f, FighterPose.ease_in_out(ph.y))
	p.hand_f = hand
	p.hand_b = _track(p.hand_b, Vector2(-p.w * 0.5, -p.h * 0.5), Vector2(-p.w * 0.3, -p.h * 0.95),
			ph)
	p.pins |= FighterPose.PIN_HANDS
	var up := _lean(-0.5, 1.0, ph)
	p.stretch *= Vector2(1.0 - 0.06 * up, 1.0 + 0.1 * up)
	p.foot_f = p.foot_f.lerp(Vector2(p.w * 0.1, p.h * 0.04), maxf(up, 0.0))
	p.foot_b = p.foot_b.lerp(Vector2(-p.w * 0.1, p.h * 0.04), maxf(up, 0.0))
	p.gaze = Vector2(0.3, -1.0)
	_arc(p, pivot, radius, wind - 0.2, turn, 15.0, ph)


# The low kick and the getup attack sweep both sides at once: a crouch with both legs out.
static func _sweep(p: Pose, box: Rect2, ph: Vector2) -> void:
	var y := minf(box.get_center().y, -10.0)
	var low := _lean(0.6, 1.0, ph)
	p.stretch = Vector2(1.0 + 0.14 * low, 1.0 - 0.22 * low)
	p.pins |= FighterPose.PIN_FEET
	var front := Vector2(box.end.x - 14.0, y)
	var behind := Vector2(box.position.x + 14.0, y)
	p.foot_f = _track(p.foot_f, Vector2(p.w * 0.3, -p.h * 0.1), front, ph)
	p.foot_b = _track(p.foot_b, Vector2(-p.w * 0.3, -p.h * 0.06), behind, ph)
	p.hand_f = Vector2(p.w * 0.55, -p.h * 0.5)
	p.hand_b = Vector2(-p.w * 0.55, -p.h * 0.48)
	p.offset.y = p.h * 0.06 * low
	var root := Vector2(0.0, y)
	_thrust(p, root.lerp(front, 0.3), p.foot_f, 12.0, ph)
	_thrust(p, root.lerp(behind, 0.3), p.foot_b, 12.0, ph)


# The dash attack kicks forward at full stretch; the back air kicks back over the shoulder.
static func _kick(p: Pose, box: Rect2, ph: Vector2, forward: bool) -> void:
	var y := box.get_center().y
	if forward:
		var strike := Vector2(box.end.x - 10.0, y)
		var wind := Vector2(p.w * 0.12, -p.h * 0.3)
		p.foot_f = _track(p.foot_f, wind, strike, ph)
		p.foot_b = _track(p.foot_b, Vector2(-p.w * 0.2, -p.h * 0.05), Vector2(-p.w * 0.3,
				-p.h * 0.18), ph)
		p.hand_f = Vector2(-p.w * 0.1, -p.h * 0.7)
		p.hand_b = Vector2(-p.w * 0.6, -p.h * 0.5)
		p.pins |= FighterPose.PIN_FOOT_F
		p.tilt = _lean(0.05, -0.28, ph)
		p.offset.y = -p.h * 0.06 * maxf(_lean(0.0, 1.0, ph), 0.0)
		_thrust(p, wind, p.foot_f, 14.0, ph)
	else:
		var strike := Vector2(box.position.x + 10.0, y)
		var wind := Vector2(-p.w * 0.05, -p.h * 0.28)
		p.foot_b = _track(p.foot_b, wind, strike, ph)
		p.foot_f = _track(p.foot_f, Vector2(p.w * 0.2, -p.h * 0.2), Vector2(p.w * 0.25,
				-p.h * 0.1), ph)
		p.hand_f = Vector2(p.w * 0.5, -p.h * 0.6)
		p.hand_b = Vector2(p.w * 0.1, -p.h * 0.75)
		p.pins |= FighterPose.PIN_FOOT_B
		p.tilt = _lean(-0.05, 0.35, ph)
		p.gaze = Vector2(-1.0, 0.0)
		_thrust(p, wind, p.foot_b, 14.0, ph)


# The neutral air: a spin with all limbs out. Brum, too heavy to spin, splashes out wide.
static func _spin(p: Pose, box: Rect2, ph: Vector2, a: Dictionary) -> void:
	var turns := 2.0 if a.has("multi") else 1.0  # Whole turns: it ends upright.
	var out := _lean(-0.4, 1.0, ph)
	var spread := maxf(out, 0.0)
	var k := ph.y if ph.x == 1.0 else (1.0 if ph.x == 2.0 else 0.0)
	if p.shape == "brum":
		p.stretch = Vector2(1.0 + 0.1 * spread, 1.0 - 0.06 * spread)
		turns = 0.0
	p.tilt = -k * TAU * turns  # Even speed: a spin that eases would jump a half turn a tick.
	FighterPose.tuck(p, maxf(-out, 0.0) * 2.0)
	if spread > 0.0:
		var w := p.w
		var h := p.h
		p.hand_f = p.hand_f.lerp(Vector2(w * 0.7, -h * 0.66), spread)
		p.hand_b = p.hand_b.lerp(Vector2(-w * 0.7, -h * 0.62), spread)
		p.foot_f = p.foot_f.lerp(Vector2(w * 0.5, -h * 0.02), spread)
		p.foot_b = p.foot_b.lerp(Vector2(-w * 0.48, h * 0.0), spread)
	var alpha := _smear_alpha(ph)
	if alpha > 0.0:
		var radius := minf(box.size.x, box.size.y) * 0.46
		var head := -PI / 2.0 + p.tilt
		p.smears.append(["ring", box.get_center(), radius, head, 3.4, 14.0, alpha])


static func _pound(p: Pose, f, ph: Vector2) -> void:
	var w := p.w
	var h := p.h
	if ph.x == 0.0:  # A short hover, curled up, arms raised.
		var k := FighterPose.ease_out(ph.y)
		FighterPose.tuck(p, k * 0.8)
		p.hand_f = p.hand_f.lerp(Vector2(w * 0.3, -h * 0.98), k)
		p.hand_b = p.hand_b.lerp(Vector2(-w * 0.3, -h * 0.96), k)
		p.stretch = Vector2(1.0 + 0.08 * k, 1.0 - 0.1 * k)
		p.tilt = 0.0
		return
	p.hand_f = Vector2(w * 0.18, -h * 1.08)
	p.hand_b = Vector2(-w * 0.18, -h * 1.06)
	p.foot_f = Vector2(w * 0.06, h * 0.04)
	p.foot_b = Vector2(-w * 0.06, h * 0.04)
	p.stretch = Vector2(0.84, 1.2)
	p.tilt = 0.0
	p.eyes = Eyes.FOCUS
	if f.velocity.y > 2.0:
		p.smears.append(["dive", Vector2(0.0, -h), w * 0.42, minf(ph.y, 1.0)])


static func _grab(p: Pose, box: Rect2, ph: Vector2) -> void:
	var c := box.get_center()
	var reach := Vector2(box.end.x - 8.0, c.y)
	p.hand_f = _track(p.hand_f, Vector2(p.w * 0.1, c.y + 8.0), reach + Vector2(0.0, 8.0), ph)
	p.hand_b = _track(p.hand_b, Vector2(-p.w * 0.05, c.y - 4.0), reach + Vector2(-6.0, -10.0), ph)
	p.pins |= FighterPose.PIN_HANDS
	p.tilt = _lean(-0.08, 0.2, ph)


# Kade's Spark: the hand holds out the orb as it grows, then kicks back as it flies.
static func _spark(p: Pose, f, a: Dictionary, ph: Vector2) -> void:
	var shot: Dictionary = a["shot"]
	var at: Vector2 = shot["offset"]
	var t: int = f.attack_ticks
	p.eyes = Eyes.FOCUS
	p.pins |= FighterPose.PIN_HANDS
	if t < shot["at"]:
		var k := FighterPose.ease_out(t / 4.0)
		p.hand_f = p.hand_f.lerp(at + Vector2(-6.0, 4.0), k)
		p.hand_b = p.hand_b.lerp(Vector2(p.w * 0.12, -p.h * 0.5), k)
		p.tilt = -0.06 * k
		p.smears.append(["orb", at, shot["size"].x / 2.0 * float(t) / a["startup"], t])
	else:
		var back := 1.0 - FighterPose.ease_in_out(float(t - shot["at"]) / 14.0)
		p.hand_f = p.rest_hand.lerp(at + Vector2(-14.0, 6.0), back)
		p.hand_b = p.back(p.rest_hand).lerp(Vector2(-p.w * 0.4, -p.h * 0.5), back)
		p.tilt = -0.14 * back
		if t - shot["at"] < 8:
			p.smears.append(["burst", at, shot["size"].x / 2.0, t - shot["at"]])


# Pip's Swoop: wings flare in the still moment, then the body streaks head first the way aimed.
static func _swoop(p: Pose, f, a: Dictionary, ph: Vector2, ticks: int) -> void:
	var w := p.w
	var h := p.h
	var aim := Vector2(f.special_aim.x * f.facing, f.special_aim.y)
	var lie := aim.angle() + PI / 2.0
	p.pivot = Vector2(0.0, -h * 0.5)
	match int(ph.x):
		0:
			var k := FighterPose.ease_out(ph.y)
			p.hand_f = p.hand_f.lerp(Vector2(w * 0.75, -h * 1.0), k)
			p.hand_b = p.hand_b.lerp(Vector2(-w * 0.75, -h * 0.98), k)
			p.foot_f = p.foot_f.lerp(Vector2(w * 0.12, -h * 0.1), k)
			p.foot_b = p.foot_b.lerp(Vector2(-w * 0.12, -h * 0.1), k)
			p.stretch = Vector2(1.0 + 0.1 * k, 1.0 - 0.12 * k)
			p.tilt = lie * 0.15 * k
			p.eyes = Eyes.FOCUS
			p.smears.append(["flare", Vector2(0.0, -h * 0.55), w * 0.5, ph.y])
		1:
			p.tilt = lie * 0.9
			p.stretch = Vector2(0.78, 1.28)
			p.hand_f = Vector2(w * 0.34, -h * 0.06)
			p.hand_b = Vector2(-w * 0.34, -h * 0.06)
			p.foot_f = Vector2(w * 0.05, h * 0.03)
			p.foot_b = Vector2(-w * 0.05, h * 0.03)
			p.eyes = Eyes.FOCUS
			p.beak = 0.3
			p.snap = 1.0
			p.smears.append(["streak", Vector2(0.0, -h * 0.5), aim, w])
		_:
			var k := 1.0 - FighterPose.ease_out(ph.y / 0.5)
			p.tilt = lie * 0.9 * k
			p.stretch = Vector2(1.0 - 0.22 * k, 1.0 + 0.28 * k)
			var beat := sin(ticks * 0.8)
			p.hand_f = Vector2(w * 0.75, -h * (0.55 + 0.25 * beat))
			p.hand_b = Vector2(-w * 0.75, p.hand_f.y)


# Brum's Whirl: a twist back in the startup, then a spin with both fists out (seen from the side,
# the fists swing round in front and behind), then a dizzy wobble.
static func _whirl(p: Pose, f, a: Dictionary, ph: Vector2, ticks: int) -> void:
	var w := p.w
	var h := p.h
	var box: Rect2 = a["box"]
	match int(ph.x):
		0:
			var k := FighterPose.ease_out(ph.y)
			p.hand_f = p.hand_f.lerp(Vector2(-w * 0.3, -h * 0.5), k)
			p.hand_b = p.hand_b.lerp(Vector2(-w * 0.7, -h * 0.46), k)
			p.tilt = -0.1 * k
			p.stretch = Vector2(1.0 - 0.05 * k, 1.0 + 0.03 * k)
			p.eyes = Eyes.FOCUS
		1:
			var spin: float = (f.attack_ticks - a["startup"]) * 0.75
			var reach := box.size.x * 0.5 - 14.0
			var x := cos(spin) * reach
			var y := -h * 0.5
			var front := sin(spin) >= 0.0
			p.hand_f = Vector2(x if front else -x, y + sin(spin) * 4.0)
			p.hand_b = Vector2(-x if front else x, y - sin(spin) * 4.0)
			p.flip = cos(spin) < 0.0
			if p.flip:  # Mirrored: the hands are drawn mirrored too.
				p.hand_f.x = -p.hand_f.x
				p.hand_b.x = -p.hand_b.x
			p.stretch = Vector2(0.8 + 0.2 * absf(cos(spin)), 1.0)
			p.pins |= FighterPose.PIN_FEET
			p.snap = 1.0
			p.eyes = Eyes.FOCUS
			p.smears.append(["whirl", Vector2(0.0, y), reach + 10.0, spin, h])
		_:
			var k := 1.0 - ph.y
			p.tilt = sin(ticks * 0.3) * 0.18 * k
			p.pivot = Vector2.ZERO
			p.hand_f = p.hand_f.lerp(Vector2(w * 0.7, -h * 0.4), k)
			p.hand_b = p.hand_b.lerp(Vector2(-w * 0.7, -h * 0.4), k)
			if ph.y < 0.5:
				p.eyes = Eyes.DIZZY


# Speed lines behind a punch or kick, from where it started to where the limb is now.
static func _thrust(p: Pose, from: Vector2, to: Vector2, width: float, ph: Vector2) -> void:
	var alpha := _smear_alpha(ph)
	if alpha > 0.0 and from.distance_to(to) > 8.0:
		p.smears.append(["thrust", from, to, width, alpha])


# A curved smear along a swing about pivot, from angle start to the limb's angle now.
static func _arc(p: Pose, pivot: Vector2, radius: float, start: float, now: float, width: float,
		ph: Vector2) -> void:
	var alpha := _smear_alpha(ph)
	if alpha <= 0.0 or absf(now - start) < 0.2:
		return
	p.smears.append(["arc", pivot, radius, start, now, width, alpha])

# The fighters' shapes in clean flat vector art (game design, "Art style"): every part outlined,
# filled in its base tone with a darker rim along the bottom and a light sheen at the top, drawn
# around the limbs of the pose. Kade: an all-rounder with a scarf; Pip: a small round bird; Brum:
# a square stone brute with gold fists. In the fighter's own space (feet at the origin, facing
# right). Drawing only.
extends RefCounted

const FighterPose := preload("res://scripts/view/fighter_pose.gd")
const Pose = FighterPose.Pose
const Eyes = FighterPose.Eyes

const LINE := 4.0  # Outline width; half of it lies outside the shape.
const INK := Color("11131a")
const SCARF := Color("d8483c")  # Kade's scarf, a character color of its own.
const BLUSH := Color("ff8a8a")
const ROUND := 30  # Points of a round shape.


# The colors of one fighter as drawn this tick, tint and flash already applied.
class Paint:
	var body := Color.WHITE  # The look's three colors.
	var second := Color.WHITE
	var third := Color.WHITE
	var scarf := SCARF
	var line := INK
	var white := Color.WHITE
	var ink := INK


static func dark(c: Color) -> Color:
	return Color(c.r * 0.66, c.g * 0.64, c.b * 0.74, c.a)


static func light(c: Color) -> Color:
	return c.lerp(Color(1.0, 0.98, 0.93, c.a), 0.38)


static func ellipse(at: Vector2, radius: Vector2, turn: float = 0.0,
		count: int = ROUND) -> PackedVector2Array:
	var points := PackedVector2Array()
	points.resize(count)
	for n in count:
		var a := TAU * n / count
		points[n] = at + Vector2(cos(a) * radius.x, sin(a) * radius.y).rotated(turn)
	return points


# A box with rounded corners; top and bottom may differ in width (a trapezoid).
static func rounded(top: float, bottom: float, top_half: float, bottom_half: float,
		radius: float, x: float = 0.0) -> PackedVector2Array:
	var corners := [Vector2(x + top_half, top), Vector2(x + bottom_half, bottom),
			Vector2(x - bottom_half, bottom), Vector2(x - top_half, top)]
	var points := PackedVector2Array()
	for n in 4:
		var c: Vector2 = corners[n]
		var before: Vector2 = corners[(n + 3) % 4]
		var after: Vector2 = corners[(n + 1) % 4]
		var a: Vector2 = c + (before - c).normalized() * radius
		var b: Vector2 = c + (after - c).normalized() * radius
		for i in 5:
			var t := i / 4.0
			points.append(a.lerp(c, t).lerp(c.lerp(b, t), t))
	return points


# Fills a shape in two tones: the dark one fills it, the base one a copy shrunk toward its top,
# so the dark shows as a rim along the bottom.
static func fill(canvas: CanvasItem, points: PackedVector2Array, color: Color, top: Vector2,
		shrink: float = 0.86) -> void:
	canvas.draw_colored_polygon(points, dark(color))
	var inner := PackedVector2Array()
	inner.resize(points.size())
	for n in points.size():
		inner[n] = top + (points[n] - top) * shrink
	canvas.draw_colored_polygon(inner, color)


static func outline(canvas: CanvasItem, points: PackedVector2Array, line: Color,
		width: float = LINE) -> void:
	var ring := points.duplicate()
	ring.append(points[0])
	canvas.draw_polyline(ring, line, width, true)


static func blob(canvas: CanvasItem, points: PackedVector2Array, color: Color, top: Vector2,
		paint: Paint, shrink: float = 0.86) -> void:
	fill(canvas, points, color, top, shrink)
	outline(canvas, points, paint.line)


static func sheen(canvas: CanvasItem, at: Vector2, radius: Vector2, turn: float,
		color: Color) -> void:
	canvas.draw_colored_polygon(ellipse(at, radius, turn, 14), Color(light(color), color.a * 0.9))


# A round part with its sheen.
static func ball(canvas: CanvasItem, at: Vector2, radius: float, color: Color,
		paint: Paint) -> void:
	blob(canvas, ellipse(at, Vector2(radius, radius)), color, at + Vector2(-radius * 0.2,
			-radius), paint, 0.84)
	sheen(canvas, at + Vector2(-radius * 0.35, -radius * 0.42), Vector2(radius * 0.3,
			radius * 0.18), -0.6, color)


# A limb from a to b as a soft curve that bends toward bend when a and b are closer than its
# length (rubber hose), outlined, with round ends.
static func limb(canvas: CanvasItem, a: Vector2, b: Vector2, length: float, width: float,
		color: Color, bend: Vector2, paint: Paint) -> void:
	var gap := a.distance_to(b)
	var side := (b - a).orthogonal().normalized()
	if side.dot(bend) < 0.0:
		side = -side
	var ctrl := (a + b) / 2.0 + side * sqrt(maxf(length * length - gap * gap, 0.0)) * 0.7
	var points := PackedVector2Array()
	points.resize(7)
	for n in 7:
		var t := n / 6.0
		points[n] = a.lerp(ctrl, t).lerp(ctrl.lerp(b, t), t)
	var outer := width + LINE
	canvas.draw_polyline(points, paint.line, outer, true)
	canvas.draw_circle(a, outer / 2.0, paint.line, true, -1.0, true)
	canvas.draw_circle(b, outer / 2.0, paint.line, true, -1.0, true)
	canvas.draw_polyline(points, color, width, true)
	canvas.draw_circle(a, width / 2.0, color, true, -1.0, true)
	canvas.draw_circle(b, width / 2.0, color, true, -1.0, true)


static func eye(canvas: CanvasItem, at: Vector2, size: float, p: Pose, paint: Paint,
		inner: bool = false) -> void:
	var ink := paint.ink
	match p.eyes:
		Eyes.SHUT:
			canvas.draw_polyline(PackedVector2Array([at + Vector2(-size, -size * 0.1),
					at + Vector2(0.0, size * 0.4), at + Vector2(size, -size * 0.1)]), ink, 2.5,
					true)
		Eyes.HURT:  # Squeezed shut: > <
			var s := -1.0 if inner else 1.0
			canvas.draw_polyline(PackedVector2Array([at + Vector2(-size * s, -size * 0.8),
					at + Vector2(size * 0.7 * s, 0.0), at + Vector2(-size * s, size * 0.8)]), ink,
					2.5, true)
		Eyes.DIZZY:  # A spiral.
			var points := PackedVector2Array()
			for n in 14:
				var a := n * 0.9
				points.append(at + Vector2(cos(a), sin(a)) * size * (0.15 + n * 0.065))
			canvas.draw_polyline(points, ink, 2.0, true)
		_:
			canvas.draw_colored_polygon(ellipse(at, Vector2(size * 0.82, size), 0.0, 16),
					paint.white)
			var pupil := at + p.gaze.normalized() * size * 0.32
			canvas.draw_circle(pupil, size * 0.52, ink, true, -1.0, true)
			canvas.draw_circle(pupil + Vector2(-size * 0.18, -size * 0.22), size * 0.18,
					paint.white, true, -1.0, true)
			if p.eyes == Eyes.FOCUS:  # A lid pressed down: determined.
				canvas.draw_colored_polygon(PackedVector2Array([at + Vector2(-size * 1.1,
						-size * 1.15), at + Vector2(size * 1.1, -size * 1.15),
						at + Vector2(size * 1.0, -size * 0.2), at + Vector2(-size * 1.0,
						-size * 0.55)]), paint.line)


# Kade: green tunic, brown hair and boots, a red scarf that streams behind.
static func kade(canvas: CanvasItem, p: Pose, paint: Paint, f, ticks: int) -> void:
	var w := p.w
	var h := p.h
	var tunic := paint.body
	var skin := paint.second
	var brown := paint.third
	var arm := h * 0.34
	var leg := h * 0.3
	_scarf_tail(canvas, p, Vector2(-w * 0.26, -h * 0.655), f, ticks, paint)
	limb(canvas, p.back(p.shoulder), p.hb, arm, 9.0, dark(tunic), Vector2(-0.4, 1.0), paint)
	ball(canvas, p.hb, 6.0, dark(skin), paint)
	_boot_leg(canvas, p.back(p.hip), p.fb, leg, 11.0, dark(brown), paint)
	_boot_leg(canvas, p.hip, p.ff, leg, 11.0, brown, paint)
	var torso := rounded(-h * 0.7, -h * 0.22, w * 0.3, w * 0.27, 8.0)
	blob(canvas, torso, tunic, Vector2(-w * 0.08, -h * 0.72), paint, 0.84)
	sheen(canvas, Vector2(-w * 0.12, -h * 0.62), Vector2(w * 0.08, h * 0.04), -0.3, tunic)
	var belt := rounded(-h * 0.35, -h * 0.29, w * 0.285, w * 0.28, 2.0)
	canvas.draw_colored_polygon(belt, dark(brown))
	canvas.draw_colored_polygon(rounded(-h * 0.355, -h * 0.275, w * 0.07, w * 0.07, 2.0,
			w * 0.1), light(paint.third.lerp(Color("e0b84a"), 0.7)))
	var head := Vector2(w * 0.04, -h * 0.82) + p.head
	var r := w * 0.3
	blob(canvas, ellipse(head, Vector2(r, r * 1.02)), skin, head + Vector2(-r * 0.3, -r), paint,
			0.86)
	_hair(canvas, head, r, brown, paint)
	eye(canvas, head + Vector2(r * 0.28, r * 0.08), 4.4, p, paint, true)
	eye(canvas, head + Vector2(r * 0.72, r * 0.08), 4.0, p, paint)
	if p.eyes == Eyes.HURT:
		canvas.draw_circle(head + Vector2(r * 0.55, r * 0.55), 3.0, paint.ink, true, -1.0, true)
	var wrap := ellipse(Vector2(0.0, -h * 0.665), Vector2(w * 0.34, h * 0.06))
	blob(canvas, wrap, paint.scarf, Vector2(0.0, -h * 0.72), paint, 0.8)
	ball(canvas, Vector2(-w * 0.27, -h * 0.655), 5.0, paint.scarf, paint)
	limb(canvas, p.shoulder, p.hf, arm, 9.0, tunic, Vector2(-0.4, 1.0), paint)
	ball(canvas, p.hf, 6.5, skin, paint)


static func _boot_leg(canvas: CanvasItem, hip: Vector2, foot: Vector2, length: float,
		width: float, color: Color, paint: Paint) -> void:
	limb(canvas, hip, foot, length, width, color, Vector2(1.0, -0.2), paint)
	var boot := rounded(foot.y - 7.0, foot.y + 1.0, 7.0, 9.0, 3.5, foot.x + 3.0)
	blob(canvas, boot, dark(color), Vector2(foot.x, foot.y - 8.0), paint, 0.8)


# A spiky fringe of hair over the top and back of the head.
static func _hair(canvas: CanvasItem, head: Vector2, r: float, color: Color,
		paint: Paint) -> void:
	var points := PackedVector2Array()
	for n in 11:  # Over the top, from behind the ear to the forehead.
		var a := lerpf(PI * 0.82, PI * 1.93, n / 10.0)
		points.append(head + Vector2(cos(a), sin(a)) * r * 1.1)
	points.append(head + Vector2(r * 0.9, -r * 0.1))  # The fringe, from the front back.
	points.append(head + Vector2(r * 0.55, -r * 0.45))
	points.append(head + Vector2(r * 0.4, -r * 0.18))
	points.append(head + Vector2(r * 0.1, -r * 0.5))
	points.append(head + Vector2(-r * 0.15, -r * 0.2))
	points.append(head + Vector2(-r * 0.55, -r * 0.3))
	points.append(head + Vector2(-r * 0.6, r * 0.25))
	points.append(head + Vector2(-r * 0.95, r * 0.45))
	canvas.draw_colored_polygon(points, color)
	outline(canvas, points, paint.line)
	sheen(canvas, head + Vector2(-r * 0.2, -r * 0.82), Vector2(r * 0.32, r * 0.1), -0.15, color)


# The ends of the scarf stream behind against the way the fighter moves, waving.
static func _scarf_tail(canvas: CanvasItem, p: Pose, knot: Vector2, f, ticks: int,
		paint: Paint) -> void:
	var v := Vector2(f.velocity.x * f.facing, f.velocity.y)
	var dir := Vector2(-1.0, 0.45)
	if v.length() > 1.0:
		dir = dir.lerp(-v.normalized(), clampf(v.length() / 10.0, 0.0, 0.85))
	dir = dir.normalized().rotated(-p.tilt)
	var length := p.w * (0.55 + clampf(v.length() / 14.0, 0.0, 0.5))
	for end in 2:
		var left := PackedVector2Array()
		var right := PackedVector2Array()
		var side := dir.orthogonal()
		for n in 7:
			var t := n / 6.0
			var wave := sin(ticks * 0.32 - t * 4.0 + end * 1.3) * p.w * 0.1 * t
			var at := knot + dir.rotated(end * 0.35 - 0.15) * length * t * (1.0 - end * 0.2) \
					+ side * wave
			var half := lerpf(4.5, 2.5, t)
			left.append(at + side * half)
			right.append(at - side * half)
		right.reverse()
		var points := left + right
		canvas.draw_colored_polygon(points, dark(paint.scarf) if end == 1 else paint.scarf)
		outline(canvas, points, paint.line, 3.0)


# Pip: a round blue bird with a cream belly, an orange beak and feet, feathered wings and tail.
static func pip(canvas: CanvasItem, p: Pose, paint: Paint, f, ticks: int) -> void:
	var w := p.w
	var h := p.h
	var body := paint.body
	var beak := paint.third
	var wag := sin(ticks * 0.15) * 0.08 - clampf(f.velocity.y * 0.02, -0.3, 0.3)
	for n in 3:  # The tail.
		var a := PI + 0.45 + n * 0.28 + wag
		feather(canvas, Vector2(-w * 0.34, -h * 0.28), a, w * (0.46 - n * 0.05), w * 0.13,
				dark(body), paint)
	_wing(canvas, p.back(p.shoulder), p.hb, w * 0.36, dark(body), paint)
	for side in [p.fb, p.ff]:
		var foot: Vector2 = side
		var hip := Vector2(signf(foot.x - 0.01) * w * 0.12, -h * 0.18)
		limb(canvas, hip, foot, h * 0.16, 4.0, beak, Vector2(1.0, 0.0), paint)
		blob(canvas, ellipse(foot + Vector2(3.0, -1.5), Vector2(6.5, 3.0)), beak,
				foot + Vector2(3.0, -4.5), paint, 0.8)
	for n in 3:  # The crest.
		feather(canvas, Vector2(-w * 0.02, -h * 0.93), -1.75 - n * 0.35, w * (0.3 - n * 0.05),
				w * 0.09, dark(body), paint)
	var center := Vector2(0.0, -h * 0.55)
	var egg := PackedVector2Array()
	for n in ROUND:
		var a := TAU * n / ROUND
		egg.append(center + Vector2(cos(a) * w * 0.5 * (1.0 + 0.08 * sin(a)), sin(a) * h * 0.43))
	fill(canvas, egg, body, Vector2(-w * 0.1, -h * 0.98), 0.86)
	var belly := ellipse(Vector2(w * 0.12, -h * 0.38), Vector2(w * 0.32, h * 0.25))
	fill(canvas, belly, paint.second, Vector2(w * 0.12, -h * 0.63), 0.88)
	outline(canvas, egg, paint.line)
	sheen(canvas, Vector2(-w * 0.18, -h * 0.85), Vector2(w * 0.14, h * 0.05), -0.5, body)
	canvas.draw_colored_polygon(ellipse(Vector2(w * 0.36, -h * 0.6), Vector2(w * 0.08, h * 0.03),
			0.0, 12), Color(BLUSH, 0.55 * body.a))
	eye(canvas, Vector2(w * 0.12, -h * 0.74), 5.6, p, paint, true)
	eye(canvas, Vector2(w * 0.34, -h * 0.74), 5.0, p, paint)
	var open := p.beak * h * 0.06
	var lower := PackedVector2Array([Vector2(w * 0.38, -h * 0.63), Vector2(w * 0.7,
			-h * 0.6 + open), Vector2(w * 0.4, -h * 0.56)])
	blob(canvas, lower, dark(beak), Vector2(w * 0.4, -h * 0.64), paint, 0.9)
	var upper := PackedVector2Array([Vector2(w * 0.36, -h * 0.7), Vector2(w * 0.62, -h * 0.68),
			Vector2(w * 0.8, -h * 0.625), Vector2(w * 0.38, -h * 0.6)])
	blob(canvas, upper, beak, Vector2(w * 0.4, -h * 0.71), paint, 0.82)
	_wing(canvas, p.shoulder, p.hf, w * 0.36, body, paint)


# A wing from root to tip: a leaf, round along the leading edge, with two feather notches in
# the trailing edge.
static func _wing(canvas: CanvasItem, root: Vector2, tip: Vector2, width: float, color: Color,
		paint: Paint) -> void:
	var along := tip - root
	var length := maxf(along.length(), 1.0)
	var u := along / length
	var n := u.orthogonal()
	if n.y > 0.0 or (n.y == 0.0 and n.x < 0.0):
		n = -n
	var points := PackedVector2Array()
	for i in 9:  # The leading edge out to the tip.
		var t := i / 8.0
		points.append(root + u * length * t + n * width * 0.55 * sin(PI * pow(t, 0.7)))
	for i in range(7, 0, -1):  # The trailing edge back.
		var t := i / 8.0
		points.append(root + u * length * t - n * width * 0.42 * sin(PI * pow(t, 0.8)))
	points.append(root - u * width * 0.3)
	blob(canvas, points, color, root + n * width * 0.6, paint, 0.8)
	for t in [0.5, 0.72]:
		var edge: Vector2 = root + u * length * t - n * width * 0.42 * sin(PI * pow(t, 0.8))
		canvas.draw_line(edge, edge.lerp(root + u * length * (t - 0.2), 0.45), paint.line, 2.0,
				true)


static func feather(canvas: CanvasItem, root: Vector2, angle: float, length: float,
		width: float, color: Color, paint: Paint) -> void:
	var u := Vector2.from_angle(angle)
	var n := u.orthogonal()
	var points := PackedVector2Array([root + n * width * 0.4, root + u * length * 0.55 + n * width,
			root + u * length, root + u * length * 0.55 - n * width, root - n * width * 0.4])
	canvas.draw_colored_polygon(points, color)
	outline(canvas, points, paint.line, 3.0)


# Brum: a clay-red rock body with stone shoulders, a square stone head under a gold band, short
# stone legs and two big gold fists.
static func brum(canvas: CanvasItem, p: Pose, paint: Paint, f, ticks: int) -> void:
	var w := p.w
	var h := p.h
	var clay := paint.body
	var stone := paint.second
	var gold := paint.third
	var arm := h * 0.36
	var leg := h * 0.24
	limb(canvas, p.back(p.shoulder), p.hb, arm, 18.0, dark(stone), Vector2(-0.3, 1.0), paint)
	_fist(canvas, p.back(p.shoulder), p.hb, w * 0.34, dark(gold), paint)
	_stone_leg(canvas, p.back(p.hip), p.fb, leg, dark(stone), paint)
	_stone_leg(canvas, p.hip, p.ff, leg, stone, paint)
	var torso := rounded(-h * 0.76, -h * 0.17, w * 0.5, w * 0.36, 13.0)
	blob(canvas, torso, clay, Vector2(-w * 0.1, -h * 0.78), paint, 0.86)
	sheen(canvas, Vector2(-w * 0.2, -h * 0.66), Vector2(w * 0.14, h * 0.035), -0.2, clay)
	var crack := dark(dark(clay))
	canvas.draw_polyline(PackedVector2Array([Vector2(w * 0.3, -h * 0.62),
			Vector2(w * 0.2, -h * 0.52), Vector2(w * 0.27, -h * 0.44),
			Vector2(w * 0.2, -h * 0.36)]), crack, 2.5, true)
	canvas.draw_polyline(PackedVector2Array([Vector2(-w * 0.36, -h * 0.4),
			Vector2(-w * 0.24, -h * 0.34), Vector2(-w * 0.26, -h * 0.26)]), crack, 2.5, true)
	var rune := PackedVector2Array([Vector2(w * 0.02, -h * 0.58), Vector2(w * 0.12, -h * 0.5),
			Vector2(w * 0.02, -h * 0.42), Vector2(-w * 0.08, -h * 0.5)])
	blob(canvas, rune, gold, Vector2(w * 0.02, -h * 0.6), paint, 0.75)
	for x in [-1.0, 1.0]:  # The stone shoulders.
		var at := Vector2(x * w * 0.42, -h * 0.72)
		var rock := rounded(at.y - h * 0.07, at.y + h * 0.07, w * 0.17, w * 0.19, 7.0, at.x)
		blob(canvas, rock, stone if x > 0.0 else dark(stone), at + Vector2(0.0, -h * 0.08),
				paint, 0.82)
	# The head sits low between the shoulders: a block with a gold band and a heavy brow.
	var head := Vector2(w * 0.1, -h * 0.83) + p.head
	var block := rounded(head.y - h * 0.14, head.y + h * 0.13, w * 0.3, w * 0.28, 8.0, head.x)
	blob(canvas, block, stone, head + Vector2(-w * 0.12, -h * 0.15), paint, 0.86)
	var band := rounded(head.y - h * 0.12, head.y - h * 0.08, w * 0.3, w * 0.3, 2.0, head.x)
	canvas.draw_colored_polygon(band, gold)
	canvas.draw_polyline(PackedVector2Array([Vector2(head.x - w * 0.27, head.y - h * 0.11),
			Vector2(head.x + w * 0.27, head.y - h * 0.11)]), light(gold), 2.0, true)
	var brow := PackedVector2Array([Vector2(head.x - w * 0.06, head.y - h * 0.05),
			Vector2(head.x + w * 0.32, head.y - h * 0.055),
			Vector2(head.x + w * 0.32, head.y - h * 0.015),
			Vector2(head.x - w * 0.06, head.y - h * 0.025)])
	canvas.draw_colored_polygon(brow, dark(stone))
	eye(canvas, head + Vector2(w * 0.06, h * 0.015), 4.8, p, paint, true)
	eye(canvas, head + Vector2(w * 0.21, h * 0.015), 4.4, p, paint)
	canvas.draw_polyline(PackedVector2Array([head + Vector2(w * 0.02, h * 0.085),
			head + Vector2(w * 0.14, h * 0.095), head + Vector2(w * 0.26, h * 0.08)]),
			paint.ink, 2.5, true)
	limb(canvas, p.shoulder, p.hf, arm, 18.0, stone, Vector2(-0.3, 1.0), paint)
	_fist(canvas, p.shoulder, p.hf, w * 0.36, gold, paint)


static func _stone_leg(canvas: CanvasItem, hip: Vector2, foot: Vector2, length: float,
		color: Color, paint: Paint) -> void:
	limb(canvas, hip, foot, length, 20.0, color, Vector2(1.0, -0.2), paint)
	var block := rounded(foot.y - 10.0, foot.y + 1.0, 11.0, 13.0, 4.0, foot.x + 3.0)
	blob(canvas, block, color, Vector2(foot.x, foot.y - 11.0), paint, 0.8)


# A big gold fist at the hand, turned along the arm, its knuckles in front.
static func _fist(canvas: CanvasItem, shoulder: Vector2, hand: Vector2, size: float,
		color: Color, paint: Paint) -> void:
	var turn := (hand - shoulder).angle()
	var half := size / 2.0
	var points := rounded(-half, half, half, half, half * 0.45)
	for n in points.size():
		points[n] = hand + points[n].rotated(turn)
	blob(canvas, points, color, hand + Vector2(0.0, -half), paint, 0.82)
	var u := Vector2.from_angle(turn)
	var n := u.orthogonal()
	for k in [-0.33, 0.0, 0.33]:  # Knuckles.
		var at: Vector2 = hand + u * half * 0.55 + n * half * k
		canvas.draw_line(at - u * half * 0.3, at, dark(color), 2.0, true)
	sheen(canvas, hand + Vector2(-half * 0.3, -half * 0.45), Vector2(half * 0.35, half * 0.16),
			-0.4, color)


# The test fighter: a plain rounded box with limbs, in the player's color.
static func test(canvas: CanvasItem, p: Pose, paint: Paint, _f, _ticks: int) -> void:
	var w := p.w
	var h := p.h
	limb(canvas, p.back(p.shoulder), p.hb, h * 0.34, 9.0, dark(paint.third), Vector2(-0.4, 1.0),
			paint)
	limb(canvas, p.back(p.hip), p.fb, h * 0.28, 11.0, dark(paint.third), Vector2(1.0, 0.0), paint)
	limb(canvas, p.hip, p.ff, h * 0.28, 11.0, paint.third, Vector2(1.0, 0.0), paint)
	var body := rounded(-h, -h * 0.2, w * 0.45, w * 0.42, 12.0)
	blob(canvas, body, paint.body, Vector2(-w * 0.1, -h), paint, 0.86)
	eye(canvas, Vector2(w * 0.08, -h * 0.76), 6.0, p, paint, true)
	eye(canvas, Vector2(w * 0.28, -h * 0.76), 5.5, p, paint)
	limb(canvas, p.shoulder, p.hf, h * 0.34, 9.0, paint.third, Vector2(-0.4, 1.0), paint)


# A soft flat oval of the body, round when curled up, for afterimages.
static func silhouette(canvas: CanvasItem, p: Pose, color: Color) -> void:
	var radius := Vector2(p.w * 0.55, p.h * 0.47).lerp(Vector2.ONE * p.h * 0.36, p.ball)
	canvas.draw_colored_polygon(ellipse(Vector2(0.0, -p.h * 0.5), radius, 0.0, 24), color)

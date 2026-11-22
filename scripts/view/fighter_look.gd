# The fighters as clean vector art drawn in code (game design, "Art style"): posed every tick from
# the fighter's state (fighter_pose.gd, fighter_strike.gd), drawn in outlined, shaded shapes
# (fighter_art.gd), with smears behind fast limbs and the glow of the specials. Drawing only.
extends RefCounted

const Mode = preload("res://scripts/sim/fighter_state.gd").Mode
const FighterPose := preload("res://scripts/view/fighter_pose.gd")
const FighterStrike := preload("res://scripts/view/fighter_strike.gd")
const FighterArt := preload("res://scripts/view/fighter_art.gd")
const Pose = FighterPose.Pose

const SHADOW := Color(0.04, 0.05, 0.08, 0.35)


# Draws fighter f on canvas (a CanvasItem at the fighter's feet). player: the player's color,
# tint multiplies all colors, shake moves the body. anim: the view's timers for this fighter
# ("land", "turn", "flip", "throw", "throw_t", "tumble", "seed", "flash", "flash_color", "glow",
# "glow_color"); the pose drawn is kept in it as "pose", so the next one blends from it.
static func draw(canvas: CanvasItem, f, player: Color, tint: Color, shake: Vector2,
		ticks: int, anim: Dictionary = {}) -> void:
	var p := pose(f, ticks, anim)
	var paint := _paint(f, player, tint, anim)
	canvas.draw_set_transform(shake, 0.0, Vector2.ONE)
	_ring(canvas, f, player, tint.a)
	var frame := Transform2D(0.0, Vector2(f.facing, 1.0), 0.0, shake)
	canvas.draw_set_transform_matrix(frame)
	var light := Color(player.lightened(0.6), tint.a)
	for smear in p.smears:
		_smear(canvas, smear, light, player, false)
	var body := FighterPose.body_transform(p)
	if p.flip:
		body = Transform2D(0.0, Vector2(-1.0, 1.0), 0.0, Vector2.ZERO) * body
	canvas.draw_set_transform_matrix(frame * body)
	match p.shape:
		"kade":
			FighterArt.kade(canvas, p, paint, f, ticks)
		"pip":
			FighterArt.pip(canvas, p, paint, f, ticks)
		"brum":
			FighterArt.brum(canvas, p, paint, f, ticks)
		_:
			FighterArt.test(canvas, p, paint, f, ticks)
	canvas.draw_set_transform_matrix(frame)
	for smear in p.smears:
		_smear(canvas, smear, light, player, true)
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# The pose of f this tick, blended from the last one shown (kept in anim).
static func pose(f, ticks: int, anim: Dictionary) -> Pose:
	var p := FighterPose.make(f, ticks, anim)
	if f.attack != "" and (f.mode == Mode.GROUND or f.mode == Mode.AIR):
		FighterStrike.apply(p, f, ticks)
	if not anim.is_empty():  # Callers without timers (the menus) get no blending.
		var last = anim.get("pose")
		if last != null:
			FighterPose.blend(p, last, p.snap)
		anim["pose"] = p
	FighterPose.finalize(p)
	return p


# A flat afterimage of the body as last drawn, offset from the fighter.
static func draw_ghost(canvas: CanvasItem, f, offset: Vector2, color: Color,
		anim: Dictionary) -> void:
	var last = anim.get("pose")
	if last == null:
		return
	var p: Pose = last
	var frame := Transform2D(0.0, Vector2(f.facing, 1.0), 0.0, offset)
	canvas.draw_set_transform_matrix(frame * FighterPose.body_transform(p))
	FighterArt.silhouette(canvas, p, color)
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


static func _paint(f, player: Color, tint: Color, anim: Dictionary) -> FighterArt.Paint:
	var paint := FighterArt.Paint.new()
	var colors: Array = f.stats.look.get("colors", [])
	var flash: float = anim.get("flash", 0.0)
	var flash_color: Color = anim.get("flash_color", Color.WHITE)
	var tones := []
	for n in 3:
		var c: Color = colors[n] if colors.size() > n else [player, player.lightened(0.4),
				player.darkened(0.4)][n]
		tones.append(_tone(c, tint, flash, flash_color))
	paint.body = tones[0]
	paint.second = tones[1]
	paint.third = tones[2]
	paint.scarf = _tone(FighterArt.SCARF, tint, flash, flash_color)
	var glow: float = anim.get("glow", 0.0)
	paint.line = FighterArt.INK.lerp(anim.get("glow_color", Color.WHITE), glow)
	paint.line.a = tint.a
	paint.ink.a = tint.a
	paint.white = Color(1, 1, 1, tint.a)
	return paint


static func _tone(c: Color, tint: Color, flash: float, flash_color: Color) -> Color:
	var toned := Color(c.r * tint.r, c.g * tint.g, c.b * tint.b, tint.a)
	return toned.lerp(Color(flash_color, tint.a), flash)


# The player's ring under the feet over a soft shadow: who is who at a glance. Off the ground it
# shrinks and fades, a marker rather than a shadow.
static func _ring(canvas: CanvasItem, f, player: Color, alpha: float) -> void:
	var size := 1.0
	if f.mode in [Mode.AIR, Mode.LEDGE, Mode.CLIMB, Mode.HELD, Mode.HITSTUN] 			or f.mode == Mode.DODGE and f.dodge == "air":
		size = 0.6
		alpha *= 0.5
	var radius := Vector2(f.stats.width * 0.62, 9.0) * size
	canvas.draw_colored_polygon(FighterArt.ellipse(Vector2(0.0, -1.0), radius, 0.0, 24),
			Color(SHADOW, SHADOW.a * alpha))
	var ring := FighterArt.ellipse(Vector2(0.0, -1.0), radius, 0.0, 24)
	ring.append(ring[0])
	canvas.draw_polyline(ring, Color(player, 0.9 * alpha), 4.0 * size, true)


# One smear or special effect (see fighter_strike.gd), in the fighter's own space. front: the
# pass over the body (the orb, the burst, the front of the Whirl) or the one behind it.
static func _smear(canvas: CanvasItem, smear: Array, light: Color, player: Color,
		front: bool) -> void:
	match smear[0]:
		"arc":
			if not front:
				_crescent(canvas, smear[1], smear[2], smear[3], smear[4], smear[5], light,
						smear[6])
		"ring":
			if not front:
				var head: float = smear[3]
				for n in 2:
					_crescent(canvas, smear[1], smear[2], head + n * PI + smear[4],
							head + n * PI, smear[5], light, smear[6])
		"thrust":
			if not front:
				_thrust(canvas, smear[1], smear[2], smear[3], light, smear[4])
		"dive":
			if not front:
				_dive(canvas, smear[1], smear[2], light, smear[3])
		"streak":
			if not front:
				_streak(canvas, smear[1], smear[2], smear[3], light)
		"flare":
			if not front:
				_flare(canvas, smear[1], smear[2], smear[3], light)
		"whirl":
			_whirl(canvas, smear[1], smear[2], smear[3], smear[4], light, front)
		"orb":
			if front:
				_orb(canvas, smear[1], smear[2], smear[3], player)
		"burst":
			if front:
				_burst(canvas, smear[1], smear[2], smear[3], player)
		"glint":
			if front:
				_glint(canvas, smear[1], smear[2])


# A curved band from angle start (its thin, clear tail) to angle now (its full head).
static func _crescent(canvas: CanvasItem, pivot: Vector2, radius: float, start: float,
		now: float, width: float, color: Color, alpha: float) -> void:
	var count := 12
	var last_out := Vector2.ZERO
	var last_in := Vector2.ZERO
	var last_color := Color(color, 0.0)
	var edge := PackedVector2Array()
	var edge_colors := PackedColorArray()
	for n in count + 1:
		var t := float(n) / count
		var a := lerpf(start, now, t)
		var thick := width * (0.15 + 0.85 * t)
		var dir := Vector2.from_angle(a)
		var outer := pivot + dir * (radius + thick * 0.5)
		var inner := pivot + dir * (radius - thick * 0.5)
		var c := Color(color, color.a * alpha * t * 0.8)
		if n > 0:
			canvas.draw_primitive(PackedVector2Array([last_out, outer, inner, last_in]),
					PackedColorArray([last_color, c, c, last_color]), PackedVector2Array())
		edge.append(outer)
		edge_colors.append(Color(1.0, 1.0, 1.0, color.a * alpha * t))
		last_out = outer
		last_in = inner
		last_color = c
	canvas.draw_polyline_colors(edge, edge_colors, 2.5, true)


# Speed lines behind a punch or kick: a fading wedge and two thin lines.
static func _thrust(canvas: CanvasItem, from: Vector2, to: Vector2, width: float, color: Color,
		alpha: float) -> void:
	var u := (to - from).normalized()
	var n := u.orthogonal()
	var clear := Color(color, 0.0)
	var c := Color(color, color.a * alpha * 0.7)
	canvas.draw_primitive(PackedVector2Array([from, to + n * width * 0.5, to - n * width * 0.5]),
			PackedColorArray([clear, c, c]), PackedVector2Array())
	for side in [-1.0, 1.0]:
		var start: Vector2 = from - u * 10.0 + n * width * side
		var end: Vector2 = to - u * 14.0 + n * width * side * 0.8
		canvas.draw_polyline_colors(PackedVector2Array([start, end]), PackedColorArray([clear,
				Color(1, 1, 1, color.a * alpha * 0.8)]), 2.5, true)


# Speed lines above a ground pound as it drops.
static func _dive(canvas: CanvasItem, top: Vector2, half: float, color: Color, k: float) -> void:
	for n in 4:
		var x := lerpf(-half, half, n / 3.0)
		var length := 30.0 + 26.0 * k + (n % 2) * 14.0
		var start := top + Vector2(x, -8.0 - length)
		canvas.draw_polyline_colors(PackedVector2Array([start, top + Vector2(x * 0.8, -6.0)]),
				PackedColorArray([Color(color, 0.0), Color(color, color.a * 0.8)]), 3.0, true)


# The Swoop's streak: lines trailing far behind against the way aimed.
static func _streak(canvas: CanvasItem, middle: Vector2, aim: Vector2, size: float,
		color: Color) -> void:
	var back := -aim.normalized()
	var n := back.orthogonal()
	var clear := Color(color, 0.0)
	canvas.draw_primitive(PackedVector2Array([middle + n * size * 0.42,
			middle + back * size * 2.6, middle - n * size * 0.42]),
			PackedColorArray([Color(color, color.a * 0.45), clear, Color(color, color.a * 0.45)]),
			PackedVector2Array())
	for k in [-0.35, 0.0, 0.35]:
		var start: Vector2 = middle + n * size * k + back * size * 0.3
		canvas.draw_polyline_colors(PackedVector2Array([start, start + back * size * (2.2 -
				absf(k) * 2.0)]), PackedColorArray([Color(1, 1, 1, color.a * 0.85), clear]), 3.0,
				true)


# Feathers flaring out before the Swoop.
static func _flare(canvas: CanvasItem, middle: Vector2, radius: float, k: float,
		color: Color) -> void:
	for n in 5:
		var a := -PI / 2.0 + (n - 2) * 0.5
		var dir := Vector2.from_angle(a)
		var from := middle + dir * radius * (1.05 + 0.2 * k)
		canvas.draw_line(from, from + dir * (6.0 + 16.0 * k), Color(color, color.a * 0.9), 4.0,
				true)


# The Whirl's motion arcs: flat rings round the body at fist height and lower, turning with the
# spin; the near half is drawn over the body, the far half behind it.
static func _whirl(canvas: CanvasItem, middle: Vector2, radius: float, spin: float, h: float,
		color: Color, front: bool) -> void:
	for ring in 2:
		var center := middle + Vector2(0.0, ring * h * 0.28)
		var size := Vector2(radius * (1.0 - ring * 0.25), radius * 0.26)
		for arc in 2:
			var head := spin + arc * PI
			var points := PackedVector2Array()
			var colors := PackedColorArray()
			for n in 13:
				var a := head - 2.0 * (1.0 - n / 12.0)
				if (sin(a) >= 0.0) != front:
					continue
				points.append(center + Vector2(cos(a) * size.x, sin(a) * size.y))
				colors.append(Color(color, color.a * 0.85 * n / 12.0))
			if points.size() > 1:
				canvas.draw_polyline_colors(points, colors, 7.0 - ring * 2.0, true)


# The Spark growing in the hand: a soft glow, a bright core and motes circling it.
static func _orb(canvas: CanvasItem, at: Vector2, radius: float, t: int, player: Color) -> void:
	if radius < 1.0:
		return
	var pulse := 1.0 + 0.1 * sin(t * 1.3)
	canvas.draw_circle(at, radius * 1.7 * pulse, Color(player.lightened(0.2), 0.25), true, -1.0,
			true)
	canvas.draw_circle(at, radius, player.lightened(0.45), true, -1.0, true)
	canvas.draw_circle(at, radius * 0.55, Color(1.0, 1.0, 0.95), true, -1.0, true)
	for n in 3:
		var a := t * 0.55 + TAU * n / 3.0
		canvas.draw_circle(at + Vector2.from_angle(a) * radius * 1.45, 2.5,
				Color(1, 1, 1, 0.9), true, -1.0, true)


# A small four-point sparkle on the limb about to strike: the wind-up cue.
static func _glint(canvas: CanvasItem, at: Vector2, k: float) -> void:
	var size := 4.0 + 9.0 * k
	var points := PackedVector2Array()
	for n in 8:
		points.append(at + Vector2.from_angle(TAU * n / 8.0 - PI / 2.0)
				* (size if n % 2 == 0 else size * 0.22))
	canvas.draw_colored_polygon(points, Color(1.0, 1.0, 0.9, 0.95))
	canvas.draw_circle(at, size * 0.25, Color.WHITE, true, -1.0, true)


# A ring and rays where the Spark leaves the hand.
static func _burst(canvas: CanvasItem, at: Vector2, radius: float, age: int,
		player: Color) -> void:
	var k := age / 8.0
	var fade := 1.0 - k
	canvas.draw_arc(at, radius * (0.6 + k * 0.9), 0.0, TAU, 24, Color(player.lightened(0.6),
			fade), 4.0 * fade + 1.0, true)
	for n in 6:
		var dir := Vector2.from_angle(TAU * n / 6.0 + 0.3)
		canvas.draw_line(at + dir * radius * (0.7 + k), at + dir * radius * (1.0 + k * 1.4),
				Color(1, 1, 1, fade), 3.0, true)

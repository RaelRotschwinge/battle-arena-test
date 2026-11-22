# The shapes of the fighters: flat vector shapes drawn in code (game design, "Art style"), kept
# simple because pixel art comes later. Squash and stretch from the fighter's speed and mode, and
# an arm or leg that reaches out to the hitbox of an attack. Drawing only.
extends RefCounted

const Mode = preload("res://scripts/sim/fighter_state.gd").Mode
const FighterCombat := preload("res://scripts/sim/fighter_combat.gd")


# Draws fighter f on canvas (a CanvasItem at the fighter's feet). player: the player's color,
# tint multiplies all colors, shake moves the body.
static func draw(canvas: CanvasItem, f, player: Color, tint: Color, shake: Vector2,
		ticks: int) -> void:
	var s = f.stats
	var look: Dictionary = s.look
	var squash := _squash(f, s)
	# A colored shadow under the feet tells the players apart.
	canvas.draw_set_transform(shake, 0.0, Vector2.ONE)
	_ellipse(canvas, Vector2(0.0, -2.0), Vector2(s.width * 0.75, 7.0), Color(player, 0.7 * tint.a))
	canvas.draw_set_transform(shake, 0.0, squash)
	var colors: Array = look.get("colors", [])
	var c1: Color = colors[0] if colors.size() > 0 else player
	var c2: Color = colors[1] if colors.size() > 1 else player.lightened(0.4)
	var c3: Color = colors[2] if colors.size() > 2 else player.darkened(0.4)
	c1 *= tint
	c2 *= tint
	c3 *= tint
	_limb(canvas, f, c2)
	match look.get("shape", "test"):
		"pip":
			_pip(canvas, f, s, c1, c2, c3, ticks)
		"kade":
			_kade(canvas, f, s, c1, c2, c3)
		"brum":
			_brum(canvas, f, s, c1, c2, c3)
		_:
			_test(canvas, f, s, c1)
	_special(canvas, f, s, c2, player)
	if f.mode == Mode.LEDGE:  # Hands on the ledge.
		canvas.draw_rect(Rect2(f.facing * s.width / 2.0 - 8.0, -s.height - 6.0, 16.0, 14.0), c2)
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# Stretched while flying fast up or down, squashed in the take-off and landing lag.
static func _squash(f, s) -> Vector2:
	var y := 1.0
	match f.mode:
		Mode.JUMP_SQUAT:
			y = 0.82
		Mode.AIR, Mode.HITSTUN:
			y = 1.0 + clampf(absf(f.velocity.y) / s.max_fall_speed * 0.12, 0.0, 0.16)
		Mode.GROUND:
			if f.lag > 0:
				y = 0.88
			elif f.running:
				y = 0.95
		Mode.SHIELD, Mode.DODGE:
			y = 0.9 if f.dodge != "roll" else 0.7
	return Vector2(1.0 / sqrt(y), y)


# During an attack an arm or leg reaches from the body to the hitbox, so it is clear who hits.
static func _limb(canvas: CanvasItem, f, color: Color) -> void:
	if f.attack == "" or f.attack in ["grab"] or f.attack.begins_with("special"):
		return
	var box: Rect2 = FighterCombat.data(f)["box"]
	if not box.has_area():
		return
	var x: float = box.position.x if f.facing > 0 else -box.end.x
	var target := Rect2(Vector2(x, box.position.y), box.size).get_center()
	var root := Vector2(0.0, -f.stats.height * 0.55)
	var reach := 0.45 if FighterCombat.in_startup(f) else 0.9
	canvas.draw_line(root, root.lerp(target, reach), color, 14.0)
	canvas.draw_circle(root.lerp(target, reach), 10.0, color)


# The specials show what they are: an orb growing in the hand before a Spark, feathers that flare
# before a Swoop and streaks behind it, rings that spin around a Whirl.
static func _special(canvas: CanvasItem, f, s, light: Color, player: Color) -> void:
	if not f.attack.begins_with("special"):
		return
	var a: Dictionary = FighterCombat.data(f)
	var t: int = f.attack_ticks
	var middle := Vector2(0.0, -s.height * 0.5)
	if a.has("shot"):
		if t <= a["startup"]:
			var offset: Vector2 = a["shot"]["offset"]
			var radius: float = a["shot"]["size"].x / 2.0 * float(t) / a["startup"]
			canvas.draw_circle(Vector2(offset.x * f.facing, offset.y), radius, player.lightened(0.5))
			canvas.draw_circle(Vector2(offset.x * f.facing, offset.y), radius * 0.5, Color.WHITE)
	elif a.has("multi"):
		if t > a["startup"] and t <= a["startup"] + a["active"]:
			for n in 3:
				var turn := t * 0.7 + TAU * n / 3.0
				canvas.draw_arc(middle, s.width * 1.05, turn, turn + 1.4, 12,
						Color(light, 0.8), 8.0)
	elif a.has("move"):
		if t <= a["startup"]:
			for n in 5:
				var turn := -PI / 2.0 + (n - 2) * 0.5
				var from: Vector2 = middle + Vector2(cos(turn), sin(turn)) * s.width * 0.5
				canvas.draw_line(from, from + Vector2(cos(turn), sin(turn)) * (8.0 + t * 3.0),
						light, 5.0)
		elif t <= a["startup"] + a["active"]:
			var back: Vector2 = -f.special_aim
			for n in 3:
				var side: Vector2 = back.orthogonal() * (n - 1) * s.width * 0.3
				canvas.draw_line(middle + side, middle + side + back * s.width * 1.6,
						Color(player.lightened(0.4), 0.6), 6.0)


static func _test(canvas: CanvasItem, f, s, body: Color) -> void:
	var w: float = s.width
	var h: float = s.height
	canvas.draw_rect(Rect2(-w / 2.0, -h, w, h), body)
	_eye(canvas, f, Vector2(f.facing * w * 0.22, -h * 0.75), 8.0, body.a)


# Kade: an all-rounder with a round head and a scarf that trails behind.
static func _kade(canvas: CanvasItem, f, s, body: Color, skin: Color, scarf: Color) -> void:
	var w: float = s.width
	var h: float = s.height
	var back: int = -f.facing
	canvas.draw_rect(Rect2(-w * 0.3, -h * 0.28, w * 0.22, h * 0.28), scarf)  # Legs.
	canvas.draw_rect(Rect2(w * 0.08, -h * 0.28, w * 0.22, h * 0.28), scarf)
	canvas.draw_rect(Rect2(-w * 0.42, -h * 0.66, w * 0.84, h * 0.42), body)
	var flutter: float = clampf(f.velocity.x * -f.facing * 1.5, -10.0, 24.0)
	canvas.draw_colored_polygon(PackedVector2Array([Vector2(0.0, -h * 0.68),
			Vector2(back * (w * 0.55 + flutter), -h * 0.62 - flutter * 0.3),
			Vector2(back * (w * 0.5 + flutter), -h * 0.54), Vector2(0.0, -h * 0.6)]), scarf)
	canvas.draw_circle(Vector2(0.0, -h * 0.82), w * 0.33, skin)
	_eye(canvas, f, Vector2(f.facing * w * 0.15, -h * 0.84), 6.0, body.a)


# Pip: small, round and quick, with a pointed beak and wings that flap in the air.
static func _pip(canvas: CanvasItem, f, s, body: Color, belly: Color, beak: Color,
		ticks: int) -> void:
	var w: float = s.width
	var h: float = s.height
	var middle := Vector2(0.0, -h * 0.45)
	var flap := 0.0
	if f.mode == Mode.AIR:
		flap = sin(ticks * 0.6) * 0.6 if f.velocity.y < 0.0 else 0.3
	for side in [-1.0, 1.0]:
		var root := middle + Vector2(side * w * 0.42, -h * 0.05)
		var wing_tip := root + Vector2(side * w * 0.35, -h * 0.1).rotated(side * flap)
		canvas.draw_line(root, wing_tip, belly, 12.0)
	canvas.draw_circle(middle, w * 0.5, body)
	canvas.draw_circle(middle + Vector2(f.facing * w * 0.08, h * 0.1), w * 0.3, belly)
	canvas.draw_circle(Vector2(0.0, -h * 0.82), w * 0.3, body)
	var tip := Vector2(f.facing * w * 0.62, -h * 0.8)
	canvas.draw_colored_polygon(PackedVector2Array([Vector2(f.facing * w * 0.2, -h * 0.88),
			tip, Vector2(f.facing * w * 0.2, -h * 0.74)]), beak)
	_eye(canvas, f, Vector2(f.facing * w * 0.1, -h * 0.86), 5.0, body.a)


# Brum: wide and heavy, a square head on broad shoulders and two big fists.
static func _brum(canvas: CanvasItem, f, s, body: Color, stone: Color, gold: Color) -> void:
	var w: float = s.width
	var h: float = s.height
	canvas.draw_rect(Rect2(-w * 0.36, -h * 0.25, w * 0.28, h * 0.25), stone)  # Legs.
	canvas.draw_rect(Rect2(w * 0.08, -h * 0.25, w * 0.28, h * 0.25), stone)
	canvas.draw_colored_polygon(PackedVector2Array([Vector2(-w * 0.36, -h * 0.22),
			Vector2(-w * 0.52, -h * 0.72), Vector2(w * 0.52, -h * 0.72),
			Vector2(w * 0.36, -h * 0.22)]), body)
	canvas.draw_rect(Rect2(-w * 0.22, -h * 0.98, w * 0.44, h * 0.28), stone)
	canvas.draw_rect(Rect2(-w * 0.22, -h * 0.76, w * 0.44, h * 0.05), gold)
	for side in [-1.0, 1.0]:
		canvas.draw_circle(Vector2(side * w * 0.55, -h * 0.4), w * 0.17, gold)
	_eye(canvas, f, Vector2(f.facing * w * 0.1, -h * 0.87), 6.0, body.a)


static func _eye(canvas: CanvasItem, f, at: Vector2, size: float, alpha: float) -> void:
	canvas.draw_circle(at, size, Color(1, 1, 1, alpha))
	canvas.draw_circle(at + Vector2(f.facing * size * 0.4, 0.0), size * 0.5, Color(0, 0, 0, alpha))


static func _ellipse(canvas: CanvasItem, at: Vector2, radius: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for n in 20:
		var turn := TAU * n / 20.0
		points.append(at + Vector2(cos(turn) * radius.x, sin(turn) * radius.y))
	canvas.draw_colored_polygon(points, color)

# The stage look shared by every arena (arena_view.gd): solid platforms with a beveled cap, a
# texture of the arena's kind, darker sides and a dark outline; thin platforms as outlined slabs
# with a bright top, a keel and a soft shadow; small bright corners on the ledges. The style comes
# from the arena's backdrop: {"kind": texture, "cap": top decoration, "accent": its color,
# "thin": thin platform kind}.
extends RefCounted

const Kit := preload("res://scripts/view/backdrop_kit.gd")
const CAP := 16.0  # Height of the beveled top band of a solid platform.

static var _boxes := {}  # Color -> StyleBoxFlat, the outlined body of a thin platform.


static func solid(c: CanvasItem, r: Rect2, colors: Dictionary, style: Dictionary) -> void:
	var body: Color = colors["ground"]
	var top: Color = colors["ground_top"]
	c.draw_rect(r, body)
	var inside := Rect2(r.position.x, r.position.y + CAP, r.size.x, r.size.y - CAP)
	match style.get("kind", ""):
		"rock":
			_stones(c, inside, body)
		"earth":
			_strata(c, inside, body)
		"dock":
			_boards(c, inside, body)
		"slab":
			_facets(c, inside, body, style.get("accent", top))
		"bricks":
			_bricks(c, inside, body, 34.0, 74.0)
		"iron":
			_plates(c, inside, body)
		_:
			_panels(c, inside, body)
	# Volume: shaded sides and a shadow under the cap.
	Kit.hband(c, Rect2(r.position.x, r.position.y, 22.0, r.size.y), Color(0, 0, 0, 0.22),
			Color(0, 0, 0, 0.0))
	Kit.hband(c, Rect2(r.end.x - 30.0, r.position.y, 30.0, r.size.y), Color(0, 0, 0, 0.0),
			Color(0, 0, 0, 0.3))
	Kit.band(c, Rect2(r.position.x, r.position.y + CAP, r.size.x, 22.0), Color(0, 0, 0, 0.35),
			Color(0, 0, 0, 0.0))
	_cap(c, r, top, style)
	c.draw_rect(r, Kit.OUTLINE, false, 3.0)


static func _cap(c: CanvasItem, r: Rect2, top: Color, style: Dictionary) -> void:
	var accent: Color = style.get("accent", top)
	match style.get("cap", ""):
		"grass", "moss":  # A green cap whose lower edge hangs down in soft drips.
			c.draw_rect(Rect2(r.position, Vector2(r.size.x, CAP)), accent)
			var x := r.position.x + 10.0
			var i := 0
			while x < r.end.x - 10.0:
				var rad: float = 5.0 + 7.0 * Kit.rnd(i, 7)
				if style["cap"] == "moss" and Kit.rnd(i, 8) > 0.7:
					var hang: float = 10.0 + 22.0 * Kit.rnd(i, 9)
					c.draw_line(Vector2(x, r.position.y + CAP), Vector2(x, r.position.y + CAP + hang),
							accent.darkened(0.15), 4.0, true)
				c.draw_circle(Vector2(x, r.position.y + CAP - 2.0), rad, accent, true, -1.0, true)
				x += rad * 1.6 + 6.0
				i += 1
			c.draw_rect(Rect2(r.position.x, r.position.y, r.size.x, 5.0), accent.lightened(0.3))
			c.draw_rect(Rect2(r.position.x, r.position.y + 5.0, r.size.x, 3.0), accent.lightened(0.1))
		"glow":  # A metal lip with a hot line along its top.
			c.draw_rect(Rect2(r.position, Vector2(r.size.x, CAP)), top.darkened(0.25))
			c.draw_rect(Rect2(r.position.x, r.position.y + CAP - 3.0, r.size.x, 3.0),
					top.darkened(0.55))
			Kit.band(c, Rect2(r.position.x, r.position.y - 14.0, r.size.x, 14.0), Color(accent, 0.0),
					Color(accent, 0.28))
			c.draw_rect(Rect2(r.position.x, r.position.y, r.size.x, 4.0), accent.lightened(0.35))
		_:
			c.draw_rect(Rect2(r.position, Vector2(r.size.x, CAP)), top)
			c.draw_rect(Rect2(r.position.x, r.position.y, r.size.x, 4.0), top.lightened(0.35))
			c.draw_rect(Rect2(r.position.x, r.position.y + CAP - 3.0, r.size.x, 3.0),
					top.darkened(0.3))


# Rounded stones in staggered rows, each with a lit top and a shade below.
static func _stones(c: CanvasItem, r: Rect2, body: Color) -> void:
	var row := 0
	var y := r.position.y + 20.0
	while y < r.end.y - 16.0:
		var x := r.position.x + (18.0 if row % 2 == 0 else 46.0)
		var i := row * 31
		while x < r.end.x - 14.0:
			var rad: float = 13.0 + 8.0 * Kit.rnd(i, 11)
			var at := Vector2(x, y + 6.0 * Kit.rnd(i, 12))
			c.draw_circle(at + Vector2(0, 3), rad, body.darkened(0.12), true, -1.0, true)
			c.draw_circle(at, rad - 1.0, body.lerp(Color.WHITE, 0.02 + 0.05 * Kit.rnd(i, 13)),
					true, -1.0, true)
			c.draw_arc(at, rad - 4.0, PI * 1.15, PI * 1.75, 6, Color(body.lightened(0.3), 0.6),
					2.0, true)
			x += rad * 2.0 + 10.0
			i += 1
		y += 36.0
		row += 1


# Layers of earth with wavy seams and a few pebbles.
static func _strata(c: CanvasItem, r: Rect2, body: Color) -> void:
	var y := r.position.y + 34.0
	var k := 0
	while y < r.end.y:
		var line := PackedVector2Array()
		var x := r.position.x
		while x <= r.end.x:
			line.append(Vector2(x, y + 5.0 * sin(x * 0.02 + k * 1.3)))
			x += 20.0
		c.draw_polyline(line, body.darkened(0.25), 4.0, true)
		c.draw_polyline(line, body.lightened(0.08), 1.5, true)
		y += 46.0 + 10.0 * Kit.rnd(k, 3)
		k += 1
	for i in int(r.size.x * r.size.y / 9000.0):
		var at := r.position + Vector2(Kit.rnd(i, 21), Kit.rnd(i, 22)) * r.size
		c.draw_circle(at, 3.0 + 3.0 * Kit.rnd(i, 23), body.lightened(0.12), true, -1.0, true)


# Horizontal boards with staggered joints.
static func _boards(c: CanvasItem, r: Rect2, body: Color) -> void:
	var h := 28.0
	var row := 0
	var y := r.position.y
	while y < r.end.y:
		c.draw_rect(Rect2(r.position.x, y, r.size.x, 3.0), body.darkened(0.14))
		c.draw_rect(Rect2(r.position.x, y + 3.0, r.size.x, 2.0), body.lightened(0.08))
		var x := r.position.x + 60.0 + 70.0 * Kit.rnd(row, 4)
		while x < r.end.x - 20.0:
			c.draw_rect(Rect2(x, y, 3.0, minf(h, r.end.y - y)), body.darkened(0.14))
			x += 150.0 + 60.0 * Kit.rnd(int(x), row)
		y += h
		row += 1


# Smooth slanted facets in two tones and a thin glowing inlay.
static func _facets(c: CanvasItem, r: Rect2, body: Color, accent: Color) -> void:
	var x := r.position.x - 60.0
	var i := 0
	while x < r.end.x:
		var w: float = 120.0 + 90.0 * Kit.rnd(i, 31)
		var tone := body.lightened(0.035) if i % 2 == 0 else body.darkened(0.05)
		var a := Vector2(maxf(x, r.position.x), r.position.y)
		var quad := PackedVector2Array([a, Vector2(minf(x + w, r.end.x), r.position.y),
				Vector2(minf(x + w + 70.0, r.end.x), r.end.y), Vector2(clampf(x + 70.0,
				r.position.x, r.end.x), r.end.y)])
		c.draw_colored_polygon(quad, tone)
		x += w
		i += 1
	c.draw_line(Vector2(r.position.x + 24.0, r.position.y + 34.0),
			Vector2(r.end.x - 24.0, r.position.y + 34.0), Color(accent, 0.55), 2.0, true)


# Bricks in staggered courses, each a little different in tone.
static func _bricks(c: CanvasItem, r: Rect2, body: Color, h: float, w: float) -> void:
	var row := 0
	var y := r.position.y
	while y < r.end.y:
		var x := r.position.x - (w / 2.0 if row % 2 == 1 else 0.0)
		var i := row * 40
		while x < r.end.x:
			var brick := Rect2(maxf(x, r.position.x) + 2.0, y + 2.0, 0.0, minf(h, r.end.y - y) - 4.0)
			brick.size.x = minf(x + w, r.end.x) - brick.position.x - 2.0
			if brick.size.x > 2.0 and brick.size.y > 2.0:
				var tone := body.lerp(Color.WHITE, 0.04 + 0.07 * Kit.rnd(i, 41))
				c.draw_rect(brick, tone)
				c.draw_rect(Rect2(brick.position, Vector2(brick.size.x, 3.0)), tone.lightened(0.12))
			x += w
			i += 1
		y += h
		row += 1


# Riveted iron plates.
static func _plates(c: CanvasItem, r: Rect2, body: Color) -> void:
	var w := 140.0
	var h := 80.0
	var y := r.position.y + 6.0
	var row := 0
	while y < r.end.y:
		var x := r.position.x + 6.0 - (w / 2.0 if row % 2 == 1 else 0.0)
		while x < r.end.x:
			var plate := Rect2(maxf(x, r.position.x + 6.0), y, 0.0, minf(h, r.end.y - y) - 6.0)
			plate.size.x = minf(x + w - 6.0, r.end.x - 6.0) - plate.position.x
			if plate.size.x > 10.0 and plate.size.y > 10.0:
				c.draw_rect(plate, body.lightened(0.06))
				c.draw_rect(Rect2(plate.position, Vector2(plate.size.x, 3.0)), body.lightened(0.18))
				for corner in [plate.position + Vector2(8, 10), Vector2(plate.end.x - 8.0,
						plate.position.y + 10.0)]:
					c.draw_circle(corner, 3.5, body.lightened(0.3), true, -1.0, true)
			x += w
		y += h
		row += 1


# Clean square panels with seams and screws, for the training arena.
static func _panels(c: CanvasItem, r: Rect2, body: Color) -> void:
	var x := r.position.x + 100.0
	while x < r.end.x - 20.0:
		c.draw_rect(Rect2(x, r.position.y, 2.0, r.size.y), body.darkened(0.25))
		x += 100.0
	var y := r.position.y + 70.0
	while y < r.end.y:
		c.draw_rect(Rect2(r.position.x, y, r.size.x, 2.0), body.darkened(0.25))
		y += 70.0
	c.draw_rect(Rect2(r.position.x, r.position.y, r.size.x, 8.0), body.lightened(0.08))


# A thin platform: a slab with a bright top, a narrower keel under it and a soft shadow; kind
# "plank" adds board joints, "grill" slots, "stone" block joints, "glass" a glowing line.
static func thin(c: CanvasItem, r: Rect2, color: Color, kind: String) -> void:
	var keel := Rect2(r.position.x + 14.0, r.end.y - 4.0, r.size.x - 28.0, 12.0)
	c.draw_style_box(_box(color.darkened(0.35), 10.0), keel)
	c.draw_style_box(_box(color.darkened(0.12), 14.0), r)
	var face := r.grow(-3.0)
	match kind:
		"plank":
			var x := face.position.x + 40.0
			while x < face.end.x - 10.0:
				c.draw_line(Vector2(x, face.position.y + 4.0), Vector2(x, face.end.y), color.darkened(0.4),
						2.0)
				x += 56.0
		"grill":
			var x := face.position.x + 12.0
			while x < face.end.x - 12.0:
				c.draw_rect(Rect2(x, face.position.y + 5.0, 10.0, face.size.y - 7.0),
						color.darkened(0.6))
				x += 20.0
		"stone":
			var x := face.position.x + 70.0
			while x < face.end.x - 20.0:
				c.draw_line(Vector2(x, face.position.y), Vector2(x, face.end.y), color.darkened(0.45),
						2.0)
				x += 90.0
		"glass":
			c.draw_line(Vector2(face.position.x + 8.0, face.end.y - 2.0),
					Vector2(face.end.x - 8.0, face.end.y - 2.0), color.lightened(0.4), 2.0)
	c.draw_rect(Rect2(face.position.x + 2.0, face.position.y, face.size.x - 4.0, 4.0),
			color.lightened(0.35))


# An outlined body with rounded corners and a soft shadow below, cached per color.
static func _box(color: Color, shadow: float) -> StyleBoxFlat:
	var key := "%s/%d" % [color.to_html(), shadow]
	if not _boxes.has(key):
		var box := StyleBoxFlat.new()
		box.bg_color = color
		box.border_color = Kit.OUTLINE
		box.set_border_width_all(3)
		box.set_corner_radius_all(6)
		box.shadow_color = Color(0, 0, 0, 0.3)
		box.shadow_size = int(shadow)
		box.shadow_offset = Vector2(0, shadow * 0.6)
		box.anti_aliasing = true
		_boxes[key] = box
	return _boxes[key]


# Ledges: a small bright corner where a fighter can hang.
static func ledges(c: CanvasItem, list: Array, color: Color) -> void:
	for ledge: Dictionary in list:
		var p: Vector2 = ledge["point"]
		var out: float = -float(ledge["side"])  # Toward the inside of the platform.
		var corner := PackedVector2Array([p + Vector2(out * 2.0, 2.0), p + Vector2(out * 20.0, 2.0),
				p + Vector2(out * 2.0, 20.0)])
		c.draw_colored_polygon(corner, Color(color.lightened(0.6), 0.75))

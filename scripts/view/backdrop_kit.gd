# Drawing helpers shared by the arena backdrops (backdrop_*.gd) and the stage (arena_decor.gd):
# gradients, soft glows, silhouettes, clouds, stars, drifting motes and a stable scatter. Backdrop
# layers are painted as seen from CENTER at zoom 1; their fills reach COVER, so no camera position
# ever finds an edge.
extends RefCounted

const CENTER := Vector2(960.0, 640.0)
const COVER := Rect2(-2600.0, -2400.0, 7120.0, 6000.0)
const OUTLINE := Color(0.067, 0.075, 0.102, 0.9)

static var _ring := PackedVector2Array()


# A stable pseudo-random number in [0, 1) for item i; salt picks another sequence.
static func rnd(i: int, salt: int = 0) -> float:
	return fposmod(sin(i * 12.9898 + salt * 78.233) * 43758.5453, 1.0)


# A rectangle shaded from the top color to the bottom color.
static func band(c: CanvasItem, r: Rect2, top: Color, bottom: Color) -> void:
	c.draw_polygon(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end,
			Vector2(r.position.x, r.end.y)]), PackedColorArray([top, top, bottom, bottom]))


# A rectangle shaded from the left color to the right color.
static func hband(c: CanvasItem, r: Rect2, left: Color, right: Color) -> void:
	c.draw_polygon(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end,
			Vector2(r.position.x, r.end.y)]), PackedColorArray([left, right, right, left]))


# A vertical gradient over the whole cover through stops [[y, color], ...] from top to bottom.
static func vgradient(c: CanvasItem, stops: Array) -> void:
	var y0: float = COVER.position.y
	var c0: Color = stops[0][1]
	for stop: Array in stops + [[COVER.end.y, stops[-1][1]]]:
		var y1: float = stop[0]
		if y1 > y0:
			band(c, Rect2(COVER.position.x, y0, COVER.size.x, y1 - y0), c0, stop[1])
		y0 = y1
		c0 = stop[1]


# A soft round light: full color in the middle, fading to nothing at radius.
static func glow(c: CanvasItem, at: Vector2, radius: float, color: Color,
		squash: float = 1.0) -> void:
	if _ring.is_empty():
		for i in 25:
			_ring.append(Vector2.from_angle(TAU * i / 24.0))
	var points := PackedVector2Array([at])
	var colors := PackedColorArray([color])
	for k in 2:  # A middle ring makes the falloff soft instead of a cone.
		var reach: float = radius * (0.4 if k == 0 else 1.0)
		var tint := Color(color, color.a * (0.4 if k == 0 else 0.0))
		for p in _ring:
			points.append(at + Vector2(p.x, p.y * squash) * reach)
			colors.append(tint)
	var indices := PackedInt32Array()
	for i in 24:
		var a := 1 + i
		var b := 26 + i
		indices.append_array([0, a, a + 1, a, b, a + 1, a + 1, b, b + 1])
	RenderingServer.canvas_item_add_triangle_array(c.get_canvas_item(), indices, points, colors)


# A silhouette under the line edge (points from left to right), shaded from top to bottom color
# and filled down to y bottom; its outline is antialiased.
static func fill_below(c: CanvasItem, edge: PackedVector2Array, bottom: float, top: Color,
		low: Color) -> void:
	var points := PackedVector2Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	for i in edge.size():
		points.append_array([edge[i], Vector2(edge[i].x, bottom)])
		colors.append_array([top, low])
		if i > 0:
			var k := i * 2
			indices.append_array([k - 2, k, k - 1, k, k + 1, k - 1])
	RenderingServer.canvas_item_add_triangle_array(c.get_canvas_item(), indices, points, colors)
	c.draw_polyline(edge, top, 2.0, true)


# The line y = height(x) sampled every step from x0 to x1, for fill_below.
static func ridge(x0: float, x1: float, step: float, height: Callable) -> PackedVector2Array:
	var edge := PackedVector2Array()
	var x := x0
	while x < x1 + step:
		var y: float = height.call(x)
		edge.append(Vector2(x, y))
		x += step
	return edge


# Small dots in rect, some brighter; salt picks the pattern.
static func stars(c: CanvasItem, count: int, rect: Rect2, color: Color, salt: int) -> void:
	for i in count:
		var at := rect.position + Vector2(rnd(i, salt), rnd(i, salt + 1)) * rect.size
		var big := rnd(i, salt + 2)
		c.draw_circle(at, 1.0 + big * 1.6, Color(color, color.a * (0.35 + 0.65 * big)), true,
				-1.0, true)


# A puffy cloud with a flat base: width w, base at y of at, a darker shade along the bottom.
# Opaque colors only (blend them toward the sky first): overlapping puffs must not show.
static func cloud(c: CanvasItem, at: Vector2, w: float, color: Color, shade: Color,
		salt: int) -> void:
	var puffs := 5
	for pass_i in 2:  # The shade first, offset down, then the body.
		var tint: Color = shade if pass_i == 0 else color
		var drop: float = w * 0.035 if pass_i == 0 else 0.0
		for i in puffs:
			var f := (i + 0.5) / puffs
			var r: float = w * (0.1 + 0.1 * sin(PI * f)) * (0.8 + 0.4 * rnd(i, salt))
			var x: float = at.x - w * 0.4 + f * w * 0.8
			c.draw_circle(Vector2(x, at.y - r + drop), r, tint, true, -1.0, true)
		c.draw_rect(Rect2(at.x - w * 0.36, at.y - w * 0.1 + drop, w * 0.72, w * 0.1), tint)


# Drifting particles that wrap around inside region: they sway, twinkle and fade near its top and
# bottom so nothing pops. Stateless: everything follows from the time t.
static func motes(c: CanvasItem, t: float, count: int, region: Rect2, velocity: Vector2,
		size: float, color: Color, sway: float = 12.0) -> void:
	for i in count:
		var speed: float = 0.6 + 0.8 * rnd(i, 3)
		var p := Vector2(rnd(i, 1), rnd(i, 2)) * region.size + velocity * speed * t
		p.x += sin(t * (0.5 + rnd(i, 5)) + i) * sway
		p = Vector2(fposmod(p.x, region.size.x), fposmod(p.y, region.size.y))
		var fade: float = sin(PI * p.y / region.size.y) * sin(PI * p.x / region.size.x)
		var twinkle: float = 0.55 + 0.45 * sin(t * (1.5 + rnd(i, 6) * 2.0) + i * 1.7)
		c.draw_circle(region.position + p, size * (0.6 + 0.8 * rnd(i, 4)),
				Color(color, color.a * fade * twinkle), true, -1.0, true)

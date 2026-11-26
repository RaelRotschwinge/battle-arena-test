# Ferry's backdrop: an open sea with rolling wave crests, a hazy harbor coast, drifting clouds and a
# few gulls. The island is a pier on piles; the moving deck is a little boat hull that leaves a
# wake, sailing between two buoys.
extends RefCounted

const Kit := preload("res://scripts/view/backdrop_kit.gd")
const Decor := preload("res://scripts/view/arena_decor.gd")
const HORIZON := 730.0
const HAZE := Color("8cc5c0")

var arena
var style := {"kind": "dock", "cap": "", "thin": "plank"}
var fog := Color("041824")
var _last_x := -1.0
var _heading := 1.0


func layers() -> Array:
	return [[0.96, false, "sky"], [0.94, true, "clouds"], [0.9, false, "coast"],
			[0.9, true, "waves"], [0.4, true, "gulls"]]


func sky(c: CanvasItem, _t: float) -> void:
	Kit.vgradient(c, [[0.0, Color("0a3350")], [430.0, Color("1d6a83")], [HORIZON, HAZE],
			[HORIZON + 1.0, Color("2b8d95")], [HORIZON + 460.0, Color("08394b")]])
	Kit.glow(c, Vector2(420, 260), 420.0, Color(1.0, 0.97, 0.85, 0.18))


func clouds(c: CanvasItem, t: float) -> void:
	for i in 7:
		var w: float = 150.0 + 150.0 * Kit.rnd(i, 1)
		var x: float = fposmod(Kit.rnd(i, 2) * 3800.0 + t * (5.0 + 4.0 * Kit.rnd(i, 3)), 3800.0)
		var y: float = 150.0 + 380.0 * Kit.rnd(i, 4)
		var sky := Color("0a3350").lerp(Color("1d6a83"), clampf(y / 430.0, 0.0, 1.0))
		var tint := Color("dff0ee").lerp(sky, 0.45)
		Kit.cloud(c, Vector2(x - 900.0, y), w, tint, tint.lerp(sky, 0.35), i)


func coast(c: CanvasItem, _t: float) -> void:
	var land := Color("4c9696")
	var left := Kit.ridge(-2600.0, 620.0, 20.0, func(x: float) -> float:
		var taper := smoothstep(620.0, 380.0, x)  # The coast runs out low into the sea.
		return HORIZON - (24.0 + 46.0 * clampf((620.0 - x) / 600.0, 0.0, 1.0)
				+ 10.0 * sin(x * 0.013)) * taper)
	Kit.fill_below(c, left, HORIZON, land, land.lerp(HAZE, 0.35))
	var right := Kit.ridge(1380.0, 4520.0, 20.0, func(x: float) -> float:
		var taper := smoothstep(1380.0, 1560.0, x)
		return HORIZON - (22.0 + 60.0 * clampf((x - 1380.0) / 600.0, 0.0, 1.0)
				+ 8.0 * sin(x * 0.017)) * taper)
	Kit.fill_below(c, right, HORIZON, land, land.lerp(HAZE, 0.35))
	for i in 9:  # A harbor town: small houses on the shore.
		var x: float = 1540.0 + i * 42.0 + 14.0 * Kit.rnd(i, 7)
		var h: float = 14.0 + 12.0 * Kit.rnd(i, 8)
		var y: float = HORIZON - 26.0 - 30.0 * clampf((x - 1380.0) / 600.0, 0.0, 1.0)
		c.draw_rect(Rect2(x, y - h, 24.0, h), Color("b8dcd6"))
		c.draw_colored_polygon(PackedVector2Array([Vector2(x - 3, y - h), Vector2(x + 27, y - h),
				Vector2(x + 12, y - h - 10)]), Color("6fa8a8"))
	Kit.band(c, Rect2(-2600, HORIZON - 60.0, 7120, 60.0), Color(HAZE, 0.0), Color(HAZE, 0.5))


# Rows of wave crests, closer and bigger toward the bottom, rolling slowly. Each row is one
# draw call (its crests as line segments): about 270 separate arcs cost a whole frame.
func waves(c: CanvasItem, t: float) -> void:
	for row in 9:
		var f := row / 8.0
		var y: float = HORIZON + 8.0 + pow(f, 1.6) * 430.0
		var gap: float = 70.0 + f * 120.0
		var w: float = 14.0 + f * 40.0
		var shift: float = fposmod(t * (8.0 + f * 22.0) + row * 37.0, gap)
		var x: float = -700.0 + shift
		var k := 0
		var lines := PackedVector2Array()
		while x < 2620.0:
			var bob: float = 3.0 * sin(t * 1.4 + k * 0.9 + row)
			var middle := Vector2(x, y + bob + w * 0.5)
			var last := middle + Vector2.from_angle(PI * 1.2) * w * 0.6
			for n in range(1, 5):
				var next := middle + Vector2.from_angle(PI * (1.2 + 0.15 * n)) * w * 0.6
				lines.append(last)
				lines.append(next)
				last = next
			x += gap * (0.8 + 0.4 * Kit.rnd(k, row))
			k += 1
		# No extra antialiasing: the 2x supersampling smooths them, and it would double the cost.
		c.draw_multiline(lines, Color(0.9, 1.0, 1.0, 0.16 + 0.14 * f), 2.0 + f * 2.5)


func gulls(c: CanvasItem, t: float) -> void:
	for i in 3:
		var x: float = fposmod(Kit.rnd(i, 1) * 3000.0 + t * (40.0 + 15.0 * i), 3000.0) - 500.0
		var at := Vector2(x, 260.0 + 140.0 * i + 20.0 * sin(t * 0.6 + i))
		var flap: float = 8.0 * sin(t * 5.0 + i * 2.0)
		var wing := Color("e8f4f4", 0.8)
		c.draw_polyline(PackedVector2Array([at + Vector2(-16, -flap), at + Vector2(-6, -2), at,
				at + Vector2(6, -2), at + Vector2(16, -flap)]), wing, 3.0, true)


# Piles under the pier, fading into the deep.
func stage_back(c: CanvasItem, _t: float) -> void:
	var pier: Rect2 = arena.solids[0]
	var wood := Color("5b6f7d")
	var x := pier.position.x + 40.0
	while x < pier.end.x - 20.0:
		c.draw_rect(Rect2(x - 14.0, pier.end.y - 10.0, 28.0, 420.0), wood)
		c.draw_rect(Rect2(x - 14.0, pier.end.y - 10.0, 8.0, 420.0), wood.lightened(0.12))
		c.draw_rect(Rect2(x - 14.0, pier.end.y - 10.0, 28.0, 420.0), Kit.OUTLINE, false, 3.0)
		x += 130.0
	var buoy: Color = arena.colors["moving"]
	for path in arena.paths:  # A dotted wake line between two buoys marks the way.
		var a: Vector2 = path["a"] + Vector2(-arena.WIDTH / 2.0 - 30.0, 40.0)
		var b: Vector2 = path["b"] + Vector2(arena.WIDTH / 2.0 + 30.0, 40.0)
		var dot := a.x
		while dot < b.x:
			c.draw_circle(Vector2(dot, a.y), 3.0, Color(1, 1, 1, 0.22), true, -1.0, true)
			dot += 26.0
		for end in [a, b]:
			c.draw_circle(end, 11.0, buoy, true, -1.0, true)
			c.draw_rect(Rect2(end.x - 11.0, end.y - 3.0, 22.0, 6.0), Color("f4f1de"))
			c.draw_circle(end, 11.0, Kit.OUTLINE, false, 3.0, true)


# Front of the pier: a few old tires hung as fenders.
func stage_front(c: CanvasItem, _t: float) -> void:
	var pier: Rect2 = arena.solids[0]
	for f in [0.18, 0.5, 0.82]:
		var at := Vector2(lerpf(pier.position.x, pier.end.x, f), pier.position.y + 48.0)
		c.draw_circle(at, 14.0, Color("3a3d44"), false, 8.0, true)
		c.draw_arc(at, 14.0, PI * 1.1, PI * 1.6, 8, Color("5c606a"), 3.0, true)


# The moving deck: a boat hull under the platform, with portholes and a wake behind it.
func mover(c: CanvasItem, r: Rect2) -> void:
	if _last_x >= 0.0 and absf(r.position.x - _last_x) > 0.01:
		_heading = signf(r.position.x - _last_x)
	_last_x = r.position.x
	var red: Color = arena.colors["moving"]
	var hull := PackedVector2Array([Vector2(r.position.x - 6.0, r.end.y - 2.0),
			Vector2(r.end.x + 6.0, r.end.y - 2.0), Vector2(r.end.x - 26.0, r.end.y + 40.0),
			Vector2(r.position.x + 26.0, r.end.y + 40.0)])
	var stern: float = r.position.x + 20.0 if _heading > 0.0 else r.end.x - 20.0
	for i in 4:  # The wake: puffs trailing off the stern.
		var at := Vector2(stern - _heading * (18.0 + i * 22.0), r.end.y + 34.0 + i * 3.0)
		c.draw_circle(at, 9.0 - i * 1.6, Color(1, 1, 1, 0.35 - i * 0.07), true, -1.0, true)
	c.draw_colored_polygon(hull, Color("f4f1de"))
	c.draw_colored_polygon(PackedVector2Array([hull[0] + Vector2(0, 16), hull[1] + Vector2(0, 16),
			hull[2], hull[3]]), red.darkened(0.25))
	c.draw_polyline(hull + PackedVector2Array([hull[0]]), Kit.OUTLINE, 3.0, true)
	for f in [0.3, 0.5, 0.7]:
		var at := Vector2(lerpf(r.position.x, r.end.x, f), r.end.y + 9.0)
		c.draw_circle(at, 4.5, Color("2b5f74"), true, -1.0, true)
		c.draw_circle(at, 4.5, Kit.OUTLINE, false, 2.0, true)
	Decor.thin(c, r, red, "plank")

# Flatiron's backdrop: a sleek violet dusk with a glowing horizon and a low banded sun, flat-topped
# mesas in two rows with lit and shaded faces, a faint perspective grid on the plain and slow
# rising sparks. The stage is a faceted slab with a glowing lip.
extends RefCounted

const Kit := preload("res://scripts/view/backdrop_kit.gd")
const HORIZON := 740.0
const SUN := Vector2(960.0, 715.0)
const HAZE := Color("8a4f9e")

var arena
var style := {"kind": "slab", "cap": "glow", "accent": Color("a68cff"), "thin": "glass"}
var fog := Color("07050f")


func layers() -> Array:
	return [[0.96, false, "sky"], [0.85, false, "far_mesas"], [0.62, false, "near_mesas"],
			[0.3, true, "sparks"]]


func sky(c: CanvasItem, _t: float) -> void:
	Kit.vgradient(c, [[0.0, Color("0d0b16")], [320.0, Color("221a4d")], [600.0, Color("4a2f86")],
			[HORIZON, Color("b05a8e")], [HORIZON + 1.0, Color("2a1a48")],
			[HORIZON + 400.0, Color("0d0a1c")]])
	Kit.stars(c, 70, Rect2(-500, -500, 2920, 1000), Color("e2d8ff"), 3)
	Kit.glow(c, SUN, 640.0, Color(1.0, 0.45, 0.7, 0.3), 0.45)
	# The sun sinking behind the plain, cut by thin bands of sky.
	var sun := Color("f08ab4")
	var points := PackedVector2Array()
	for i in 33:
		var a := PI + PI * i / 32.0
		points.append(SUN + Vector2(cos(a), sin(a)) * 150.0)
	c.draw_colored_polygon(points, Color(sun, 0.7))
	c.draw_polyline(points, Color(sun, 0.7), 2.0, true)
	for k in 5:
		var y: float = SUN.y - 12.0 - k * 22.0
		c.draw_rect(Rect2(SUN.x - 160.0, y, 320.0, 6.0 - k), Color("7a3f8a"))
	# The plain: lines toward a vanishing point on the horizon.
	for i in range(-14, 15):
		var bottom := Vector2(SUN.x + i * 260.0, HORIZON + 600.0)
		c.draw_line(Vector2(SUN.x + i * 14.0, HORIZON + 2.0), bottom, Color("9a6ad0", 0.1), 2.0,
				true)
	for k in 7:
		var y: float = HORIZON + 6.0 + pow(k / 6.0, 2.0) * 420.0
		c.draw_line(Vector2(-2600, y), Vector2(4520, y), Color("9a6ad0", 0.08), 2.0)


# Flat-topped mesas from [left x, top width, height]: steep sides, one lit face.
func _mesas(c: CanvasItem, list: Array, lit: Color, shade: Color, base: float) -> void:
	for m: Array in list:
		var x: float = m[0]
		var w: float = m[1]
		var h: float = m[2]
		var slope: float = h * 0.35
		var top_y: float = base - h
		var body := PackedVector2Array([Vector2(x - slope, base), Vector2(x, top_y),
				Vector2(x + w, top_y), Vector2(x + w + slope, base)])
		c.draw_colored_polygon(body, shade)
		c.draw_polyline(body, shade, 2.0, true)
		Kit.band(c, Rect2(x - slope, base, w + slope * 2.0, 500.0), shade, Color(shade, 0.0))
		c.draw_colored_polygon(PackedVector2Array([Vector2(x - slope, base), Vector2(x, top_y),
				Vector2(x + w * 0.45, top_y), Vector2(x + w * 0.3, base)]), lit)
		c.draw_line(Vector2(x, top_y), Vector2(x + w, top_y), lit.lightened(0.25), 3.0, true)


func far_mesas(c: CanvasItem, _t: float) -> void:
	_mesas(c, [[-700.0, 380.0, 120.0], [-120.0, 220.0, 80.0], [1380.0, 300.0, 140.0],
			[1900.0, 180.0, 70.0], [2350.0, 420.0, 110.0]], Color("51357f"), Color("3a2768"),
			HORIZON + 2.0)
	Kit.band(c, Rect2(-2600, HORIZON - 90.0, 7120, 92.0), Color(HAZE, 0.0), Color(HAZE, 0.35))


func near_mesas(c: CanvasItem, _t: float) -> void:
	_mesas(c, [[-900.0, 420.0, 240.0], [60.0, 160.0, 150.0], [1720.0, 260.0, 210.0],
			[2500.0, 340.0, 260.0]], Color("342263"), Color("221745"), HORIZON + 40.0)


func sparks(c: CanvasItem, t: float) -> void:
	Kit.motes(c, t, 20, Rect2(150, 200, 1620, 760), Vector2(3.0, -14.0), 2.2,
			Color(0.8, 0.7, 1.0, 0.55), 10.0)

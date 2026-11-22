# Terraces' backdrop: a warm sunset behind layered hills, the middle ones stepped into terraced
# fields, cypresses on the near ridge and warm dust in the air. The stage is earth with grass.
extends RefCounted

const Kit := preload("res://scripts/view/backdrop_kit.gd")
const HORIZON := 740.0
const SUN := Vector2(700.0, 650.0)
const GLOW := Color("e8a87c")

var arena
var style := {"kind": "earth", "cap": "grass", "accent": Color("9c9a4c"), "thin": "plank"}
var fog := Color("12080f")


func layers() -> Array:
	return [[0.96, false, "sky"], [0.88, false, "far_hills"], [0.7, false, "fields"],
			[0.5, false, "near_hills"], [0.25, true, "dust"]]


func sky(c: CanvasItem, _t: float) -> void:
	Kit.vgradient(c, [[0.0, Color("241827")], [300.0, Color("4e2a45")], [540.0, Color("a8565e")],
			[HORIZON, GLOW]])
	Kit.glow(c, SUN, 520.0, Color(1.0, 0.78, 0.5, 0.35))
	c.draw_circle(SUN, 110.0, Color("f6c58e"), true, -1.0, true)
	for streak in [[Vector2(1350, 360), 260.0], [Vector2(1600, 420), 160.0],
			[Vector2(300, 300), 220.0], [Vector2(560, 470), 180.0], [Vector2(1250, 540), 200.0]]:
		Kit.glow(c, streak[0], streak[1], Color(1.0, 0.62, 0.55, 0.4), 0.07)


func far_hills(c: CanvasItem, _t: float) -> void:
	var edge := Kit.ridge(-2600.0, 4520.0, 24.0, func(x: float) -> float:
		return HORIZON - 70.0 - 45.0 * sin(x * 0.0035 + 0.6) - 22.0 * sin(x * 0.011))
	Kit.fill_below(c, edge, 3600.0, Color("b0676c"), Color("8d4e5e"))


# Hills stepped into fields: their outline repeated lower and lower, each step a lit lip.
func fields(c: CanvasItem, _t: float) -> void:
	var height := func(x: float) -> float:
		return HORIZON + 10.0 - 90.0 * sin(x * 0.0026 - 0.4) - 30.0 * sin(x * 0.0071 + 2.0)
	var base := Color("7c4256")
	Kit.fill_below(c, Kit.ridge(-2600.0, 4520.0, 24.0, height), 3600.0, base, Color("5a2f45"))
	for k in range(1, 8):
		var step := Kit.ridge(-2600.0, 4520.0, 24.0, func(x: float) -> float:
			return height.call(x) + k * 26.0 + k * k * 2.0)
		var shade := PackedVector2Array()
		for p in step:
			shade.append(p + Vector2(0, 4))
		c.draw_polyline(shade, Color("5a2f45", 0.6), 3.0, true)
		c.draw_polyline(step, Color("b07082", 0.7 - k * 0.06), 3.0, true)


func near_hills(c: CanvasItem, _t: float) -> void:
	var height := func(x: float) -> float:
		return HORIZON + 60.0 - 60.0 * sin(x * 0.0019 + 1.1) - 25.0 * sin(x * 0.006)
	var dark := Color("43233a")
	Kit.fill_below(c, Kit.ridge(-2600.0, 4520.0, 24.0, height), 3600.0, dark, Color("2a1527"))
	for i in 14:  # Cypresses standing on the ridge.
		var x: float = -900.0 + i * 270.0 + 90.0 * Kit.rnd(i, 5)
		var h: float = 70.0 + 50.0 * Kit.rnd(i, 6)
		var y: float = height.call(x) + 6.0
		var w: float = h * 0.13
		var tree := PackedVector2Array([Vector2(x - w, y), Vector2(x - w, y - h * 0.4),
				Vector2(x - w * 0.6, y - h * 0.8), Vector2(x, y - h), Vector2(x + w * 0.6, y - h * 0.8),
				Vector2(x + w, y - h * 0.4), Vector2(x + w, y)])
		c.draw_colored_polygon(tree, dark)
		c.draw_polyline(tree, dark, 1.5, true)


func dust(c: CanvasItem, t: float) -> void:
	Kit.motes(c, t, 26, Rect2(100, 200, 1720, 760), Vector2(10.0, -4.0), 2.2,
			Color(1.0, 0.82, 0.6, 0.45), 18.0)

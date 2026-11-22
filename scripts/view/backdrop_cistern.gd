# Cistern's backdrop: an underground hall. Far arches in the dark, a near arcade of stone pillars,
# pale light falling in shafts from above, water dripping into a still pool that ripples, dust in
# the light. The stage is mossy brick.
extends RefCounted

const Kit := preload("res://scripts/view/backdrop_kit.gd")
const POOL := 1060.0  # The water line of the pool below the stage.
const WALL := Color("143029")
const DRIPS := [380.0, 1240.0, 1650.0, 820.0]

var arena
var style := {"kind": "bricks", "cap": "moss", "accent": Color("5a9467"), "thin": "stone"}
var fog := Color("030907")


func layers() -> Array:
	return [[0.95, false, "deep"], [0.75, false, "arcade"], [0.75, true, "pool"],
			[0.5, true, "light"]]


# The far end of the hall: darkness with a row of faint small arches.
func deep(c: CanvasItem, _t: float) -> void:
	Kit.vgradient(c, [[0.0, Color("040c0a")], [700.0, Color("0b201b")], [POOL, Color("113229")]])
	_arches(c, -1200.0, 3200.0, 260.0, 620.0, 40.0, Color("0e2620"))


# Stone with arched openings: pillars of width pillar every bay from x0 to x1, the arches
# springing at spring_y. Only the stone is drawn; the layers behind show through the openings.
func _arches(c: CanvasItem, x0: float, x1: float, bay: float, spring_y: float, pillar: float,
		stone: Color) -> void:
	var x := x0
	while x < x1:
		var a := x + pillar / 2.0
		var b := x + bay - pillar / 2.0
		var r := (b - a) / 2.0
		var arch := PackedVector2Array()
		for i in 17:
			var ang := -PI * i / 16.0
			arch.append(Vector2(a + r + cos(ang) * r, spring_y + sin(ang) * r))
		var spandrel := PackedVector2Array([Vector2(x, -2400.0), Vector2(x + bay, -2400.0),
				Vector2(x + bay, spring_y)]) + arch + PackedVector2Array([Vector2(x, spring_y)])
		c.draw_colored_polygon(spandrel, stone)
		c.draw_rect(Rect2(x - 1.0, spring_y, a - x + 1.0, 4000.0), stone)
		c.draw_rect(Rect2(b, spring_y, x + bay - b + 1.0, 4000.0), stone)
		c.draw_polyline(arch, stone.lightened(0.12), 3.0, true)
		c.draw_rect(Rect2(a - 6.0, spring_y - 8.0, 14.0, 10.0), stone.lightened(0.1))
		c.draw_rect(Rect2(b - 8.0, spring_y - 8.0, 14.0, 10.0), stone.lightened(0.1))
		x += bay


func arcade(c: CanvasItem, _t: float) -> void:
	var x := -1400.0
	var bay := 560.0
	var spring_y := 470.0
	_arches(c, x, 3400.0, bay, spring_y, 110.0, WALL)
	# The pillars' masonry and moss running down from the springs.
	while x < 3400.0:
		for k in 30:
			var y := -400.0 + k * 52.0
			c.draw_line(Vector2(x - 55.0, y), Vector2(x + 55.0, y), WALL.darkened(0.25), 2.0)
		var bay_i := int((x + 1400.0) / bay)
		for i in 2:
			var mx: float = x - 45.0 + 90.0 * Kit.rnd(bay_i, i + 1)
			var long: float = 40.0 + 200.0 * Kit.rnd(bay_i, i + 4)
			c.draw_line(Vector2(mx, spring_y - 30.0), Vector2(mx, spring_y + long),
					Color("2a5a3e", 0.45), 5.0, true)
		x += bay
	Kit.band(c, Rect2(-2600, 900.0, 7120, POOL - 900.0), Color(WALL, 0.0), Color("0b1d18"))


# The pool: a dark mirror with slow light lines and the rings of the drips.
func pool(c: CanvasItem, t: float) -> void:
	Kit.band(c, Rect2(-2600, POOL, 7120, 500.0), Color("1a4a3c"), Color("06130f"))
	c.draw_rect(Rect2(-2600, POOL + 500.0, 7120, 3000.0), Color("06130f"))
	for i in 18:
		var y: float = POOL + 8.0 + pow(Kit.rnd(i, 2), 1.5) * 200.0
		var x: float = -400.0 + fposmod(Kit.rnd(i, 1) * 2800.0 + t * 6.0, 2800.0)
		c.draw_line(Vector2(x, y), Vector2(x + 40.0, y), Color(0.6, 1.0, 0.85, 0.08 + 0.06 *
				sin(t + i)), 2.0, true)
	for d in DRIPS.size():  # Each drip falls on its own clock and rings out on the water.
		var period: float = 2.6 + d * 0.7
		var phase: float = fposmod(t + d * 1.3, period)
		var x: float = DRIPS[d]
		var fall := 1.1
		if phase < fall:
			var y: float = 120.0 + (POOL - 120.0) * pow(phase / fall, 2.0)
			c.draw_line(Vector2(x, y - 10.0), Vector2(x, y), Color(0.7, 1.0, 0.9, 0.35), 3.0, true)
		else:
			var grow: float = (phase - fall) / (period - fall)
			c.draw_set_transform(Vector2(x, POOL + 6.0), 0.0, Vector2(1.0, 0.25))  # Flat rings.
			for ring in 2:
				var r: float = 8.0 + (grow * 90.0) * (1.0 - ring * 0.4)
				var a: float = 0.35 * (1.0 - grow)
				c.draw_arc(Vector2.ZERO, r, 0.0, TAU, 24, Color(0.7, 1.0, 0.9, a), 4.0, true)
			c.draw_set_transform(Vector2.ZERO)


# Shafts of pale light from openings in the vault, with dust turning in them.
func light(c: CanvasItem, t: float) -> void:
	for s in [[520.0, 0.9], [1340.0, 1.0], [2100.0, 0.8], [-300.0, 0.7]]:
		var x: float = s[0]
		var a: float = 0.07 * s[1] * (0.85 + 0.15 * sin(t * 0.4 + x))
		c.draw_polygon(PackedVector2Array([Vector2(x - 40.0, -200.0), Vector2(x + 60.0, -200.0),
				Vector2(x + 330.0, 1100.0), Vector2(x + 90.0, 1100.0)]), PackedColorArray([
				Color(0.75, 1.0, 0.9, a), Color(0.75, 1.0, 0.9, a), Color(0.75, 1.0, 0.9, 0.0),
				Color(0.75, 1.0, 0.9, 0.0)]))
	Kit.motes(c, t, 24, Rect2(250, 100, 1500, 900), Vector2(4.0, 6.0), 2.0,
			Color(0.8, 1.0, 0.9, 0.4), 16.0)

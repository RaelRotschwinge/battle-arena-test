# Kettle's backdrop: a hot stove room. A dark tiled wall lit from the fire below, copper pipes
# with flanges, valves and a gauge, steam leaking from the valves, embers rising. The stage is a
# riveted iron cooktop with a hot lip; its vents are drawn here too (stage_front): a grate that
# glows, shimmers and puffs ever faster before the burst, the danger column lit from below, then a
# billowing column of steam.
extends RefCounted

const Kit := preload("res://scripts/view/backdrop_kit.gd")
const COPPER := Color("6e3022")
const LEAKS := [Vector2(560, 236), Vector2(1500, 236), Vector2(150, 640)]

var arena
var style := {"kind": "iron", "cap": "glow", "accent": Color("ffb35c"), "thin": "grill"}
var fog := Color("0c0204")


func layers() -> Array:
	return [[0.94, false, "wall"], [0.7, false, "pipes"], [0.7, true, "leaks"],
			[0.3, true, "embers"]]


func wall(c: CanvasItem, _t: float) -> void:
	Kit.vgradient(c, [[0.0, Color("1a0508")], [480.0, Color("350a12")], [960.0, Color("4e1016")]])
	var line := Color("12030555")
	for k in range(-8, 20):
		c.draw_line(Vector2(-2600, k * 90.0), Vector2(4520, k * 90.0), line, 3.0)
	for k in range(-30, 50):
		c.draw_line(Vector2(k * 90.0, -2400), Vector2(k * 90.0, 3600), line, 3.0)
	Kit.glow(c, Vector2(960, 1150), 1100.0, Color(1.0, 0.45, 0.15, 0.28), 0.5)


# A copper pipe from a to b (straight, horizontal or vertical), with a lit side and flanges.
func _pipe(c: CanvasItem, a: Vector2, b: Vector2, r: float) -> void:
	c.draw_line(a, b, COPPER, r * 2.0)
	var along := (b - a).normalized()
	var side := along.orthogonal() * r * 0.45
	c.draw_line(a - side, b - side, COPPER.lightened(0.2), r * 0.5)
	c.draw_line(a + side * 1.6, b + side * 1.6, COPPER.darkened(0.3), r * 0.3)
	var n := int(a.distance_to(b) / 320.0)
	for i in n + 1:
		var at := a + along * (i * 320.0 + 80.0)
		if at.distance_to(a) > a.distance_to(b):
			break
		c.draw_line(at - along * 9.0, at + along * 9.0, COPPER.lightened(0.1), r * 2.6)


func pipes(c: CanvasItem, _t: float) -> void:
	_pipe(c, Vector2(-2600, 220), Vector2(4520, 220), 20.0)
	_pipe(c, Vector2(-2600, 300), Vector2(4520, 300), 11.0)
	for x in [150.0, 1780.0, -420.0, 2350.0]:
		_pipe(c, Vector2(x, 220), Vector2(x, 3600), 16.0)
	for v in [Vector2(560, 220), Vector2(1500, 220)]:  # Valve wheels on the big pipe.
		c.draw_line(v, v + Vector2(0, 30), COPPER.darkened(0.2), 8.0)
		c.draw_arc(v + Vector2(0, 34), 18.0, 0.0, TAU, 20, Color("8a4a2e"), 5.0, true)
		c.draw_line(v + Vector2(-18, 34), v + Vector2(18, 34), Color("8a4a2e"), 4.0)
	var gauge := Vector2(1780, 560)
	c.draw_circle(gauge, 34.0, COPPER.lightened(0.1), true, -1.0, true)
	c.draw_circle(gauge, 26.0, Color("b89a80"), true, -1.0, true)
	c.draw_line(gauge, gauge + Vector2.from_angle(-0.6) * 20.0, Color("4a1010"), 3.0, true)


func leaks(c: CanvasItem, t: float) -> void:
	for l in LEAKS.size():
		var at: Vector2 = LEAKS[l]
		for k in 4:
			var life: float = fposmod(t * 0.35 + k * 0.25 + l * 0.37, 1.0)
			var p := at + Vector2(18.0 * life + 8.0 * sin(t + k), -90.0 * life)
			c.draw_circle(p, 10.0 + 26.0 * life, Color(1, 0.92, 0.9, 0.16 * (1.0 - life)), true,
					-1.0, true)


func embers(c: CanvasItem, t: float) -> void:
	Kit.motes(c, t, 26, Rect2(100, 150, 1720, 900), Vector2(6.0, -32.0), 2.2,
			Color(1.0, 0.6, 0.2, 0.85), 14.0)


func stage_front(c: CanvasItem, _t: float) -> void:
	var vent: Color = arena.colors.get("vent", Color.ORANGE)
	var steam: Color = arena.colors.get("steam", Color.WHITE)
	for v in arena.VENTS.size():
		_vent(c, arena.vent_column(v), arena.vent_phase(v), vent, steam)


func _vent(c: CanvasItem, column: Rect2, phase: Array, vent: Color, steam: Color) -> void:
	var cx: float = column.get_center().x
	var floor_y: float = column.end.y
	var ticks: float = phase[1]
	var heat := 0.0
	match phase[0]:
		"warn":  # Ever brighter and faster toward the burst.
			var near: float = ticks / float(arena.BURST_FROM - arena.WARN_FROM)
			heat = (0.35 + 0.65 * near) * (0.7 + 0.3 * sin(ticks * (0.25 + near * 0.5)))
			Kit.band(c, Rect2(column.position.x, column.position.y, column.size.x,
					column.size.y), Color(vent, 0.0), Color(vent, 0.3 * near + 0.05))
			for side in [column.position.x, column.end.x]:
				c.draw_line(Vector2(side, floor_y), Vector2(side, floor_y - column.size.y * near),
						Color(vent, 0.45 * near), 3.0, true)
			for k in 3:  # Heat shimmer rising from the grate.
				var wave := PackedVector2Array()
				var x0: float = cx + (k - 1) * 36.0
				for j in 10:
					var y: float = floor_y - 8.0 - j * 16.0 * (0.4 + near)
					wave.append(Vector2(x0 + 6.0 * sin(y * 0.09 + ticks * 0.5 + k), y))
				c.draw_polyline(wave, Color(1.0, 0.8, 0.5, 0.3), 2.0, true)
			for k in 4:  # Puffs that rise higher as the burst comes closer.
				var life: float = fposmod(ticks * (0.02 + near * 0.03) + k * 0.25, 1.0)
				var p := Vector2(cx + (k - 1.5) * 30.0, floor_y - 12.0 - life * 120.0 * (0.4 + near))
				c.draw_circle(p, 10.0 + 14.0 * life, Color(steam, 0.4 * (1.0 - life)), true, -1.0, true)
		"burst":
			heat = 1.0
			_burst(c, column, ticks, steam)
		"idle":
			heat = 0.12
			var life: float = fposmod(ticks / 70.0, 1.0)
			c.draw_circle(Vector2(cx, floor_y - 12.0 - life * 40.0), 6.0 + 8.0 * life,
					Color(steam, 0.18 * (1.0 - life)), true, -1.0, true)
	# The grate: a recess with bars, glowing from the heat below.
	var grate := Rect2(cx - 66.0, floor_y + 1.0, 132.0, 13.0)
	if heat > 0.0:
		Kit.glow(c, Vector2(cx, floor_y), 150.0, Color(vent, 0.6 * heat), 0.35)
	c.draw_rect(grate, Color("1a1010").lerp(vent, heat * 0.9))
	var x := grate.position.x + 8.0
	while x < grate.end.x - 6.0:
		c.draw_rect(Rect2(x, grate.position.y, 6.0, grate.size.y), Color("4a3a36").lerp(
				vent.lightened(0.4), heat * 0.5))
		x += 14.0
	c.draw_rect(grate, Kit.OUTLINE, false, 3.0)


# The burst: a column of steam, densest in the middle, puffs rolling up its sides and billowing
# over the top.
func _burst(c: CanvasItem, column: Rect2, ticks: float, steam: Color) -> void:
	var wobble := 6.0 * sin(ticks * 0.9)
	var body := column.grow_individual(wobble, 0.0, -wobble, 0.0)
	Kit.band(c, body, Color(steam, 0.5), Color(steam, 0.75))
	Kit.band(c, body.grow_individual(-34.0, 0.0, -34.0, 0.0), Color(1, 1, 1, 0.45),
			Color(1, 1, 1, 0.8))
	for k in 10:
		var rise: float = fposmod(ticks * 16.0 + k * 44.0, column.size.y)
		var side: float = column.position.x if k % 2 == 0 else column.end.x
		var at := Vector2(side + (6.0 if k % 2 == 0 else -6.0) * sin(ticks * 0.3 + k),
				column.end.y - rise)
		c.draw_circle(at, 24.0 + 10.0 * Kit.rnd(k, 1), Color(steam, 0.55), true, -1.0, true)
	for k in 5:
		var at := Vector2(column.position.x + column.size.x * (k + 0.5) / 5.0,
				column.position.y + 6.0 * sin(ticks * 0.5 + k))
		c.draw_circle(at, 32.0 + 8.0 * sin(ticks * 0.4 + k * 1.3), Color(steam, 0.7), true, -1.0,
				true)

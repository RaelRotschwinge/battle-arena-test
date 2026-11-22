# Pebble's backdrop: a calm night sea under the moon, distant islets with a lighthouse, fireflies
# around the island. The stage is a stony island with a grassy top.
extends RefCounted

const Kit := preload("res://scripts/view/backdrop_kit.gd")
const HORIZON := 730.0
const MOON := Vector2(1440.0, 250.0)
const HAZE := Color("3d5878")
const LIGHT := Vector2(1830.0, HORIZON - 182.0)  # The lighthouse lamp.

var arena
var style := {"kind": "rock", "cap": "grass", "accent": Color("86a878"), "thin": "stone"}
var fog := Color("060a13")


func layers() -> Array:
	return [[0.96, false, "sky"], [0.96, true, "shimmer"], [0.92, false, "islets"],
			[0.92, true, "lamp"],
			[0.25, true, "fireflies"]]


func sky(c: CanvasItem, _t: float) -> void:
	Kit.vgradient(c, [[0.0, Color("0b1322")], [420.0, Color("1b2a41")], [HORIZON, HAZE],
			[HORIZON + 1.0, Color("24405e")], [HORIZON + 420.0, Color("0d1829")]])
	Kit.stars(c, 90, Rect2(-500, -500, 2920, 1150), Color("d4dcec"), 1)
	Kit.glow(c, MOON, 300.0, Color(0.7, 0.8, 0.95, 0.22))
	c.draw_circle(MOON, 56.0, Color("dde5ee"), true, -1.0, true)
	for spot in [[Vector2(-16, -12), 14.0], [Vector2(18, 10), 10.0], [Vector2(-6, 22), 8.0]]:
		c.draw_circle(MOON + spot[0], spot[1], Color("c5cfdc"), true, -1.0, true)
	Kit.glow(c, Vector2(MOON.x, HORIZON + 10.0), 520.0, Color(0.6, 0.72, 0.9, 0.12), 0.25)


# The moon's path on the water and slow glints elsewhere.
func shimmer(c: CanvasItem, t: float) -> void:
	for i in 24:
		var f := i / 24.0
		var y: float = HORIZON + 6.0 + pow(f, 1.5) * 380.0
		var w: float = (30.0 + f * 160.0) * (0.55 + 0.45 * sin(t * 1.1 + i * 1.9))
		var x: float = MOON.x + sin(t * 0.7 + i * 2.3) * (8.0 + f * 30.0)
		c.draw_line(Vector2(x - w / 2.0, y), Vector2(x + w / 2.0, y),
				Color(0.85, 0.9, 1.0, 0.4 * (1.0 - f) + 0.08), 2.0 + f * 2.0, true)
	for i in 40:
		var f: float = Kit.rnd(i, 3)
		var y: float = HORIZON + 10.0 + pow(f, 1.4) * 400.0
		var x: float = fposmod(Kit.rnd(i, 4) * 3400.0 + t * (6.0 + 10.0 * f), 3400.0) - 740.0
		var a: float = 0.12 * (0.5 + 0.5 * sin(t * 1.3 + i))
		c.draw_line(Vector2(x, y), Vector2(x + 20.0 + 30.0 * f, y), Color(0.8, 0.88, 1.0, a),
				2.0, true)


func islets(c: CanvasItem, _t: float) -> void:
	var rock := Color("1b2c45")
	for isle in [[-260.0, 420.0, 70.0], [380.0, 160.0, 30.0], [1620.0, 520.0, 95.0],
			[2500.0, 300.0, 50.0]]:
		var x0: float = isle[0]
		var w: float = isle[1]
		var h: float = isle[2]
		var edge := Kit.ridge(x0, x0 + w, 12.0, func(x: float) -> float:
			var f := (x - x0) / w
			return HORIZON - h * pow(maxf(sin(PI * f), 0.0), 0.7) * (0.85 + 0.15 * sin(x * 0.05)))
		Kit.fill_below(c, edge, HORIZON, rock, rock.lerp(HAZE, 0.25))
		Kit.glow(c, Vector2(x0 + w / 2.0, HORIZON + 2.0), w * 0.5, Color(rock, 0.7), 0.08)
	# The lighthouse on the big islet.
	c.draw_colored_polygon(PackedVector2Array([LIGHT + Vector2(-14, 94), LIGHT + Vector2(14, 94),
			LIGHT + Vector2(8, 8), LIGHT + Vector2(-8, 8)]), Color("2a3b55"))
	c.draw_rect(Rect2(LIGHT + Vector2(-10, -8), Vector2(20, 16)), Color("2a3b55"))
	Kit.band(c, Rect2(-2600, HORIZON - 70.0, 7120, 70.0), Color(HAZE, 0.0), Color(HAZE, 0.45))


# The lighthouse lamp, breathing slowly.
func lamp(c: CanvasItem, t: float) -> void:
	var beat: float = 0.6 + 0.4 * sin(t * 1.6)
	Kit.glow(c, LIGHT, 90.0, Color(1.0, 0.85, 0.55, 0.35 * beat))
	c.draw_circle(LIGHT, 5.0, Color(1.0, 0.9, 0.65, 0.9), true, -1.0, true)


func fireflies(c: CanvasItem, t: float) -> void:
	Kit.motes(c, t, 22, Rect2(300, 250, 1320, 700), Vector2(5.0, -3.0), 2.6,
			Color(0.85, 0.95, 0.6, 0.75), 24.0)

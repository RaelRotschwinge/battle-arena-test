# Windlass' backdrop: a bright windy sky with drifting clouds, green hills with turning windmills,
# petals on the wind. The lift hangs from a gantry: two posts on the island, a beam with a winch
# drum that turns as the lift moves, chains down to the lift, which has a braced steel frame.
extends RefCounted

const Kit := preload("res://scripts/view/backdrop_kit.gd")
const Decor := preload("res://scripts/view/arena_decor.gd")
const HORIZON := 740.0
const HAZE := Color("c8e0eb")
const BEAM_Y := 300.0
const STEEL := Color("5c4d6b")

var arena
var style := {"kind": "bricks", "cap": "", "thin": "plank"}
var fog := Color("1a1830")


func layers() -> Array:
	return [[0.96, false, "sky"], [0.92, true, "far_clouds"], [0.75, false, "hills"],
			[0.75, true, "mills"], [0.45, true, "near_clouds"], [0.25, true, "petals"]]


func sky(c: CanvasItem, _t: float) -> void:
	Kit.vgradient(c, [[0.0, Color("5b9fca")], [440.0, Color("8cbfdb")], [HORIZON, HAZE],
			[HORIZON + 300.0, Color("b6d3df")]])
	Kit.glow(c, Vector2(1560, 180), 380.0, Color(1.0, 1.0, 0.92, 0.45))
	c.draw_circle(Vector2(1560, 180), 46.0, Color("fffbe8"), true, -1.0, true)


func _drift(c: CanvasItem, t: float, count: int, salt: int, speed: float, scale_w: float,
		alpha: float) -> void:
	for i in count:
		var w: float = (140.0 + 140.0 * Kit.rnd(i, salt)) * scale_w
		var x: float = fposmod(Kit.rnd(i, salt + 1) * 4000.0 + t * speed * (0.7 + 0.6 *
				Kit.rnd(i, salt + 2)), 4000.0) - 1000.0
		var y: float = 130.0 + 420.0 * Kit.rnd(i, salt + 3)
		var sky := Color("5b9fca").lerp(Color("8cbfdb"), clampf(y / 440.0, 0.0, 1.0))
		Kit.cloud(c, Vector2(x, y), w, Color.WHITE.lerp(sky, 1.0 - alpha),
				Color("c9dceb").lerp(sky, 1.0 - alpha), i + salt)


func far_clouds(c: CanvasItem, t: float) -> void:
	_drift(c, t, 8, 10, 7.0, 1.0, 0.75)


func _height(x: float) -> float:
	return HORIZON - 40.0 - 50.0 * sin(x * 0.003 + 0.8) - 18.0 * sin(x * 0.009)


func hills(c: CanvasItem, _t: float) -> void:
	Kit.fill_below(c, Kit.ridge(-2600.0, 4520.0, 24.0, _height), 3600.0, Color("9cc8b4"),
			Color("86b4a6"))
	Kit.band(c, Rect2(-2600, HORIZON - 160.0, 7120, 160.0), Color(HAZE, 0.0), Color(HAZE, 0.4))


func mills(c: CanvasItem, t: float) -> void:
	for m in [[220.0, 1.0], [1620.0, 0.8], [2300.0, 0.9], [-500.0, 0.7]]:
		var x: float = m[0]
		var s: float = m[1]
		var foot := Vector2(x, _height(x) + 4.0)
		var hub := foot + Vector2(0, -110.0 * s)
		var tower := Color("e6eef0")
		c.draw_colored_polygon(PackedVector2Array([foot + Vector2(-14, 0) * s,
				foot + Vector2(14, 0) * s, hub + Vector2(6, 0) * s, hub + Vector2(-6, 0) * s]), tower)
		var turn: float = t * (0.8 + 0.3 * s) + x
		for k in 4:
			var tip := hub + Vector2.from_angle(turn + k * TAU / 4.0) * 62.0 * s
			c.draw_line(hub, tip, Color("f4f8f8"), 5.0 * s, true)
		c.draw_circle(hub, 6.0 * s, Color("b9c6cc"), true, -1.0, true)


# Thin wisps of wind, soft enough to pass behind the fight.
func near_clouds(c: CanvasItem, t: float) -> void:
	for i in 5:
		var x: float = fposmod(Kit.rnd(i, 31) * 4000.0 + t * 30.0 * (0.7 + 0.6 * Kit.rnd(i, 32)),
				4000.0) - 1000.0
		Kit.glow(c, Vector2(x, 180.0 + 500.0 * Kit.rnd(i, 33)), 260.0, Color(1, 1, 1, 0.3), 0.12)


func petals(c: CanvasItem, t: float) -> void:
	Kit.motes(c, t, 18, Rect2(0, 150, 1920, 800), Vector2(38.0, 6.0), 3.0,
			Color(1.0, 0.78, 0.8, 0.8), 26.0)


# The gantry behind the lift: posts on the island, a beam, the winch drum and its chains.
func stage_back(c: CanvasItem, _t: float) -> void:
	var lift: Rect2 = arena.thin[arena.LIFT]
	var ground_y: float = arena.solids[0].position.y
	var mid: float = lift.get_center().x
	var post := Color("8e7f9c").lerp(Color("9dcde6"), 0.35)  # Behind the fight: kept soft.
	for side in [-1.0, 1.0]:
		var x: float = mid + side * (arena.WIDTH / 2.0 + 28.0)
		c.draw_rect(Rect2(x - 7.0, BEAM_Y, 14.0, ground_y - BEAM_Y), post)
		c.draw_rect(Rect2(x - 7.0, BEAM_Y, 4.0, ground_y - BEAM_Y), post.lightened(0.12))
	c.draw_rect(Rect2(mid - arena.WIDTH / 2.0 - 46.0, BEAM_Y - 14.0, arena.WIDTH + 92.0, 18.0), post)
	c.draw_rect(Rect2(mid - arena.WIDTH / 2.0 - 46.0, BEAM_Y - 14.0, arena.WIDTH + 92.0, 18.0),
			Color(Kit.OUTLINE, 0.5), false, 2.0)
	# The drum turns with the lift: chain paid out over its rim.
	var drum := Vector2(mid, BEAM_Y - 36.0)
	var turn: float = lift.position.y / 26.0
	c.draw_circle(drum, 30.0, STEEL, true, -1.0, true)
	c.draw_circle(drum, 30.0, Kit.OUTLINE, false, 3.0, true)
	for k in 6:
		c.draw_line(drum, drum + Vector2.from_angle(turn + k * TAU / 6.0) * 26.0,
				STEEL.lightened(0.35), 3.0, true)
	c.draw_circle(drum, 7.0, Color("ffb703"), true, -1.0, true)
	for side in [-1.0, 1.0]:  # Chains from the beam to the ends of the lift.
		var x: float = mid + side * (arena.WIDTH / 2.0 - 24.0)
		var y := BEAM_Y + 4.0
		var k := 0
		var shift: float = fposmod(lift.position.y, 16.0)
		while y < lift.position.y:
			var link := Rect2(x - (3.0 if k % 2 == 0 else 1.5), y + shift - 16.0, 6.0 if k % 2 == 0
					else 3.0, 12.0)
			if link.position.y > BEAM_Y and link.end.y < lift.position.y + 2.0:
				c.draw_rect(link, Color(STEEL.darkened(0.2), 0.85))
			y += 8.0
			k += 1


# The lift: a yellow deck on a braced steel frame.
func mover(c: CanvasItem, r: Rect2) -> void:
	var frame := Rect2(r.position.x + 10.0, r.end.y - 2.0, r.size.x - 20.0, 26.0)
	c.draw_rect(frame, Color(STEEL, 0.9))
	var cells := 5
	for i in cells:
		var x0: float = frame.position.x + frame.size.x * i / cells
		var x1: float = frame.position.x + frame.size.x * (i + 1) / cells
		c.draw_line(Vector2(x0, frame.position.y), Vector2(x1, frame.end.y), STEEL.lightened(0.3),
				3.0, true)
		c.draw_line(Vector2(x0, frame.end.y), Vector2(x1, frame.position.y), STEEL.lightened(0.3),
				3.0, true)
	c.draw_rect(frame, Kit.OUTLINE, false, 3.0)
	Decor.thin(c, r, arena.colors["moving"], "plank")
	for side in [-1.0, 1.0]:  # Shackles where the chains hold.
		var at := Vector2(r.get_center().x + side * (arena.WIDTH / 2.0 - 24.0), r.position.y + 8.0)
		c.draw_circle(at, 6.0, STEEL.lightened(0.2), true, -1.0, true)
		c.draw_circle(at, 6.0, Kit.OUTLINE, false, 2.0, true)

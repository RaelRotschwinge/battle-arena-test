# Short effects in the arena (game design, "Hit feel"), flat vector shapes: a star burst, speed
# lines and an impact ring where a hit lands (bigger and longer for stronger launches), a beam from
# the screen edge where a fighter leaves the blast zone, a tapered ribbon behind a fighter launched
# hard, sparks on blocks, clanks and armor, a flash ring on a parry, shards when a shield breaks,
# soft dust puffs, jump rings and a light pillar where a fighter respawns. Drawing only.
extends Node2D

const LIFE := {"hit": 0.3, "ko": 1.0, "block": 0.22, "parry": 0.4, "break": 0.7, "clank": 0.26,
		"grab": 0.22, "armor": 0.32, "dust": 0.45, "ring": 0.32, "respawn": 0.9, "trail": 0.8,
		"pop": 0.25}
const TRAIL_POINTS := 16
const FAN := 20  # Segments of a soft circle.
const HOT := Color("ffd84a")
const FIRE := Color("ff7a2e")
const ICE := Color("b8f2ff")
const GOLD := Color("ffd166")

var _effects := []
var _rng := RandomNumberGenerator.new()  # Looks only: never touches the simulation.
var _fan_indices := PackedInt32Array()


func _init() -> void:
	_rng.seed = 7
	for n in FAN:
		_fan_indices.append_array([0, n + 1, (n + 1) % FAN + 1])


# speed: the launch speed; direction: roughly where the target flies (zero for unknown).
func add_hit(at: Vector2, speed: float, direction: Vector2 = Vector2.ZERO) -> void:
	var k := clampf((speed - 4.0) / 30.0, 0.0, 1.0)
	var e := _add("hit", at, lerpf(46.0, 150.0, k), Color.WHITE)
	e["life"] = lerpf(0.22, 0.42, k)
	e["k"] = k
	e["spin"] = _rng.randf() * TAU
	var rays := []
	for n in 6 + int(k * 8):
		var angle := TAU * n / (6 + int(k * 8)) + _rng.randf_range(-0.25, 0.25)
		if direction != Vector2.ZERO and k > 0.35 and n % 2 == 0:  # Lines stream along the launch.
			angle = direction.angle() + _rng.randf_range(-0.45, 0.45)
		rays.append(Vector3(angle, _rng.randf_range(0.7, 1.3), _rng.randf_range(0.6, 1.0)))
	e["rays"] = rays
	var away := direction if direction != Vector2.ZERO else Vector2.UP
	e["parts"] = _parts(3 + int(k * 9), away, 1.3, 400.0, 700.0 + 900.0 * k)


# toward: a point inside the arena; the beam shoots from the screen edge towards it.
func add_ko(at: Vector2, color: Color, toward: Vector2 = Vector2(960.0, 540.0)) -> void:
	var e := _add("ko", at, 1.0, color)
	e["dir"] = (toward - at).normalized()
	e["parts"] = _parts(18, e["dir"], 0.9, 500.0, 1500.0)


func add_block(at: Vector2, color: Color) -> void:
	var e := _add("block", at, 62.0, color.lightened(0.45))
	e["spin"] = _rng.randf() * TAU


func add_parry(at: Vector2) -> void:
	_add("parry", at, 120.0, ICE)


func add_break(at: Vector2, color: Color) -> void:
	var e := _add("break", at, 90.0, color.lightened(0.35))
	e["parts"] = _parts(14, Vector2.UP, PI, 300.0, 700.0)


func add_clank(at: Vector2) -> void:
	var e := _add("clank", at, 70.0, Color.WHITE)
	e["spin"] = _rng.randf() * TAU


func add_grab(at: Vector2, color: Color) -> void:
	_add("grab", at, 50.0, color.lightened(0.4))


func add_armor(at: Vector2) -> void:
	_add("armor", at, 70.0, GOLD)


func add_dust(at: Vector2, size: float = 1.0) -> void:
	var e := _add("dust", at, 26.0 * size, Color(0.93, 0.9, 0.84, 0.6))
	e["parts"] = _parts(4, Vector2.UP, PI * 0.5, 30.0, 80.0)


# A ring at the feet, for a jump in the air.
func add_ring(at: Vector2, color: Color) -> void:
	_add("ring", at, 46.0, color)


# A light pillar falling on a respawn platform.
func add_respawn(at: Vector2, color: Color) -> void:
	_add("respawn", at, 120.0, color)


# A small burst where a shot vanishes.
func add_pop(at: Vector2, color: Color) -> void:
	_add("pop", at, 30.0, color.lightened(0.4))


# A ribbon along the launched fighter's last positions, while it flies.
func add_trail(fighter, color: Color) -> void:
	var e := _add("trail", fighter.position, 1.0, color)
	e["fighter"] = fighter
	e["respawns"] = fighter.respawns
	e["points"] = PackedVector2Array()


func clear() -> void:
	_effects.clear()
	queue_redraw()


func _add(kind: String, at: Vector2, size: float, color: Color) -> Dictionary:
	var e := {"kind": kind, "at": at, "size": size, "age": 0.0, "life": LIFE[kind],
			"color": color}
	_effects.append(e)
	return e


# Particles: [direction, speed, size, spin] spread around a direction.
func _parts(count: int, direction: Vector2, spread: float, slow: float, fast: float) -> Array:
	var parts := []
	for n in count:
		var d := direction.rotated(_rng.randf_range(-spread, spread))
		parts.append([d, _rng.randf_range(slow, fast), _rng.randf_range(0.6, 1.2),
				_rng.randf_range(-12.0, 12.0)])
	return parts


func _process(delta: float) -> void:
	if _effects.is_empty():
		return
	for e in _effects:
		e["age"] += delta
		if e["kind"] == "trail":
			var f = e["fighter"]
			var points: PackedVector2Array = e["points"]
			if not f.out and f.respawns == e["respawns"]:
				points.append(f.position + Vector2(0.0, -f.stats.height / 2.0))
			if points.size() > TRAIL_POINTS:
				points.remove_at(0)
			e["points"] = points
	_effects = _effects.filter(func(e): return e["age"] < e["life"])
	queue_redraw()


func _draw() -> void:
	for e in _effects:
		var t: float = e["age"] / e["life"]
		match e["kind"]:
			"hit":
				_draw_hit(e, t)
			"ko":
				_draw_ko(e, t)
			"block":
				_draw_block(e, t)
			"parry":
				_draw_parry(e, t)
			"break":
				_draw_break(e, t)
			"clank":
				_draw_clank(e, t)
			"grab":
				_draw_grab(e, t)
			"armor":
				_draw_armor(e, t)
			"dust":
				_draw_dust(e, t)
			"ring":
				_ellipse_ring(e["at"], Vector2(1.0, 0.3) * e["size"] * (0.5 + _out(t)),
						Color(e["color"], 0.8 * (1.0 - t)), 5.0 * (1.0 - t) + 1.0)
			"respawn":
				_draw_respawn(e, t)
			"trail":
				_draw_trail(e, t)
			"pop":
				var c: Color = e["color"]
				draw_arc(e["at"], e["size"] * (0.3 + _out(t)), 0.0, TAU, 24,
						Color(c, 1.0 - t), 4.0 * (1.0 - t) + 1.0, true)
				_star(e["at"], e["size"] * 0.6 * (1.0 - t), 4, 0.3, 0.8,
						Color(Color.WHITE, 1.0 - t))


func _draw_hit(e: Dictionary, t: float) -> void:
	var at: Vector2 = e["at"]
	var size: float = e["size"]
	var k: float = e["k"]
	var fade := 1.0 - _smooth(0.55, 1.0, t)
	if t < 0.3:  # The flash of the contact.
		_soft(at, size * (0.5 + t), Color(1.0, 1.0, 0.95, 0.9 * (1.0 - t / 0.3)))
	# The star pops at once and is gone before the ring and lines, so the fighters show again.
	var grow := _back(minf(t * 4.0, 1.0)) * (1.0 - _smooth(0.25, 0.8, t))
	var outer: Color = HOT.lerp(FIRE, k)
	var points := 8 + int(k * 4)
	_star(at, size * 0.62 * grow, points, e["spin"], 0.38, Color(outer, fade))
	_star(at, size * 0.4 * grow, points, e["spin"] + PI / points, 0.42, Color(1.0, 0.97, 0.8, fade))
	draw_circle(at, size * 0.13 * grow, Color(Color.WHITE, fade), true, -1.0, true)
	var ring := size * (0.35 + 0.75 * _out(t))
	draw_arc(at, ring, 0.0, TAU, 48, Color(1.0, 0.97, 0.85, 0.95 * (1.0 - t)),
			size * 0.07 * (1.0 - t) + 1.5, true)
	for p in e["parts"]:  # Hot chips flying off, falling a little.
		var age: float = e["age"]
		var v: Vector2 = p[0] * p[1] + Vector2(0.0, 1400.0 * age)
		var chip: Vector2 = at + p[0] * p[1] * age + Vector2(0.0, 700.0 * age * age)
		_wedge(chip, chip - v * 0.03 * p[2], 6.0 * p[2] * (1.0 - t),
				Color(HOT.lightened(0.3), fade))
	for ray: Vector3 in e["rays"]:  # Speed lines, thin tapered wedges racing outwards.
		var d := Vector2.from_angle(ray.x)
		var from := at + d * size * (0.42 + 0.9 * _out(t))
		var to := at + d * size * (0.8 + (0.8 + k) * _out(t)) * ray.y
		_wedge(from, to, (5.0 + 9.0 * k) * ray.z * (1.0 - t), Color(Color.WHITE, 1.0 - t))


func _draw_ko(e: Dictionary, t: float) -> void:
	var view := _view_rect()
	var at: Vector2 = e["at"]
	# The blast zone edge is often off screen: the beam starts at the screen edge instead.
	var o := Vector2(clampf(at.x, view.position.x, view.end.x),
			clampf(at.y, view.position.y, view.end.y))
	var d: Vector2 = e["dir"]
	var c: Color = e["color"]
	var fade := 1.0 - _smooth(0.45, 1.0, t)
	var length := 1700.0 * _out(minf(t * 2.2, 1.0))
	var width := 125.0 * (1.0 - _smooth(0.1, 0.8, t)) + 3.0  # Half the beam's width.
	_soft(o, 420.0 * (0.6 + 0.4 * _out(t)), Color(c.lightened(0.2), 0.55 * fade))
	for band in [[1.0, 1.0, Color(c, 0.65 * fade)], [0.85, 0.42, Color(c.lightened(0.6), fade)],
			[0.65, 0.16, Color(1, 1, 1, fade)]]:  # The beam: wide at the edge, a point inside.
		_ribbon(o, o + d * length * band[0], width * band[1], width * band[1] * 0.08,
				band[2], Color(band[2], 0.0))
	for ring in 2:  # Rings bursting from the edge.
		var r := _out(clampf(t * 1.8 - ring * 0.25, 0.0, 1.0))
		if r > 0.0:
			draw_arc(o, 60.0 + 380.0 * r, 0.0, TAU, 64, Color(Color.WHITE, (1.0 - r) * fade),
					22.0 * (1.0 - r) + 2.0, true)
	var burst := 170.0 * _back(minf(t * 4.0, 1.0)) * (1.0 - _smooth(0.1, 0.5, t))
	_star(o, burst, 12, d.angle(), 0.3, Color(Color.WHITE, fade))
	for p in e["parts"]:  # Shards flying into the arena.
		var at_p: Vector2 = o + p[0] * p[1] * e["age"] * (1.0 - 0.4 * t)
		_wedge(at_p - p[0] * 50.0 * p[2], at_p, 10.0 * p[2] * (1.0 - t),
				Color(c.lightened(0.5), fade))


func _draw_block(e: Dictionary, t: float) -> void:
	var at: Vector2 = e["at"]
	var c: Color = e["color"]
	var size: float = e["size"]
	_soft(at, size * (0.7 + 0.5 * t), Color(c, 0.75 * (1.0 - t)))
	for r in 8:  # Sparks glancing off the shield.
		var d := Vector2.from_angle(e["spin"] + TAU * r / 8.0)
		var reach := 1.0 if r % 2 == 0 else 0.7
		_wedge(at + d * size * (0.25 + 0.6 * _out(t)), at + d * size * (0.6 + reach * _out(t)),
				8.0 * (1.0 - t), Color(c.lightened(0.6), 1.0 - t))
	draw_arc(at, size * (0.3 + 0.45 * _out(t)), e["spin"], e["spin"] + TAU, 7,
			Color(Color.WHITE, 1.0 - t), 6.0 * (1.0 - t) + 1.0, true)
	_star(at, size * 0.35 * (1.0 - t), 4, e["spin"], 0.3, Color(Color.WHITE, 1.0 - t))


func _draw_parry(e: Dictionary, t: float) -> void:
	var at: Vector2 = e["at"]
	var size: float = e["size"]
	var c: Color = e["color"]
	if t < 0.25:
		_soft(at, size * 0.9, Color(1.0, 1.0, 1.0, 0.8 * (1.0 - t / 0.25)))
	for ring in 2:
		var r := _out(clampf(t * 1.6 - ring * 0.3, 0.0, 1.0))
		if r > 0.0:
			draw_arc(at, size * (0.2 + r), 0.0, TAU, 48, Color(c, 1.0 - r),
					12.0 * (1.0 - r) + 1.5, true)
	for r in 12:  # Freeze lines closing in.
		var d := Vector2.from_angle(TAU * r / 12.0 + 0.13)
		var inner := size * (1.5 - 0.9 * _out(t))
		_wedge(at + d * (inner + size * 0.5), at + d * inner, 5.0 * (1.0 - t),
				Color(Color.WHITE, 1.0 - t))


func _draw_break(e: Dictionary, t: float) -> void:
	var at: Vector2 = e["at"]
	var c: Color = e["color"]
	var age: float = e["age"]
	if t < 0.4:
		_star(at, e["size"] * 1.4 * _back(minf(t * 5.0, 1.0)) * (1.0 - t / 0.4), 10, 0.2, 0.35,
				Color(HOT, 1.0 - t / 0.4))
	draw_arc(at, e["size"] * (0.5 + 1.5 * _out(t)), 0.0, TAU, 48, Color(c, 1.0 - t),
			8.0 * (1.0 - t) + 1.0, true)
	for p in e["parts"]:  # Shield shards falling away and spinning.
		var pos: Vector2 = at + p[0] * p[1] * age + Vector2(0.0, 900.0 * age * age)
		var spin: float = p[3] * age
		var s: float = 22.0 * p[2]
		draw_colored_polygon(PackedVector2Array([pos + Vector2(s, 0.0).rotated(spin),
				pos + Vector2(-s * 0.5, s * 0.6).rotated(spin),
				pos + Vector2(-s * 0.4, -s * 0.7).rotated(spin)]), Color(c, 1.0 - t))


func _draw_clank(e: Dictionary, t: float) -> void:
	var at: Vector2 = e["at"]
	var size: float = e["size"] * (0.6 + 0.8 * _out(t))
	_soft(at, e["size"] * 0.8, Color(HOT, 0.6 * (1.0 - t)))
	for r in 4:
		var d := Vector2.from_angle(e["spin"] + TAU * r / 4.0)
		_wedge(at + d * size * 0.2, at + d * size * 1.2, 8.0 * (1.0 - t), Color(HOT, 1.0 - t))
	_star(at, size * 0.6 * (1.0 - t), 4, e["spin"] + PI / 4.0, 0.25, Color(Color.WHITE, 1.0 - t))


func _draw_grab(e: Dictionary, t: float) -> void:
	var at: Vector2 = e["at"]
	var c: Color = e["color"]
	draw_arc(at, e["size"] * (1.0 - 0.6 * _out(t)), 0.0, TAU, 32, Color(c, 1.0 - t),
			6.0 * (1.0 - t) + 1.0, true)
	_soft(at, e["size"] * 0.7, Color(c, 0.5 * (1.0 - t)))


func _draw_armor(e: Dictionary, t: float) -> void:
	var at: Vector2 = e["at"]
	var grow := sin(PI * t)
	_soft(at, e["size"] * 0.9 * grow, Color(GOLD, 0.6))
	_star(at, e["size"] * grow, 4, t * 1.2, 0.16, Color(Color.WHITE, 1.0 - t * 0.5))
	_star(at, e["size"] * 0.5 * grow, 4, PI / 4.0 + t * 1.2, 0.2, Color(GOLD, 1.0 - t * 0.5))


func _draw_dust(e: Dictionary, t: float) -> void:
	var c: Color = e["color"]
	var size: float = e["size"]
	var age: float = e["age"]
	for p in e["parts"]:  # Soft puffs rolling outwards, rising and thinning.
		var side: float = signf(p[0].x) if p[0].x != 0.0 else 1.0
		var pos: Vector2 = e["at"] + Vector2(side * (size * 0.4 + p[1] * age * 1.4),
				-size * 0.35 - p[1] * age * 0.35)
		var r: float = size * p[2] * (0.45 + 0.5 * _out(t)) * (1.0 - 0.5 * t)
		_soft(pos, r * 1.5, Color(c, 0.5 * c.a * (1.0 - t)))
		draw_circle(pos, r, Color(c, c.a * (1.0 - t)), true, -1.0, true)
		draw_circle(pos + Vector2(-r * 0.25, -r * 0.3), r * 0.5,
				Color(Color.WHITE, 0.4 * (1.0 - t)), true, -1.0, true)


func _draw_respawn(e: Dictionary, t: float) -> void:
	var at: Vector2 = e["at"]
	var c: Color = e["color"]
	var top := _view_rect().position.y - 10.0
	var fade := 1.0 - _smooth(0.4, 1.0, t)
	var w: float = e["size"] * (0.4 + 0.6 * _out(minf(t * 3.0, 1.0))) * (1.0 - 0.5 * t)
	var sky := Vector2(at.x, top)
	_ribbon(sky, at, w / 2.0, w / 2.0, Color(c.lightened(0.5), 0.0),
			Color(c.lightened(0.3), 0.55 * fade))
	_ribbon(sky, at, w * 0.12, w * 0.12, Color(1, 1, 1, 0), Color(1, 1, 1, 0.8 * fade))
	_ellipse_ring(at, Vector2(1.0, 0.25) * e["size"] * (0.5 + _out(t)),
			Color(c.lightened(0.5), fade), 5.0 * fade + 1.0)


func _draw_trail(e: Dictionary, t: float) -> void:
	var points: PackedVector2Array = e["points"]
	var c: Color = e["color"].lightened(0.2)
	var count := points.size()
	var fade := 1.0 - t
	for n in range(1, count):  # A ribbon, thin and clear at the tail, wide at the fighter.
		var wa := 34.0 * float(n - 1) / count * fade
		var wb := 34.0 * float(n) / count * fade
		var aa := 0.85 * float(n - 1) / count * fade
		var ab := 0.85 * float(n) / count * fade
		_ribbon(points[n - 1], points[n], wa, wb, Color(c, aa), Color(c, ab))
		_ribbon(points[n - 1], points[n], wa * 0.35, wb * 0.35, Color(1, 1, 1, aa),
				Color(1, 1, 1, ab))


# A band from a to b, wa wide on each side at a and wb at b, its color going from ca to cb.
func _ribbon(a: Vector2, b: Vector2, wa: float, wb: float, ca: Color, cb: Color) -> void:
	if a.distance_squared_to(b) < 1.0:
		return
	var side := (b - a).normalized().orthogonal()
	draw_primitive(PackedVector2Array([a + side * wa, b + side * wb, b - side * wb,
			a - side * wa]), PackedColorArray([ca, cb, cb, ca]), PackedVector2Array())


# A star of thin spikes: radius, spike count, turn, inner radius as a share of the outer.
func _star(at: Vector2, radius: float, spikes: int, turn: float, inner: float, c: Color) -> void:
	if radius < 1.0:
		return
	var colors := PackedColorArray([c, c, c])
	var base := radius * inner
	var half := PI / spikes
	for s in spikes:  # Long and short spikes in turn.
		var a := turn + TAU * s / spikes
		var reach := radius * (1.0 if s % 2 == 0 else 0.7)
		draw_primitive(PackedVector2Array([at + Vector2.from_angle(a - half) * base,
				at + Vector2.from_angle(a) * reach, at + Vector2.from_angle(a + half) * base]),
				colors, PackedVector2Array())
	draw_circle(at, radius * inner * 1.02, c, true, -1.0, true)


# A thin triangle, wide at from and pointed at to.
func _wedge(from: Vector2, to: Vector2, width: float, c: Color) -> void:
	if width < 0.3 or from.distance_squared_to(to) < 1.0:
		return
	var side := (to - from).normalized().orthogonal() * width / 2.0
	draw_primitive(PackedVector2Array([from + side, to, from - side]),
			PackedColorArray([c, c, c]), PackedVector2Array())


# A soft glow: full color in the middle, clear at the rim.
func _soft(at: Vector2, radius: float, c: Color) -> void:
	if radius < 1.0 or c.a <= 0.0:
		return
	var points := PackedVector2Array([at])
	var colors := PackedColorArray([c])
	var rim := Color(c, 0.0)
	for n in FAN:
		points.append(at + Vector2.from_angle(TAU * n / FAN) * radius)
		colors.append(rim)
	RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), _fan_indices, points,
			colors)


func _ellipse_ring(at: Vector2, radius: Vector2, c: Color, width: float) -> void:
	var points := PackedVector2Array()
	for n in 33:
		var a := TAU * n / 32.0
		points.append(at + Vector2(cos(a) * radius.x, sin(a) * radius.y))
	draw_polyline(points, c, width, true)


func _view_rect() -> Rect2:
	return get_viewport().get_canvas_transform().affine_inverse() * get_viewport_rect()


static func _out(t: float) -> float:
	return 1.0 - pow(1.0 - clampf(t, 0.0, 1.0), 3.0)


static func _back(t: float) -> float:
	var x := clampf(t, 0.0, 1.0) - 1.0
	return 1.0 + 2.70158 * x * x * x + 1.70158 * x * x


static func _smooth(from: float, to: float, t: float) -> float:
	return smoothstep(from, to, t)

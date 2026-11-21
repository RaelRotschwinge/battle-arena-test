# Short effects in the arena (game design, "Hit feel"): a burst where a hit lands, bigger for
# stronger hits, a trail behind a fighter launched hard, a spark on a blocked hit, a ring on a
# parry, dust where fighters land and turn, and a flash where a fighter leaves the blast zone.
# Drawing only.
extends Node2D

const TIMES := {"hit": 0.25, "ko": 0.6, "block": 0.18, "parry": 0.35, "dust": 0.35,
		"trail": 0.7}
const RAYS := 8
const TRAIL_POINTS := 14

var _effects := []  # [kind, position, size, age, color, extra]


func add_hit(at: Vector2, speed: float) -> void:
	_effects.append(["hit", at, clampf(20.0 + speed * 3.0, 30.0, 140.0), 0.0, Color.WHITE, null])


func add_ko(at: Vector2, color: Color) -> void:
	_effects.append(["ko", at, 420.0, 0.0, color, null])


func add_block(at: Vector2, color: Color) -> void:
	_effects.append(["block", at, 40.0, 0.0, color.lightened(0.5), null])


func add_parry(at: Vector2) -> void:
	_effects.append(["parry", at, 90.0, 0.0, Color("b8f2ff"), null])


func add_dust(at: Vector2, size: float = 1.0) -> void:
	_effects.append(["dust", at, 26.0 * size, 0.0, Color(0.85, 0.82, 0.75, 0.6), null])


# A trail of the launched fighter's last positions, while it flies.
func add_trail(fighter, color: Color) -> void:
	_effects.append(["trail", fighter.position, 1.0, 0.0, color, {"fighter": fighter,
			"points": PackedVector2Array()}])


func clear() -> void:
	_effects.clear()
	queue_redraw()


func _process(delta: float) -> void:
	if _effects.is_empty():
		return
	for e in _effects:
		e[3] += delta
		if e[0] == "trail":
			var f = e[5]["fighter"]
			var points: PackedVector2Array = e[5]["points"]
			points.append(f.position + Vector2(0.0, -f.stats.height / 2.0))
			if points.size() > TRAIL_POINTS:
				points.remove_at(0)
			e[5]["points"] = points
	_effects = _effects.filter(func(e): return e[3] < TIMES[e[0]])
	queue_redraw()


func _draw() -> void:
	for e in _effects:
		var at: Vector2 = e[1]
		var size: float = e[2]
		var color: Color = e[4]
		var t: float = e[3] / TIMES[e[0]]
		match e[0]:
			"hit":
				color.a = 1.0 - t
				draw_circle(at, size * (0.3 + 0.7 * t), color, false, 6.0 * (1.0 - t) + 1.0)
				for r in RAYS:
					var direction := Vector2.from_angle(TAU * r / RAYS + 0.3)
					draw_line(at + direction * size * 0.4 * t,
							at + direction * size * (0.5 + 0.6 * t), color, 4.0)
			"ko":
				color.a = 0.8 * (1.0 - t)
				draw_circle(at, size * (0.2 + 0.8 * t), color)
				draw_circle(at, size * (0.1 + 0.6 * t), Color(1.0, 1.0, 1.0, 0.7 * (1.0 - t)))
			"block":
				color.a = 1.0 - t
				for r in 5:
					var direction := Vector2.from_angle(TAU * r / 5.0 + 0.6)
					draw_line(at, at + direction * size * (0.4 + t), color, 3.0)
			"parry":
				color.a = 1.0 - t
				draw_arc(at, size * (0.3 + t), 0.0, TAU, 32, color, 6.0 * (1.0 - t) + 2.0)
			"dust":
				color.a *= 1.0 - t
				for side in [-1.0, 1.0]:
					draw_circle(at + Vector2(side * size * (0.5 + t), -size * 0.3 * t),
							size * (0.5 - 0.3 * t), color)
			"trail":
				var points: PackedVector2Array = e[5]["points"]
				for n in range(1, points.size()):
					var c := color
					c.a = 0.6 * float(n) / points.size() * (1.0 - t)
					draw_line(points[n - 1], points[n], c, 4.0 + 10.0 * float(n) / points.size())

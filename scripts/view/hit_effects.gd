# Short effects in the arena (game design, "Hit feel"): a burst where a hit lands, bigger for
# stronger hits, and a flash where a fighter leaves the blast zone. Drawing only.
extends Node2D

const HIT_TIME := 0.25  # Seconds.
const KO_TIME := 0.6
const RAYS := 8

var _effects := []  # [kind, position, size, age, color]


func add_hit(at: Vector2, speed: float) -> void:
	_effects.append(["hit", at, clampf(20.0 + speed * 3.0, 30.0, 140.0), 0.0, Color.WHITE])


func add_ko(at: Vector2, color: Color) -> void:
	_effects.append(["ko", at, 420.0, 0.0, color])


func clear() -> void:
	_effects.clear()
	queue_redraw()


func _process(delta: float) -> void:
	if _effects.is_empty():
		return
	for e in _effects:
		e[3] += delta
	_effects = _effects.filter(func(e): return e[3] < (HIT_TIME if e[0] == "hit" else KO_TIME))
	queue_redraw()


func _draw() -> void:
	for e in _effects:
		var at: Vector2 = e[1]
		var size: float = e[2]
		var color: Color = e[4]
		if e[0] == "hit":
			var t: float = e[3] / HIT_TIME
			color.a = 1.0 - t
			draw_circle(at, size * (0.3 + 0.7 * t), color, false, 6.0 * (1.0 - t) + 1.0)
			for r in RAYS:
				var direction := Vector2.from_angle(TAU * r / RAYS + 0.3)
				draw_line(at + direction * size * 0.4 * t, at + direction * size * (0.5 + 0.6 * t),
						color, 4.0)
		else:
			var t: float = e[3] / KO_TIME
			color.a = 0.8 * (1.0 - t)
			draw_circle(at, size * (0.2 + 0.8 * t), color)
			draw_circle(at, size * (0.1 + 0.6 * t), Color(1.0, 1.0, 1.0, 0.7 * (1.0 - t)))

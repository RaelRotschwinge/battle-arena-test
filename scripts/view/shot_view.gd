# Draws the shots in flight (Kade's Spark): a glowing orb in its owner's color with a soft halo,
# sparkles circling it and a tapered trail; a small burst where it vanishes.
extends Node2D

const TRAIL := 10  # Positions kept per shot for the trail.
const FAN := 20

var sim
var colors: Array = []  # The players' colors.
var effects  # The hit effects node, for the burst where a shot vanishes.
var _ticks := 0
var _trails := {}  # Owner index -> [last positions, color], one shot per owner at a time.
var _fan_indices := PackedInt32Array()


func _init() -> void:
	for n in FAN:
		_fan_indices.append_array([0, n + 1, (n + 1) % FAN + 1])


# Forgets the shots of the last match.
func reset() -> void:
	_trails.clear()


# Called every tick after the simulation step.
func sync() -> void:
	_ticks += 1
	var seen := {}
	for shot in sim.shots:
		var who: int = shot["owner"]
		seen[who] = true
		var at: Vector2 = shot["position"]
		if not _trails.has(who) or _trails[who][0][-1].distance_to(at) > 80.0:
			_trails[who] = [PackedVector2Array(), _color(who)]  # A new shot (or parried).
		var points: PackedVector2Array = _trails[who][0]
		points.append(at)
		if points.size() > TRAIL:
			points.remove_at(0)
		_trails[who][0] = points
	for who in _trails.keys():
		if not seen.has(who):
			if effects != null:
				effects.add_pop(_trails[who][0][-1], _trails[who][1])
			_trails.erase(who)
	queue_redraw()


func _color(who: int) -> Color:
	return colors[who] if who < colors.size() else Color.WHITE


func _draw() -> void:
	if sim == null:
		return
	for shot in sim.shots:
		var radius: float = sim.shot_data(shot)["size"].x / 2.0
		var color := _color(shot["owner"])
		var at: Vector2 = shot["position"]
		if _trails.has(shot["owner"]):
			_trail(_trails[shot["owner"]][0], radius, color)
		var pulse := 1.0 + 0.1 * sin(_ticks * 0.6)
		_soft(at, radius * 2.6 * pulse, Color(color.lightened(0.2), 0.5))
		draw_circle(at, radius * 1.05 * pulse, Color(color, 0.9), true, -1.0, true)
		draw_circle(at, radius * 0.78, color.lightened(0.55), true, -1.0, true)
		draw_circle(at + Vector2(-radius * 0.15, -radius * 0.15), radius * 0.42, Color.WHITE,
				true, -1.0, true)
		for n in 3:  # Sparkles circling the orb.
			var turn := _ticks * 0.25 + TAU * n / 3.0
			var spot := at + Vector2(cos(turn), sin(turn) * 0.8) * radius * 1.55
			var s := radius * (0.32 + 0.12 * sin(_ticks * 0.9 + n * 2.0))
			_sparkle(spot, s, Color(Color.WHITE, 0.95))


# A tapered ribbon through the shot's last positions, clear at its tail.
func _trail(points: PackedVector2Array, radius: float, color: Color) -> void:
	var count := points.size()
	for n in range(1, count):
		var a := points[n - 1]
		var b := points[n]
		if a.distance_squared_to(b) < 1.0:
			continue
		var side := (b - a).normalized().orthogonal()
		var wa := radius * 0.9 * float(n - 1) / count
		var wb := radius * 0.9 * float(n) / count
		var ca := Color(color.lightened(0.3), 0.75 * float(n - 1) / count)
		var cb := Color(color.lightened(0.3), 0.75 * float(n) / count)
		draw_primitive(PackedVector2Array([a + side * wa, b + side * wb, b - side * wb,
				a - side * wa]), PackedColorArray([ca, cb, cb, ca]), PackedVector2Array())


# A four-pointed sparkle.
func _sparkle(at: Vector2, size: float, c: Color) -> void:
	var colors4 := PackedColorArray([c, c, c, c])
	draw_primitive(PackedVector2Array([at + Vector2(0.0, -size), at + Vector2(size * 0.22, 0.0),
			at + Vector2(0.0, size), at + Vector2(-size * 0.22, 0.0)]), colors4,
			PackedVector2Array())
	draw_primitive(PackedVector2Array([at + Vector2(-size, 0.0), at + Vector2(0.0, -size * 0.22),
			at + Vector2(size, 0.0), at + Vector2(0.0, size * 0.22)]), colors4,
			PackedVector2Array())


# A soft glow: full color in the middle, clear at the rim.
func _soft(at: Vector2, radius: float, c: Color) -> void:
	var points := PackedVector2Array([at])
	var colors_fan := PackedColorArray([c])
	for n in FAN:
		points.append(at + Vector2.from_angle(TAU * n / FAN) * radius)
		colors_fan.append(Color(c, 0.0))
	RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), _fan_indices, points,
			colors_fan)

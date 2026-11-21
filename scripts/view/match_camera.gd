# One shared camera that keeps all fighters in view, zooms out as they spread and stops at the
# edges of the blast zone (game design, "Camera"). Strong hits shake it lightly.
extends Camera2D

const MARGIN := Vector2(360.0, 240.0)
const MIN_VIEW := Vector2(1280.0, 720.0)
const FOLLOW := 0.12  # Share of the way to the target per tick.
const SHAKE_TICKS := 12

var sim
var _shake := 0.0  # Strength in pixels.
var _shake_ticks := 0


func _init() -> void:
	process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS


func snap() -> void:
	var target := _target()
	position = target[0]
	zoom = Vector2(target[1], target[1])
	_shake_ticks = 0
	offset = Vector2.ZERO
	reset_physics_interpolation()


func shake(strength: float) -> void:
	if strength >= _shake or _shake_ticks == 0:
		_shake = strength
		_shake_ticks = SHAKE_TICKS


# Called every tick after the simulation step.
func follow() -> void:
	var target := _target()
	position = position.lerp(target[0], FOLLOW)
	var z := lerpf(zoom.x, target[1], FOLLOW)
	zoom = Vector2(z, z)
	if _shake_ticks > 0:
		_shake_ticks -= 1
		var fade := float(_shake_ticks) / SHAKE_TICKS
		offset = Vector2(sin(_shake_ticks * 2.1), cos(_shake_ticks * 2.9)) * _shake * fade
	else:
		offset = Vector2.ZERO


# Returns [center, zoom] that show every fighter with a margin.
func _target() -> Array:
	var bounds := Rect2()
	var first := true
	for f in sim.fighters:
		if f.out:
			continue
		var fighter_box := Rect2(f.position.x - f.stats.width / 2.0,
				f.position.y - f.stats.height, f.stats.width, f.stats.height)
		bounds = fighter_box if first else bounds.merge(fighter_box)
		first = false
	bounds = bounds.grow_individual(MARGIN.x, MARGIN.y, MARGIN.x, MARGIN.y)
	var view := get_viewport_rect().size
	var size := bounds.size.max(MIN_VIEW)
	var blast: Rect2 = sim.arena.blast_zone
	var z := minf(view.x / size.x, view.y / size.y)
	z = maxf(z, maxf(view.x / blast.size.x, view.y / blast.size.y))
	var half := view / z / 2.0
	var center := bounds.get_center()
	center.x = clampf(center.x, blast.position.x + half.x, blast.end.x - half.x)
	center.y = clampf(center.y, blast.position.y + half.y, blast.end.y - half.y)
	return [center, z]

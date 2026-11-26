# One shared camera that keeps all fighters in view, zooms out as they spread and stops at the
# edges of the blast zone (game design, "Camera"). It looks a little ahead of where the fighters
# move, zooms out quickly and in slowly, and gives strong hits and knockouts a light shake and a
# short zoom punch, both scaled by the Screen shake option. A match opens on the whole arena and
# eases in to the fighters.
extends Camera2D

const Settings := preload("res://scripts/view/settings.gd")

const MARGIN := Vector2(360.0, 240.0)
const MIN_VIEW := Vector2(1280.0, 720.0)
const FOLLOW := 0.1  # Share of the way to the target per tick.
const ZOOM_OUT := 0.12  # Zooming out is quicker than zooming in, so no fighter leaves the view.
const ZOOM_IN := 0.045
const LOOKAHEAD := 8.0  # Ticks of the fighters' average velocity the camera looks ahead.
const LOOKAHEAD_MAX := 110.0
const SHAKE_TICKS := 14
const PUNCH_TICKS := 22
const INTRO_TICKS := 60  # About as long as the "GO!" banner.

var sim
var _shake := 0.0  # Strength in pixels.
var _shake_ticks := 0
var _punch := 0.0  # Extra zoom share at the peak of a punch.
var _punch_ticks := 0
var _focus := Vector2.INF  # The point a punch leans towards, INF for the middle.
var _base_zoom := 1.0  # The framing zoom, without the punch.
var _intro_ticks := 0
var _intro_from := []  # [center, zoom] showing the whole arena.


func _init() -> void:
	process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS


func snap() -> void:
	var target := _target()
	position = target[0]
	_base_zoom = target[1]
	zoom = Vector2(_base_zoom, _base_zoom)
	_shake_ticks = 0
	_punch_ticks = 0
	_intro_ticks = 0
	offset = Vector2.ZERO
	reset_physics_interpolation()


# Starts on the whole arena; follow() eases in to the fighters over INTRO_TICKS.
func intro() -> void:
	_intro_from = _frame(sim.arena.view_rect().grow(150.0), Vector2.ZERO)
	_intro_ticks = INTRO_TICKS
	position = _intro_from[0]
	_base_zoom = _intro_from[1]
	zoom = Vector2(_base_zoom, _base_zoom)
	reset_physics_interpolation()


func shake(strength: float) -> void:
	strength *= Settings.shake_scale()
	if strength >= _shake or _shake_ticks == 0:
		_shake = strength
		_shake_ticks = SHAKE_TICKS


# A short zoom in by this share (0.05 is 5 %), quick in and eased back out, leaning towards the
# world point at if given (never past the view it had before the punch).
func punch(amount: float, at: Vector2 = Vector2.INF) -> void:
	amount *= Settings.shake_scale()
	if amount >= _punch or _punch_ticks == 0:
		_punch = amount
		_punch_ticks = PUNCH_TICKS
		_focus = at


# Called every tick after the simulation step.
func follow() -> void:
	var target := _target()
	if _intro_ticks > 0:
		_intro_ticks -= 1
		var t := smoothstep(0.0, 1.0, 1.0 - float(_intro_ticks) / INTRO_TICKS)
		position = _intro_from[0].lerp(target[0], t)
		_base_zoom = lerpf(_intro_from[1], target[1], t)
	else:
		position = position.lerp(target[0], FOLLOW)
		var rate := ZOOM_OUT if target[1] < _base_zoom else ZOOM_IN
		_base_zoom = lerpf(_base_zoom, target[1], rate)
	var z := _base_zoom
	var lean := Vector2.ZERO
	if _punch_ticks > 0:
		_punch_ticks -= 1
		var t := 1.0 - float(_punch_ticks) / PUNCH_TICKS
		var envelope := t / 0.15 if t < 0.15 else pow(1.0 - (t - 0.15) / 0.85, 2.0)
		z *= 1.0 + _punch * envelope
		if _focus != Vector2.INF:  # The room the smaller view has inside the old one.
			var room := get_viewport_rect().size / _base_zoom / 2.0 * (1.0 - _base_zoom / z)
			lean = (_focus - position).clamp(-room, room)
	zoom = Vector2(z, z)
	var jolt := Vector2.ZERO
	if _shake_ticks > 0:
		_shake_ticks -= 1
		var fade := float(_shake_ticks) / SHAKE_TICKS
		jolt = Vector2(sin(_shake_ticks * 2.1), cos(_shake_ticks * 2.9)) * _shake * fade * fade
	offset = lean + jolt


# Returns [center, zoom] that show every fighter with a margin.
func _target() -> Array:
	var bounds := Rect2()
	var first := true
	var drift := Vector2.ZERO
	var count := 0
	for f in sim.fighters:
		if f.out:
			continue
		var fighter_box := Rect2(f.position.x - f.stats.width / 2.0,
				f.position.y - f.stats.height, f.stats.width, f.stats.height)
		bounds = fighter_box if first else bounds.merge(fighter_box)
		first = false
		if f.hitlag == 0:
			drift += f.velocity
		count += 1
	var ahead := Vector2.ZERO
	if count > 0:
		ahead = (drift / count * LOOKAHEAD).limit_length(LOOKAHEAD_MAX)
	return _frame(bounds.grow_individual(MARGIN.x, MARGIN.y, MARGIN.x, MARGIN.y), ahead)


# [center, zoom] showing area (moved by shift), no smaller than MIN_VIEW, inside the blast zone.
func _frame(area: Rect2, shift: Vector2) -> Array:
	var view := get_viewport_rect().size
	var size := area.size.max(MIN_VIEW)
	var blast: Rect2 = sim.arena.blast_zone
	var z := minf(view.x / size.x, view.y / size.y)
	z = maxf(z, maxf(view.x / blast.size.x, view.y / blast.size.y))
	var half := view / z / 2.0
	var center := area.get_center() + shift
	center.x = clampf(center.x, blast.position.x + half.x, blast.end.x - half.x)
	center.y = clampf(center.y, blast.position.y + half.y, blast.end.y - half.y)
	return [center, z]

# Draws one fighter (game design, "Fighters") and what belongs to it: afterimages of its dodges
# and dashes, its shield bubble, dizzy stars, sweat and steam at high damage, the respawn disc, its
# name tag and the hitbox of its attack; with the info overlay its hurtbox and hitbox. The fighter
# itself comes from fighter_look.gd; this node keeps the few timers its animation needs.
extends Node2D

const Mode = preload("res://scripts/sim/fighter_state.gd").Mode
const FighterCombat := preload("res://scripts/sim/fighter_combat.gd")
const FighterDefense := preload("res://scripts/sim/fighter_defense.gd")
const FighterLook := preload("res://scripts/view/fighter_look.gd")
const FighterPose := preload("res://scripts/view/fighter_pose.gd")
const FighterArt := preload("res://scripts/view/fighter_art.gd")

const HURTBOX_COLOR := Color(1.0, 0.9, 0.2, 0.9)
const HITBOX_COLOR := Color(1.0, 0.2, 0.2, 0.45)
const TRAIL_TICKS := 10
const GHOSTS := [3, 6, 9]  # Ticks back of the afterimages.
const STAR := Color("ffe066")
const SWEAT := Color("aee6ff")
const STEAM := Color(0.86, 0.88, 0.92)
const TAG_BACK := Color(0.067, 0.075, 0.102, 0.72)
const TAG_SIZE := 26

var fighter
var color := Color.WHITE  # The player's color: label, ring and shield.
var label := ""
var tag_lift := 0.0  # Raises the name tag when it would cover another fighter's (match_view).
var show_boxes := false
var effects  # The hit effects node: dust where the fighter lands, jumps and turns.
var _respawns := 0
var _ticks := 0
var _last_mode := -1
var _last_facing := 1
var _last_jumps := 0
var _last_hitlag := 0
var _anim := {}  # The look's timers and last pose (fighter_look.gd).
var _trail: Array = []  # The fighter's feet in the last ticks, newest last.
var _tumble := 0.0


# Called every tick after the simulation step.
func sync() -> void:
	visible = not fighter.out
	position = fighter.position
	if fighter.respawns != _respawns:
		_respawns = fighter.respawns
		reset_physics_interpolation()
		_trail.clear()
	_ticks += 1
	_animate()
	_dust()
	queue_redraw()


func _dust() -> void:
	var mode: int = fighter.mode
	if effects != null and _last_mode != -1 and fighter.hitlag == 0:
		var size: float = fighter.stats.width / 60.0
		if mode == Mode.GROUND and _last_mode in [Mode.AIR, Mode.HITSTUN, Mode.DODGE]:
			effects.add_dust(fighter.position, size)
		elif mode == Mode.AIR and _last_mode == Mode.JUMP_SQUAT:
			effects.add_dust(fighter.position, size * 0.7)
		elif mode == Mode.GROUND and fighter.running and fighter.facing != _last_facing:
			effects.add_dust(fighter.position, size * 0.6)
		elif mode == Mode.TECH and _last_mode == Mode.HITSTUN:
			effects.add_dust(fighter.position, size * 1.3)
	_last_mode = mode
	_last_facing = fighter.facing


# The timers of the animation: ticks since landing, turning, a double jump and a throw, and the
# spin of a tumble, which keeps turning on from where it is.
func _animate() -> void:
	var f = fighter
	var mode: int = f.mode
	if not _anim.has("seed"):
		_anim["seed"] = absi(hash(label)) % 97
	_count("land", mode == Mode.GROUND and _last_mode in [Mode.AIR, Mode.HITSTUN, Mode.DODGE])
	_count("turn", mode == Mode.GROUND and _last_mode == Mode.GROUND
			and f.facing != _last_facing)
	_count("flip", mode == Mode.AIR and f.jumps_left < _last_jumps and f.velocity.y < 0.0)
	var threw: bool = _last_mode == Mode.GRAB and mode == Mode.GROUND and f.lag > 0
	if threw:
		var last: String = f.stale.back() if not f.stale.is_empty() else ""
		_anim["throw"] = last if last.begins_with("throw") else "throw_forward"
	_count("throw_t", threw)
	_count("hit", f.mode == Mode.HITSTUN and f.hitlag > 0 and _last_hitlag == 0)
	_last_hitlag = f.hitlag
	var speed: float = f.velocity.length()
	if mode == Mode.HITSTUN and f.hitlag == 0 and speed > FighterPose.TUMBLE_SPEED:
		_tumble -= clampf(speed * 0.022, 0.15, 0.5)
	else:
		_tumble = wrapf(_tumble, -PI, PI) * 0.7
		if absf(_tumble) < 0.02:
			_tumble = 0.0
	_anim["tumble"] = _tumble
	_last_jumps = f.jumps_left
	_trail.append(f.position)
	if _trail.size() > TRAIL_TICKS:
		_trail.pop_front()


func _count(key: String, start: bool) -> void:
	_anim[key] = 0 if start else mini(int(_anim.get(key, 999)) + 1, 999)


func _draw() -> void:
	var f = fighter
	var s = f.stats
	var w: float = s.width
	var h: float = s.height
	if f.mode == Mode.RESPAWN:
		_platform(w)
	_ghosts(f, h)
	if f.mode == Mode.AIR and f.fast_falling:
		_fall_lines(w, h)
	FighterLook.draw(self, f, color, _tint(f), _shake(f), _ticks, _anim)
	if f.mode == Mode.SHIELD:
		_shield(f, h)
	elif f.mode == Mode.SHIELD_BREAK:
		_stars(w, h)
	if f.damage >= 100.0:
		_sweat(f, w, h)
	_hitbox(f)
	_tag(h)
	if show_boxes:
		draw_rect(Rect2(-w / 2.0, -h, w, h), HURTBOX_COLOR, false, 3.0)
		var hitbox := FighterCombat.hitbox(f)
		if hitbox.has_area():
			draw_rect(Rect2(hitbox.position - f.position, hitbox.size), HITBOX_COLOR)


# Shaking in the hit pause, harder the longer it still lasts, and a little while held.
func _shake(f) -> Vector2:
	var side := 1.0 if _ticks % 2 == 0 else -1.0
	if f.hitlag > 0 and f.mode == Mode.HITSTUN:
		return Vector2(side * minf(f.hitlag, 6.0) * 0.9, 0.0)
	if f.mode == Mode.HELD:
		return Vector2(side * 2.0, 0.0)
	return Vector2.ZERO


# Sets the look's flash and glow for this tick; returns the tint. A hit flashes white; a dodge
# that cannot be hit glows bright; other invulnerability shimmers in the player's color.
func _tint(f) -> Color:
	var tint := Color.WHITE
	_anim["flash"] = 0.0
	_anim["glow"] = 0.0
	if f.mode == Mode.HITSTUN:
		if f.hitlag > 0:
			_anim["flash"] = 0.85 if int(_anim.get("hit", 99)) < 3 else 0.4  # The impact.
			_anim["flash_color"] = Color.WHITE
		else:
			tint = Color(0.93, 0.93, 0.96)
	if FighterDefense.intangible(f) or f.mode == Mode.TECH:
		_anim["flash"] = 0.32
		_anim["flash_color"] = Color("e2f2ff")
		_anim["glow"] = 0.9
		_anim["glow_color"] = Color("f2fbff")
	elif f.invuln > 0:
		var shimmer := 0.5 + 0.5 * sin(_ticks * 0.3)
		_anim["flash"] = 0.14 * shimmer
		_anim["flash_color"] = color.lightened(0.7)
		_anim["glow"] = 0.35 + 0.55 * shimmer
		_anim["glow_color"] = color.lightened(0.55)
	return tint


# Afterimages along the way of a roll, an air dodge, a tech roll and a dashing special; Pip's
# Swoop also sheds feathers.
func _ghosts(f, h: float) -> void:
	var dashing: bool = f.attack.begins_with("special") and FighterCombat.is_active(f) \
			and FighterCombat.data(f).has("move")
	var dodging: bool = f.mode == Mode.DODGE and f.dodge != "spot" \
			or f.mode == Mode.TECH and f.dodge == "roll"
	if not (dashing or dodging):
		return
	for n: int in GHOSTS:
		if _trail.size() <= n:
			continue
		var offset: Vector2 = _trail[_trail.size() - 1 - n] - f.position
		if offset.length() < 6.0:
			continue
		var ghost := Color(color.lightened(0.45), 0.34 * (1.0 - n / 12.0))
		FighterLook.draw_ghost(self, f, offset, ghost, _anim)
	if dashing and f.stats.look.get("shape", "") == "pip":
		var feather: Color = f.stats.look["colors"][0]
		for n: int in [2, 5, 8]:
			if _trail.size() <= n:
				continue
			var at: Vector2 = _trail[_trail.size() - 1 - n] - f.position + Vector2(
					sin(n * 2.3) * 14.0, -h * 0.5 + n * 2.0)
			var paint := FighterArt.Paint.new()
			var fade := 1.0 - n / 10.0
			paint.line = Color(FighterArt.INK, 0.8 * fade)
			FighterArt.feather(self, at, n * 1.7 + _ticks * 0.15, 16.0, 6.0,
					Color(feather.lightened(0.2), fade), paint)


func _fall_lines(w: float, h: float) -> void:
	for n in 3:
		var x := (n - 1) * w * 0.32
		var top := -h - 18.0 - (n % 2) * 16.0
		draw_polyline_colors(PackedVector2Array([Vector2(x, top - 44.0), Vector2(x, top)]),
				PackedColorArray([Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.45)]), 3.0, true)


# The shield: a bubble in the player's color that pops up, shrinks with its health, ripples
# when hit, flashes white in the parry window and flickers when nearly broken.
func _shield(f, h: float) -> void:
	var pop := clampf(f.mode_ticks / 6.0, 0.0, 1.0)
	var grow := 1.0 + 2.7 * pow(pop - 1.0, 3.0) + 1.7 * pow(pop - 1.0, 2.0)  # Ease out back.
	var radius: float = FighterDefense.shield_radius(f) * lerpf(0.55, 1.0, grow)
	var middle := Vector2(0.0, -h / 2.0)
	var base := color.lightened(0.3)
	var rim := base.lightened(0.35)
	if f.shield_hp < 30.0 and _ticks % 12 < 6:
		rim = rim.lerp(Color("ff6a50"), 0.6)
	draw_circle(middle, radius, Color(base, 0.18), true, -1.0, true)
	draw_arc(middle, radius * 0.87, 0.0, TAU, 48, Color(base, 0.16), radius * 0.26, true)
	var hit := clampf(f.shield_stun / 8.0, 0.0, 1.0)
	var points := PackedVector2Array()
	for n in 49:
		var a := TAU * n / 48.0
		var wobble := 1.0 + 0.06 * hit * sin(a * 7.0 + _ticks * 1.7)
		points.append(middle + Vector2.from_angle(a) * radius * wobble)
	draw_polyline(points, Color(rim, 0.9), 3.0, true)
	if hit > 0.0:  # A ripple running out from the hit.
		draw_arc(middle, radius * (1.0 + 0.25 * (1.0 - hit)), 0.0, TAU, 48,
				Color(rim, 0.6 * hit), 3.0, true)
	draw_arc(middle, radius * 0.74, -2.55, -1.75, 12, Color(1, 1, 1, 0.6), 4.0, true)
	draw_circle(middle + Vector2.from_angle(-1.45) * radius * 0.74, 2.5, Color(1, 1, 1, 0.6),
			true, -1.0, true)
	var parry: int = f.ticks_since_shield
	if parry <= FighterDefense.PARRY_TICKS:
		var fade := 1.0 - parry / float(FighterDefense.PARRY_TICKS + 1)
		draw_circle(middle, radius, Color(1, 1, 1, 0.3 * fade), true, -1.0, true)
		draw_arc(middle, radius, 0.0, TAU, 48, Color(1, 1, 1, 0.9 * fade), 5.0, true)


# Dizzy after a shield break: three stars circle above the head, the far ones smaller.
func _stars(w: float, h: float) -> void:
	for n in 3:
		var a := _ticks * 0.12 + TAU * n / 3.0
		var near := sin(a)
		var at := Vector2(cos(a) * w * 0.6, -h - 12.0 + near * 7.0)
		var radius := 7.0 + near * 1.5
		var points := PackedVector2Array()
		for k in 10:
			var turn := -PI / 2.0 + TAU * k / 10.0 + _ticks * 0.05
			points.append(at + Vector2.from_angle(turn) * (radius if k % 2 == 0 else radius * 0.45))
		draw_colored_polygon(points, STAR.darkened(0.25 * (1.0 - near)))
		FighterArt.outline(self, points, FighterArt.INK, 2.5)


# From 100 % damage sweat drops fly off; from 150 % steam rises too.
func _sweat(f, w: float, h: float) -> void:
	for k in 2:
		var t := (_ticks + k * 23) % 46
		if t >= 22:
			continue
		var side := 1.0 if k == 0 else -1.0
		var at := Vector2(side * (w * 0.32 + t * 1.3), -h * 0.9 - t * 2.0 + t * t * 0.13)
		var fade := 1.0 - t / 22.0
		var tilt := side * (0.9 - t * 0.08)  # The drop points the way it flies.
		var drop := PackedVector2Array([at + Vector2(0.0, -10.0).rotated(tilt)])
		for n in 7:
			drop.append(at + Vector2.from_angle(-0.2 + n * (PI + 0.4) / 6.0 + tilt) * 5.5)
		draw_colored_polygon(drop, Color(SWEAT, fade))
		FighterArt.outline(self, drop, Color(FighterArt.INK, 0.8 * fade), 2.0)
	if f.damage < 150.0:
		return
	for k in 3:  # Puffs that swell, drift and fade as they rise off the head.
		var t := (_ticks + k * 14) % 42
		var at := Vector2(sin(k * 2.1 + t * 0.12) * 10.0 + (k - 1) * w * 0.25, -h * 0.95 - t * 1.4)
		var fade := sin(PI * t / 42.0)
		draw_circle(at, 7.0 + t * 0.35, Color(STEAM, 0.5 * fade), true, -1.0, true)
		draw_circle(at + Vector2(-3.0, -3.0), 3.0 + t * 0.15, Color(1, 1, 1, 0.35 * fade), true,
				-1.0, true)


# The respawn platform: a glowing disc in the player's color with light falling from it.
func _platform(w: float) -> void:
	var pulse := 0.5 + 0.5 * sin(_ticks * 0.12)
	var clear := Color(color, 0.0)
	draw_primitive(PackedVector2Array([Vector2(-w * 0.9, 10.0), Vector2(w * 0.9, 10.0),
			Vector2(w * 0.35, 90.0), Vector2(-w * 0.35, 90.0)]), PackedColorArray([
			Color(color, 0.35), Color(color, 0.35), clear, clear]), PackedVector2Array())
	draw_colored_polygon(FighterArt.ellipse(Vector2(0.0, 8.0), Vector2(w * 1.35, 20.0)),
			Color(color.lightened(0.3), 0.16 + 0.1 * pulse))
	var side := FighterArt.ellipse(Vector2(0.0, 11.0), Vector2(w * 1.05, 10.0))
	draw_colored_polygon(side, color.darkened(0.35))
	FighterArt.outline(self, side, FighterArt.INK, 3.0)
	var top := FighterArt.ellipse(Vector2(0.0, 6.0), Vector2(w * 1.02, 8.0))
	draw_colored_polygon(top, color.lightened(0.25))
	FighterArt.outline(self, top, Color(color.lightened(0.7), 0.9), 2.5)
	for n in 4:
		var t := fmod(_ticks * 0.7 + n * 9.0, 36.0)
		var at := Vector2((n - 1.5) * w * 0.45, 18.0 + t * 1.6)
		draw_circle(at, 2.5, Color(color.lightened(0.6), 0.8 * (1.0 - t / 36.0)), true, -1.0,
				true)


# The attack's hitbox while it is out: a soft glow in the player's color, an oval inside the box
# with a faint rim, so every hit is readable without a hard frame (F1 shows the exact box).
func _hitbox(f) -> void:
	var hitbox := FighterCombat.hitbox(f)
	if not hitbox.has_area():
		return
	var area := Rect2(hitbox.position - f.position, hitbox.size)
	var middle := area.get_center()
	var half := area.size / 2.0
	var glow := color.lightened(0.6)
	draw_colored_polygon(FighterArt.ellipse(middle, half * 1.05, 0.0, 28), Color(glow, 0.1))
	draw_colored_polygon(FighterArt.ellipse(middle, half * 0.72, 0.0, 24), Color(glow, 0.1))
	FighterArt.outline(self, FighterArt.ellipse(middle, half * 1.05, 0.0, 28),
			Color(color.lightened(0.75), 0.4), 2.0)


# The name tag over the head: the label in the player's color on a dark pill.
func _tag(h: float) -> void:
	if label == "":
		return
	var font := ThemeDB.fallback_font
	var width := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, TAG_SIZE).x
	var bottom := -h - 30.0 - tag_lift
	var pill := FighterArt.rounded(bottom - 34.0, bottom, width / 2.0 + 8.0, width / 2.0 + 8.0,
			10.0)
	draw_colored_polygon(pill, TAG_BACK)
	FighterArt.outline(self, pill, Color(color, 0.9), 2.5)
	draw_colored_polygon(PackedVector2Array([Vector2(-7.0, bottom - 1.0),
			Vector2(7.0, bottom - 1.0), Vector2(0.0, bottom + 8.0)]), color)
	draw_string(font, Vector2(-width / 2.0, bottom - 9.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1,
			TAG_SIZE, color.lightened(0.2))

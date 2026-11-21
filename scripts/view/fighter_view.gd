# Draws one fighter (game design, "Fighters"), its attacks, its shield and dodges, and with the
# info overlay its hurtbox and hitbox. The shape comes from the fighter's look (fighter_look.gd).
extends Node2D

const Mode = preload("res://scripts/sim/fighter_state.gd").Mode
const FighterCombat := preload("res://scripts/sim/fighter_combat.gd")
const FighterDefense := preload("res://scripts/sim/fighter_defense.gd")
const FighterLook := preload("res://scripts/view/fighter_look.gd")

const HURTBOX_COLOR := Color(1.0, 0.9, 0.2, 0.9)
const HITBOX_COLOR := Color(1.0, 0.2, 0.2, 0.45)
const PLATFORM_COLOR := Color("8a93a8")

var fighter
var color := Color.WHITE  # The player's color: label, outline and shield.
var label := ""
var show_boxes := false
var effects  # The hit effects node: dust where the fighter lands, jumps and turns.
var _respawns := 0
var _ticks := 0
var _last_mode := -1
var _last_facing := 1


# Called every tick after the simulation step.
func sync() -> void:
	visible = not fighter.out
	position = fighter.position
	if fighter.respawns != _respawns:
		_respawns = fighter.respawns
		reset_physics_interpolation()
	_ticks += 1
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


func _draw() -> void:
	var s = fighter.stats
	var w: float = s.width
	var h: float = s.height
	var shake := Vector2.ZERO
	if fighter.hitlag > 0 and fighter.mode == Mode.HITSTUN or fighter.mode == Mode.HELD:
		shake.x = 5.0 if _ticks % 2 == 0 else -5.0  # Shakes in the hit pause and when held.
	if fighter.mode == Mode.RESPAWN:
		draw_rect(Rect2(-w, 0.0, w * 2.0, 12.0), PLATFORM_COLOR)

	var tint := Color(1, 1, 1, 1)
	if fighter.mode == Mode.HITSTUN:
		tint = Color(1.6, 1.6, 1.6) if fighter.hitlag > 0 else Color(0.8, 0.8, 0.8)
	if FighterDefense.intangible(fighter) or fighter.mode == Mode.TECH:
		tint = Color(1.5, 1.5, 1.8, 0.45)
	elif fighter.invuln > 0 and (fighter.invuln / 4) % 2 == 0:
		tint.a = 0.35  # Blinks while it cannot be hit.
	FighterLook.draw(self, fighter, color, tint, shake, _ticks)

	if fighter.mode == Mode.SHIELD:
		var radius := FighterDefense.shield_radius(fighter)
		var flash: bool = fighter.shield_stun > 0 and _ticks % 4 < 2
		var shield_color := color.lightened(0.35)
		shield_color.a = 0.55 if flash else 0.32
		var middle := Vector2(0.0, -h / 2.0)
		draw_circle(middle, radius, shield_color)
		draw_arc(middle, radius, 0.0, TAU, 40, Color(1, 1, 1, 0.6), 3.0)
	elif fighter.mode == Mode.SHIELD_BREAK:  # Dizzy: stars circle above the head.
		for n in 3:
			var turn := _ticks * 0.12 + TAU * n / 3.0
			draw_circle(Vector2(cos(turn) * 34.0, -h - 18.0 + sin(turn) * 8.0), 6.0,
					Color("ffe066"))
	elif fighter.mode == Mode.GRAB:  # The arm holding the other fighter.
		draw_rect(Rect2(Vector2(0.0 if fighter.facing > 0 else -w * 0.9, -h * 0.62),
				Vector2(w * 0.9, 12.0)), color.lightened(0.3))

	draw_string(ThemeDB.fallback_font, Vector2(-w, -h - 14.0), label, HORIZONTAL_ALIGNMENT_CENTER,
			w * 2.0, 30, color)

	var hitbox := FighterCombat.hitbox(fighter)
	if hitbox.has_area():  # The attack itself, so every hit is readable.
		var local := Rect2(hitbox.position - fighter.position, hitbox.size)
		draw_rect(local, Color(color.lightened(0.55), 0.75))
		draw_rect(local, Color.WHITE, false, 3.0)
	elif FighterCombat.in_startup(fighter):  # Wind-up: a hint of where the attack will come.
		var box: Rect2 = FighterCombat.data(fighter)["box"]
		var x: float = box.position.x if fighter.facing > 0 else -box.end.x
		draw_rect(Rect2(Vector2(x, box.position.y), box.size), Color(color.lightened(0.55), 0.18))

	if show_boxes:
		draw_rect(Rect2(-w / 2.0, -h, w, h), HURTBOX_COLOR, false, 3.0)
		if hitbox.has_area():
			draw_rect(Rect2(hitbox.position - fighter.position, hitbox.size), HITBOX_COLOR)

# Draws one fighter as a simple shape (game design, "Fighters": a test fighter until M4), its
# attacks, and with the info overlay its hurtbox and hitbox.
extends Node2D

const Mode = preload("res://scripts/sim/fighter_state.gd").Mode
const FighterCombat := preload("res://scripts/sim/fighter_combat.gd")

const HURTBOX_COLOR := Color(1.0, 0.9, 0.2, 0.9)
const HITBOX_COLOR := Color(1.0, 0.2, 0.2, 0.45)
const PLATFORM_COLOR := Color("8a93a8")

var fighter
var stats
var color := Color.WHITE
var label := ""
var show_boxes := false
var _respawns := 0


# Called every tick after the simulation step.
func sync() -> void:
	visible = not fighter.out
	position = fighter.position
	if fighter.respawns != _respawns:
		_respawns = fighter.respawns
		reset_physics_interpolation()
	queue_redraw()


func _draw() -> void:
	var w: float = stats.width
	var h: float = stats.height
	var body := Rect2(-w / 2.0, -h, w, h)
	if fighter.hitlag > 0 and fighter.mode == Mode.HITSTUN:
		body.position.x += 5.0 if fighter.hitlag % 2 == 0 else -5.0  # Shakes in the hit pause.
	if fighter.mode == Mode.RESPAWN:
		draw_rect(Rect2(-w, 0.0, w * 2.0, 12.0), PLATFORM_COLOR)

	var body_color := color
	if fighter.mode == Mode.HITSTUN:
		body_color = color.lerp(Color.WHITE, 0.5) if fighter.hitlag > 0 else color.darkened(0.25)
	if fighter.invuln > 0 and (fighter.invuln / 4) % 2 == 0:
		body_color.a = 0.35  # Blinks while it cannot be hit.
	draw_rect(body, body_color)
	if fighter.mode == Mode.LEDGE:  # Hands on the ledge.
		draw_rect(Rect2(fighter.facing * w / 2.0 - 8.0, -h - 6.0, 16.0, 14.0), color.lightened(0.4))
	var eye := body.position + Vector2(w / 2.0 + fighter.facing * w * 0.22, h * 0.25)
	draw_circle(eye, 8.0, Color.WHITE)
	draw_circle(eye + Vector2(fighter.facing * 3.0, 0.0), 4.0, Color.BLACK)
	draw_string(ThemeDB.fallback_font, Vector2(-w, -h - 14.0), label, HORIZONTAL_ALIGNMENT_CENTER,
			w * 2.0, 30, color)

	var hitbox := FighterCombat.hitbox(fighter)
	if hitbox.has_area():  # The attack itself, so every hit is readable.
		var local := Rect2(hitbox.position - fighter.position, hitbox.size)
		draw_rect(local, Color(color.lightened(0.55), 0.75))
		draw_rect(local, Color.WHITE, false, 3.0)
	elif FighterCombat.in_startup(fighter):  # Wind-up: a hint of where the attack will come.
		var box: Rect2 = FighterCombat.data(fighter.attack)["box"]
		var x: float = box.position.x if fighter.facing > 0 else -box.end.x
		draw_rect(Rect2(Vector2(x, box.position.y), box.size), Color(color.lightened(0.55), 0.18))

	if show_boxes:
		draw_rect(Rect2(-w / 2.0, -h, w, h), HURTBOX_COLOR, false, 3.0)
		if hitbox.has_area():
			draw_rect(Rect2(hitbox.position - fighter.position, hitbox.size), HITBOX_COLOR)

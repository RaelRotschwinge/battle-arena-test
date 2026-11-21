# Draws one fighter as a simple shape (game design, "Fighters": a test fighter until M4).
extends Node2D

const Mode = preload("res://scripts/sim/fighter_state.gd").Mode

var fighter
var stats
var color := Color.WHITE
var label := ""
var _respawns := 0


# Called every tick after the simulation step.
func sync() -> void:
	position = fighter.position
	if fighter.respawns != _respawns:
		_respawns = fighter.respawns
		reset_physics_interpolation()
	queue_redraw()


func _draw() -> void:
	var w: float = stats.width
	var h: float = stats.height
	draw_rect(Rect2(-w / 2.0, -h, w, h), color)
	if fighter.mode == Mode.LEDGE:  # Hands on the ledge.
		draw_rect(Rect2(fighter.facing * w / 2.0 - 8.0, -h - 6.0, 16.0, 14.0), color.lightened(0.4))
	var eye := Vector2(fighter.facing * w * 0.22, -h * 0.75)
	draw_circle(eye, 8.0, Color.WHITE)
	draw_circle(eye + Vector2(fighter.facing * 3.0, 0.0), 4.0, Color.BLACK)
	draw_string(ThemeDB.fallback_font, Vector2(-w, -h - 14.0), label, HORIZONTAL_ALIGNMENT_CENTER,
			w * 2.0, 30, color)

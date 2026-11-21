# Draws the arena: solid platforms, thin platforms and, with the info overlay, the blast zone.
extends Node2D

const SOLID_COLOR := Color("3a3f4b")
const SOLID_TOP_COLOR := Color("5b6275")
const THIN_COLOR := Color("8a93a8")
const BLAST_COLOR := Color(1.0, 0.35, 0.35, 0.7)

var arena
var show_blast_zone := false:
	set(value):
		show_blast_zone = value
		queue_redraw()


func _draw() -> void:
	if arena == null:
		return
	for r: Rect2 in arena.solids:
		draw_rect(r, SOLID_COLOR)
		draw_rect(Rect2(r.position, Vector2(r.size.x, 8.0)), SOLID_TOP_COLOR)
	for r: Rect2 in arena.thin:
		draw_rect(r, THIN_COLOR)
	if show_blast_zone:
		draw_rect(arena.blast_zone, BLAST_COLOR, false, 6.0)

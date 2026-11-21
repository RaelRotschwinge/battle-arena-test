# Draws the arena in its colors: a sky from top to bottom, solid platforms with a light top edge,
# thin platforms, the path of a moving platform and, with the info overlay, the blast zone.
extends Node2D

const BLAST_COLOR := Color(1.0, 0.35, 0.35, 0.7)
const SKY_BANDS := 24

var arena
var show_blast_zone := false:
	set(value):
		show_blast_zone = value
		queue_redraw()


# Called every tick; only arenas with moving parts need drawing again.
func sync() -> void:
	if arena != null and arena.has_moving_parts():
		queue_redraw()


func _draw() -> void:
	if arena == null:
		return
	var colors: Dictionary = arena.colors
	var sky: Array = colors["sky"]
	var area: Rect2 = arena.blast_zone.grow(1200.0)
	for band in SKY_BANDS:  # The sky as bands from the top color to the bottom color.
		var t := float(band) / (SKY_BANDS - 1)
		var top: float = lerpf(area.position.y, area.end.y, float(band) / SKY_BANDS)
		draw_rect(Rect2(area.position.x, top, area.size.x, area.size.y / SKY_BANDS + 1.0),
				sky[0].lerp(sky[1], t))
	for r: Rect2 in arena.solids:
		draw_rect(r, colors["ground"])
		draw_rect(Rect2(r.position, Vector2(r.size.x, 10.0)), colors["ground_top"])
		draw_rect(Rect2(r.position.x, r.position.y + 10.0, r.size.x, 6.0),
				colors["ground"].darkened(0.25))
	for i in arena.thin.size():
		var r: Rect2 = arena.thin[i]
		var moving: bool = colors.has("moving") and i == arena.thin.size() - 1
		if moving:  # A faint line shows the path, with marks at both ends.
			var y := r.position.y + 8.0
			var left: float = arena.MIDDLE - arena.SWING - arena.WIDTH / 2.0
			var right: float = arena.MIDDLE + arena.SWING + arena.WIDTH / 2.0
			var path := Color(colors["moving"], 0.25)
			draw_line(Vector2(left, y), Vector2(right, y), path, 3.0)
			draw_line(Vector2(left, y - 12.0), Vector2(left, y + 12.0), path, 3.0)
			draw_line(Vector2(right, y - 12.0), Vector2(right, y + 12.0), path, 3.0)
		draw_rect(r, colors["moving"] if moving else colors["thin"])
		draw_rect(Rect2(r.position.x, r.end.y, r.size.x, 4.0), Color(0, 0, 0, 0.25))
	if show_blast_zone:
		draw_rect(arena.blast_zone, BLAST_COLOR, false, 6.0)

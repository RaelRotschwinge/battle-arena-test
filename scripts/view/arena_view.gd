# Draws the arena in its colors: a sky from top to bottom, solid platforms with a light top edge,
# thin platforms, the paths of moving platforms and, with the info overlay, the blast zone. With
# preview_area set it draws only that part, for the arena select screen.
extends Node2D

const BLAST_COLOR := Color(1.0, 0.35, 0.35, 0.7)
const SKY_BANDS := 24

var arena
var preview_area := Rect2()  # Not empty: draw the sky only here (a preview).
var show_blast_zone := false:
	set(value):
		show_blast_zone = value
		queue_redraw()


var _ticks := 0


# Called every tick; only arenas with moving parts or hazards need drawing again.
func sync() -> void:
	_ticks += 1
	if arena != null and (arena.has_moving_parts() or arena.has_hazards()):
		queue_redraw()


func _draw() -> void:
	if arena == null:
		return
	var colors: Dictionary = arena.colors
	var sky: Array = colors["sky"]
	var area: Rect2 = preview_area if preview_area.has_area() else arena.blast_zone.grow(1200.0)
	for band in SKY_BANDS:  # The sky as bands from the top color to the bottom color.
		var t := float(band) / (SKY_BANDS - 1)
		var top: float = lerpf(area.position.y, area.end.y, float(band) / SKY_BANDS)
		draw_rect(Rect2(area.position.x, top, area.size.x, area.size.y / SKY_BANDS + 1.0),
				sky[0].lerp(sky[1], t))
	for r: Rect2 in arena.solids:
		if preview_area.has_area():
			r = r.intersection(preview_area)
		draw_rect(r, colors["ground"])
		draw_rect(Rect2(r.position, Vector2(r.size.x, 10.0)), colors["ground_top"])
		draw_rect(Rect2(r.position.x, r.position.y + 10.0, r.size.x, 6.0),
				colors["ground"].darkened(0.25))
	var moving_color: Color = colors.get("moving", colors["thin"])
	for path in arena.paths:  # A faint line shows the way, with marks at both ends.
		var a: Vector2 = path["a"] + Vector2(0.0, 8.0)
		var b: Vector2 = path["b"] + Vector2(0.0, 8.0)
		var across := (b - a).normalized().orthogonal() * 12.0
		var line := Color(moving_color, 0.25)
		draw_line(a, b, line, 3.0)
		draw_line(a - across, a + across, line, 3.0)
		draw_line(b - across, b + across, line, 3.0)
	for i in arena.thin.size():
		var r: Rect2 = arena.thin[i]
		draw_rect(r, moving_color if arena.is_moving(i) else colors["thin"])
		draw_rect(Rect2(r.position.x, r.end.y, r.size.x, 4.0), Color(0, 0, 0, 0.25))
	if arena.has_hazards():
		_draw_vents(colors)
	if show_blast_zone:
		draw_rect(arena.blast_zone, BLAST_COLOR, false, 6.0)


# Kettle's vents: a grate in the floor that glows and puffs before a burst, then a column of
# steam; cold and dark with hazards off.
func _draw_vents(colors: Dictionary) -> void:
	var vent: Color = colors.get("vent", Color.ORANGE)
	var steam: Color = colors.get("steam", Color.WHITE)
	for v in arena.VENTS.size():
		var column: Rect2 = arena.vent_column(v)
		var phase: Array = arena.vent_phase(v)
		var floor_y := column.end.y
		var grate := Rect2(column.position.x + 20.0, floor_y - 4.0, column.size.x - 40.0, 10.0)
		var glow := 0.0
		match phase[0]:
			"warn":
				glow = 0.5 + 0.5 * sin(phase[1] * 0.4)
			"burst":
				glow = 1.0
		draw_rect(grate, Color("2a1f1f") if phase[0] == "off" else vent.darkened(0.6).lerp(vent, glow))
		if phase[0] == "warn":  # Puffs rise higher as the burst comes closer.
			for n in 3:
				var rise: float = fmod(phase[1] * 2.0 + n * 30.0, 90.0) * (0.4 + phase[1] / 90.0)
				draw_circle(Vector2(column.get_center().x + (n - 1) * 34.0, floor_y - 10.0 - rise),
						10.0 + n * 3.0, Color(steam, 0.35))
		elif phase[0] == "burst":
			var wobble := 8.0 * sin(phase[1] * 0.9)
			draw_rect(column.grow_individual(wobble, 0.0, -wobble, 0.0), Color(steam, 0.55))
			draw_rect(column.grow_individual(-30.0, 0.0, -30.0, 0.0), Color(1, 1, 1, 0.5))
		elif phase[0] == "idle" and _ticks % 40 < 20:
			draw_circle(Vector2(column.get_center().x, floor_y - 14.0), 6.0, Color(steam, 0.15))

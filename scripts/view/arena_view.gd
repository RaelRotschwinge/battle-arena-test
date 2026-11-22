# Draws an arena: a themed backdrop in parallax layers (backdrop_<arena>.gd) behind the stage in
# the look of arena_decor.gd (solid and thin platforms, ledges, the moving parts with their
# machinery, Kettle's vents), a fog that darkens toward the bottom blast line and, with the info
# overlay, the blast zone. In a match the layers follow the camera, the far ones slower and less
# zoomed; with preview_area set (arena select) they hold still as seen from its middle.
extends Node2D

const Kit := preload("res://scripts/view/backdrop_kit.gd")
const Decor := preload("res://scripts/view/arena_decor.gd")
const THEMES := {
	"pebble": preload("res://scripts/view/backdrop_pebble.gd"),
	"terraces": preload("res://scripts/view/backdrop_terraces.gd"),
	"ferry": preload("res://scripts/view/backdrop_ferry.gd"),
	"flatiron": preload("res://scripts/view/backdrop_flatiron.gd"),
	"cistern": preload("res://scripts/view/backdrop_cistern.gd"),
	"windlass": preload("res://scripts/view/backdrop_windlass.gd"),
	"kettle": preload("res://scripts/view/backdrop_kettle.gd"),
	"test_arena": preload("res://scripts/view/backdrop_lab.gd"),
}
const BLAST_COLOR := Color(1.0, 0.35, 0.35, 0.7)
const FAR_ZOOM := 1.0  # Far layers keep about this zoom whatever the camera does.
const PREVIEW_WIDTH := 1920.0  # A preview looks like a match view this wide.
const SMALL_PREVIEW := 0.3  # Previews drawn smaller than this scale have no ambient motion.

var arena:
	set(value):
		arena = value
		_build()
var preview_area := Rect2()  # Not empty: a preview showing this part of the arena.
var show_blast_zone := false:
	set(value):
		show_blast_zone = value
		queue_redraw()

var _time := 0.0  # Seconds, for the ambient motion only; the match never reads it.
var _theme
var _layers := []  # Per backdrop layer: [node, depth (1 fixed to the view, 0 the stage), animated].
var _last_center := Vector2.INF


# Called every tick; only arenas with moving parts or hazards need drawing again.
func sync() -> void:
	if arena != null and (arena.has_moving_parts() or arena.has_hazards()):
		queue_redraw()


func _build() -> void:
	for layer in _layers:
		remove_child(layer[0])
		layer[0].queue_free()
	_layers.clear()
	_theme = null
	if arena != null:
		var id: String = arena.colors.get("theme",
				arena.get_script().resource_path.get_file().get_basename())
		_theme = THEMES.get(id, THEMES["test_arena"]).new()
		_theme.arena = arena
		for spec: Array in _theme.layers():
			var node := Node2D.new()
			node.show_behind_parent = true
			var method: String = spec[2]
			node.draw.connect(func() -> void: _theme.call(method, node, _time))
			add_child(node)
			_layers.append([node, spec[0], spec[1]])
	_last_center = Vector2.INF
	_place_layers()
	queue_redraw()


func _physics_process(_delta: float) -> void:
	_place_layers()  # After the match moved its camera this tick (the parent runs first).


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	# Small previews (the arena select's tiles) keep a still backdrop: nine animated ones at once
	# cost more than a whole match.
	if preview_area.has_area() and get_global_transform().get_scale().x < SMALL_PREVIEW:
		return
	_time += delta
	for layer in _layers:
		if layer[2]:
			layer[0].queue_redraw()


# Each layer is shown as if a camera of its own looked at it: one that moves and zooms less the
# farther the layer is.
func _place_layers() -> void:
	var center := Kit.CENTER
	var zoom := 1.0
	if preview_area.has_area():
		center = preview_area.get_center()
		zoom = PREVIEW_WIDTH / preview_area.size.x
	elif is_inside_tree() and get_viewport().get_camera_2d() != null:
		var camera := get_viewport().get_camera_2d()
		center = camera.position + camera.offset
		zoom = camera.zoom.x
	var jumped := center.distance_to(_last_center) > 300.0
	_last_center = center
	for layer in _layers:
		var depth: float = layer[1]
		var s: float = lerpf(zoom, FAR_ZOOM, depth) / zoom
		var seen: Vector2 = Kit.CENTER + (center - Kit.CENTER) * (1.0 - depth)
		layer[0].scale = Vector2(s, s)
		layer[0].position = center - seen * s
		if jumped:
			layer[0].reset_physics_interpolation()


func _draw() -> void:
	if arena == null:
		return
	var colors: Dictionary = arena.colors
	if _theme.has_method("stage_back"):
		_theme.stage_back(self, _time)
	for r: Rect2 in arena.solids:
		Decor.solid(self, r, colors, _theme.style)
	Decor.ledges(self, arena.ledges, colors["ground_top"])
	_draw_fog()
	if not _theme.has_method("mover"):
		_draw_paths(colors.get("moving", colors["thin"]))
	for i in arena.thin.size():
		var r: Rect2 = arena.thin[i]
		if arena.is_moving(i) and _theme.has_method("mover"):
			_theme.mover(self, r)
		else:
			Decor.thin(self, r, colors.get("moving", colors["thin"]) if arena.is_moving(i)
					else colors["thin"], _theme.style.get("thin", "plank"))
	if _theme.has_method("stage_front"):
		_theme.stage_front(self, _time)
	if show_blast_zone:
		draw_rect(arena.blast_zone, BLAST_COLOR, false, 6.0)


# Below the stage everything fades into the theme's darkness, fully so at the bottom blast line:
# a fighter falling off stands out against it.
func _draw_fog() -> void:
	var top := -INF
	for r: Rect2 in arena.solids:
		top = maxf(top, r.position.y)
	var fog: Color = _theme.fog
	var zone: Rect2 = arena.blast_zone
	var x0: float = zone.position.x - 3000.0
	var width: float = zone.size.x + 6000.0
	var start: float = top + 100.0
	var middle: float = minf(start + 380.0, zone.end.y)
	Kit.band(self, Rect2(x0, start, width, middle - start), Color(fog, 0.0), Color(fog, 0.85))
	Kit.band(self, Rect2(x0, middle, width, zone.end.y - middle), Color(fog, 0.85),
			Color(fog, 0.96))
	draw_rect(Rect2(x0, zone.end.y, width, 3000.0), Color(fog, 0.96))


# A faint line shows the way of a moving platform, with marks at both ends.
func _draw_paths(color: Color) -> void:
	for path in arena.paths:
		var a: Vector2 = path["a"] + Vector2(0.0, 8.0)
		var b: Vector2 = path["b"] + Vector2(0.0, 8.0)
		var across := (b - a).normalized().orthogonal() * 12.0
		var line := Color(color, 0.25)
		draw_line(a, b, line, 3.0)
		draw_line(a - across, a + across, line, 3.0)
		draw_line(b - across, b + across, line, 3.0)

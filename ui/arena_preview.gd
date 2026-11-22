# A live miniature of an arena (game design, "Menus"): the arena's own drawing scaled to fit, its
# moving platforms moving and its hazards running. "random" shows a question mark.
extends Control

const ArenaList := preload("res://arenas/arena_list.gd")
const ArenaView := preload("res://scripts/view/arena_view.gd")

var arena_id := ""
var _view
var _tick := 0


func _init() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_view = ArenaView.new()
	add_child(_view)
	resized.connect(_fit)


func show_arena(id: String, hazards: bool = true) -> void:
	if id == arena_id and (_view.arena == null or _view.arena.hazards_on == hazards):
		return
	arena_id = id
	_view.arena = null if id == "random" else ArenaList.make(id)
	if _view.arena != null:
		_view.arena.hazards_on = hazards
	_view.visible = _view.arena != null
	_tick = 0
	_fit()
	queue_redraw()


func _physics_process(_delta: float) -> void:
	var arena = _view.arena
	if arena != null and (arena.has_moving_parts() or arena.has_hazards()) and is_visible_in_tree():
		_tick += 1
		arena.update(_tick, [])
		_view.sync()


# Scales the arena so its platforms fit, and widens the drawn sky to fill the whole control.
func _fit() -> void:
	if _view.arena == null or size.x <= 0.0 or size.y <= 0.0:
		return
	var area: Rect2 = _view.arena.view_rect()
	var s := minf(size.x / area.size.x, size.y / area.size.y)
	var shown := Rect2(area.get_center() - size / s / 2.0, size / s)
	_view.preview_area = shown
	_view.scale = Vector2(s, s)
	_view.position = -shown.position * s
	_view.queue_redraw()


func _draw() -> void:
	if arena_id != "random":
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color("232838"))
	var font := ThemeDB.fallback_font
	var font_size := int(size.y * 0.6)
	var at := Vector2(0.0, size.y / 2.0 + font_size * 0.35)
	draw_string(font, at, "?", HORIZONTAL_ALIGNMENT_CENTER, size.x, font_size, Color("ffd24a"))

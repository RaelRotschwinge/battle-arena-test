# A live miniature of an arena (game design, "Menus"): the arena's own drawing scaled to fit, its
# moving platforms moving and its hazards running. "random" shows a question mark.
extends Control

const ArenaList := preload("res://arenas/arena_list.gd")
const ArenaView := preload("res://scripts/view/arena_view.gd")
const UiDraw := preload("res://ui/ui_draw.gd")

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


func _process(_delta: float) -> void:
	if arena_id == "random" and is_visible_in_tree():
		queue_redraw()  # The question mark bobs.


# Random: slanted stripes in the player colors behind a big gold question mark.
func _draw() -> void:
	if arena_id != "random":
		return
	var top := Color("2b3146")
	var bottom := Color("161a26")
	draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0), size, Vector2(0, size.y)]),
			PackedColorArray([top, top, bottom, bottom]))
	var t := Time.get_ticks_msec() / 1000.0
	var band := size.y * 0.5
	for n in 4:
		var x := size.x * (0.1 + n * 0.25) + fposmod(t * 20.0, size.x * 0.25)
		var color := Color(UiDraw.PLAYER_COLORS[n], 0.1)
		draw_colored_polygon(PackedVector2Array([Vector2(x - band, size.y), Vector2(x, size.y),
				Vector2(x + band * 0.6, 0), Vector2(x - band * 0.4, 0)]), color)
	UiDraw.glow(self, size / 2.0, Vector2(size.y, size.y) * 0.6, Color(UiDraw.GOLD, 0.25))
	var font_size := int(size.y * 0.66)
	var bob := sin(t * 2.4) * size.y * 0.025
	var at := Vector2(0.0, size.y / 2.0 + font_size * 0.36 + bob)
	UiDraw.text(self, at, "?", font_size, UiDraw.GOLD, HORIZONTAL_ALIGNMENT_CENTER, size.x,
			UiDraw.bold(), maxi(font_size / 9, 6))

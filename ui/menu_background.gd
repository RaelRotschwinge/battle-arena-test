# The animated backdrop of the menu screens: a night sky with soft colored lights, far floating
# islands and drifting shapes. With heroes on (the main menu) it adds turning light rays and the
# fighters standing on a stage. Drawing only; set heroes before the node enters the tree.
extends Control

const UiDraw := preload("res://ui/ui_draw.gd")
const FighterFigure := preload("res://ui/fighter_figure.gd")
const FighterState := preload("res://scripts/sim/fighter_state.gd")
const Roster := preload("res://fighters/roster.gd")

const SKY_TOP := Color("0a0d18")
const SKY_BOTTOM := Color("1f2438")
const STAGE_TOP := Color("3b4560")
const STAGE_BOTTOM := Color("151927")
const RAY_CENTER := Vector2(0.5, 0.3)  # Where the rays start, as a share of the screen size.

var heroes := false
var hint := ""  # A line at the bottom of the screen.
var title := ""  # A screen title on a band along the top.
var _t := 0.0
var _shapes := []  # Per shape: [x, y, rise speed, size, spin, kind, color].
var _islands := []  # Per island: [x share, y share, width, bob phase].
var _embers := []  # Per ember: [x share, phase, speed].
var _figures := []  # [figure, x share or negative pixels from the right, floor offset, flies]
var _live: Control  # Redrawn every frame.
var _top: Control  # Redrawn when the size changes.
var _c: CanvasItem  # The layer being drawn.


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rng := RandomNumberGenerator.new()
	rng.seed = 11  # The same sky every time.
	for n in 26:
		_shapes.append([rng.randf(), rng.randf(), rng.randf_range(8.0, 26.0),
				rng.randf_range(10.0, 40.0), rng.randf_range(-0.5, 0.5), n % 3,
				UiDraw.PLAYER_COLORS[n % 4]])
	for n in 6:
		_islands.append([(n + 0.5) / 6.0 + rng.randf_range(-0.05, 0.05), rng.randf_range(0.2, 0.62),
				rng.randf_range(110.0, 240.0), rng.randf() * TAU])
	for n in 30:
		_embers.append([rng.randf(), rng.randf(), rng.randf_range(0.04, 0.1)])
	_live = _layer(_draw_live)
	_top = _layer(_draw_top)
	resized.connect(_top.queue_redraw)
	if heroes:
		_add_hero("kade", 0, 1, 0.17, 0.0, false)
		_add_hero("pip", 1, 1, 0.29, -150.0, true)
		_add_hero("brum", 2, -1, 0.82, 0.0, false)


func _add_hero(id: String, slot: int, facing: int, x: float, lift: float, flies: bool) -> void:
	var figure := FighterFigure.new()
	var f := FighterState.new()
	f.stats = Roster.make(id)
	f.facing = facing
	f.mode = FighterState.Mode.AIR if flies else FighterState.Mode.GROUND
	f.velocity = Vector2(0.0, -2.0) if flies else Vector2.ZERO  # Rising: Pip flaps.
	figure.f = f
	figure.color = UiDraw.PLAYER_COLORS[slot]
	figure.size = 2.6
	add_child(figure)
	_figures.append([figure, x, lift, flies])


func _process(delta: float) -> void:
	_t += delta
	var floor_y := _stage_top()
	for hero in _figures:
		var bob: float = sin(_t * 2.2) * 14.0 if hero[3] else 0.0
		hero[0].position = Vector2(size.x * hero[1], floor_y + hero[2] + bob)
	_live.queue_redraw()


func _layer(drawer: Callable) -> Control:
	var layer := Control.new()
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.draw.connect(drawer)
	add_child(layer)
	return layer


func _stage_top() -> float:
	return size.y - 150.0


# Three layers, so only what moves is drawn every frame: the sky (here), the moving lights and
# shapes (_live), and the stage, title and hint on top (_top); the fighters stand above them.
func _draw() -> void:
	_c = self
	var w := size.x
	var h := size.y
	_c.draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(w, 0), Vector2(w, h), Vector2(0, h)]),
			PackedColorArray([SKY_TOP, SKY_TOP, SKY_BOTTOM, SKY_BOTTOM]))


func _draw_live() -> void:
	_c = _live
	var w := size.x
	var h := size.y
	# Soft colored lights drifting slowly, one per player color.
	for n in 4:
		var at := Vector2(w * (0.2 + 0.6 * (0.5 + 0.5 * sin(_t * 0.07 + n * 1.7))),
				h * (0.35 + 0.3 * sin(_t * 0.05 + n * 2.3)))
		UiDraw.glow(_c, at, Vector2(560, 460), Color(UiDraw.PLAYER_COLORS[n], 0.09))
	if heroes:
		_rays(Vector2(w, h) * RAY_CENTER)
	if heroes:  # Behind the panels of the other screens they would only clutter.
		_draw_islands(w, h)
	_draw_shapes(w, h)
	_draw_embers(w, h)


func _draw_top() -> void:
	_c = _top
	var w := size.x
	var h := size.y
	if heroes:
		_stage(w, h)
	if title != "":
		_title_band(w)
	if hint != "":
		UiDraw.text(_c, Vector2(0, h - 34), hint, 26, Color(UiDraw.DIM, 0.9),
				HORIZONTAL_ALIGNMENT_CENTER, w)


# Long faint rays turning slowly behind the title.
func _rays(center: Vector2) -> void:
	var inner := Color(1.0, 0.86, 0.55, 0.07)
	var outer := Color(1.0, 0.86, 0.55, 0.0)
	for n in 12:
		var turn := _t * 0.04 + TAU * n / 12.0
		var a := center + Vector2(cos(turn), sin(turn)) * 1600.0
		var b := center + Vector2(cos(turn + 0.16), sin(turn + 0.16)) * 1600.0
		_c.draw_primitive(PackedVector2Array([center, a, b]), PackedColorArray([inner, outer, outer]),
				PackedVector2Array())


# Far floating islands: hazy, no outlines, bobbing slowly.
func _draw_islands(w: float, h: float) -> void:
	for island in _islands:
		var width: float = island[2]
		var at := Vector2(w * island[0], h * island[1] + sin(_t * 0.4 + island[3]) * 8.0)
		var haze: float = 0.25 + island[1] * 0.4
		var top := SKY_BOTTOM.lerp(Color("4a5574"), haze)
		var under := SKY_BOTTOM.lerp(Color("2a3044"), haze)
		# The rock under the top: a rounded, uneven bowl tapering to a point.
		var rock := PackedVector2Array()
		for n in 11:
			var turn := PI * n / 10.0
			var depth := width * (0.18 + 0.22 * sin(turn) * (0.7 + 0.3 * sin(n * 2.3 + island[3])))
			rock.append(at + Vector2(cos(turn) * width / 2.0, depth * sin(turn)))
		_c.draw_colored_polygon(rock, under)
		UiDraw.panel(_c, Rect2(at - Vector2(width / 2.0, 7.0), Vector2(width, 14.0)), 7.0,
				top.lightened(0.12), top)


# Diamonds, rings and crosses rising slowly in the player colors, very faint.
func _draw_shapes(w: float, h: float) -> void:
	for shape in _shapes:
		var travel := h + 200.0
		var y := fposmod(shape[1] * travel - _t * shape[2], travel) - 100.0
		var at := Vector2(shape[0] * w + sin(_t * 0.3 + shape[1] * 9.0) * 30.0, y)
		var r: float = shape[3]
		var turn: float = _t * shape[4] + shape[1] * 6.0
		var color := Color(shape[6], 0.1)
		match shape[5]:
			0:
				var points := PackedVector2Array()
				for n in 4:
					points.append(at + Vector2(r, 0).rotated(turn + n * PI / 2.0))
				_c.draw_colored_polygon(points, color)
			1:
				_c.draw_arc(at, r, 0.0, TAU, 32, color, 4.0, true)
			_:
				for n in 2:
					var d := Vector2(r, 0).rotated(turn + n * PI / 2.0)
					_c.draw_line(at - d, at + d, color, 5.0, true)


# The stage the fighters stand on: a broad slab with a lit top edge, running off the bottom.
func _stage(w: float, h: float) -> void:
	var top := _stage_top()
	for hero in _figures:  # A spotlight behind each fighter in its player color.
		var x: float = w * hero[1]
		UiDraw.glow(_c, Vector2(x, top - 140.0), Vector2(260, 300),
				Color(hero[0].color, 0.22))
	var points := PackedVector2Array([Vector2(70, top), Vector2(w - 70, top),
			Vector2(w - 150, h + 10), Vector2(150, h + 10)])
	var colors := PackedColorArray([STAGE_TOP, STAGE_TOP, STAGE_BOTTOM, STAGE_BOTTOM])
	_c.draw_polygon(points, colors)
	_c.draw_polyline(PackedVector2Array([points[3], points[0], points[1], points[2]]), UiDraw.INK,
			6.0, true)
	_c.draw_line(Vector2(76, top + 5), Vector2(w - 76, top + 5), Color("6b7899"), 5.0, true)
	for n in 9:  # Seams in the stone.
		var x := 70.0 + (w - 140.0) * (n + 0.5) / 9.0
		_c.draw_line(Vector2(x, top + 18), Vector2(x - (x - w / 2.0) * 0.08, h), Color(0, 0, 0, 0.18),
				3.0, true)


# Embers rising from the bottom, fading as they climb.
func _draw_embers(w: float, h: float) -> void:
	for ember in _embers:
		var life := fposmod(ember[1] + _t * ember[2], 1.0)
		var at := Vector2(w * ember[0] + sin(_t + ember[1] * 20.0) * 20.0, h - life * h * 0.7)
		var alpha := sin(life * PI) * (0.5 if heroes else 0.3)
		_c.draw_circle(at, 3.0, Color(1.0, 0.8, 0.45, alpha), true, -1.0, true)


# The title of a screen on a dark band with a gold edge and slanted accents in the player colors.
func _title_band(w: float) -> void:
	var dark := Color(0.04, 0.05, 0.08, 0.75)
	_c.draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(w, 0), Vector2(w, 100), Vector2(0, 100)]),
			PackedColorArray([dark, dark, Color(dark, 0.35), Color(dark, 0.35)]))
	var font := UiDraw.bold()
	var half := UiDraw.text_width(title, 60, font) / 2.0 + 40.0
	var cx := minf(w, 1920.0) / 2.0  # The screens lay out on 1920 wide; wider windows add right.
	for n in 4:  # Two slanted bars on each side of the title.
		var side := -1.0 if n < 2 else 1.0
		var x := cx + side * (half + (n % 2) * 26.0)
		var color: Color = UiDraw.PLAYER_COLORS[n]
		_c.draw_colored_polygon(PackedVector2Array([Vector2(x - 6, 74), Vector2(x + 8, 74),
				Vector2(x + 22, 30), Vector2(x + 8, 30)]), color)
	UiDraw.text(_c, Vector2(cx - half, 76), title, 60, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER,
			half * 2.0, font, 12)
	_c.draw_line(Vector2(cx - half, 96), Vector2(cx + half, 96), Color(UiDraw.GOLD, 0.8), 4.0, true)
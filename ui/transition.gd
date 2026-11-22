# The wipe between screens: a dark slanted band with a gold edge sweeps over the screen, the
# screen changes under full cover, then the band sweeps on and off. go() starts it; covering is
# true until the change, so the caller ignores menu input meanwhile.
extends CanvasLayer

const UiDraw := preload("res://ui/ui_draw.gd")

const COVER_TIME := 0.1  # Short, so a quick player is not held up.
const REVEAL_TIME := 0.24
const SLANT := 220.0
const BAND := Color("11131a")

var covering := false
var _then := Callable()
var _phase := ""  # "cover", "reveal" or "" when idle.
var _t := 0.0
var _canvas: Control


func _init() -> void:
	layer = 50
	_canvas = Control.new()
	_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_draw_band)
	add_child(_canvas)


# Covers the screen, calls then, uncovers. A call while covering only replaces then.
func go(then: Callable) -> void:
	_then = then
	if _phase != "cover":
		_phase = "cover"
		_t = 0.0
	covering = true


# Starts fully covered and uncovers, for the first screen.
func reveal() -> void:
	_phase = "reveal"
	_t = 0.0


func _process(delta: float) -> void:
	if _phase == "":
		return
	_t += delta
	if _phase == "cover" and _t >= COVER_TIME:
		_phase = "reveal"
		_t = 0.0
		covering = false
		var then := _then
		_then = Callable()
		then.call()
	elif _phase == "reveal" and _t >= REVEAL_TIME:
		_phase = ""
	_canvas.queue_redraw()


# The band's left and right edges as shares of the screen width plus the slant.
func _draw_band() -> void:
	if _phase == "":
		return
	var w := _canvas.size.x + SLANT
	var left := 0.0
	var right := 0.0
	if _phase == "cover":
		right = UiDraw.out_cubic(_t / COVER_TIME) * w
	else:
		left = UiDraw.out_cubic(_t / REVEAL_TIME) * w
		right = w + SLANT
	var h := _canvas.size.y
	_band(left - SLANT, right - SLANT, h, BAND)
	# A gold edge on the moving side, then a thin line of the player colors.
	if _phase == "cover":
		_band(right - SLANT - 18.0, right - SLANT, h, UiDraw.GOLD)
	else:
		_band(left - SLANT, left - SLANT + 18.0, h, UiDraw.GOLD)
		for n in 4:
			var x := left - SLANT + 18.0 + n * 8.0
			_band(x, x + 8.0, h, UiDraw.PLAYER_COLORS[n])


# A slanted band from x0 to x1 at the bottom, leaning right toward the top.
func _band(x0: float, x1: float, h: float, color: Color) -> void:
	if x1 <= x0:
		return
	_canvas.draw_colored_polygon(PackedVector2Array([Vector2(x0, h), Vector2(x1, h),
			Vector2(x1 + SLANT, 0.0), Vector2(x0 + SLANT, 0.0)]), color)

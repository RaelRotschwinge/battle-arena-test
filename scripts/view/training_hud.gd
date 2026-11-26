# The training panel, at the top right (the F1 info takes the top left): the last combo on the
# dummy (its hits and their damage; gold while it goes on, white once the dummy got free), the
# dummy's damage and behavior, and the training keys. training_view.gd sets the values.
extends CanvasLayer

const UiDraw := preload("res://ui/ui_draw.gd")

const SIZE := Vector2(420, 270)
const MARGIN := 28.0
const PAD := 26.0
const KEYS := "R / F5: reset      Esc / Start: menu      F1: hitboxes"
const POP_TIME := 0.35

var dummy  # The dummy's fighter state.
var behavior := ""
var combo := 0  # Hits of the last combo, 0 before the first hit.
var combo_damage := 0.0
var live := false  # The combo goes on: the dummy has not got free yet.
var _panel: Control
var _pop := POP_TIME  # Seconds since the combo grew.


func _ready() -> void:
	layer = 2  # With the HUD, under the info overlay and the menus.
	_panel = Control.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.anchor_left = 1.0
	_panel.anchor_right = 1.0
	_panel.offset_left = -MARGIN - SIZE.x
	_panel.offset_right = -MARGIN
	_panel.offset_top = MARGIN
	_panel.offset_bottom = MARGIN + SIZE.y
	_panel.draw.connect(_draw_panel)
	add_child(_panel)


# The combo got a hit: its number pops.
func grew() -> void:
	_pop = 0.0


func _process(delta: float) -> void:
	_pop += delta
	_panel.queue_redraw()


func _draw_panel() -> void:
	var c := _panel
	var right := SIZE.x - PAD * 2.0
	UiDraw.panel(c, Rect2(Vector2.ZERO, SIZE), 22.0, Color(UiDraw.PANEL_TOP, 0.93),
			Color(UiDraw.PANEL_BOTTOM, 0.93), Color("454e6a"), 2.0)
	UiDraw.text(c, Vector2(PAD, 42), "TRAINING", 22, UiDraw.GOLD, HORIZONTAL_ALIGNMENT_LEFT,
			-1.0, UiDraw.bold(), 6)
	UiDraw.text(c, Vector2(PAD, 42), "Dummy: %s" % behavior, 22, UiDraw.DIM,
			HORIZONTAL_ALIGNMENT_RIGHT, right, null, 6)
	var tone: Color = UiDraw.GOLD if live else Color.WHITE
	var t := clampf(_pop / POP_TIME, 0.0, 1.0)
	var grow := 1.0 + 0.3 * (1.0 - t) * (1.0 - t)
	var number := str(combo)
	var width := UiDraw.text_width(number, 80, UiDraw.bold())
	c.draw_set_transform(Vector2(PAD + width / 2.0, 104), 0.0, Vector2(grow, grow))
	UiDraw.text(c, Vector2(-width / 2.0, 30), number, 80, tone, HORIZONTAL_ALIGNMENT_LEFT, -1.0,
			UiDraw.bold(), 12)
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	UiDraw.text(c, Vector2(PAD + width + 16.0, 134), "hit combo" if combo != 1 else "hit", 28,
			Color(tone, 0.85), HORIZONTAL_ALIGNMENT_LEFT, -1.0, null, 6)
	_row(c, 186, "Combo damage", "%d %%" % int(combo_damage))
	_row(c, 224, "Dummy damage", "%d %%" % int(dummy.damage) if dummy != null else "")
	UiDraw.text(c, Vector2(PAD, 256), KEYS, 17, Color(UiDraw.DIM, 0.85),
			HORIZONTAL_ALIGNMENT_LEFT, -1.0, null, 4)


func _row(c: Control, base: float, title: String, value: String) -> void:
	UiDraw.text(c, Vector2(PAD, base), title, 24, Color("c3c8d6"), HORIZONTAL_ALIGNMENT_LEFT,
			-1.0, null, 6)
	UiDraw.text(c, Vector2(PAD, base), value, 28, Color.WHITE, HORIZONTAL_ALIGNMENT_RIGHT,
			SIZE.x - PAD * 2.0, UiDraw.bold(), 6)

# One player's panel on the fighter select screen (game design, "Menus"): who plays it, the
# fighter as it looks in the match, its name, role and difficulty, its stat sheet, one line about
# it, and its special with this player's own key. Empty panels ask to join; computer panels show
# the fighter the computer plays.
extends Control

const Roster := preload("res://fighters/roster.gd")
const StatSheet := preload("res://fighters/stat_sheet.gd")
const FighterState := preload("res://scripts/sim/fighter_state.gd")
const FighterLook := preload("res://scripts/view/fighter_look.gd")

const SIZE := Vector2(430, 820)
const BACK := Color("232838")
const DIM := Color("9aa0b0")
const FLOOR_Y := 330.0
const FIGURE_SCALE := 2.0

static var _stats := {}  # Roster id -> stats, made once.

var state := "empty"  # "empty", "player" or "cpu".
var color := Color.WHITE  # The slot's color.
var title := ""
var fighter := ""  # A roster id or "random".
var shown_ready := false
var key := ""  # The player's special key, as shown.
var hint := ""
var _figure: Figure


class Figure extends Node2D:
	var f
	var color := Color.WHITE
	var ticks := 0

	func _draw() -> void:
		if f != null:
			FighterLook.draw(self, f, color, Color.WHITE, Vector2.ZERO, ticks)


func _init() -> void:
	size = SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_figure = Figure.new()
	_figure.position = Vector2(SIZE.x / 2.0, FLOOR_Y)
	_figure.scale = Vector2(FIGURE_SCALE, FIGURE_SCALE)
	add_child(_figure)


func show_card(new_state: String, new_title: String, new_fighter: String, is_ready: bool,
		new_key: String, new_hint: String) -> void:
	var changed: bool = [state, title, fighter, shown_ready, key, hint] != [new_state, new_title,
			new_fighter, is_ready, new_key, new_hint]
	state = new_state
	title = new_title
	fighter = new_fighter
	shown_ready = is_ready
	key = new_key
	hint = new_hint
	if not changed:
		return
	_figure.visible = state != "empty" and fighter != "random" and fighter != ""
	if _figure.visible:
		var f := FighterState.new()
		f.stats = stats_of(fighter)
		f.mode = FighterState.Mode.GROUND
		_figure.f = f
		_figure.color = color
		_figure.queue_redraw()
	queue_redraw()


static func stats_of(id: String):
	if not _stats.has(id):
		_stats[id] = Roster.make(id)
	return _stats[id]


func _draw() -> void:
	var font := ThemeDB.fallback_font
	var w := SIZE.x
	var alpha := 0.45 if state == "empty" else 1.0
	draw_rect(Rect2(Vector2.ZERO, SIZE), Color(BACK, 0.9 * alpha))
	draw_rect(Rect2(0, 0, w, 56), Color(color, alpha) if state == "player" else Color("3a4052"))
	if shown_ready:
		draw_rect(Rect2(Vector2.ZERO, SIZE), color, false, 6.0)
	_text(font, Vector2(18, 40), title, 28, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, w - 36)
	if shown_ready:
		_text(font, Vector2(18, 40), "READY", 28, Color.WHITE, HORIZONTAL_ALIGNMENT_RIGHT, w - 36)
	if state == "empty":
		_text(font, Vector2(0, 360), "Join", 52, Color.WHITE)
		_text(font, Vector2(30, 420), hint, 26, DIM, HORIZONTAL_ALIGNMENT_CENTER, w - 60, 3)
		return
	draw_line(Vector2(60, FLOOR_Y), Vector2(w - 60, FLOOR_Y), Color("3a4052"), 4.0)
	var arrows := state == "player" and not shown_ready
	var shown := "?" if fighter == "random" else Roster.display_name(fighter)
	_text(font, Vector2(0, 398), ("<  %s  >" if arrows else "%s") % shown, 46, Color.WHITE)
	if fighter == "random":
		_text(font, Vector2(0, 250), "?", 160, Color("ffd24a"))
		_text(font, Vector2(30, 470), "A new fighter every match, a surprise for everyone.", 26,
				DIM, HORIZONTAL_ALIGNMENT_CENTER, w - 60, 3)
		_text(font, Vector2(0, 800), hint, 24, DIM)
		return
	var s = stats_of(fighter)
	var info: Dictionary = s.info
	_text(font, Vector2(30, 444), info.get("role", ""), 26, DIM, HORIZONTAL_ALIGNMENT_LEFT, 250)
	for n in 3:  # Difficulty: filled stars of three.
		_star(Vector2(w - 110 + n * 34, 434), 13.0, n < info.get("difficulty", 1))
	var pips := StatSheet.pips(s)
	for row in StatSheet.NAMES.size():
		var y := 478.0 + row * 34.0
		_text(font, Vector2(30, y + 8), StatSheet.NAMES[row], 24, Color.WHITE,
				HORIZONTAL_ALIGNMENT_LEFT, 150)
		for p in 5:
			var pip := Rect2(190 + p * 44, y - 12, 36, 20)
			draw_rect(pip, color if p < pips[row] else Color("3a4052"))
	_text(font, Vector2(30, 646), info.get("line", ""), 23, DIM, HORIZONTAL_ALIGNMENT_LEFT,
			w - 60, 2)
	_text(font, Vector2(30, 706), "Special:  " + info.get("special", ""), 28, Color("ffd24a"),
			HORIZONTAL_ALIGNMENT_LEFT, 300)
	if key != "":
		var chip := font.get_string_size(key, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x + 24.0
		draw_rect(Rect2(w - 30 - chip, 680, chip, 36), Color("3a4052"))
		_text(font, Vector2(w - 30 - chip, 706), key, 24, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER,
				chip)
	var how: String = info.get("special_how", "")
	_text(font, Vector2(30, 740), how.substr(0, 1).to_upper() + how.substr(1), 22, Color.WHITE,
			HORIZONTAL_ALIGNMENT_LEFT, w - 60, 2)
	_text(font, Vector2(0, 812), hint, 22, DIM)


func _text(font: Font, at: Vector2, text: String, font_size: int, color_: Color,
		align := HORIZONTAL_ALIGNMENT_CENTER, width := -1.0, lines := 1) -> void:
	var span: float = width if width > 0.0 else SIZE.x - at.x * 2.0
	if lines > 1:
		draw_multiline_string_outline(font, at, text, align, span, font_size, lines, 6,
				Color(0, 0, 0, 0.8))
		draw_multiline_string(font, at, text, align, span, font_size, lines, color_)
	else:
		draw_string_outline(font, at, text, align, span, font_size, 6, Color(0, 0, 0, 0.8))
		draw_string(font, at, text, align, span, font_size, color_)


func _star(at: Vector2, radius: float, filled: bool) -> void:
	var points := PackedVector2Array()
	for n in 10:
		var turn := -PI / 2.0 + TAU * n / 10.0
		var r := radius if n % 2 == 0 else radius * 0.45
		points.append(at + Vector2(cos(turn), sin(turn)) * r)
	if filled:
		draw_colored_polygon(points, Color("ffd24a"))
	else:
		points.append(points[0])
		draw_polyline(points, Color("ffd24a"), 2.0)

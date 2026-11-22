# A dimmed screen with a title, a text and a menu list, for the pause and results screens and the
# menus. Build it with show_menu(); handle() returns what was chosen (menu_list.gd).
#
# look picks the style before show_menu(): "card" (default: a card that pops in, with the title on
# a slanted banner in the title color), "logo" (the main menu: the title logo, no card) or "page"
# (a full page over the menu backdrop: banner, content, menu). Text made of the results lines of
# match_view.gd becomes a table, with the winner's fighter beside it in a victory pose under
# confetti in the winner's color (a neutral emblem for a draw).
extends CanvasLayer

const MenuList := preload("res://ui/menu_list.gd")
const UiDraw := preload("res://ui/ui_draw.gd")
const Logo := preload("res://ui/logo.gd")
const Roster := preload("res://fighters/roster.gd")
const FighterState := preload("res://scripts/sim/fighter_state.gd")
const FighterFigure := preload("res://ui/fighter_figure.gd")

const CARD := Color("1c2131")
const NEUTRAL_BANNER := Color("3a4462")
const RESULTS_LINE := "^(.+?)  (.+?)     KOs (\\d+)   falls (\\d+)   self-KOs (\\d+)   " \
		+ "damage dealt (\\d+) %$"

var menu: MenuList
var look := "card"
var _root: Control
var _dim: ColorRect
var _card: PanelContainer
var _card_style: StyleBoxFlat
var _banner: PanelContainer
var _banner_style: StyleBoxFlat
var _title: Label
var _text: Label
var _table: ResultsTable
var _results: HBoxContainer  # The winner showcase and the table.
var _showcase: Showcase
var _holder: CenterContainer  # Holds the content of a page.
var _logo: Logo
var _t := 0.0


# The results as a table: player, fighter, KOs, falls, self-KOs, damage dealt. The rows slide in
# one after the other; the winner's row is lit in its color.
class ResultsTable extends Control:
	const HEADS := ["Player", "Fighter", "KOs", "Falls", "Self-KOs", "Damage dealt"]
	const WIDTHS := [190.0, 190.0, 120.0, 120.0, 150.0, 210.0]
	const HEAD_HEIGHT := 46.0
	const ROW := 60.0

	var rows := []  # Per row: [player, fighter, kos, falls, self-KOs, damage].
	var winner := ""  # The winner's player label, "" for a draw.
	var t := 0.0

	func set_rows(new_rows: Array, new_winner: String) -> void:
		rows = new_rows
		winner = new_winner
		var width := 0.0
		for w in WIDTHS:
			width += w
		custom_minimum_size = Vector2(width, HEAD_HEIGHT + rows.size() * ROW)

	func _process(_delta: float) -> void:
		if is_visible_in_tree():
			queue_redraw()

	func _draw() -> void:
		var x := 0.0
		for c in HEADS.size():
			var align := HORIZONTAL_ALIGNMENT_LEFT if c < 2 else HORIZONTAL_ALIGNMENT_CENTER
			UiDraw.text(self, Vector2(x + (16.0 if c < 2 else 0.0), 30), HEADS[c].to_upper(), 20,
					UiDraw.DIM, align, WIDTHS[c] - (16.0 if c < 2 else 0.0), null, 0)
			x += WIDTHS[c]
		draw_line(Vector2(0, HEAD_HEIGHT - 4), Vector2(size.x, HEAD_HEIGHT - 4), UiDraw.SLOT, 2.0)
		for r in rows.size():
			_row(r, UiDraw.out_cubic((t - 0.12 - r * 0.07) / 0.3))

	func _row(r: int, shown: float) -> void:
		if shown <= 0.0:
			return
		var row: Array = rows[r]
		var color: Color = UiDraw.PLAYER_COLORS[r % UiDraw.PLAYER_COLORS.size()]
		var top := HEAD_HEIGHT + r * ROW
		var slide := (1.0 - shown) * 60.0
		var rect := Rect2(slide + 2.0, top + 5.0, size.x - 4.0, ROW - 10.0)
		var won: bool = row[0] == winner
		if won:
			UiDraw.panel(self, rect, 12.0, Color(color, 0.34 * shown), Color(color, 0.16 * shown),
					Color(color, shown), 2.0)
		elif r % 2 == 0:
			UiDraw.panel(self, rect, 12.0, Color(1, 1, 1, 0.05 * shown), Color(1, 1, 1, 0.03 * shown))
		var base := UiDraw.baseline(top, ROW, 28)
		draw_circle(Vector2(slide + 26.0, top + ROW / 2.0), 9.0, Color(color, shown), true, -1.0,
				true)
		var font := UiDraw.bold()
		UiDraw.text(self, Vector2(slide + 46.0, base), row[0], 28, Color(color.lightened(0.15),
				shown), HORIZONTAL_ALIGNMENT_LEFT, WIDTHS[0] - 46.0, font, 6)
		if won:
			_crown(Vector2(slide + 46.0 + UiDraw.text_width(row[0], 28, font) + 24.0,
					top + ROW / 2.0 - 2.0), shown)
		var x: float = WIDTHS[0]
		UiDraw.text(self, Vector2(slide + x + 16.0, base), row[1], 28, Color(1, 1, 1, shown),
				HORIZONTAL_ALIGNMENT_LEFT, WIDTHS[1] - 16.0, null, 6)
		x += WIDTHS[1]
		for c in range(2, 6):
			var value: String = row[c] + (" %" if c == 5 else "")
			var faint: bool = row[c] == "0"
			UiDraw.text(self, Vector2(slide + x, base), value, 30, Color(1, 1, 1,
					shown * (0.45 if faint else 1.0)), HORIZONTAL_ALIGNMENT_CENTER, WIDTHS[c], font, 6)
			x += WIDTHS[c]

	# A small gold crown for the winner.
	func _crown(at: Vector2, alpha: float) -> void:
		var points := PackedVector2Array([at + Vector2(-16, 10), at + Vector2(-16, -6),
				at + Vector2(-8, 2), at + Vector2(0, -12), at + Vector2(8, 2), at + Vector2(16, -6),
				at + Vector2(16, 10)])
		draw_colored_polygon(points, Color(UiDraw.GOLD, alpha))
		points.append(points[0])
		draw_polyline(points, Color(UiDraw.INK, alpha), 3.0, true)


# The winner on a lit floor: its fighter plays its uppercut once, then breathes; a crown bobs
# above and confetti in the winner's color falls. A draw shows two crossed blades instead.
class Showcase extends Control:
	const SIZE := Vector2(300, 330)
	const FEET := 280.0

	var color := Color.WHITE
	var won := false
	var figure: FighterFigure
	var _t := 0.0
	var _posed := false
	var _confetti := []  # Per piece: [x share, phase, fall speed, spin, sway, color index].

	func _init() -> void:
		custom_minimum_size = SIZE
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		figure = FighterFigure.new()
		figure.position = Vector2(SIZE.x / 2.0, FEET)
		figure.size = 1.7
		add_child(figure)
		var rng := RandomNumberGenerator.new()
		rng.seed = 5
		for n in 40:
			_confetti.append([rng.randf(), rng.randf(), rng.randf_range(0.35, 0.6),
					rng.randf_range(-6.0, 6.0), rng.randf() * TAU, n % 4])

	# id: the winner's roster id, "" for a draw.
	func show_winner(id: String, new_color: Color) -> void:
		won = id != ""
		color = new_color
		_t = 0.0
		_posed = false
		figure.visible = won
		if won:
			var f := FighterState.new()
			f.stats = Roster.make(id)
			f.mode = FighterState.Mode.GROUND
			figure.f = f
			figure.color = color

	func _process(delta: float) -> void:
		if not is_visible_in_tree():
			return
		_t += delta
		if won and not _posed and _t > 0.35:  # After the card has popped in.
			_posed = true
			figure.play("up")
			figure.pop()
		queue_redraw()

	func _draw() -> void:
		var cx := SIZE.x / 2.0
		UiDraw.glow(self, Vector2(cx, FEET - 110.0), Vector2(170, 190),
				Color(color, 0.3 if won else 0.12))
		var disc := PackedVector2Array()
		for n in 40:
			var turn := TAU * n / 40.0
			disc.append(Vector2(cx + cos(turn) * 120.0, FEET + 6.0 + sin(turn) * 20.0))
		draw_colored_polygon(disc, Color("141824"))
		disc.append(disc[0])
		draw_polyline(disc, Color(color, 0.7), 3.0, true)
		if not won:
			_blades(Vector2(cx, FEET - 110.0))
			return
		var bob := sin(_t * 3.0) * 6.0
		_crown(Vector2(cx, 34.0 + bob), 1.6)
		var palette := [color, color.lightened(0.45), UiDraw.GOLD, Color.WHITE]
		for piece in _confetti:
			var fall := fposmod(piece[1] + _t * piece[2], 1.0)
			var at := Vector2(SIZE.x * piece[0] + sin(_t * 2.0 + piece[4]) * 16.0,
					-40.0 + fall * (SIZE.y + 20.0))
			var alpha := clampf(_t * 3.0, 0.0, 1.0) * (1.0 - smoothstep(0.8, 1.0, fall))
			var c: Color = palette[piece[5]]
			draw_set_transform(at, _t * piece[3] + piece[4], Vector2(1.0, absf(sin(_t * 4.0
					+ piece[4])) * 0.8 + 0.2))
			draw_rect(Rect2(-5, -3, 10, 6), Color(c, alpha))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	func _crown(at: Vector2, s: float) -> void:
		var points := PackedVector2Array()
		for p in [Vector2(-16, 10), Vector2(-16, -6), Vector2(-8, 2), Vector2(0, -12), Vector2(8, 2),
				Vector2(16, -6), Vector2(16, 10)]:
			points.append(at + p * s)
		UiDraw.glow(self, at, Vector2(50, 40), Color(UiDraw.GOLD, 0.35))
		draw_colored_polygon(points, UiDraw.GOLD)
		points.append(points[0])
		draw_polyline(points, UiDraw.INK, 4.0, true)

	# A draw: two crossed blades in a neutral steel.
	func _blades(at: Vector2) -> void:
		for side in [-1.0, 1.0]:
			var tip: Vector2 = at + Vector2(side * 70.0, -70.0)
			var hilt: Vector2 = at + Vector2(-side * 60.0, 60.0)
			draw_line(hilt, tip, UiDraw.INK, 22.0, true)
			draw_line(hilt, tip, Color("c3c8d6"), 14.0, true)
			var guard: Vector2 = hilt.lerp(tip, 0.18)
			var across: Vector2 = (tip - hilt).normalized().orthogonal() * 24.0
			draw_line(guard - across, guard + across, UiDraw.INK, 14.0, true)
			draw_line(guard - across, guard + across, UiDraw.GOLD, 8.0, true)


func _init() -> void:
	layer = 10
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_dim = ColorRect.new()
	_dim.color = Color(0.03, 0.04, 0.07, 0.72)
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(_dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(center)
	_card = PanelContainer.new()
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card_style = StyleBoxFlat.new()
	_card_style.bg_color = Color(CARD, 0.97)
	_card_style.set_corner_radius_all(26)
	_card_style.set_border_width_all(3)
	_card_style.border_color = Color("3d465f")
	_card_style.shadow_color = Color(0, 0, 0, 0.45)
	_card_style.shadow_size = 40
	_card_style.shadow_offset = Vector2(0, 14)
	_card_style.set_content_margin_all(44)
	_card_style.content_margin_top = 34
	_card_style.anti_aliasing = true
	center.add_child(_card)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 22)
	_card.add_child(box)
	_logo = Logo.new()
	box.add_child(_logo)
	_banner = PanelContainer.new()
	_banner.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_banner_style = StyleBoxFlat.new()
	_banner_style.set_corner_radius_all(10)
	_banner_style.border_width_bottom = 6
	_banner_style.skew = Vector2(0.22, 0.0)
	_banner_style.content_margin_left = 70
	_banner_style.content_margin_right = 70
	_banner_style.content_margin_top = 2
	_banner_style.content_margin_bottom = 6
	_banner_style.shadow_color = Color(0, 0, 0, 0.35)
	_banner_style.shadow_size = 12
	_banner_style.shadow_offset = Vector2(0, 6)
	_banner_style.anti_aliasing = true
	_banner.add_theme_stylebox_override("panel", _banner_style)
	box.add_child(_banner)
	_title = label(76)
	_title.add_theme_font_override("font", UiDraw.bold())
	_banner.add_child(_title)
	_text = label(30)
	_text.add_theme_color_override("font_color", Color("c3c8d6"))
	box.add_child(_text)
	_results = HBoxContainer.new()
	_results.alignment = BoxContainer.ALIGNMENT_CENTER
	_results.add_theme_constant_override("separation", 20)
	box.add_child(_results)
	_showcase = Showcase.new()
	_results.add_child(_showcase)
	_table = ResultsTable.new()
	_table.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_results.add_child(_table)
	_holder = CenterContainer.new()
	box.add_child(_holder)
	menu = MenuList.new()
	menu.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(menu)
	visible = false


# content: a control shown under the text (a page's body), freed on the next show_menu().
func show_menu(title: String, text: String, options: Array, device: String = "",
		title_color: Color = Color.WHITE, content: Control = null) -> void:
	_title.text = title
	_title.add_theme_color_override("font_color", Color.WHITE)
	var banner := NEUTRAL_BANNER if title_color == Color.WHITE else title_color
	_banner_style.bg_color = banner
	_banner_style.border_color = banner.darkened(0.35)
	_banner.visible = look != "logo" and title != ""
	_logo.visible = look == "logo"
	if look == "logo":
		_logo.intro()
	var rows := _results_rows(text)
	_results.visible = not rows.is_empty()
	if _results.visible:
		var winner := title.trim_suffix(" wins!")
		_table.set_rows(rows, winner)
		var id := ""
		var color := Color.WHITE
		for r in rows.size():
			if rows[r][0] == winner:
				id = _roster_id(rows[r][1])
				color = UiDraw.PLAYER_COLORS[r % UiDraw.PLAYER_COLORS.size()]
		_showcase.show_winner(id, color)
	_text.text = text
	_text.visible = text != "" and rows.is_empty()
	for child in _holder.get_children():
		child.queue_free()
	if content != null:
		_holder.add_child(content)
	_holder.visible = content != null
	_card.add_theme_stylebox_override("panel", _card_style if look == "card" else StyleBoxEmpty.new())
	_dim.color.a = {"card": 0.62, "logo": 0.0, "page": 0.72}[look]
	menu.device = device
	menu.selected = 0
	menu.set_options(options)
	_t = 0.0
	_animate(0.0)
	visible = true


func handle() -> int:
	return menu.handle() if visible else -1


func _process(delta: float) -> void:
	if visible:
		_animate(delta)


# The card pops in with an overshoot while the screen dims.
func _animate(delta: float) -> void:
	_t += delta
	_table.t = _t
	_root.modulate.a = UiDraw.out_cubic(_t / 0.15)
	if look == "card":
		var s := lerpf(0.86, 1.0, UiDraw.out_back(_t / 0.3))
		_card.pivot_offset = _card.size / 2.0
		_card.scale = Vector2(s, s)
	else:
		_card.scale = Vector2.ONE


# The roster id of a fighter name; names outside the roster (the test fighter) get "test".
func _roster_id(fighter_name: String) -> String:
	for id in Roster.ids():
		if Roster.display_name(id) == fighter_name:
			return id
	return "test"


# The rows of a results text, or [] when the text is something else.
func _results_rows(text: String) -> Array:
	if text == "":
		return []
	var pattern := RegEx.create_from_string(RESULTS_LINE)
	var rows := []
	for line in text.split("\n"):
		var found := pattern.search(line)
		if found == null:
			return []
		rows.append(Array(found.strings.slice(1)))
	return rows


static func label(size: int) -> Label:
	var l := Label.new()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_constant_override("outline_size", maxi(size / 6, 6))
	l.add_theme_color_override("font_outline_color", UiDraw.INK)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

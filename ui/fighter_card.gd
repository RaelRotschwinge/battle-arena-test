# One player's panel on the fighter select screen (game design, "Menus"): who plays it, the
# fighter as it looks in the match under a spotlight in the slot color, its name, role and
# difficulty, its stat sheet, one line about it, and its special with this player's own key.
# Empty panels pulse and ask to join; computer panels show the fighter the computer plays. A new
# pick slides in and fills its stat pips; ready stamps the panel. A player's panel has a Controls
# row (a padlock and the chosen device with arrows), a Ready button and a leave cross, all of them
# clickable: hit() names the part under the mouse, the select screen acts on it.
extends Control

const Roster := preload("res://fighters/roster.gd")
const StatSheet := preload("res://fighters/stat_sheet.gd")
const FighterState := preload("res://scripts/sim/fighter_state.gd")
const FighterFigure := preload("res://ui/fighter_figure.gd")
const UiDraw := preload("res://ui/ui_draw.gd")

const SIZE := Vector2(430, 820)
const HEADER := 64.0
const FLOOR_Y := 352.0
const FIGURE_SCALE := 1.8
const DY := 12.0  # Everything under the figure sits this much lower than it once did.
# The clickable parts of a player's panel.
const LEAVE := Rect2(376, 10, 44, 44)
const LOCK := Rect2(14, 74, 52, 48)
const DEVICE_LEFT := Rect2(72, 74, 54, 48)
const DEVICE_RIGHT := Rect2(364, 74, 54, 48)
const FIGHTER_LEFT := Rect2(36, 372, 66, 60)
const FIGHTER_RIGHT := Rect2(328, 372, 66, 60)
const READY := Rect2(120, 778, 190, 36)
const PARTS := {"leave": LEAVE, "lock": LOCK, "device-": DEVICE_LEFT, "device+": DEVICE_RIGHT,
		"fighter-": FIGHTER_LEFT, "fighter+": FIGHTER_RIGHT, "ready": READY}
const RADIUS := 20.0
const TEXT := Color("e6e9f0")
const JOIN_KEYS := ["Space", "Enter", "A", "X"]

static var _stats := {}  # Roster id -> stats, made once.

var state := "empty"  # "empty", "player" or "cpu".
var color := Color.WHITE  # The slot's color.
var title := ""  # "P1   Keys left": the name, three spaces, the device or level.
var fighter := ""  # A roster id or "random".
var shown_ready := false
var key := ""  # The player's special key, as shown.
var hint := ""
var device_label := ""  # The chosen device, as shown in the Controls row.
var locked := false
var focus := 0  # The row the player's device works: 0 the fighter, 1 the controls.
var hover := ""  # The part under the mouse, as hit() names it.
var _figure: FighterFigure
var _front: Control  # Drawn over the figure.
var _t := 0.0
var _since_pick := 10.0  # Seconds since the shown fighter changed.
var _since_ready := 10.0
var _from := 0  # The side the new pick slid in from: -1 left, 1 right.
var _old_pips := [0, 0, 0, 0]  # The stat pips of the fighter shown before, for the change.


func _init() -> void:
	size = SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_figure = FighterFigure.new()
	_figure.position = Vector2(SIZE.x / 2.0, FLOOR_Y)
	_figure.size = FIGURE_SCALE
	add_child(_figure)
	_front = Control.new()
	_front.size = SIZE
	_front.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_front.draw.connect(_draw_front)
	add_child(_front)


func show_card(new_state: String, new_title: String, new_fighter: String, is_ready: bool,
		new_key: String, new_hint: String) -> void:
	var changed: bool = [state, title, fighter, shown_ready, key, hint] != [new_state, new_title,
			new_fighter, is_ready, new_key, new_hint]
	if not changed:
		return
	var readied := is_ready and not shown_ready
	if new_fighter != fighter or new_state != state:
		_from = _step(fighter, new_fighter) if new_state == state else 0
		_since_pick = 0.0
		_old_pips = _pips_of(fighter) if state != "empty" else [0, 0, 0, 0]
	if readied:
		_since_ready = 0.0
		_figure.pop()
	queue_redraw()
	state = new_state
	title = new_title
	fighter = new_fighter
	shown_ready = is_ready
	key = new_key
	hint = new_hint
	_figure.visible = state != "empty" and fighter != "random" and fighter != ""
	if _figure.visible:
		var f := FighterState.new()
		f.stats = stats_of(fighter)
		f.mode = FighterState.Mode.GROUND
		_figure.f = f
		_figure.color = color
		if readied:
			_figure.play("side")  # A quick swing as the player says ready.


# The Controls row, the keyboard focus and the mouse hover; redraws when one changes.
func set_controls(new_label: String, is_locked: bool, new_focus: int, new_hover: String) -> void:
	if [device_label, locked, focus, hover] != [new_label, is_locked, new_focus, new_hover]:
		device_label = new_label
		locked = is_locked
		focus = new_focus
		hover = new_hover
		queue_redraw()


# The part of the panel at the local point p: "join" (an empty or computer panel), "leave",
# "lock", "device-", "device+", "fighter-", "fighter+", "ready", or "" for none.
func hit(p: Vector2) -> String:
	if not Rect2(Vector2.ZERO, SIZE).has_point(p):
		return ""
	if state != "player":
		return "join"
	for part in PARTS:
		if PARTS[part].has_point(p):
			if shown_ready and part in ["device-", "device+", "fighter-", "fighter+"]:
				return ""
			return part
	return ""


# 1 when the pick moved right through the list, -1 when left.
func _step(old: String, new: String) -> int:
	var picks: Array = Roster.ids() + ["random"]
	var at := picks.find(old)
	if at < 0:
		return 0
	return 1 if picks[posmod(at + 1, picks.size())] == new else -1


func _pips_of(id: String) -> Array:
	return [0, 0, 0, 0] if id == "" or id == "random" else StatSheet.pips(stats_of(id))


static func stats_of(id: String):
	if not _stats.has(id):
		_stats[id] = Roster.make(id)
	return _stats[id]


func _process(delta: float) -> void:
	_t += delta
	_since_pick += delta
	_since_ready += delta
	var slide := 1.0 - UiDraw.out_cubic(_since_pick / 0.28)
	_figure.position = Vector2(SIZE.x / 2.0 + _from * 70.0 * slide, FLOOR_Y)
	_figure.alpha = 1.0 - slide
	# The panel's text and shapes redraw only while a change animates (text is costly); what
	# moves all the time is drawn on the small front layer.
	if _since_pick < 0.7 or _since_ready < 0.7:
		queue_redraw()
	_front.queue_redraw()


func _draw() -> void:
	if state == "empty":
		_draw_empty()
		return
	var w := SIZE.x
	var lit := shown_ready or state == "player"
	var border := Color(color, 0.55) if state == "player" else Color("3d465f")
	if shown_ready:  # A glow around the panel, strongest just after the press.
		var flash := 1.0 - UiDraw.out_cubic(_since_ready / 0.5)
		UiDraw.glow(self, SIZE / 2.0, SIZE * Vector2(0.75, 0.62), Color(color, 0.3 + 0.4 * flash))
		border = color
	UiDraw.panel(self, Rect2(Vector2.ZERO, SIZE), RADIUS, UiDraw.PANEL_TOP, UiDraw.PANEL_BOTTOM)
	_spotlight(lit)
	_header()
	if state == "player":
		_controls_row()
	if fighter == "random":
		_draw_random()
	else:
		_draw_fighter()
	_outline(border, 5.0 if shown_ready else 2.5)


func _header() -> void:
	var top := color.lightened(0.12) if state == "player" else Color("4a5370")
	var bottom := color.darkened(0.18) if state == "player" else Color("394159")
	UiDraw.panel(self, Rect2(0, 0, SIZE.x, HEADER), RADIUS, top, bottom)
	draw_rect(Rect2(0, HEADER - RADIUS, SIZE.x, RADIUS), bottom)
	draw_line(Vector2(0, HEADER), Vector2(SIZE.x, HEADER), Color(UiDraw.INK, 0.6), 3.0)
	var parts := title.split("   ")
	var name_size := 34
	var base := UiDraw.baseline(0, HEADER, name_size, UiDraw.bold())
	UiDraw.text(self, Vector2(20, base), parts[0], name_size, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT,
			-1.0, UiDraw.bold(), 7)
	if state == "player":
		_leave_cross()
	if parts.size() > 1:
		var x := 32.0 + UiDraw.text_width(parts[0], name_size, UiDraw.bold())
		UiDraw.text(self, Vector2(x, base - 2.0), parts[1], 24, Color(1, 1, 1, 0.92),
				HORIZONTAL_ALIGNMENT_LEFT, -1.0, null, 5)



# A cone of light from the header onto a round floor, in the slot color.
func _spotlight(lit: bool) -> void:
	var cx := SIZE.x / 2.0
	var strength := 1.0 if lit else 0.55
	if shown_ready:
		strength += 0.6 * (1.0 - UiDraw.out_cubic(_since_ready / 0.6))
	var top := Color(color, 0.2 * strength)
	var bottom := Color(color, 0.0)
	draw_polygon(PackedVector2Array([Vector2(cx - 50, 126), Vector2(cx + 50, 126),
			Vector2(cx + 165, FLOOR_Y), Vector2(cx - 165, FLOOR_Y)]),
			PackedColorArray([top, top, bottom, bottom]))
	UiDraw.glow(self, Vector2(cx, FLOOR_Y - 90.0), Vector2(190, 170), Color(color, 0.16 * strength))
	# The floor: a dark disc with a lit rim.
	var disc := PackedVector2Array()
	for n in 40:
		var turn := TAU * n / 40.0
		disc.append(Vector2(cx + cos(turn) * 150.0, FLOOR_Y + 8.0 + sin(turn) * 24.0))
	draw_colored_polygon(disc, Color("141824"))
	disc.append(disc[0])
	draw_polyline(disc, Color(color, 0.5 * strength), 3.0, true)
	UiDraw.glow(self, Vector2(cx, FLOOR_Y + 6.0), Vector2(150, 26), Color(color, 0.45 * strength))


func _draw_fighter() -> void:
	var w := SIZE.x
	var s = stats_of(fighter)
	var info: Dictionary = s.info
	_name_row(Roster.display_name(fighter))
	UiDraw.text(self, Vector2(30, 458), info.get("role", ""), 26, UiDraw.DIM,
			HORIZONTAL_ALIGNMENT_LEFT, 250, null, 0)
	for n in 3:  # Difficulty: filled stars of three.
		_star(Vector2(w - 110 + n * 34, 449), 13.0, n < info.get("difficulty", 1))
	var pips := StatSheet.pips(s)
	for row in StatSheet.NAMES.size():
		var y := 492.0 + row * 30.0
		UiDraw.text(self, Vector2(30, y + 8), StatSheet.NAMES[row], 24, TEXT,
				HORIZONTAL_ALIGNMENT_LEFT, 150, null, 0)
		for p in 5:
			var pip := Rect2(186 + p * 44, y - 10, 38, 18)
			UiDraw.panel(self, pip, 9.0, Color("2a3043"), Color("323a50"))
			# Pips the last fighter had too stay lit; new ones pop in, lost ones shrink away.
			var now: bool = p < pips[row]
			var was: bool = p < _old_pips[row]
			var t := (_since_pick - row * 0.02 - p * 0.02) / 0.14
			var k := 1.0 if now else 0.0
			if now and not was:
				k = UiDraw.out_back(t)
			elif was and not now:
				k = 1.0 - UiDraw.out_cubic(t)
			if k > 0.05:
				var grown := Rect2(pip.get_center() - pip.size * k / 2.0, pip.size * k)
				UiDraw.panel(self, grown, 9.0 * k, color.lightened(0.3), color.darkened(0.08))
	draw_multiline_string(ThemeDB.fallback_font, Vector2(30, 628), info.get("line", ""),
			HORIZONTAL_ALIGNMENT_LEFT, w - 60, 22, 2, UiDraw.DIM)
	# The special in its own box, with the player's key as a key cap.
	var box := Rect2(18, 672, w - 36, 98)
	UiDraw.panel(self, box, 14.0, Color("262b3d"), Color("1f2333"), Color(UiDraw.GOLD, 0.35), 2.0)
	UiDraw.text(self, Vector2(34, 703), "Special", 20, Color(UiDraw.GOLD, 0.8),
			HORIZONTAL_ALIGNMENT_LEFT, -1.0, null, 0)
	UiDraw.text(self, Vector2(112, 704), info.get("special", ""), 28, UiDraw.GOLD,
			HORIZONTAL_ALIGNMENT_LEFT, 200, UiDraw.bold(), 5)
	if key != "":
		_chip_right(Vector2(w - 32.0, 680.0), key, Color("e9ecf3"))
	var how: String = info.get("special_how", "")
	draw_multiline_string(ThemeDB.fallback_font, Vector2(34, 732),
			how.substr(0, 1).to_upper() + how.substr(1), HORIZONTAL_ALIGNMENT_LEFT, w - 68, 20, 2,
			TEXT)
	_bottom()


func _draw_random() -> void:
	var w := SIZE.x
	_name_row("Random")
	draw_multiline_string(ThemeDB.fallback_font, Vector2(30, 492),
			"A new fighter every match, a surprise for everyone.", HORIZONTAL_ALIGNMENT_CENTER,
			w - 60, 26, 3, UiDraw.DIM)
	_bottom()


# The fighter's name, with arrows that bob outward while the player still picks.
func _name_row(shown: String) -> void:
	var w := SIZE.x
	var pop := 1.0 + 0.12 * (1.0 - UiDraw.out_cubic(_since_pick / 0.25))
	draw_set_transform(Vector2(w / 2.0, 410), 0.0, Vector2(pop, pop))
	UiDraw.text(self, Vector2(-w / 2.0, 0), shown, 50, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, w,
			UiDraw.bold(), 9)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_empty() -> void:
	var w := SIZE.x
	var rect := Rect2(Vector2.ZERO, SIZE)
	UiDraw.panel(self, rect, RADIUS, Color(UiDraw.PANEL_TOP, 0.7), Color(UiDraw.PANEL_BOTTOM, 0.7))
	UiDraw.text(self, Vector2(0, 490), "Press attack", 26, UiDraw.DIM, HORIZONTAL_ALIGNMENT_CENTER,
			w, null, 0)
	var widths := []
	var total := -12.0
	for k in JOIN_KEYS:
		widths.append(maxf(UiDraw.chip_width(k, 22), 46.0))
		total += widths[-1] + 12.0
	var x := (w - total) / 2.0
	for n in JOIN_KEYS.size():
		_key_cap(Rect2(x, 512, widths[n], 40), JOIN_KEYS[n])
		x += widths[n] + 12.0
	UiDraw.text(self, Vector2(0, 584), "Keys left, keys right, gamepad", 20, Color(UiDraw.DIM, 0.8),
			HORIZONTAL_ALIGNMENT_CENTER, w, null, 0)


# The panel's border, antialiased.
func _outline(border: Color, width: float) -> void:
	var points := UiDraw.rounded(Rect2(Vector2.ZERO, SIZE).grow(-width / 2.0), RADIUS)
	points.append(points[0])
	draw_polyline(points, border, width, true)


# A dashed round border that crawls slowly.
func _dashes(rect: Rect2, border: Color) -> void:
	var points := UiDraw.rounded(rect, RADIUS)
	points.append(points[0])
	var dash := 18.0
	var travel := fposmod(_t * 20.0, dash * 2.0)
	for n in points.size() - 1:
		var a: Vector2 = points[n]
		var b: Vector2 = points[n + 1]
		var length := a.distance_to(b)
		var at := -travel
		while at < length:
			var from := maxf(at, 0.0)
			var to := minf(at + dash, length)
			if to > from:
				_front.draw_line(a.lerp(b, from / length), a.lerp(b, to / length), border, 3.0, true)
			at += dash * 2.0
		travel = fposmod(travel + length, dash * 2.0)


# The front layer: the live bits, then READY stamped onto the right of the header, in front of
# everything: it drops in big and settles with an overshoot.
func _draw_front() -> void:
	_draw_live()
	if state == "empty" or not shown_ready:
		return
	var c := _front
	var k := UiDraw.out_back(_since_ready / 0.35)
	var s := lerpf(2.2, 1.0, k)
	var alpha := clampf(_since_ready / 0.12, 0.0, 1.0)
	c.draw_set_transform(Vector2(SIZE.x - 150.0, 38), -0.06, Vector2(s, s) * 0.72)
	var rect := Rect2(-118, -34, 236, 68)
	UiDraw.panel(c, rect, 14.0, Color(1, 1, 1, alpha), Color(Color("dfe3ec"), alpha),
			Color(UiDraw.INK, alpha), 4.0)
	var check := Vector2(-80, 0)
	var ink := Color(color.darkened(0.25), alpha)
	c.draw_circle(check, 21.0, ink, true, -1.0, true)
	c.draw_polyline(PackedVector2Array([check + Vector2(-10, 0), check + Vector2(-3, 8),
			check + Vector2(11, -9)]), Color(1, 1, 1, alpha), 6.0, true)
	UiDraw.text(c, Vector2(-52, UiDraw.baseline(-34, 68, 40, UiDraw.bold())), "READY", 40, ink,
			HORIZONTAL_ALIGNMENT_LEFT, -1.0, UiDraw.bold(), 0)
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# What moves all the time, on the front layer: the pick arrows, Random's question mark and an
# empty panel's pulsing border, plus sign and "Join".
func _draw_live() -> void:
	var c := _front
	var w := SIZE.x
	if state == "empty":
		var pulse := 0.5 + 0.5 * sin(_t * 3.0)
		_dashes(Rect2(Vector2.ZERO, SIZE).grow(-2.0), Color(color, 0.35 + 0.35 * pulse))
		var center := Vector2(w / 2.0, 300)
		UiDraw.glow(c, center, Vector2(120, 120) * (1.0 + 0.15 * pulse), Color(color, 0.18))
		c.draw_circle(center, 58.0, Color(color, 0.85), false, 6.0, true)
		c.draw_line(center - Vector2(26, 0), center + Vector2(26, 0), Color(color, 0.85), 8.0, true)
		c.draw_line(center - Vector2(0, 26), center + Vector2(0, 26), Color(color, 0.85), 8.0, true)
		UiDraw.text(c, Vector2(0, 432), "Join", 56, Color(1, 1, 1, 0.75 + 0.25 * pulse),
				HORIZONTAL_ALIGNMENT_CENTER, w, UiDraw.bold(), 9)
		return
	if fighter == "random":
		var bob := sin(_t * 2.4) * 8.0
		UiDraw.glow(c, Vector2(w / 2.0, 220 + bob), Vector2(130, 130), Color(UiDraw.GOLD, 0.25))
		c.draw_set_transform(Vector2(w / 2.0, 290 + bob), sin(_t * 1.3) * 0.08, Vector2.ONE)
		UiDraw.text(c, Vector2(-100, 0), "?", 200, UiDraw.GOLD, HORIZONTAL_ALIGNMENT_CENTER, 200,
				UiDraw.bold(), 18)
		c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if state == "player" and not shown_ready:
		var bob := (4.0 + 4.0 * sin(_t * 5.0)) if focus == 0 else 0.0
		var kick := 14.0 * (1.0 - UiDraw.out_cubic(_since_pick / 0.2))
		for side in [-1, 1]:
			var part := "fighter-" if side < 0 else "fighter+"
			var push := bob + (kick if side == _from else 0.0)
			if hover == part:
				UiDraw.glow(c, PARTS[part].get_center(), Vector2(44, 44), Color(color, 0.45))
			var tone := color if focus == 0 or hover == part else Color(UiDraw.DIM, 0.7)
			UiDraw.chevron(c, Vector2(w / 2.0 + side * (150.0 + push), 394), 14.0, side, tone)
	if state == "player" and not locked:  # Open: the Controls row pulses and says how to lock.
		var pulse := 0.5 + 0.5 * sin(_t * 5.0)
		var ring := UiDraw.rounded(Rect2(12, 72, SIZE.x - 24, 52).grow(2.0), 14.0)
		ring.append(ring[0])
		c.draw_polyline(ring, Color(UiDraw.GOLD, 0.35 + 0.55 * pulse), 3.0, true)
		var caption := "Press attack on it, or click the lock"
		var width := UiDraw.text_width(caption, 18) + 28.0
		UiDraw.panel(c, Rect2((w - width) / 2.0, 132, width, 28), 14.0, Color(0, 0, 0, 0.65),
				Color(0, 0, 0, 0.65))
		UiDraw.text(c, Vector2(0, 152), caption, 18, Color(UiDraw.GOLD, 0.75 + 0.25 * pulse),
				HORIZONTAL_ALIGNMENT_CENTER, w, null, 0)


# A small chip ending at the right edge at.x.
func _chip_right(at: Vector2, value: String, fill: Color) -> void:
	var width := maxf(UiDraw.chip_width(value, 22), 46.0)
	_key_cap(Rect2(at.x - width, at.y, width, 36), value, fill)


func _key_cap(rect: Rect2, value: String, fill: Color = Color("e9ecf3")) -> void:
	var dark := fill.get_luminance() > 0.5
	UiDraw.panel(self, Rect2(rect.position + Vector2(0, 3), rect.size), 8.0, fill.darkened(0.45),
			fill.darkened(0.55))
	UiDraw.panel(self, rect, 8.0, fill, fill.darkened(0.18), UiDraw.INK, 2.0)
	UiDraw.text(self, Vector2(rect.position.x, UiDraw.baseline(rect.position.y, rect.size.y, 22)),
			value, 22, Color("1b1e2a") if dark else Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER,
			rect.size.x, UiDraw.bold(), 0)


func _star(at: Vector2, radius: float, filled: bool) -> void:
	var points := PackedVector2Array()
	for n in 10:
		var turn := -PI / 2.0 + TAU * n / 10.0
		var r := radius if n % 2 == 0 else radius * 0.45
		points.append(at + Vector2(cos(turn), sin(turn)) * r)
	if filled:
		draw_colored_polygon(points, UiDraw.GOLD)
	points.append(points[0])
	draw_polyline(points, UiDraw.GOLD, 2.0, true)


# The Controls row: a padlock (closed: the device is locked in) and the device between arrows.
func _controls_row() -> void:
	var row := Rect2(12, 72, SIZE.x - 24, 52)
	var lit := focus == 1 and not shown_ready
	UiDraw.panel(self, row, 12.0, Color("2c3247"), Color("222738"),
			Color(color, 0.95) if lit else Color("454e6a"), 3.0 if lit else 2.0)
	_padlock(LOCK.get_center() + Vector2(0, 2), hover == "lock")
	var shown := device_label if device_label != "" else "No device free"
	var span := DEVICE_RIGHT.position.x - DEVICE_LEFT.end.x
	UiDraw.text(self, Vector2(DEVICE_LEFT.end.x, UiDraw.baseline(row.position.y, row.size.y, 23)),
			shown, 23, Color.WHITE if locked else UiDraw.GOLD, HORIZONTAL_ALIGNMENT_CENTER, span,
			null, 5)
	if shown_ready:
		return
	for side in [-1, 1]:
		var part := "device-" if side < 0 else "device+"
		var box: Rect2 = PARTS[part]
		if hover == part:
			UiDraw.panel(self, box.grow(-5.0), 10.0, Color(1, 1, 1, 0.16), Color(1, 1, 1, 0.08))
		var tone := color if lit or hover == part else Color(UiDraw.DIM, 0.8)
		UiDraw.chevron(self, box.get_center(), 10.0, side, tone)


# A padlock: closed and gold when locked, its shackle lifted and swung aside when open.
func _padlock(at: Vector2, hot: bool) -> void:
	var tone := UiDraw.GOLD if locked else Color("c3c8d6")
	if hot:
		UiDraw.glow(self, at, Vector2(36, 36), Color(tone, 0.45))
	var lift := 0.0 if locked else 7.0
	var swing := 0.0 if locked else 9.0
	var top := at + Vector2(swing, -6.0 - lift)
	for pass_ in 2:  # The dark outline first, then the metal.
		var width := 8.0 if pass_ == 0 else 4.0
		var ink: Color = UiDraw.INK if pass_ == 0 else tone
		draw_arc(top, 9.0, PI, TAU, 16, ink, width, true)
		draw_line(top + Vector2(-9, 0), top + Vector2(-9, 6.0 + (0.0 if locked else -2.0)), ink,
				width, true)
		draw_line(top + Vector2(9, 0), top + Vector2(9, 6.0 + lift), ink, width, true)
	var body := Rect2(at + Vector2(-14, -2), Vector2(28, 21))
	UiDraw.panel(self, body, 5.0, tone.lightened(0.25), tone.darkened(0.25), UiDraw.INK, 2.0)
	draw_circle(body.get_center() + Vector2(0, -2), 3.5, UiDraw.INK, true, -1.0, true)
	draw_line(body.get_center(), body.get_center() + Vector2(0, 6), UiDraw.INK, 3.0)


# The bottom of the panel: a player's Ready button (it says to lock first while open), or the
# computer's hint.
func _bottom() -> void:
	if state != "player":
		UiDraw.text(self, Vector2(0, 806), hint, 21, UiDraw.DIM, HORIZONTAL_ALIGNMENT_CENTER,
				SIZE.x, null, 0)
		return
	var hot := hover == "ready"
	var fill := color if shown_ready else (Color("3a4462") if locked else Color("262b3a"))
	if hot and locked:
		fill = fill.lightened(0.18)
	var label := "Ready!" if shown_ready else ("Ready" if locked else "Lock first")
	UiDraw.chip(self, READY, label, 22, fill, Color.WHITE if locked else UiDraw.DIM,
			Color.WHITE if hot else Color("525d80"))


# The leave cross in the header of a player's panel.
func _leave_cross() -> void:
	var at := LEAVE.get_center()
	if hover == "leave":
		draw_circle(at, 18.0, Color(1, 1, 1, 0.22), true, -1.0, true)
	for d in [Vector2(8, 8), Vector2(8, -8)]:
		draw_line(at - d, at + d, UiDraw.INK, 8.0, true)
		draw_line(at - d, at + d, Color.WHITE, 4.0, true)
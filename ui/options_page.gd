# The options (game design, "Menus"): full screen, music and effects volume, screen shake, Back.
# Shown as the content of the overlay's page look. One cursor that any device works: up and down
# select, left and right change, attack changes or chooses Back, the shield key, B or Esc goes
# back. The mouse selects by hovering and changes with the arrows or the value. Every change is
# saved and applied at once (settings.gd). Call handle() once per tick after Devices.poll().
extends Control

const Devices := preload("res://scripts/view/devices.gd")
const Settings := preload("res://scripts/view/settings.gd")
const UiDraw := preload("res://ui/ui_draw.gd")
const MenuList := preload("res://ui/menu_list.gd")

const ROWS := [["Full screen", "fullscreen"], ["Music", "music"], ["Effects", "effects"],
		["Screen shake", "shake"]]
const BACK := 4  # The row index of Back, after the options.
const ROW_HEIGHT := 86.0
const ROW_STEP := 104.0
const ARROW := 56.0  # The square boxes of the < and > arrows.
const MIDDLE := 310.0  # The value between the arrows.
const PIPS := 10
const PIP := Vector2(22.0, 8.0)  # A pip's width and the gap to the next.
const SIZE := Vector2(1100.0, 4 * ROW_STEP + 92.0)
const BACK_RECT := Rect2(330.0, 4 * ROW_STEP + 24.0, 440.0, 64.0)
const FLASH := 0.2

var selected := 0
var _hover := [-1, ""]  # The row and part under the mouse.
var _click_at := Vector2.INF  # A click waiting for handle(), INF for none.
var _flash := 0.0  # Seconds left of the flash of a changed row.
var _flash_row := -1
var _t := 0.0


func _init() -> void:
	custom_minimum_size = SIZE


# Returns true when the players go back.
func handle() -> bool:
	if _pressed("up"):
		selected = posmod(selected - 1, BACK + 1)
	elif _pressed("down"):
		selected = posmod(selected + 1, BACK + 1)
	if selected != BACK:
		if _pressed("left"):
			_step(selected, -1, false)
		elif _pressed("right"):
			_step(selected, 1, false)
	if _pressed("confirm"):
		if selected == BACK:
			return true
		_step(selected, 1, true)
	if _pressed("back"):
		return true
	if _click_at != Vector2.INF:
		var at := _click_at
		_click_at = Vector2.INF
		return _click(at)
	return false


func _gui_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button != null and button.pressed and button.button_index == MOUSE_BUTTON_LEFT:
		_click_at = button.position


func _click(at: Vector2) -> bool:
	var hit := _hit(at)
	var r: int = hit[0]
	if r != -1:
		selected = r
	match hit[1]:
		"back":
			return true
		"less":
			_step(r, -1, false)
		"more":
			_step(r, 1, false)
		"value":
			if Settings.BUSES.has(ROWS[r][1]):  # A volume: the pip clicked is the new level.
				var first := _pip_rect(r, 0).position.x
				var pip := clampi(int((at.x - first) / (PIP.x + PIP.y)), 0, PIPS - 1)
				_change(r, (pip + 1) * Settings.VOLUME_STEP)
			else:
				_step(r, 1, true)
	return false


# Moves an option one step. Choices always wrap; a volume wraps only when wrap is set (attack and
# a click on the value), so holding an arrow stops at 0 or 100.
func _step(r: int, direction: int, wrap: bool) -> void:
	var key: String = ROWS[r][1]
	var current: Variant = Settings.value(key)
	match key:
		"fullscreen":
			_change(r, not current)
		"shake":
			_change(r, posmod(int(current) + direction, Settings.SHAKE_NAMES.size()))
		_:
			var level: int = current + direction * Settings.VOLUME_STEP
			if wrap:
				level = posmod(level, 100 + Settings.VOLUME_STEP)
			_change(r, clampi(level, 0, 100))


func _change(r: int, new_value: Variant) -> void:
	if new_value == Settings.value(ROWS[r][1]):
		return
	Settings.change(ROWS[r][1], new_value)
	_flash = FLASH
	_flash_row = r


func _pressed(action: String) -> bool:
	return Devices.any_pressed(action) != ""


# [row, part] at a point: part is "less", "more", "value", "" (the name) or "back".
func _hit(at: Vector2) -> Array:
	if BACK_RECT.has_point(at):
		return [BACK, "back"]
	for r in ROWS.size():
		if _row_rect(r).has_point(at):
			for part in ["less", "more", "value"]:
				if _part_rect(r, part).has_point(at):
					return [r, part]
			return [r, ""]
	return [-1, ""]


func _row_rect(r: int) -> Rect2:
	return Rect2(0.0, r * ROW_STEP, SIZE.x, ROW_HEIGHT)


func _part_rect(r: int, part: String) -> Rect2:
	var right := SIZE.x - 26.0
	var y := r * ROW_STEP + (ROW_HEIGHT - ARROW) / 2.0
	match part:
		"less":
			return Rect2(right - 2.0 * ARROW - MIDDLE, y, ARROW, ARROW)
		"more":
			return Rect2(right - ARROW, y, ARROW, ARROW)
	return Rect2(right - ARROW - MIDDLE, y, MIDDLE, ARROW)


# Pips grow taller to the right, standing on the same line.
func _pip_rect(r: int, n: int) -> Rect2:
	var middle := _part_rect(r, "value")
	var width := PIPS * PIP.x + (PIPS - 1) * PIP.y
	var height := 16.0 + n * 2.6
	return Rect2(middle.position.x + (middle.size.x - width) / 2.0 + n * (PIP.x + PIP.y),
			middle.end.y - 6.0 - height, PIP.x, height)


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_t += delta
	_flash = maxf(_flash - delta, 0.0)
	# The mouse is polled, as on the select screens: motion does not reach gui_input in the
	# SubViewport of supersample.gd. Moving onto another row or part selects that row.
	var inside := get_viewport_rect().has_point(get_viewport().get_mouse_position())
	var hover := _hit(get_local_mouse_position()) if inside else [-1, ""]
	if hover != _hover and hover[0] != -1:
		selected = hover[0]
	_hover = hover
	queue_redraw()


func _draw() -> void:
	var pulse := 0.5 + 0.5 * sin(_t * 4.0)
	for r in ROWS.size():
		_row(r, pulse)
	_back(pulse)


func _row(r: int, pulse: float) -> void:
	var rect := _row_rect(r)
	var lit := r == selected
	if lit:
		UiDraw.glow(self, rect.get_center(), Vector2(rect.size.x * 0.62, rect.size.y * 1.5),
				Color(MenuList.BAR_BOTTOM, 0.1 + 0.06 * pulse))
	UiDraw.panel(self, rect, 16.0, Color("2c3247", 0.95), Color("222738", 0.95),
			UiDraw.GOLD if lit else Color("454e6a"), 3.0 if lit else 2.0)
	if lit:  # A gold tab on the left edge.
		UiDraw.panel(self, Rect2(rect.position + Vector2(12, 18), Vector2(8, ROW_HEIGHT - 36)), 4.0,
				MenuList.BAR_TOP, MenuList.BAR_BOTTOM)
	if _flash > 0.0 and r == _flash_row:
		var k := _flash / FLASH
		UiDraw.panel(self, rect, 16.0, Color(1, 1, 1, 0.22 * k), Color(1, 1, 1, 0.08 * k))
	var font := UiDraw.bold()
	UiDraw.text(self, Vector2(44.0, UiDraw.baseline(rect.position.y, ROW_HEIGHT, 34, font)),
			ROWS[r][0], 34, Color.WHITE if lit else Color("c3c8d6"), HORIZONTAL_ALIGNMENT_LEFT, -1.0,
			font, 6)
	var key: String = ROWS[r][1]
	var current: Variant = Settings.value(key)
	var volume: bool = Settings.BUSES.has(key)
	if volume:
		_pips(r, current, lit)
	else:
		var shown: String = Settings.SHAKE_NAMES[current] if key == "shake" \
				else ("On" if current else "Off")
		var chip := _part_rect(r, "value").grow_individual(-34.0, -4.0, -34.0, -4.0)
		UiDraw.chip(self, chip, shown, 28, Color("4a5679") if lit else Color("3a4462"),
				Color.WHITE, UiDraw.GOLD if lit else Color("525d80"))
	for side in [-1, 1]:
		var part := "less" if side < 0 else "more"
		var box := _part_rect(r, part)
		var hot: bool = _hover[0] == r and _hover[1] == part
		if hot:
			UiDraw.panel(self, box.grow(-4.0), 10.0, Color(1, 1, 1, 0.16), Color(1, 1, 1, 0.08))
		var tone := UiDraw.GOLD if lit or hot else Color(UiDraw.DIM, 0.8)
		if volume and current == (0 if side < 0 else 100):  # Nothing further this way.
			tone.a *= 0.3
		UiDraw.chevron(self, box.get_center(), 12.0, side, tone)


# A volume: ten pips, lit up to the level, and the level as text left of the < arrow.
func _pips(r: int, level: int, lit: bool) -> void:
	for n in PIPS:
		var pip := _pip_rect(r, n)
		if n * Settings.VOLUME_STEP < level:
			var top := MenuList.BAR_TOP if lit else Color("e4e8f0")
			var bottom := MenuList.BAR_BOTTOM if lit else Color("a9b0c1")
			UiDraw.panel(self, pip, 5.0, top, bottom, UiDraw.INK, 2.0)
		else:
			UiDraw.panel(self, pip, 5.0, UiDraw.SLOT, UiDraw.SLOT.darkened(0.25))
	var less := _part_rect(r, "less")
	var shown := "Off" if level == 0 else "%d %%" % level
	UiDraw.text(self, Vector2(less.position.x - 140.0,
			UiDraw.baseline(r * ROW_STEP, ROW_HEIGHT, 28, UiDraw.bold())), shown, 28,
			Color.WHITE if lit else UiDraw.DIM, HORIZONTAL_ALIGNMENT_RIGHT, 124.0, UiDraw.bold(), 5)


# Back, in the look of the menu list: the gold bar with chevrons when selected.
func _back(pulse: float) -> void:
	var rect := BACK_RECT
	var lit := selected == BACK
	var font := UiDraw.bold()
	var base := UiDraw.baseline(rect.position.y, rect.size.y, 44, font)
	if not lit:
		UiDraw.text(self, Vector2(rect.position.x, base), "Back", 44, MenuList.NORMAL,
				HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, font, 9)
		return
	var h := rect.size.y
	UiDraw.glow(self, rect.get_center(), Vector2(rect.size.x * 0.75, h * 1.6),
			Color(MenuList.BAR_BOTTOM, 0.16 + 0.1 * pulse))
	UiDraw.panel(self, rect, h / 2.0, MenuList.BAR_TOP, MenuList.BAR_BOTTOM, UiDraw.INK, 4.0)
	var gloss := Rect2(rect.position + Vector2(h * 0.4, 5.0), Vector2(rect.size.x - h * 0.8, h * 0.32))
	UiDraw.panel(self, gloss, gloss.size.y / 2.0, Color(1, 1, 1, 0.35), Color(1, 1, 1, 0.05))
	UiDraw.text(self, Vector2(rect.position.x, base), "Back", 44, MenuList.SELECTED,
			HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, font, 0)
	for side in [-1, 1]:
		var tip := Vector2(rect.get_center().x + side * (rect.size.x / 2.0 + 26.0 + 6.0 * pulse),
				rect.get_center().y)
		UiDraw.chevron(self, tip, 12.0, -side, UiDraw.GOLD)

# A list of menu options worked with the players' own keys (game design, "Menus"): up and down
# move, attack or A chooses, the shield key or B goes back. With device set, only that device
# works it; else any device. Call handle() once per tick after Devices.poll(). A gold bar slides
# to the selected option and pulses.
extends VBoxContainer

const Devices := preload("res://scripts/view/devices.gd")
const UiDraw := preload("res://ui/ui_draw.gd")

const NORMAL := Color(0.78, 0.81, 0.88)
const SELECTED := Color("1b1e2a")  # Dark text on the gold bar.
const BAR_TOP := Color("ffe486")
const BAR_BOTTOM := Color("f0ac2a")

var device := ""
var selected := 0
var _labels := []
var _texts := []
var _clicked := -1
var _bar_y := -1.0  # The bar's middle, eased toward the selected option; -1 snaps it there.
var _pop := 0.0
var _flash := 0.0  # Seconds left of the flash of a chosen option.
var _t := 0.0


func _init() -> void:
	add_theme_constant_override("separation", 14)


func set_options(options: Array, font_size: int = 44) -> void:
	_clicked = -1  # A click on the old options must not act on the new ones.
	for label in _labels:
		label.queue_free()
	_labels.clear()
	_texts = options.duplicate()
	for text in options:
		var label := Label.new()
		label.text = text
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_override("font", UiDraw.bold())
		label.add_theme_font_size_override("font_size", font_size)
		label.add_theme_color_override("font_outline_color", UiDraw.INK)
		label.mouse_filter = Control.MOUSE_FILTER_STOP
		label.gui_input.connect(_on_label_input.bind(_labels.size()))
		label.mouse_entered.connect(_on_label_hover.bind(_labels.size()))
		add_child(label)
		_labels.append(label)
	selected = clampi(selected, 0, maxi(_labels.size() - 1, 0))
	_bar_y = -1.0
	_refresh()


# Returns the index of the option chosen this tick, -2 for back, -1 for nothing.
func handle() -> int:
	if _pressed("up"):
		selected = posmod(selected - 1, _labels.size())
		_refresh()
	elif _pressed("down"):
		selected = posmod(selected + 1, _labels.size())
		_refresh()
	if _pressed("confirm"):
		_flash = 0.25
		return selected
	if _pressed("back"):
		return -2
	if _clicked >= 0:
		var chosen := _clicked
		_clicked = -1
		_flash = 0.25
		return chosen
	return -1


func _on_label_input(event: InputEvent, at: int) -> void:
	var click := event as InputEventMouseButton
	if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		selected = at
		_clicked = at
		_refresh()


# The mouse over an option selects it, as up and down would.
func _on_label_hover(at: int) -> void:
	if at != selected:
		selected = at
		_refresh()


func _pressed(action: String) -> bool:
	if device != "":
		return Devices.pressed(device, action)
	return Devices.any_pressed(action) != ""


func _refresh() -> void:
	_pop = 0.25
	for i in _labels.size():
		var label: Label = _labels[i]
		var chosen: bool = i == selected
		label.add_theme_color_override("font_color", SELECTED if chosen else NORMAL)
		label.add_theme_constant_override("outline_size", 0 if chosen else 9)


func _process(delta: float) -> void:
	if not is_visible_in_tree() or _labels.is_empty():
		return
	_t += delta
	_pop = maxf(_pop - delta, 0.0)
	_flash = maxf(_flash - delta, 0.0)
	var label: Label = _labels[selected]
	var target := label.position.y + label.size.y / 2.0
	_bar_y = target if _bar_y < 0.0 else lerpf(_bar_y, target, 1.0 - exp(-delta * 20.0))
	queue_redraw()


func _draw() -> void:
	if _labels.is_empty() or _bar_y < 0.0:
		return
	var font_size: int = _labels[0].get_theme_font_size("font_size")
	var widest := 0.0
	for text in _texts:
		widest = maxf(widest, UiDraw.text_width(text, font_size, UiDraw.bold()))
	var stretch := 1.0 + 0.08 * sin(_pop / 0.25 * PI)
	var width := minf(maxf(widest + 150.0, 440.0) * stretch, size.x)
	var height := font_size * 1.45
	var rect := Rect2(Vector2((size.x - width) / 2.0, _bar_y - height / 2.0), Vector2(width, height))
	var pulse := 0.5 + 0.5 * sin(_t * 4.0)
	UiDraw.glow(self, rect.get_center(), Vector2(width * 0.75, height * 1.6),
			Color(BAR_BOTTOM, 0.16 + 0.1 * pulse))
	UiDraw.panel(self, rect, height / 2.0, BAR_TOP, BAR_BOTTOM, UiDraw.INK, 4.0)
	# A light gloss on the top half.
	var gloss := Rect2(rect.position + Vector2(height * 0.4, 5.0),
			Vector2(width - height * 0.8, height * 0.32))
	UiDraw.panel(self, gloss, gloss.size.y / 2.0, Color(1, 1, 1, 0.35), Color(1, 1, 1, 0.05))
	if _flash > 0.0:  # Chosen: the bar lights up and a ring flies off it.
		var k := 1.0 - _flash / 0.25
		UiDraw.panel(self, rect, height / 2.0, Color(1, 1, 1, 0.6 * (1.0 - k)),
				Color(1, 1, 1, 0.3 * (1.0 - k)))
		var ring := UiDraw.rounded(rect.grow(6.0 + 26.0 * k), height / 2.0 + 26.0 * k)
		ring.append(ring[0])
		draw_polyline(ring, Color(UiDraw.GOLD, 1.0 - k), 4.0, true)
	var nudge := 6.0 * pulse
	for side in [-1, 1]:
		var tip := Vector2(rect.get_center().x + side * (width / 2.0 + 26.0 + nudge), _bar_y)
		UiDraw.chevron(self, tip, 12.0, side * -1, UiDraw.GOLD)

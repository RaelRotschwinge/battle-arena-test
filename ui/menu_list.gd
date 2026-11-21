# A list of menu options worked with the players' own keys (game design, "Menus"): up and down
# move, attack or A chooses, the shield key or B goes back. With device set, only that device
# works it; else any device. Call handle() once per tick after Devices.poll().
extends VBoxContainer

const Devices := preload("res://scripts/view/devices.gd")

const NORMAL := Color(0.75, 0.78, 0.85)
const SELECTED := Color(1.0, 0.85, 0.3)

var device := ""
var selected := 0
var _labels := []
var _texts := []
var _clicked := -1


func set_options(options: Array, font_size: int = 44) -> void:
	for label in _labels:
		label.queue_free()
	_labels.clear()
	_texts = options.duplicate()
	for text in options:
		var label := Label.new()
		label.text = text
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", font_size)
		label.add_theme_constant_override("outline_size", 8)
		label.add_theme_color_override("font_outline_color", Color.BLACK)
		label.mouse_filter = Control.MOUSE_FILTER_STOP
		label.gui_input.connect(_on_label_input.bind(_labels.size()))
		add_child(label)
		_labels.append(label)
	selected = clampi(selected, 0, maxi(_labels.size() - 1, 0))
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
		return selected
	if _pressed("back"):
		return -2
	if _clicked >= 0:
		var chosen := _clicked
		_clicked = -1
		return chosen
	return -1


func _on_label_input(event: InputEvent, at: int) -> void:
	var click := event as InputEventMouseButton
	if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		selected = at
		_clicked = at
		_refresh()


func _pressed(action: String) -> bool:
	if device != "":
		return Devices.pressed(device, action)
	return Devices.any_pressed(action) != ""


func _refresh() -> void:
	for i in _labels.size():
		var label: Label = _labels[i]
		label.add_theme_color_override("font_color", SELECTED if i == selected else NORMAL)
		label.text = ("> %s <" if i == selected else "%s") % _texts[i]

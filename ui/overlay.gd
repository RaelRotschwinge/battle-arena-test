# A dimmed screen with a title, a text and a menu list, for the pause and results screens and the
# menus. Build it with show_menu(); handle() returns what was chosen (menu_list.gd).
extends CanvasLayer

const MenuList := preload("res://ui/menu_list.gd")

var menu: MenuList
var _dim: ColorRect
var _title: Label
var _text: Label


func _init() -> void:
	layer = 10
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_dim = ColorRect.new()
	_dim.color = Color(0.03, 0.04, 0.07, 0.72)
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(_dim)
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 26)
	root.add_child(box)
	_title = label(84)
	box.add_child(_title)
	_text = label(30)
	box.add_child(_text)
	menu = MenuList.new()
	menu.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(menu)
	visible = false


func show_menu(title: String, text: String, options: Array, device: String = "",
		title_color: Color = Color.WHITE) -> void:
	_title.text = title
	_title.add_theme_color_override("font_color", title_color)
	_text.text = text
	_text.visible = text != ""
	menu.device = device
	menu.selected = 0
	menu.set_options(options)
	visible = true


func handle() -> int:
	return menu.handle() if visible else -1


static func label(size: int) -> Label:
	var l := Label.new()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_constant_override("outline_size", maxi(size / 6, 6))
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

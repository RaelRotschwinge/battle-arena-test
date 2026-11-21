# The match HUD: damage and lives of every player along the bottom of the screen, and the win
# screen at the end of the match.
extends CanvasLayer

const PANEL_WIDTH := 220.0
const STOCK_SIZE := 18.0

var sim
var colors: Array = []
var labels: Array = []  # Per fighter: the player's name, for example "P1" or "CPU".

var _root: Control
var _panels := []  # Per player: [damage label, stock row].
var _win: Label
var _win_hint: Label


func _ready() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	_win = _label(96)
	_win.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_win.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_win.grow_vertical = Control.GROW_DIRECTION_BOTH
	_win.offset_top = -160.0
	_win.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_root.add_child(_win)
	_win_hint = _label(36)
	_win_hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_win_hint.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_win_hint.offset_top = -20.0
	_win_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_win_hint.text = ""
	_root.add_child(_win_hint)


# Builds the player panels for a new match.
func reset() -> void:
	for panel in _panels:
		panel[2].queue_free()
	_panels.clear()
	var count: int = sim.fighters.size()
	for i in count:
		var box := VBoxContainer.new()
		box.anchor_left = 0.5
		box.anchor_right = 0.5
		box.anchor_top = 1.0
		box.anchor_bottom = 1.0
		box.offset_left = (i - count / 2.0) * PANEL_WIDTH
		box.offset_right = box.offset_left + PANEL_WIDTH
		box.offset_top = -224.0
		box.offset_bottom = -92.0
		box.alignment = BoxContainer.ALIGNMENT_END
		var name_label := _label(28)
		name_label.text = "%s  %s" % [labels[i], sim.fighters[i].stats.fighter_name]
		name_label.add_theme_color_override("font_color", colors[i])
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var damage := _label(64)
		damage.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var stocks := HBoxContainer.new()
		stocks.alignment = BoxContainer.ALIGNMENT_CENTER
		box.add_child(name_label)
		box.add_child(damage)
		box.add_child(stocks)
		_root.add_child(box)
		_panels.append([damage, stocks, box])
	_win.visible = false
	_win_hint.visible = false
	refresh()


# Called every tick after the simulation step.
func refresh() -> void:
	for i in _panels.size():
		var f = sim.fighters[i]
		var damage: Label = _panels[i][0]
		damage.text = "%d%%" % int(f.damage)
		# White at 0 %, red towards 150 %: the higher the damage, the farther the fighter flies.
		damage.add_theme_color_override("font_color",
				Color.WHITE.lerp(Color("ff3030"), clampf(f.damage / 150.0, 0.0, 1.0)))
		damage.modulate.a = 0.35 if f.out else 1.0
		var stocks: HBoxContainer = _panels[i][1]
		while stocks.get_child_count() > f.stocks:
			var last := stocks.get_child(stocks.get_child_count() - 1)
			stocks.remove_child(last)
			last.queue_free()
		while stocks.get_child_count() < f.stocks:
			var stock := ColorRect.new()
			stock.color = colors[i]
			stock.custom_minimum_size = Vector2(STOCK_SIZE, STOCK_SIZE)
			stocks.add_child(stock)


func hide_winner() -> void:
	_win.visible = false
	_win_hint.visible = false


func show_winner(can_restart: bool) -> void:
	if sim.winner >= 0:
		_win.text = "%s wins!" % labels[sim.winner]
		_win.add_theme_color_override("font_color", colors[sim.winner])
	else:
		_win.text = "Draw!"
		_win.add_theme_color_override("font_color", Color.WHITE)
	_win.visible = true
	_win_hint.visible = can_restart


func _label(size: int) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_constant_override("outline_size", maxi(size / 6, 6))
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

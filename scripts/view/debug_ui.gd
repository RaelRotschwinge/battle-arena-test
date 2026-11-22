# Aids for trying and tuning the game by hand: a help line, the info overlay (F1) and the tuning
# panel (F2). The panel changes the fighter values at once; "Save" keeps them for the next start.
extends CanvasLayer

const FighterStats := preload("res://scripts/sim/fighter_stats.gd")
const FighterState := preload("res://scripts/sim/fighter_state.gd")
const TuningStore := preload("res://scripts/view/tuning_store.gd")

const HELP := "P1: W A S D, Space attack, E special, left Shift shield     P2: arrows, Enter" \
		+ " attack, Backspace special, right Shift shield     Esc pause     F1 info     F2 tuning" \
		+ "     F5 restart"

var sim
var stats  # The tuned fighter's stats (the first player's).
var fighter_id := "test"

var _info: Label
var _root: Control
var _title: Label
var _panel: PanelContainer
var _status: Label
var _rows := {}  # Value name -> [slider, value label].


func _ready() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = Theme.new()
	root.theme.default_font_size = 22
	add_child(root)

	var help := Label.new()
	help.text = HELP
	help.anchor_top = 1.0
	help.anchor_bottom = 1.0
	help.offset_left = 16.0
	help.offset_top = -48.0
	help.offset_bottom = -16.0
	_outline(help)
	root.add_child(help)

	_info = Label.new()
	_info.position = Vector2(16.0, 16.0)
	_info.visible = false
	_outline(_info)
	root.add_child(_info)

	_root = root


func _ensure_tuning() -> void:
	if _panel == null:
		_panel = _build_tuning()
		_root.add_child(_panel)


func toggle_info() -> bool:
	_info.visible = not _info.visible
	return _info.visible


func toggle_tuning() -> void:
	_ensure_tuning()
	_panel.visible = not _panel.visible
	_title.text = "Tuning %s: changes apply at once" % stats.fighter_name
	_refresh_sliders()


func _process(_delta: float) -> void:
	if not _info.visible or sim == null:
		return
	var lines := PackedStringArray(["tick %d" % sim.tick])
	for i in sim.fighters.size():
		var f = sim.fighters[i]
		lines.append("P%d  %s  position %.0f, %.0f  speed %.1f, %.1f  jumps %d  shield %d%s%s%s%s%s" % [
			i + 1, FighterState.Mode.keys()[f.mode].to_lower(), f.position.x, f.position.y,
			f.velocity.x, f.velocity.y, f.jumps_left, int(f.shield_hp),
			"  running" if f.running else "",
			"  fast fall" if f.fast_falling else "",
			"  %s %d" % [f.attack, f.attack_ticks] if f.attack != "" else "",
			"  hitstun %d" % f.hitstun if f.hitstun > 0 else "",
			"  hitlag %d" % f.hitlag if f.hitlag > 0 else ""])
	_info.text = "\n".join(lines)


func _build_tuning() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.offset_left = -640.0
	panel.offset_right = -16.0
	panel.offset_top = 16.0
	panel.anchor_bottom = 1.0
	panel.offset_bottom = -64.0
	panel.visible = false
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(box)
	_title = Label.new()
	box.add_child(_title)

	for entry in FighterStats.TUNABLE:
		var key: String = entry[0]
		var row := HBoxContainer.new()
		var name_label := Label.new()
		name_label.text = key.replace("_", " ")
		name_label.custom_minimum_size.x = 260.0
		var slider := HSlider.new()
		slider.min_value = entry[1]
		slider.max_value = entry[2]
		slider.step = entry[3]
		slider.custom_minimum_size.x = 240.0
		slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		slider.focus_mode = Control.FOCUS_NONE  # Arrow keys belong to player 2.
		var value_label := Label.new()
		value_label.custom_minimum_size.x = 80.0
		row.add_child(name_label)
		row.add_child(slider)
		row.add_child(value_label)
		box.add_child(row)
		_rows[key] = [slider, value_label]
		slider.value_changed.connect(_on_slider_changed.bind(key))

	var buttons := HBoxContainer.new()
	buttons.add_child(_button("Save", _on_save))
	buttons.add_child(_button("Defaults", _on_defaults))
	box.add_child(buttons)
	_status = Label.new()
	box.add_child(_status)
	_refresh_sliders()
	return panel


func _button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE  # Space and Enter belong to the players.
	button.pressed.connect(action)
	return button


func _on_slider_changed(value: float, key: String) -> void:
	stats.set_value(key, value)
	_rows[key][1].text = _format(stats.get(key))
	_status.text = ""


func _on_save() -> void:
	var error := TuningStore.save(stats, fighter_id)
	if error == OK:
		_status.text = "Saved. These values load at every start."
	else:
		_status.text = "Saving failed (error %d)." % error


func _on_defaults() -> void:
	stats.reset_defaults()
	_refresh_sliders()
	_status.text = "Defaults back (not saved yet)."


func _refresh_sliders() -> void:
	for key in _rows:
		_rows[key][0].set_value_no_signal(stats.get(key))
		_rows[key][1].text = _format(stats.get(key))


func _format(value) -> String:
	return str(value) if typeof(value) == TYPE_INT else "%.2f" % value


func _outline(label: Label) -> void:
	label.add_theme_constant_override("outline_size", 6)
	label.add_theme_color_override("font_outline_color", Color.BLACK)

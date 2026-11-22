# The arena select screen (game design, "Menus"), after the fighter select: a big live preview of
# the arena under the cursor with its name, what makes it different and its size, and a grid of
# tiles with live previews on the right (every arena, the training arena, Random). Every player
# who joined moves the one cursor; attack picks, the shield key or B goes back to the fighter
# select with the picks kept.
extends Control

const Devices := preload("res://scripts/view/devices.gd")
const ArenaList := preload("res://arenas/arena_list.gd")
const ArenaPreview := preload("res://ui/arena_preview.gd")
const Overlay := preload("res://ui/overlay.gd")

const COLUMNS := 3
const TILE := Vector2(196, 110)
const TILE_STEP := Vector2(214, 160)
const GRID := Vector2(1236, 150)
const CURSOR := Color("ffd24a")
const FRAME := Color("2d3345")

var app
var setup := {}  # The match setup from the fighter select; "arena" is filled in here.

var _ids := []
var _at := 0
var _tiles := []  # Per id: [frame, preview, name].
var _big
var _name: Label
var _text: Label
var _facts: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.color = Color("161a24")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var title := Overlay.label(64)
	title.text = "Choose the arena"
	title.position = Vector2(0, 22)
	title.size = Vector2(1920, 90)
	add_child(title)
	var frame := ColorRect.new()
	frame.color = FRAME
	frame.position = Vector2(52, 142)
	frame.size = Vector2(1116, 636)
	add_child(frame)
	_big = ArenaPreview.new()
	_big.position = Vector2(60, 150)
	_big.size = Vector2(1100, 620)
	add_child(_big)
	_name = Overlay.label(52)
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_name.position = Vector2(60, 790)
	_name.size = Vector2(700, 70)
	add_child(_name)
	_facts = Overlay.label(26)
	_facts.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_facts.add_theme_color_override("font_color", Color("b0b4c0"))
	_facts.position = Vector2(660, 792)
	_facts.size = Vector2(500, 80)
	add_child(_facts)
	_text = Overlay.label(30)
	_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD
	_text.position = Vector2(60, 875)
	_text.size = Vector2(1100, 90)
	add_child(_text)

	var hazards_on: bool = setup.get("hazards", true)
	_ids = ArenaList.ids()
	_ids.erase("test")
	_ids += ["test", "random"]
	for i in _ids.size():
		var at := GRID + Vector2(i % COLUMNS, i / COLUMNS) * TILE_STEP
		var border := ColorRect.new()
		border.position = at - Vector2(6, 6)
		border.size = TILE + Vector2(12, 12)
		add_child(border)
		var preview := ArenaPreview.new()
		preview.position = at
		preview.size = TILE
		add_child(preview)
		preview.show_arena(_ids[i], hazards_on)
		var label := Overlay.label(24)
		label.text = _display_name(_ids[i])
		label.position = at + Vector2(-10, TILE.y + 8)
		label.size = Vector2(TILE.x + 20, 34)
		add_child(label)
		_tiles.append([border, preview, label])
	var hazards := Overlay.label(24)
	hazards.add_theme_color_override("font_color", Color("b0b4c0"))
	hazards.text = "Hazards %s: a rule on the fighter screen" % ("on" if hazards_on else "off")
	hazards.position = Vector2(1200, 640)
	hazards.size = Vector2(700, 40)
	add_child(hazards)
	var hint := Overlay.label(26)
	hint.text = "Directions: arena    Attack: fight!    Shield or B: back to the fighters"
	hint.position = Vector2(0, 1000)
	hint.size = Vector2(1920, 50)
	add_child(hint)
	_at = maxi(_ids.find(setup.get("arena_choice", "random")), 0)
	_refresh()
	Devices.swallow()


func _physics_process(_delta: float) -> void:
	for device in _devices():
		if Devices.pressed(device, "left"):
			_at = posmod(_at - 1, _ids.size())
		elif Devices.pressed(device, "right"):
			_at = posmod(_at + 1, _ids.size())
		elif Devices.pressed(device, "up"):
			_at = posmod(_at - COLUMNS, _ids.size())
		elif Devices.pressed(device, "down"):
			_at = posmod(_at + COLUMNS, _ids.size())
		elif Devices.pressed(device, "confirm"):
			_start()
			return
		elif Devices.pressed(device, "back"):
			app.show_select()
			return
	_refresh()


# The devices of the players who joined.
func _devices() -> Array:
	var devices := []
	for player in setup.get("players", []):
		if player.get("cpu", 0) == 0 and Devices.has_device(player.get("device", "")):
			devices.append(player["device"])
	return devices


func _start() -> void:
	var choice: String = _ids[_at]
	var arena := choice
	if arena == "random":
		arena = ArenaList.pick_random(setup.get("arena", ""), Time.get_ticks_msec() / 16)
	var match_setup := setup.duplicate(true)
	match_setup["arena"] = arena
	match_setup["arena_choice"] = choice
	app.start_match(match_setup)


func _refresh() -> void:
	var id: String = _ids[_at]
	_big.show_arena(id, setup.get("hazards", true))
	_name.text = _display_name(id)
	if id == "random":
		_facts.text = ""
		_text.text = "Any arena but the training one, and not the last one played."
	else:
		_facts.text = ArenaList.facts(id)
		_text.text = ArenaList.description(id)
	for i in _tiles.size():
		var chosen := i == _at
		_tiles[i][0].color = CURSOR if chosen else FRAME
		_tiles[i][2].add_theme_color_override("font_color", CURSOR if chosen else Color.WHITE)


func _display_name(id: String) -> String:
	if id == "test":
		return "Training"
	return "Random" if id == "random" else ArenaList.display_name(id)

# The arena select screen (game design, "Menus"), after the fighter select: a big live preview of
# the arena under the cursor with its name on a plate, what makes it different and its size as
# chips, and a grid of tiles with live previews on the right (every arena, the training arena,
# Random). Every player who joined moves the one cursor; attack picks, the shield key or B goes
# back to the fighter select with the picks kept. The cursor glides and the tile under it grows.
# With the mouse: click a tile to choose it, click it again or "Fight!" to start, "Back" returns.
extends Control

const Devices := preload("res://scripts/view/devices.gd")
const ArenaList := preload("res://arenas/arena_list.gd")
const ArenaPreview := preload("res://ui/arena_preview.gd")
const Overlay := preload("res://ui/overlay.gd")
const MenuBackground := preload("res://ui/menu_background.gd")
const UiDraw := preload("res://ui/ui_draw.gd")
const Roster := preload("res://fighters/roster.gd")
const FighterState := preload("res://scripts/sim/fighter_state.gd")
const FighterFigure := preload("res://ui/fighter_figure.gd")
const Sounds := preload("res://scripts/view/sounds.gd")

const COLUMNS := 3
const TILE := Vector2(196, 110)
const TILE_STEP := Vector2(214, 160)
const GRID := Vector2(1236, 150)
const BIG := Rect2(60, 150, 1100, 620)
const CURSOR := Color("ffd24a")
const FRAME := Color("3d465f")
const GROWN := 1.06  # The scale of the tile under the cursor.
const MATCH_CARD := Rect2(1222, 690, 656, 284)  # Who fights, under the tiles.
const THUMB_SCALE := 2.0  # Tile pictures are drawn at twice their size, for the supersampling.
const THUMB_FRAMES := 3  # Frames the tile pictures render before they hold still.
const BACK := Rect2(60, 1000, 200, 54)
const FIGHT := Rect2(1660, 1000, 220, 54)

var app
var setup := {}  # The match setup from the fighter select; "arena" is filled in here.

var _ids := []
var _at := 0
var _tiles := []  # Per id: [preview, name].
var _big
var _text: Label
var _decor: Control  # Frames, drawn under the previews.
var _front: Control  # Cursor, name plate and chips, drawn over them.
var _scales := []  # Per tile: its scale, eased.
var _cursor := Vector2(-1.0, -1.0)  # The cursor's top left corner, eased.
var _shown := -1  # The tile the big preview shows.
var _since_change := 10.0
var _facts := []  # The chips under the big preview.
var _roster := []  # Per player of the match: [label, fighter name, color, x, roster id].
var _thumbs := []  # Per tile picture: [viewport, preview], stopped after THUMB_FRAMES.
var _thumb_frames := THUMB_FRAMES
var _hover := ""  # "tile<n>", "back", "fight" or "".
var _t := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := MenuBackground.new()
	background.title = "Choose the arena"
	add_child(background)
	_decor = _layer(_draw_decor)
	_big = ArenaPreview.new()
	_big.position = BIG.position
	_big.size = BIG.size
	add_child(_big)
	_text = Overlay.label(28)
	_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD
	_text.add_theme_color_override("font_color", Color("dde1ea"))
	_text.position = Vector2(60, 880)
	_text.size = Vector2(1100, 90)
	add_child(_text)

	var hazards_on: bool = setup.get("hazards", true)
	_ids = ArenaList.ids()
	_ids.erase("test")
	_ids += ["test", "random"]
	for i in _ids.size():
		var at := _tile_at(i)
		var preview := _thumbnail(_ids[i], hazards_on)
		preview.position = at
		preview.size = TILE
		preview.pivot_offset = TILE / 2.0
		add_child(preview)
		var label := Overlay.label(24)
		label.text = _display_name(_ids[i])
		label.position = at + Vector2(-10, TILE.y + 8)
		label.size = Vector2(TILE.x + 20, 34)
		add_child(label)
		_tiles.append([preview, label])
		_scales.append(1.0)
	_match_card(setup.get("players", []))
	_front = _layer(_draw_front)
	var hazards := Overlay.label(23)
	hazards.add_theme_color_override("font_color", Color("b0b4c0"))
	hazards.text = "Hazards %s: a rule on the fighter screen" % ("on" if hazards_on else "off")
	hazards.position = Vector2(1200, 646)
	hazards.size = Vector2(700, 40)
	add_child(hazards)
	var hint := Overlay.label(25)
	hint.add_theme_color_override("font_color", Color("c3c8d6"))
	hint.text = "Directions: arena    Attack: fight!    Shield or B: back to the fighters"
	hint.position = Vector2(0, 1004)
	hint.size = Vector2(1920, 50)
	add_child(hint)
	_at = maxi(_ids.find(setup.get("arena_choice", "random")), 0)
	_refresh()
	Devices.swallow()


# A tile: the arena drawn a few frames into a small viewport, then shown as a still picture, so
# the grid costs one texture per frame; only the big preview stays live. Random stays a drawing.
func _thumbnail(id: String, hazards_on: bool) -> Control:
	var preview := ArenaPreview.new()
	preview.size = TILE
	if id == "random":
		preview.show_arena(id, hazards_on)
		return preview
	var viewport := SubViewport.new()
	viewport.size = Vector2i((TILE * THUMB_SCALE).round())
	viewport.size_2d_override = Vector2i(TILE.round())
	viewport.size_2d_override_stretch = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	viewport.add_child(preview)
	preview.show_arena(id, hazards_on)
	_thumbs.append([viewport, preview])
	var picture := TextureRect.new()
	picture.texture = viewport.get_texture()
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_SCALE
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return picture


func _layer(drawer: Callable) -> Control:
	var layer := Control.new()
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.draw.connect(drawer)
	add_child(layer)
	return layer


func _tile_at(i: int) -> Vector2:
	return GRID + Vector2(i % COLUMNS, i / COLUMNS) * TILE_STEP


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
			Sounds.cue("back")
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
	Sounds.cue("confirm")
	app.start_match(match_setup)


func _refresh() -> void:
	if _at == _shown:
		return
	if _shown >= 0:  # Not for the first arena shown.
		Sounds.cue("arena")
	_shown = _at
	_since_change = 0.0
	var id: String = _ids[_at]
	_big.show_arena(id, setup.get("hazards", true))
	_facts = []
	if id == "random":
		_text.text = "Any arena but the training one, and not the last one played."
	else:
		for line in ArenaList.facts(id).split("\n"):
			_facts += Array(line.split(",  "))
		_text.text = ArenaList.description(id)
	for i in _tiles.size():
		_tiles[i][1].add_theme_color_override("font_color", CURSOR if i == _at else Color.WHITE)


func _process(delta: float) -> void:
	_t += delta
	if _thumb_frames > 0:
		_thumb_frames -= 1
		if _thumb_frames == 0:  # The pictures keep their last frame.
			for thumb in _thumbs:
				thumb[0].render_target_update_mode = SubViewport.UPDATE_DISABLED
				thumb[1].process_mode = Node.PROCESS_MODE_DISABLED
	_since_change += delta
	var blend := 1.0 - exp(-delta * 16.0)
	for i in _tiles.size():
		_scales[i] = lerpf(_scales[i], GROWN if i == _at else 1.0, blend)
		_tiles[i][0].scale = Vector2.ONE * _scales[i]
	_hover = _part_at(get_local_mouse_position()) \
			if get_viewport_rect().has_point(get_viewport().get_mouse_position()) else ""
	var target := _tile_at(_at)
	_cursor = target if _cursor.x < 0.0 else _cursor.lerp(target, blend)
	_decor.queue_redraw()
	_front.queue_redraw()


func _gui_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click == null or not click.pressed or click.button_index != MOUSE_BUTTON_LEFT:
		return
	accept_event()
	var part := _part_at(click.position)
	if part == "back":
		Sounds.cue("back")
		app.show_select()
	elif part == "fight":
		_start()
	elif part.begins_with("tile"):
		var i := int(part.substr(4))
		if i == _at:
			_start()
		else:
			_at = i
			_refresh()


# What is under the point: "tile<n>", "back", "fight" or "".
func _part_at(p: Vector2) -> String:
	if BACK.has_point(p):
		return "back"
	if FIGHT.has_point(p):
		return "fight"
	for i in _tiles.size():
		if _grown(i).grow(6.0).has_point(p):
			return "tile%d" % i
	return ""


func _display_name(id: String) -> String:
	if id == "test":
		return "Training"
	return "Random" if id == "random" else ArenaList.display_name(id)


# The frame of the big preview and a frame and shadow per tile.
func _draw_decor() -> void:
	UiDraw.glow(_decor, BIG.get_center() + Vector2(0, 20), BIG.size * 0.62, Color(0, 0, 0, 0.5))
	UiDraw.panel(_decor, BIG.grow(14.0), 20.0, Color("4a5474"), Color("262b3d"), UiDraw.INK, 3.0)
	for i in _tiles.size():
		var rect := _grown(i).grow(5.0)
		UiDraw.panel(_decor, Rect2(rect.position + Vector2(0, 6), rect.size), 12.0,
				Color(0, 0, 0, 0.35), Color(0, 0, 0, 0.35))
		UiDraw.panel(_decor, rect, 12.0, FRAME.lightened(0.1), FRAME.darkened(0.25))
	UiDraw.panel(_decor, MATCH_CARD, 18.0, Color(UiDraw.PANEL_TOP, 0.9),
			Color(UiDraw.PANEL_BOTTOM, 0.9), FRAME, 2.0)
	for p in _roster:  # A lit floor under each fighter in the player's color.
		var feet := Vector2(p[3], MATCH_CARD.position.y + 196.0)
		UiDraw.glow(_decor, feet + Vector2(0, -50), Vector2(90, 110), Color(p[2], 0.18))


func _grown(i: int) -> Rect2:
	var s: float = _scales[i]
	return Rect2(_tile_at(i) + TILE / 2.0 - TILE * s / 2.0, TILE * s)


func _draw_front() -> void:
	_front.draw_rect(BIG, UiDraw.INK, false, 3.0)
	# A short dark flash on the big preview when the arena changes.
	var flash := 1.0 - UiDraw.out_cubic(_since_change / 0.25)
	if flash > 0.0:
		_front.draw_rect(BIG, Color(0.04, 0.05, 0.08, 0.7 * flash))
	# The cursor: a gold ring that glides between the tiles and pulses.
	var s: float = _scales[_at]
	var ring := Rect2(_cursor + TILE / 2.0 - TILE * s / 2.0, TILE * s).grow(6.0)
	var pulse := 0.5 + 0.5 * sin(_t * 5.0)
	UiDraw.glow(_front, ring.get_center(), ring.size * 0.8, Color(CURSOR, 0.14 + 0.1 * pulse))
	var points := UiDraw.rounded(ring, 14.0)
	points.append(points[0])
	_front.draw_polyline(points, UiDraw.INK, 9.0, true)
	_front.draw_polyline(points, CURSOR, 5.0, true)
	_name_plate()
	_fact_chips()
	_match_labels()
	if _hover.begins_with("tile") and int(_hover.substr(4)) != _at:  # A light ring on hover.
		var hovered := UiDraw.rounded(_grown(int(_hover.substr(4))).grow(5.0), 12.0)
		hovered.append(hovered[0])
		_front.draw_polyline(hovered, Color(1, 1, 1, 0.75), 3.0, true)
	_button(BACK, "Back", Color("3a4462"), Color.WHITE)
	_button(FIGHT, "Fight!", Color("f0ac2a"), Color("1b1e2a"))


func _button(rect: Rect2, label: String, fill: Color, ink: Color) -> void:
	var hot := _hover == label.to_lower().trim_suffix("!")
	if hot:
		UiDraw.glow(_front, rect.get_center(), rect.size * Vector2(0.7, 1.3), Color(fill, 0.3))
	UiDraw.chip(_front, rect, label, 26, fill.lightened(0.15) if hot else fill, ink,
			Color.WHITE if hot else UiDraw.INK)


# The arena's name on a slanted plate over the preview's bottom left corner; it slides in.
func _name_plate() -> void:
	var font := UiDraw.bold()
	var shown := _display_name(_ids[_at])
	var k := UiDraw.out_cubic(_since_change / 0.3)
	var width := UiDraw.text_width(shown, 54, font) + 90.0
	var x := 34.0 - (1.0 - k) * 40.0
	var top := BIG.end.y - 30.0
	var plate := PackedVector2Array([Vector2(x + 24, top), Vector2(x + width + 24, top),
			Vector2(x + width, top + 74), Vector2(x, top + 74)])
	var gold_top := Color(CURSOR.lightened(0.25), k)
	var gold_bottom := Color(CURSOR.darkened(0.15), k)
	_front.draw_polygon(plate, PackedColorArray([gold_top, gold_top, gold_bottom, gold_bottom]))
	plate.append(plate[0])
	_front.draw_polyline(plate, Color(UiDraw.INK, k), 4.0, true)
	UiDraw.text(_front, Vector2(x + 50.0, top + 57.0), shown, 54, Color(Color("1b1e2a"), k),
			HORIZONTAL_ALIGNMENT_LEFT, -1.0, font, 0)


# The facts as chips, right-aligned under the preview.
func _fact_chips() -> void:
	var x := BIG.end.x
	for n in range(_facts.size() - 1, -1, -1):
		var fact: String = _facts[n]
		var width := UiDraw.chip_width(fact, 22)
		x -= width
		var lit := fact in ["moving parts", "hazards", "walls"]
		UiDraw.chip(_front, Rect2(x, BIG.end.y + 26.0, width, 40.0), fact, 22,
				Color("3a4462") if not lit else Color("6a4b1c"),
				Color.WHITE if not lit else CURSOR.lightened(0.3), Color("525d80") if not lit
				else Color(CURSOR, 0.6))
		x -= 10.0


# The fighters of the match standing in a row, in their player colors.
func _match_card(players: Array) -> void:
	var cpu := 0
	for i in players.size():
		var player: Dictionary = players[i]
		var level: int = player.get("cpu", 0)
		if level > 0:
			cpu += 1
		var id: String = player.get("fighter", "")
		var x := MATCH_CARD.position.x + MATCH_CARD.size.x * (i + 0.5) / players.size()
		var slot: int = player.get("slot", i)  # The fighter select panel: number and color.
		var color: Color = UiDraw.PLAYER_COLORS[slot % UiDraw.PLAYER_COLORS.size()]
		_roster.append(["CPU %d" % cpu if level > 0 else "P%d" % (slot + 1),
				"Random" if id == "random" else Roster.display_name(id), color, x, id])
		if id == "random":
			continue
		var f := FighterState.new()
		f.stats = Roster.make(id)
		f.mode = FighterState.Mode.GROUND
		f.facing = 1 if x < MATCH_CARD.get_center().x else -1
		var figure := FighterFigure.new()
		figure.f = f
		figure.color = color
		figure.size = 1.2
		figure.position = Vector2(x, MATCH_CARD.position.y + 196.0)
		add_child(figure)


func _match_labels() -> void:
	var top := MATCH_CARD.position.y
	UiDraw.text(_front, Vector2(MATCH_CARD.position.x + 24.0, top + 36.0), "THE MATCH", 20,
			UiDraw.DIM, HORIZONTAL_ALIGNMENT_LEFT, -1.0, null, 0)
	var lives: int = setup.get("stocks", 3)
	UiDraw.text(_front, Vector2(MATCH_CARD.position.x, top + 36.0), "%d %s" % [lives,
			"life" if lives == 1 else "lives"], 22, Color.WHITE, HORIZONTAL_ALIGNMENT_RIGHT,
			MATCH_CARD.size.x - 24.0, null, 0)
	var font := UiDraw.bold()
	for p in _roster:
		var x: float = p[3]
		if p[4] == "random":
			UiDraw.text(_front, Vector2(x - 60.0, top + 186.0), "?", 110, UiDraw.GOLD,
					HORIZONTAL_ALIGNMENT_CENTER, 120.0, font, 12)
		UiDraw.text(_front, Vector2(x - 80.0, top + 236.0), p[0], 28, p[2],
				HORIZONTAL_ALIGNMENT_CENTER, 160.0, font, 6)
		UiDraw.text(_front, Vector2(x - 80.0, top + 266.0), p[1], 21, UiDraw.DIM,
				HORIZONTAL_ALIGNMENT_CENTER, 160.0, null, 0)
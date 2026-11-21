# The join and select screen (game design, "Menus"): every device joins with its attack key or
# button and picks a fighter with left and right; attack again is ready. A ready player changes the
# match settings below (arena, lives, computer opponents) with the directions, and attack starts
# the match. The shield key or B steps back.
extends Control

const Devices := preload("res://scripts/view/devices.gd")
const Roster := preload("res://fighters/roster.gd")
const ArenaList := preload("res://arenas/arena_list.gd")
const CpuPlayer := preload("res://scripts/sim/cpu_player.gd")
const Overlay := preload("res://ui/overlay.gd")

const SLOTS := 4
const COLORS := [Color("e8553e"), Color("3e8fe8"), Color("e8c33e"), Color("4ec96a")]
const STOCK_CHOICES := [1, 2, 3, 4, 5]
const ROWS := ["arena", "stocks", "cpus", "cpu_level"]

var app
# The setup kept from the last time: {"players": [...], "arena", "stocks", "cpus", "cpu_level"}.
var setup := {}

var _slots := []  # Per slot: {} empty, or {"device", "fighter", "ready"}.
var _row := 0
var _arena := "random"
var _stocks := 3
var _cpus := 0
var _cpu_level := 2
var _cards := []  # Per slot: [panel, title, fighter, hint].
var _settings: Label
var _hint: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.color = Color("161a24")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var title := Overlay.label(72)
	title.text = "Choose your fighters"
	title.position = Vector2(0, 60)
	title.size = Vector2(1920, 100)
	add_child(title)
	for i in SLOTS:
		var panel := Panel.new()
		panel.position = Vector2(150 + i * 420, 210)
		panel.size = Vector2(380, 420)
		add_child(panel)
		var name_label := Overlay.label(40)
		name_label.position = Vector2(0, 24)
		name_label.size = Vector2(380, 60)
		panel.add_child(name_label)
		var fighter := Overlay.label(52)
		fighter.position = Vector2(0, 150)
		fighter.size = Vector2(380, 80)
		panel.add_child(fighter)
		var hint := Overlay.label(24)
		hint.position = Vector2(10, 280)
		hint.size = Vector2(360, 120)
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD
		panel.add_child(hint)
		_cards.append([panel, name_label, fighter, hint])
	_settings = Overlay.label(36)
	_settings.position = Vector2(0, 680)
	_settings.size = Vector2(1920, 230)
	add_child(_settings)
	_hint = Overlay.label(26)
	_hint.position = Vector2(0, 940)
	_hint.size = Vector2(1920, 100)
	add_child(_hint)
	_load_setup()
	_refresh()
	Devices.swallow()


func _load_setup() -> void:
	_slots = []
	for i in SLOTS:
		_slots.append({})
	_arena = setup.get("arena_choice", "random")
	_stocks = setup.get("stocks", 3)
	_cpus = setup.get("cpus", 0)
	_cpu_level = setup.get("cpu_level", 2)
	var i := 0
	for player in setup.get("players", []):
		if player.get("cpu", 0) == 0 and Devices.has_device(player["device"]) and i < SLOTS:
			_slots[i] = {"device": player["device"], "fighter": player["fighter"],
					"ready": false}
			i += 1


func _physics_process(_delta: float) -> void:
	for device in Devices.all():
		var slot := _slot_of(device)
		if slot < 0:
			if Devices.pressed(device, "confirm"):
				_join(device)
			elif Devices.pressed(device, "back") and _humans() == 0:
				app.show_main_menu()
				return
			continue
		var player: Dictionary = _slots[slot]
		if not player["ready"]:
			if Devices.pressed(device, "left"):
				player["fighter"] = _cycle(Roster.ids(), player["fighter"], -1)
			elif Devices.pressed(device, "right"):
				player["fighter"] = _cycle(Roster.ids(), player["fighter"], 1)
			elif Devices.pressed(device, "confirm"):
				player["ready"] = true
			elif Devices.pressed(device, "back"):
				_slots[slot] = {}
				if _humans() == 0:
					app.show_main_menu()
					return
		else:
			if Devices.pressed(device, "back"):
				player["ready"] = false
			elif Devices.pressed(device, "up"):
				_row = posmod(_row - 1, ROWS.size())
			elif Devices.pressed(device, "down"):
				_row = posmod(_row + 1, ROWS.size())
			elif Devices.pressed(device, "left"):
				_change(-1)
			elif Devices.pressed(device, "right"):
				_change(1)
			elif Devices.pressed(device, "confirm") and _can_start():
				_start()
				return
	_refresh()


func _join(device: String) -> void:
	for i in SLOTS:
		if _slots[i].is_empty():
			var ids := Roster.ids()
			_slots[i] = {"device": device, "fighter": ids[i % ids.size()], "ready": false}
			if _humans() + _cpus > SLOTS:
				_cpus = SLOTS - _humans()
			return


func _change(step: int) -> void:
	match ROWS[_row]:
		"arena":
			_arena = _cycle(["random"] + ArenaList.ids(), _arena, step)
		"stocks":
			_stocks = STOCK_CHOICES[posmod(STOCK_CHOICES.find(_stocks) + step, STOCK_CHOICES.size())]
		"cpus":
			_cpus = clampi(_cpus + step, 0, SLOTS - _humans())
		"cpu_level":
			_cpu_level = clampi(_cpu_level + step, 1, 3)


func _can_start() -> bool:
	if _humans() == 0 or _humans() + _cpus < 2:
		return false
	for slot in _slots:
		if not slot.is_empty() and not slot["ready"]:
			return false
	return true


func _start() -> void:
	var players := []
	for slot in _slots:
		if not slot.is_empty():
			players.append({"device": slot["device"], "cpu": 0, "fighter": slot["fighter"]})
	var ids := Roster.ids()
	for n in _cpus:
		players.append({"device": "", "cpu": _cpu_level,
				"fighter": ids[(players.size() + n) % ids.size()]})
	var arena := _arena
	if arena == "random":
		var choices := ArenaList.ids()
		var last: String = setup.get("arena", "")
		if choices.size() > 1:
			choices.erase(last)
		arena = choices[(Time.get_ticks_msec() / 16) % choices.size()]
	app.start_match({"players": players, "arena": arena, "arena_choice": _arena,
			"stocks": _stocks, "cpus": _cpus, "cpu_level": _cpu_level})


func _refresh() -> void:
	var cpus_left := _cpus  # Computer players take the first empty slots.
	for i in SLOTS:
		var card: Array = _cards[i]
		var slot: Dictionary = _slots[i]
		var cpu_slot: bool = slot.is_empty() and cpus_left > 0
		if cpu_slot:
			cpus_left -= 1
		card[0].modulate = Color(1, 1, 1, 1) if not slot.is_empty() or cpu_slot \
				else Color(1, 1, 1, 0.45)
		if not slot.is_empty():
			card[1].text = "P%d  %s" % [i + 1, Devices.label(slot["device"])]
			card[1].add_theme_color_override("font_color", COLORS[i])
			card[2].text = "< %s >" % Roster.display_name(slot["fighter"])
			card[3].text = "READY" if slot["ready"] else "Left / right: fighter\nAttack: ready"
		elif cpu_slot:
			card[1].text = "CPU  %s" % CpuPlayer.LEVEL_NAMES[_cpu_level]
			card[1].add_theme_color_override("font_color", Color("b0b4c0"))
			card[2].text = Roster.display_name(
					Roster.ids()[(i) % Roster.ids().size()])
			card[3].text = ""
		else:
			card[1].text = "Join"
			card[1].add_theme_color_override("font_color", Color.WHITE)
			card[2].text = ""
			card[3].text = "Press attack (Space, Enter, gamepad A or X)"
	var arena_name := "Random" if _arena == "random" else ArenaList.display_name(_arena)
	var values := [arena_name, str(_stocks), str(_cpus), CpuPlayer.LEVEL_NAMES[_cpu_level]]
	var names := ["Arena", "Lives", "Computer players", "Computer level"]
	var lines := PackedStringArray()
	for r in ROWS.size():
		var line := "%s:  < %s >" % [names[r], values[r]]
		lines.append(("> " + line + " <") if r == _row and _any_ready() else line)
	_settings.text = "\n".join(lines)
	if _humans() == 0:
		_hint.text = "Press attack to join.   Shield or B: back to the main menu"
	elif not _any_ready():
		_hint.text = "Pick a fighter, then attack: ready.   Shield or B: leave"
	elif not _can_start():
		_hint.text = "Ready players: up / down / left / right change the match." \
				+ "   Needs two fighters: a second player or a computer player"
	else:
		_hint.text = "Ready players: up / down / left / right change the match.   Attack: fight!"


func _any_ready() -> bool:
	for slot in _slots:
		if not slot.is_empty() and slot["ready"]:
			return true
	return false


func _humans() -> int:
	var count := 0
	for slot in _slots:
		if not slot.is_empty():
			count += 1
	return count


func _slot_of(device: String) -> int:
	for i in SLOTS:
		if not _slots[i].is_empty() and _slots[i]["device"] == device:
			return i
	return -1


func _cycle(list: Array, value, step: int):
	var at := list.find(value)
	return list[posmod(at + step, list.size())]

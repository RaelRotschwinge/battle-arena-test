# The fighter select screen (game design, "Menus"): every device joins with its attack key or
# button and picks a fighter with left and right (or Random); attack again is ready. Each panel
# shows the fighter, its stat sheet and its special with the player's own key. Ready players
# change the match rules at the bottom (lives, computer players, their level, hazards) with the
# directions, and attack goes on to the arena select. The shield key or B steps back.
extends Control

const Devices := preload("res://scripts/view/devices.gd")
const Roster := preload("res://fighters/roster.gd")
const CpuPlayer := preload("res://scripts/sim/cpu_player.gd")
const Overlay := preload("res://ui/overlay.gd")
const FighterCard := preload("res://ui/fighter_card.gd")

const SLOTS := 4
const COLORS := [Color("e8553e"), Color("3e8fe8"), Color("e8c33e"), Color("4ec96a")]
const STOCK_CHOICES := [1, 2, 3, 4, 5]
const ROWS := ["stocks", "cpus", "cpu_level", "hazards"]
const ROW_NAMES := ["Lives", "Computer players", "Level", "Hazards"]

var app
# The setup kept from the last time: {"players", "arena", "arena_choice", "stocks", "cpus",
# "cpu_level", "hazards"}.
var setup := {}

var _slots := []  # Per slot: {} empty, or {"device", "fighter", "ready"}.
var _row := 0
var _stocks := 3
var _cpus := 0
var _cpu_level := 2
var _hazards := true
var _cards := []
var _rules: Label
var _hint: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.color = Color("161a24")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var title := Overlay.label(64)
	title.text = "Choose your fighters"
	title.position = Vector2(0, 22)
	title.size = Vector2(1920, 90)
	add_child(title)
	for i in SLOTS:
		var card := FighterCard.new()
		card.color = COLORS[i]
		card.position = Vector2(40 + i * 470, 120)
		add_child(card)
		_cards.append(card)
	_rules = Overlay.label(32)
	_rules.position = Vector2(0, 952)
	_rules.size = Vector2(1920, 50)
	add_child(_rules)
	_hint = Overlay.label(24)
	_hint.add_theme_color_override("font_color", Color("b0b4c0"))
	_hint.position = Vector2(0, 1012)
	_hint.size = Vector2(1920, 44)
	add_child(_hint)
	_load_setup()
	_refresh()
	Devices.swallow()


func _load_setup() -> void:
	_slots = []
	for i in SLOTS:
		_slots.append({})
	_stocks = setup.get("stocks", 3)
	_cpus = setup.get("cpus", 0)
	_cpu_level = setup.get("cpu_level", 2)
	_hazards = setup.get("hazards", true)
	var i := 0
	for player in setup.get("players", []):
		if player.get("cpu", 0) == 0 and Devices.has_device(player["device"]) and i < SLOTS:
			_slots[i] = {"device": player["device"], "fighter": player["fighter"],
					"ready": false}
			i += 1


func _physics_process(_delta: float) -> void:
	var picks: Array = Roster.ids() + ["random"]
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
				player["fighter"] = _cycle(picks, player["fighter"], -1)
			elif Devices.pressed(device, "right"):
				player["fighter"] = _cycle(picks, player["fighter"], 1)
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
		"stocks":
			_stocks = STOCK_CHOICES[posmod(STOCK_CHOICES.find(_stocks) + step, STOCK_CHOICES.size())]
		"cpus":
			_cpus = clampi(_cpus + step, 0, SLOTS - _humans())
		"cpu_level":
			_cpu_level = clampi(_cpu_level + step, 1, 3)
		"hazards":
			_hazards = not _hazards


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
	for fighter in _cpu_fighters():
		players.append({"device": "", "cpu": _cpu_level, "fighter": fighter})
	var next := setup.duplicate(true)
	next.merge({"players": players, "stocks": _stocks, "cpus": _cpus, "cpu_level": _cpu_level,
			"hazards": _hazards}, true)
	app.show_arena_select(next)


# The fighters of the computer players: in roster order, first the ones no player picked.
func _cpu_fighters() -> Array:
	var taken := []
	for slot in _slots:
		if not slot.is_empty():
			taken.append(slot["fighter"])
	var order := []
	for id in Roster.ids():
		if not taken.has(id):
			order.append(id)
	order += Roster.ids()
	var fighters := []
	for n in _cpus:
		fighters.append(order[n % order.size()])
	return fighters


func _refresh() -> void:
	var cpu_fighters := _cpu_fighters()
	var cpu_at := 0  # Computer players take the first empty slots.
	for i in SLOTS:
		var card = _cards[i]
		var slot: Dictionary = _slots[i]
		if not slot.is_empty():
			var device: String = slot["device"]
			var hint := "Shield: back" if slot["ready"] else "Left / right: fighter    Attack: ready"
			card.show_card("player", "P%d   %s" % [i + 1, Devices.label(device)], slot["fighter"],
					slot["ready"], Devices.special_key(device), hint)
		elif cpu_at < cpu_fighters.size():
			card.show_card("cpu", "CPU   %s" % CpuPlayer.LEVEL_NAMES[_cpu_level],
					cpu_fighters[cpu_at], false, "", "Computer player")
			cpu_at += 1
		else:
			card.show_card("empty", "", "", false, "",
					"Press attack:\nSpace, Enter, gamepad A or X")
	var values := [str(_stocks), str(_cpus), CpuPlayer.LEVEL_NAMES[_cpu_level],
			"On" if _hazards else "Off"]
	var parts := PackedStringArray()
	for r in ROWS.size():
		var part := "%s  < %s >" % [ROW_NAMES[r], values[r]]
		parts.append(("[ %s ]" % part) if r == _row and _any_ready() else part)
	_rules.text = "        ".join(parts)
	_rules.add_theme_color_override("font_color", Color.WHITE if _any_ready() else Color("8a90a0"))
	if _humans() == 0:
		_hint.text = "Press attack to join.    Shield or B: back to the main menu"
	elif not _any_ready():
		_hint.text = "Pick a fighter, then attack: ready.    Shield or B: leave"
	elif not _can_start():
		_hint.text = "Ready players: up / down / left / right change the rules." \
				+ "    Two fighters needed: a second player or a computer player"
	else:
		_hint.text = "Ready players: up / down / left / right change the rules." \
				+ "    Attack: on to the arena"


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

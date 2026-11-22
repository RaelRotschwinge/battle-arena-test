# The fighter select screen (game design, "Menus"). Every player slot chooses its input device and
# locks it (device_slots.gd holds those rules): attack on a device that steers nothing joins the
# next panel with it, locked, or locks an open panel that chose it. In its panel the device moves
# a small focus between the Fighter row and the Controls row with up and down; left and right
# change the focused row (a new device opens the panel until attack is pressed on it); attack is
# ready, the shield key or B steps back (unready, then leave). Ready players change the match
# rules at the bottom with the directions, and attack goes on to the arena select.
#
# The mouse works every panel: click an empty panel to join, the arrows to change the fighter or
# the device, the padlock to lock or unlock, Ready, the cross to leave; rules chips (left click
# next value, right click the one before) and "On to the arena" once the match can start.
extends Control

const Devices := preload("res://scripts/view/devices.gd")
const Roster := preload("res://fighters/roster.gd")
const CpuPlayer := preload("res://scripts/sim/cpu_player.gd")
const Overlay := preload("res://ui/overlay.gd")
const FighterCard := preload("res://ui/fighter_card.gd")
const MenuBackground := preload("res://ui/menu_background.gd")
const DeviceSlots := preload("res://ui/device_slots.gd")
const UiDraw := preload("res://ui/ui_draw.gd")

const SLOTS := 4
const COLORS := [Color("e8553e"), Color("3e8fe8"), Color("e8c33e"), Color("4ec96a")]
const STOCK_CHOICES := [1, 2, 3, 4, 5]
const ROWS := ["stocks", "cpus", "cpu_level", "hazards"]
const ROW_NAMES := ["Lives", "Computer players", "Level", "Hazards"]
const START := Rect2(1584, 954, 300, 56)  # The "On to the arena" button.

var app
# The setup kept from the last time: {"players", "arena", "arena_choice", "stocks", "cpus",
# "cpu_level", "hazards"}.
var setup := {}

var _devices := DeviceSlots.new()  # Who joined, with which device, locked or open.
var _slots := []  # Per slot: {} empty, or {"device", "fighter", "ready"}; device from _devices.
var _focus := [0, 0, 0, 0]  # Per slot: the row its device works, 0 fighter, 1 controls.
var _row := 0
var _stocks := 3
var _cpus := 0
var _cpu_level := 2
var _hazards := true
var _cards := []
var _rules: RulesBar
var _hint: Label
var _buttons: Control  # The start button, drawn over everything.
var _start_hover := false


# The match rules as chips; the selected one is lit with arrows while a player is ready. The
# chip under the mouse is lit too.
class RulesBar extends Control:
	var names := []
	var values := []
	var row := 0
	var active := false
	var hover := -1
	var _t := 0.0
	var _glide := -1.0  # The highlight's x, eased toward the selected chip.

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	# The chips' rectangles, local.
	func chips() -> Array:
		var widths := []
		var total := -24.0
		for r in names.size():
			widths.append(26.0 + UiDraw.text_width(names[r].to_upper(), 19) + 44.0
					+ UiDraw.text_width(values[r], 28, UiDraw.bold()) + 44.0)
			total += widths[r] + 24.0
		var rects := []
		var x := (size.x - total) / 2.0
		for r in names.size():
			rects.append(Rect2(x, 0, widths[r], size.y))
			x += widths[r] + 24.0
		return rects

	func chip_at(p: Vector2) -> int:
		var rects := chips()
		for r in rects.size():
			if rects[r].has_point(p):
				return r
		return -1

	func _draw() -> void:
		var rects := chips()
		var alpha := 1.0 if active else 0.5
		for r in rects.size():
			var hot: bool = r == hover
			UiDraw.panel(self, rects[r], size.y / 2.0, Color("2c3247", alpha).lightened(
					0.12 if hot else 0.0), Color("1e2231", alpha),
					Color(1, 1, 1, 0.8) if hot else Color("454e6a", alpha), 2.0)
		if active:  # The gold ring glides to the selected chip.
			var lit: Rect2 = rects[row]
			_glide = lit.position.x if _glide < 0.0 else lerpf(_glide, lit.position.x, 0.3)
			var ring := Rect2(_glide, 0, lit.size.x, size.y)
			UiDraw.glow(self, ring.get_center(), ring.size * Vector2(0.7, 1.2),
					Color(UiDraw.GOLD, 0.12 + 0.06 * sin(_t * 4.0)))
			var points := UiDraw.rounded(ring.grow(1.0), size.y / 2.0)
			points.append(points[0])
			draw_polyline(points, UiDraw.GOLD, 4.0, true)
		for r in rects.size():
			var x: float = rects[r].position.x
			var base := UiDraw.baseline(0, size.y, 28)
			var chosen: bool = active and r == row
			var on: float = 1.0 if r == hover else alpha
			UiDraw.text(self, Vector2(x + 26.0, base - 1.0), names[r].to_upper(), 19,
					Color(UiDraw.DIM, on), HORIZONTAL_ALIGNMENT_LEFT, -1.0, null, 0)
			var vx: float = x + 26.0 + UiDraw.text_width(names[r].to_upper(), 19) + 44.0
			var vw := UiDraw.text_width(values[r], 28, UiDraw.bold())
			UiDraw.text(self, Vector2(vx, base), values[r], 28,
					Color(UiDraw.GOLD if chosen else Color.WHITE, on), HORIZONTAL_ALIGNMENT_LEFT,
					-1.0, UiDraw.bold(), 6)
			if chosen or r == hover:
				var bob := 2.0 * sin(_t * 6.0)
				var tone: Color = UiDraw.GOLD if chosen else Color.WHITE
				UiDraw.chevron(self, Vector2(vx - 20.0 - bob, size.y / 2.0), 8.0, -1, tone)
				UiDraw.chevron(self, Vector2(vx + vw + 20.0 + bob, size.y / 2.0), 8.0, 1, tone)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var background := MenuBackground.new()
	background.title = "Choose your fighters"
	add_child(background)
	for i in SLOTS:
		var card := FighterCard.new()
		card.color = COLORS[i]
		card.position = Vector2(40 + i * 470, 120)
		add_child(card)
		_cards.append(card)
	_rules = RulesBar.new()
	_rules.names = ROW_NAMES
	_rules.position = Vector2(0, 954)
	_rules.size = Vector2(1920, 56)
	add_child(_rules)
	_hint = Overlay.label(23)
	_hint.add_theme_color_override("font_color", Color("b0b4c0"))
	_hint.position = Vector2(0, 1022)
	_hint.size = Vector2(1920, 44)
	add_child(_hint)
	_buttons = Control.new()
	_buttons.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_buttons.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_buttons.draw.connect(_draw_buttons)
	add_child(_buttons)
	_load_setup()
	_refresh()
	Devices.swallow()


# The players of the last match come back in their slots, their devices locked, if still there.
func _load_setup() -> void:
	_slots = []
	for i in SLOTS:
		_slots.append({})
	_stocks = setup.get("stocks", 3)
	_cpus = setup.get("cpus", 0)
	_cpu_level = setup.get("cpu_level", 2)
	_hazards = setup.get("hazards", true)
	for player in setup.get("players", []):
		if player.get("cpu", 0) == 0 and Devices.has_device(player["device"]):
			var i := _devices.press(player["device"], Devices.all())
			if i >= 0:
				_slots[i] = {"device": player["device"], "fighter": player["fighter"],
						"ready": false}
	_sync()


func _physics_process(_delta: float) -> void:
	var all := Devices.all()
	_devices.forget_missing(all)
	var picks: Array = Roster.ids() + ["random"]
	for device in all:
		var slot := _devices.owner_of(device)
		if slot < 0:
			if Devices.pressed(device, "confirm"):
				_devices.press(device, all)
				_sync()
			elif Devices.pressed(device, "back") and _humans() == 0:
				app.show_main_menu()
				return
			continue
		var player: Dictionary = _slots[slot]
		if not player["ready"]:
			if Devices.pressed(device, "up") or Devices.pressed(device, "down"):
				_focus[slot] = 1 - _focus[slot]
			elif Devices.pressed(device, "left") or Devices.pressed(device, "right"):
				var step := -1 if Devices.pressed(device, "left") else 1
				if _focus[slot] == 0:
					player["fighter"] = _cycle(picks, player["fighter"], step)
				else:
					_devices.cycle(slot, step, all)  # Open now: attack on the new one locks it.
			elif Devices.pressed(device, "confirm"):
				player["ready"] = true
			elif Devices.pressed(device, "back"):
				if _leave(slot):
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
		_sync()
	_sync()
	_refresh()


# Copies who joined and with which device from _devices into _slots; an open slot is not ready.
func _sync() -> void:
	var ids := Roster.ids()
	for i in SLOTS:
		if not _devices.joined(i):
			_slots[i] = {}
			continue
		if _slots[i].is_empty():
			_slots[i] = {"device": "", "fighter": ids[i % ids.size()], "ready": false}
			_focus[i] = 0
		_slots[i]["device"] = _devices.device(i)
		if not _devices.locked(i):
			_slots[i]["ready"] = false
	if _humans() + _cpus > SLOTS:
		_cpus = SLOTS - _humans()


# Leaves slot i; true when nobody is left and the main menu comes back.
func _leave(i: int) -> bool:
	_devices.leave(i)
	_sync()
	if _humans() == 0:
		app.show_main_menu()
		return true
	return false


func _gui_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click == null or not click.pressed:
		return
	if click.button_index != MOUSE_BUTTON_LEFT and click.button_index != MOUSE_BUTTON_RIGHT:
		return
	var step := 1 if click.button_index == MOUSE_BUTTON_LEFT else -1
	var at := click.position
	var chip := _rules.chip_at(at - _rules.position)
	if chip >= 0:
		_row = chip
		_change(step)
	elif START.has_point(at):
		if _can_start():
			_start()
			return
	elif step == 1:
		for i in SLOTS:
			var part: String = _cards[i].hit(at - _cards[i].position)
			if part != "":
				if _click(i, part):
					return
				break
	_sync()
	_refresh()
	accept_event()


# A click on a part of panel i (fighter_card.gd's hit()); true when the screen was left.
func _click(i: int, part: String) -> bool:
	var all := Devices.all()
	var picks: Array = Roster.ids() + ["random"]
	match part:
		"join":
			_devices.join(i, all)
		"leave":
			return _leave(i)
		"lock":
			if _devices.locked(i):
				_devices.unlock(i)
			else:
				_devices.lock(i, all)
		"device-", "device+":
			_devices.cycle(i, -1 if part == "device-" else 1, all)
		"fighter-", "fighter+":
			_slots[i]["fighter"] = _cycle(picks, _slots[i]["fighter"], -1 if part == "fighter-"
					else 1)
		"ready":
			if _slots[i]["ready"]:
				_slots[i]["ready"] = false
			elif _devices.locked(i):
				_slots[i]["ready"] = true
	return false


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


# Every joined slot locked and ready, and two fighters at least.
func _can_start() -> bool:
	if _humans() == 0 or _humans() + _cpus < 2:
		return false
	for i in SLOTS:
		if _devices.joined(i) and not (_devices.locked(i) and _slots[i]["ready"]):
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


func _process(_delta: float) -> void:
	_hover(get_local_mouse_position())


# Lights what the mouse is over: a panel part, a rules chip, the start button.
func _hover(at: Vector2) -> void:
	var inside := get_viewport_rect().has_point(get_viewport().get_mouse_position())
	for i in SLOTS:
		var part: String = _cards[i].hit(at - _cards[i].position) if inside else ""
		_cards[i].set_controls(_device_name(_devices.device(i)), _devices.locked(i), _focus[i],
				part)
	_rules.hover = _rules.chip_at(at - _rules.position) if inside else -1
	var hot := inside and START.has_point(at)
	if hot != _start_hover:
		_start_hover = hot
	_buttons.queue_redraw()


func _refresh() -> void:
	var cpu_fighters := _cpu_fighters()
	var cpu_at := 0  # Computer players take the first empty slots.
	for i in SLOTS:
		var card = _cards[i]
		var slot: Dictionary = _slots[i]
		if not slot.is_empty():
			var device: String = slot["device"]
			card.show_card("player", "P%d" % (i + 1), slot["fighter"], slot["ready"],
					Devices.special_key(device) if device != "" else "", "")
		elif cpu_at < cpu_fighters.size():
			card.show_card("cpu", "CPU   %s" % CpuPlayer.LEVEL_NAMES[_cpu_level],
					cpu_fighters[cpu_at], false, "", "Computer player")
			cpu_at += 1
		else:
			card.show_card("empty", "", "", false, "", "")
	_rules.values = [str(_stocks), str(_cpus), CpuPlayer.LEVEL_NAMES[_cpu_level],
			"On" if _hazards else "Off"]
	_rules.row = _row
	_rules.active = _any_ready()
	if _humans() == 0:
		_hint.text = "Press attack to join, or click a panel.    Shield or B: back to the main menu"
	elif not _any_ready():
		_hint.text = "Up / down: fighter or controls    Left / right: change    Attack: ready" \
				+ "    Shield or B: back"
	elif not _can_start():
		_hint.text = "Ready players: up / down / left / right change the rules." \
				+ "    Two fighters needed, every player locked and ready"
	else:
		_hint.text = "Ready players: up / down / left / right change the rules." \
				+ "    Attack: on to the arena"


# "On to the arena": gold when the match can start, dim before.
func _draw_buttons() -> void:
	var ready_ := _can_start()
	var fill := Color("f0ac2a") if ready_ else Color("2c3247")
	if _start_hover and ready_:
		fill = fill.lightened(0.15)
	if ready_:
		UiDraw.glow(_buttons, START.get_center(), START.size * Vector2(0.7, 1.3),
				Color(UiDraw.GOLD, 0.25 if _start_hover else 0.14))
	UiDraw.chip(_buttons, START, "On to the arena", 26, fill,
			Color("1b1e2a") if ready_ else Color(UiDraw.DIM, 0.7),
			Color.WHITE if _start_hover else UiDraw.INK)


# The device as the Controls row shows it.
static func _device_name(device: String) -> String:
	match device:
		"":
			return ""
		"kb1":
			return "Keys left  WASD"
		"kb2":
			return "Keys right  Arrows"
	return Devices.label(device)


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


func _cycle(list: Array, value, step: int):
	var at := list.find(value)
	return list[posmod(at + step, list.size())]

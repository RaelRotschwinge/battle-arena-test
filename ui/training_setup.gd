# The training setup (game design, "Menus"): the player's fighter, the dummy's fighter and
# behavior and the arena, as rows of a menu page over the menu backdrop. Up and down move; left
# and right, attack or a click change a row; Start begins. The device used last plays (the Start
# row names it; the left keys at first), so the device that chooses Start is the one that plays.
# The shield key or B goes back to the main menu.
extends Control

const Devices := preload("res://scripts/view/devices.gd")
const Roster := preload("res://fighters/roster.gd")
const ArenaList := preload("res://arenas/arena_list.gd")
const Overlay := preload("res://ui/overlay.gd")
const MenuBackground := preload("res://ui/menu_background.gd")
const TrainingDummy := preload("res://scripts/view/training_dummy.gd")

const ROWS := 4  # The rows that change a value; Start and Back follow them.
const HINT := "Up / down: row      Left / right or attack: change      Shield or B: back"

var app
var setup := {}  # The last training setup, if any: {"players", "arena", "behavior"}.

var _you := ""
var _dummy := ""
var _behavior := 0
var _arena := "test"
var _device := "kb1"
var _menu


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(MenuBackground.new())
	var ids := Roster.ids()
	_you = ids[0]
	_dummy = ids[1 % ids.size()]
	var players: Array = setup.get("players", [])
	if players.size() == 2:
		_you = players[0]["fighter"]
		_dummy = players[1]["fighter"]
		if Devices.has_device(players[0]["device"]):
			_device = players[0]["device"]
	_behavior = setup.get("behavior", 0)
	_arena = setup.get("arena", "test")
	_menu = Overlay.new()
	_menu.look = "page"
	add_child(_menu)
	_menu.show_menu("Training", HINT, _options())
	Devices.swallow()


func _physics_process(_delta: float) -> void:
	for device in Devices.all():
		for action in Devices.MENU_ACTIONS:
			if Devices.pressed(device, action) and device != _device:
				_device = device
				_menu.menu.set_options(_options())
	var row: int = _menu.menu.selected
	var step := 0
	if Devices.any_pressed("left") != "":
		step = -1
	elif Devices.any_pressed("right") != "":
		step = 1
	if step != 0 and row < ROWS:
		_change(row, step)
		return
	var chosen: int = _menu.handle()
	if chosen >= 0 and chosen < ROWS:
		_change(chosen, 1)
	elif chosen == ROWS:
		_start()
	elif chosen == ROWS + 1 or chosen == -2:
		app.show_main_menu()


func _options() -> Array:
	return ["Your fighter:  %s" % Roster.display_name(_you),
			"Dummy:  %s" % Roster.display_name(_dummy),
			"Dummy does:  %s" % TrainingDummy.BEHAVIORS[_behavior],
			"Arena:  %s" % ("Training" if _arena == "test" else ArenaList.display_name(_arena)),
			"Start with %s" % Devices.label(_device), "Back"]


func _change(row: int, step: int) -> void:
	match row:
		0:
			_you = _cycle(Roster.ids(), _you, step)
		1:
			_dummy = _cycle(Roster.ids(), _dummy, step)
		2:
			_behavior = posmod(_behavior + step, TrainingDummy.BEHAVIORS.size())
		3:
			_arena = _cycle(ArenaList.ids(), _arena, step)
	_menu.menu.set_options(_options())


func _start() -> void:
	app.start_training({"players": [{"device": _device, "cpu": 0, "fighter": _you},
			{"device": "", "cpu": 0, "fighter": _dummy}], "arena": _arena, "behavior": _behavior})


func _cycle(list: Array, value, step: int):
	return list[posmod(list.find(value) + step, list.size())]

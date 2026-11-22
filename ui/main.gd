# The game's main node (game design, "Menus"): the main menu, the controls overview, the fighter
# select, the arena select and the match, one at a time. It reads the devices once per tick for
# all of them and keeps the last match setup, so a rematch or a new pick starts from it.
extends Node

const Devices := preload("res://scripts/view/devices.gd")
const MatchView := preload("res://scripts/view/match_view.gd")
const SelectScreen := preload("res://ui/select_screen.gd")
const ArenaSelect := preload("res://ui/arena_select.gd")
const Overlay := preload("res://ui/overlay.gd")

const CONTROLS := """Keys left:  A D move,  W jump,  S down,  Space attack,  E special,  left Shift or Ctrl shield
Keys right:  arrows move and jump,  Enter attack,  Backspace special,  right Shift or Ctrl shield
Gamepad:  stick or D-pad move,  A or Y jump,  X attack,  B special,  shoulder buttons shield,  Start pause

The direction held picks the attack: none, side, up or down, on the ground and in the air.
Special: each fighter has its own (see the fighter select); the direction aims or steers it.
Shield: hold it.  In the shield: left or right rolls, down dodges, attack grabs, up jumps.
In the air the shield key dodges, also with a direction.
Launched: hold a direction to bend your flight, press shield just before you hit the ground.
Double tap a direction to run.  Esc or Start pauses the match."""

var _screen: Node
var _menu
var _setup := {}
var _menu_kind := "main"


func _ready() -> void:
	process_physics_priority = -10  # Reads the devices before the screens use them.
	add_child(Devices.new())
	_menu = Overlay.new()
	add_child(_menu)
	show_main_menu()


func _physics_process(_delta: float) -> void:
	Devices.poll()
	if not _menu.visible:
		return
	var chosen: int = _menu.handle()
	if _menu_kind == "controls":
		if chosen != -1:
			show_main_menu()
		return
	match chosen:
		0:
			show_select()
		1:
			_menu_kind = "controls"
			_menu.show_menu("Controls", CONTROLS, ["Back"])
		2:
			get_tree().quit()


func show_main_menu() -> void:
	_clear()
	_menu_kind = "main"
	_menu.show_menu("Battle Arena", "2 to 4 players: keyboard and gamepads", ["Play", "Controls",
			"Quit"], "", Color("ffd24a"))
	Devices.swallow()


func show_select() -> void:
	_clear()
	var select := SelectScreen.new()
	select.app = self
	select.setup = _setup
	_screen = select
	add_child(select)


# After the fighter select: the players and rules are set, the arena comes next.
func show_arena_select(setup: Dictionary) -> void:
	_setup = setup
	_clear()
	var select := ArenaSelect.new()
	select.app = self
	select.setup = setup
	_screen = select
	add_child(select)


func start_match(setup: Dictionary) -> void:
	_setup = setup
	_clear()
	var view := MatchView.new()
	view.app = self
	view.setup = setup
	_screen = view
	add_child(view)


# Called by the match when the players leave it: "select" or "menu".
func leave_match(where: String) -> void:
	if where == "select":
		show_select()
	else:
		show_main_menu()


func _clear() -> void:
	_menu.visible = false
	if _screen != null:
		_screen.queue_free()
		_screen = null

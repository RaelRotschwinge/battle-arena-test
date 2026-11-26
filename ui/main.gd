# The game's main node (game design, "Menus"): the main menu, the controls overview, the options,
# the fighter select, the arena select, the training setup and the match (or the training), one
# at a time. It reads the devices once per tick for all of them and keeps the last match setup, so
# a rematch or a new pick starts from it, and the last training setup apart from it. A wipe
# covers every change of screen; the old screen stops at once, and the new one takes input only
# a few ticks after it appears, with every key still held swallowed, so no press acts twice and
# a held or repeated key cannot skip a screen.
extends Node

const Devices := preload("res://scripts/view/devices.gd")
const MatchView := preload("res://scripts/view/match_view.gd")
const TrainingView := preload("res://scripts/view/training_view.gd")
const TrainingSetup := preload("res://ui/training_setup.gd")
const SelectScreen := preload("res://ui/select_screen.gd")
const ArenaSelect := preload("res://ui/arena_select.gd")
const Overlay := preload("res://ui/overlay.gd")
const MenuBackground := preload("res://ui/menu_background.gd")
const ControlsPage := preload("res://ui/controls_page.gd")
const OptionsPage := preload("res://ui/options_page.gd")
const Transition := preload("res://ui/transition.gd")
const Sounds := preload("res://scripts/view/sounds.gd")

const HOLD_TICKS := 2  # A new screen ignores input this long, then swallows held keys.

var _screen: Node
var _menu
var _backdrop
var _options  # The options page while it is shown.
var _wipe
var _sounds  # All effects and the music, for every screen (Sounds.main()).
var _setup := {}
var _training := {}  # The last training setup, kept apart from the match setup.
var _menu_kind := "main"
var _hold := 0  # Ticks left before the new screen takes input.


func _ready() -> void:
	process_physics_priority = -10  # Reads the devices before the screens use them.
	add_child(Devices.new())
	_sounds = Sounds.new()
	add_child(_sounds)
	_backdrop = MenuBackground.new()
	_backdrop.heroes = true
	_backdrop.hint = "2 to 4 players:  keyboard and gamepads"
	add_child(_backdrop)
	_menu = Overlay.new()
	add_child(_menu)
	_wipe = Transition.new()
	add_child(_wipe)
	_show_main_menu()
	_wipe.reveal()


func _physics_process(_delta: float) -> void:
	Devices.poll()
	if _hold > 0:
		_hold -= 1
		if _hold == 0:
			Devices.swallow()  # Keys held through the change count as already pressed.
			if _screen != null:
				_screen.set_physics_process(true)
		return
	if not _menu.visible or _wipe.covering:
		return
	if _menu_kind == "options":  # The page has its own cursor; the overlay's list is empty.
		if _options.handle():
			show_main_menu()
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
			_go(_show_training_setup)
		2:
			_go(_show_controls)
		3:
			_go(_show_options)
		4:
			get_tree().quit()


func show_main_menu() -> void:
	_go(_show_main_menu)


func show_select() -> void:
	_go(_show_select)


# After the fighter select: the players and rules are set, the arena comes next.
func show_arena_select(setup: Dictionary) -> void:
	_setup = setup
	_go(_show_arena_select.bind(setup))


func start_match(setup: Dictionary) -> void:
	_setup = setup
	_go(_start_match.bind(setup))


func start_training(setup: Dictionary) -> void:
	_training = setup
	_go(_start_match.bind(setup))


# Called by the match when the players leave it: "select" or "menu".
func leave_match(where: String) -> void:
	if where == "select":
		show_select()
	else:
		show_main_menu()


# Stops the current screen and changes to the next one under the wipe.
func _go(then: Callable) -> void:
	_menu.menu._clicked = -1  # A click during the wipe must not act on the next screen.
	if _screen != null:
		_screen.process_mode = Node.PROCESS_MODE_DISABLED
	_wipe.go(then)


func _show_main_menu() -> void:
	_clear()
	_menu_kind = "main"
	_backdrop.visible = true
	_backdrop.process_mode = Node.PROCESS_MODE_INHERIT
	_menu.look = "logo"
	_menu.show_menu("Battle Arena", "", ["Play", "Training", "Controls", "Options", "Quit"], "",
			Color("ffd24a"))
	Devices.swallow()
	_hold_input()


func _show_controls() -> void:
	_clear()
	_menu_kind = "controls"
	_backdrop.visible = true
	_backdrop.process_mode = Node.PROCESS_MODE_INHERIT
	_menu.look = "page"
	_menu.show_menu("Controls", "", ["Back"], "", Color.WHITE, ControlsPage.new())
	Devices.swallow()
	_hold_input()


func _show_options() -> void:
	_clear()
	_menu_kind = "options"
	_backdrop.visible = true
	_backdrop.process_mode = Node.PROCESS_MODE_INHERIT
	_menu.look = "page"
	_options = OptionsPage.new()
	_menu.show_menu("Options", "", [], "", Color.WHITE, _options)
	Devices.swallow()
	_hold_input()


func _show_select() -> void:
	_clear()
	var select := SelectScreen.new()
	select.app = self
	select.setup = _setup
	_screen = select
	add_child(select)
	_hold_input()


func _show_training_setup() -> void:
	_clear()
	var screen := TrainingSetup.new()
	screen.app = self
	screen.setup = _training
	_screen = screen
	add_child(screen)
	_hold_input()


func _show_arena_select(setup: Dictionary) -> void:
	_clear()
	var select := ArenaSelect.new()
	select.app = self
	select.setup = setup
	_screen = select
	add_child(select)
	_hold_input()


func _start_match(setup: Dictionary) -> void:
	_clear()
	var view = TrainingView.new() if setup.has("behavior") else MatchView.new()
	view.app = self
	view.setup = setup
	_screen = view
	add_child(view)
	_hold_input()


# A new screen waits before it takes input (it still draws and animates).
func _hold_input() -> void:
	_hold = HOLD_TICKS
	if _screen != null:
		_screen.set_physics_process(false)


func _clear() -> void:
	_sounds.music("menu")  # A match asks for its own music right after.
	_menu.visible = false
	_backdrop.visible = false
	_backdrop.process_mode = Node.PROCESS_MODE_DISABLED  # Its fighters stop breathing unseen.
	if _screen != null:
		_screen.queue_free()
		_screen = null

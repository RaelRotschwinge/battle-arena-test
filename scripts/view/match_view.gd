# The match scene: runs the simulation at 60 ticks per second with the two keyboard players and
# draws it. F1 info overlay, F2 tuning panel, F5 restart.
extends Node2D

const MatchSim := preload("res://scripts/sim/match_sim.gd")
const FighterStats := preload("res://scripts/sim/fighter_stats.gd")
const TestArena := preload("res://arenas/test_arena.gd")
const LocalInput := preload("res://scripts/view/local_input.gd")
const ArenaView := preload("res://scripts/view/arena_view.gd")
const FighterView := preload("res://scripts/view/fighter_view.gd")
const MatchCamera := preload("res://scripts/view/match_camera.gd")
const DebugUi := preload("res://scripts/view/debug_ui.gd")
const TuningStore := preload("res://scripts/view/tuning_store.gd")

const PLAYERS := 2
const PLAYER_COLORS := [Color("e8553e"), Color("3e8fe8")]

var sim
var stats
var _arena_view
var _camera
var _ui
var _fighter_views := []


func _ready() -> void:
	stats = FighterStats.new()
	TuningStore.load_into(stats)
	_arena_view = ArenaView.new()
	add_child(_arena_view)
	_camera = MatchCamera.new()
	add_child(_camera)
	_ui = DebugUi.new()
	_ui.stats = stats
	add_child(_ui)
	_start()


func _physics_process(_delta: float) -> void:
	var inputs := []
	for i in PLAYERS:
		inputs.append(LocalInput.read(i))
	sim.step(inputs)
	for view in _fighter_views:
		view.sync()
	_camera.follow()


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_F1:
			_arena_view.show_blast_zone = _ui.toggle_info()
		KEY_F2:
			_ui.toggle_tuning()
		KEY_F5:
			_start()


func _start() -> void:
	sim = MatchSim.new(TestArena.new(), PLAYERS, stats)
	_arena_view.arena = sim.arena
	_arena_view.queue_redraw()
	for view in _fighter_views:
		view.queue_free()
	_fighter_views.clear()
	for i in PLAYERS:
		var view := FighterView.new()
		view.fighter = sim.fighters[i]
		view.stats = stats
		view.color = PLAYER_COLORS[i]
		view.label = "P%d" % (i + 1)
		add_child(view)
		view.sync()
		view.reset_physics_interpolation()
		_fighter_views.append(view)
	_camera.sim = sim
	_camera.stats = stats
	_camera.snap()
	_ui.sim = sim

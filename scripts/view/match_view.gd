# The match scene: runs the simulation at 60 ticks per second with the two keyboard players and
# draws it. F1 info overlay with hitboxes, F2 tuning panel, F5 restart. After the win screen an
# attack key starts a new match.
extends Node2D

const MatchSim := preload("res://scripts/sim/match_sim.gd")
const FighterStats := preload("res://scripts/sim/fighter_stats.gd")
const TestArena := preload("res://arenas/test_arena.gd")
const LocalInput := preload("res://scripts/view/local_input.gd")
const ArenaView := preload("res://scripts/view/arena_view.gd")
const FighterView := preload("res://scripts/view/fighter_view.gd")
const HitEffects := preload("res://scripts/view/hit_effects.gd")
const MatchCamera := preload("res://scripts/view/match_camera.gd")
const Hud := preload("res://scripts/view/hud.gd")
const DebugUi := preload("res://scripts/view/debug_ui.gd")
const TuningStore := preload("res://scripts/view/tuning_store.gd")

const PLAYERS := 2
const PLAYER_COLORS := [Color("e8553e"), Color("3e8fe8")]
const RESTART_DELAY_TICKS := 60  # The win screen ignores attack keys this long.
const SHAKE_SPEED := 18.0  # Hits launching at least this fast shake the camera.

var sim
var stats
var _arena_view
var _effects
var _camera
var _hud
var _ui
var _fighter_views := []
var _show_boxes := false
var _over_ticks := 0
var _attack_held := []


func _ready() -> void:
	stats = FighterStats.new()
	TuningStore.load_into(stats)
	_arena_view = ArenaView.new()
	add_child(_arena_view)
	_effects = HitEffects.new()
	_effects.z_index = 1
	add_child(_effects)
	_camera = MatchCamera.new()
	add_child(_camera)
	_hud = Hud.new()
	_hud.colors = PLAYER_COLORS
	add_child(_hud)
	_ui = DebugUi.new()
	_ui.stats = stats
	add_child(_ui)
	_start()


func _physics_process(_delta: float) -> void:
	var inputs := []
	for i in PLAYERS:
		inputs.append(LocalInput.read(i))
	if sim.over:
		_after_match(inputs)
		return
	sim.step(inputs)
	for event in sim.events:
		if event["type"] == "hit":
			_effects.add_hit(event["position"], event["speed"])
			if event["speed"] >= SHAKE_SPEED:
				_camera.shake(minf(event["speed"] * 0.4, 16.0))
		elif event["type"] == "ko":
			_effects.add_ko(event["position"], PLAYER_COLORS[event["fighter"]])
			_camera.shake(14.0)
	for view in _fighter_views:
		view.sync()
	_camera.follow()
	_hud.refresh()
	if sim.over:
		_over_ticks = 0
		_hud.show_winner(false)


# The win screen: after a short wait, a new press of any attack key starts a new match.
func _after_match(inputs: Array) -> void:
	_camera.follow()
	_over_ticks += 1
	var can_restart := _over_ticks >= RESTART_DELAY_TICKS
	if _over_ticks == RESTART_DELAY_TICKS:
		_hud.show_winner(true)
	for i in inputs.size():
		var pressed: bool = inputs[i].attack and not _attack_held[i]
		_attack_held[i] = inputs[i].attack
		if can_restart and pressed:
			_start()
			return


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_F1:
			_show_boxes = _ui.toggle_info()
			_arena_view.show_blast_zone = _show_boxes
			for view in _fighter_views:
				view.show_boxes = _show_boxes
		KEY_F2:
			_ui.toggle_tuning()
		KEY_F5:
			_start()


func _start() -> void:
	sim = MatchSim.new(TestArena.new(), PLAYERS, stats)
	_arena_view.arena = sim.arena
	_arena_view.queue_redraw()
	_effects.clear()
	for view in _fighter_views:
		view.queue_free()
	_fighter_views.clear()
	for i in PLAYERS:
		var view := FighterView.new()
		view.fighter = sim.fighters[i]
		view.stats = stats
		view.color = PLAYER_COLORS[i]
		view.label = "P%d" % (i + 1)
		view.show_boxes = _show_boxes
		add_child(view)
		view.sync()
		view.reset_physics_interpolation()
		_fighter_views.append(view)
	_attack_held = []
	for i in PLAYERS:
		_attack_held.append(true)  # A key still held from the last match is no new press.
	_camera.sim = sim
	_camera.stats = stats
	_camera.snap()
	_hud.sim = sim
	_hud.reset()
	_ui.sim = sim

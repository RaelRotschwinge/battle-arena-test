# The training match: the player (fighter 0) against a dummy (fighter 1) that follows the
# behavior of the training setup (training_dummy.gd). Lives are refilled after every tick, so no
# one is ever out and no results screen comes; a knocked out fighter comes back as in a match. R
# or F5, and "Reset" in the pause menu, put both back on their start places at 0 % (the start
# snapshot of the match). The training panel counts the combos on the dummy. The pause menu also
# changes the dummy's behavior and leaves the training. The simulation is the match's own: the
# view only refills lives between ticks and restores the snapshot.
extends "res://scripts/view/match_view.gd"

const TrainingDummy := preload("res://scripts/view/training_dummy.gd")
const TrainingHud := preload("res://scripts/view/training_hud.gd")

const DUMMY := 1  # The dummy's fighter index; the player is fighter 0.
const LIVES := 99  # Refilled after every tick.
const BEHAVIOR_ROW := 2  # The pause menu's row of the dummy's behavior.

var _panel
var _start_snap := {}
var _counted_tick := -1  # The tick the panel counted last: a paused tick counts nothing.
var _damage_before := 0.0  # The dummy's damage after the tick counted last.
var _combo_start := 0.0  # The dummy's damage before the current combo.


func _ready() -> void:
	_panel = TrainingHud.new()  # Before the match view's _ready(), which calls _start().
	add_child(_panel)
	super()


func _physics_process(delta: float) -> void:
	super(delta)
	if sim.tick == _counted_tick:
		return
	_counted_tick = sim.tick
	for f in sim.fighters:
		f.stocks = LIVES
	_count_combo()


func _start() -> void:
	setup["stocks"] = LIVES
	super()
	_hud.labels[DUMMY] = "Dummy"
	_fighter_views[DUMMY].label = "Dummy"
	_hud.reset()  # Again, for the dummy's name on its card.
	_ui.set_players(setup["players"], "R or F5 reset")
	_start_snap = sim.snapshot()
	_new_dummy()
	_panel.dummy = sim.fighters[DUMMY]
	_clear_combo()


# Both fighters back to the start of the match, the dummy's behavior starting again.
func _reset() -> void:
	sim.restore(_start_snap)
	sim.events.clear()  # The last tick's events are not this state's.
	_new_dummy()
	_clear_combo()
	_effects.clear()
	_back_effects.clear()
	_shot_view.reset()
	for view in _fighter_views:
		view.sync()
		view.reset_physics_interpolation()
	_arena_view.sync()
	_camera.snap()
	_hud.refresh()


func _new_dummy() -> void:
	_cpus[DUMMY] = TrainingDummy.new(_behavior(), DUMMY, _seed * 31 + DUMMY)
	_panel.behavior = TrainingDummy.BEHAVIORS[_behavior()]


func _behavior() -> int:
	return setup.get("behavior", 0)


func _clear_combo() -> void:
	_counted_tick = sim.tick
	_damage_before = sim.fighters[DUMMY].damage
	_combo_start = _damage_before
	_panel.combo = 0
	_panel.combo_damage = 0.0
	_panel.live = false


# A combo: hits on the dummy while it never got free between them, as the simulation counts them
# (combo_hits, the count its combo guard uses).
func _count_combo() -> void:
	var d = sim.fighters[DUMMY]
	var hits := 0
	for event in sim.events:
		if event["type"] == "hit" and event["target"] == DUMMY:
			hits += 1
	if hits > 0 and d.combo_hits > 0:  # 0: knocked out in the same tick, back at 0 %.
		if d.combo_hits <= hits:  # The combo began this tick.
			_combo_start = _damage_before
		_panel.combo = d.combo_hits
		_panel.combo_damage = d.damage - _combo_start
		_panel.grew()
	_panel.live = d.combo_hits > 0 and (d.mode == FighterState.Mode.HITSTUN or d.launch_pending)
	_damage_before = d.damage


func _open_pause(device: String) -> void:
	_slow_motion(false)
	_paused_by = device
	_pause.show_menu("Training", "Left / right on Dummy: its behavior", _pause_options(), device)
	Devices.swallow()


func _pause_options() -> Array:
	return ["Resume", "Reset", "Dummy:  %s" % TrainingDummy.BEHAVIORS[_behavior()],
			"Leave training"]


func _pause_menu() -> void:
	if Devices.pressed(_paused_by, "start"):
		_pause.visible = false
		return
	var left := Devices.pressed(_paused_by, "left")
	if _pause.menu.selected == BEHAVIOR_ROW and (left or Devices.pressed(_paused_by, "right")):
		_change_behavior(-1 if left else 1)
		return
	match _pause.handle():
		0, -2:
			_pause.visible = false
		1:
			_pause.visible = false
			_reset()
		BEHAVIOR_ROW:
			_change_behavior(1)
		3:
			_leave("menu")


func _change_behavior(step: int) -> void:
	setup["behavior"] = posmod(_behavior() + step, TrainingDummy.BEHAVIORS.size())
	_new_dummy()
	_pause.menu.set_options(_pause_options())


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo \
			and (key.physical_keycode == KEY_R or key.keycode == KEY_F5):
		if not _pause.visible:
			_reset()
		return
	super(event)

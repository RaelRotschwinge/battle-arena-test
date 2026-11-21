# The match scene: runs the simulation at 60 ticks per second with the players of the match setup
# and draws it. Esc or Start pauses; the results screen follows the end of the match. F1 info
# overlay with hitboxes, F2 tuning panel, F5 restart. Run alone, it starts a match of the two
# keyboard players on the test arena.
extends Node2D

const MatchSim := preload("res://scripts/sim/match_sim.gd")
const CpuPlayer := preload("res://scripts/sim/cpu_player.gd")
const FighterInput := preload("res://scripts/sim/fighter_input.gd")
const Roster := preload("res://fighters/roster.gd")
const ArenaList := preload("res://arenas/arena_list.gd")
const Devices := preload("res://scripts/view/devices.gd")
const ArenaView := preload("res://scripts/view/arena_view.gd")
const FighterView := preload("res://scripts/view/fighter_view.gd")
const HitEffects := preload("res://scripts/view/hit_effects.gd")
const MatchCamera := preload("res://scripts/view/match_camera.gd")
const Hud := preload("res://scripts/view/hud.gd")
const DebugUi := preload("res://scripts/view/debug_ui.gd")
const TuningStore := preload("res://scripts/view/tuning_store.gd")
const Sounds := preload("res://scripts/view/sounds.gd")
const Overlay := preload("res://ui/overlay.gd")

const PLAYER_COLORS := [Color("e8553e"), Color("3e8fe8"), Color("e8c33e"), Color("4ec96a")]
const RESULTS_DELAY_TICKS := 90  # The winner shows this long before the results screen.
const SHAKE_SPEED := 18.0  # Hits launching at least this fast shake the camera.
const DEFAULT_SETUP := {"players": [{"device": "kb1", "cpu": 0, "fighter": "kade"},
		{"device": "kb2", "cpu": 0, "fighter": "pip"}], "arena": "test", "stocks": 3}

# players: one per fighter {"device": "kb1" (none for a computer), "cpu": 0 for a player or the
# level 1 to 3, "fighter": a roster id}; arena: an arena id; stocks: lives. Set before the node
# enters the tree.
var setup := {}
var app  # The main node, told when the players leave the match; null when run alone.
var sim
var _arena_view
var _effects
var _camera
var _hud
var _ui
var _sounds
var _pause
var _results
var _fighter_views := []
var _cpus := []  # Per fighter: a computer player or null.
var _show_boxes := false
var _over_ticks := 0
var _paused_by := ""
var _seed := 1


func _ready() -> void:
	if setup.is_empty():
		setup = DEFAULT_SETUP.duplicate(true)
	if app == null:
		add_child(Devices.new())
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
	add_child(_ui)
	_sounds = Sounds.new()
	add_child(_sounds)
	_pause = Overlay.new()
	add_child(_pause)
	_results = Overlay.new()
	add_child(_results)
	_start()


func _physics_process(_delta: float) -> void:
	if app == null:
		Devices.poll()
	if _pause.visible:
		_pause_menu()
		return
	if _results.visible:
		_results_menu()
		return
	for device in _human_devices():
		if Devices.pressed(device, "start"):
			_open_pause(device)
			return
	var inputs := []
	for i in sim.fighters.size():
		inputs.append(_cpus[i].next_input(sim) if _cpus[i] != null else _read(i))
	if sim.over:
		_after_match()
		return
	sim.step(inputs)
	for event in sim.events:
		_show_event(event)
	for view in _fighter_views:
		view.sync()
	_arena_view.sync()
	_camera.follow()
	_hud.refresh()
	if sim.over:
		_over_ticks = 0
		_hud.show_winner(false)
		_sounds.play("win")


func _read(i: int) -> FighterInput:
	var device: String = setup["players"][i].get("device", "")
	return Devices.read(device) if device != "" else FighterInput.new()


func _human_devices() -> Array:
	var devices := []
	for player in setup["players"]:
		if player.get("cpu", 0) == 0 and player.get("device", "") != "":
			devices.append(player["device"])
	return devices


func _show_event(event: Dictionary) -> void:
	match event["type"]:
		"hit":
			_effects.add_hit(event["position"], event["speed"])
			_sounds.play("hit", event["speed"])
			if event["speed"] >= SHAKE_SPEED:
				_camera.shake(minf(event["speed"] * 0.4, 16.0))
				_effects.add_trail(sim.fighters[event["target"]], PLAYER_COLORS[event["target"]])
		"block":
			_effects.add_block(event["position"], PLAYER_COLORS[event["target"]])
			_sounds.play("block")
		"parry":
			_effects.add_parry(event["position"])
			_sounds.play("parry")
		"break":
			_effects.add_ko(event["position"], Color("ffe066"))
			_sounds.play("break")
			_camera.shake(10.0)
		"grab":
			_sounds.play("grab")
		"armor":
			_effects.add_block(event["position"], Color("e0b84a"))
			_sounds.play("block")
		"ko":
			_effects.add_ko(event["position"], PLAYER_COLORS[event["fighter"]])
			_sounds.play("ko")
			_camera.shake(14.0)


# The winner shows for a moment, then the results screen.
func _after_match() -> void:
	_camera.follow()
	for view in _fighter_views:
		view.sync()
	_over_ticks += 1
	if _over_ticks >= RESULTS_DELAY_TICKS:
		_hud.hide_winner()
		_results.show_menu(_winner_text(), _stats_text(), ["Rematch", "Change fighters",
				"Main menu"], "", PLAYER_COLORS[sim.winner] if sim.winner >= 0 else Color.WHITE)
		Devices.swallow()


func _winner_text() -> String:
	return "%s wins!" % _hud.labels[sim.winner] if sim.winner >= 0 else "Draw!"


func _stats_text() -> String:
	var lines := PackedStringArray()
	for i in sim.fighters.size():
		var f = sim.fighters[i]
		lines.append("%s  %s     KOs %d   falls %d   self-KOs %d   damage dealt %d %%" % [
				_hud.labels[i], f.stats.fighter_name, f.kos, f.falls, f.self_destructs,
				int(f.damage_dealt)])
	return "\n".join(lines)


func _results_menu() -> void:
	match _results.handle():
		0:
			_results.visible = false
			_start()
		1:
			_leave("select")
		2, -2:
			_leave("menu")


func _open_pause(device: String) -> void:
	_paused_by = device
	var who := ""
	for i in setup["players"].size():
		if setup["players"][i].get("device", "") == device:
			who = _hud.labels[i]
	_pause.show_menu("Paused", "%s has the menu" % who, ["Resume", "Restart", "Change fighters",
			"Main menu"], device)
	Devices.swallow()


func _pause_menu() -> void:
	if Devices.pressed(_paused_by, "start"):
		_pause.visible = false
		return
	match _pause.handle():
		0, -2:
			_pause.visible = false
		1:
			_pause.visible = false
			_start()
		2:
			_leave("select")
		3:
			_leave("menu")


func _leave(where: String) -> void:
	if app != null:
		app.call_deferred("leave_match", where)
	else:
		_pause.visible = false
		_results.visible = false
		_start()


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
	var players: Array = setup["players"]
	var all_stats := []
	var kinds := {}  # Fighters of the same kind share their stats, so tuning changes them all.
	for player in players:
		var id: String = player.get("fighter", "test")
		if not kinds.has(id):
			kinds[id] = Roster.make(id)
			TuningStore.load_into(kinds[id], id)
		all_stats.append(kinds[id])
	sim = MatchSim.new(ArenaList.make(setup.get("arena", "test")), players.size(), all_stats,
			setup.get("stocks", MatchSim.DEFAULT_STOCKS))
	_seed += 1
	_cpus.clear()
	var labels := []
	var cpu_count := 0
	for i in players.size():
		var level: int = players[i].get("cpu", 0)
		_cpus.append(CpuPlayer.new(level, i, _seed * 31 + i) if level > 0 else null)
		if level > 0:
			cpu_count += 1
		labels.append("CPU %d" % cpu_count if level > 0 else "P%d" % (i + 1))
	_arena_view.arena = sim.arena
	_arena_view.queue_redraw()
	_effects.clear()
	for view in _fighter_views:
		view.queue_free()
	_fighter_views.clear()
	for i in players.size():
		var view := FighterView.new()
		view.fighter = sim.fighters[i]
		view.color = PLAYER_COLORS[i]
		view.label = labels[i]
		view.effects = _effects
		view.show_boxes = _show_boxes
		add_child(view)
		view.sync()
		view.reset_physics_interpolation()
		_fighter_views.append(view)
	_camera.sim = sim
	_camera.snap()
	_hud.sim = sim
	_hud.labels = labels
	_hud.reset()
	_ui.sim = sim
	_ui.stats = all_stats[0]
	_ui.fighter_id = players[0].get("fighter", "test")
	_over_ticks = 0
	Devices.swallow()

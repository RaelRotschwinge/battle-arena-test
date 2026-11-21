# Movement of the simulation (game design, "Movement") on the test arena.
extends "res://tests/sim_test.gd"


func test_stands_still_on_the_ground() -> void:
	var start: Vector2 = fighter().position
	hold([], 60)
	assert_eq(fighter().mode, Mode.GROUND, "mode")
	assert_eq(fighter().position, start, "position")


func test_walks_at_walk_speed() -> void:
	hold(["right"], 30)
	assert_eq(fighter().velocity.x, sim.stats.walk_speed, "speed")
	assert_true(not fighter().running, "walking, not running")
	assert_eq(fighter().facing, 1, "faces right")


func test_double_tap_runs() -> void:
	hold(["right"], 3)
	hold([], 3)
	hold(["right"], 30)
	assert_true(fighter().running, "running")
	assert_eq(fighter().velocity.x, sim.stats.run_speed, "speed")


func test_jump_leaves_the_ground_after_the_take_off() -> void:
	fighter().position.x = 960.0
	hold(["up"], 3)
	assert_eq(fighter().mode, Mode.JUMP_SQUAT, "still in the take-off")
	assert_eq(fighter().position.y, 800.0, "still on the ground")
	hold(["up"])
	assert_eq(fighter().mode, Mode.AIR, "in the air on the fourth tick")
	assert_true(fighter().position.y < 800.0, "rising")


func test_holding_jump_goes_higher_than_a_tap() -> void:
	var tap := _peak_after_holding_up(2)
	var full := _peak_after_holding_up(40)
	assert_true(tap < 800.0, "a tap still jumps")
	assert_true(full < tap - 50.0, "full jump top %.0f well above the tap's top %.0f" % [full, tap])


func test_double_jump_works_once_until_landing() -> void:
	fighter().position.x = 960.0
	hold(["up"], 4)
	hold([], 6)
	assert_eq(fighter().mode, Mode.AIR, "in the air")
	assert_eq(fighter().jumps_left, 1, "double jump ready")
	hold(["up"])
	assert_eq(fighter().jumps_left, 0, "double jump used")
	hold([], 2)
	var speed: float = fighter().velocity.y
	hold(["up"])
	assert_true(fighter().velocity.y > speed, "no third jump")
	hold([], 180)
	assert_eq(fighter().mode, Mode.GROUND, "landed")
	assert_eq(fighter().jumps_left, 1, "double jump ready again")


func test_double_jump_while_rising_adds_its_full_height() -> void:
	var dj_height: float = sim.stats.double_jump_speed * sim.stats.double_jump_speed \
			/ (2.0 * sim.stats.gravity)
	var without := _peak_from_rising(false)
	var with := _peak_from_rising(true)
	assert_true(absf(without - with - dj_height) < 20.0,
			"%.0f higher, expected about %.0f" % [without - with, dj_height])


func test_tap_and_quick_double_jump_is_no_higher_than_tap_and_late_double_jump() -> void:
	var quick := _peak_tap_then_double_jump(4)
	var late := _peak_tap_then_double_jump(12)
	assert_true(absf(quick - late) < 20.0, "tops %.0f and %.0f" % [quick, late])


func test_double_jump_while_falling_starts_at_full_speed() -> void:
	fighter().position = Vector2(960.0, 500.0)
	fighter().mode = Mode.AIR
	fighter().velocity.y = 5.0
	hold(["up"])
	assert_true(is_equal_approx(fighter().velocity.y, -sim.stats.double_jump_speed + sim.stats.gravity),
			"speed %.2f" % fighter().velocity.y)


func test_down_at_the_top_of_a_jump_falls_fast() -> void:
	fighter().position.x = 960.0
	hold(["up"], 40)
	assert_true(fighter().velocity.y > 0.0, "falling")
	hold(["down"])
	assert_true(fighter().fast_falling, "fast fall")
	assert_eq(fighter().velocity.y, sim.stats.fast_fall_speed, "fall speed")


func test_down_on_a_thin_platform_drops_through() -> void:
	fighter().position = Vector2(710.0, 620.0)
	hold([], 2)
	assert_eq(fighter().mode, Mode.GROUND, "stands on the thin platform")
	assert_eq(fighter().position.y, 620.0, "on its top")
	hold(["down"])
	hold([], 90)
	assert_eq(fighter().mode, Mode.GROUND, "landed again")
	assert_eq(fighter().position.y, 800.0, "on the main platform")


func test_jumps_up_through_a_thin_platform_and_lands_on_it() -> void:
	fighter().position.x = 710.0
	hold(["up"], 60)
	assert_eq(fighter().mode, Mode.GROUND, "landed")
	assert_eq(fighter().position.y, 620.0, "on the thin platform")


func test_walking_off_the_edge_falls_with_the_double_jump_ready() -> void:
	fighter().position.x = 1500.0
	hold(["right"], 30)
	assert_eq(fighter().mode, Mode.AIR, "in the air")
	assert_eq(fighter().jumps_left, 1, "double jump ready")


func test_leaving_the_blast_zone_respawns_above_the_arena() -> void:
	fighter().position = Vector2(1800.0, 800.0)
	fighter().mode = Mode.AIR
	hold([], 240)
	assert_eq(fighter().respawns, 1, "respawned once")
	assert_eq(fighter().mode, Mode.GROUND, "landed after the respawn")
	assert_eq(fighter().position, Vector2(960.0, 800.0), "in the middle of the main platform")


func test_same_inputs_give_the_same_match() -> void:
	var a := MatchSim.new(TestArena.new(), 2)
	var b := MatchSim.new(TestArena.new(), 2)
	for t in 300:
		a.step([_pattern(t), _pattern(t + 7)])
		b.step([_pattern(t), _pattern(t + 7)])
	assert_eq(a.snapshot(), b.snapshot(), "snapshots")


func test_restore_replays_the_same_ticks() -> void:
	var s := MatchSim.new(TestArena.new(), 2)
	for t in 100:
		s.step([_pattern(t), _pattern(t + 7)])
	var saved := s.snapshot()
	for t in range(100, 200):
		s.step([_pattern(t), _pattern(t + 7)])
	var first := s.snapshot()
	s.restore(saved)
	for t in range(100, 200):
		s.step([_pattern(t), _pattern(t + 7)])
	assert_eq(s.snapshot(), first, "snapshots")


func _peak_after_holding_up(ticks: int) -> float:
	var s := MatchSim.new(TestArena.new(), 1)
	s.fighters[0].position.x = 960.0
	var peak: float = s.fighters[0].position.y
	for t in 60:
		var input := FighterInput.new()
		input.up = t < ticks
		s.step([input])
		peak = minf(peak, s.fighters[0].position.y)
	return peak


# Top of a fighter that rises from y 500 at speed 10, with or without a double jump at once.
func _peak_from_rising(double_jump: bool) -> float:
	var s := MatchSim.new(TestArena.new(), 1)
	var f = s.fighters[0]
	f.position = Vector2(960.0, 500.0)
	f.mode = Mode.AIR
	f.velocity.y = -10.0
	var peak: float = f.position.y
	for t in 60:
		var input := FighterInput.new()
		input.up = double_jump and t == 0
		s.step([input])
		peak = minf(peak, f.position.y)
	return peak


# Top of a 2-tick tap on up, followed by the double jump press at tick `press_tick`.
func _peak_tap_then_double_jump(press_tick: int) -> float:
	var s := MatchSim.new(TestArena.new(), 1)
	var f = s.fighters[0]
	f.position.x = 960.0
	var peak: float = f.position.y
	for t in 90:
		var input := FighterInput.new()
		input.up = t < 2 or t == press_tick
		s.step([input])
		peak = minf(peak, f.position.y)
	return peak


# A fixed input sequence that runs, turns, jumps and drops.
func _pattern(t: int) -> FighterInput:
	var input := FighterInput.new()
	input.right = t % 50 < 25
	input.left = t % 50 >= 30
	input.up = t % 37 < 3
	input.down = t % 23 == 0
	return input

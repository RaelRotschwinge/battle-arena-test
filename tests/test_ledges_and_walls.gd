# Ledge grab and wall jump (game design, "Movement"), at the left end of the test arena's main
# platform: ledge corner at x 360, y 800; the wall below it reaches down to y 1100.
extends "res://tests/sim_test.gd"


# Lets the fighter fall past the left ledge so that it grabs it.
func hang_on_left_ledge() -> void:
	fighter().position = Vector2(320.0, 840.0)
	fighter().mode = Mode.AIR
	hold([], 10)


# Puts the fighter in the air 2 pixels left of the left wall.
func beside_left_wall() -> void:
	fighter().position = Vector2(328.0, 1050.0)
	fighter().velocity = Vector2.ZERO
	fighter().mode = Mode.AIR


func test_falling_past_a_ledge_grabs_it() -> void:
	fighter().jumps_left = 0
	hang_on_left_ledge()
	assert_eq(fighter().mode, Mode.LEDGE, "hangs on the ledge")
	assert_eq(fighter().position, Vector2(330.0, 890.0), "beside the wall, just below the corner")
	assert_eq(fighter().facing, 1, "faces the arena")
	assert_eq(fighter().jumps_left, 1, "double jump back")


func test_rising_past_a_ledge_does_not_grab_it() -> void:
	fighter().position = Vector2(320.0, 900.0)
	fighter().mode = Mode.AIR
	fighter().velocity.y = -12.0
	hold([], 6)
	assert_eq(fighter().mode, Mode.AIR, "still in the air")


func test_toward_the_arena_climbs_up() -> void:
	hang_on_left_ledge()
	hold(["right"])
	assert_eq(fighter().mode, Mode.CLIMB, "climbing")
	hold([], sim.stats.ledge_climb_ticks + 2)
	assert_eq(fighter().mode, Mode.GROUND, "on the ground")
	assert_eq(fighter().position, Vector2(394.0, 800.0), "on the main platform at its edge")


func test_up_on_a_ledge_jumps_off_it() -> void:
	hang_on_left_ledge()
	hold(["up"])
	assert_eq(fighter().mode, Mode.AIR, "in the air")
	assert_true(fighter().velocity.y < 0.0, "rising")
	assert_eq(fighter().jumps_left, 1, "double jump still there")


func test_down_lets_go_and_does_not_grab_again_at_once() -> void:
	hang_on_left_ledge()
	hold(["down"])
	assert_eq(fighter().mode, Mode.AIR, "let go")
	hold([], 10)
	assert_eq(fighter().mode, Mode.AIR, "still falling")
	assert_true(fighter().position.y > 890.0, "below the hang position")


func test_away_from_the_arena_lets_go() -> void:
	hang_on_left_ledge()
	hold(["left"])
	assert_eq(fighter().mode, Mode.AIR, "let go")


func test_hanging_too_long_lets_go() -> void:
	hang_on_left_ledge()
	hold([], sim.stats.ledge_hang_ticks)
	assert_eq(fighter().mode, Mode.AIR, "let go by itself")


func test_a_ledge_holds_one_fighter_and_a_new_grabber_takes_it_over() -> void:
	var s := MatchSim.new(TestArena.new(), 2)
	for f in s.fighters:
		f.position = Vector2(320.0, 840.0)
		f.mode = Mode.AIR
	for t in 10:
		s.step([FighterInput.new(), FighterInput.new()])
	assert_eq(s.fighters[0].mode, Mode.LEDGE, "grabbing at the same time: the first one hangs")
	assert_true(s.fighters[1].mode != Mode.LEDGE, "the second does not")
	s = MatchSim.new(TestArena.new(), 2)
	s.fighters[0].position = Vector2(320.0, 840.0)
	s.fighters[0].mode = Mode.AIR
	s.fighters[1].position = Vector2(320.0, 700.0)
	s.fighters[1].mode = Mode.AIR
	for t in 30:
		s.step([FighterInput.new(), FighterInput.new()])
	assert_eq(s.fighters[1].mode, Mode.LEDGE, "the later grabber hangs")
	assert_true(s.fighters[0].mode != Mode.LEDGE, "the one hanging before is pushed off")


func test_against_the_wall_and_up_jumps_off_the_wall() -> void:
	beside_left_wall()
	hold(["right"])
	hold(["right", "up"])
	assert_true(fighter().velocity.x < 0.0, "pushed away from the wall")
	assert_true(fighter().velocity.y < 0.0, "upwards")
	assert_eq(fighter().jumps_left, 1, "double jump kept")
	assert_eq(fighter().facing, -1, "faces away from the wall")


func test_up_without_pressing_against_the_wall_double_jumps() -> void:
	beside_left_wall()
	hold([])
	hold(["up"])
	assert_eq(fighter().jumps_left, 0, "double jump used")
	assert_eq(fighter().wall_jumps_used, 0, "no wall jump")


func test_wall_jumps_run_out_until_landing() -> void:
	for n in sim.stats.max_wall_jumps:
		beside_left_wall()
		hold(["right"])
		hold(["right", "up"])
	assert_eq(fighter().wall_jumps_used, sim.stats.max_wall_jumps, "all wall jumps used")
	beside_left_wall()
	hold(["right"])
	hold(["right", "up"])
	assert_eq(fighter().jumps_left, 0, "the next press is the double jump")
	hold([], 240)
	assert_eq(fighter().wall_jumps_used, 0, "landing gives them back")

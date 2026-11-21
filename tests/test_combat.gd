# Tests of the combat (game design, "Combat" and "Core rules"): attacks, hits, knockback, hit
# pause, lives, respawn and the end of the match. Two fighters on the test arena: fighter a at
# x 900 facing right, fighter b at x 960 facing left, both on the main platform (top at y 800).
extends "res://tests/base_test.gd"

const MatchSim := preload("res://scripts/sim/match_sim.gd")
const TestArena := preload("res://arenas/test_arena.gd")
const FighterInput := preload("res://scripts/sim/fighter_input.gd")
const FighterCombat := preload("res://scripts/sim/fighter_combat.gd")
const Mode = preload("res://scripts/sim/fighter_state.gd").Mode

var sim


func _init() -> void:
	sim = MatchSim.new(TestArena.new(), 2)
	place(Vector2(900.0, 800.0), Vector2(960.0, 800.0))


func a():
	return sim.fighters[0]


func b():
	return sim.fighters[1]


func place(at_a: Vector2, at_b: Vector2) -> void:
	a().position = at_a
	a().facing = 1
	b().position = at_b
	b().facing = -1


# Holds the given keys for fighter a and for fighter b for a number of ticks.
func hold(keys_a: Array = [], keys_b: Array = [], ticks: int = 1) -> void:
	for t in ticks:
		sim.step([_input(keys_a), _input(keys_b)])


# Puts fighter a in the air at the given place, not moving.
func a_in_air(at: Vector2) -> void:
	a().position = at
	a().mode = Mode.AIR
	a().velocity = Vector2.ZERO


func test_jab_hits_after_its_startup_and_only_once() -> void:
	hold(["attack"])
	assert_eq(a().attack, "jab", "no direction gives the jab")
	hold(["attack"], [], 3)
	assert_eq(b().damage, 0.0, "no hit during the startup")
	hold(["attack"])
	assert_eq(b().damage, 3.0, "hit on the first active tick")
	assert_eq(b().mode, Mode.HITSTUN, "launched")
	hold(["attack"], [], 40)
	assert_eq(b().damage, 3.0, "one hit per attack, and holding attack starts no new one")


func test_hit_pause_freezes_both_fighters() -> void:
	hold(["attack"], [], 5)
	var pause := FighterCombat.hitlag_ticks(FighterCombat.data("jab"))
	assert_eq(a().hitlag, pause, "attacker paused")
	assert_eq(b().hitlag, pause, "target paused")
	var at: Vector2 = b().position
	hold([], [], pause)
	assert_eq(b().position, at, "the target stands still during the pause")
	hold()
	assert_true(b().position.x > at.x, "then it flies away from the attacker")


func test_the_held_direction_picks_the_ground_attack() -> void:
	hold(["down", "attack"])
	assert_eq(a().attack, "down", "down: the low kick")
	hold([], [], 40)
	hold(["left", "attack"])
	assert_eq(a().attack, "side", "left: the side attack")
	assert_eq(a().facing, -1, "turned to the side")
	hold([], [], 40)
	hold(["up"])
	assert_eq(a().mode, Mode.JUMP_SQUAT, "up starts the take-off")
	hold(["up", "attack"])
	assert_eq(a().attack, "up", "attack during the take-off: the up attack")
	assert_eq(a().mode, Mode.GROUND, "instead of the jump")


func test_more_damage_launches_farther() -> void:
	var low := _distance_after_side_hit(0.0)
	var high := _distance_after_side_hit(100.0)
	assert_true(high > low * 2.0, "at 100 %% %.0f px, at 0 %% %.0f px" % [high, low])


func test_two_fighters_hitting_each_other_both_get_hit() -> void:
	hold(["attack"], ["attack"], 5)
	assert_eq(a().damage, 3.0, "a hit")
	assert_eq(b().damage, 3.0, "b hit")


func test_air_attacks() -> void:
	b().position = Vector2(1400.0, 800.0)
	a_in_air(Vector2(960.0, 300.0))
	hold(["attack"])
	assert_eq(a().attack, "nair", "no direction: the neutral air attack")
	hold([], [], 30)
	a_in_air(Vector2(960.0, 300.0))
	hold(["left", "attack"])
	assert_eq(a().attack, "fair", "a side: the forward air attack")
	assert_eq(a().facing, -1, "turned to that side")


func test_air_attack_allows_no_jump() -> void:
	b().position = Vector2(1400.0, 800.0)
	a_in_air(Vector2(960.0, 300.0))
	hold(["attack"])
	hold(["up"])
	assert_eq(a().jumps_left, 1, "no double jump during the attack")


func test_landing_during_an_air_attack_gives_landing_lag() -> void:
	b().position = Vector2(1400.0, 800.0)
	a_in_air(Vector2(960.0, 790.0))
	a().velocity.y = 5.0
	hold(["attack"], [], 3)
	assert_eq(a().mode, Mode.GROUND, "landed")
	assert_eq(a().attack, "", "the attack ended")
	assert_true(a().lag > 0, "landing lag")
	hold([])
	hold(["attack"])
	assert_eq(a().attack, "", "no attack during the landing lag")


func test_ground_pound_stops_then_drops_fast_and_lands_with_lag() -> void:
	b().position = Vector2(1400.0, 800.0)
	a_in_air(Vector2(960.0, 300.0))
	hold(["down", "attack"])
	assert_eq(a().attack, "ground_pound", "down in the air: the ground pound")
	var startup: int = FighterCombat.data("ground_pound")["startup"]
	hold(["down"], [], startup - 1)
	assert_eq(a().position, Vector2(960.0, 300.0), "stops in the air")
	hold(["down"], [], 2)
	assert_eq(a().velocity.y, sim.stats.fast_fall_speed * 2.0, "drops at twice the fast-fall speed")
	hold([], [], 30)
	assert_eq(a().mode, Mode.GROUND, "landed")
	assert_eq(a().position.x, 960.0, "straight down")
	assert_eq(a().attack, "", "ended on landing")


func test_ground_pound_bounces_a_fighter_on_the_ground() -> void:
	place(Vector2(960.0, 300.0), Vector2(960.0, 800.0))
	a().mode = Mode.AIR
	hold(["down", "attack"])
	var top := 800.0
	for t in 40:
		hold()
		top = minf(top, b().position.y)
	assert_eq(b().damage, 10.0, "hit on the way down")
	assert_true(top < 790.0, "bounced up to %.0f" % top)


func test_recovery_move_carries_up_once_per_air_time() -> void:
	b().position = Vector2(1400.0, 800.0)
	a_in_air(Vector2(960.0, 500.0))
	hold(["up", "attack"])
	assert_eq(a().attack, "recovery", "up in the air: the recovery move")
	assert_eq(a().velocity.y, -sim.stats.recovery_speed, "carried up")
	assert_eq(a().jumps_left, 1, "the double jump is kept")
	hold([], [], 30)
	assert_eq(a().attack, "", "over")
	hold(["up", "attack"])
	assert_true(a().attack != "recovery", "not twice in one time in the air")
	hold([], [], 240)
	assert_eq(a().mode, Mode.GROUND, "landed")
	assert_eq(a().recovery_used, false, "landing gives it back")


func test_a_hit_knocks_a_fighter_off_the_ledge() -> void:
	b().position = Vector2(320.0, 840.0)
	b().mode = Mode.AIR
	a().position = Vector2(390.0, 800.0)
	hold([], [], 10)
	assert_eq(b().mode, Mode.LEDGE, "b hangs on the left ledge")
	a().facing = -1
	hold(["down", "attack"], [], 6)
	assert_eq(b().mode, Mode.HITSTUN, "the low kick reaches the ledge")
	assert_eq(b().ledge, -1, "and knocks b off it")


func test_lost_life_respawns_on_the_platform_with_invulnerability() -> void:
	b().position = Vector2(1800.0, 800.0)
	b().mode = Mode.AIR
	b().damage = 50.0
	for t in 200:
		hold()
		if b().respawns > 0:
			break
	assert_eq(b().stocks, MatchSim.DEFAULT_STOCKS - 1, "one life lost")
	assert_eq(b().mode, Mode.RESPAWN, "on the respawn platform")
	assert_eq(b().damage, 0.0, "back at 0 %")
	hold([], [], 60)
	assert_eq(b().position, sim.arena.respawn_point, "the platform holds until a key")
	assert_true(not sim.can_be_hit(b()), "cannot be hit on the platform")
	hold([], ["left"])
	assert_eq(b().mode, Mode.AIR, "a key leaves the platform")
	assert_true(not sim.can_be_hit(b()), "still cannot be hit")
	hold([], [], sim.stats.respawn_invuln_ticks)
	assert_true(sim.can_be_hit(b()), "after 2 seconds it can be hit again")


func test_the_platform_lets_go_by_itself() -> void:
	b().position = Vector2(1800.0, 800.0)
	b().mode = Mode.AIR
	for t in 200:
		hold()
		if b().respawns > 0:
			break
	hold([], [], sim.stats.respawn_wait_ticks)
	assert_eq(b().mode, Mode.AIR, "falls after the wait")


func test_the_last_fighter_with_lives_wins() -> void:
	sim = MatchSim.new(TestArena.new(), 2, null, 1)
	b().position = Vector2(1800.0, 800.0)
	b().mode = Mode.AIR
	for t in 200:
		hold()
	assert_true(b().out, "b is out")
	assert_true(sim.over, "the match is over")
	assert_eq(sim.winner, 0, "a wins")
	var tick: int = sim.tick
	hold(["right"], [], 10)
	assert_eq(sim.tick, tick, "an ended match does not go on")


func test_same_inputs_give_the_same_fight() -> void:
	var one := MatchSim.new(TestArena.new(), 2)
	var two := MatchSim.new(TestArena.new(), 2)
	var hits := 0
	for t in 600:
		one.step([_fight(t, 1), _fight(t + 11, -1)])
		two.step([_fight(t, 1), _fight(t + 11, -1)])
		for event in one.events:
			if event["type"] == "hit":
				hits += 1
	assert_true(hits > 0, "the fighters hit each other")
	assert_eq(one.snapshot(), two.snapshot(), "snapshots")


func test_restore_replays_the_same_fight() -> void:
	var s := MatchSim.new(TestArena.new(), 2)
	for t in 300:
		s.step([_fight(t, 1), _fight(t + 11, -1)])
	var saved := s.snapshot()
	for t in range(300, 500):
		s.step([_fight(t, 1), _fight(t + 11, -1)])
	var first := s.snapshot()
	s.restore(saved)
	for t in range(300, 500):
		s.step([_fight(t, 1), _fight(t + 11, -1)])
	assert_eq(s.snapshot(), first, "snapshots")


# How far fighter b flies within 40 ticks after a side attack, starting at the given damage.
func _distance_after_side_hit(damage: float) -> float:
	sim = MatchSim.new(TestArena.new(), 2)
	place(Vector2(900.0, 800.0), Vector2(960.0, 800.0))
	b().damage = damage
	hold(["right", "attack"])
	hold([], [], 46)
	return b().position.x - 960.0


func _input(keys: Array) -> FighterInput:
	var input := FighterInput.new()
	for key in keys:
		input.set(key, true)
	return input


# A fixed input sequence that walks mostly towards `forward` (1 right, -1 left), jumps and
# attacks in all directions.
func _fight(t: int, forward: int) -> FighterInput:
	var input := FighterInput.new()
	var phase := t % 90
	var ahead := phase < 35
	var back := phase >= 45 and phase < 55
	input.right = ahead if forward > 0 else back
	input.left = back if forward > 0 else ahead
	input.up = t % 41 < 2 or t % 67 == 5
	input.down = t % 53 == 30
	input.attack = t % 13 < 2
	return input

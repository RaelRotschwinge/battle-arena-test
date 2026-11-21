# Tests of the combat (game design, "Combat" and "Core rules"): attacks, hits, knockback, hit
# pause, lives, respawn and the end of the match. Two fighters on the test arena: fighter a at
# x 900 facing right, fighter b at x 960 facing left, both on the main platform (top at y 800).
extends "res://tests/base_test.gd"

const MatchSim := preload("res://scripts/sim/match_sim.gd")
const TestArena := preload("res://arenas/test_arena.gd")
const FighterInput := preload("res://scripts/sim/fighter_input.gd")
const FighterCombat := preload("res://scripts/sim/fighter_combat.gd")
const FighterDefense := preload("res://scripts/sim/fighter_defense.gd")
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
	hold(["attack"], [], FighterCombat.data(a(), "jab")["startup"])
	assert_eq(b().damage, 0.0, "no hit during the startup")
	hold(["attack"])
	assert_eq(b().damage, 3.0, "hit on the first active tick")
	assert_eq(b().mode, Mode.HITSTUN, "launched")
	hold(["attack"], [], 40)
	assert_eq(b().damage, 3.0, "one hit per attack, and holding attack starts no new one")


func test_hit_pause_freezes_both_fighters() -> void:
	hold(["attack"], [], FighterCombat.data(a(), "jab")["startup"] + 2)
	var pause := FighterCombat.hitlag_ticks(FighterCombat.data(a(), "jab"))
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
	hold(["up", "attack"])
	assert_eq(a().attack, "up", "up and attack together: the up attack")
	hold([], [], 30)
	assert_eq(a().mode, Mode.GROUND, "no jump after it")


func test_a_direction_pressed_just_after_attack_still_picks_the_attack() -> void:
	b().position = Vector2(1400.0, 800.0)
	hold(["attack"])
	hold(["down", "attack"])
	assert_eq(a().attack, "down", "on the ground")
	hold([], [], 30)
	hold(["attack"])
	hold(["up", "attack"])
	assert_eq(a().attack, "up", "up just after attack: the up attack")
	hold([], [], 30)
	assert_eq(a().mode, Mode.GROUND, "and no jump")
	a_in_air(Vector2(960.0, 300.0))
	hold(["attack"])
	hold(["right", "attack"])
	assert_eq(a().attack, "fair", "in the air")


func test_attack_during_the_take_off_gives_the_uppercut_on_the_ground() -> void:
	b().position = Vector2(1400.0, 800.0)
	hold(["up"])
	assert_eq(a().mode, Mode.JUMP_SQUAT, "up starts the take-off")
	hold(["up", "attack"])
	assert_eq(a().attack, "up", "the uppercut")
	assert_eq(a().mode, Mode.GROUND, "instead of the jump")
	hold(["up"], [], 30)
	assert_eq(a().mode, Mode.GROUND, "no jump after it")


# Fighter b stands in fighter a; up and attack in any order must hit b at once, before a moves.
func test_the_uppercut_hits_a_fighter_standing_in_the_attacker() -> void:
	var orders := {
		"together": [["up", "attack"]],
		"up first": [["up"], ["up", "attack"]],
		"up two ticks first": [["up"], ["up"], ["up", "attack"]],
		"attack first": [["attack"], ["up", "attack"]],
	}
	for order in orders:
		for b_x in [960.0, 975.0, 945.0]:
			sim = MatchSim.new(TestArena.new(), 2)
			place(Vector2(960.0, 800.0), Vector2(b_x, 800.0))
			var presses: Array = orders[order]
			var hit_tick := -1
			for t in 12:
				hold(presses[mini(t, presses.size() - 1)])
				if b().damage > 0.0:
					hit_tick = t
					break
			var where := "%s, b at x %.0f" % [order, b_x]
			assert_true(hit_tick >= 0 and hit_tick <= presses.size() + 4,
					"%s: hit on tick %d" % [where, hit_tick])
			assert_eq(a().position, Vector2(960.0, 800.0), "%s: a has not moved" % where)


func test_an_attack_pressed_during_an_attack_comes_right_after_it() -> void:
	b().position = Vector2(1400.0, 800.0)
	hold(["attack"])
	var a_jab := FighterCombat.data(a(), "jab")
	var total: int = a_jab["startup"] + a_jab["active"] + a_jab["recovery"]
	hold([], [], total - 5)
	hold(["attack"])
	hold([], [], 4)
	assert_eq(a().attack_ticks, total, "the first jab still runs")
	hold()
	assert_eq(a().attack, "jab", "the second jab")
	assert_eq(a().attack_ticks, 0, "starts at once")


func test_a_jump_pressed_near_the_end_of_an_air_attack_comes_right_after_it() -> void:
	b().position = Vector2(1400.0, 800.0)
	a_in_air(Vector2(960.0, 200.0))
	hold(["attack"])
	hold([], [], 4)
	hold(["up"])
	assert_eq(a().jumps_left, 1, "no jump during the attack")
	var nair := FighterCombat.data(a(), "nair")
	var total: int = nair["startup"] + nair["active"] + nair["recovery"]
	hold([], [], total - 12)
	hold(["up"])
	hold([], [], 7)
	assert_eq(a().jumps_left, 0, "the double jump right after the attack")


func test_more_damage_launches_farther() -> void:
	var low := _distance_after_side_hit(0.0)
	var high := _distance_after_side_hit(100.0)
	assert_true(high > low * 2.0, "at 100 %% %.0f px, at 0 %% %.0f px" % [high, low])


func test_two_fighters_hitting_each_other_both_get_hit() -> void:
	hold(["attack"], ["attack"], FighterCombat.data(a(), "jab")["startup"] + 2)
	assert_eq(a().damage, 3.0, "a hit")
	assert_eq(b().damage, 3.0, "b hit")


func test_air_attacks() -> void:
	b().position = Vector2(1400.0, 800.0)
	a_in_air(Vector2(960.0, 300.0))
	hold(["attack"])
	assert_eq(a().attack, "nair", "no direction: the neutral air attack")
	hold([], [], 30)
	a_in_air(Vector2(960.0, 300.0))
	hold(["right", "attack"])
	assert_eq(a().attack, "fair", "the way it faces: the forward air attack")
	hold([], [], 30)
	a_in_air(Vector2(960.0, 300.0))
	hold(["left", "attack"])
	assert_eq(a().attack, "bair", "the other way: the back air attack")
	assert_eq(a().facing, 1, "it does not turn")


func test_up_held_on_from_a_jump_does_not_make_every_air_attack_the_up_air() -> void:
	b().position = Vector2(1400.0, 800.0)
	a().position.x = 960.0
	hold(["up"], [], 15)
	assert_eq(a().mode, Mode.AIR, "jumped")
	hold(["up", "attack"])
	assert_eq(a().attack, "nair", "the neutral air")
	hold(["up"], [], 18)
	hold(["up", "right", "attack"])
	assert_eq(a().attack, "fair", "with a side: the forward air")


func test_landing_during_an_air_attack_gives_landing_lag() -> void:
	b().position = Vector2(1400.0, 800.0)
	a_in_air(Vector2(960.0, 790.0))
	a().velocity.y = 5.0
	hold(["attack"])
	hold()
	assert_eq(a().mode, Mode.GROUND, "landed")
	assert_eq(a().attack, "", "the attack ended")
	assert_eq(a().lag, sim.stats.landing_lag_ticks, "landing lag")
	hold(["attack"])
	assert_eq(a().attack, "", "no attack during the landing lag")
	hold(["attack"], [], sim.stats.landing_lag_ticks - 1)
	assert_eq(a().attack, "jab", "the attack pressed in the lag comes right after it")


func test_ground_pound_stops_then_drops_fast_and_lands_with_lag() -> void:
	b().position = Vector2(1400.0, 800.0)
	a_in_air(Vector2(960.0, 300.0))
	hold(["down", "attack"])
	assert_eq(a().attack, "ground_pound", "down in the air: the ground pound")
	var startup: int = FighterCombat.data(a(), "ground_pound")["startup"]
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


func test_up_air_hits_every_time_and_carries_up_once_per_air_time() -> void:
	b().position = Vector2(1400.0, 800.0)
	a_in_air(Vector2(960.0, 500.0))
	hold(["up", "attack"])
	assert_eq(a().attack, "up_air", "up and attack in the air: the up air")
	assert_eq(a().velocity.y, -sim.stats.lift_speed, "carried up")
	assert_eq(a().jumps_left, 1, "the double jump is kept")
	hold([], [], 30)
	assert_eq(a().attack, "", "over")
	hold(["up", "attack"])
	assert_eq(a().attack, "up_air", "the up air again")
	assert_true(not a().lifting, "without the lift")
	assert_eq(a().jumps_left, 1, "and without a jump")
	hold([], [], 240)
	assert_eq(a().mode, Mode.GROUND, "landed")
	assert_eq(a().lift_used, false, "landing gives the lift back")


func test_the_low_kick_hits_fighters_standing_in_each_other() -> void:
	place(Vector2(960.0, 800.0), Vector2(965.0, 800.0))
	a().facing = -1
	hold(["down", "attack"], [], FighterCombat.data(a(), "down")["startup"] + 2)
	assert_eq(b().damage, 6.0, "hit behind")
	assert_true(b().velocity.x > 0.0, "launched away")


func test_a_hit_knocks_a_fighter_off_the_ledge() -> void:
	b().position = Vector2(320.0, 840.0)
	b().mode = Mode.AIR
	a().position = Vector2(390.0, 800.0)
	hold([], [], 10)
	assert_eq(b().mode, Mode.LEDGE, "b hangs on the left ledge")
	hold([], [], FighterDefense.LEDGE_INVULN)  # The grab made b invulnerable for a moment.
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
	assert_eq(b().position, sim.arena.respawn_point + Vector2(MatchSim.RESPAWN_SPACING / 2.0, 0.0),
			"the platform holds until a key")
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
	var ahead := phase < 45
	var back := phase >= 60 and phase < 68
	input.right = ahead if forward > 0 else back
	input.left = back if forward > 0 else ahead
	input.up = t % 41 < 2 or t % 67 == 5
	input.down = t % 53 == 30
	input.attack = t % 30 < 2
	input.shield = t % 77 < 6 or t % 131 == 40
	return input

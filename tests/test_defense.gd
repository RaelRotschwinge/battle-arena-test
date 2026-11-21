# Tests of defence and the ways out of combos (game design, "Defence"): shield, parry, shield
# break, dodges, grabs and throws, DI, techs, the early way out of hitstun, the combo guard, stale
# moves, ledge rules, and the gamepad's jump button. Two fighters on the test arena: a at x 900
# facing right, b at x 960 facing left, both on the main platform (top at y 800).
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


func hold(keys_a: Array = [], keys_b: Array = [], ticks: int = 1) -> void:
	for t in ticks:
		sim.step([_input(keys_a), _input(keys_b)])


func _input(keys: Array) -> FighterInput:
	var input := FighterInput.new()
	for key in keys:
		input.set(key, true)
	return input


# b raises its shield and holds it long enough that a new hit is no parry.
func b_shields() -> void:
	hold([], ["shield"], FighterDefense.PARRY_TICKS + 2)


func test_the_shield_blocks_a_hit_and_slides_back() -> void:
	b_shields()
	assert_eq(b().mode, Mode.SHIELD, "held shield key: shield up")
	var hp: float = b().shield_hp
	hold(["right", "attack"], ["shield"], 20)
	assert_eq(b().damage, 0.0, "no damage")
	assert_eq(b().mode, Mode.SHIELD, "still shielding")
	assert_true(b().shield_hp < hp - 8.0, "the shield took the side attack's damage")
	assert_true(b().position.x > 960.0, "and slid back")


func test_a_shield_pressed_just_before_the_hit_parries() -> void:
	hold(["right", "attack"], [], 3)
	for t in 10:
		hold(["right", "attack"], ["shield"])
		if a().hitlag > 0:
			break
	assert_eq(b().damage, 0.0, "no damage")
	assert_true(b().shield_hp > FighterDefense.SHIELD_MAX - 9.0, "the shield takes nothing")
	assert_true(a().hitlag >= FighterDefense.PARRY_FREEZE - 1, "the attacker stands frozen")


func test_the_shield_wears_down_breaks_and_comes_back() -> void:
	b().shield_hp = 3.0
	hold([], ["shield"], 20)
	assert_eq(b().mode, Mode.SHIELD_BREAK, "held too long: the shield breaks")
	hold([], [], FighterDefense.SHIELD_BREAK_TICKS + 2)
	assert_eq(b().mode, Mode.GROUND, "the stun ends")
	assert_true(b().shield_hp >= FighterDefense.SHIELD_AFTER_BREAK, "with part of the shield back")
	var hp: float = b().shield_hp
	hold([], [], FighterDefense.SHIELD_REGEN_WAIT + 10)
	assert_true(b().shield_hp > hp, "it regrows when not held")


func test_left_or_right_in_the_shield_rolls_and_the_roll_cannot_be_hit() -> void:
	b().position = Vector2(1200.0, 800.0)
	hold(["shield"], [], 3)
	hold(["shield", "left"])
	assert_eq(a().mode, Mode.DODGE, "a rolls")
	assert_eq(a().dodge, "roll", "a roll")
	hold(["shield", "left"], [], 5)
	assert_true(not sim.can_be_hit(a()), "invulnerable in the middle of the roll")
	hold([], [], 30)
	assert_true(absf(a().position.x - (900.0 - FighterDefense.ROLL["distance"])) < 12.0,
			"about 150 px to the left")
	assert_eq(a().mode, Mode.GROUND, "back on its feet")
	assert_eq(a().facing, 1, "facing back the way it came")


func test_a_direction_just_before_the_shield_key_rolls_at_once() -> void:
	b().position = Vector2(1200.0, 800.0)
	hold(["left"])
	hold(["left", "shield"])
	assert_eq(a().dodge, "roll", "no exact simultaneous press needed")
	place(Vector2(900.0, 800.0), Vector2(1200.0, 800.0))
	hold([], [], 40)
	hold(["left"], [], 20)  # Walking left for a while, then the shield: a shield, no roll.
	hold(["left", "shield"])
	assert_eq(a().mode, Mode.SHIELD, "a held direction does not roll")


func test_a_roll_stops_at_the_edge() -> void:
	a().position = Vector2(420.0, 800.0)
	b().position = Vector2(1200.0, 800.0)
	hold(["shield"], [], 2)
	hold(["shield", "left"])
	hold([], [], 40)
	assert_eq(a().mode, Mode.GROUND, "still on the platform")
	assert_true(a().position.x >= 360.0, "did not roll off")


func test_down_in_the_shield_dodges_in_place() -> void:
	hold([], ["shield"], 2)
	hold([], ["shield", "down"])
	assert_eq(b().dodge, "spot", "spot dodge")
	hold([], [], 4)
	assert_true(not sim.can_be_hit(b()), "cannot be hit")
	hold(["attack"], [], 5)
	assert_eq(b().damage, 0.0, "the jab goes through")


func test_dodges_in_a_row_protect_less() -> void:
	b().position = Vector2(1400.0, 800.0)
	var protected := []
	for n in 3:
		hold(["shield"], [], 2)
		hold(["shield", "down"])
		var ticks := 0
		for t in 24:
			hold(["shield"])
			if not sim.can_be_hit(a()):
				ticks += 1
		protected.append(ticks)
		hold([], [], 2)
	assert_true(protected[1] < protected[0] and protected[2] < protected[1],
			"each dodge in a row is invulnerable less long: %s" % [protected])


func test_the_air_dodge_moves_protects_and_comes_once_per_time_in_the_air() -> void:
	a().position = Vector2(700.0, 400.0)
	a().mode = Mode.AIR
	b().position = Vector2(1400.0, 800.0)
	hold(["shield", "right"])
	assert_eq(a().mode, Mode.DODGE, "the shield key in the air: an air dodge")
	hold(["right"], [], 4)
	assert_true(not sim.can_be_hit(a()), "invulnerable")
	hold([], [], 12)
	assert_true(absf(a().position.x - (700.0 + FighterDefense.AIR_DODGE["distance"])) < 20.0,
			"130 px the way it was aimed")
	hold([], [], 20)
	hold(["shield"])
	assert_true(a().mode != Mode.DODGE, "no second air dodge in the same time in the air")


func test_an_air_dodge_into_the_ground_slides_on() -> void:
	a().position = Vector2(700.0, 770.0)
	a().mode = Mode.AIR
	b().position = Vector2(1400.0, 800.0)
	hold(["shield", "right", "down"])
	hold(["right", "down"], [], 5)
	assert_eq(a().mode, Mode.GROUND, "landed")
	assert_true(a().velocity.x > 4.0, "sliding on")
	assert_true(a().lag > 0, "with a short lag")


func test_attack_in_the_shield_grabs_and_the_holder_throws() -> void:
	b_shields()
	hold(["shield"], ["shield"], 3)
	hold(["shield", "attack"], ["shield"], FighterCombat.data(a(), "grab")["startup"] + 2)
	assert_eq(a().mode, Mode.GRAB, "a holds b: a grab goes through the shield")
	assert_eq(b().mode, Mode.HELD, "b is held")
	hold([], ["shield"], FighterDefense.GRAB_HOLD_TICKS + 2)
	assert_eq(b().mode, Mode.HITSTUN, "thrown forward at the latest after the hold time")
	assert_true(b().damage > 0.0, "with damage")
	assert_true(b().velocity.x > 0.0 or b().hitlag > 0, "to the right")


func test_the_held_direction_picks_the_throw() -> void:
	hold(["shield"], [], 3)
	hold(["shield", "attack"], [], FighterCombat.data(a(), "grab")["startup"] + 2)
	assert_eq(a().mode, Mode.GRAB, "grabbed")
	hold(["up"], [], FighterDefense.GRAB_MIN_TICKS + 1)
	assert_eq(b().stale.size(), 0, "b threw nothing")
	assert_eq(a().stale.back(), "throw_up", "up: the up throw")


func test_a_grab_misses_a_dodging_fighter() -> void:
	hold(["shield"], ["shield"], 3)
	hold(["shield", "attack"], ["shield", "down"], FighterCombat.data(a(), "grab")["startup"] + 2)
	assert_true(a().mode != Mode.GRAB, "no grab")


func _side_hit_on_b(keys_b: Array) -> Vector2:
	sim = MatchSim.new(TestArena.new(), 2)
	place(Vector2(900.0, 800.0), Vector2(960.0, 800.0))
	b().damage = 80.0
	for t in 10:
		hold(["right", "attack"])
		if b().hitlag > 0:
			break
	while b().hitlag > 0 or b().launch_pending:
		hold([], keys_b)
	return b().velocity


func test_the_held_direction_bends_the_launch() -> void:
	var none := _side_hit_on_b([])
	var up := _side_hit_on_b(["up"])
	var down := _side_hit_on_b(["down"])
	assert_true(up.angle() < none.angle() and down.angle() > none.angle(),
			"up bends it up, down bends it down: %s %s %s" % [up, none, down])
	assert_true(absf(rad_to_deg(none.angle_to(up))) <= FighterDefense.DI_DEGREES + 0.5,
			"by at most 15 degrees")
	assert_true(is_equal_approx(up.length(), none.length()), "same speed")


func _launch_b_down(damage: float) -> void:
	sim = MatchSim.new(TestArena.new(), 2)
	b().damage = damage
	b().position = Vector2(960.0, 700.0)
	b().mode = Mode.AIR
	a().position = Vector2(960.0, 560.0)
	a().mode = Mode.AIR
	hold(["down", "attack"], [], 8)


func test_the_shield_key_just_before_hitting_the_ground_techs() -> void:
	_launch_b_down(40.0)
	assert_eq(b().mode, Mode.HITSTUN, "spiked by the ground pound")
	var landed := false
	for t in 40:
		var near: bool = b().position.y > 800.0 - 5.0 * absf(b().velocity.y) and b().velocity.y > 0
		hold([], ["shield"] if near else [])
		if b().mode == Mode.TECH:
			landed = true
			break
	assert_true(landed, "a tech instead of a bounce")
	assert_true(not sim.can_be_hit(b()), "invulnerable")


func test_a_press_far_too_early_does_not_tech() -> void:
	_launch_b_down(40.0)
	hold([], ["shield"])
	for t in 40:
		hold()
	assert_true(b().mode != Mode.TECH, "no tech")


func test_late_in_hitstun_a_jump_ends_it() -> void:
	sim = MatchSim.new(TestArena.new(), 2)
	place(Vector2(900.0, 800.0), Vector2(960.0, 800.0))
	b().damage = 60.0
	hold(["right", "attack"], [], 7)
	while b().hitlag > 0:
		hold()
	var total: int = b().hitstun_total
	assert_true(total > 10, "a long hitstun")
	hold([], ["up"])
	hold([], [], 2)
	assert_eq(b().mode, Mode.HITSTUN, "early on a jump does nothing")
	for t in total:
		var keys: Array = ["up"] if t % 2 == 0 else []
		hold([], keys)
		if b().mode != Mode.HITSTUN:
			break
	assert_true(b().hitstun > 0 or b().jumps_left == 0, "the double jump ended the hitstun early")


func test_long_combos_get_shorter_hitstun() -> void:
	var f = b()
	var a_up := FighterCombat.data(a(), "up")
	FighterCombat.apply_hit(f, a_up, 1)
	var first: int = f.hitstun
	f.damage = 0.0
	FighterCombat.apply_hit(f, a_up, 1)
	f.damage = 0.0
	FighterCombat.apply_hit(f, a_up, 1)
	assert_eq(f.hitstun, first, "the third still has the full hitstun")
	f.damage = 0.0
	FighterCombat.apply_hit(f, a_up, 1)
	assert_eq(f.combo_hits, 4, "four hits in a row")
	assert_true(f.hitstun < first, "the fourth has less hitstun")


func test_the_same_attack_again_and_again_gets_weaker() -> void:
	b().position = Vector2(960.0, 800.0)
	var damages := []
	for n in 4:
		var before: float = b().damage
		place(Vector2(900.0, 800.0), Vector2(960.0, 800.0))
		b().mode = Mode.GROUND
		b().velocity = Vector2.ZERO
		hold(["attack"], [], 6)
		damages.append(b().damage - before)
		hold([], [], 30)
	assert_true(damages[3] < damages[0], "the fourth jab does less: %s" % [damages])


func test_only_the_first_ledge_grab_protects() -> void:
	b().position = Vector2(1400.0, 800.0)
	a().position = Vector2(320.0, 840.0)
	a().mode = Mode.AIR
	hold([], [], 10)
	assert_eq(a().mode, Mode.LEDGE, "hangs")
	assert_true(a().invuln > 0, "first grab: invulnerable")
	hold(["down"])
	hold([], [], 3)
	hold(["up"])
	hold([], [], 40)
	for t in 60:
		hold()
		if a().mode == Mode.LEDGE:
			break
	assert_eq(a().mode, Mode.LEDGE, "grabbed again")
	assert_eq(a().invuln, 0, "no invulnerability without landing in between")


func test_attack_on_a_ledge_climbs_up_with_an_attack() -> void:
	b().position = Vector2(1400.0, 800.0)
	a().position = Vector2(320.0, 840.0)
	a().mode = Mode.AIR
	hold([], [], 10)
	hold(["attack"])
	assert_eq(a().mode, Mode.CLIMB, "climbs")
	hold([], [], 10)
	assert_eq(a().attack, "getup", "into the getup attack")
	assert_eq(a().mode, Mode.GROUND, "on the platform")


func test_the_jump_button_jumps_but_is_no_up_for_attacks() -> void:
	b().position = Vector2(1400.0, 800.0)
	hold(["jump"])
	hold(["jump", "attack"], [], 3)
	hold(["jump"], [], 3)
	assert_eq(a().mode, Mode.AIR, "the jump button jumps")
	assert_eq(a().attack, "nair", "attack in the take-off: an air attack, no uppercut")


func test_a_stick_tilted_all_the_way_runs_at_once() -> void:
	b().position = Vector2(1400.0, 800.0)
	hold(["right", "run"], [], 20)
	assert_true(a().running, "running")
	assert_eq(a().velocity.x, sim.stats.run_speed, "at run speed")

# Tests of the special moves (game design, "Special moves"): Kade's Spark (one orb at a time,
# blocked, parried back, knocked away by attacks), Pip's Swoop (a dash in eight directions, once in
# the air), Brum's Whirl (four hits, sideways in the air), and the special key's buffer and shield
# rules.
extends "res://tests/base_test.gd"

const MatchSim := preload("res://scripts/sim/match_sim.gd")
const TestArena := preload("res://arenas/test_arena.gd")
const FighterInput := preload("res://scripts/sim/fighter_input.gd")
const Roster := preload("res://fighters/roster.gd")
const FighterCombat := preload("res://scripts/sim/fighter_combat.gd")
const Mode = preload("res://scripts/sim/fighter_state.gd").Mode


func _input(keys: Array) -> FighterInput:
	var input := FighterInput.new()
	for key in keys:
		input.set(key, true)
	return input


# Fighter a at x_a and b at x_b on the test arena's floor, facing each other.
func _two(a: String, b: String, x_a: float, x_b: float) -> MatchSim:
	var sim := MatchSim.new(TestArena.new(), 2, [Roster.make(a), Roster.make(b)])
	sim.fighters[0].position = Vector2(x_a, 800.0)
	sim.fighters[1].position = Vector2(x_b, 800.0)
	sim.fighters[0].facing = 1 if x_b > x_a else -1
	sim.fighters[1].facing = -sim.fighters[0].facing
	return sim


func _step(sim: MatchSim, a: Array = [], b: Array = [], ticks: int = 1) -> void:
	for t in ticks:
		sim.step([_input(a), _input(b)])


func test_every_fighter_has_a_special_on_the_ground_and_in_the_air() -> void:
	for id in Roster.ids():
		var stats := Roster.make(id)
		assert_true(stats.attacks.has("special") and stats.attacks.has("special_air"), id)
		assert_true(stats.info.has("special") and stats.info.has("special_how"), id + " info")
	var sim := MatchSim.new(TestArena.new(), 1)
	sim.step([_input(["special"])])
	assert_eq(sim.fighters[0].attack, "", "the test fighter has no special")


func test_spark_flies_hits_and_only_one_flies_at_a_time() -> void:
	var sim := _two("kade", "kade", 600.0, 1500.0)
	_step(sim, ["special"])
	_step(sim, [], [], 14)
	assert_eq(sim.shots.size(), 1, "one orb flies")
	var x: float = sim.shots[0]["position"].x
	_step(sim, [], [], 20)
	assert_true(sim.shots[0]["position"].x > x + 150.0, "it flies forward")
	_step(sim, ["special"])
	_step(sim, [], [], 3)
	assert_eq(sim.fighters[0].attack, "", "no second Spark while one flies")
	_step(sim, [], [], 40)
	assert_eq(sim.shots.size(), 0, "the orb is gone after its time")
	_step(sim, ["special"])
	assert_eq(sim.fighters[0].attack, "special", "then the next one")

	var hit := _two("kade", "brum", 700.0, 950.0)
	_step(hit, ["special"])
	_step(hit, [], [], 40)
	assert_eq(hit.fighters[1].damage, 5.0, "the orb deals 5 %")
	assert_eq(hit.shots.size(), 0, "and is gone")


func test_a_shield_stops_the_spark_and_a_parry_sends_it_back() -> void:
	var sim := _two("kade", "brum", 700.0, 950.0)
	_step(sim, [], ["shield"], 10)
	_step(sim, ["special"], ["shield"])
	_step(sim, [], ["shield"], 30)
	assert_eq(sim.fighters[1].damage, 0.0, "blocked")
	assert_eq(sim.shots.size(), 0, "a blocked orb is gone")

	var parry := _two("kade", "brum", 700.0, 1000.0)
	_step(parry, ["special"])
	var raised := false
	for t in 60:
		var near: bool = not parry.shots.is_empty() \
				and parry.shots[0]["position"].x > parry.fighters[1].position.x - 80.0
		raised = raised or near
		_step(parry, [], ["shield"] if raised else [])
	assert_eq(parry.fighters[1].damage, 0.0, "the parrying fighter takes nothing")
	assert_true(parry.fighters[0].damage > 0.0, "the orb flew back and hit Kade")


func test_an_attack_knocks_the_spark_away() -> void:
	var sim := _two("kade", "brum", 700.0, 1000.0)
	_step(sim, ["special"])
	var swung := false
	for t in 40:
		var near: bool = not sim.shots.is_empty() \
				and sim.shots[0]["position"].x > sim.fighters[1].position.x - 140.0
		var press := near and not swung
		swung = swung or near
		_step(sim, [], ["attack"] if press else [])
	assert_eq(sim.fighters[1].damage, 0.0, "the jab met the orb")
	assert_eq(sim.shots.size(), 0, "the orb is gone")


func test_a_flying_spark_is_part_of_the_match_state() -> void:
	var sim := _two("kade", "pip", 600.0, 1300.0)
	_step(sim, ["special"])
	_step(sim, [], [], 15)
	var saved := sim.snapshot()
	_step(sim, [], ["right"], 20)
	var first := sim.snapshot()
	sim.restore(saved)
	_step(sim, [], ["right"], 20)
	assert_eq(sim.snapshot(), first, "the same again after a restore")


func test_swoop_dashes_the_way_held_and_once_in_the_air() -> void:
	var sim := MatchSim.new(TestArena.new(), 1, Roster.make("pip"))
	var pip = sim.fighters[0]
	pip.position = Vector2(700.0, 800.0)
	sim.step([_input(["right", "special"])])
	for t in 20:
		sim.step([_input([])])
	assert_true(pip.position.x > 880.0, "about 216 px on the ground, got %.0f" % pip.position.x)
	for t in 30:
		sim.step([_input([])])
	assert_eq(pip.attack, "", "the Swoop is over")

	pip.position = Vector2(960.0, 300.0)
	pip.mode = Mode.AIR
	pip.velocity = Vector2.ZERO
	sim.step([_input([])])
	sim.step([_input(["up", "special"])])
	var start_y: float = pip.position.y
	for t in 18:
		sim.step([_input(["up"])])
	assert_true(pip.position.y < start_y - 180.0, "up in the air, got %.0f"
			% (start_y - pip.position.y))
	assert_true(pip.special_used, "used in this time in the air")
	while pip.attack != "" and pip.mode == Mode.AIR:  # The Swoop's recovery ends in the air.
		sim.step([_input([])])
	sim.step([_input(["special"])])
	assert_eq(pip.attack, "", "not a second time before landing")
	for t in 120:
		sim.step([_input([])])
	assert_eq(pip.mode, Mode.GROUND, "landed")
	sim.step([_input(["special"])])
	assert_eq(pip.attack, "special", "back after landing")


func test_swoop_stops_where_it_hits() -> void:
	var sim := _two("pip", "brum", 700.0, 860.0)
	_step(sim, ["right", "special"])
	var hit_at := -1
	for t in 30:
		_step(sim)
		if hit_at < 0 and sim.fighters[1].damage > 0.0:
			hit_at = t
	assert_eq(sim.fighters[1].damage, 6.0, "6 %")
	assert_true(sim.fighters[0].position.x < 900.0, "Pip stopped at Brum, got %.0f"
			% sim.fighters[0].position.x)


func test_whirl_hits_four_times_and_carries_brum_sideways_in_the_air() -> void:
	var sim := _two("brum", "kade", 900.0, 980.0)
	_step(sim, ["special"])
	var hits := 0
	for t in 40:
		_step(sim)
		for event in sim.events:
			if event["type"] == "hit" and event["attacker"] == 0:
				hits += 1
	assert_eq(hits, 4, "three light hits and the finisher")
	assert_true(sim.fighters[1].damage >= 14.0, "about 15 %%, got %.1f" % sim.fighters[1].damage)

	var air := MatchSim.new(TestArena.new(), 1, Roster.make("brum"))
	var brum = air.fighters[0]
	brum.position = Vector2(700.0, 300.0)
	brum.mode = Mode.AIR
	air.step([_input([])])
	var x: float = brum.position.x
	air.step([_input(["right", "special"])])
	for t in 26:
		air.step([_input(["right"])])
	assert_true(brum.position.x > x + 110.0, "sideways in the air, got %.0f" % (brum.position.x - x))
	assert_true(brum.special_used and FighterCombat.special_for(brum, true) == "",
			"once per time in the air")


func test_special_comes_out_of_the_shield_and_waits_in_the_buffer() -> void:
	var sim := MatchSim.new(TestArena.new(), 1, Roster.make("kade"))
	var kade = sim.fighters[0]
	for t in 5:
		sim.step([_input(["shield"])])
	assert_eq(kade.mode, Mode.SHIELD, "shielding")
	sim.step([_input(["shield", "special"])])
	assert_eq(kade.attack, "special", "out of the shield at once")

	var buffer := MatchSim.new(TestArena.new(), 1, Roster.make("kade"))
	buffer.step([_input(["attack"])])
	for t in 4:
		buffer.step([_input([])])
	buffer.step([_input(["special"])])
	for t in 8:
		buffer.step([_input([])])
	assert_eq(buffer.fighters[0].attack, "special", "pressed during the jab, it came after")

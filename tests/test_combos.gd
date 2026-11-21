# Checks the ways out of combos (game design, "Ways out of combos") with the combo search: no
# endless combo and no combo that takes a life, against a defender that uses DI, drift, the early
# way out of hitstun and techs. Searches from several damages; takes a few seconds.
extends "res://tests/base_test.gd"

const MatchSim := preload("res://scripts/sim/match_sim.gd")
const TestArena := preload("res://arenas/test_arena.gd")
const ComboSearch := preload("res://tests/combo_search.gd")

const MAX_HITS := 4  # Longest true combo allowed against a defender that tries to get out.
const MAX_HITS_STANDING := 6  # Even against a defender that does nothing.


func _search(damage: float, smart: bool, stats = null) -> Dictionary:
	var sim := MatchSim.new(TestArena.new(), 2, stats)
	sim.fighters[0].position = Vector2(900.0, 800.0)
	sim.fighters[1].position = Vector2(960.0, 800.0)
	sim.fighters[1].facing = -1
	sim.fighters[1].damage = damage
	var search := ComboSearch.new(sim)
	search.smart = smart
	return search.search()


func test_no_long_combo_against_a_defender_that_gets_out() -> void:
	for damage in [0.0, 40.0, 80.0]:
		var result := _search(damage, true)
		assert_true(result["hits"] <= MAX_HITS, "from %d %%: %d hits (%s)" % [damage,
				result["hits"], " > ".join(result["path"])])
		assert_true(not result["ko"] or damage >= 80.0, "from %d %%: a combo takes a life (%s)" % [
				damage, " > ".join(result["path"])])


func test_no_endless_combo_even_against_a_defender_that_does_nothing() -> void:
	for damage in [0.0, 60.0]:
		var result := _search(damage, false)
		assert_true(result["hits"] <= MAX_HITS_STANDING, "from %d %%: %d hits (%s)" % [damage,
				result["hits"], " > ".join(result["path"])])

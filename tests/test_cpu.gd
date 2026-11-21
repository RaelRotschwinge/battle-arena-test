# Tests of the computer opponents (game design, "Computer opponents"): they fight, they do not
# fall off the stage by themselves, a harder level beats an easier one, and the same seed plays
# the same match.
extends "res://tests/base_test.gd"

const MatchSim := preload("res://scripts/sim/match_sim.gd")
const TestArena := preload("res://arenas/test_arena.gd")
const CpuPlayer := preload("res://scripts/sim/cpu_player.gd")


func _play(level_a: int, level_b: int, seed: int, ticks: int) -> MatchSim:
	var sim := MatchSim.new(TestArena.new(), 2)
	var cpus := [CpuPlayer.new(level_a, 0, seed), CpuPlayer.new(level_b, 1, seed + 1)]
	for t in ticks:
		if sim.over:
			break
		sim.step([cpus[0].next_input(sim), cpus[1].next_input(sim)])
	return sim


func test_computer_players_fight_and_stay_on_the_stage() -> void:
	var sim := _play(2, 2, 3, 3600)
	var dealt: float = sim.fighters[0].damage_dealt + sim.fighters[1].damage_dealt
	assert_true(dealt > 50.0, "they hit each other: %.0f %% dealt" % dealt)
	for f in sim.fighters:
		assert_eq(f.self_destructs, 0, "no fall without being hit")


func test_hard_beats_easy() -> void:
	var sim := _play(3, 1, 7, 60 * 240)
	assert_true(sim.over, "the match ends")
	assert_eq(sim.winner, 0, "hard wins")


func test_the_same_seed_plays_the_same_match() -> void:
	var one := _play(3, 2, 11, 900)
	var two := _play(3, 2, 11, 900)
	assert_eq(one.snapshot(), two.snapshot(), "snapshots")

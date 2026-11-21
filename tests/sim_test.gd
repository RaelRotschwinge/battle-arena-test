# Base of the simulation tests: one fighter on the test arena and a helper to hold keys.
# Test arena: main platform top at y 800 from x 360 to 1560, its walls down to y 1100, ledges at
# both top corners; thin platforms at y 620 from x 560 to 860 and 1060 to 1360.
extends "res://tests/base_test.gd"

const MatchSim := preload("res://scripts/sim/match_sim.gd")
const TestArena := preload("res://arenas/test_arena.gd")
const FighterInput := preload("res://scripts/sim/fighter_input.gd")
const Mode = preload("res://scripts/sim/fighter_state.gd").Mode

var sim


func _init() -> void:
	sim = MatchSim.new(TestArena.new(), 1)


func fighter():
	return sim.fighters[0]


# Holds the given keys ("left", "right", "up", "down", "attack") for a number of ticks.
func hold(keys: Array, ticks: int = 1) -> void:
	for t in ticks:
		var input := FighterInput.new()
		for key in keys:
			input.set(key, true)
		sim.step([input])

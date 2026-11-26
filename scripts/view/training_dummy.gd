# The training dummy's input provider, asked like a computer player (next_input(sim)): it stands,
# walks to and fro on the main stage, jumps now and then, holds its shield, or plays as a
# computer player of one of the three levels. Its own ticks count from its creation, so a reset
# (a new dummy) starts its rhythm again.
extends RefCounted

const FighterInput := preload("res://scripts/sim/fighter_input.gd")
const CpuPlayer := preload("res://scripts/sim/cpu_player.gd")

const BEHAVIORS := ["Stand", "Walk", "Jump", "Shield", "CPU Easy", "CPU Medium", "CPU Hard"]
const FIRST_CPU := 4  # The behaviors from here on are the computer levels 1 to 3.
const EDGE := 140.0  # Walking turns this far before an edge of the main stage.
const JUMP_EVERY := 70  # Ticks from one jump to the next.
const JUMP_HOLD := 14  # Ticks up is held: long enough for a full jump.

var behavior := 0
var index := 1
var _cpu  # The computer player of a CPU behavior, else null.
var _dir := 1
var _ticks := 0


func _init(dummy_behavior: int, fighter_index: int, cpu_seed: int) -> void:
	behavior = clampi(dummy_behavior, 0, BEHAVIORS.size() - 1)
	index = fighter_index
	if behavior >= FIRST_CPU:
		_cpu = CpuPlayer.new(behavior - FIRST_CPU + 1, index, cpu_seed)


func next_input(sim) -> FighterInput:
	if _cpu != null:
		return _cpu.next_input(sim)
	var input := FighterInput.new()
	_ticks += 1
	match BEHAVIORS[behavior]:
		"Walk":
			var x: float = sim.fighters[index].position.x
			var stage: Rect2 = sim.arena.solids[0]
			if x > stage.end.x - EDGE:
				_dir = -1
			elif x < stage.position.x + EDGE:
				_dir = 1
			input.left = _dir < 0
			input.right = _dir > 0
		"Jump":
			input.up = _ticks % JUMP_EVERY < JUMP_HOLD
		"Shield":
			input.shield = true
	return input

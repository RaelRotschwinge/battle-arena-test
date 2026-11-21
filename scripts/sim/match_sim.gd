# The match simulation (game design, "Technical design"). step() advances the match by exactly
# one tick from the inputs of that tick. No clock, no random numbers, no reading of devices: the
# same inputs always give the same match.
extends RefCounted

const FighterState := preload("res://scripts/sim/fighter_state.gd")
const FighterStats := preload("res://scripts/sim/fighter_stats.gd")
const FighterMotion := preload("res://scripts/sim/fighter_motion.gd")

var arena
var stats
var fighters: Array = []
var tick := 0


func _init(match_arena, fighter_count: int, fighter_stats = null) -> void:
	arena = match_arena
	stats = fighter_stats if fighter_stats != null else FighterStats.new()
	var middle: float = arena.blast_zone.get_center().x
	for i in fighter_count:
		var f := FighterState.new()
		f.position = arena.spawns[i % arena.spawns.size()]
		f.facing = 1 if f.position.x < middle else -1
		f.mode = FighterState.Mode.GROUND
		f.jumps_left = FighterMotion.MAX_AIR_JUMPS
		fighters.append(f)


# inputs holds one fighter input per fighter, in fighter order.
func step(inputs: Array) -> void:
	for i in fighters.size():
		var f = fighters[i]
		var blocked_ledges := []  # A ledge holds one fighter at a time.
		for other in fighters:
			if other != f and other.ledge >= 0:
				blocked_ledges.append(other.ledge)
		FighterMotion.step(f, inputs[i], stats, arena, blocked_ledges)
		if not arena.blast_zone.intersects(FighterMotion.box(f, stats)):
			_respawn(f)
	tick += 1


func snapshot() -> Dictionary:
	var states := []
	for f in fighters:
		states.append(f.to_dict())
	return {"tick": tick, "fighters": states}


func restore(snap: Dictionary) -> void:
	tick = snap["tick"]
	for i in fighters.size():
		fighters[i].from_dict(snap["fighters"][i])


# M1: a fighter that leaves the blast zone comes back above the arena. Lives come in M2.
func _respawn(f) -> void:
	f.position = arena.respawn_point
	f.velocity = Vector2.ZERO
	f.mode = FighterState.Mode.AIR
	f.mode_ticks = 0
	f.jumps_left = FighterMotion.MAX_AIR_JUMPS
	f.wall_jumps_used = 0
	f.fast_falling = false
	f.jump_rising = false
	f.running = false
	f.drop_ticks = 0
	f.ledge = -1
	f.ledge_cooldown = 0
	f.respawns += 1

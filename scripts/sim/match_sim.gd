# The match simulation (game design, "Technical design"). step() advances the match by exactly
# one tick from the inputs of that tick. No clock, no random numbers, no reading of devices: the
# same inputs always give the same match.
extends RefCounted

const FighterState := preload("res://scripts/sim/fighter_state.gd")
const FighterStats := preload("res://scripts/sim/fighter_stats.gd")
const FighterMotion := preload("res://scripts/sim/fighter_motion.gd")
const FighterCombat := preload("res://scripts/sim/fighter_combat.gd")
const Mode = FighterState.Mode

const DEFAULT_STOCKS := 3

var arena
var stats
var fighters: Array = []
var tick := 0
var over := false  # At most one fighter has lives left (none left with a single fighter).
var winner := -1  # Index of the winning fighter once the match is over, -1 for a draw.
# What happened in the last tick, for the view: {"type": "hit", "position", "speed"} and
# {"type": "ko", "fighter", "position"}. Not part of the match state.
var events: Array = []


func _init(match_arena, fighter_count: int, fighter_stats = null,
		stocks: int = DEFAULT_STOCKS) -> void:
	arena = match_arena
	stats = fighter_stats if fighter_stats != null else FighterStats.new()
	var middle: float = arena.blast_zone.get_center().x
	for i in fighter_count:
		var f := FighterState.new()
		f.position = arena.spawns[i % arena.spawns.size()]
		f.facing = 1 if f.position.x < middle else -1
		f.mode = Mode.GROUND
		f.jumps_left = FighterMotion.MAX_AIR_JUMPS
		f.stocks = stocks
		fighters.append(f)


# inputs holds one fighter input per fighter, in fighter order.
func step(inputs: Array) -> void:
	events.clear()
	if over:
		return
	for i in fighters.size():
		var f = fighters[i]
		if f.out:
			continue
		var blocked_ledges := []  # A ledge holds one fighter at a time.
		for other in fighters:
			if other != f and other.ledge >= 0:
				blocked_ledges.append(other.ledge)
		FighterMotion.step(f, inputs[i], stats, arena, blocked_ledges)
	_resolve_hits()
	for i in fighters.size():
		var f = fighters[i]
		if not f.out and not arena.blast_zone.intersects(FighterMotion.box(f, stats)):
			_lose_life(i)
	_check_end()
	tick += 1


func snapshot() -> Dictionary:
	var states := []
	for f in fighters:
		states.append(f.to_dict())
	return {"tick": tick, "over": over, "winner": winner, "fighters": states}


func restore(snap: Dictionary) -> void:
	tick = snap["tick"]
	over = snap["over"]
	winner = snap["winner"]
	for i in fighters.size():
		fighters[i].from_dict(snap["fighters"][i])


func can_be_hit(f) -> bool:
	return not f.out and f.mode != Mode.RESPAWN and f.invuln == 0


# Finds every hit of this tick first and applies them after, so two fighters hitting each other
# in the same tick both get hit (a trade). An attack hits each fighter once.
func _resolve_hits() -> void:
	var hits := []
	for i in fighters.size():
		var attacker = fighters[i]
		if attacker.out:
			continue
		var hitbox := FighterCombat.hitbox(attacker)
		if not hitbox.has_area():
			continue
		for j in fighters.size():
			var target = fighters[j]
			if j == i or not can_be_hit(target) or (attacker.hit_mask & (1 << j)) != 0:
				continue
			var hurtbox := FighterMotion.box(target, stats)
			if hitbox.intersects(hurtbox):
				var a := FighterCombat.data(attacker.attack)
				hits.append({"attacker": i, "target": j, "attack": attacker.attack,
						"side": FighterCombat.launch_side(attacker, target, a),
						"position": hitbox.intersection(hurtbox).get_center()})
	for hit in hits:
		var attacker = fighters[hit["attacker"]]
		var a := FighterCombat.data(hit["attack"])
		attacker.hit_mask |= 1 << hit["target"]
		attacker.hitlag = maxi(attacker.hitlag, FighterCombat.hitlag_ticks(a))
		var speed := FighterCombat.apply_hit(fighters[hit["target"]], hit["attack"], hit["side"],
				stats)
		events.append({"type": "hit", "position": hit["position"], "speed": speed})


func _lose_life(i: int) -> void:
	var f = fighters[i]
	var blast: Rect2 = arena.blast_zone
	events.append({"type": "ko", "fighter": i, "position": Vector2(
			clampf(f.position.x, blast.position.x, blast.end.x),
			clampf(f.position.y, blast.position.y, blast.end.y))})
	f.stocks -= 1
	_respawn(f)
	if f.stocks <= 0:
		f.stocks = 0
		f.out = true


func _check_end() -> void:
	var left := []
	for i in fighters.size():
		if not fighters[i].out:
			left.append(i)
	if left.is_empty() or (fighters.size() > 1 and left.size() == 1):
		over = true
		winner = left[0] if left.size() == 1 else -1


# After a lost life the fighter comes back on the respawn platform above the arena at 0 %.
func _respawn(f) -> void:
	f.position = arena.respawn_point
	f.velocity = Vector2.ZERO
	f.mode = Mode.RESPAWN
	f.mode_ticks = 0
	f.jumps_left = FighterMotion.MAX_AIR_JUMPS
	f.wall_jumps_used = 0
	f.lift_used = false
	f.lifting = false
	f.ticks_since_up = 1000
	f.attack_buffer = 0
	f.jump_buffer = 0
	f.fast_falling = false
	f.jump_rising = false
	f.running = false
	f.drop_ticks = 0
	f.ledge = -1
	f.ledge_cooldown = 0
	f.damage = 0.0
	f.attack = ""
	f.attack_ticks = 0
	f.hit_mask = 0
	f.hitstun = 0
	f.hitlag = 0
	f.invuln = 0
	f.lag = 0
	f.respawns += 1

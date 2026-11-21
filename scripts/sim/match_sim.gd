# The match simulation (game design, "Technical design"). step() advances the match by exactly
# one tick from the inputs of that tick. No clock, no random numbers, no reading of devices: the
# same inputs always give the same match.
extends RefCounted

const FighterState := preload("res://scripts/sim/fighter_state.gd")
const FighterStats := preload("res://scripts/sim/fighter_stats.gd")
const FighterMotion := preload("res://scripts/sim/fighter_motion.gd")
const FighterCombat := preload("res://scripts/sim/fighter_combat.gd")
const FighterDefense := preload("res://scripts/sim/fighter_defense.gd")
const Mode = FighterState.Mode

const DEFAULT_STOCKS := 3
const RESPAWN_SPACING := 110.0  # Respawn platforms of several fighters stand side by side.
const TRUMP_COOLDOWN := 30  # A fighter pushed off a ledge by another cannot grab one this long.

var arena
var stats  # The first fighter's stats (all fighters share them when one stats was given).
var fighters: Array = []
var tick := 0
var over := false  # At most one fighter has lives left (none left with a single fighter).
var winner := -1  # Index of the winning fighter once the match is over, -1 for a draw.
# What happened in the last tick, for the view: {"type": "hit", "position", "speed", "attacker",
# "target"}, {"type": "block" / "parry" / "break" / "grab", "position", "attacker", "target"} and
# {"type": "ko", "fighter", "position"}. Not part of the match state.
var events: Array = []


# fighter_stats: one stats for all fighters, an array with one per fighter, or null for the test
# fighter.
func _init(match_arena, fighter_count: int, fighter_stats = null,
		stocks: int = DEFAULT_STOCKS) -> void:
	arena = match_arena
	var middle: float = arena.blast_zone.get_center().x
	for i in fighter_count:
		var f := FighterState.new()
		if fighter_stats is Array:
			f.stats = fighter_stats[i]
		elif fighter_stats != null:
			f.stats = fighter_stats
		else:
			f.stats = FighterStats.new() if i == 0 else fighters[0].stats
		f.position = arena.spawns[i % arena.spawns.size()]
		f.facing = 1 if f.position.x < middle else -1
		f.mode = Mode.GROUND
		f.jumps_left = f.stats.air_jumps
		f.stocks = stocks
		fighters.append(f)
	stats = fighters[0].stats if fighter_count > 0 else FighterStats.new()


# inputs holds one fighter input per fighter, in fighter order.
func step(inputs: Array) -> void:
	events.clear()
	if over:
		return
	arena.update(tick + 1, fighters)
	for i in fighters.size():
		var f = fighters[i]
		if f.out:
			continue
		var climbing := []  # A ledge being climbed up cannot be grabbed.
		for other in fighters:
			if other != f and other.mode == Mode.CLIMB:
				climbing.append(other.ledge)
		FighterMotion.step(f, inputs[i], f.stats, arena, climbing)
	_trump_ledges()
	_resolve_hits()
	_update_grabs()
	for i in fighters.size():
		var f = fighters[i]
		if not f.out and not arena.blast_zone.intersects(FighterMotion.box(f, f.stats)):
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
	arena.update(tick, [])


func can_be_hit(f) -> bool:
	return not f.out and f.mode != Mode.RESPAWN and f.invuln == 0 \
			and not FighterDefense.intangible(f)


# A new grabber takes a ledge over: the fighter hanging there before falls off it.
func _trump_ledges() -> void:
	for i in fighters.size():
		var f = fighters[i]
		if f.mode != Mode.LEDGE:
			continue
		for j in fighters.size():
			var other = fighters[j]
			var newer: bool = other.mode_ticks < f.mode_ticks \
					or (other.mode_ticks == f.mode_ticks and j < i)
			if j != i and other.mode == Mode.LEDGE and other.ledge == f.ledge and newer:
				FighterMotion.let_go(f, f.stats)
				f.ledge_cooldown = TRUMP_COOLDOWN
				break


# Finds every hit of this tick first and applies them after, so two fighters hitting each other
# in the same tick both get hit (a trade). An attack hits each fighter once. A raised shield
# blocks a hit; a grab goes through a shield.
func _resolve_hits() -> void:
	var hits := []
	for i in fighters.size():
		var attacker = fighters[i]
		if attacker.out:
			continue
		var hitbox := FighterCombat.hitbox(attacker)
		if not hitbox.has_area():
			continue
		var a := FighterCombat.hit_data(attacker)
		for j in fighters.size():
			var target = fighters[j]
			if j == i or not can_be_hit(target) or (attacker.hit_mask & (1 << j)) != 0:
				continue
			if a.get("grab", false) and not FighterDefense.can_be_grabbed(target):
				continue
			var hurtbox := FighterMotion.box(target, target.stats)
			if hitbox.intersects(hurtbox):
				hits.append({"attacker": i, "target": j, "attack": attacker.attack, "data": a,
						"side": FighterCombat.launch_side(attacker, target, a),
						"position": hitbox.intersection(hurtbox).get_center()})
	for hit in hits:
		var i: int = hit["attacker"]
		var j: int = hit["target"]
		var attacker = fighters[i]
		var target = fighters[j]
		var a: Dictionary = hit["data"]
		attacker.hit_mask |= 1 << j
		var event := {"position": hit["position"], "attacker": i, "target": j}
		if a.get("grab", false):
			if attacker.holding >= 0 or attacker.held_by >= 0 or target.held_by >= 0 \
					or target.holding >= 0 or attacker.attack != "grab":
				continue  # Two grabs at once, or the grabber was hit in the same tick.
			_start_grab(i, j)
			event["type"] = "grab"
			events.append(event)
			continue
		if target.mode == Mode.SHIELD:
			var result := FighterDefense.hit_shield(target, a, hit["side"])
			if result == "parry":
				attacker.hitlag = maxi(attacker.hitlag, FighterDefense.PARRY_FREEZE)
			else:
				attacker.hitlag = maxi(attacker.hitlag, FighterCombat.hitlag_ticks(a))
			event["type"] = result
			events.append(event)
			continue
		# An attack counts once for stale moves, however many fighters or times it hits.
		var own := 1 if attacker.attack_hits > 0 else 0
		var scales := FighterDefense.stale_scales(attacker, hit["attack"], own)
		if attacker.attack_hits == 0:
			FighterDefense.add_stale(attacker, hit["attack"])
		attacker.attack_hits += 1
		attacker.hitlag = maxi(attacker.hitlag, FighterCombat.hitlag_ticks(a))
		if FighterCombat.armored(target, a):  # Takes the damage, keeps attacking.
			target.damage += a["damage"] * scales.x
			attacker.damage_dealt += a["damage"] * scales.x
			target.hitlag = maxi(target.hitlag, FighterCombat.hitlag_ticks(a))
			event["type"] = "armor"
			events.append(event)
			continue
		var before: float = target.damage
		var speed := FighterCombat.apply_hit(target, a, hit["side"], scales.x, scales.y)
		attacker.hitlag = maxi(attacker.hitlag, target.hitlag)  # Strong hits pause both longer.
		attacker.damage_dealt += target.damage - before
		target.last_hit_by = i
		event["type"] = "hit"
		event["speed"] = speed
		events.append(event)


func _start_grab(i: int, j: int) -> void:
	var holder = fighters[i]
	var target = fighters[j]
	holder.attack = ""
	holder.mode = Mode.GRAB
	holder.mode_ticks = 0
	holder.holding = j
	holder.velocity = Vector2.ZERO
	holder.throw = ""
	target.mode = Mode.HELD
	target.mode_ticks = 0
	target.held_by = i
	target.attack = ""
	target.velocity = Vector2.ZERO
	target.shield_stun = 0
	target.dodge = ""
	target.running = false
	_place_held(holder, target)


func _place_held(holder, target) -> void:
	var gap: float = (holder.stats.width + target.stats.width) / 2.0
	target.position = Vector2(holder.position.x + holder.facing * gap, holder.position.y)
	target.facing = -holder.facing


# Keeps a held fighter in front of its holder, carries out the chosen throw, and frees both when
# the grab is broken (a hit on either of them).
func _update_grabs() -> void:
	for i in fighters.size():
		var f = fighters[i]
		if f.mode == Mode.GRAB:
			var target = fighters[f.holding] if f.holding >= 0 else null
			if target == null or target.mode != Mode.HELD or target.held_by != i:
				f.holding = -1
				f.throw = ""
				f.mode = Mode.GROUND
				f.mode_ticks = 0
				continue
			_place_held(f, target)
			if f.throw != "":
				_throw(i)
		elif f.mode == Mode.HELD:
			var holder = fighters[f.held_by] if f.held_by >= 0 else null
			if holder == null or holder.mode != Mode.GRAB or holder.holding != i:
				f.held_by = -1
				f.mode = Mode.AIR
				f.mode_ticks = 0
				f.grab_immune = FighterDefense.GRAB_IMMUNE_TICKS


func _throw(i: int) -> void:
	var holder = fighters[i]
	var j: int = holder.holding
	var target = fighters[j]
	var name: String = holder.throw
	var a := FighterCombat.data(holder, name)
	holder.throw = ""
	holder.holding = -1
	holder.mode = Mode.GROUND
	holder.mode_ticks = 0
	holder.lag = a["recovery"]
	holder.hitlag = maxi(holder.hitlag, FighterCombat.hitlag_ticks(a))
	target.held_by = -1
	target.grab_immune = FighterDefense.GRAB_IMMUNE_TICKS
	var scales := FighterDefense.stale_scales(holder, name)
	FighterDefense.add_stale(holder, name)
	var before: float = target.damage
	var speed := FighterCombat.apply_hit(target, a, holder.facing, scales.x, scales.y)
	holder.damage_dealt += target.damage - before
	target.last_hit_by = i
	events.append({"type": "hit", "position": target.position + Vector2(0.0, -50.0),
			"speed": speed, "attacker": i, "target": j})


func _lose_life(i: int) -> void:
	var f = fighters[i]
	var blast: Rect2 = arena.blast_zone
	events.append({"type": "ko", "fighter": i, "position": Vector2(
			clampf(f.position.x, blast.position.x, blast.end.x),
			clampf(f.position.y, blast.position.y, blast.end.y))})
	if f.last_hit_by >= 0 and f.last_hit_by != i:
		fighters[f.last_hit_by].kos += 1
	else:
		f.self_destructs += 1
	f.falls += 1
	f.stocks -= 1
	if f.holding >= 0:  # A holder that falls out lets go.
		fighters[f.holding].held_by = -1
	_respawn(i)
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
func _respawn(i: int) -> void:
	var f = fighters[i]
	var keep := {"stocks": f.stocks, "respawns": f.respawns + 1, "kos": f.kos, "falls": f.falls,
			"self_destructs": f.self_destructs, "damage_dealt": f.damage_dealt,
			"stale": f.stale.duplicate(), "prev_input": f.prev_input, "stats": f.stats}
	var fresh := FighterState.new()
	for field in FighterState.new().to_dict().keys():
		if field != "prev_input" and field != "stale":
			f.set(field, fresh.get(field))
	for field in keep:
		f.set(field, keep[field])
	var offset := (i - (fighters.size() - 1) / 2.0) * RESPAWN_SPACING
	f.position = arena.respawn_point + Vector2(offset, 0.0)
	f.mode = Mode.RESPAWN
	f.jumps_left = f.stats.air_jumps
	f.ticks_since_up = 1000

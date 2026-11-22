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
const HAZARD_COOLDOWN := 40  # An arena hazard hits a fighter once per burst.

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
# Shots flying (special moves that throw something): {"owner": fighter index, "from": the index of
# the fighter whose move data it uses, "attack": that move's name, "position": middle, "velocity",
# "ticks": ticks flown, "hit_mask": fighters already hit}. Part of the match state.
var shots: Array = []


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
	_fly_shots()
	_resolve_hits()
	_hazard_hits()
	_update_grabs()
	for i in fighters.size():
		var f = fighters[i]
		if not f.out and not arena.blast_zone.intersects(FighterMotion.box(f, f.stats)):
			_lose_life(i)
	for i in fighters.size():
		fighters[i].shot_out = false
	for shot in shots:
		fighters[shot["owner"]].shot_out = true
	_check_end()
	tick += 1


func snapshot() -> Dictionary:
	var states := []
	for f in fighters:
		states.append(f.to_dict())
	return {"tick": tick, "over": over, "winner": winner, "fighters": states,
			"shots": shots.duplicate(true)}


func restore(snap: Dictionary) -> void:
	tick = snap["tick"]
	over = snap["over"]
	winner = snap["winner"]
	for i in fighters.size():
		fighters[i].from_dict(snap["fighters"][i])
	shots = snap["shots"].duplicate(true)
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


# Shots: a move with "shot" data throws one at the tick "at" of the attack along the fighter's
# special aim (its special waits while one flies; an older one would vanish). Shots fly on, fall
# with their "gravity", vanish after their "life", on a solid platform, outside the blast zone, on
# another fighter's shot, or when an active hitbox of another fighter touches them.
func _fly_shots() -> void:
	for i in fighters.size():
		var f = fighters[i]
		if f.out or f.attack == "" or f.hitlag > 0:
			continue
		var a := FighterCombat.data(f)
		if a.has("shot") and f.attack_ticks == a["shot"]["at"]:
			var shot: Dictionary = a["shot"]
			_remove_shots_of(i)
			var offset: Vector2 = shot["offset"]
			shots.append({"owner": i, "from": i, "attack": f.attack,
					"position": f.position + Vector2(offset.x * f.facing, offset.y),
					"velocity": f.special_aim * shot["speed"], "ticks": 0, "hit_mask": 0})
	var kept := []
	for shot in shots:
		var data := shot_data(shot)
		shot["velocity"].y += data.get("gravity", 0.0)
		shot["position"] += shot["velocity"]
		shot["ticks"] += 1
		var box := shot_box(shot)
		var gone: bool = shot["ticks"] > data["life"] or not arena.blast_zone.intersects(box)
		for r: Rect2 in arena.solids:
			gone = gone or box.intersects(r)
		for j in fighters.size():
			var other = fighters[j]
			if j != shot["owner"] and not other.out and FighterCombat.hitbox(other).intersects(box) \
					and not FighterCombat.data(other).get("grab", false):
				gone = true
				events.append({"type": "clank", "position": shot["position"], "attacker": j,
						"target": shot["owner"]})
		if not gone:
			kept.append(shot)
	var clashed := []
	for x in kept.size():
		for y in range(x + 1, kept.size()):
			if kept[x]["owner"] != kept[y]["owner"] \
					and shot_box(kept[x]).intersects(shot_box(kept[y])):
				clashed.append(kept[x])
				clashed.append(kept[y])
				events.append({"type": "clank", "position": kept[x]["position"],
						"attacker": kept[x]["owner"], "target": kept[y]["owner"]})
	shots = []
	for shot in kept:
		if not clashed.has(shot):
			shots.append(shot)


# The move data of a shot: what it deals and how it flies.
func shot_data(shot: Dictionary) -> Dictionary:
	return FighterCombat.data(fighters[shot["from"]], shot["attack"])["shot"]


func shot_box(shot: Dictionary) -> Rect2:
	var size: Vector2 = shot_data(shot)["size"]
	return Rect2(shot["position"] - size / 2.0, size)


func _remove_shots_of(i: int) -> void:
	var kept := []
	for shot in shots:
		if shot["owner"] != i:
			kept.append(shot)
	shots = kept


# Finds every hit of this tick first and applies them after, so two fighters hitting each other
# in the same tick both get hit (a trade). An attack hits each fighter once. A raised shield
# blocks a hit; a grab goes through a shield.
func _resolve_hits() -> void:
	var hits := []
	for k in shots.size():
		var shot: Dictionary = shots[k]
		var box := shot_box(shot)
		for j in fighters.size():
			var target = fighters[j]
			if j == shot["owner"] or not can_be_hit(target) or (shot["hit_mask"] & (1 << j)) != 0:
				continue
			var hurtbox := FighterMotion.box(target, target.stats)
			if box.intersects(hurtbox):
				var side := 1 if shot["velocity"].x >= 0.0 else -1
				hits.append({"attacker": shot["owner"], "target": j, "attack": shot["attack"],
						"data": shot_data(shot), "side": side, "shot": shot,
						"position": box.intersection(hurtbox).get_center()})
				break  # A shot hits one fighter.
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
	var spent := []  # Shots that hit or were blocked this tick.
	for hit in hits:
		var i: int = hit["attacker"]
		var j: int = hit["target"]
		var attacker = fighters[i]
		var target = fighters[j]
		var a: Dictionary = hit["data"]
		var event := {"position": hit["position"], "attacker": i, "target": j}
		if hit.has("shot"):
			_shot_hit(hit, event, spent)
			continue
		attacker.hit_mask |= 1 << j
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
			_stop_on_contact(attacker, a, false)
			continue
		_stop_on_contact(attacker, a, true)
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
	if not spent.is_empty():
		var kept := []
		for shot in shots:
			if not spent.has(shot):
				kept.append(shot)
		shots = kept


# A shot reaches a fighter: a shield blocks it, a parry sends it back as the parrying fighter's
# own, else it hits like an attack (stale moves count it for its owner).
func _shot_hit(hit: Dictionary, event: Dictionary, spent: Array) -> void:
	var shot: Dictionary = hit["shot"]
	if spent.has(shot):
		return
	var i: int = hit["attacker"]
	var j: int = hit["target"]
	var owner = fighters[i]
	var target = fighters[j]
	var a: Dictionary = hit["data"]
	shot["hit_mask"] |= 1 << j
	if target.mode == Mode.SHIELD:
		var result := FighterDefense.hit_shield(target, a, hit["side"])
		event["type"] = result
		events.append(event)
		if result == "parry":
			shot["owner"] = j
			shot["velocity"].x = -shot["velocity"].x
			shot["ticks"] = 0
			shot["hit_mask"] = 0
		else:
			spent.append(shot)
		return
	spent.append(shot)
	var scales := FighterDefense.stale_scales(owner, hit["attack"])
	FighterDefense.add_stale(owner, hit["attack"])
	if FighterCombat.armored(target, a):
		target.damage += a["damage"] * scales.x
		owner.damage_dealt += a["damage"] * scales.x
		target.hitlag = maxi(target.hitlag, FighterCombat.hitlag_ticks(a))
		event["type"] = "armor"
		events.append(event)
		return
	var before: float = target.damage
	var speed := FighterCombat.apply_hit(target, a, hit["side"], scales.x, scales.y)
	owner.damage_dealt += target.damage - before
	target.last_hit_by = i
	event["type"] = "hit"
	event["speed"] = speed
	events.append(event)


# Arena hazards hit like an attack of no one: a shield blocks them, they hit each fighter once
# per burst and give no one the knockout.
func _hazard_hits() -> void:
	for hazard in arena.hazard_hits():
		var box: Rect2 = hazard["box"]
		var a: Dictionary = hazard["data"]
		for j in fighters.size():
			var target = fighters[j]
			if not can_be_hit(target) or target.hazard_cooldown > 0:
				continue
			var hurtbox := FighterMotion.box(target, target.stats)
			if not box.intersects(hurtbox):
				continue
			target.hazard_cooldown = HAZARD_COOLDOWN
			var event := {"position": box.intersection(hurtbox).get_center(), "attacker": -1,
					"target": j}
			if target.mode == Mode.SHIELD:
				event["type"] = FighterDefense.hit_shield(target, a, 1)
			else:
				event["type"] = "hit"
				event["speed"] = FighterCombat.apply_hit(target, a, 1)
			events.append(event)


# A dash ("stop_on_contact": recovery ticks a hit cuts) stops where it meets a fighter or shield.
func _stop_on_contact(attacker, a: Dictionary, hit: bool) -> void:
	if a.has("stop_on_contact") and FighterCombat.is_active(attacker):
		FighterCombat.end_active(attacker, a["stop_on_contact"] if hit else 0)
		attacker.velocity *= 0.25


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

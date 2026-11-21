# Searches for true combos (game design, "Ways out of combos"): an attacker tries many attacks
# and jumps on a defender that does what a good player does when hit: bends the launch away,
# steers away, presses jump and shield for the early way out and techs. A combo is true while
# the defender never got free between two hits. Used by test_combos.gd; slow, so it searches a
# beam of the best combos only.
extends RefCounted

const MatchSim := preload("res://scripts/sim/match_sim.gd")
const FighterInput := preload("res://scripts/sim/fighter_input.gd")
const Mode = preload("res://scripts/sim/fighter_state.gd").Mode

const BEAM := 6
const MAX_DEPTH := 10
const WAIT_LIMIT := 50  # Ticks a macro may wait for its hit.

var sim
var a := 0  # Attacker index.
var d := 1  # Defender index.
var best_hits := 0
var best_damage := 0.0
var best_path := []
var ko := false
var smart := true  # false: the defender does nothing, to see what the attacks allow by themselves.


func _init(match_sim) -> void:
	sim = match_sim


# Searches from the current match state. Returns {"hits", "damage", "path", "ko"}.
func search() -> Dictionary:
	var start_damage: float = sim.fighters[d].damage
	var start_lives: int = sim.fighters[d].stocks
	var beam := [{"snap": sim.snapshot(), "hits": 0, "path": []}]
	for depth in MAX_DEPTH:
		var next := []
		for entry in beam:
			sim.restore(entry["snap"])
			if not _wait_until_free(entry["hits"] == 0):
				continue
			var ready: Dictionary = sim.snapshot()
			for macro in _macros(ready):
				sim.restore(ready)
				var hit := _run(macro, entry["hits"] == 0)
				if not hit:
					continue
				var damage: float = sim.fighters[d].damage - start_damage
				var hits: int = entry["hits"] + 1
				var path: Array = entry["path"] + [macro["name"]]
				if sim.fighters[d].stocks < start_lives:
					ko = true
				if hits > best_hits or (hits == best_hits and damage > best_damage):
					best_hits = hits
					best_damage = damage
					best_path = path
				next.append({"snap": sim.snapshot(), "hits": hits, "path": path,
						"damage": damage})
		if next.is_empty():
			break
		next.sort_custom(func(x, y): return x["damage"] > y["damage"])
		beam = next if depth == 0 else next.slice(0, BEAM)  # Every first hit gets its chance.
	return {"hits": best_hits, "damage": best_damage, "path": best_path, "ko": ko}


# Lets the attacker finish its attack and hit pause, so its next keys count. False when the
# defender gets free first.
func _wait_until_free(first: bool) -> bool:
	for t in WAIT_LIMIT:
		var me = sim.fighters[a]
		var acts: bool = me.hitlag == 0 and me.attack == "" and me.lag == 0 				and (me.mode == Mode.GROUND or me.mode == Mode.AIR)
		if acts:
			return true
		sim.step(_inputs(FighterInput.new()))
		if not first and _free(sim.fighters[d]) or sim.over:
			return false
	return false


# Runs one macro of attacker inputs, then waits. True when it hits while the defender was never
# free (on the first hit any state counts).
func _run(macro: Dictionary, first: bool) -> bool:
	var keys: Array = macro["keys"]
	for t in keys.size() + WAIT_LIMIT:
		var input := _keys(keys[t] if t < keys.size() else [])
		sim.step(_inputs(input))
		for event in sim.events:
			if event["type"] == "hit" and event["attacker"] == a and event["target"] == d:
				return true
		if not first and _free(sim.fighters[d]):
			return false
		if sim.over:
			return false
	return false


func _inputs(attacker_input) -> Array:
	var list := []
	for i in sim.fighters.size():
		list.append(attacker_input if i == a else _escape(i))
	return list


# The defender's best answer when hit: away from the attacker, jump and shield pressed again and
# again.
func _escape(i: int) -> FighterInput:
	var me = sim.fighters[i]
	var them = sim.fighters[a]
	var input := FighterInput.new()
	if _free(me) or not smart:
		return input  # Free, it waits: a combo has ended anyway once it is free.
	var away := 1 if me.position.x >= them.position.x else -1
	input.right = away > 0
	input.left = away < 0
	input.up = sim.tick % 2 == 0
	input.shield = sim.tick % 2 == 1
	return input


func _free(f) -> bool:
	return f.hitlag == 0 and f.mode != Mode.HITSTUN and f.mode != Mode.HELD


func _keys(keys: Array) -> FighterInput:
	var input := FighterInput.new()
	for key in keys:
		input.set(key, true)
	return input


# The attacker's choices from this state: every ground attack, jumps into every air attack at
# several heights, air attacks at once, a double jump into them, and a short walk first.
func _macros(snap: Dictionary) -> Array:
	sim.restore(snap)
	var me = sim.fighters[a]
	var them = sim.fighters[d]
	var toward := "right" if them.position.x >= me.position.x else "left"
	var away := "left" if toward == "right" else "right"
	var facing := "right" if me.facing > 0 else "left"
	var behind := "left" if facing == "right" else "right"
	var list := []
	var airs := {"nair": ["attack"], "fair": [facing, "attack"], "bair": [behind, "attack"],
			"up_air": ["up", "attack"], "ground_pound": ["down", "attack"]}
	if me.mode == Mode.GROUND or me.mode == Mode.JUMP_SQUAT:
		var grounds := {"jab": ["attack"], "side": [toward, "attack"], "up": ["up", "attack"],
				"down": ["down", "attack"]}
		if sim.tick == 0 or them.held_by == a:
			for throw in ["down", "up", toward, away]:
				var keys := [["shield"], ["shield", "attack"]]
				for t in 14:
					keys.append([throw])
				list.append({"name": "grab " + throw, "keys": keys})
		for name in grounds:
			list.append({"name": name, "keys": [grounds[name]]})
			list.append({"name": "walk " + name, "keys": [[toward], [toward], [toward],
					[toward], grounds[name]]})
		for name in airs:
			for wait in [1, 2, 4, 6, 9, 12]:
				var keys := [["jump"]]
				for t in wait:
					keys.append([toward] if t < wait - 1 else [])
				keys.append(airs[name])
				list.append({"name": "hop %d %s" % [wait, name], "keys": keys})
			for rise in [5, 9, 14]:
				var full := [["jump"]]
				for t in rise:
					full.append(["jump", toward])
				full.append(airs[name])
				list.append({"name": "jump %d %s" % [rise, name], "keys": full})
	else:
		for name in airs:
			list.append({"name": name, "keys": [[toward], airs[name]]})
			if me.jumps_left > 0:
				var keys := [["jump", toward]]
				for t in 6:
					keys.append([toward])
				keys.append(airs[name])
				list.append({"name": "double jump " + name, "keys": keys})
	return list

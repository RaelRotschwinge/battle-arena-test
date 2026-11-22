# A computer opponent (game design, "Computer opponents"). It presses the same keys a player
# would, through one fighter input per tick, and sees the other fighters as they were a reaction
# time ago; harder levels only decide better and react faster, they get no extra strength. Its
# chances come from a hash of the tick, so the same match plays out the same way.
extends RefCounted

const FighterInput := preload("res://scripts/sim/fighter_input.gd")
const FighterCombat := preload("res://scripts/sim/fighter_combat.gd")
const FighterMotion := preload("res://scripts/sim/fighter_motion.gd")
const Mode = preload("res://scripts/sim/fighter_state.gd").Mode

const LEVEL_NAMES := ["", "Easy", "Medium", "Hard"]
# reaction: ticks behind what it sees; jitter: plus or minus; shield, dodge, parry: chances to
# defend an attack it sees coming; di, tech: chances when launched; edge: distance it keeps from
# the edge; combo: hits in a row before it backs off; miss: chance to attack out of range; ko:
# damage of the target from which it prefers strong attacks; grab: chance to grab a shield;
# special: chance per tick to use its special when it fits.
const LEVELS := [
	{},
	{"reaction": 28, "jitter": 4, "shield": 0.2, "dodge": 0.0, "parry": 0.0, "di": 0.0,
			"tech": 0.0, "edge": 80.0, "combo": 2, "miss": 0.3, "ko": 80.0, "grab": 0.0,
			"chase_air": false, "air_dodge": false, "rest_after_hit": 40, "think": 20,
			"special": 0.01},
	{"reaction": 16, "jitter": 4, "shield": 0.5, "dodge": 0.3, "parry": 0.0, "di": 0.5,
			"tech": 0.5, "edge": 40.0, "combo": 3, "miss": 0.1, "ko": 100.0, "grab": 0.3,
			"chase_air": true, "air_dodge": false, "rest_after_hit": 0, "think": 10,
			"special": 0.03},
	{"reaction": 9, "jitter": 4, "shield": 0.6, "dodge": 0.3, "parry": 0.25, "di": 0.85,
			"tech": 0.8, "edge": 40.0, "combo": 4, "miss": 0.0, "ko": 90.0, "grab": 0.6,
			"chase_air": true, "air_dodge": true, "rest_after_hit": 0, "think": 5,
			"special": 0.05},
]
const MOVE_SLACK := 12.0  # A move counts as reaching when its hitbox comes this close.

var level := 2
var index := 0  # The fighter this player controls.
var seed := 0

var _seen: Array = []  # Per past tick: one Dictionary per fighter (position, mode, attack...).
var _hold := {}  # Keys held on for some ticks: key -> ticks left.
var _last := FighterInput.new()
var _answered := {}  # "attacker attack-start" -> true: attacks it already chose a defence for.
var _hits_in_row := 0
var _rest := 0  # Ticks it waits before attacking again.
var _ledge_wait := -1
var _respawn_wait := -1
var _last_damage := 0.0
var _di := Vector2.ZERO
var _teched_for := -1
var _aim_up := false  # Its recovery special aims up.


func _init(cpu_level: int = 2, fighter_index: int = 0, cpu_seed: int = 0) -> void:
	level = clampi(cpu_level, 1, 3)
	index = fighter_index
	seed = cpu_seed


func next_input(sim) -> FighterInput:
	var p: Dictionary = LEVELS[level]
	_remember(sim)
	var me = sim.fighters[index]
	var input := FighterInput.new()
	if me.out or sim.over:
		_last = input
		return input
	if me.damage > _last_damage + 0.01:
		_rest = maxi(_rest, p["rest_after_hit"] + int(_chance(sim, 1) * 20.0) \
				if p["rest_after_hit"] > 0 else 0)
		_hits_in_row = 0
	_last_damage = me.damage
	if _rest > 0:
		_rest -= 1
	for key in _hold.keys():
		if _hold[key] > 0:
			input.set(key, true)
			_hold[key] -= 1
		else:
			_hold.erase(key)

	var stage: Rect2 = sim.arena.solids[0]
	match me.mode:
		Mode.HITSTUN:
			_in_hitstun(sim, me, input, stage, p)
		Mode.HELD, Mode.GRAB:
			if me.mode == Mode.GRAB:
				_choose_throw(me, input, stage)
		Mode.LEDGE:
			_on_ledge(sim, me, input)
		Mode.RESPAWN:
			if _respawn_wait < 0:
				_respawn_wait = 20 + int(_chance(sim, 2) * (60.0 if level == 1 else 30.0))
			_respawn_wait -= 1
			if _respawn_wait <= 0:
				input.down = true
				_respawn_wait = -1
		_:
			_ledge_wait = -1
			if _off_stage(me, stage):
				_recover(sim, me, input, stage, p)
			elif _avoid_hazard(sim, me, input):
				pass
			elif not _defend(sim, me, input, p):
				_fight(sim, me, input, stage, p)
	_keep_on_stage(me, input, stage, p)
	_press_fresh(input)
	_last = input
	return input


# What the other fighters did a reaction time ago.
func _remember(sim) -> void:
	var now := []
	for f in sim.fighters:
		now.append({"position": f.position, "velocity": f.velocity, "mode": f.mode,
				"attack": f.attack, "attack_ticks": f.attack_ticks, "facing": f.facing,
				"damage": f.damage, "out": f.out, "invuln": f.invuln, "stats": f.stats,
				"start": sim.tick - f.attack_ticks})
	_seen.append(now)
	var p: Dictionary = LEVELS[level]
	while _seen.size() > p["reaction"] + p["jitter"] + 1:
		_seen.pop_front()


func _seen_now(sim) -> Array:
	var p: Dictionary = LEVELS[level]
	var delay: int = p["reaction"] + int(round((_chance(sim, 3) * 2.0 - 1.0) * p["jitter"]))
	return _seen[maxi(_seen.size() - 1 - delay, 0)]


func _target(sim, me) -> Dictionary:
	var best := {}
	var best_distance := INF
	var seen := _seen_now(sim)
	for i in seen.size():
		var o: Dictionary = seen[i]
		if i == index or o["out"] or o["mode"] == Mode.RESPAWN:
			continue
		if level == 1 and (o["mode"] == Mode.LEDGE or o["invuln"] > 0):
			continue  # Easy leaves a fighter that is hanging or just came back alone.
		var d: float = o["position"].distance_to(me.position)
		if d < best_distance:
			best_distance = d
			best = o.duplicate()
			best["index"] = i
	return best


# Launched: bend the launch toward the stage, tech when hitting the ground, and on hard jump out
# of the hitstun as soon as it may.
func _in_hitstun(sim, me, input, stage: Rect2, p: Dictionary) -> void:
	if me.hitlag > 0 and me.launch_pending:
		if _di == Vector2.ZERO:
			if _chance(sim, 4) < p["di"]:
				# Across the launch: sideways toward the stage for a launch up, up and in for a
				# launch to the side.
				var inward := signf(stage.get_center().x - me.position.x)
				if inward == 0.0:
					inward = 1.0
				var upward: bool = absf(me.velocity.y) > absf(me.velocity.x)
				_di = Vector2(inward, 0.0) if upward else Vector2(inward, -1.0)
			else:
				_di = Vector2(0.0, 0.01)
		input.left = _di.x < 0.0
		input.right = _di.x > 0.0
		input.up = _di.y < -0.5
		return
	_di = Vector2.ZERO
	input.left = me.position.x > stage.get_center().x
	input.right = not input.left
	var ground_below: bool = me.position.x > stage.position.x and me.position.x < stage.end.x
	var close: bool = me.velocity.y > 0.0 and stage.position.y - me.position.y < me.velocity.y * 6.0
	if ground_below and close and _teched_for != me.hitstun_total:
		_teched_for = me.hitstun_total
		if _chance(sim, 5) < p["tech"]:
			input.shield = true
	if level == 3 and me.hitstun * 5 <= me.hitstun_total and me.jumps_left > 0 \
			and _off_stage(me, stage):
		input.up = true


func _choose_throw(me, input, stage: Rect2) -> void:
	var to_edge := signf(me.position.x - stage.get_center().x)
	if to_edge == 0.0:
		to_edge = me.facing
	if level >= 2 and me.mode_ticks > 4:  # Throw toward the nearer edge.
		input.right = to_edge > 0.0
		input.left = to_edge < 0.0


func _on_ledge(sim, me, input) -> void:
	if _ledge_wait < 0:
		_ledge_wait = 6 + int(_chance(sim, 6) * (40.0 if level == 1 else 25.0))
	_ledge_wait -= 1
	if _ledge_wait > 0:
		return
	_ledge_wait = -1
	var toward := 1
	if me.ledge >= 0:
		toward = -int(sim.arena.ledges[me.ledge]["side"])
	var pick := _chance(sim, 7) if level > 1 else 0.0
	if pick < 0.4:
		input.left = toward < 0
		input.right = toward > 0
	elif pick < 0.6:
		input.attack = true
	elif pick < 0.8:
		input.shield = true
	else:
		input.up = true


func _off_stage(me, stage: Rect2) -> bool:
	var over_stage: bool = me.position.x > stage.position.x - 10.0 \
			and me.position.x < stage.end.x + 10.0
	return not over_stage or me.position.y > stage.position.y + 4.0


# Back to the stage: steer in, double jump, the up-air lift, a wall jump, and on hard an air dodge.
func _recover(sim, me, input, stage: Rect2, p: Dictionary) -> void:
	var inward := signf(stage.get_center().x - me.position.x)
	input.left = inward < 0.0
	input.right = inward > 0.0
	var below: float = me.position.y - stage.position.y  # Positive: below the stage top.
	var falling: bool = me.velocity.y > -2.0
	if (falling or me.attack.begins_with("special")) \
			and _recover_with_special(sim, me, input, stage):
		return
	if not falling or me.attack != "":
		return
	var depth := -100.0 if level == 1 else -40.0
	var wall_near: bool = below > 20.0 and (absf(me.position.x - stage.position.x) < 50.0 \
			or absf(me.position.x - stage.end.x) < 50.0)
	# Any wall on the way in (a pillar, too): jump off it.
	var inward_wall: bool = FighterMotion._touching_wall(me, me.stats, sim.arena) \
			== int(signf(stage.get_center().x - me.position.x))
	wall_near = wall_near or inward_wall
	if wall_near and me.wall_jumps_used < me.stats.max_wall_jumps:
		input.up = true
	elif me.jumps_left > 0 and below > depth:
		input.up = true
	elif not me.lift_used and me.stats.lift_ticks > 0 and below > -60.0:
		input.up = true
		input.attack = true
	elif p["air_dodge"] and not me.air_dodge_used and below > 40.0:
		input.shield = true
		input.up = true


# A vent about to burst under it: walk out of it (medium and hard; easy does not look).
func _avoid_hazard(sim, me, input) -> bool:
	if level == 1 or me.mode != Mode.GROUND:
		return false
	var box := FighterMotion.box(me, me.stats)
	if not sim.arena.hazard_warns(box):
		return false
	var stage: Rect2 = sim.arena.solids[0]
	var way := 1 if me.position.x < stage.get_center().x else -1
	if sim.arena.hazard_warns(box.grow_individual(0.0, 0.0, 120.0, 0.0)) \
			and not sim.arena.hazard_warns(box.grow_individual(120.0, 0.0, 0.0, 0.0)):
		way = -1
	input.left = way < 0
	input.right = way > 0
	return true


# Its special used to get back: a dash toward the stage (up and in when below it) or a sideways
# spin when far out. Up is let go on the press and pressed fresh right after, so it aims. Returns
# true while it uses the special.
func _recover_with_special(sim, me, input, stage: Rect2) -> bool:
	var inward := signf(stage.get_center().x - me.position.x)
	if me.attack.begins_with("special"):
		input.left = inward < 0.0
		input.right = inward > 0.0
		if _aim_up and me.attack_ticks <= FighterCombat.AIM_TICKS and not _hold.has("up"):
			input.up = true
			_hold["up"] = FighterCombat.AIM_TICKS
		return true
	var name := FighterCombat.special_for(me, true)
	if name == "" or me.attack != "" or level == 1 and me.jumps_left > 0:
		return false
	var a := FighterCombat.data(me, name)
	if not a.has("move"):
		return false
	var out_x: float = maxf(stage.position.x - me.position.x, me.position.x - stage.end.x)
	var below: float = me.position.y - stage.position.y
	var go := false
	if a["move"].get("fly", false):  # A dash: once the jumps are used, or when far below.
		go = me.jumps_left == 0 and me.velocity.y > 0.0 or below > 160.0
	else:  # A sideways spin: when it is still far out to the side.
		go = out_x > 100.0 and below > -120.0 and me.jumps_left == 0
	if not go:
		return false
	_aim_up = below > -60.0
	_hold.erase("up")
	input.up = false
	input.left = inward < 0.0
	input.right = inward > 0.0
	input.special = true
	return true


# Whether its special fits now against the target: a Spark from a distance it can throw over,
# a Swoop into a target a dash away, a Whirl when one or more fighters are close. Then only at the
# level's chance, so it does not spam.
func _special_fits(sim, me, t: Dictionary, p: Dictionary) -> bool:
	var in_air: bool = me.mode != Mode.GROUND
	var name := FighterCombat.special_for(me, in_air)
	if name == "" or _chance(sim, 15) >= p["special"]:
		return false
	var a := FighterCombat.data(me, name)
	var to: Vector2 = t["position"] - me.position
	var dx := absf(to.x)
	if a.has("shot"):
		return dx > 220.0 and dx < 520.0 and absf(to.y) < 80.0
	if a.has("multi"):
		var close := 0
		for o in _seen_now(sim):
			if not o["out"] and o["position"].distance_to(me.position) < 120.0 \
					and o["position"] != me.position:
				close += 1
		return close >= 1 and dx < 100.0 and absf(to.y) < 90.0 and not in_air
	if a.has("move"):
		return dx > 110.0 and dx < 230.0 and absf(to.y) < 60.0
	return false


# Sees an attack coming its way and picks a defence once for it: shield (or a parry), a spot
# dodge or a roll away. Returns true while it defends.
func _defend(sim, me, input, p: Dictionary) -> bool:
	if me.mode == Mode.SHIELD and input.shield:
		return true
	if me.mode != Mode.GROUND or me.attack != "":
		return false
	var seen := _seen_now(sim)
	for i in seen.size():
		var o: Dictionary = seen[i]
		if i == index or o["out"] or o["attack"] == "" or o["attack"] == "grab":
			continue
		var key := "%d %d" % [i, o["start"]]
		if _answered.has(key):
			continue
		var box := _box_of(o, o["attack"], o["facing"]).grow(30.0)
		if not box.intersects(FighterMotion.box(me, me.stats)):
			continue
		_answered[key] = true
		if _answered.size() > 64:
			_answered.clear()
		var roll := _chance(sim, 8 + i)
		if roll < p["shield"]:
			_hold["shield"] = 14 + int(_chance(sim, 9) * 10.0)
			input.shield = true
			return true
		if roll < p["shield"] + p["dodge"]:
			input.shield = true
			if _chance(sim, 10) < 0.5:
				input.down = true
			else:
				var away := signf(me.position.x - o["position"].x)
				input.left = away < 0.0
				input.right = away >= 0.0
			return true
	return false


# Approach the nearest fighter and attack it with the move that reaches it.
func _fight(sim, me, input, stage: Rect2, p: Dictionary) -> void:
	var t := _target(sim, me)
	if t.is_empty():
		return
	var to: Vector2 = t["position"] - me.position
	var side := 1 if to.x >= 0.0 else -1
	var grounded: bool = me.mode == Mode.GROUND
	if (me.attack == "" and me.lag == 0) and _rest == 0 and _special_fits(sim, me, t, p):
		input.special = true
		input.left = side < 0
		input.right = side > 0
		return
	if (me.attack == "" and me.lag == 0) and _rest == 0:
		var move := _pick_move(sim, me, t, p)
		if move != "":
			_press_move(me, input, move, side)
			_hits_in_row += 1
			if _hits_in_row >= p["combo"]:
				_hits_in_row = 0
				_rest = 30
			return
	if me.attack != "":
		return
	# Keep a little distance while resting, else close in.
	var want := side
	if _rest > 0 and absf(to.x) < 140.0:
		want = -side
	elif absf(to.x) < 30.0:
		want = 0
	input.left = want < 0
	input.right = want > 0
	if grounded and absf(to.x) > 260.0 and level > 1 and _chance(sim, 11) < 0.1:
		input.run = true
	var above: bool = to.y < -110.0 and absf(to.x) < 220.0
	if grounded and above and (p["chase_air"] or t["mode"] == Mode.GROUND) \
			and _chance(sim, 12) < 0.08:
		_hold["up"] = 10
	# Platforms: a target far above gets the double jump at the top of the jump; a target below
	# a thin platform it stands on makes it drop through.
	if not grounded and to.y < -80.0 and absf(to.x) < 260.0 and me.velocity.y > -3.0 \
			and me.jumps_left > 0 and not _last.up:
		input.up = true
	var below: bool = to.y > 100.0 and absf(to.x) < 320.0 and t["mode"] == Mode.GROUND
	if grounded and below and not _last.down and _chance(sim, 16) < 0.1 \
			and FighterMotion._stands_on_thin(me, me.stats, sim.arena):
		input.down = true


func _pick_move(sim, me, t: Dictionary, p: Dictionary) -> String:
	var to: Vector2 = t["position"] - me.position
	var side := 1 if to.x >= 0.0 else -1
	var target_box := Rect2(t["position"] - Vector2(t["stats"].width / 2.0, t["stats"].height),
			Vector2(t["stats"].width, t["stats"].height))
	var grounded: bool = me.mode == Mode.GROUND
	var moves: Array
	if grounded:
		if t["mode"] == Mode.SHIELD and _chance(sim, 13) < p["grab"]:
			moves = ["grab"]
		elif t["damage"] >= p["ko"]:
			moves = ["side", "up", "down", "jab"]
		else:
			moves = ["jab", "down", "up", "side"]
	else:
		if t["damage"] >= p["ko"]:
			moves = ["fair", "bair", "up_air", "nair"]
		else:
			moves = ["nair", "up_air", "fair", "bair", "ground_pound"]
	for move in moves:
		if not FighterCombat.has(me, move):
			continue
		var facing: int = side if move in ["side", "grab", "jab", "dash"] or grounded else me.facing
		if move == "fair" and side != me.facing or move == "bair" and side == me.facing:
			continue
		if move == "ground_pound" and (to.y < 60.0 or level == 1):
			continue
		var reach := _box_of({"position": me.position}, move, facing, me).grow(MOVE_SLACK)
		if reach.intersects(target_box):
			return move
	if p["miss"] > 0.0 and grounded and absf(to.x) < 200.0 and _chance(sim, 14) < p["miss"] * 0.1:
		return "side"
	return ""


func _press_move(me, input, move: String, side: int) -> void:
	input.attack = true
	match move:
		"side", "dash":
			input.left = side < 0
			input.right = side > 0
		"fair":
			input.left = me.facing < 0
			input.right = me.facing > 0
		"bair":
			input.left = me.facing > 0
			input.right = me.facing < 0
		"up", "up_air":
			input.up = true
		"down", "ground_pound":
			input.down = true
		"jab", "nair":
			if me.mode == Mode.GROUND and side != me.facing:
				input.left = side < 0  # Turn first: the side attack.
				input.right = side > 0
		"grab":
			input.shield = true
			_hold["shield"] = 2


# Never walk off the stage: the edge check comes before everything else on the ground.
func _keep_on_stage(me, input, stage: Rect2, p: Dictionary) -> void:
	if me.mode != Mode.GROUND and me.mode != Mode.SHIELD:
		return
	var margin: float = p["edge"]
	if input.left and me.position.x - margin < stage.position.x:
		input.left = false
		input.run = false
	if input.right and me.position.x + margin > stage.end.x:
		input.right = false
		input.run = false


# Attack, jump and shield act on a new press, so a key held from the last tick is let go for one
# tick first.
func _press_fresh(input) -> void:
	for key in ["attack", "special"]:
		if input.get(key) and _last.get(key) and not _hold.has(key):
			input.set(key, false)
	if input.up and _last.up and not _hold.has("up") and not input.attack:
		input.up = false


func _box_of(o: Dictionary, move: String, facing: int, f = null) -> Rect2:
	var stats = f.stats if f != null else o["stats"]
	var box: Rect2 = stats.attacks[move]["box"]
	var x: float = box.position.x if facing > 0 else -box.end.x
	return Rect2(o["position"] + Vector2(x, box.position.y), box.size)


# A number from 0 to 1 that depends only on the seed, the fighter, the tick and the salt.
func _chance(sim, salt: int) -> float:
	return float(absi(hash([seed, index, sim.tick, salt])) % 10000) / 10000.0

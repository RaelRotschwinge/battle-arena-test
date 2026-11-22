# Tests of the fighters and arenas of M4 (game design, "Fighters" and "Arenas"): complete and fair
# move sets, the fighters' own traits, arenas that hold four fighters, the moving platform, and
# computer players that come back to every arena with every fighter.
extends "res://tests/base_test.gd"

const MatchSim := preload("res://scripts/sim/match_sim.gd")
const TestArena := preload("res://arenas/test_arena.gd")
const FighterInput := preload("res://scripts/sim/fighter_input.gd")
const FighterCombat := preload("res://scripts/sim/fighter_combat.gd")
const CpuPlayer := preload("res://scripts/sim/cpu_player.gd")
const Roster := preload("res://fighters/roster.gd")
const ArenaList := preload("res://arenas/arena_list.gd")
const StatSheet := preload("res://fighters/stat_sheet.gd")
const Mode = preload("res://scripts/sim/fighter_state.gd").Mode

const MOVES := ["jab", "side", "up", "down", "dash", "getup", "grab", "nair", "fair", "bair",
		"up_air", "ground_pound", "throw_forward", "throw_back", "throw_up", "throw_down"]
const KO_MOVES := ["side", "up", "fair", "bair"]


func _input(keys: Array) -> FighterInput:
	var input := FighterInput.new()
	for key in keys:
		input.set(key, true)
	return input


func _two(id_a: String, id_b: String) -> MatchSim:
	var sim := MatchSim.new(TestArena.new(), 2, [Roster.make(id_a), Roster.make(id_b)])
	sim.fighters[0].position = Vector2(900.0, 800.0)
	sim.fighters[1].position = Vector2(960.0, 800.0)
	sim.fighters[1].facing = -1
	return sim


func test_every_fighter_has_a_full_and_fair_move_set() -> void:
	for id in Roster.ids():
		var stats := Roster.make(id)
		for move in MOVES:
			assert_true(stats.attacks.has(move), "%s has %s" % [id, move])
		for move in stats.attacks:
			var a: Dictionary = stats.attacks[move]
			if not move.begins_with("throw"):
				assert_true(a["startup"] >= 2, "%s %s: startup at least 2" % [id, move])
		for move in KO_MOVES:
			assert_true(stats.attacks[move]["recovery"] >= 8, "%s %s: a strong attack is not safe"
					% [id, move])


func test_pip_jumps_three_times_in_the_air_and_brum_lifts_less() -> void:
	var sim := MatchSim.new(TestArena.new(), 1, Roster.make("pip"))
	sim.step([_input(["up"])])
	for t in 20:
		sim.step([_input([])])
	assert_eq(sim.fighters[0].jumps_left, 2, "Pip: two jumps in the air")
	for n in 3:
		sim.step([_input(["up"])])
		sim.step([_input([])])
	assert_eq(sim.fighters[0].jumps_left, 0, "both used")
	var brum := MatchSim.new(TestArena.new(), 1, Roster.make("brum"))
	brum.fighters[0].position = Vector2(960.0, 300.0)
	brum.fighters[0].mode = Mode.AIR
	assert_true(brum.fighters[0].stats.lift_ticks < Roster.make("kade").lift_ticks,
			"Brum's up air lifts less long")


func test_pips_neutral_air_hits_three_times() -> void:
	var sim := _two("pip", "brum")
	sim.fighters[0].position = Vector2(930.0, 700.0)
	sim.fighters[0].mode = Mode.AIR
	sim.fighters[1].position = Vector2(960.0, 800.0)
	var hits := 0
	for t in 30:
		sim.step([_input(["attack"] if t == 0 else []), _input([])])
		sim.fighters[0].velocity = Vector2.ZERO  # Hold Pip in place for the test.
		for event in sim.events:
			if event["type"] == "hit" and event["attacker"] == 0:
				hits += 1
	assert_eq(hits, 3, "three hits")
	assert_true(absf(sim.fighters[1].damage - 7.0) < 0.01, "7 % in all")


func test_brums_side_attack_shrugs_off_a_jab_but_not_a_strong_hit() -> void:
	var sim := _two("kade", "brum")
	sim.step([_input([]), _input(["left", "attack"])])
	for t in 3:
		sim.step([_input([]), _input(["left"])])
	sim.step([_input(["attack"]), _input([])])
	for t in 4:
		sim.step([_input([]), _input([])])
	assert_true(sim.fighters[1].damage > 0.0, "the jab dealt damage")
	assert_eq(sim.fighters[1].attack, "side", "Brum keeps attacking")
	var events := []
	sim = _two("kade", "brum")
	sim.fighters[0].damage = 0.0
	sim.step([_input([]), _input(["left", "attack"])])
	for t in 3:
		sim.step([_input([]), _input([])])
	var a := FighterCombat.data(sim.fighters[0], "fair")
	assert_true(not FighterCombat.armored(sim.fighters[1], a), "the forward air (10 %) is light")
	var strong := {"damage": 14.0}
	assert_true(not FighterCombat.armored(sim.fighters[1], strong), "14 % breaks the armor")


func test_every_arena_holds_four_fighters_at_their_spawns() -> void:
	for id in ArenaList.ids():
		var sim := MatchSim.new(ArenaList.make(id), 4)
		for t in 30:
			sim.step([_input([]), _input([]), _input([]), _input([])])
		for f in sim.fighters:
			assert_eq(f.mode, Mode.GROUND, "%s: every fighter stands" % id)
		assert_true(sim.arena.ledges.size() >= 2, "%s: ledges" % id)
		assert_true(sim.arena.blast_zone.encloses(sim.arena.solids[0]), "%s: blast zone" % id)


func test_the_ferry_carries_a_fighter_and_replays_the_same() -> void:
	var sim := MatchSim.new(ArenaList.make("ferry"), 1)
	var f = sim.fighters[0]
	var deck: Rect2 = sim.arena.thin[2]
	f.position = Vector2(deck.get_center().x, deck.position.y - 2.0)
	f.mode = Mode.AIR
	for t in 5:
		sim.step([_input([])])
	assert_eq(f.mode, Mode.GROUND, "stands on the deck")
	var x: float = f.position.x
	var saved := sim.snapshot()
	for t in 60:
		sim.step([_input([])])
	assert_true(absf(f.position.x - x) > 20.0, "carried along")
	assert_eq(f.position.y, sim.arena.thin[2].position.y, "still on the deck")
	var after := sim.snapshot()
	sim.restore(saved)
	for t in 60:
		sim.step([_input([])])
	assert_eq(sim.snapshot(), after, "the same after a restore")


func test_the_windlass_lift_carries_a_fighter_up_and_down() -> void:
	var sim := MatchSim.new(ArenaList.make("windlass"), 1)
	var f = sim.fighters[0]
	var lift: Rect2 = sim.arena.thin[2]
	f.position = Vector2(lift.get_center().x, lift.position.y - 2.0)
	f.mode = Mode.AIR
	for t in 5:
		sim.step([_input([])])
	assert_eq(f.mode, Mode.GROUND, "stands on the lift")
	var lowest: float = f.position.y
	var highest: float = f.position.y
	for t in 840:
		sim.step([_input([])])
		lowest = maxf(lowest, f.position.y)
		highest = minf(highest, f.position.y)
	assert_true(lowest - highest > 250.0, "rode up and down, %.0f px" % (lowest - highest))
	assert_eq(f.position.y, sim.arena.thin[2].position.y, "still on the lift")


# Stands a fighter on Kettle's first vent and waits for its burst.
func _kettle(damage: float, hazards: bool, keys: Array = []) -> MatchSim:
	var arena = ArenaList.make("kettle")
	arena.hazards_on = hazards
	var sim := MatchSim.new(arena, 1, Roster.make("pip"))
	var f = sim.fighters[0]
	f.position = Vector2(arena.VENTS[0], 820.0)
	f.damage = damage
	for t in 480:
		sim.step([_input(keys)])
		if f.mode == Mode.GROUND and absf(f.position.x - arena.VENTS[0]) > 1.0:
			f.position.x = arena.VENTS[0]  # Back onto the vent after landing.
	return sim


func test_kettle_vents_throw_up_but_never_knock_out() -> void:
	var sim := _kettle(0.0, true)
	assert_eq(sim.fighters[0].damage, 6.0, "one burst: 6 %")
	var high := _kettle(300.0, true)
	assert_eq(high.fighters[0].stocks, 3, "even at 300 % a burst does not knock out")
	assert_true(high.fighters[0].damage > 300.0, "it did hit")
	var off := _kettle(0.0, false)
	assert_eq(off.fighters[0].damage, 0.0, "hazards off: the vents stay cold")
	var shield := _kettle(0.0, true, ["shield"])
	assert_eq(shield.fighters[0].damage, 0.0, "a shield takes the burst")


func test_computer_players_come_back_on_every_arena_with_every_fighter() -> void:
	for arena_id in ArenaList.ids():
		var ids := Roster.ids()
		var sim := MatchSim.new(ArenaList.make(arena_id), 3,
				[Roster.make(ids[0]), Roster.make(ids[1]), Roster.make(ids[2])])
		var cpus := [CpuPlayer.new(3, 0, 5), CpuPlayer.new(3, 1, 6), CpuPlayer.new(2, 2, 7)]
		for t in 2400:
			if sim.over:
				break
			sim.step([cpus[0].next_input(sim), cpus[1].next_input(sim), cpus[2].next_input(sim)])
		for i in 3:
			assert_eq(sim.fighters[i].self_destructs, 0, "%s: %s does not fall by itself" % [
					arena_id, ids[i]])


func test_the_stat_sheet_follows_the_data() -> void:
	var expected := {"kade": [3, 3, 3, 4], "pip": [2, 5, 3, 5], "brum": [5, 1, 5, 3]}
	for id in expected:
		assert_eq(StatSheet.pips(Roster.make(id)), expected[id], id)

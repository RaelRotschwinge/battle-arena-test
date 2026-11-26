# Checks the sounds made in code: every effect is made, has sound in it and stays under -1 dBFS,
# and the audio buses the options menu sets exist once however often they are asked for.
extends "res://tests/base_test.gd"

const Sounds := preload("res://scripts/view/sounds.gd")
const Bank := preload("res://scripts/view/sound_bank.gd")
const SoundCues := preload("res://scripts/view/sound_cues.gd")
const MatchSim := preload("res://scripts/sim/match_sim.gd")
const ArenaList := preload("res://arenas/arena_list.gd")
const Roster := preload("res://fighters/roster.gd")
const Mode = preload("res://scripts/sim/fighter_state.gd").Mode


# Stands in for sounds.gd and keeps the names asked for.
class Heard:
	var names := []

	func play(sound: String, _volume_db: float = 0.0, _pitch: float = 1.0) -> void:
		names.append(sound)

	func land(_weight: float, _fall: float) -> void:
		names.append("land")

	func set_intensity(_x: float) -> void:
		pass


# The music's intensity: the top damage of the fighters still in, plus a step for two left and
# one for a last life among them.
func test_intensity_follows_damage_and_the_end() -> void:
	var stats := [Roster.make("kade"), Roster.make("pip"), Roster.make("brum")]
	var sim := MatchSim.new(ArenaList.make("pebble"), 3, stats)
	assert_eq(SoundCues.intensity(sim), 0.0, "three fighters at 0 %")
	sim.fighters[1].damage = 75.0
	assert_eq(SoundCues.intensity(sim), 0.5, "75 % of three fighters")
	sim.fighters[2].out = true
	assert_eq(SoundCues.intensity(sim), 0.5 + SoundCues.STEP, "two left")
	sim.fighters[0].stocks = 1
	assert_eq(SoundCues.intensity(sim), 0.5 + 2.0 * SoundCues.STEP, "two left, a last life")
	sim.fighters[1].damage = 300.0
	assert_eq(SoundCues.intensity(sim), 1.0, "capped")


# Each change of a fighter's state, made by hand between two ticks, asks for its sound.
func test_cues_follow_the_fighters() -> void:
	var sim := MatchSim.new(ArenaList.make("pebble"), 1, [Roster.make("kade")])
	var f = sim.fighters[0]
	var cues := SoundCues.new()
	var heard := Heard.new()
	cues.watch(sim, ["kade"], heard)  # The first look only learns the states.
	var steps := [
		[func(): f.mode = Mode.JUMP_SQUAT, ""], [func(): f.mode = Mode.AIR, "jump"],
		[func(): f.jumps_left -= 1, "double_jump"], [func(): f.mode = Mode.GROUND, "land"],
		[func(): f.mode = Mode.DODGE; f.dodge = "roll", "roll"],
		[func(): f.mode = Mode.LEDGE; f.dodge = "", "ledge"],
		[func(): f.mode = Mode.GROUND; f.attack = "special"; f.attack_ticks = 1,
				"spark_charge"],
		[func(): f.attack_ticks = 11, "spark_zap"],
		[func(): f.attack = ""; f.respawns += 1; f.mode = Mode.RESPAWN; f.mode_ticks = 1, ""],
		[func(): f.mode_ticks = SoundCues.CHIME_TICK, "respawn"],
	]
	for step in steps:
		heard.names.clear()
		step[0].call()
		cues.watch(sim, ["kade"], heard)
		var expected: Array = [] if step[1] == "" else [step[1]]
		assert_eq(heard.names, expected, "after a change toward %s" % step[1])


func test_every_effect_is_made_under_its_ceiling() -> void:
	for sound in Bank.names():
		var wav := Bank.make(sound)
		var top := 0
		for i in wav.data.size() / 2:
			top = maxi(top, absi(wav.data.decode_s16(i * 2)))
		var peak_db := linear_to_db(top / 32768.0)
		assert_true(peak_db < -1.0 and peak_db > -40.0, "%s peaks at %.1f dBFS" % [sound, peak_db])


func test_buses_are_made_once() -> void:
	Sounds.ensure_buses()
	var count := AudioServer.bus_count
	Sounds.ensure_buses()
	assert_eq(AudioServer.bus_count, count, "buses after a second call")
	for bus in ["Music", "SFX"]:
		var at := AudioServer.get_bus_index(bus)
		assert_true(at > 0, "bus %s exists" % bus)
		assert_eq(AudioServer.get_bus_send(at), &"Master", "bus %s sends to" % bus)

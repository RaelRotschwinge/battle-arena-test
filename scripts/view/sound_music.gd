# The music, made in code (sound_score.gd plays it): high-energy electronic dance music. Four on
# the floor kick, claps on 2 and 4, a pumping side-chained bass and chords, sixteenth arpeggios,
# a lead hook and a riser into it, sixteen bars per loop (the hook in bars 9 to 16).
# The match track comes in four tempo tiers (TIER_BPM), each in two layers that play in step:
# "core" always, "energy" (sixteenth hats, percussion, a second arpeggio, bright open chords)
# faded in by the match's intensity. Higher tiers also open the filters. The menu theme uses the
# same sounds, a little lighter. make() returns cache entries: {"music:<name>": stream, ...}.
extends RefCounted

const Synth := preload("res://scripts/view/sound_synth.gd")
const W = Synth.Wave

const RATE := 22050
const PEAK_DB := -10.0  # Both layers together: under the effects.
const STEPS := 16
const BARS := 16
const TIER_BPM := [140.0, 150.0, 160.0, 172.0]
const MENU_BPM := 128.0
# chords: per bar [bass midi, chord notes]; hook: bars of [step, steps long, midi], played in
# bars 9 to 16 with the last bar swapped for "turn" (a rise back into the loop's start).
const SONGS := {
	"match": {"chords": [[45, [57, 60, 64]], [41, [57, 60, 65]], [48, [55, 60, 64]],
			[43, [55, 59, 62]]],
		"hook": [[[0, 2, 76], [3, 2, 76], [6, 2, 81], [8, 2, 79], [10, 3, 76], [14, 2, 74]],
			[[0, 3, 72], [3, 3, 74], [6, 2, 76], [8, 6, 72], [14, 2, 69]],
			[[0, 2, 76], [3, 2, 76], [6, 2, 79], [8, 2, 81], [10, 3, 79], [14, 2, 76]],
			[[0, 3, 74], [3, 3, 71], [6, 4, 67], [10, 2, 71], [12, 4, 74]]],
		"turn": [[0, 2, 74], [2, 2, 76], [4, 2, 79], [6, 2, 83], [8, 8, 81]]},
	"menu": {"chords": [[41, [57, 60, 65]], [43, [55, 59, 62]], [40, [55, 59, 64]],
			[45, [57, 60, 64]]],
		"hook": [[[0, 2, 69], [2, 2, 72], [4, 4, 77], [8, 2, 76], [10, 2, 74], [12, 4, 72]],
			[[0, 2, 71], [2, 2, 74], [4, 4, 79], [8, 4, 77], [12, 4, 74]],
			[[0, 2, 71], [2, 2, 76], [4, 4, 79], [8, 2, 76], [10, 2, 74], [12, 4, 71]],
			[[0, 6, 72], [6, 2, 71], [8, 8, 69]]],
		"turn": [[0, 2, 72], [2, 2, 74], [4, 2, 76], [6, 2, 79], [8, 8, 81]]},
}
const ARP := [0, 2, 1, 3, 0, 2, 1, 3, 0, 2, 1, 3, 2, 1, 3, 2]  # Indexes into chord + octave.


static func names() -> Array:
	return ["menu", "match0", "match1", "match2", "match3", "stinger"]


static func bar_seconds(tier: int) -> float:
	return 240.0 / TIER_BPM[tier]


static func make(track: String) -> Dictionary:
	if track == "menu":
		var menu: Synth = _layers("menu", MENU_BPM, 0, false)[0]
		return {"music:menu": menu.finish(PEAK_DB, true)}
	if track == "stinger":
		return {"music:stinger": _stinger()}
	var tier := int(track.substr(5))
	var layers := _layers("match", TIER_BPM[tier], tier, true)
	var core: Synth = layers[0]
	var energy: Synth = layers[1]
	var top := 0.0
	for i in core.data.size():
		top = maxf(top, absf(core.data[i] + energy.data[i]))
	return {"music:" + track: core.finish(PEAK_DB, true, top),
			"music:" + track + "+": energy.finish(PEAK_DB, true, top)}


# [core, energy (null without)] for one tempo. Parts that repeat are made once and laid in
# again: a bar of drums, four bars of bass, chords and arpeggio.
static func _layers(song_name: String, bpm: float, tier: int, with_energy: bool) -> Array:
	var song: Dictionary = SONGS[song_name]
	var beat := 60.0 / bpm
	var step := beat / 4.0
	var bar := beat * 4.0
	var light := song_name == "menu"
	var core := Synth.new(RATE, bar * BARS + 2.0)  # Two seconds of tail, wrapped to the start.
	var drums := _drum_bar(bar, step, false, light)
	var fill := _drum_bar(bar, step, true, light)
	var pumped := _chord_block(song, bar, step, tier, light)
	var arp := _arp_block(song, bar, step, tier)
	pumped.pump(beat, 0.85, beat * 0.7)
	arp.pump(beat, 0.35, beat * 0.5)
	var riser := _riser(bar * 2.0)
	for b in BARS:
		core.add(fill.data if b % 8 == 7 else drums.data, b * bar)
		if b % 4 == 0:
			core.add(pumped.data, b * bar)
			core.add(arp.data, b * bar)
		if b == 6 or b == 14:
			core.add(riser.data, b * bar)
	for b in [0, 8]:
		_crash(core, b * bar, 0.22)
	var lead_lp := 2600.0 + 900.0 * tier
	for b in range(8, 16):
		var notes: Array = song["turn"] if b == 15 else song["hook"][b % 4]
		for note in notes:
			_lead(core, b * bar + note[0] * step, note[1] * step, note[2], lead_lp,
					0.11 if light else 0.14)
	core.wrap(bar * BARS)
	if not with_energy:
		return [core, null]
	var energy := Synth.new(RATE, bar * BARS + 2.0)
	var perc := _perc_bar(bar, step)
	var sparkle := _sparkle_block(song, bar, step, tier)
	sparkle.pump(beat, 0.5, beat * 0.6)
	var wide := _wide_block(song, bar, tier)
	wide.pump(beat, 0.8, beat * 0.7)
	for b in BARS:
		energy.add(perc.data, b * bar)
		if b % 4 == 0:
			energy.add(sparkle.data, b * bar)
		if b >= 8 and b % 4 == 0:
			energy.add(wide.data, b * bar)
	energy.wrap(bar * BARS)
	return [core, energy]


static func _hz(midi: float) -> float:
	return 440.0 * pow(2.0, (midi - 69.0) / 12.0)


# Kick on every beat, clap on 2 and 4, open hats on the off-beats; a fill bar ends in a snare
# roll that swells into the next bar.
static func _drum_bar(bar: float, step: float, fill: bool, light: bool) -> Synth:
	var d := Synth.new(RATE, bar + 0.5)
	for n in [0, 4, 8, 12]:
		_kick(d, n * step, 0.8 if light else 1.0)
	for n in [4, 12]:
		for flam in 3:  # A clap is a few hands just apart.
			d.noise({"at": n * step + flam * 0.011, "len": 0.03, "filter": "bp", "cut": 1500.0,
					"q": 1.2, "decay": 0.008, "vol": 0.35, "seed": 60 + flam})
		d.noise({"at": n * step + 0.03, "len": 0.2, "filter": "bp", "cut": 1300.0, "q": 0.9,
				"decay": 0.06, "vol": 0.4, "seed": 63})
	for n in [2, 6, 10, 14]:
		d.noise({"at": n * step, "len": 0.12, "filter": "hp", "cut": 7500.0, "decay": 0.05,
				"vol": 0.16, "seed": 64 + n})
	if fill:
		for n in range(8, 16):
			d.noise({"at": n * step, "len": 0.12, "filter": "bp", "cut": 1900.0, "q": 0.8,
					"decay": 0.04, "vol": 0.15 + 0.35 * (n - 8) / 8.0, "seed": 80 + n})
	return d


static func _kick(s, at: float, vol: float) -> void:
	s.tone({"at": at, "len": 0.32, "hz": 160.0, "to": 46.0, "sweep": 0.028, "decay": 0.11,
			"vol": vol})
	s.noise({"at": at, "len": 0.012, "filter": "hp", "cut": 2500.0, "decay": 0.003,
			"vol": vol * 0.5, "seed": 66})


static func _crash(s, at: float, vol: float) -> void:
	s.noise({"at": at, "len": 1.4, "filter": "hp", "cut": 5500.0, "decay": 0.45, "vol": vol,
			"seed": 67})


# Four bars of a rolling sixteenth bass (a saw and a sub an octave down) and held saw chords,
# pumped afterwards.
static func _chord_block(song: Dictionary, bar: float, step: float, tier: int,
		light: bool) -> Synth:
	var s := Synth.new(RATE, bar * 4.0 + 0.4)
	var bass_lp := 650.0 + 160.0 * tier
	for b in 4:
		var chord: Array = song["chords"][b]
		var root: int = chord[0]
		for n in STEPS:
			var midi := root + (12 if n == 6 or n == 14 else 0)
			var at := b * bar + n * step
			s.tone({"at": at, "len": step * 0.9, "hz": _hz(midi), "wave": W.SAW, "lp": bass_lp,
					"decay": step * 1.5, "vol": 0.3})
			s.tone({"at": at, "len": step * 0.9, "hz": _hz(midi - 12), "decay": step * 2.0,
					"vol": 0.35})
		for note in chord[1]:
			for detune in [0.996, 1.004]:
				s.tone({"at": b * bar, "len": bar, "hz": _hz(note) * detune, "wave": W.SAW,
						"lp": 1800.0 + 500.0 * tier, "attack": 0.01, "vol": 0.05 if light else 0.06})
	return s


# Four bars of sixteenth plucks up and down the chord.
static func _arp_block(song: Dictionary, bar: float, step: float, tier: int) -> Synth:
	var s := Synth.new(RATE, bar * 4.0 + 0.4)
	for b in 4:
		var notes: Array = song["chords"][b][1]
		for n in STEPS:
			var i: int = ARP[n]
			var midi: int = (notes[0] + 12 if i == 3 else notes[i]) + 12
			s.tone({"at": b * bar + n * step, "len": 0.16, "hz": _hz(midi), "wave": W.SAW,
					"lp": 2400.0 + 800.0 * tier, "decay": 0.06, "vol": 0.1})
	return s


# The energy layer's bar: closed hats on every sixteenth, a rim and a tom off the beat.
static func _perc_bar(bar: float, step: float) -> Synth:
	var d := Synth.new(RATE, bar + 0.3)
	for n in STEPS:
		d.noise({"at": n * step, "len": 0.04, "filter": "hp", "cut": 9000.0, "decay": 0.012,
				"vol": 0.17 if n % 2 == 1 else 0.1, "seed": 90 + n})
	for n in [3, 7, 11, 13]:
		d.tone({"at": n * step, "len": 0.05, "hz": 820.0, "to": 640.0, "sweep": 0.01,
				"decay": 0.015, "vol": 0.3, "wave": W.TRIANGLE})
	for n in [10, 15]:
		d.tone({"at": n * step, "len": 0.2, "hz": 230.0, "to": 150.0, "sweep": 0.04,
				"decay": 0.07, "vol": 0.45})
	return d


# The energy layer's second arpeggio: square plucks two octaves up on the off-sixteenths.
static func _sparkle_block(song: Dictionary, bar: float, step: float, tier: int) -> Synth:
	var s := Synth.new(RATE, bar * 4.0 + 0.4)
	for b in 4:
		var notes: Array = song["chords"][b][1]
		for n in range(1, STEPS, 2):
			s.tone({"at": b * bar + n * step, "len": 0.1, "hz": _hz(notes[(n / 2) % 3] + 24),
					"wave": W.SQUARE, "lp": 3500.0 + 1000.0 * tier, "decay": 0.04, "vol": 0.11})
	return s


# The energy layer's bright, open chords an octave up, for the hook bars.
static func _wide_block(song: Dictionary, bar: float, tier: int) -> Synth:
	var s := Synth.new(RATE, bar * 4.0 + 0.4)
	for b in 4:
		for note in song["chords"][b][1]:
			for detune in [0.993, 1.0, 1.007]:
				s.tone({"at": b * bar, "len": bar, "hz": _hz(note + 12) * detune, "wave": W.SAW,
						"lp": 4500.0 + 1000.0 * tier, "attack": 0.01, "vol": 0.06})
	return s


# Two bars of rising noise and pitch into the hook.
static func _riser(seconds: float) -> Synth:
	var s := Synth.new(RATE, seconds)
	s.noise({"len": seconds, "filter": "bp", "cut": 400.0, "to": 7000.0, "q": 1.4,
			"attack": seconds * 0.9, "vol": 0.25, "seed": 68})
	s.tone({"len": seconds, "hz": 200.0, "to": 1600.0, "attack": seconds * 0.9, "vol": 0.05,
			"wave": W.SAW, "lp": 4000.0})
	return s


static func _lead(s, at: float, seconds: float, midi: int, lp: float, vol: float) -> void:
	for detune in [0.995, 1.005]:
		s.tone({"at": at, "len": seconds * 0.92, "hz": _hz(midi) * detune, "wave": W.SAW,
				"lp": lp, "attack": 0.005, "decay": maxf(seconds * 2.0, 0.2), "vol": vol,
				"vib": 0.004, "vib_hz": 6.0})
	s.tone({"at": at, "len": seconds * 0.92, "hz": _hz(midi - 12), "wave": W.SQUARE,
			"lp": lp * 0.5, "attack": 0.005, "decay": maxf(seconds, 0.15), "vol": vol * 0.4})


# The final knockout: a kick, a crash, a wide A minor chord and a run up three octaves.
static func _stinger() -> AudioStreamWAV:
	var s := Synth.new(RATE, 2.6)
	_kick(s, 0.0, 1.0)
	_crash(s, 0.0, 0.4)
	s.tone({"len": 1.2, "hz": 110.0, "to": 40.0, "sweep": 0.3, "decay": 0.4, "vol": 0.6})
	for note in [57, 60, 64, 69, 72]:
		for detune in [0.994, 1.006]:
			s.tone({"len": 2.5, "hz": _hz(note) * detune, "wave": W.SAW, "lp": 5000.0,
					"decay": 0.8, "vol": 0.06})
	var run := [69, 72, 76, 81, 84, 88, 93, 96]
	for n in run.size():
		s.tone({"at": n * 0.045, "len": 0.25 if n < run.size() - 1 else 1.4, "hz": _hz(run[n]),
				"wave": W.TRIANGLE, "decay": 0.08 if n < run.size() - 1 else 0.5, "vol": 0.25})
	return s.finish(-6.0)

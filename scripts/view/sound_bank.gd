# The recipes of every sound effect (sounds.gd plays them): layers of tones, noise and FM bells
# made with sound_synth.gd. SPECS holds each sound's length and its peak in dBFS, which sets the
# mix: hits and stings loudest, movement quieter, menu ticks quietest. Everything stays under
# -1 dBFS, so a sound at full volume does not clip on its own.
extends RefCounted

const Synth := preload("res://scripts/view/sound_synth.gd")
const W = Synth.Wave

const RATE := 32000
# name -> [seconds, peak dBFS]. Listed by how soon they are needed: menu sounds first.
const SPECS := {
	"tick": [0.05, -17.0], "confirm": [0.3, -10.0], "back": [0.2, -12.0],
	"wipe": [0.45, -14.0], "join": [0.4, -10.0], "lock": [0.14, -12.0], "ready": [0.6, -9.0],
	"arena": [0.25, -13.0],
	"hit_light": [0.2, -7.0], "hit_medium": [0.32, -5.0], "hit_heavy": [0.55, -3.0],
	"hit_smash": [0.95, -2.0], "block": [0.24, -6.0], "parry": [0.9, -5.0],
	"break": [1.0, -3.0], "grab": [0.22, -7.0], "armor": [0.5, -5.0], "clank": [0.45, -6.0],
	"ko": [1.7, -1.5], "steam": [1.0, -9.0],
	"spark_charge": [0.24, -11.0], "spark_zap": [0.36, -7.0], "swoop": [0.45, -8.0],
	"whirl": [0.62, -8.0], "special": [0.28, -9.0],
	"jump": [0.17, -14.0], "double_jump": [0.24, -13.0], "land": [0.2, -11.0],
	"dodge": [0.26, -13.0], "roll": [0.36, -13.0], "ledge": [0.16, -10.0],
	"respawn": [1.1, -10.0], "step": [0.06, -24.0],
	"go": [1.1, -2.5], "game": [1.8, -2.0], "victory": [2.6, -3.5],
}


static func names() -> Array:
	return SPECS.keys()


static func make(sound: String) -> AudioStreamWAV:
	var spec: Array = SPECS[sound]
	var s := Synth.new(RATE, spec[0])
	_voices(sound, s)
	return s.finish(spec[1])


static func _voices(sound: String, s) -> void:
	match sound:
		# Menus: short, soft, pitched.
		"tick":
			s.tone({"len": 0.04, "hz": 2200.0, "decay": 0.008, "vol": 0.6, "wave": W.TRIANGLE})
			s.noise({"len": 0.01, "filter": "hp", "cut": 5000.0, "decay": 0.002, "vol": 0.3})
		"confirm":
			s.tone({"len": 0.07, "hz": 880.0, "decay": 0.04, "vol": 0.5, "wave": W.TRIANGLE})
			s.tone({"at": 0.06, "len": 0.22, "hz": 1318.5, "decay": 0.07, "vol": 0.6,
					"wave": W.TRIANGLE})
			s.fm({"at": 0.06, "len": 0.22, "hz": 2637.0, "ratio": 2.0, "index": 1.0,
					"decay": 0.06, "vol": 0.15})
		"back":
			s.tone({"len": 0.07, "hz": 880.0, "decay": 0.04, "vol": 0.5, "wave": W.TRIANGLE})
			s.tone({"at": 0.06, "len": 0.13, "hz": 587.3, "to": 520.0, "decay": 0.05, "vol": 0.6,
					"wave": W.TRIANGLE})
		"wipe":
			s.noise({"len": 0.45, "filter": "bp", "cut": 300.0, "to": 2800.0, "q": 1.3,
					"attack": 0.12, "decay": 0.12, "vol": 0.7})
			s.noise({"at": 0.1, "len": 0.3, "filter": "bp", "cut": 2500.0, "to": 900.0, "q": 1.0,
					"attack": 0.05, "decay": 0.08, "vol": 0.3, "seed": 3})
		"join":
			for n in 3:
				s.tone({"at": n * 0.06, "len": 0.2, "hz": [783.99, 1046.5, 1318.5][n], "decay": 0.06,
						"vol": 0.45, "wave": W.TRIANGLE})
			s.noise({"len": 0.25, "filter": "bp", "cut": 800.0, "to": 4000.0, "q": 1.5,
					"attack": 0.05, "decay": 0.08, "vol": 0.25})
		"lock":
			s.noise({"len": 0.012, "filter": "hp", "cut": 2500.0, "decay": 0.003, "vol": 0.8})
			s.tone({"len": 0.05, "hz": 420.0, "to": 300.0, "sweep": 0.01, "decay": 0.015,
					"vol": 0.5, "wave": W.SQUARE, "lp": 2500.0})
			s.noise({"at": 0.045, "len": 0.02, "filter": "bp", "cut": 3500.0, "q": 2.0,
					"decay": 0.005, "vol": 0.9, "seed": 2})
		"ready":
			_chord(s, 0.0, [523.25, 659.25, 783.99, 1046.5], 0.5, 0.18, 0.16, 3000.0)
			s.fm({"len": 0.6, "hz": 2093.0, "ratio": 3.5, "index": 1.4, "index_decay": 0.1,
					"decay": 0.2, "vol": 0.3})
			_thump(s, 0.0, 150.0, 60.0, 0.06, 0.5)
		"arena":
			s.tone({"len": 0.1, "hz": 660.0, "to": 990.0, "decay": 0.05, "vol": 0.5,
					"wave": W.TRIANGLE})
			_thump(s, 0.0, 180.0, 70.0, 0.03, 0.4)
			s.noise({"len": 0.2, "filter": "hp", "cut": 5000.0, "attack": 0.02, "decay": 0.05,
					"vol": 0.15})
		# Hits: a click, a pitched body, a crunch, and from medium on a sub thump; drive glues them.
		"hit_light":
			_click(s, 0.6)
			s.tone({"len": 0.09, "hz": 560.0, "to": 210.0, "sweep": 0.015, "decay": 0.03,
					"vol": 0.6, "wave": W.TRIANGLE})
			s.noise({"len": 0.08, "filter": "bp", "cut": 2600.0, "q": 1.2, "decay": 0.022,
					"vol": 0.6, "seed": 5})
			s.drive(1.4)
		"hit_medium":
			_click(s, 0.7)
			s.tone({"len": 0.16, "hz": 320.0, "to": 100.0, "sweep": 0.022, "decay": 0.055,
					"vol": 0.8})
			s.noise({"len": 0.14, "filter": "bp", "cut": 1700.0, "to": 900.0, "q": 1.1,
					"decay": 0.045, "vol": 0.7, "seed": 6})
			_thump(s, 0.0, 150.0, 58.0, 0.08, 0.6)
			s.drive(1.8)
		"hit_heavy":
			_click(s, 0.8)
			s.noise({"len": 0.04, "filter": "hp", "cut": 1500.0, "decay": 0.014, "vol": 0.8,
					"seed": 7})
			s.tone({"len": 0.28, "hz": 240.0, "to": 70.0, "sweep": 0.03, "decay": 0.09,
					"vol": 0.8})
			s.noise({"len": 0.25, "filter": "bp", "cut": 1200.0, "to": 450.0, "q": 1.0,
					"decay": 0.07, "vol": 0.7, "seed": 8})
			_thump(s, 0.0, 100.0, 42.0, 0.18, 1.0)
			s.drive(2.2)
		"hit_smash":
			_click(s, 1.0)
			s.noise({"len": 0.06, "filter": "hp", "cut": 1200.0, "decay": 0.02, "vol": 1.0,
					"seed": 9})
			s.tone({"len": 0.4, "hz": 200.0, "to": 52.0, "sweep": 0.04, "decay": 0.12,
					"vol": 0.8})
			s.noise({"len": 0.8, "filter": "lp", "cut": 3500.0, "to": 140.0, "decay": 0.22,
					"vol": 0.6, "seed": 10})
			_thump(s, 0.0, 85.0, 32.0, 0.32, 1.1)
			s.fm({"len": 0.5, "hz": 1180.0, "ratio": 1.41, "index": 2.5, "index_decay": 0.04,
					"decay": 0.12, "vol": 0.12})
			s.drive(2.5)
		# Defense: a shield thunks, a parry rings bright, a breaking shield shatters.
		"block":
			s.tone({"len": 0.12, "hz": 620.0, "to": 380.0, "sweep": 0.02, "decay": 0.035,
					"vol": 0.5, "wave": W.TRIANGLE})
			s.fm({"len": 0.2, "hz": 1240.0, "ratio": 2.0, "index": 1.2, "index_decay": 0.03,
					"decay": 0.05, "vol": 0.25})
			s.noise({"len": 0.08, "filter": "bp", "cut": 900.0, "q": 1.0, "decay": 0.025,
					"vol": 0.5, "seed": 11})
			_thump(s, 0.0, 130.0, 80.0, 0.03, 0.35)
		"parry":
			_click(s, 0.5)
			s.fm({"len": 0.9, "hz": 1568.0, "ratio": 3.5, "index": 2.5, "index_decay": 0.12,
					"decay": 0.3, "vol": 0.55})
			s.tone({"len": 0.8, "hz": 2349.3, "decay": 0.28, "vol": 0.22})
			s.tone({"len": 0.6, "hz": 3136.0, "decay": 0.18, "vol": 0.16})
			s.tone({"at": 0.02, "len": 0.16, "hz": 2000.0, "to": 4200.0, "decay": 0.08,
					"vol": 0.1, "wave": W.TRIANGLE})
		"break":
			s.noise({"len": 0.08, "filter": "bp", "cut": 1300.0, "q": 0.9, "decay": 0.03,
					"vol": 0.9, "seed": 12})
			s.noise({"len": 0.7, "filter": "hp", "cut": 2600.0, "attack": 0.005, "decay": 0.17,
					"vol": 0.45, "seed": 13})
			_thump(s, 0.0, 220.0, 55.0, 0.24, 0.8)
			var rng := RandomNumberGenerator.new()
			rng.seed = 21  # Fixed: the same shards every start.
			for n in 16:
				s.fm({"at": rng.randf() * 0.35, "len": 0.25, "hz": rng.randf_range(2000.0, 5200.0),
						"ratio": 1.41, "index": 1.6, "index_decay": 0.02,
						"decay": rng.randf_range(0.03, 0.08), "vol": 0.22})
			s.drive(1.6)
		"grab":
			_click(s, 0.4)
			s.noise({"len": 0.18, "filter": "lp", "cut": 900.0, "to": 250.0, "attack": 0.006,
					"decay": 0.05, "vol": 0.8, "seed": 14})
			_thump(s, 0.0, 170.0, 90.0, 0.05, 0.6)
		"armor":
			_thump(s, 0.0, 210.0, 80.0, 0.06, 0.6)
			s.fm({"len": 0.5, "hz": 2100.0, "ratio": 1.41, "index": 3.0, "index_decay": 0.05,
					"decay": 0.17, "vol": 0.45})
			s.fm({"at": 0.01, "len": 0.4, "hz": 3300.0, "ratio": 2.76, "index": 1.5,
					"index_decay": 0.04, "decay": 0.11, "vol": 0.22})
		"clank":
			s.fm({"len": 0.45, "hz": 910.0, "ratio": 1.41, "index": 4.0, "index_decay": 0.04,
					"decay": 0.12, "vol": 0.5})
			s.fm({"len": 0.4, "hz": 1370.0, "ratio": 2.2, "index": 2.0, "index_decay": 0.04,
					"decay": 0.09, "vol": 0.4})
			s.noise({"len": 0.06, "filter": "bp", "cut": 3000.0, "q": 2.0, "decay": 0.015,
					"vol": 0.6, "seed": 15})
		"ko":
			_click(s, 1.0)
			s.noise({"len": 0.08, "filter": "hp", "cut": 1000.0, "decay": 0.03, "vol": 1.0,
					"seed": 16})
			s.tone({"len": 0.5, "hz": 170.0, "to": 48.0, "sweep": 0.05, "decay": 0.15,
					"vol": 0.8})
			_thump(s, 0.0, 72.0, 27.0, 0.5, 1.2)
			s.noise({"len": 1.2, "filter": "lp", "cut": 3000.0, "to": 110.0, "decay": 0.4,
					"vol": 0.7, "seed": 17})
			# The whoosh of the fighter flying off, rising into the distance.
			s.noise({"at": 0.12, "len": 1.5, "filter": "bp", "cut": 500.0, "to": 2600.0, "q": 1.6,
					"attack": 0.25, "decay": 0.45, "vol": 0.45, "seed": 18})
			s.drive(2.0)
		"steam":
			s.noise({"len": 0.3, "filter": "lp", "cut": 420.0, "to": 140.0, "attack": 0.01,
					"decay": 0.12, "vol": 0.7, "seed": 19})
			s.noise({"len": 1.0, "filter": "hp", "cut": 3200.0, "attack": 0.03, "decay": 0.42,
					"vol": 0.55, "seed": 20})
			s.noise({"len": 0.8, "filter": "bp", "cut": 5200.0, "to": 2400.0, "q": 1.0,
					"attack": 0.02, "decay": 0.3, "vol": 0.3, "seed": 22})
		# Specials, one per fighter.
		"spark_charge":
			s.tone({"len": 0.24, "hz": 300.0, "to": 1400.0, "attack": 0.03, "vol": 0.3,
					"wave": W.SAW, "lp": 3000.0, "vib": 0.02, "vib_hz": 30.0})
			s.tone({"len": 0.24, "hz": 600.0, "to": 2800.0, "attack": 0.03, "vol": 0.18})
			s.noise({"len": 0.24, "filter": "bp", "cut": 4000.0, "q": 3.0, "attack": 0.05,
					"vol": 0.25, "trem": 0.8, "trem_hz": 55.0, "seed": 23})
		"spark_zap":
			s.tone({"len": 0.13, "hz": 1800.0, "to": 180.0, "decay": 0.06, "vol": 0.4,
					"wave": W.SQUARE, "lp": 5000.0})
			s.noise({"len": 0.2, "filter": "bp", "cut": 3200.0, "to": 800.0, "q": 1.2,
					"decay": 0.05, "vol": 0.55, "seed": 24})
			s.fm({"len": 0.36, "hz": 1200.0, "ratio": 3.3, "index": 4.0, "index_decay": 0.03,
					"decay": 0.08, "vol": 0.3})
		"swoop":
			s.noise({"len": 0.45, "filter": "bp", "cut": 500.0, "to": 3000.0, "q": 1.8,
					"attack": 0.12, "decay": 0.14, "vol": 0.85, "seed": 25})
			s.noise({"len": 0.4, "filter": "bp", "cut": 900.0, "to": 4500.0, "q": 3.0,
					"attack": 0.1, "decay": 0.12, "vol": 0.25, "seed": 26})
		"whirl":
			s.noise({"len": 0.62, "filter": "bp", "cut": 700.0, "to": 1500.0, "q": 2.0,
					"attack": 0.06, "decay": 0.4, "vol": 0.85, "trem": 0.85, "trem_hz": 13.0,
					"seed": 27})
			s.tone({"len": 0.6, "hz": 140.0, "to": 190.0, "attack": 0.05, "decay": 0.35,
					"vol": 0.25, "wave": W.TRIANGLE, "trem": 0.6, "trem_hz": 13.0})
		"special":
			s.noise({"len": 0.28, "filter": "bp", "cut": 600.0, "to": 2500.0, "q": 1.5,
					"attack": 0.04, "decay": 0.1, "vol": 0.6, "seed": 28})
			s.tone({"len": 0.16, "hz": 500.0, "to": 1200.0, "decay": 0.08, "vol": 0.3,
					"wave": W.TRIANGLE})
		# Movement: airy and quiet, so a busy match does not turn into noise.
		"jump":
			s.noise({"len": 0.17, "filter": "bp", "cut": 400.0, "to": 1900.0, "q": 1.2,
					"attack": 0.01, "decay": 0.05, "vol": 0.6, "seed": 29})
			s.tone({"len": 0.07, "hz": 220.0, "to": 420.0, "decay": 0.03, "vol": 0.25})
		"double_jump":
			s.noise({"len": 0.24, "filter": "bp", "cut": 800.0, "to": 3200.0, "q": 1.5,
					"attack": 0.01, "decay": 0.06, "vol": 0.5, "seed": 30})
			s.tone({"len": 0.11, "hz": 500.0, "to": 950.0, "decay": 0.05, "vol": 0.25,
					"wave": W.TRIANGLE})
		"land":
			s.noise({"len": 0.18, "filter": "lp", "cut": 550.0, "to": 150.0, "decay": 0.04,
					"vol": 0.8, "seed": 31})
			_thump(s, 0.0, 125.0, 58.0, 0.05, 0.7)
		"dodge":
			s.noise({"len": 0.26, "filter": "bp", "cut": 1500.0, "to": 4200.0, "q": 1.0,
					"attack": 0.04, "decay": 0.07, "vol": 0.6, "seed": 32})
		"roll":
			s.noise({"len": 0.36, "filter": "bp", "cut": 600.0, "to": 2200.0, "q": 0.9,
					"attack": 0.06, "decay": 0.12, "vol": 0.6, "seed": 33})
			s.noise({"len": 0.3, "filter": "lp", "cut": 300.0, "attack": 0.03, "decay": 0.1,
					"vol": 0.4, "seed": 34})
		"ledge":
			s.noise({"len": 0.02, "filter": "hp", "cut": 2000.0, "decay": 0.006, "vol": 0.6,
					"seed": 35})
			s.tone({"len": 0.06, "hz": 720.0, "to": 500.0, "sweep": 0.01, "decay": 0.02,
					"vol": 0.4, "wave": W.TRIANGLE})
			s.noise({"len": 0.12, "filter": "lp", "cut": 650.0, "decay": 0.03, "vol": 0.45,
					"seed": 36})
		"respawn":
			for n in 4:
				s.fm({"at": n * 0.07, "len": 0.8, "hz": [1046.5, 1318.5, 1568.0, 2093.0][n],
						"ratio": 3.5, "index": 1.1, "index_decay": 0.1, "decay": 0.3, "vol": 0.32})
			s.noise({"len": 1.0, "filter": "hp", "cut": 6000.0, "attack": 0.2, "decay": 0.3,
					"vol": 0.08, "seed": 37})
		"step":
			s.noise({"len": 0.05, "filter": "lp", "cut": 1300.0, "decay": 0.012, "vol": 0.6,
					"seed": 38})
			s.tone({"len": 0.04, "hz": 190.0, "to": 100.0, "sweep": 0.01, "decay": 0.012,
					"vol": 0.4})
		# Match flow: stings in the key of the music around them.
		"go":
			_kick(s, 0.0, 1.0)
			_snare(s, 0.0, 0.7)
			_chord(s, 0.0, [392.0, 493.88, 587.33, 783.99], 0.9, 0.3, 0.2, 2600.0)
			_crash(s, 0.0, 0.35)
			s.drive(1.6)
		"game":
			_kick(s, 0.0, 0.8)
			_chord(s, 0.0, [261.63, 392.0, 523.25], 0.16, 0.08, 0.18, 2200.0)
			_kick(s, 0.18, 1.1)
			_snare(s, 0.18, 0.8)
			_chord(s, 0.18, [196.0, 261.63, 329.63, 392.0, 523.25], 1.5, 0.55, 0.2, 2400.0)
			_thump(s, 0.18, 70.0, 30.0, 0.4, 0.9)
			_crash(s, 0.18, 0.4)
			s.drive(1.6)
		"victory":
			var notes := [523.25, 659.25, 783.99, 1046.5, 783.99, 1046.5]
			var starts := [0.0, 0.12, 0.24, 0.36, 0.6, 0.72]
			for n in notes.size():
				var last: bool = n == notes.size() - 1
				s.tone({"at": starts[n], "len": 1.6 if last else 0.2, "hz": notes[n],
						"decay": 0.6 if last else 0.09, "vol": 0.3, "wave": W.SQUARE, "lp": 3200.0,
						"vib": 0.006 if last else 0.0, "vib_hz": 5.5})
			_chord(s, 0.72, [261.63, 329.63, 392.0, 523.25], 1.8, 0.7, 0.13, 2000.0)
			s.tone({"at": 0.72, "len": 1.8, "hz": 130.81, "decay": 0.7, "vol": 0.45,
					"wave": W.TRIANGLE})
			_kick(s, 0.72, 0.8)
			_crash(s, 0.72, 0.25)
			s.fm({"at": 0.72, "len": 1.5, "hz": 2093.0, "ratio": 3.5, "index": 1.2,
					"decay": 0.4, "vol": 0.18})


# The bright edge every hit starts with.
static func _click(s, vol: float) -> void:
	s.noise({"len": 0.012, "filter": "hp", "cut": 3500.0, "decay": 0.003, "vol": vol,
			"seed": 40})


# A low sine that drops in pitch: the weight of a hit or a landing.
static func _thump(s, at: float, hz: float, to: float, decay: float, vol: float) -> void:
	s.tone({"at": at, "len": decay * 4.0, "hz": hz, "to": to, "sweep": decay * 0.4,
			"decay": decay, "vol": vol})


static func _kick(s, at: float, vol: float) -> void:
	s.tone({"at": at, "len": 0.4, "hz": 140.0, "to": 45.0, "sweep": 0.03, "decay": 0.12,
			"vol": vol})
	s.noise({"at": at, "len": 0.01, "filter": "hp", "cut": 3000.0, "decay": 0.003,
			"vol": vol * 0.4, "seed": 41})


static func _snare(s, at: float, vol: float) -> void:
	s.noise({"at": at, "len": 0.25, "filter": "bp", "cut": 1900.0, "q": 0.8, "decay": 0.07,
			"vol": vol, "seed": 42})
	s.tone({"at": at, "len": 0.12, "hz": 230.0, "to": 180.0, "sweep": 0.02, "decay": 0.04,
			"vol": vol * 0.6, "wave": W.TRIANGLE})


static func _crash(s, at: float, vol: float) -> void:
	s.noise({"at": at, "len": 1.2, "filter": "hp", "cut": 5000.0, "decay": 0.35, "vol": vol,
			"seed": 43})


# Detuned saw pairs under a low pass: a bright brass-like stab.
static func _chord(s, at: float, notes: Array, seconds: float, decay: float, vol: float,
		lp: float) -> void:
	for hz in notes:
		for detune in [0.997, 1.003]:
			s.tone({"at": at, "len": seconds, "hz": hz * detune, "decay": decay, "vol": vol * 0.5,
					"wave": W.SAW, "lp": lp, "attack": 0.004})

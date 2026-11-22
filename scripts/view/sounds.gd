# A few simple sounds and a short music loop, all made in code at start (game design, "Sound"):
# no sound files. play(name, strength) plays one; free sound packs may replace them later.
extends Node

const RATE := 22050
const VOICES := 8  # Sounds that can play at the same time.
const MUSIC_VOLUME_DB := -14.0

static var _cache := {}  # name -> AudioStreamWAV, made once.

var music_on := true
var _players := []
var _next := 0
var _music: AudioStreamPlayer


func _ready() -> void:
	for n in VOICES:
		var player := AudioStreamPlayer.new()
		add_child(player)
		_players.append(player)
	_music = AudioStreamPlayer.new()
	_music.volume_db = MUSIC_VOLUME_DB
	add_child(_music)
	if music_on:
		_music.stream = _sound("music")
		_music.play()


func play(name: String, strength: float = 10.0) -> void:
	var player: AudioStreamPlayer = _players[_next]
	_next = (_next + 1) % VOICES
	player.stream = _sound(name)
	player.volume_db = -6.0
	player.pitch_scale = 1.0
	if name == "hit":  # Stronger hits sound lower and louder.
		player.pitch_scale = clampf(1.4 - strength / 40.0, 0.6, 1.4)
		player.volume_db = clampf(-12.0 + strength * 0.4, -12.0, 0.0)
	player.play()


static func _sound(name: String) -> AudioStreamWAV:
	if not _cache.has(name):
		_cache[name] = _make(name)
	return _cache[name]


static func _make(name: String) -> AudioStreamWAV:
	var samples := PackedFloat32Array()
	match name:
		"hit":
			samples = _mix([_noise(0.09, 0.9, 7), _tone(110.0, 0.12, 0.8, 0.0)])
		"block":
			samples = _mix([_tone(880.0, 0.06, 0.5, 0.0), _noise(0.03, 0.4, 3)])
		"parry":
			samples = _mix([_tone(1320.0, 0.18, 0.6, 0.0), _tone(1980.0, 0.14, 0.3, 0.0)])
		"break":
			samples = _mix([_noise(0.3, 0.8, 11), _tone(660.0, 0.3, 0.4, -600.0)])
		"grab":
			samples = _tone(220.0, 0.08, 0.5, 120.0)
		"special":
			samples = _mix([_tone(520.0, 0.14, 0.45, 900.0), _noise(0.06, 0.2, 5)])
		"steam":
			samples = _mix([_noise(0.45, 0.5, 17), _tone(180.0, 0.3, 0.25, 60.0)])
		"ko":
			samples = _mix([_noise(0.5, 0.9, 13), _tone(70.0, 0.6, 1.0, -30.0)])
		"win":
			samples = _melody([523.3, 659.3, 784.0, 1046.5], 0.12, 0.5)
		"music":
			samples = _music_loop()
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.data = data
	if name == "music":
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_end = samples.size()
	return stream


# A tone that fades out; slide changes its pitch per second.
static func _tone(hz: float, seconds: float, volume: float, slide: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var count := int(seconds * RATE)
	out.resize(count)
	var phase := 0.0
	for i in count:
		var t := float(i) / RATE
		phase += (hz + slide * t) / RATE
		var fade := pow(1.0 - float(i) / count, 2.0)
		out[i] = sin(TAU * phase) * volume * fade
	return out


# Noise from a fixed sequence (no random numbers needed), fading out.
static func _noise(seconds: float, volume: float, salt: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var count := int(seconds * RATE)
	out.resize(count)
	var value := salt * 7919 + 1
	var low := 0.0
	for i in count:
		value = (value * 1103515245 + 12345) % 2147483648
		var white := float(value) / 1073741824.0 - 1.0
		low = lerpf(low, white, 0.35)
		out[i] = low * volume * pow(1.0 - float(i) / count, 3.0)
	return out


static func _mix(parts: Array) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for part in parts:
		if part.size() > out.size():
			out.resize(part.size())
	for part in parts:
		for i in part.size():
			out[i] += part[i]
	return out


static func _melody(notes: Array, step: float, volume: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for n in notes.size():
		var note := _tone(notes[n], step * (2.0 if n == notes.size() - 1 else 1.2), volume, 0.0)
		var start := int(n * step * RATE)
		if out.size() < start + note.size():
			out.resize(start + note.size())
		for i in note.size():
			out[start + i] += note[i]
	return out


# Eight bars of a calm bass line and a light arpeggio over four chords, looping.
static func _music_loop() -> PackedFloat32Array:
	var beat := 0.25  # Seconds per eighth note, 120 beats per minute.
	var chords := [[110.0, 220.0, 261.6, 329.6], [87.3, 174.6, 220.0, 261.6],
			[130.8, 196.0, 261.6, 329.6], [98.0, 196.0, 246.9, 293.7]]
	var out := PackedFloat32Array()
	out.resize(int(beat * 8 * 8 * RATE))
	for bar in 8:
		var chord: Array = chords[bar % 4]
		for eighth in 8:
			var start := int((bar * 8 + eighth) * beat * RATE)
			var notes := []
			if eighth % 4 == 0:
				notes.append([chord[0] / 2.0, beat * 3.5, 0.35])
			notes.append([chord[1 + eighth % 3] * 2.0, beat * 0.9, 0.08])
			for note in notes:
				var wave := _tone(note[0], note[1], note[2], 0.0)
				for i in wave.size():
					if start + i < out.size():
						out[start + i] += wave[i]
	return out

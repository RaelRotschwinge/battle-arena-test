# A small synthesizer for the sounds and music made in code (sounds.gd): voices that add into one
# buffer of float samples, and the conversion to a WAV stream. Voices take a dictionary of named
# values with defaults, so a sound reads like its recipe. Noise comes from a seeded sequence:
# a sound is the same at every start, and no random numbers are drawn.
extends RefCounted

enum Wave { SINE, TRIANGLE, SAW, SQUARE }

const RELEASE := 0.004  # Every voice fades out over its last seconds this long: no clicks.

var rate: int
var data := PackedFloat32Array()


func _init(sample_rate: int, seconds: float) -> void:
	rate = sample_rate
	data.resize(maxi(int(seconds * rate), 1))
	data.fill(0.0)


# A tone. at, len: seconds; hz, to: the pitch from and to; sweep > 0 falls from hz toward to with
# that time constant (a thump), else the pitch glides evenly over the length; wave; vol; attack;
# decay: the time constant of the fade (0 holds); lp: a gentle low pass in Hz (0 for none);
# vib, vib_hz: vibrato depth (share of the pitch) and speed; trem, trem_hz: the same for volume.
func tone(p: Dictionary) -> void:
	var start := int(p.get("at", 0.0) * rate)
	var n := mini(int(p.get("len", 0.2) * rate), data.size() - start)
	if n <= 0:
		return
	var hz: float = p.get("hz", 440.0)
	var to: float = p.get("to", hz)
	var sweep: float = p.get("sweep", 0.0)
	var wave: int = p.get("wave", Wave.SINE)
	var gain: float = p.get("vol", 0.5)
	var decay: float = p.get("decay", 0.0)
	var kd := exp(-1.0 / (decay * rate)) if decay > 0.0 else 1.0
	var attack_n := maxi(int(p.get("attack", 0.002) * rate), 1)
	var release_n := maxi(int(RELEASE * rate), 1)
	var glide := pow(to / hz, 1.0 / n) if sweep <= 0.0 else 1.0
	var ks := exp(-1.0 / (sweep * rate)) if sweep > 0.0 else 0.0
	var lp: float = p.get("lp", 0.0)
	var lp_a := 1.0 - exp(-TAU * lp / rate) if lp > 0.0 else 1.0
	var vib: float = p.get("vib", 0.0)
	var vib_step: float = TAU * p.get("vib_hz", 5.0) / rate
	var trem: float = p.get("trem", 0.0)
	var trem_step: float = TAU * p.get("trem_hz", 8.0) / rate
	var inv := 1.0 / rate
	var phase: float = p.get("phase", 0.0)
	var f := hz
	var s := 1.0
	var low := 0.0
	for i in n:
		var env := gain
		if i < attack_n:
			env *= float(i) / attack_n
		if i > n - release_n:
			env *= float(n - i) / release_n
		gain *= kd
		if sweep > 0.0:
			f = to + (hz - to) * s
			s *= ks
		else:
			f *= glide
		var step := f * inv
		if vib > 0.0:
			step *= 1.0 + vib * sin(vib_step * i)
		phase += step
		phase -= floorf(phase)
		var v := 0.0
		match wave:
			Wave.SINE:
				v = sin(TAU * phase)
			Wave.TRIANGLE:
				v = 4.0 * absf(phase - 0.5) - 1.0
			Wave.SAW:
				v = 2.0 * phase - 1.0
			Wave.SQUARE:
				v = 1.0 if phase < 0.5 else -1.0
		if lp > 0.0:
			low += lp_a * (v - low)
			v = low
		if trem > 0.0:
			v *= 1.0 - trem * (0.5 + 0.5 * sin(trem_step * i))
		data[start + i] += v * env


# Filtered noise. at, len, vol, attack, decay as for tone(); filter: "lp", "bp" or "hp"; cut, to:
# the cutoff from and to (it glides evenly); q: resonance (0.5 soft, 4 a narrow whistle); seed;
# trem, trem_hz: a pulsing volume (a spin).
func noise(p: Dictionary) -> void:
	var start := int(p.get("at", 0.0) * rate)
	var n := mini(int(p.get("len", 0.2) * rate), data.size() - start)
	if n <= 0:
		return
	var gain: float = p.get("vol", 0.5)
	var decay: float = p.get("decay", 0.0)
	var kd := exp(-1.0 / (decay * rate)) if decay > 0.0 else 1.0
	var attack_n := maxi(int(p.get("attack", 0.002) * rate), 1)
	var release_n := maxi(int(RELEASE * rate), 1)
	var kind: String = p.get("filter", "lp")
	var cut: float = p.get("cut", 3000.0)
	var to: float = p.get("to", cut)
	var glide := pow(to / cut, 16.0 / n)  # The cutoff moves every 16 samples.
	var k: float = 1.0 / p.get("q", 0.7)
	var trem: float = p.get("trem", 0.0)
	var trem_step: float = TAU * p.get("trem_hz", 8.0) / rate
	var value: int = int(p.get("seed", 1)) * 7919 + 17
	var ic1 := 0.0
	var ic2 := 0.0
	var a1 := 0.0
	var a2 := 0.0
	var a3 := 0.0
	for i in n:
		if i % 16 == 0:  # A state variable filter (trapezoidal), stable at any cutoff.
			var g := tan(PI * minf(cut, rate * 0.45) / rate)
			a1 = 1.0 / (1.0 + g * (g + k))
			a2 = g * a1
			a3 = g * a2
			cut *= glide
		value = (value * 1103515245 + 12345) & 0x7fffffff
		var x := float(value) / 1073741824.0 - 1.0
		var v3 := x - ic2
		var v1 := a1 * ic1 + a2 * v3
		var v2 := ic2 + a2 * ic1 + a3 * v3
		ic1 = 2.0 * v1 - ic1
		ic2 = 2.0 * v2 - ic2
		var v := v2
		if kind == "bp":
			v = v1 * k
		elif kind == "hp":
			v = x - k * v1 - v2
		var env := gain
		if i < attack_n:
			env *= float(i) / attack_n
		if i > n - release_n:
			env *= float(n - i) / release_n
		gain *= kd
		if trem > 0.0:
			env *= 1.0 - trem * (0.5 + 0.5 * sin(trem_step * i))
		data[start + i] += v * env


# A two-operator FM tone: bells, rings and metal. ratio: the modulator's pitch to the carrier's
# (not whole numbers sound metallic); index: how bright, fading with index_decay.
func fm(p: Dictionary) -> void:
	var start := int(p.get("at", 0.0) * rate)
	var n := mini(int(p.get("len", 0.5) * rate), data.size() - start)
	if n <= 0:
		return
	var hz: float = p.get("hz", 880.0)
	var ratio: float = p.get("ratio", 1.4)
	var index: float = p.get("index", 2.0)
	var index_decay: float = p.get("index_decay", 0.1)
	var ki := exp(-1.0 / (index_decay * rate))
	var gain: float = p.get("vol", 0.4)
	var decay: float = p.get("decay", 0.2)
	var kd := exp(-1.0 / (decay * rate))
	var attack_n := maxi(int(p.get("attack", 0.001) * rate), 1)
	var release_n := maxi(int(RELEASE * rate), 1)
	var step := hz / rate
	var mod_step := hz * ratio / rate
	var phase := 0.0
	var mod := 0.0
	for i in n:
		var env := gain
		if i < attack_n:
			env *= float(i) / attack_n
		if i > n - release_n:
			env *= float(n - i) / release_n
		gain *= kd
		mod += mod_step
		mod -= floorf(mod)
		phase += step
		phase -= floorf(phase)
		data[start + i] += sin(TAU * phase + index * sin(TAU * mod)) * env
		index *= ki


# Adds another buffer in from at (seconds), cut off at this buffer's end.
func add(other: PackedFloat32Array, at: float) -> void:
	var start := int(at * rate)
	for i in mini(other.size(), data.size() - start):
		data[start + i] += other[i]


# Ducks the buffer on every beat and lets it swell back, as a compressor keyed by the kick does
# (the pumping side-chain of dance music). The buffer must start on a beat.
func pump(beat: float, depth: float, release: float) -> void:
	var t := 0.0
	var inv := 1.0 / rate
	for i in data.size():
		var k := minf(t / release, 1.0)
		data[i] *= 1.0 - depth * (1.0 - k) * (1.0 - k)
		t += inv
		if t >= beat:
			t -= beat


# Soft saturation over the whole buffer: louder body, rounded peaks.
func drive(amount: float) -> void:
	var norm := 1.0 / tanh(amount)
	for i in data.size():
		data[i] = tanh(data[i] * amount) * norm


# For a loop: what rings on past loop_seconds is added to the start, then cut off there.
func wrap(loop_seconds: float) -> void:
	var length := mini(int(loop_seconds * rate), data.size())
	for i in range(length, data.size()):
		data[i - length] += data[i]
	data.resize(length)


func peak() -> float:
	var top := 0.0
	for v in data:
		top = maxf(top, absf(v))
	return top


# Scales the buffer to the peak in dBFS and makes the WAV; a sound that does not loop fades over
# its last milliseconds, a loop keeps its ends as they are. reference: the peak to scale by
# instead of the buffer's own (layers that play together share one scale).
func finish(peak_db: float, loop: bool = false, reference: float = 0.0) -> AudioStreamWAV:
	var top := reference if reference > 0.0 else peak()
	var scale_to := db_to_linear(peak_db) / top if top > 0.0 else 0.0
	var bytes := PackedByteArray()
	bytes.resize(data.size() * 2)
	var fade_n := 0 if loop else mini(int(0.005 * rate), data.size())
	var last := data.size() - 1
	for i in data.size():
		var v := data[i] * scale_to
		if last - i < fade_n:
			v *= float(last - i) / fade_n
		bytes.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.data = bytes
	if loop:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = data.size()
	return stream

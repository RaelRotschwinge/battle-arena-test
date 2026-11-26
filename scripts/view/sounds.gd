# All sound of the game, made in code (game design, "Sound"): the effects of sound_bank.gd and the
# music of sound_music.gd, played by sound_score.gd. They are made once per run on worker threads
# at the start, the menu music first, and kept; a sound asked for before it is made is skipped,
# music starts once it is made. The game's main node holds one Sounds node, main(); cue() and
# set_intensity() reach it from anywhere and do nothing without one. Effects play on the bus
# "SFX", music on "Music" (ensure_buses()); the options menu sets their volumes by name.
extends Node

const Bank := preload("res://scripts/view/sound_bank.gd")
const Music := preload("res://scripts/view/sound_music.gd")
const SoundScore := preload("res://scripts/view/sound_score.gd")

const VOICES := 16  # Effects that can play at the same time; the oldest gives way.
const SAME_SOUND_VOICES := 3  # One effect at most this often at once (multi-hits, footsteps).
const SAME_SOUND_GAP_MS := 25  # The same effect again this soon is one sound, not two.
const LIMIT_DB := -1.0  # The ceiling of the limiter on the master bus.

static var _main = null
static var _cache := {}  # name -> AudioStreamWAV; music as "music:<track>" (+ for a layer).
static var _lock := Mutex.new()
static var _jobs := PackedStringArray()  # What the worker threads make, in order.
static var _done := 0
static var _group := -1
static var _maker = null  # The node that started the worker threads waits for them.
static var _stop := false
static var _start_usec := 0
static var made_usec := {}  # job -> microseconds after the start when it was ready (for QA).
static var trace = null  # Set to an array, every play() adds [msec, name, made] (for QA).

var score  # sound_score.gd: the music.
var _players := []
var _names := []
var _times := []
var _rng := RandomNumberGenerator.new()  # View only: the slight spread of every effect.


static func main():
	return _main if is_instance_valid(_main) else null


# Plays an effect on the game's Sounds node, if there is one.
static func cue(sound: String, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	var sounds = main()
	if sounds != null:
		sounds.play(sound, volume_db, pitch)


# How hard the match is going, 0 to 1: the match music speeds up and fills out with it.
static func set_intensity(x: float) -> void:
	var sounds = main()
	if sounds != null:
		sounds.score.set_intensity(x)


# Adds the buses "Music" and "SFX" (sent to "Master") when missing, and a limiter on the master
# bus, so many sounds at once do not clip. Safe to call again.
static func ensure_buses() -> void:
	for bus in ["Music", "SFX"]:
		if AudioServer.get_bus_index(bus) == -1:
			var at := AudioServer.bus_count
			AudioServer.add_bus(at)
			AudioServer.set_bus_name(at, bus)
			AudioServer.set_bus_send(at, "Master")
	for e in AudioServer.get_bus_effect_count(0):
		if AudioServer.get_bus_effect(0, e) is AudioEffectHardLimiter:
			return
	var limiter := AudioEffectHardLimiter.new()
	limiter.ceiling_db = LIMIT_DB
	AudioServer.add_bus_effect(0, limiter)


# The effect or music stream if it is made, else null.
static func stream(sound: String) -> AudioStreamWAV:
	_lock.lock()
	var made: AudioStreamWAV = _cache.get(sound)
	_lock.unlock()
	return made


# True once every sound and track is made.
static func all_made() -> bool:
	_lock.lock()
	var done := _done == _jobs.size() and _jobs.size() > 0
	_lock.unlock()
	return done


func _ready() -> void:
	ensure_buses()
	if main() == null:
		_main = self
	for n in VOICES:
		var player := AudioStreamPlayer.new()
		player.bus = "SFX"
		add_child(player)
		_players.append(player)
		_names.append("")
		_times.append(0)
	score = SoundScore.new()
	score.sounds = self
	add_child(score)
	_rng.randomize()
	_start_making()


func _exit_tree() -> void:
	if _main == self:
		_main = null
	if _maker == self and _group >= 0:
		_stop = true  # Jobs not begun are skipped; the ones running finish.
		WorkerThreadPool.wait_for_group_task_completion(_group)
		_group = -1
		_maker = null
		_stop = false


# Starts the worker threads once per run: the menu music, menu sounds, the first match tier,
# the match sounds, the stinger and the faster tiers. A task must be waited for once, which
# _process does when it is done.
func _start_making() -> void:
	if _group >= 0 or not _jobs.is_empty():
		return
	var menu := ["tick", "confirm", "back", "wipe", "join", "lock", "ready", "arena"]
	_jobs.append("music:menu")
	_jobs.append_array(menu)
	_jobs.append("music:match0")
	for sound in Bank.names():
		if not menu.has(sound):
			_jobs.append(sound)
	for track in ["stinger", "match1", "match2", "match3"]:
		_jobs.append("music:" + track)
	_start_usec = Time.get_ticks_usec()
	_maker = self
	_group = WorkerThreadPool.add_group_task(_make, _jobs.size(), -1, false, "Make sounds")


# Runs on a worker thread: touches only its own sound and the locked cache.
func _make(job: int) -> void:
	if _stop:
		return
	var sound := _jobs[job]
	var made: Dictionary
	if sound.begins_with("music:"):
		made = Music.make(sound.trim_prefix("music:"))
	else:
		made = {sound: Bank.make(sound)}
	_lock.lock()
	_cache.merge(made)
	made_usec[sound] = Time.get_ticks_usec() - _start_usec
	_done += 1
	_lock.unlock()


func _process(_delta: float) -> void:
	if _maker == self and _group >= 0 and WorkerThreadPool.is_group_task_completed(_group):
		WorkerThreadPool.wait_for_group_task_completion(_group)
		_group = -1


# Plays an effect, a little louder or softer and higher or lower each time, so repeats differ.
# volume_db and pitch come on top; volume_db above 0 is cut, so no effect goes over its peak.
func play(sound: String, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	var made := stream(sound)
	var now := Time.get_ticks_msec()
	if trace != null:
		trace.append([now, sound, made != null])
	if made == null:
		return
	var v := _voice_for(sound, now)
	if v < 0:
		return
	var player: AudioStreamPlayer = _players[v]
	player.stream = made
	player.volume_db = minf(volume_db, 0.0) - _rng.randf_range(0.0, 1.5)
	player.pitch_scale = pitch * _rng.randf_range(0.97, 1.03)
	player.play()
	_names[v] = sound
	_times[v] = now


# A hit: four sizes of impact by launch speed, louder and lower the harder it is.
func hit(speed: float) -> void:
	var k := clampf((speed - 4.0) / 30.0, 0.0, 1.0)  # As hit_effects.gd sizes the burst.
	var tier := "hit_light"
	if k >= 0.75:
		tier = "hit_smash"
	elif k >= 0.45:
		tier = "hit_heavy"
	elif k >= 0.2:
		tier = "hit_medium"
	play(tier, -3.0 * (1.0 - k), 1.08 - 0.16 * k)


# A landing: heavier fighters land lower and louder, a harder fall is louder.
func land(weight: float, fall: float) -> void:
	var heavy := clampf((weight - 96.0) / 14.0, 0.0, 1.0)
	play("land", clampf(-7.0 + fall * 0.35 + heavy * 3.0, -10.0, 0.0), 1.05 - 0.2 * heavy)


# The music: "menu", "match" (it follows set_intensity()) or "" for none. It crossfades.
func music(track: String) -> void:
	score.music(track)


# The end of a match: its music drops away under a short flourish.
func stinger() -> void:
	score.stinger()


# A free voice, else the oldest one; -1 when the same effect has just started.
func _voice_for(sound: String, now: int) -> int:
	var same := 0
	var oldest_same := -1
	var free := -1
	var oldest := 0
	for i in VOICES:
		if not _players[i].playing:
			if free < 0:
				free = i
			continue
		if _names[i] == sound:
			if now - _times[i] < SAME_SOUND_GAP_MS:
				return -1
			same += 1
			if oldest_same < 0 or _times[i] < _times[oldest_same]:
				oldest_same = i
		if _times[i] < _times[oldest]:
			oldest = i
	if same >= SAME_SOUND_VOICES:
		return oldest_same
	return free if free >= 0 else oldest

# Plays the music of sound_music.gd on the bus "Music" (sounds.gd holds it): the menu theme, or
# the match track, which follows the match's intensity (0 to 1, set_intensity()). The energy
# layer fades in with it, and the tempo steps up a tier (140, 150, 160, 172 bpm) at the next bar
# line: the new tier starts in the same bar at the same time into it, so the beat goes on. It
# steps back down one tier at a time, slowly. Menu and match crossfade; stinger() ends a match.
extends Node

const Music := preload("res://scripts/view/sound_music.gd")

const FADE_SECONDS := 1.2  # Menu to match and back.
const SWITCH_SECONDS := 0.03  # A tier change: just enough to hide the cut.
const END_SECONDS := 0.25  # The match music under the stinger.
const RISE_PER_SECOND := 0.8  # The intensity follows a rise fast and a fall slowly.
const FALL_PER_SECOND := 0.04
const TIER_AT := [0.0, 0.3, 0.55, 0.8]  # The intensity each tempo tier begins at.
const TIER_BACK := 0.1  # A tier ends this far below where it began.
const BARS_BEFORE_DOWN := 8

var sounds  # The parent sounds.gd, for its made streams.
var switches := []  # Every tier change as [tier, bar, ms into the bar] (for QA).
var _decks := []  # Two decks for crossfades, each [core player, energy player].
var _tracks := ["", ""]  # Per deck: "menu", "match0" to "match3" or "".
var _gains := [0.0, 0.0]
var _fades := [FADE_SECONDS, FADE_SECONDS]  # Per deck: seconds of a full fade.
var _deck := 0
var _wanted := ""  # "menu", "match" or "".
var _target := 0.0
var _level := 0.0
var _tier := 0
var _last_bar := -1
var _bars_since_switch := 0
var _stinger: AudioStreamPlayer


func _ready() -> void:
	for d in 2:
		var deck := []
		for n in 2:
			var player := AudioStreamPlayer.new()
			player.bus = "Music"
			add_child(player)
			deck.append(player)
		_decks.append(deck)
	_stinger = AudioStreamPlayer.new()
	_stinger.bus = "Music"
	add_child(_stinger)


# "menu", "match" or "" for silence. A new match starts calm, in the first tier.
func music(track: String) -> void:
	if track == _wanted:
		return
	if track == "match":
		_target = 0.0
		_level = 0.0
		_tier = 0
		_bars_since_switch = 0
	_fades = [FADE_SECONDS, FADE_SECONDS]
	_wanted = track


func set_intensity(x: float) -> void:
	_target = clampf(x, 0.0, 1.0)


func intensity() -> float:
	return _level


func tier() -> int:
	return _tier


# The match is over: its music drops away under a short, loud flourish.
func stinger() -> void:
	_wanted = ""
	_fades = [END_SECONDS, END_SECONDS]
	var made: AudioStreamWAV = sounds.stream("music:stinger")
	if made != null:
		_stinger.stream = made
		_stinger.play()


func _process(delta: float) -> void:
	var speed := RISE_PER_SECOND if _target > _level else FALL_PER_SECOND
	_level = move_toward(_level, _target, delta * speed)
	if _wanted != "" and _kind(_tracks[_deck]) != _wanted:
		if _kind(_tracks[1 - _deck]) == _wanted:  # Still fading out: it comes back.
			_deck = 1 - _deck
		else:
			_start("menu" if _wanted == "menu" else "match%d" % _tier, 0.0, FADE_SECONDS)
	elif _wanted == "match":
		_follow_tiers()
	_fade(delta)


# At each bar line, steps a tier up or down when the intensity asks for it and that tier is made.
func _follow_tiers() -> void:
	var core: AudioStreamPlayer = _decks[_deck][0]
	if not core.playing or _gains[1 - _deck] > 0.0:
		return  # A fade is still going on.
	var bar := Music.bar_seconds(_tier)
	var at := core.get_playback_position() + AudioServer.get_time_since_last_mix()
	var bar_now := int(at / bar)
	var crossed := _last_bar >= 0 and bar_now != _last_bar
	_last_bar = bar_now
	if not crossed:
		return
	_bars_since_switch += 1
	var next := _tier
	if _tier < TIER_AT.size() - 1 and _level >= TIER_AT[_tier + 1]:
		next = _tier + 1
	elif _tier > 0 and _level < TIER_AT[_tier] - TIER_BACK \
			and _bars_since_switch >= BARS_BEFORE_DOWN:
		next = _tier - 1
	if next == _tier or sounds.stream("music:match%d" % next) == null:
		return
	var into := at - bar_now * bar  # Time since the bar line, kept in the new tier.
	switches.append([next, bar_now, int(into * 1000.0)])
	_tier = next
	_bars_since_switch = 0
	_start("match%d" % next, bar_now * Music.bar_seconds(next) + into, SWITCH_SECONDS)
	_last_bar = bar_now


# Starts a track on the quieter deck from a time; the other deck fades out as fast.
func _start(track: String, from: float, fade: float) -> void:
	var core: AudioStreamWAV = sounds.stream("music:" + track)
	if core == null:
		return
	var d := 1 - _deck if _gains[1 - _deck] <= _gains[_deck] else _deck
	if d == _deck:  # Both decks sound: the quieter one gives way now.
		_gains[d] = 0.0
	var energy: AudioStreamWAV = sounds.stream("music:" + track + "+")
	_decks[d][0].stream = core
	_decks[d][0].play(from)
	_decks[d][1].stream = energy
	if energy != null:
		_decks[d][1].play(from)
	else:
		_decks[d][1].stop()
	_tracks[d] = track
	_deck = d
	_fades = [fade, fade]
	if track.begins_with("match"):
		_last_bar = int(from / Music.bar_seconds(int(track.substr(5))))


func _fade(delta: float) -> void:
	var energy := smoothstep(0.05, 0.5, _level)
	for d in 2:
		var on: bool = d == _deck and _wanted != "" and _kind(_tracks[d]) == _wanted
		_gains[d] = move_toward(_gains[d], 1.0 if on else 0.0, delta / _fades[d])
		var core: AudioStreamPlayer = _decks[d][0]
		core.volume_db = linear_to_db(maxf(_gains[d], 0.0001))
		_decks[d][1].volume_db = linear_to_db(maxf(_gains[d] * energy, 0.0001))
		if _gains[d] == 0.0 and not on and core.playing:
			core.stop()
			_decks[d][1].stop()
			_tracks[d] = ""


static func _kind(track: String) -> String:
	return "match" if track.begins_with("match") else track

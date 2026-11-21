# The values of a fighter kind: movement, weight, size and its moves (attacks.gd format). The
# defaults are the test fighter; each fighter in fighters/ changes some of them. Units: pixels and
# ticks (60 ticks per second). Starting values, tuned in play.
extends RefCounted

const Attacks := preload("res://scripts/sim/attacks.gd")

# Name, lowest value, highest value, step: what the tuning panel offers.
const TUNABLE := [
	["walk_speed", 1.0, 20.0, 0.5],
	["run_speed", 1.0, 30.0, 0.5],
	["ground_accel", 0.1, 5.0, 0.1],
	["ground_friction", 0.1, 5.0, 0.1],
	["air_speed", 1.0, 20.0, 0.5],
	["air_accel", 0.05, 3.0, 0.05],
	["air_friction", 0.0, 2.0, 0.05],
	["gravity", 0.1, 3.0, 0.05],
	["max_fall_speed", 2.0, 40.0, 0.5],
	["fast_fall_speed", 2.0, 50.0, 0.5],
	["jump_squat_ticks", 1, 10, 1],
	["jump_speed", 2.0, 40.0, 0.5],
	["jump_release_cut", 0.1, 1.0, 0.05],
	["double_jump_speed", 2.0, 40.0, 0.5],
	["run_double_tap_ticks", 4, 30, 1],
	["wall_jump_speed", 2.0, 40.0, 0.5],
	["wall_jump_push", 0.0, 30.0, 0.5],
	["max_wall_jumps", 0, 10, 1],
	["ledge_climb_ticks", 1, 60, 1],
	["lift_speed", 2.0, 40.0, 0.5],
	["landing_lag_ticks", 0, 20, 1],
	["weight", 50.0, 200.0, 5.0],
	["knockback_scale", 0.2, 3.0, 0.05],
	["hitstun_factor", 0.0, 1.5, 0.05],
	["hitstun_gravity", 0.1, 1.0, 0.05],
]

var walk_speed := 6.0
var run_speed := 10.0
var ground_accel := 1.2
var ground_friction := 1.0
var air_speed := 6.0
var air_accel := 0.5
var air_friction := 0.1
var gravity := 0.8
var max_fall_speed := 14.0
var fast_fall_speed := 22.0
var jump_squat_ticks := 3  # Take-off before a jump from the ground leaves the ground.
var jump_speed := 18.0
var jump_release_cut := 0.6  # Letting go of up while rising keeps this share of the speed.
var double_jump_speed := 16.0
var run_double_tap_ticks := 12  # A second tap within this many ticks starts a run.
var drop_through_ticks := 8  # After down on a thin platform, thin platforms let go this long.
var wall_jump_speed := 15.0
var wall_jump_push := 8.0  # Speed away from the wall.
var max_wall_jumps := 3  # Per time in the air; landing or grabbing a ledge gives them back.
var ledge_climb_ticks := 12
var ledge_hang_ticks := 180  # Hanging longer than this lets go by itself.
var ledge_regrab_ticks := 30  # After letting go, no ledge can be grabbed this long.
var lift_speed := 13.0  # Upward speed while the up air carries the fighter up,
var lift_ticks := 10  # for this many ticks of the up air; 0: no lift.
var air_jumps := 1  # Jumps in the air (the double jump).
var weight := 100.0  # Heavier fighters fly less far (game design, "Core rules").
var knockback_scale := 1.0  # Scales every launch.
var hitstun_factor := 1.5  # Hitstun ticks per pixel per tick of launch speed.
var hitstun_gravity := 0.5  # Share of gravity while in hitstun, so launched fighters fly far.
var landing_lag_ticks := 2  # Landing during an air attack.
var respawn_wait_ticks := 120  # The respawn platform holds the fighter at most this long.
var respawn_invuln_ticks := 120
var width := 60.0
var height := 100.0
var fighter_name := "Test"
var look := {"shape": "test", "colors": []}  # How the view draws it (fighter_look.gd).
var attacks: Dictionary = Attacks.ATTACKS


func set_value(key: String, value: float) -> void:
	if typeof(get(key)) == TYPE_INT:
		set(key, roundi(value))
	else:
		set(key, value)


func reset_defaults() -> void:
	var defaults: RefCounted = get_script().new()
	for entry in TUNABLE:
		set(entry[0], defaults.get(entry[0]))

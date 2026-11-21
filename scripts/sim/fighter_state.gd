# The state of one fighter. Everything the simulation needs is in here, so a copy of all fighter
# states is a full copy of the match (for rollback netcode later).
extends RefCounted

const FighterInput := preload("res://scripts/sim/fighter_input.gd")

enum Mode { GROUND, JUMP_SQUAT, AIR, LEDGE, CLIMB, HITSTUN, RESPAWN }

const _FIELDS := [
	"position", "velocity", "mode", "mode_ticks", "facing", "running", "jumps_left",
	"wall_jumps_used", "lift_used", "lifting", "fast_falling", "jump_rising", "drop_ticks",
	"ledge", "ledge_cooldown", "tap_dir", "ticks_since_tap", "ticks_since_up", "attack_buffer",
	"jump_buffer", "respawns", "damage", "stocks", "out", "attack", "attack_ticks", "hit_mask",
	"hitstun", "hitlag", "invuln", "lag",
]

var position := Vector2.ZERO  # Feet, horizontal middle. Pixels, y points down.
var velocity := Vector2.ZERO  # Pixels per tick.
var mode := Mode.AIR
var mode_ticks := 0  # Ticks since the current mode began.
var facing := 1  # 1 right, -1 left.
var running := false
var jumps_left := 0  # Jumps left in the air (the double jump).
var wall_jumps_used := 0  # Wall jumps since the last landing or ledge grab.
var fast_falling := false
var jump_rising := false  # Rising from a ground jump: letting go of up cuts the jump short.
var drop_ticks := 0  # Ticks left in which thin platforms do not hold the fighter.
var ledge := -1  # Index of the ledge the fighter hangs on or climbs up, -1 for none.
var ledge_cooldown := 0  # Ticks left after letting go of a ledge before one can be grabbed.
var tap_dir := 0  # Direction of the last left or right tap, for the double tap to run.
var ticks_since_tap := 1000
var respawns := 0  # Counts respawns, so the view knows when the fighter jumped to a new place.
var lift_used := false  # The up air carried the fighter up in this time in the air.
var lifting := false  # The current up air carries the fighter up.
var ticks_since_up := 1000  # Ticks since up was last pressed.
var attack_buffer := 0  # Ticks left in which a press of attack waits until the fighter can act.
var jump_buffer := 0  # The same for a press of up that asks for a jump.
var damage := 0.0  # Percent.
var stocks := 0  # Lives left.
var out := false  # No lives left: out of the match.
var attack := ""  # Name of the current attack (attacks.gd), "" for none.
var attack_ticks := 0  # Ticks since the attack began.
var hit_mask := 0  # Bit per fighter index already hit by the current attack.
var hitstun := 0  # Ticks left in which the fighter, launched by a hit, cannot act.
var hitlag := 0  # Ticks left of the hit pause: the fighter stands frozen.
var invuln := 0  # Ticks left in which hits do not touch the fighter.
var lag := 0  # Ticks left in which the fighter cannot act, after landing from an attack.
var prev_input := FighterInput.new()  # The input of the previous tick, to see new presses.


func to_dict() -> Dictionary:
	var data := {}
	for field in _FIELDS:
		data[field] = get(field)
	data["prev_input"] = prev_input.to_dict()
	return data


func from_dict(data: Dictionary) -> void:
	for field in _FIELDS:
		set(field, data[field])
	prev_input.from_dict(data["prev_input"])

# The state of one fighter. Everything the simulation needs is in here, so a copy of all fighter
# states is a full copy of the match (for rollback netcode later). stats is the fighter's kind
# (values and moves); it is set once when the match is made and is not part of the copy.
extends RefCounted

const FighterInput := preload("res://scripts/sim/fighter_input.gd")

enum Mode {
	GROUND, JUMP_SQUAT, AIR, LEDGE, CLIMB, HITSTUN, RESPAWN, SHIELD, DODGE, SHIELD_BREAK, TECH,
	GRAB, HELD,
}

const _FIELDS := [
	"position", "velocity", "mode", "mode_ticks", "facing", "running", "jumps_left",
	"wall_jumps_used", "lift_used", "lifting", "fast_falling", "jump_rising", "drop_ticks",
	"ledge", "ledge_cooldown", "tap_dir", "ticks_since_tap", "ticks_since_up", "ticks_since_down",
	"attack_buffer", "jump_buffer", "shield_buffer", "respawns", "damage", "stocks", "out",
	"attack", "attack_ticks", "hit_mask", "hitstun", "hitstun_total", "hitlag", "launch_pending",
	"combo_hits", "invuln", "lag", "shield_hp", "shield_rest", "shield_stun", "shield_push",
	"shield_drop", "ticks_since_shield", "dodge", "dodge_dir", "dodge_streak",
	"ticks_since_dodge", "air_dodge_used", "tech_window", "tech_lockout", "ledge_invuln_ok",
	"climb_next", "holding", "held_by", "grab_immune", "throw", "last_hit_by", "kos", "falls",
	"self_destructs", "damage_dealt",
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
var ticks_since_down := 1000
var attack_buffer := 0  # Ticks left in which a press of attack waits until the fighter can act.
var jump_buffer := 0  # The same for a press that asks for a jump.
var shield_buffer := 0  # The same for a press of the shield key (air dodge, roll).
var damage := 0.0  # Percent.
var stocks := 0  # Lives left.
var out := false  # No lives left: out of the match.
var attack := ""  # Name of the current attack (the fighter's moves), "" for none.
var attack_ticks := 0  # Ticks since the attack began.
var hit_mask := 0  # Bit per fighter index already hit by the current attack.
var hitstun := 0  # Ticks left in which the fighter, launched by a hit, cannot act.
var hitstun_total := 0  # The hitstun of the last launch, for the early way out.
var hitlag := 0  # Ticks left of the hit pause: the fighter stands frozen.
var launch_pending := false  # Hit, the launch waits for the end of the hit pause (DI).
var combo_hits := 0  # Hits taken in a row without leaving hitstun.
var invuln := 0  # Ticks left in which hits do not touch the fighter.
var lag := 0  # Ticks left in which the fighter cannot act (landing, throws).
var shield_hp := 100.0
var shield_rest := 0  # Ticks since the shield was let go, for its regeneration.
var shield_stun := 0  # Ticks left in which a hit shield cannot act.
var shield_push := 0.0  # Sideways slide of a hit shield, pixels per tick.
var shield_drop := 0  # Ticks left of lowering the shield.
var ticks_since_shield := 1000  # Ticks since the shield key was last pressed.
var dodge := ""  # "spot", "roll", "air" or "" while in DODGE or TECH mode.
var dodge_dir := Vector2.ZERO
var dodge_streak := 0  # Dodges in a row, each with less invulnerability.
var ticks_since_dodge := 1000
var air_dodge_used := false
var tech_window := 0  # Ticks left in which hitting the ground or a wall is a tech.
var tech_lockout := 0  # Ticks left in which a press opens no new tech window.
var ledge_invuln_ok := true  # The next ledge grab makes the fighter invulnerable.
var climb_next := ""  # What follows climbing up a ledge: "", "attack" or "roll".
var holding := -1  # Index of the fighter this one holds in a grab, -1 for none.
var held_by := -1  # Index of the fighter holding this one, -1 for none.
var grab_immune := 0  # Ticks left in which this fighter cannot be grabbed.
var throw := ""  # The throw the holder chose this tick, for the match to carry out.
var last_hit_by := -1  # Index of the fighter that hit this one last in this life, -1 for none.
var kos := 0  # Knockouts scored, for the results screen.
var falls := 0  # Lives lost.
var self_destructs := 0  # Lives lost without being hit.
var damage_dealt := 0.0
var stale: Array = []  # Names of the fighter's last attacks that hit, newest last.
var prev_input := FighterInput.new()  # The input of the previous tick, to see new presses.
var stats  # The fighter's kind: values and moves. Not part of the copy.


func to_dict() -> Dictionary:
	var data := {}
	for field in _FIELDS:
		data[field] = get(field)
	data["stale"] = stale.duplicate()
	data["prev_input"] = prev_input.to_dict()
	return data


func from_dict(data: Dictionary) -> void:
	for field in _FIELDS:
		set(field, data[field])
	stale = data["stale"].duplicate()
	prev_input.from_dict(data["prev_input"])

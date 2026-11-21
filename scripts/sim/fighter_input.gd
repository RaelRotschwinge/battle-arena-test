# The buttons one player holds during one tick. The simulation reads input only through this.
# up is the direction (on a keyboard it is also the jump key); jump is a jump button of its own
# (gamepads), so it jumps without counting as up for an attack. run: a gamepad stick tilted all
# the way, which runs at once.
extends RefCounted

const FIELDS := ["left", "right", "up", "down", "attack", "shield", "jump", "run"]

var left := false
var right := false
var up := false
var down := false
var attack := false
var shield := false
var jump := false
var run := false


func copy_from(other) -> void:
	for field in FIELDS:
		set(field, other.get(field))


func to_dict() -> Dictionary:
	var data := {}
	for field in FIELDS:
		data[field] = get(field)
	return data


func from_dict(data: Dictionary) -> void:
	for field in FIELDS:
		set(field, data.get(field, false))


func dir() -> int:
	return int(right) - int(left)

# The buttons one player holds during one tick. The simulation reads input only through this.
extends RefCounted

var left := false
var right := false
var up := false
var down := false
var attack := false


func copy_from(other) -> void:
	left = other.left
	right = other.right
	up = other.up
	down = other.down
	attack = other.attack


func to_dict() -> Dictionary:
	return {"left": left, "right": right, "up": up, "down": down, "attack": attack}


func from_dict(data: Dictionary) -> void:
	left = data["left"]
	right = data["right"]
	up = data["up"]
	down = data["down"]
	attack = data["attack"]

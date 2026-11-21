# The keyboard layout of the two local players (game design, "Controls"). Physical keys: the keys
# stay in the same place on every keyboard language.
extends RefCounted

const FighterInput := preload("res://scripts/sim/fighter_input.gd")

const LAYOUTS := [
	{"left": [KEY_A], "right": [KEY_D], "up": [KEY_W], "down": [KEY_S], "attack": [KEY_SPACE]},
	{"left": [KEY_LEFT], "right": [KEY_RIGHT], "up": [KEY_UP], "down": [KEY_DOWN],
			"attack": [KEY_ENTER, KEY_KP_ENTER]},
]


static func read(player: int) -> FighterInput:
	var layout: Dictionary = LAYOUTS[player]
	var input := FighterInput.new()
	input.left = _held(layout["left"])
	input.right = _held(layout["right"])
	input.up = _held(layout["up"])
	input.down = _held(layout["down"])
	input.attack = _held(layout["attack"])
	return input


static func _held(keys: Array) -> bool:
	for key in keys:
		if Input.is_physical_key_pressed(key):
			return true
	return false

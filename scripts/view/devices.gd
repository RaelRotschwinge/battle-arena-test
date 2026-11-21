# The input devices of the local players (game design, "Controls"): two keyboard layouts and the
# gamepads. A device is "kb1", "kb2" or "pad<n>" with n the Godot joypad id. Only the view reads
# devices; the simulation sees fighter inputs. Physical keys: the keys stay in the same place on
# every keyboard language.
#
# Left and right Shift and Ctrl are told apart only through key events, so one Devices node must
# be in the tree. poll() is called once per tick before reading menu presses.
extends Node

const FighterInput := preload("res://scripts/sim/fighter_input.gd")

const KEYBOARD := {
	"kb1": {"left": [KEY_A], "right": [KEY_D], "up": [KEY_W], "down": [KEY_S],
			"attack": [KEY_SPACE], "side": KEY_LOCATION_LEFT},
	"kb2": {"left": [KEY_LEFT], "right": [KEY_RIGHT], "up": [KEY_UP], "down": [KEY_DOWN],
			"attack": [KEY_ENTER, KEY_KP_ENTER], "side": KEY_LOCATION_RIGHT},
}
const STICK := 0.5  # A stick tilted this far counts as a direction.
const RUN_TILT := 0.9  # Tilted this far sideways, the fighter runs at once.
const TRIGGER := 0.5
const PAD_JUMP := [JOY_BUTTON_A, JOY_BUTTON_Y]
const PAD_ATTACK := [JOY_BUTTON_X, JOY_BUTTON_B]
const PAD_SHIELD := [JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_RIGHT_SHOULDER]
const MENU_ACTIONS := ["up", "down", "left", "right", "confirm", "back", "start"]
const REPEAT_DELAY := 20  # Ticks a held direction waits before it repeats in menus.
const REPEAT_EVERY := 6

static var _modifiers := {}  # "keycode location" -> held, for Shift and Ctrl.
static var _menu_held := {}  # device -> {action: ticks held}
static var _menu_pressed := {}  # device -> {action: true} for this tick.


func _input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or key.echo:
		return
	if key.physical_keycode == KEY_SHIFT or key.physical_keycode == KEY_CTRL:
		_modifiers["%d %d" % [key.physical_keycode, key.location]] = key.pressed


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_modifiers.clear()  # Releases are not seen while the window has no focus.


# All devices that can play now: both keyboard layouts and every connected gamepad.
static func all() -> Array:
	var devices := ["kb1", "kb2"]
	for id in Input.get_connected_joypads():
		devices.append("pad%d" % id)
	return devices


static func has_device(device: String) -> bool:
	return all().has(device)


static func label(device: String) -> String:
	match device:
		"kb1":
			return "Keys left"
		"kb2":
			return "Keys right"
	return "Gamepad %d" % (_pad(device) + 1)


static func read(device: String) -> FighterInput:
	var input := FighterInput.new()
	if KEYBOARD.has(device):
		var layout: Dictionary = KEYBOARD[device]
		for action in ["left", "right", "up", "down", "attack"]:
			input.set(action, _keys(layout[action]))
		input.shield = _modifier(KEY_SHIFT, layout["side"]) or _modifier(KEY_CTRL, layout["side"])
		return input
	var pad := _pad(device)
	if pad < 0 or not Input.get_connected_joypads().has(pad):
		return input
	var x := Input.get_joy_axis(pad, JOY_AXIS_LEFT_X)
	var y := Input.get_joy_axis(pad, JOY_AXIS_LEFT_Y)
	input.left = x < -STICK or Input.is_joy_button_pressed(pad, JOY_BUTTON_DPAD_LEFT)
	input.right = x > STICK or Input.is_joy_button_pressed(pad, JOY_BUTTON_DPAD_RIGHT)
	input.up = y < -STICK or Input.is_joy_button_pressed(pad, JOY_BUTTON_DPAD_UP)
	input.down = y > STICK or Input.is_joy_button_pressed(pad, JOY_BUTTON_DPAD_DOWN)
	input.run = absf(x) > RUN_TILT
	input.jump = _buttons(pad, PAD_JUMP)
	input.attack = _buttons(pad, PAD_ATTACK)
	input.shield = _buttons(pad, PAD_SHIELD) \
			or Input.get_joy_axis(pad, JOY_AXIS_TRIGGER_LEFT) > TRIGGER \
			or Input.get_joy_axis(pad, JOY_AXIS_TRIGGER_RIGHT) > TRIGGER
	return input


# Reads the menu keys of every device once per tick: a press counts on the first tick, and a held
# direction repeats.
static func poll() -> void:
	var devices := all()
	for device in _menu_held.keys():
		if not devices.has(device):
			_menu_held.erase(device)
	for device in devices:
		var held := _menu_state(device)
		var ticks: Dictionary = _menu_held.get(device, {})
		var pressed := {}
		for action in MENU_ACTIONS:
			if not held[action]:
				ticks[action] = 0
				continue
			var t: int = ticks.get(action, 0) + 1
			ticks[action] = t
			var repeats: bool = action in ["up", "down", "left", "right"] \
					and t > REPEAT_DELAY and (t - REPEAT_DELAY) % REPEAT_EVERY == 0
			if t == 1 or repeats:
				pressed[action] = true
		_menu_held[device] = ticks
		_menu_pressed[device] = pressed


static func pressed(device: String, action: String) -> bool:
	return _menu_pressed.get(device, {}).get(action, false)


# The first device that pressed the menu action this tick, "" for none.
static func any_pressed(action: String) -> String:
	for device in all():
		if pressed(device, action):
			return device
	return ""


# Marks every held menu key as already pressed, so a key still held from the last screen does not
# act on the next one.
static func swallow() -> void:
	for device in all():
		var ticks := {}
		var held := _menu_state(device)
		for action in MENU_ACTIONS:
			ticks[action] = 1 if held[action] else 0
		_menu_held[device] = ticks
		_menu_pressed[device] = {}


static func _menu_state(device: String) -> Dictionary:
	var input := read(device)
	var state := {"up": input.up, "down": input.down, "left": input.left, "right": input.right,
			"confirm": input.attack, "back": false, "start": false}
	if KEYBOARD.has(device):
		state["back"] = input.shield or Input.is_physical_key_pressed(KEY_ESCAPE)
		state["start"] = Input.is_physical_key_pressed(KEY_ESCAPE)
	else:
		var pad := _pad(device)
		state["confirm"] = Input.is_joy_button_pressed(pad, JOY_BUTTON_A) \
				or Input.is_joy_button_pressed(pad, JOY_BUTTON_X)
		state["back"] = Input.is_joy_button_pressed(pad, JOY_BUTTON_B)
		state["start"] = Input.is_joy_button_pressed(pad, JOY_BUTTON_START)
	return state


static func _pad(device: String) -> int:
	return int(device.substr(3)) if device.begins_with("pad") else -1


static func _keys(keys: Array) -> bool:
	for key in keys:
		if Input.is_physical_key_pressed(key):
			return true
	return false


static func _modifier(keycode: int, location: int) -> bool:
	return _modifiers.get("%d %d" % [keycode, location], false)


static func _buttons(pad: int, buttons: Array) -> bool:
	for button in buttons:
		if Input.is_joy_button_pressed(pad, button):
			return true
	return false

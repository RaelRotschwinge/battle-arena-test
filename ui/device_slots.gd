# Who plays with which input device on the fighter select (game design, "Menus"). Each of the four
# player slots chooses a device (a keyboard layout or a gamepad) and locks it in. A slot may only
# choose devices that no slot before it has locked; when a slot locks a device a later slot holds,
# that later slot moves on to its next free device and is open again. Only a locked device steers
# its slot; the mouse works every slot. Pure logic: the connected devices are passed in.
extends RefCounted

const SLOTS := 4

var slots := []  # Per slot: {} empty, or {"device": String ("" for none free), "locked": bool}.


func _init() -> void:
	for i in SLOTS:
		slots.append({})


func joined(i: int) -> bool:
	return not slots[i].is_empty()


func device(i: int) -> String:
	return slots[i].get("device", "")


func locked(i: int) -> bool:
	return slots[i].get("locked", false)


# The devices slot i may choose: every connected device no earlier slot has locked.
func choices(i: int, devices: Array) -> Array:
	var free := []
	for d in devices:
		var taken := false
		for j in i:
			if locked(j) and device(j) == d:
				taken = true
		if not taken:
			free.append(d)
	return free


# The slot this device steers (the one that locked it), -1 for none.
func owner_of(d: String) -> int:
	for i in SLOTS:
		if locked(i) and device(i) == d:
			return i
	return -1


# A press of attack on a device that steers no slot: it locks the first open slot that chose it,
# else it joins the first empty slot, locked. Returns the slot, -1 when all four are taken.
func press(d: String, devices: Array) -> int:
	for i in SLOTS:
		if joined(i) and not locked(i) and device(i) == d and choices(i, devices).has(d):
			lock(i, devices)
			return i
	for i in SLOTS:
		if not joined(i) and choices(i, devices).has(d):
			slots[i] = {"device": d, "locked": false}
			lock(i, devices)
			return i
	return -1


# Joins slot i by mouse: open, with the first device it may choose that no other slot holds.
func join(i: int, devices: Array) -> void:
	if joined(i):
		return
	var pick := ""
	for d in choices(i, devices):
		if owner_of(d) < 0 and not _held_by_other(i, d):
			pick = d
			break
	if pick == "":
		var all := choices(i, devices)
		pick = all[0] if not all.is_empty() else ""
	slots[i] = {"device": pick, "locked": false}


# The next device slot i may choose, step forward or back; changing the device opens the slot.
func cycle(i: int, step: int, devices: Array) -> void:
	var all := choices(i, devices)
	if not joined(i) or all.is_empty():
		return
	var at := all.find(device(i))
	slots[i] = {"device": all[posmod(at + step, all.size())] if at >= 0 else all[0],
			"locked": false}


# Locks slot i's device; a later slot holding the same device moves on and is open again.
func lock(i: int, devices: Array) -> bool:
	if not joined(i) or device(i) == "" or not choices(i, devices).has(device(i)):
		return false
	slots[i]["locked"] = true
	for j in range(i + 1, SLOTS):
		if joined(j) and device(j) == device(i):
			var rest := choices(j, devices)
			slots[j] = {"device": rest[0] if not rest.is_empty() else "", "locked": false}
	return true


func unlock(i: int) -> void:
	if joined(i):
		slots[i]["locked"] = false


func leave(i: int) -> void:
	slots[i] = {}


# Devices that went away (a gamepad unplugged): their slots stay, open, until a device is chosen.
func forget_missing(devices: Array) -> void:
	for i in SLOTS:
		if joined(i) and device(i) != "" and not devices.has(device(i)):
			slots[i] = {"device": "", "locked": false}


func _held_by_other(i: int, d: String) -> bool:
	for j in SLOTS:
		if j != i and joined(j) and device(j) == d:
			return true
	return false

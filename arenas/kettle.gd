# Kettle (game design, "Arenas"): a wide stage for four with three thin platforms and two vents in
# the floor. Each vent idles, then glows and puffs for 1.5 seconds, then bursts: a column of steam
# that throws everyone in it straight up. Straight up and weak, so it never knocks anyone out by
# itself. The two vents take turns on a fixed clock; with the rule "Hazards" off they stay cold.
extends "res://scripts/sim/arena.gd"

const VENTS := [700.0, 1220.0]  # Middle x of each vent.
const VENT_WIDTH := 160.0
const TOP_Y := 420.0  # The burst reaches this high.
const CYCLE := 480
const WARN_FROM := 300
const BURST_FROM := 390
const BURST_TO := 420
const BURST := {"damage": 6.0, "base": 12.0, "growth": 0.0, "angle": 90.0}

var _tick := 0


func _init() -> void:
	arena_name = "Kettle"
	description = "A party stove: the floor erupts on a clock you can read. Wide, room for four."
	solids.assign([Rect2(260, 820, 1400, 280)])
	thin.assign([Rect2(400, 650, 220, 16), Rect2(1300, 650, 220, 16), Rect2(810, 520, 300, 16)])
	add_ledges_of_solids()
	blast_zone = Rect2(-560, -820, 3040, 2370)
	spawns.assign([Vector2(460, 820), Vector2(1460, 820), Vector2(560, 820), Vector2(1360, 820)])
	respawn_point = Vector2(960, 260)
	colors = {"sky": [Color("3d0814"), Color("a4161a")], "ground": Color("3a2a2a"),
			"ground_top": Color("f3b562"), "thin": Color("ffd6a5"), "vent": Color("ff7b00"),
			"steam": Color("f4f4f4")}


func update(tick: int, _fighters: Array) -> void:
	_tick = tick


func has_hazards() -> bool:
	return true


# "off", "idle", "warn" or "burst", and the ticks since that phase began, for vent v.
func vent_phase(v: int) -> Array:
	if not hazards_on:
		return ["off", 0]
	var t: int = (_tick + v * CYCLE / 2) % CYCLE
	if t >= BURST_TO:
		return ["idle", t - BURST_TO]
	if t >= BURST_FROM:
		return ["burst", t - BURST_FROM]
	if t >= WARN_FROM:
		return ["warn", t - WARN_FROM]
	return ["idle", t]


func vent_column(v: int) -> Rect2:
	var floor_y: float = solids[0].position.y
	return Rect2(VENTS[v] - VENT_WIDTH / 2.0, TOP_Y, VENT_WIDTH, floor_y - TOP_Y)


func hazard_hits() -> Array:
	var hits := []
	for v in VENTS.size():
		if vent_phase(v)[0] == "burst":
			hits.append({"box": vent_column(v), "data": BURST})
	return hits


# From the second half of the warning on: there is still time to walk out.
func hazard_warns(box: Rect2) -> bool:
	for v in VENTS.size():
		var phase: Array = vent_phase(v)
		var soon: bool = phase[0] == "warn" and phase[1] >= (BURST_FROM - WARN_FROM) / 2
		if (soon or phase[0] == "burst") and vent_column(v).grow(20.0).intersects(box):
			return true
	return false

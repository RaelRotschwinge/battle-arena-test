# The controls overview (game design, "Controls"): one card per device with its keys drawn as
# key caps, and the tips of the fight below. Drawing only; shown as the content of the overlay.
extends Control

const UiDraw := preload("res://ui/ui_draw.gd")

const SIZE := Vector2(1700, 680)
const CARD := Vector2(546, 410)
const GAP := 31.0
const ROW := 48.0
# Per device: its name and rows of [action, keys]; "<left>" and the like are drawn arrows.
const DEVICES := [
	["Keys left", [["Move", ["A", "D"]], ["Jump", ["W"]], ["Down", ["S"]], ["Attack", ["Space"]],
			["Special", ["E"]], ["Shield", ["L-Shift", "L-Ctrl"]], ["Pause", ["Esc"]]]],
	["Keys right", [["Move", ["<left>", "<right>"]], ["Jump", ["<up>"]], ["Down", ["<down>"]],
			["Attack", ["Enter"]], ["Special", ["Backspace"]], ["Shield", ["R-Shift", "R-Ctrl"]],
			["Pause", ["Esc"]]]],
	["Gamepad", [["Move", ["Stick", "D-pad"]], ["Jump", ["A", "Y"]], ["Attack", ["X"]],
			["Special", ["B"]], ["Shield", ["LB", "RB"]], ["Pause", ["Start"]]]],
]
const TIPS := [
	"The direction held picks the attack: none, side, up or down, on the ground and in the air.",
	"Special: each fighter has its own (see the fighter select); the direction aims or steers it.",
	"Shield: hold it. In the shield: left or right rolls, down dodges, attack grabs, up jumps.",
	"In the air the shield key dodges, also with a direction.",
	"Launched: hold a direction to bend your flight, press shield just before you hit the ground.",
	"Double tap a direction to run.",
]
const ARROWS := {"<left>": Vector2.LEFT, "<right>": Vector2.RIGHT, "<up>": Vector2.UP,
		"<down>": Vector2.DOWN}


func _init() -> void:
	custom_minimum_size = SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	for d in DEVICES.size():
		_device(Vector2(d * (CARD.x + GAP), 0.0), DEVICES[d][0], DEVICES[d][1])
	var tips := Rect2(0.0, CARD.y + 24.0, SIZE.x, SIZE.y - CARD.y - 24.0)
	UiDraw.panel(self, tips, 18.0, Color(UiDraw.PANEL_TOP, 0.92), Color(UiDraw.PANEL_BOTTOM, 0.92),
			Color("3d465f"))
	for n in TIPS.size():
		var y := tips.position.y + 44.0 + n * 37.0
		_diamond(Vector2(34.0, y - 9.0), 7.0)
		UiDraw.text(self, Vector2(56.0, y), TIPS[n], 25, Color("dde1ea"), HORIZONTAL_ALIGNMENT_LEFT,
				SIZE.x - 80.0, null, 0)


func _device(at: Vector2, title: String, rows: Array) -> void:
	var rect := Rect2(at, CARD)
	UiDraw.panel(self, rect, 18.0, Color(UiDraw.PANEL_TOP, 0.92), Color(UiDraw.PANEL_BOTTOM, 0.92),
			Color("3d465f"))
	UiDraw.panel(self, Rect2(at, Vector2(CARD.x, 58.0)), 18.0, Color("3f4966"), Color("323a52"))
	draw_rect(Rect2(at + Vector2(0, 40), Vector2(CARD.x, 18)), Color("323a52"))
	UiDraw.text(self, Vector2(at.x, UiDraw.baseline(at.y, 58.0, 30, UiDraw.bold())), title, 30,
			Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, CARD.x, UiDraw.bold(), 6)
	for r in rows.size():
		var y := at.y + 76.0 + r * ROW
		UiDraw.text(self, Vector2(at.x + 26.0, UiDraw.baseline(y, ROW - 8.0, 25)), rows[r][0], 25,
				UiDraw.DIM, HORIZONTAL_ALIGNMENT_LEFT, -1.0, null, 0)
		var x := at.x + CARD.x - 24.0
		var keys: Array = rows[r][1]
		for k in range(keys.size() - 1, -1, -1):
			x -= _key(Vector2(x, y), keys[k]) + 10.0


# A key cap ending at the right edge at.x; returns its width.
func _key(at: Vector2, key: String) -> float:
	var arrow: bool = ARROWS.has(key)
	var width := 44.0 if arrow else maxf(UiDraw.text_width(key, 22) + 24.0, 40.0)
	var rect := Rect2(at.x - width, at.y, width, ROW - 12.0)
	UiDraw.panel(self, Rect2(rect.position + Vector2(0, 4), rect.size), 8.0, Color("7d8496"),
			Color("5d6375"))
	UiDraw.panel(self, rect, 8.0, Color("f2f4f8"), Color("c4c9d4"), UiDraw.INK, 2.0)
	if arrow:
		var dir: Vector2 = ARROWS[key]
		var c := rect.get_center()
		draw_colored_polygon(PackedVector2Array([c + dir * 9.0, c + dir.orthogonal() * 8.0 - dir * 6.0,
				c - dir.orthogonal() * 8.0 - dir * 6.0]), Color("1b1e2a"))
	else:
		UiDraw.text(self, Vector2(rect.position.x, UiDraw.baseline(rect.position.y, rect.size.y, 22)),
				key, 22, Color("1b1e2a"), HORIZONTAL_ALIGNMENT_CENTER, width, UiDraw.bold(), 0)
	return width


func _diamond(at: Vector2, r: float) -> void:
	draw_colored_polygon(PackedVector2Array([at + Vector2(0, -r), at + Vector2(r, 0),
			at + Vector2(0, r), at + Vector2(-r, 0)]), UiDraw.GOLD)

# The training arena's backdrop: a clean lab. A cool dark wall with a fine grid, framed panels in
# front, each with a soft lamp strip. The stage is paneled.
extends RefCounted

const Kit := preload("res://scripts/view/backdrop_kit.gd")

var arena
var style := {"kind": "panel", "cap": "", "thin": "glass"}
var fog := Color("07080c")


func layers() -> Array:
	return [[0.95, false, "wall"], [0.6, false, "panels"]]


func wall(c: CanvasItem, _t: float) -> void:
	Kit.vgradient(c, [[0.0, Color("12151c")], [650.0, Color("222734")], [1000.0, Color("181b24")]])
	for k in range(-30, 60):
		var a: float = 0.09 if k % 5 == 0 else 0.04
		c.draw_line(Vector2(k * 80.0, -2400), Vector2(k * 80.0, 3600), Color(0.6, 0.7, 0.9, a), 2.0)
		c.draw_line(Vector2(-2600, k * 80.0), Vector2(4520, k * 80.0), Color(0.6, 0.7, 0.9, a), 2.0)


func panels(c: CanvasItem, _t: float) -> void:
	for i in range(-4, 9):
		var panel := Rect2(i * 420.0 - 120.0, 200.0, 360.0, 560.0)
		Kit.band(c, panel, Color("262c39"), Color("1d212b"))
		c.draw_rect(panel, Color("313a4b"), false, 4.0)
		Kit.glow(c, Vector2(panel.get_center().x, panel.position.y + 30.0), 220.0,
				Color(0.65, 0.8, 1.0, 0.14), 0.5)
		c.draw_rect(Rect2(panel.position.x + 110.0, panel.position.y + 24.0, 140.0, 6.0),
				Color("9fb8dc", 0.55))

# Draws the shots in flight (Kade's Spark): a glowing orb in its owner's color with a short tail.
extends Node2D

var sim
var colors: Array = []  # The players' colors.
var _ticks := 0


# Called every tick after the simulation step.
func sync() -> void:
	_ticks += 1
	queue_redraw()


func _draw() -> void:
	if sim == null:
		return
	for shot in sim.shots:
		var size: Vector2 = sim.shot_data(shot)["size"]
		var radius := size.x / 2.0
		var color: Color = colors[shot["owner"]] if shot["owner"] < colors.size() else Color.WHITE
		var at: Vector2 = shot["position"]
		var back: Vector2 = -shot["velocity"].normalized()
		for n in 4:  # The tail.
			draw_circle(at + back * radius * (n + 1) * 0.8, radius * (0.7 - n * 0.15),
					Color(color, 0.35 - n * 0.08))
		var pulse := 1.0 + 0.12 * sin(_ticks * 0.8)
		draw_circle(at, radius * 1.25 * pulse, Color(color.lightened(0.3), 0.45))
		draw_circle(at, radius * 0.8, color.lightened(0.5))
		draw_circle(at, radius * 0.4, Color.WHITE)

# A fighter standing in a menu: its match look drawn at the node's origin (the feet), breathing,
# with an optional springy pop, a fade in and one attack played as a pose. Drawing only; f is a
# FighterState the simulation never steps.
extends Node2D

const FighterLook := preload("res://scripts/view/fighter_look.gd")

const POP_TIME := 0.45

var f  # A FighterState, or null for nothing.
var color := Color.WHITE  # The player's color.
var size := 1.0  # The base scale.
var alpha := 1.0
var ticks := 0
var _breath := 0.0
var _pop := 0.0  # Seconds left of the pop.
var _attack_ticks := 0  # The length of the attack being played.


func _init() -> void:
	_breath = randf() * TAU  # Figures side by side breathe out of step.


# A short stretch and settle, for a pick or a ready.
func pop() -> void:
	_pop = POP_TIME


# Plays one of the fighter's attacks once (startup, active, recovery), then it breathes again.
func play(attack: String) -> void:
	if f == null or not f.stats.attacks.has(attack):
		return
	var a: Dictionary = f.stats.attacks[attack]
	f.attack = attack
	f.attack_ticks = 0
	_attack_ticks = a["startup"] + a["active"] + a["recovery"]


# The attack advances a tick per physics tick, as in the match.
func _physics_process(_delta: float) -> void:
	if f == null or f.attack == "":
		return
	f.attack_ticks += 1
	if f.attack_ticks > _attack_ticks:
		f.attack = ""
		f.attack_ticks = 0


func _process(delta: float) -> void:
	if f == null:
		return
	ticks += 1
	_breath += delta * 2.4
	_pop = maxf(_pop - delta, 0.0)
	var stretch := sin(_breath) * 0.018
	if _pop > 0.0:
		var t := POP_TIME - _pop
		stretch += sin(t * 22.0) * 0.16 * (_pop / POP_TIME)
	scale = Vector2(size * (1.0 - stretch * 0.5), size * (1.0 + stretch))
	# A fighter drawing costs about 1.5 ms: the slow idle pose redraws every second frame (the
	# breathing is the scale above, smooth anyway); an attack or a fade redraws every frame.
	if ticks % 2 == 0 or f.attack != "" or alpha < 1.0:
		queue_redraw()


func _draw() -> void:
	if f != null and alpha > 0.0:
		FighterLook.draw(self, f, color, Color(1, 1, 1, alpha), Vector2.ZERO, ticks)

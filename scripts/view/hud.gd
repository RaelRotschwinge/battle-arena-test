# The match HUD: a card per player along the bottom of the screen (portrait, name, damage, lives),
# a "GO!" banner when the match starts, "GAME!" and the winner when it ends, and a short screen
# flash for the strongest hits and knockouts. It lies above the arena and the screen effects.
extends CanvasLayer

const FighterState := preload("res://scripts/sim/fighter_state.gd")
const FighterLook := preload("res://scripts/view/fighter_look.gd")

const CARD_SIZE := Vector2(360.0, 112.0)
const CARD_GAP := 18.0
const BOTTOM := 70.0  # Room under the cards for the controls line.
const INK := Color(0.043, 0.047, 0.067)
const FLASH_TIME := 0.2

var sim
var colors: Array = []
var labels: Array = []  # Per fighter: the player's name, for example "P1" or "CPU 1".

var _root: Control
var _flash: ColorRect
var _flash_strength := 0.0
var _flash_age := 0.0
var _cards := []
var _pointers := []  # Per fighter: its bubble at the screen edge while it is out of view.
var _banner: Banner
var _bold: FontVariation


func _ready() -> void:
	layer = 2
	_bold = FontVariation.new()
	_bold.base_font = ThemeDB.fallback_font
	_bold.variation_embolden = 0.9
	_bold.variation_transform = Transform2D(Vector2(1.0, 0.0), Vector2(-0.12, 1.0), Vector2.ZERO)
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_flash = ColorRect.new()
	_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.color = Color(1, 1, 1, 0)
	_root.add_child(_flash)
	_banner = Banner.new()
	_banner.font = _bold
	_banner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_banner)


func _process(delta: float) -> void:
	var to_screen := get_viewport().get_canvas_transform()
	var screen := get_viewport().get_visible_rect()
	for pointer in _pointers:
		pointer.place(to_screen, screen, delta)
	if _flash_strength > 0.0:
		_flash_age += delta
		var t := clampf(_flash_age / FLASH_TIME, 0.0, 1.0)
		_flash.color.a = _flash_strength * (1.0 - t) * (1.0 - t)
		if t >= 1.0:
			_flash_strength = 0.0


# Builds the player cards for a new match and shows "GO!".
func reset() -> void:
	for node in _cards + _pointers:
		node.queue_free()
	_cards.clear()
	_pointers.clear()
	var count: int = sim.fighters.size()
	for i in count:
		var pointer := Pointer.new()
		pointer.fighter = sim.fighters[i]
		pointer.color = colors[i]
		pointer.keep_free = BOTTOM + CARD_SIZE.y
		_root.add_child(pointer)
		_pointers.append(pointer)
		var card := Card.new()
		card.fighter = sim.fighters[i]
		card.color = colors[i]
		card.label = labels[i]
		card.font = _bold
		card.anchor_left = 0.5
		card.anchor_right = 0.5
		card.anchor_top = 1.0
		card.anchor_bottom = 1.0
		card.offset_left = (i - count / 2.0) * (CARD_SIZE.x + CARD_GAP) + CARD_GAP / 2.0
		card.offset_right = card.offset_left + CARD_SIZE.x
		card.offset_top = -BOTTOM - CARD_SIZE.y
		card.offset_bottom = -BOTTOM
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_root.add_child(card)
		_root.move_child(_banner, -1)
		_cards.append(card)
	_banner.show_text("GO!", "", Color("ffe14d"), Color("d9480f"), 0.95)
	_flash_strength = 0.0
	_flash.color.a = 0.0
	refresh()


# Called every tick after the simulation step.
func refresh() -> void:
	for card in _cards:
		card.refresh()


# A short flash of the whole arena (not of the HUD): strength is its alpha at the start.
func flash(color: Color, strength: float) -> void:
	if strength < _flash.color.a:
		return
	_flash.color = Color(color, strength)
	_flash_strength = strength
	_flash_age = 0.0


func hide_winner() -> void:
	_banner.hide_text()


# "GAME!" with the winner under it. The match goes on underneath (the results come after it).
func show_winner(_can_restart: bool) -> void:
	var line := "Draw!"
	var color := Color("d9480f")
	_banner.sub_color = Color.WHITE
	if sim.winner >= 0:
		line = "%s wins!" % labels[sim.winner]
		color = colors[sim.winner]
		_banner.sub_color = color
		_cards[sim.winner].winner = true
	_banner.show_text("GAME!", line, Color.WHITE, color, 0.0)


# One player's card: a portrait of the fighter, the player's name and fighter, the damage that
# pops and shakes when hit and warms from white to red, and a token per life.
class Card extends Control:
	const STOCK_RADIUS := 10.0
	const POP_TIME := 0.45
	const DANGER := 120.0  # From this damage the portrait frame pulses red.
	const DAMAGE_STOPS := [[0.0, Color("ffffff")], [35.0, Color("fff0a0")],
			[70.0, Color("ffb347")], [110.0, Color("ff5a3c")], [160.0, Color("d41c3c")]]

	var fighter
	var color := Color.WHITE
	var label := ""
	var font: Font
	var winner := false
	var _glow_age := 0.0
	var _portrait: Portrait
	var _style := StyleBoxFlat.new()
	var _last_damage := 0.0
	var _pop := 0.0  # Strength of the pop of the last hit, 0 for none.
	var _pop_age := 10.0
	var _shown_stocks := 0
	var _lost_age := 10.0  # Seconds since a life was lost, for the token popping away.
	var _ticks := 0
	var _dirty := true  # Something changed since the last drawing.

	func _ready() -> void:
		_style.bg_color = Color(0.05, 0.058, 0.085, 0.9)
		_style.set_corner_radius_all(20)
		_style.border_color = color
		_style.border_width_top = 4
		_style.shadow_color = Color(0, 0, 0, 0.35)
		_style.shadow_size = 10
		_style.anti_aliasing = true
		var frame := Control.new()  # Clips the portrait to its square.
		frame.clip_contents = true
		frame.position = Vector2(12.0, 10.0)
		frame.size = Vector2(92.0, 92.0)
		frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.draw.connect(_frame_back.bind(frame))
		add_child(frame)
		_portrait = Portrait.new()
		_portrait.color = color
		_portrait.pose = FighterState.new()
		_portrait.pose.stats = fighter.stats
		_portrait.pose.mode = FighterState.Mode.GROUND
		var h: float = fighter.stats.height
		var zoom := 140.0 / h  # The head and shoulders fill the square.
		_portrait.scale = Vector2(zoom, zoom)
		_portrait.position = Vector2(46.0, 14.0 + h * zoom)
		frame.add_child(_portrait)
		_last_damage = fighter.damage
		_shown_stocks = fighter.stocks

	func _frame_back(frame: Control) -> void:
		var tone := Color(0.4, 0.42, 0.48) if fighter.out else color  # Out: grey.
		var back := StyleBoxFlat.new()
		back.bg_color = tone.darkened(0.45)
		back.set_corner_radius_all(14)
		back.anti_aliasing = true
		frame.draw_style_box(back, Rect2(Vector2.ZERO, frame.size))
		frame.draw_circle(Vector2(46.0, 40.0), 40.0, Color(tone, 0.55), true, -1.0, true)

	func refresh() -> void:
		_ticks += 1
		var gain: float = fighter.damage - _last_damage
		if gain > 0.0:
			_pop = clampf(gain / 18.0, 0.25, 0.6)
			_pop_age = 0.0
			_portrait.hurt = 0.18
		if fighter.damage != _last_damage or fighter.stocks != _shown_stocks:
			_dirty = true
		_last_damage = fighter.damage
		if fighter.stocks < _shown_stocks:
			_lost_age = 0.0
		_shown_stocks = fighter.stocks
		if _portrait.out != fighter.out:
			_portrait.get_parent().queue_redraw()  # The frame turns grey.
			_dirty = true
		_portrait.out = fighter.out
		modulate.a = 0.55 if fighter.out else 1.0

	func _process(delta: float) -> void:
		_pop_age += delta
		_lost_age += delta
		_glow_age += delta
		_portrait.tick(delta)
		# A lost life jolts the whole card: a quick wobble and bump that settle.
		var settle := exp(-8.0 * _lost_age) if _lost_age < 0.6 else 0.0
		pivot_offset = size / 2.0
		rotation = 0.07 * settle * sin(_lost_age * 38.0)
		scale = Vector2.ONE * (1.0 + 0.1 * settle)
		# Redraw only while something moves: a pop, a lost life, the winner's or danger glow.
		var moving: bool = (_pop_age < POP_TIME + 0.05 or _lost_age < 0.5 or winner
				or fighter.damage >= 100.0 and not fighter.out)
		if moving or _dirty:
			_dirty = false
			queue_redraw()

	func _draw() -> void:
		draw_style_box(_style, Rect2(Vector2.ZERO, size))
		if winner:  # A glowing rim that breathes.
			_rim(Rect2(Vector2.ZERO, size).grow(3.0), 22,
					Color(color.lightened(0.3), 0.6 + 0.4 * sin(_glow_age * 6.0)), 0.0)
		if fighter.damage >= DANGER and not fighter.out:  # In danger: the portrait glows red.
			var pulse := 0.5 + 0.5 * sin(_glow_age * 7.0)
			_rim(Rect2(12.0, 10.0, 92.0, 92.0).grow(3.0), 16,
					Color(1.0, 0.23, 0.19, 0.55 + 0.45 * pulse), 4.0 + 10.0 * pulse)
		draw_string_outline(font, Vector2(118.0, 40.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 27,
				6, INK)
		draw_string(font, Vector2(118.0, 40.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 27,
				color.lightened(0.15))
		draw_string(ThemeDB.fallback_font, Vector2(119.0, 66.0), fighter.stats.fighter_name,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(0.82, 0.85, 0.92, 0.85))
		_draw_stocks()
		_draw_damage()

	func _draw_stocks() -> void:
		var shown: int = fighter.stocks
		var at := Vector2(118.0 + STOCK_RADIUS, 88.0)
		if shown >= 99:  # Endless lives (training): no tokens.
			return
		if shown > 5:  # Many lives: one token and the count.
			_token(at, 1.0, 1.0)
			draw_string(font, at + Vector2(16.0, 8.0), "x%d" % shown, HORIZONTAL_ALIGNMENT_LEFT,
					-1, 22, Color.WHITE)
			return
		for n in shown:
			_token(at + Vector2(n * 25.0, 0.0), 1.0, 1.0)
		if _lost_age < 0.45:  # The lost life bursts: a fading token in a widening ring.
			var t := _lost_age / 0.45
			var spot := at + Vector2(shown * 25.0, 0.0)
			draw_circle(spot, STOCK_RADIUS * (1.0 - t), Color(color, 1.0 - t), true, -1.0, true)
			draw_arc(spot, STOCK_RADIUS * (1.0 + 1.6 * t), 0.0, TAU, 24, Color(1, 1, 1, 1.0 - t),
					3.0 * (1.0 - t) + 1.0, true)

	# A rounded border of color c around rect, with a glow of that size around it.
	func _rim(rect: Rect2, radius: int, c: Color, glow: float) -> void:
		var rim := StyleBoxFlat.new()
		rim.draw_center = false
		rim.set_corner_radius_all(radius)
		rim.set_border_width_all(4)
		rim.border_color = c
		rim.shadow_color = Color(c, c.a * 0.5)
		rim.shadow_size = int(glow)
		rim.anti_aliasing = true
		draw_style_box(rim, rect)

	func _token(at: Vector2, grow: float, alpha: float) -> void:
		var r := STOCK_RADIUS * grow
		draw_circle(at, r + 2.5, Color(INK, 0.9 * alpha), true, -1.0, true)
		draw_circle(at, r, Color(color, alpha), true, -1.0, true)
		draw_circle(at + Vector2(-r * 0.3, -r * 0.3), r * 0.38, Color(1, 1, 1, 0.55 * alpha),
				true, -1.0, true)

	func _draw_damage() -> void:
		var right := size.x - 52.0
		var base := 88.0
		if fighter.out:
			draw_string_outline(font, Vector2(right - 90.0, base), "OUT", HORIZONTAL_ALIGNMENT_LEFT,
					-1, 52, 10, INK)
			draw_string(font, Vector2(right - 90.0, base), "OUT", HORIZONTAL_ALIGNMENT_LEFT, -1, 52,
					Color(0.6, 0.62, 0.7))
			return
		var text := "%d" % int(fighter.damage)
		var fs := 72
		var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var middle := Vector2(right - width / 2.0, base - 26.0)
		var grow := 1.0
		var jolt := Vector2.ZERO
		if _pop_age < POP_TIME:  # A damped spring: big at once, wobbling back to rest.
			grow += _pop * exp(-7.0 * _pop_age) * cos(16.0 * _pop_age)
			var shake := _pop * 22.0 * exp(-12.0 * _pop_age)
			jolt = Vector2(sin(_pop_age * 90.0), cos(_pop_age * 73.0)) * shake
		if fighter.damage >= 100.0:  # In danger: the number throbs.
			grow += 0.04 * (0.5 + 0.5 * sin(_ticks * 0.25))
		var c := damage_color(fighter.damage)
		if _pop_age < 0.08:
			c = Color.WHITE
		draw_set_transform(middle + jolt, 0.0, Vector2(grow, grow))
		var at := Vector2(-width / 2.0, 26.0)
		draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 14, INK)
		draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, c)
		draw_string_outline(font, at + Vector2(width + 4.0, 0.0), "%", HORIZONTAL_ALIGNMENT_LEFT,
				-1, 34, 9, INK)
		draw_string(font, at + Vector2(width + 4.0, 0.0), "%", HORIZONTAL_ALIGNMENT_LEFT, -1, 34,
				c.darkened(0.1))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	static func damage_color(damage: float) -> Color:
		for n in range(1, DAMAGE_STOPS.size()):
			if damage <= DAMAGE_STOPS[n][0]:
				var from: Array = DAMAGE_STOPS[n - 1]
				var to: Array = DAMAGE_STOPS[n]
				return from[1].lerp(to[1], (damage - from[0]) / (to[0] - from[0]))
		return DAMAGE_STOPS[-1][1]


# A bubble at the screen edge for a fighter out of view: the player's color, an arrow towards the
# fighter and its portrait inside; the farther away the fighter, the smaller the bubble.
class Pointer extends Node2D:
	const NEAR := 50.0  # Radius just past the screen edge,
	const FAR := 34.0  # and from FAR_DISTANCE screen pixels outside on.
	const FAR_DISTANCE := 900.0

	var fighter
	var color := Color.WHITE
	var keep_free := 0.0  # Screen height kept free at the bottom, for the cards.
	var _radius := NEAR
	var _aim := Vector2.RIGHT
	var _bubble := Node2D.new()  # Its disk clips the portrait.
	var _portrait := Portrait.new()
	var _rim := Node2D.new()

	func _ready() -> void:
		visible = false
		_bubble.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
		_bubble.draw.connect(_draw_bubble)
		add_child(_bubble)
		_portrait.color = color
		_portrait.pose = FighterState.new()
		_portrait.pose.stats = fighter.stats
		_portrait.pose.mode = FighterState.Mode.GROUND
		_bubble.add_child(_portrait)
		_rim.draw.connect(_draw_rim)
		add_child(_rim)

	# Shows the bubble when the fighter's middle is off screen, at the nearest edge.
	func place(to_screen: Transform2D, screen: Rect2, delta: float) -> void:
		var middle: Vector2 = fighter.position - Vector2(0.0, fighter.stats.height / 2.0)
		var spot := to_screen * middle
		visible = not fighter.out and not screen.grow(-10.0).has_point(spot)
		if not visible:
			return
		var outside := spot.distance_to(spot.clamp(screen.position, screen.end))
		_radius = lerpf(NEAR, FAR, clampf(outside / FAR_DISTANCE, 0.0, 1.0))
		var inset := NEAR + 22.0
		position = Vector2(clampf(spot.x, screen.position.x + inset, screen.end.x - inset),
				clampf(spot.y, screen.position.y + inset, screen.end.y - keep_free - inset))
		_aim = (spot - position).normalized()
		var k := _radius * 2.0 / 92.0  # The card portrait's framing, scaled to the bubble.
		_portrait.scale = Vector2.ONE * 140.0 / fighter.stats.height * k
		_portrait.position = Vector2(0.0, 108.0 * k)
		_portrait.tick(delta)
		queue_redraw()
		_bubble.queue_redraw()
		_rim.queue_redraw()

	func _draw() -> void:  # The arrow, behind the bubble.
		var side := _aim.orthogonal() * _radius * 0.55
		var base := _aim * _radius * 0.5
		var tip := _aim * (_radius + 18.0)
		draw_primitive(PackedVector2Array([tip + _aim * 5.0, base + side * 1.2, base - side * 1.2]),
				PackedColorArray([INK, INK, INK]), PackedVector2Array())
		draw_primitive(PackedVector2Array([tip, base + side, base - side]),
				PackedColorArray([color, color, color]), PackedVector2Array())

	func _draw_bubble() -> void:
		var k := _radius * 2.0 / 92.0
		_bubble.draw_circle(Vector2.ZERO, _radius, color.darkened(0.45), true, -1.0, true)
		_bubble.draw_circle(Vector2(0.0, -6.0 * k), 40.0 * k, Color(color, 0.55), true, -1.0, true)

	func _draw_rim() -> void:
		_rim.draw_arc(Vector2.ZERO, _radius, 0.0, TAU, 48, INK, 7.0, true)
		_rim.draw_arc(Vector2.ZERO, _radius - 2.0, 0.0, TAU, 48, color.lightened(0.25), 3.5, true)


# The fighter's head and shoulders in a card, drawn with its look in a resting pose.
class Portrait extends Node2D:
	var pose  # A fighter state standing still, only for drawing.
	var color := Color.WHITE
	var hurt := 0.0  # Seconds left of the flash and shake of a hit.
	var out := false
	var _ticks := 0
	var _drawn_out := false

	# Redraws only while a hit flashes or shakes it (and once after): drawing a fighter is costly,
	# and a resting portrait does not change.
	func tick(delta: float) -> void:
		_ticks += 1
		var was := hurt
		hurt = maxf(hurt - delta, 0.0)
		if hurt > 0.0 or was > 0.0 or out != _drawn_out:
			queue_redraw()

	func _draw() -> void:
		var tint := Color(1, 1, 1, 1)
		var shake := Vector2.ZERO
		if hurt > 0.0:
			tint = Color(1.5, 1.5, 1.5) if hurt > 0.12 else Color(1.2, 1.2, 1.2)
			shake.x = 4.0 if _ticks % 2 == 0 else -4.0
		if out:
			tint = Color(0.5, 0.5, 0.56)
		_drawn_out = out
		FighterLook.draw(self, pose, color, tint, shake, 0)


# A big word across the middle of the screen on a dark band, scaled in with an overshoot: "GO!"
# for a while, or "GAME!" with a line under it until hidden.
class Banner extends Control:
	var font: Font
	var sub_color := Color.WHITE
	var _text := ""
	var _sub := ""
	var _fill := Color.WHITE
	var _shadow := Color.BLACK
	var _life := 0.0  # Seconds it shows, 0 until hidden.
	var _age := 0.0

	func show_text(text: String, sub: String, fill: Color, shadow: Color, life: float) -> void:
		_text = text
		_sub = sub
		_fill = fill
		_shadow = shadow
		_life = life
		_age = 0.0
		queue_redraw()

	func hide_text() -> void:
		_text = ""
		queue_redraw()

	func _process(delta: float) -> void:
		if _text == "":
			return
		_age += delta
		if _life > 0.0 and _age >= _life:
			_text = ""
		queue_redraw()

	func _draw() -> void:
		if _text == "":
			return
		var t_in := clampf(_age / 0.28, 0.0, 1.0)
		var t_out := 0.0 if _life <= 0.0 else clampf((_age - (_life - 0.22)) / 0.22, 0.0, 1.0)
		var middle := Vector2(size.x / 2.0, size.y * 0.3)
		var band := 230.0 * _out(clampf(_age / 0.18, 0.0, 1.0)) * (1.0 - _out(t_out))
		if band > 1.0:
			draw_rect(Rect2(0.0, middle.y - band / 2.0, size.x, band), Color(INK, 0.45))
			draw_rect(Rect2(0.0, middle.y - band / 2.0 - 3.0, size.x, 3.0), Color(_shadow, 0.9))
			draw_rect(Rect2(0.0, middle.y + band / 2.0, size.x, 3.0), Color(_shadow, 0.9))
		var grow := 0.2 + 0.8 * _back(t_in) + 0.35 * t_out
		var alpha := 1.0 - t_out
		var turn := lerpf(-0.22, -0.05, _out(t_in))
		var fs := 200
		var width := font.get_string_size(_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var base := (font.get_ascent(fs) - font.get_descent(fs)) / 2.0
		draw_set_transform(middle, turn, Vector2(grow, grow))
		var at := Vector2(-width / 2.0, base)
		draw_string_outline(font, at + Vector2(10.0, 10.0), _text, HORIZONTAL_ALIGNMENT_LEFT,
				-1, fs, 26, Color(INK, alpha))
		draw_string(font, at + Vector2(10.0, 10.0), _text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs,
				Color(_shadow, alpha))
		draw_string_outline(font, at, _text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 26,
				Color(INK, alpha))
		draw_string(font, at, _text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(_fill, alpha))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		if _sub != "" and _age > 0.35:
			var t := _out(clampf((_age - 0.35) / 0.25, 0.0, 1.0))
			var sub_width := font.get_string_size(_sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 64).x
			var sub_at := Vector2(middle.x - sub_width / 2.0, middle.y + 190.0 + 30.0 * (1.0 - t))
			draw_string_outline(font, sub_at, _sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 64, 14,
					Color(INK, t))
			draw_string(font, sub_at, _sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 64, Color(sub_color, t))

	static func _out(t: float) -> float:
		return 1.0 - pow(1.0 - t, 3.0)

	static func _back(t: float) -> float:
		var x := t - 1.0
		return 1.0 + 2.70158 * x * x * x + 1.70158 * x * x

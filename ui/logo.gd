# The title logo of the main menu, drawn in code: "BATTLE" on a slanted red banner and a big gold
# "ARENA" with a dark extrude, thick outlines, a gradient fill and a shine that sweeps across. It
# drops in when shown and floats gently.
extends Control

const UiDraw := preload("res://ui/ui_draw.gd")

const SIZE := Vector2(1300, 360)
const SMALL := 104
const BIG := 220
const SMALL_BASE := 118.0  # Baselines.
const BIG_BASE := 318.0
const RED := Color("e8553e")
const BLUE := Color("3e8fe8")
const SHADER := """
shader_type canvas_item;
uniform vec4 top_color : source_color;
uniform vec4 bottom_color : source_color;
uniform float top_y;
uniform float bottom_y;
uniform float shine_x;
varying vec2 local;

void vertex() {
	local = VERTEX;
}

void fragment() {
	float t = clamp((local.y - top_y) / (bottom_y - top_y), 0.0, 1.0);
	vec3 c = mix(top_color.rgb, bottom_color.rgb, t);
	float band = 1.0 - smoothstep(10.0, 46.0, abs(local.x + local.y * 0.45 - shine_x));
	COLOR = vec4(mix(c, vec3(1.0), band * 0.75), COLOR.a);
}
"""

var _t := 0.0
var _font: FontVariation
var _fill: Control
var _material: ShaderMaterial


func _init() -> void:
	custom_minimum_size = SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = FontVariation.new()
	_font.base_font = ThemeDB.fallback_font
	_font.variation_embolden = 1.1
	_font.spacing_glyph = 4
	var shader := Shader.new()
	shader.code = SHADER
	_material = ShaderMaterial.new()
	_material.shader = shader
	_material.set_shader_parameter("top_color", Color("fff6d0"))
	_material.set_shader_parameter("bottom_color", Color("ffa62b"))
	_material.set_shader_parameter("top_y", BIG_BASE - BIG * 0.72)
	_material.set_shader_parameter("bottom_y", BIG_BASE)
	_fill = Control.new()
	_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fill.material = _material
	_fill.size = SIZE
	_fill.draw.connect(_draw_fill)
	add_child(_fill)


# Plays the drop-in again.
func intro() -> void:
	_t = 0.0


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_t += delta
	modulate.a = clampf(_t / 0.25, 0.0, 1.0)
	_fill.size = size
	# The shine crosses in 0.9 s, then rests for 3 s.
	var sweep := fposmod(_t - 0.6, 3.9) / 0.9
	_material.set_shader_parameter("shine_x", lerpf(-200.0, size.x + 300.0, sweep))
	queue_redraw()
	_fill.queue_redraw()


# Drop in with an overshoot, then float.
func _place(canvas: CanvasItem) -> void:
	var s := lerpf(1.35, 1.0, UiDraw.out_back(_t / 0.55))
	var center := size / 2.0
	var float_y := sin(_t * 1.6) * 6.0
	canvas.draw_set_transform(center - center * s + Vector2(0.0, float_y), 0.0, Vector2(s, s))


func _draw() -> void:
	_place(self)
	var cx := size.x / 2.0
	var small_w := UiDraw.text_width("BATTLE", SMALL, _font)
	# The banner behind "BATTLE": a slanted red blade with a blue edge.
	var half := small_w / 2.0 + 70.0
	var top := SMALL_BASE - SMALL * 0.86
	var bottom := SMALL_BASE + 18.0
	var skew := 34.0
	var blue := PackedVector2Array([Vector2(cx - half - 18 + skew, top + 12),
			Vector2(cx + half + 30 + skew, top + 12), Vector2(cx + half + 30, bottom + 12),
			Vector2(cx - half - 18, bottom + 12)])
	_shape(blue, BLUE.darkened(0.1), BLUE.darkened(0.35))
	var red := PackedVector2Array([Vector2(cx - half + skew, top), Vector2(cx + half + skew, top),
			Vector2(cx + half, bottom), Vector2(cx - half, bottom)])
	_shape(red, RED.lightened(0.1), RED.darkened(0.25))
	_word("BATTLE", SMALL, SMALL_BASE, 14, Color.WHITE)
	# "ARENA": extrude, outlines; the gradient fill is drawn by _fill.
	for n in range(12, 0, -2):
		_word("ARENA", BIG, BIG_BASE + n, 26, Color("2a1408"), false)
	_word("ARENA", BIG, BIG_BASE, 26, UiDraw.INK, false)
	_word("ARENA", BIG, BIG_BASE, 12, Color("b3461f"), false)


func _draw_fill() -> void:
	_place(_fill)
	_fill.draw_string(_font, Vector2(0, BIG_BASE), "ARENA", HORIZONTAL_ALIGNMENT_CENTER, size.x,
			BIG, Color.WHITE)


func _shape(points: PackedVector2Array, top: Color, bottom: Color) -> void:
	draw_polygon(points, PackedColorArray([top, top, bottom, bottom]))
	var closed := points.duplicate()
	closed.append(points[0])
	draw_polyline(closed, UiDraw.INK, 6.0, true)


# One word centered, its outline only (fill false) or outline and fill.
func _word(value: String, font_size: int, base: float, outline: int, color: Color,
		fill: bool = true) -> void:
	var at := Vector2(0, base)
	if fill:
		draw_string_outline(_font, at, value, HORIZONTAL_ALIGNMENT_CENTER, size.x, font_size,
				outline, UiDraw.INK)
		draw_string(_font, at, value, HORIZONTAL_ALIGNMENT_CENTER, size.x, font_size, color)
	else:
		draw_string_outline(_font, at, value, HORIZONTAL_ALIGNMENT_CENTER, size.x, font_size,
				outline, color)

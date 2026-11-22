# Drawing helpers shared by the menu screens: rounded panels with a vertical gradient, soft glows,
# chips with text and outlined text. Filled polygons get an antialiased edge drawn on top, since
# the Compatibility renderer has no 2D MSAA.
extends RefCounted

const INK := Color(0.067, 0.075, 0.102, 0.9)  # The outline color of the art direction.
const GOLD := Color("ffd24a")
const DIM := Color("9aa0b0")
const PANEL_TOP := Color("2b3146")
const PANEL_BOTTOM := Color("181c28")
const SLOT := Color("3a4052")  # Empty pips, chips and frames.
const PLAYER_COLORS := [Color("e8553e"), Color("3e8fe8"), Color("e8c33e"), Color("4ec96a")]

static var _glow: GradientTexture2D
static var _bold: FontVariation


# The default font made heavier, for titles and names.
static func bold() -> Font:
	if _bold == null:
		_bold = FontVariation.new()
		_bold.base_font = ThemeDB.fallback_font
		_bold.variation_embolden = 0.6
	return _bold


# The outline of a rectangle with round corners, clockwise from the top right corner.
static func rounded(rect: Rect2, radius: float, steps: int = 6) -> PackedVector2Array:
	var points := PackedVector2Array()
	var r := minf(radius, minf(rect.size.x, rect.size.y) / 2.0)
	var corners := [Vector2(rect.end.x - r, rect.position.y + r), rect.end - Vector2(r, r),
			Vector2(rect.position.x + r, rect.end.y - r), rect.position + Vector2(r, r)]
	for c in 4:
		for n in steps + 1:
			var turn := -PI / 2.0 + (c + float(n) / steps) * PI / 2.0
			var p: Vector2 = corners[c] + Vector2(cos(turn), sin(turn)) * r
			# A pill's corners meet: a repeated point breaks the triangulation.
			if points.is_empty() or p.distance_squared_to(points[-1]) > 0.01:
				points.append(p)
	if points.size() > 1 and points[0].distance_squared_to(points[-1]) <= 0.01:
		points.remove_at(points.size() - 1)
	return points


# A rounded panel shading from top to bottom, with an optional border.
static func panel(canvas: CanvasItem, rect: Rect2, radius: float, top: Color, bottom: Color,
		border: Color = Color(0, 0, 0, 0), border_width: float = 2.0) -> void:
	var points := rounded(rect, radius)
	var colors := PackedColorArray()
	for p in points:
		colors.append(top.lerp(bottom, clampf((p.y - rect.position.y) / rect.size.y, 0.0, 1.0)))
	canvas.draw_polygon(points, colors)
	points.append(points[0])
	colors.append(colors[0])
	if border.a > 0.0:
		canvas.draw_polyline(points, border, border_width, true)
	else:
		canvas.draw_polyline_colors(points, colors, 1.0, true)


# A soft round glow, strongest in the middle.
static func glow(canvas: CanvasItem, center: Vector2, radius: Vector2, color: Color) -> void:
	if _glow == null:
		var gradient := Gradient.new()
		gradient.set_color(0, Color(1, 1, 1, 1))
		gradient.set_color(1, Color(1, 1, 1, 0))
		gradient.add_point(0.4, Color(1, 1, 1, 0.45))
		_glow = GradientTexture2D.new()
		_glow.gradient = gradient
		_glow.fill = GradientTexture2D.FILL_RADIAL
		_glow.fill_from = Vector2(0.5, 0.5)
		_glow.fill_to = Vector2(1.0, 0.5)
		_glow.width = 128
		_glow.height = 128
	canvas.draw_texture_rect(_glow, Rect2(center - radius, radius * 2.0), false, color)


# Text with the dark outline of the art direction. at is the left end of the baseline.
static func text(canvas: CanvasItem, at: Vector2, value: String, font_size: int, color: Color,
		align: int = HORIZONTAL_ALIGNMENT_LEFT, width: float = -1.0, font: Font = null,
		outline: int = 8) -> void:
	if font == null:
		font = ThemeDB.fallback_font
	if outline > 0:
		canvas.draw_string_outline(font, at, value, align, width, font_size, outline,
				Color(INK, INK.a * color.a))
	canvas.draw_string(font, at, value, align, width, font_size, color)


# The baseline that centers one line of text vertically in a box from top with this height.
static func baseline(top: float, height: float, font_size: int, font: Font = null) -> float:
	if font == null:
		font = ThemeDB.fallback_font
	return top + (height + font.get_ascent(font_size) - font.get_descent(font_size)) / 2.0


static func text_width(value: String, font_size: int, font: Font = null) -> float:
	if font == null:
		font = ThemeDB.fallback_font
	return font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x


# A pill with centered text.
static func chip(canvas: CanvasItem, rect: Rect2, value: String, font_size: int, fill: Color,
		text_color: Color = Color.WHITE, border: Color = Color(0, 0, 0, 0)) -> void:
	panel(canvas, rect, rect.size.y / 2.0, fill.lightened(0.08), fill.darkened(0.12), border)
	text(canvas, Vector2(rect.position.x, baseline(rect.position.y, rect.size.y, font_size)),
			value, font_size, text_color, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, null, 0)


static func chip_width(value: String, font_size: int) -> float:
	return text_width(value, font_size) + font_size * 1.3


# A chevron pointing left (-1) or right (1).
static func chevron(canvas: CanvasItem, at: Vector2, size: float, direction: int,
		color: Color) -> void:
	var points := PackedVector2Array([at + Vector2(-direction * size * 0.5, -size),
			at + Vector2(direction * size * 0.5, 0.0), at + Vector2(-direction * size * 0.5, size)])
	canvas.draw_polyline(points, Color(INK, INK.a * color.a), size * 0.55 + 6.0, true)
	canvas.draw_polyline(points, color, size * 0.55, true)


static func out_cubic(t: float) -> float:
	t = clampf(t, 0.0, 1.0)
	return 1.0 - pow(1.0 - t, 3.0)


static func out_back(t: float) -> float:
	t = clampf(t, 0.0, 1.0)
	return 1.0 + 2.70158 * pow(t - 1.0, 3.0) + 1.70158 * pow(t - 1.0, 2.0)

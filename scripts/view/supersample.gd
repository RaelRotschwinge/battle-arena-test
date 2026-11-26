# The window's root (game design, "Technical design"): the whole game is drawn at twice the
# window's pixels in a SubViewport and shown scaled down, a supersampling that smooths every edge
# of the shapes and texts drawn in code (the Compatibility renderer has no 2D MSAA). The game
# itself (scenes/main.tscn) runs inside it laid out for 1920 x 1080 as before (expand). Input
# events are passed on; gamepads and held keys are read globally and need nothing. On top lies
# the color grade (screen_fx.gd). The saved options are applied at start (settings.gd); F11
# switches between window and full screen and saves that as the Full screen option.
extends Node

const GAME := preload("res://scenes/main.tscn")
const ScreenFx := preload("res://scripts/view/screen_fx.gd")
const Settings := preload("res://scripts/view/settings.gd")
const BASE := Vector2(1920.0, 1080.0)
const MAX_PIXELS := 3840.0 * 2160.0  # Bigger windows get a smaller factor, to bound the cost.

var factor := 2.0
var _viewport: SubViewport
var _view: TextureRect


func _ready() -> void:
	var window := get_tree().root
	window.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	_viewport = SubViewport.new()
	_viewport.size_2d_override_stretch = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_viewport)
	_viewport.add_child(GAME.instantiate())
	var grade := ScreenFx.new()
	grade.layer = 1  # Over the match and the select screens; the HUD (2) and overlays stay crisp.
	_viewport.add_child(grade)
	_view = TextureRect.new()
	_view.texture = _viewport.get_texture()
	_view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_view.stretch_mode = TextureRect.STRETCH_SCALE
	_view.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_view)
	window.size_changed.connect(_fit)
	_fit()
	Settings.apply()


# Follows the window: the drawing size is the window's pixels times the factor, the layout stays
# 1920 x 1080 widened to the window's shape.
func _fit() -> void:
	var pixels := Vector2(get_tree().root.size)
	if pixels.x < 1.0 or pixels.y < 1.0:
		return
	factor = clampf(sqrt(MAX_PIXELS / (pixels.x * pixels.y)), 1.0, 2.0)
	_viewport.size = Vector2i((pixels * factor).round())
	var layout := BASE
	if pixels.x / pixels.y > BASE.x / BASE.y:
		layout.x = BASE.y * pixels.x / pixels.y
	else:
		layout.y = BASE.x * pixels.y / pixels.x
	_viewport.size_2d_override = Vector2i(layout.round())
	_view.position = Vector2.ZERO
	_view.size = pixels


func _input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.physical_keycode == KEY_F11:
		var full := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
		Settings.change("fullscreen", not full)
		return
	var passed := event
	if event is InputEventMouse:
		# Mouse positions go in as layout coordinates (1920 x 1080 widened), not drawing pixels.
		var to_layout := Vector2(_viewport.size_2d_override) / Vector2(get_tree().root.size)
		passed = event.duplicate()
		passed.position *= to_layout
		passed.global_position *= to_layout
	_viewport.push_input(passed, true)

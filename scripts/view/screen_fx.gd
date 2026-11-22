# A finishing pass over the whole picture (game design, "Art style"): a soft vignette that pulls
# the eye to the middle and a light color grade (a touch more contrast and saturation, warm
# highlights, cool shadows). One full-screen rect with a shader that reads the screen; the HUD and
# menus above it stay untouched.
extends CanvasLayer

const SHADER := """
shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float vignette = 0.32;
uniform float saturation = 1.08;
uniform float contrast = 1.06;
uniform vec3 warm = vec3(1.03, 1.0, 0.96);
uniform vec3 cool = vec3(0.96, 0.99, 1.05);

void fragment() {
	vec3 c = texture(screen_texture, SCREEN_UV).rgb;
	float luma = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(vec3(luma), c, saturation);
	c = (c - 0.5) * contrast + 0.5;
	c *= mix(cool, warm, smoothstep(0.2, 0.8, luma));
	vec2 d = (SCREEN_UV - 0.5) * vec2(1.25, 1.0);
	float edge = smoothstep(0.35, 0.85, length(d));
	c *= 1.0 - vignette * edge * edge;
	COLOR = vec4(clamp(c, 0.0, 1.0), 1.0);
}
"""

static var _shader: Shader


func _init() -> void:
	layer = 1
	var rect := ColorRect.new()
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER
	var material := ShaderMaterial.new()
	material.shader = _shader
	rect.material = material
	add_child(rect)

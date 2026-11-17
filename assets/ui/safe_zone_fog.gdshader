shader_type canvas_item;

uniform sampler2D fog_texture : repeat_enable, filter_linear;
uniform vec4 safe_bounds = vec4(40.0, 60.0, 1240.0, 660.0);
uniform float scroll_time = 0.0;
uniform vec2 logical_size = vec2(1280.0, 720.0);
uniform float tile_size = 256.0;
uniform float fog_alpha = 0.86;
uniform float scroll_y_ratio = 0.58;

void fragment() {
	vec2 point = SCREEN_UV * logical_size;
	bool inside_safe_zone = point.x >= safe_bounds.x && point.y >= safe_bounds.y && point.x < safe_bounds.z && point.y < safe_bounds.w;
	if (inside_safe_zone) {
		COLOR = vec4(0.0);
	} else {
		vec2 uv = (point + vec2(scroll_time, -scroll_time * scroll_y_ratio)) / tile_size;
		vec4 fog = texture(fog_texture, uv);
		COLOR = vec4(fog.rgb, fog_alpha * fog.a);
	}
}

shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_linear;
uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform float time_sec : hint_range(0.0, 1000.0) = 0.0;

void fragment() {
	if (intensity < 0.001) {
		COLOR = texture(screen_tex, SCREEN_UV);
		return;
	}
	vec2 uv = SCREEN_UV;
	float wave_x = sin(uv.y * 14.0 + time_sec * 6.0) * intensity * 0.022;
	float wave_y = cos(uv.x * 10.0 + time_sec * 4.5) * intensity * 0.014;
	uv += vec2(wave_x, wave_y);
	uv = clamp(uv, vec2(0.001), vec2(0.999));
	// Slight colour fringing at peak intensity
	float fringe = intensity * 0.010;
	float r = texture(screen_tex, uv + vec2(fringe, 0.0)).r;
	float g = texture(screen_tex, uv).g;
	float b = texture(screen_tex, uv - vec2(fringe, 0.0)).b;
	COLOR = vec4(r, g, b, 1.0);
}

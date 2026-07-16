shader_type canvas_item;

// Full-screen hue-rotate palette recolour. Samples the whole scene, rotates
// every pixel's hue by `hue_shift` (0-1 == 0-360°), and writes it back. Driven
// by screen_fx.gd from Global.palette_hue(); "default" palette pushes 0 so this
// pass is a no-op even while visible.
uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_linear;
uniform float hue_shift : hint_range(0.0, 1.0) = 0.0;

vec3 rgb2hsv(vec3 c) {
	vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	float e = 1.0e-10;
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

vec3 hsv2rgb(vec3 c) {
	vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
	vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
	return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

void fragment() {
	vec3 col = texture(screen_tex, SCREEN_UV).rgb;
	vec3 hsv = rgb2hsv(col);
	hsv.x = fract(hsv.x + hue_shift);
	col = hsv2rgb(hsv);
	COLOR = vec4(col, 1.0);
}

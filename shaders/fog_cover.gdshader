shader_type canvas_item;

// Dark fog that swallows the lower portion of the screen. Gives a sense of a
// bottomless pit under the level. Bottom fades to near-black; upper 60% of the
// screen is untouched.

uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_linear;
uniform float intensity : hint_range(0.0, 1.0) = 0.85;
uniform float start_y   : hint_range(0.0, 1.0) = 0.55;  // where fog starts fading in
uniform float end_y     : hint_range(0.0, 1.0) = 1.00;  // fully dark below here
uniform vec3  fog_color : source_color = vec3(0.03, 0.02, 0.06);

void fragment() {
	vec3 col = texture(screen_tex, SCREEN_UV).rgb;
	float t = smoothstep(start_y, end_y, UV.y);
	col = mix(col, fog_color, t * intensity);
	COLOR = vec4(col, 1.0);
}

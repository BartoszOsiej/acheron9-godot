shader_type spatial;
render_mode blend_mix, cull_back;

// ACHERON-9: INCIDENT - Whiteout / Screen Fade Post-Processing
// Used for ending transitions (good ending whiteout, general fade).

uniform float fade_alpha : hint_range(0.0, 1.0) = 0.0;
uniform vec4 fade_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform bool whiteout = false;

void fragment() {
	vec4 col = texture(TEXTURE, UV);

	if (whiteout) {
		col.rgb = mix(col.rgb, vec3(1.0), fade_alpha);
	}

	if (fade_alpha > 0.0) {
		col.rgb = mix(col.rgb, fade_color.rgb, fade_alpha);
	}

	ALBEDO = col.rgb;
	ALPHA = col.a;
	ROUGHNESS = 0.9;
	METALLIC = 0.0;
}

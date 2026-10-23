shader_type canvas_item;
render_mode unshaded, blend_mix;

// ACHERON-9: INCIDENT - CRT Scanline Post-Processing Effect
// Mirrors UCRTScanlineComponent: scanlines, curvature, chromatic aberration, flicker.
// Full-screen overlay that samples the framebuffer behind it.

uniform float scanline_intensity : hint_range(0.0, 1.0) = 0.8;
uniform float scanline_frequency : hint_range(0.0, 200.0) = 48.0;
uniform float curvature : hint_range(0.0, 0.5) = 0.05;
uniform float chromatic_aberration : hint_range(0.0, 0.1) = 0.02;
uniform float flicker_intensity : hint_range(0.0, 0.5) = 0.1;
uniform vec4 scanline_color : source_color = vec4(0.8, 0.1, 0.1, 1.0);
uniform bool blood_overlay = false;
uniform bool whiteout = false;
uniform float whiteout_alpha : hint_range(0.0, 1.0) = 0.0;
uniform float crt_power : hint_range(0.0, 1.0) = 1.0;
uniform bool enabled = true;

uniform sampler2D screen_texture : hint_screen_texture;

// Noise for flicker/randomness
float rand(vec2 co) {
	return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	if (!enabled) {
		COLOR = texture(screen_texture, SCREEN_UV);
	} else {
		vec2 uv = SCREEN_UV;
		vec2 center = vec2(0.5, 0.5);

		// Barrel curvature (CRT look)
		vec2 offset = uv - center;
		offset *= 1.0 + (curvature * length(offset) * length(offset));
		uv = center + offset;
		uv = clamp(uv, 0.0, 1.0);

		// Sample screen with chromatic aberration
		float ca = chromatic_aberration * rand(UV * 100.0) * 2.0 - 1.0;
		vec2 uv_r = uv + vec2(ca * 0.002, 0.0);
		vec2 uv_g = uv + vec2(-ca * 0.001, 0.0);
		vec2 uv_b = uv + vec2(ca * 0.003, 0.0);

		uv_r = clamp(uv_r, 0.0, 1.0);
		uv_g = clamp(uv_g, 0.0, 1.0);
		uv_b = clamp(uv_b, 0.0, 1.0);

		vec4 col_r = texture(screen_texture, uv_r);
		vec4 col_g = texture(screen_texture, uv_g);
		vec4 col_b = texture(screen_texture, uv_b);
		vec4 col = vec4(col_r.r, col_g.g, col_b.b, 1.0);

		// Apply scanlines
		float scanline = sin(UV.x * scanline_frequency * 3.14159) * 0.5 + 0.5;
		scanline = pow(scanline, scanline_intensity * 2.0);

		// Flicker simulation (CRT refresh instability)
		float flicker = 1.0 - (rand(UV * TIME * 1000.0) * flicker_intensity);

		// Scanline color tint
		col.rgb = mix(col.rgb, col.rgb * scanline_color.rgb, scanline * scanline_color.a * 0.5);
		col.rgb *= flicker;

		// Blood overlay (bad ending)
		if (blood_overlay) {
			col.rgb = mix(col.rgb, vec3(0.12, 0.02, 0.02), 0.3 * scanline);
		}

		// Whiteout (good ending)
		if (whiteout) {
			col.rgb = mix(col.rgb, vec3(1.0), whiteout_alpha);
		}

		COLOR = col;
	}
}

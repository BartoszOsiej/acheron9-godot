shader_type spatial;
render_mode blend_mix, cull_front, depth_draw_always, unshaded;

// ACHERON-9: INCIDENT - Blood Splatter Decal Material
// Mirrors M_Corrupted_Blood_Decal with translucent blending.

uniform float roughness : hint_range(0.0, 1.0) = 0.75;
uniform float metallic : hint_range(0.0, 1.0) = 0.0;
uniform float specular : hint_range(0.0, 1.0) = 0.05;
uniform float opacity : hint_range(0.0, 1.0) = 0.8;
uniform vec4 base_color : source_color = vec4(0.12, 0.02, 0.02, 1.0);

// Procedural blood splatter
float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(a, b, u.x) + (c - a - b + d) * u.y;
}

float fbm(vec2 p) {
	float value = 0.0;
	float amplitude = 0.5;
	float frequency = 1.0;
	for (int i = 0; i < 4; i++) {
		value += noise(p * frequency) * amplitude;
		amplitude *= 0.5;
		frequency *= 2.0;
	}
	return value;
}

void fragment() {
	// Blood splatter pattern: organic, irregular edges
	float splatter = fbm(UV * 15.0 + vec2(0.3, 0.7));

	// Create irregular drip patterns
	float drip = fbm(UV * 5.0 + vec2(0.0, TIME * 0.02));
	splatter = max(splatter, drip * 0.7);

	// Edge fade (decal fades at boundaries)
	float edge = 1.0 - smoothstep(0.7, 0.95, abs(UV.x - 0.5) * 2.0);
	edge *= 1.0 - smoothstep(0.7, 0.95, abs(UV.y - 0.5) * 2.0);

	splatter *= edge;

	vec3 color = base_color.rgb;
	color *= 0.8 + 0.2 * splatter;

	ALBEDO = color;
	ROUGHNESS = roughness;
	METALLIC = metallic;
	ALPHA = base_color.a * opacity * splatter;
}

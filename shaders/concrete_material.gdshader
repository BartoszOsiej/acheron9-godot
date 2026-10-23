shader_type spatial;
render_mode cull_back;

// ACHERON-9: INCIDENT - Brutalist Concrete Material
// Mirrors M_Brutalist_Concrete material instance with runtime parameter control.

uniform float roughness : hint_range(0.0, 1.0) = 0.9;
uniform float metallic : hint_range(0.0, 1.0) = 0.05;
uniform vec4 base_color : source_color = vec4(0.32, 0.32, 0.35, 1.0);
uniform float dirt_amount : hint_range(0.0, 1.0) = 0.3;
uniform float moisture_amount : hint_range(0.0, 1.0) = 0.0;
uniform float normal_scale : hint_range(0.0, 1.0) = 0.8;

// Noise function for procedural concrete texture
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
	float frequency = 3.0;
	for (int i = 0; i < 5; i++) {
		value += abs(noise(p * frequency)) * amplitude;
		amplitude *= 0.5;
		frequency *= 2.0;
	}
	return value;
}

void fragment() {
	// Base concrete with procedural noise
	float concrete_noise = fbm(UV * 50.0 + vec2(TIME * 0.1, 0.0));

	// Dirt variation
	float dirt = dirt_amount * fbm(UV * 20.0 + vec2(0.5, 0.5));

	// Moisture streaks
	float moisture = moisture_amount * fbm(UV * 10.0 + vec2(TIME * 0.05, 0.0));

	// Combine
	vec3 color = base_color.rgb;
	color *= 0.9 + 0.1 * concrete_noise;
	color += dirt * 0.2;
	color += moisture * vec3(0.1, 0.12, 0.15);

	ALBEDO = color;
	ROUGHNESS = roughness;
	METALLIC = metallic;
}

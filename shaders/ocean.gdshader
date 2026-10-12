shader_type canvas_item;

// Per-sector biome colors (GRID x GRID textures). light_tex alpha = sparkle amount.
uniform sampler2D deep_tex : filter_linear, repeat_disable;
uniform sampler2D light_tex : filter_linear, repeat_disable;
uniform vec2 world_size = vec2(10240.0, 10240.0);
uniform vec2 origin = vec2(0.0, 0.0);
uniform float grid = 8.0;
uniform float pixel = 4.0;

varying vec2 wpos;

void vertex() {
	wpos = VERTEX + origin;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
			mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

// Samples so each sector is a solid color, blending only near sector borders.
vec2 biome_uv(vec2 p) {
	vec2 s = clamp(p / world_size, 0.0, 0.9999) * grid;
	s += (vec2(noise(p / 300.0), noise(p / 300.0 + 17.0)) - 0.5) * 0.08;
	vec2 cell = floor(s);
	vec2 f = fract(s) - 0.5;
	vec2 g = sign(f) * smoothstep(0.3, 0.5, abs(f)) * 0.5;
	return (cell + 0.5 + g) / grid;
}

void fragment() {
	vec2 p = floor(wpos / pixel) * pixel;
	vec2 uv = biome_uv(p);
	vec4 deep = texture(deep_tex, uv);
	vec4 light = texture(light_tex, uv);
	float t = TIME;
	vec2 q = p / 220.0;
	float n = noise(q + vec2(t * 0.04, t * 0.025)) * 0.65 + noise(q * 2.3 - vec2(t * 0.06, -t * 0.05)) * 0.35;
	vec3 col = mix(deep.rgb, light.rgb, smoothstep(0.35, 0.85, n) * 0.3);
	float crest = smoothstep(0.02, 0.0, abs(n - 0.6)) * step(0.5, noise(q * 6.0 + t * 0.1));
	col += crest * 0.07;
	float sp = step(0.997, hash(floor(p / 8.0) + floor(t * 1.5))) * light.a;
	col += sp * vec3(0.4, 0.9, 1.0);
	// Storm wall around the map edge.
	vec2 dedge = min(p, world_size - p);
	float edge = min(dedge.x, dedge.y);
	float storm = smoothstep(160.0, -64.0, edge);
	float rain = step(0.75, noise(vec2(p.x / 6.0 + p.y / 20.0, p.y / 40.0 - t * 6.0)));
	col = mix(col, vec3(0.12, 0.14, 0.18) + rain * 0.12, storm * 0.85);
	COLOR = vec4(col, 1.0);
}

// Hex-пузырь Щита (task_8 §2): соты проявляются по краю (френель) и вспыхивают при ударе (hit 0..1).
shader_type canvas_item;
render_mode unshaded, blend_add;

uniform vec4 color : source_color = vec4(0.56, 0.72, 1.0, 1.0);
uniform float hit = 0.0;
uniform float hex_scale = 9.0;

float hex_dist(vec2 p) {
	p = abs(p);
	return max(dot(p, normalize(vec2(1.0, 1.732))), p.x);
}

vec4 hex_coords(vec2 uv) {
	vec2 r = vec2(1.0, 1.732);
	vec2 h = r * 0.5;
	vec2 a = mod(uv, r) - h;
	vec2 b = mod(uv - h, r) - h;
	vec2 gv = dot(a, a) < dot(b, b) ? a : b;
	return vec4(gv, uv - gv);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	if (r > 1.0) { discard; }
	float fresnel = pow(r, 3.0);
	vec4 hc = hex_coords(p * hex_scale + vec2(0.0, TIME * 0.15));
	float line = smoothstep(0.42, 0.5, hex_dist(hc.xy));
	float shimmer = 0.5 + 0.5 * sin(TIME * 2.0 + hc.z * 1.7 + hc.w * 2.3);
	float a = line * fresnel * (0.35 + 0.25 * shimmer) + fresnel * 0.12 + hit * (line * 0.8 + 0.2) * (1.0 - r * 0.3);
	COLOR = vec4(color.rgb, clamp(a, 0.0, 1.0));
}

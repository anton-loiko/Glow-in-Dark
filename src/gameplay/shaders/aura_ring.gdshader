// Кольцо жара Ауры (task_8 §2): мерцающая кромка по границе света, цвет скина.
// Квад 2R×2R вокруг игрока; ring_px — толщина в пикселях квада.
shader_type canvas_item;
render_mode unshaded, blend_add;

uniform vec4 color : source_color = vec4(1.0, 0.71, 0.28, 1.0);
uniform float ring_frac = 0.04;  // толщина кольца / радиус
uniform float intensity = 0.6;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float angle = atan(p.y, p.x);
	float flicker = noise(vec2(angle * 6.0, TIME * 3.0)) * 0.6 + 0.4;
	float edge = 1.0 - ring_frac * (0.6 + 0.8 * flicker);
	float ring = smoothstep(edge - ring_frac, edge, r) * (1.0 - smoothstep(1.0 - ring_frac * 0.2, 1.0, r));
	float heat = smoothstep(edge - ring_frac * 3.0, edge, r) * 0.25 * (1.0 - step(1.0, r));
	COLOR = vec4(color.rgb, (ring * flicker + heat) * intensity);
}

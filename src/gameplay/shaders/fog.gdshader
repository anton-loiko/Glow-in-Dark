// Туман главы с параллаксом 0.8× (task_8 §2): медленные клубы fbm поверх пола, под врагами.
// world_offset — мировая позиция угла квада минус 20% смещения камеры: клубы движутся на 80% от пола.
shader_type canvas_item;
render_mode unshaded;

uniform vec4 color : source_color = vec4(0.30, 0.36, 0.48, 1.0);
uniform vec2 world_offset = vec2(0.0);
uniform float density = 0.18;
uniform float scale = 0.0035;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}
float fbm(vec2 p) {
	float v = 0.0; float a = 0.5;
	for (int i = 0; i < 4; i++) { v += a * noise(p); p *= 2.03; a *= 0.5; }
	return v;
}

varying vec2 local_pos;

void vertex() {
	local_pos = VERTEX;
}

void fragment() {
	vec2 world = local_pos + world_offset;
	float n = fbm(world * scale + vec2(TIME * 0.02, TIME * 0.013));
	float clouds = smoothstep(0.45, 0.85, n);
	COLOR = vec4(color.rgb, clouds * density);
}

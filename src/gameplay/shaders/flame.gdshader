// Языки пламени (task_8 §2, «Сверхновая»): fbm-шум бежит вверх, форма сужается к кончику.
// Ядро белое → цвет скина → прозрачный край. Квад над макушкой Огонька; intensity 0..1 — рост с билдом.
shader_type canvas_item;
render_mode unshaded, blend_add;

uniform vec4 color : source_color = vec4(1.0, 0.71, 0.28, 1.0);
uniform float intensity = 0.5;
uniform float speed = 1.6;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}
float fbm(vec2 p) {
	float v = 0.0; float a = 0.5;
	for (int i = 0; i < 4; i++) { v += a * noise(p); p *= 2.1; a *= 0.5; }
	return v;
}

void fragment() {
	vec2 uv = UV;
	float h = 1.0 - uv.y;                          // 0 у основания, 1 у кончика
	float n = fbm(vec2(uv.x * 4.0, uv.y * 3.0 + TIME * speed));
	float width = mix(0.42, 0.04, pow(h, 0.8)) * (0.7 + 0.5 * intensity);
	float body = 1.0 - smoothstep(width * 0.6, width, abs(uv.x - 0.5 + (n - 0.5) * 0.18 * h));
	float height_cut = 1.0 - smoothstep(0.45 + 0.5 * intensity, 1.0, h + (n - 0.5) * 0.35);
	float a = body * height_cut;
	vec3 c = mix(vec3(1.0, 0.99, 0.95), color.rgb, smoothstep(0.1, 0.6, h + (1.0 - body) * 0.4));
	COLOR = vec4(c, a * (0.55 + 0.45 * intensity));
}

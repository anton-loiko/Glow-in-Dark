// Тело врага (Enemy DS §09, task_8 §2): альбедо темнее тьмы + normal map, освещение светом Огонька.
// Rim: край, повёрнутый к свету, загорается цветом света (= цвет скина игрока).
// Растворение при смерти: modulate.a < 1 → пиксели выгорают по маске трещин (G) с раскалённой кромкой.
// Альфа modulate используется только как прогресс растворения — один общий материал на архетип (батчинг).
shader_type canvas_item;

uniform sampler2D mask_tex : filter_linear, repeat_disable;
uniform vec4 hot_color : source_color = vec4(1.0, 0.945, 0.816, 1.0);
uniform float rim_power = 2.2;
uniform float rim_boost = 2.4;

varying vec4 vertex_color;

void vertex() {
	vertex_color = COLOR;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	COLOR = vec4(tex.rgb * vertex_color.rgb, tex.a);
	float dissolve = 1.0 - vertex_color.a;
	if (dissolve > 0.001) {
		float cracks = texture(mask_tex, UV).g;
		float n = mix(hash(floor(UV / TEXTURE_PIXEL_SIZE / 3.0)), 1.0 - cracks, 0.6);
		if (n < dissolve) {
			discard;
		}
		float edge = smoothstep(dissolve + 0.12, dissolve, n);
		COLOR.rgb = mix(COLOR.rgb, hot_color.rgb, edge);
	}
}

void light() {
	float ndl = max(0.0, dot(NORMAL, LIGHT_DIRECTION));
	float rim = pow(clamp(1.0 - NORMAL.z, 0.0, 1.0), rim_power) * ndl * rim_boost;
	LIGHT = vec4(LIGHT_COLOR.rgb * LIGHT_ENERGY * (COLOR.rgb * ndl + rim), LIGHT_COLOR.a);
}

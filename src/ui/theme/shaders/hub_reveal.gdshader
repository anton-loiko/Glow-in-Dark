// Диорама хаба (Meta DS §01): город проявляется светом Маяка — радиус = прогресс (beacon_config.hub_light).
// За радиусом — силуэты во тьме; тир 10 — «дневная» палитра (правило DS 9). Координаты — пиксели узла.
shader_type canvas_item;

uniform vec2 center_px = vec2(195.0, 280.0);
uniform float radius_px = 80.0;
uniform float day_mix = 0.0;
uniform float breath = 0.5;
uniform vec4 warm : source_color = vec4(1.0, 0.71, 0.28, 1.0);

varying vec2 local_pos;

void vertex() {
	local_pos = VERTEX;
}

void fragment() {
	vec3 t = texture(TEXTURE, UV).rgb;
	float dist = length(local_pos - center_px);
	float r = radius_px * (1.0 + 0.03 * breath);
	float lit = 1.0 - smoothstep(r * 0.55, r, dist);
	vec3 night = t * 0.6;
	vec3 lit_col = t * 3.4 + warm.rgb * 0.08 * lit * (1.0 - dist / max(r, 1.0));
	vec3 c = mix(night, lit_col, lit);
	vec3 day = mix(t * 5.5, vec3(0.62, 0.68, 0.78), 0.35);
	COLOR = vec4(mix(c, day, day_mix), 1.0);
}

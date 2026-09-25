shader_type canvas_item;

uniform vec4 vignette_color : source_color = vec4(0.6, 0.0, 0.0, 1.0);
uniform float intensity : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	float dist = distance(UV, vec2(0.5, 0.5));
	float vignette = smoothstep(0.2, 0.8, dist);
	COLOR = vignette_color;
	COLOR.a = vignette * intensity;
}
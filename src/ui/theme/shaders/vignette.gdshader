shader_type canvas_item;
// HP-виньетка (DS правило 8): тьма по краям растёт с потерей света; при HP < 25% холодеет,
// при уроне кратко краснеет. Прозрачна в центре.

uniform float intensity : hint_range(0.0, 1.0) = 0.2;
uniform vec4 tint : source_color = vec4(0.027, 0.035, 0.059, 1.0);

void fragment() {
	vec2 uv = (UV - vec2(0.5)) * vec2(1.0, 0.6);
	float d = length(uv);
	float inner = mix(0.42, 0.12, intensity);
	float edge = smoothstep(inner, inner + 0.3, d);
	COLOR = vec4(tint.rgb, edge * clamp(0.35 + intensity, 0.0, 1.0));
}

// Ударная волна Взрыва Света (task_8 §2): кольцо дисторсии экрана, расходящееся от центра.
// Полноэкранный ColorRect в CanvasLayer над миром; включается только на время волны (одна копия экрана).
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform vec2 center = vec2(0.5, 0.5);   // в UV экрана
uniform float radius = 0.0;             // в долях высоты экрана
uniform float width = 0.06;
uniform float strength = 0.025;
uniform float aspect = 0.462;           // ширина / высота вьюпорта
uniform vec4 tint : source_color = vec4(1.0, 0.71, 0.28, 1.0);

void fragment() {
	vec2 d = SCREEN_UV - center;
	d.x *= aspect;
	float dist = length(d);
	float band = 1.0 - smoothstep(0.0, width, abs(dist - radius));
	vec2 dir = dist > 0.0001 ? normalize(d) : vec2(0.0);
	dir.x /= aspect;
	vec2 uv = SCREEN_UV - dir * band * strength;
	vec3 col = texture(screen_tex, uv).rgb;
	col += tint.rgb * band * band * 0.25;
	COLOR = vec4(col, 1.0);
}

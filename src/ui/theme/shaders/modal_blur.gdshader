// Фон модала (DS §02): размытие 12 + затемнение ink.900 70%. Размытие — выборка mip-уровня экрана (дёшево на мобильных).
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float blur_lod = 2.5;
uniform vec4 dim : source_color = vec4(0.027, 0.035, 0.059, 0.7);

void fragment() {
	vec3 blurred = textureLod(screen_tex, SCREEN_UV, blur_lod).rgb;
	COLOR = vec4(mix(blurred, dim.rgb, dim.a), 1.0);
}

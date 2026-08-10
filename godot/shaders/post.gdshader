shader_type canvas_item;
render_mode blend_mix, unshaded;

// ФИНИШНЫЙ СЛОЙ. Лежит поверх мира и собирает кадр в одно целое: без него
// картинка распадается на отдельные хорошо нарисованные куски.
//
// Виньетка и лёгкая аберрация уводят внимание к центру, тёплая тонировка держит
// закатный свет, зерно и грязь на стекле убирают цифровую чистоту, из-за которой
// процедурная графика выглядит дёшево.

uniform sampler2D screen : hint_screen_texture, filter_linear_mipmap;
uniform float day : hint_range(0.0, 1.0) = 1.0;
uniform float time_s = 0.0;
uniform float vignette : hint_range(0.0, 1.0) = 0.55;
uniform float grain : hint_range(0.0, 1.0) = 0.35;
uniform vec3 warm : source_color = vec3(1.06, 0.99, 0.92);
uniform vec3 cool : source_color = vec3(0.9, 0.95, 1.08);

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 d = uv - 0.5;
	float r2 = dot(d, d);

	// Аберрация: к краям каналы чуть разъезжаются, как в объективе.
	// Величина крошечная, но именно она даёт ощущение оптики, а не рисунка.
	float ab = 0.0022 * r2;
	vec3 col;
	col.r = texture(screen, uv + d * ab).r;
	col.g = texture(screen, uv).g;
	col.b = texture(screen, uv - d * ab).b;

	// Тонировка: света тёплые, тени холодные — обычный киношный разнос
	float luma = dot(col, vec3(0.299, 0.587, 0.114));
	vec3 tint = mix(cool, warm, smoothstep(0.15, 0.75, luma));
	col *= mix(vec3(1.0), tint, 0.55 + 0.45 * day);

	// Контраст мягкой S-кривой: тени глубже, света не выбиваются
	col = clamp(col, 0.0, 4.0);
	col = mix(col, col * col * (3.0 - 2.0 * col), 0.22);

	// Виньетка
	float v = 1.0 - vignette * smoothstep(0.12, 0.78, r2);
	col *= v;

	// Зерно: чуть заметнее в тенях, как на настоящей плёнке
	float g = hash12(uv * vec2(1920.0, 1080.0) + fract(time_s) * 91.7) - 0.5;
	col += g * grain * 0.05 * (1.3 - luma);

	// Грязь и разводы по краям кадра — камера смотрит через пыльный воздух
	float smudge = hash12(floor(uv * 40.0)) * smoothstep(0.2, 0.75, r2);
	col += vec3(0.02, 0.018, 0.015) * smudge * day;

	COLOR = vec4(col, 1.0);
}

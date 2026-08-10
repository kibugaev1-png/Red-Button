shader_type canvas_item;
render_mode blend_mix, unshaded;

// ФОН ЛОКАЦИИ.
//
// Раньше здесь считался процедурный город — и выглядел вычисленным, потому что
// он и был вычисленным. Теперь фон это фотография места: панорамы Poly Haven
// (CC0), из которых взята полоса вокруг горизонта. У каждой локации своя.
//
// Панорама круговая, поэтому по горизонтали заворачивается без стыка и её можно
// катить параллаксом сколько угодно. Соседние локации смешиваются по X, так что
// на переходе одна местность плавно превращается в другую.
//
// Сверху: воздушная перспектива (даль тонет в дымке), тонировка по времени
// суток, солнечный ореол и лёгкое зерно.

uniform sampler2D bg_a : filter_linear_mipmap, repeat_enable;
uniform sampler2D bg_b : filter_linear_mipmap, repeat_enable;
uniform float bg_mix : hint_range(0.0, 1.0) = 0.0;   // 0 — только A, 1 — только B

uniform vec2 cam_pos = vec2(0.0);
uniform float zoom = 1.0;
uniform vec2 screen_size = vec2(1280.0, 720.0);
uniform float day : hint_range(0.0, 1.0) = 1.0;
uniform float time_s = 0.0;
uniform float horizon_y = 4160.0;      // мировая высота земли под игроком

// Насколько фон отстаёт от камеры и какой ширины кажется. Меньше parallax —
// дальше и медленнее; больше span — крупнее детали фона.
uniform float parallax : hint_range(0.0, 0.5) = 0.085;
uniform float span = 9000.0;           // мировых пикселей на оборот панорамы
uniform float band_h = 1.75;           // высота полосы фона в экранах
uniform float band_shift = 0.62;       // где внутри полосы сидит горизонт

uniform vec3 haze : source_color = vec3(0.68, 0.56, 0.46);
uniform vec3 night_tint : source_color = vec3(0.16, 0.19, 0.3);
uniform float fog_amount : hint_range(0.0, 1.0) = 0.42;
uniform float exposure = 1.0;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void fragment() {
	vec2 scr = UV * screen_size;

	// Линия горизонта на экране: считаем от камеры, чтобы фон стоял на месте и
	// когда игрок залез на высотку
	float hy = screen_size.y * 0.5 + (horizon_y - cam_pos.y) * zoom;

	// Мировая точка под пикселем, приведённая к скорости дальнего плана
	float wx = cam_pos.x * parallax + (scr.x - screen_size.x * 0.5) / zoom;
	float u = wx / span;

	// По вертикали полоса растянута на band_h экранов, горизонт внутри неё сидит
	// на band_shift — так под линией земли остаётся запас на подъём камеры
	float bh = screen_size.y * band_h;
	float v = (scr.y - (hy - bh * band_shift)) / bh;
	float vc = clamp(v, 0.002, 0.998);

	vec3 col = texture(bg_a, vec2(u, vc)).rgb;
	if (bg_mix > 0.001) {
		col = mix(col, texture(bg_b, vec2(u, vc)).rgb, bg_mix);
	}
	col *= exposure;

	// ---- воздушная перспектива ----
	// Чем ближе к линии горизонта, тем сильнее даль тонет в пыли. Именно это
	// отделяет фон от переднего плана и даёт ощущение расстояния.
	float to_hor = 1.0 - clamp(abs(scr.y - hy) / (screen_size.y * 0.5), 0.0, 1.0);
	col = mix(col, mix(night_tint, haze, day), pow(to_hor, 1.7) * fog_amount);

	// ---- время суток ----
	float luma = dot(col, vec3(0.299, 0.587, 0.114));
	vec3 nightc = mix(vec3(luma), night_tint * luma * 2.2, 0.7) * 0.42;
	col = mix(nightc, col, clamp(day * 1.15, 0.0, 1.0));

	// ---- солнечный ореол ----
	// Само солнце уже есть на фотографии, здесь только свечение в воздухе,
	// иначе фон выглядит плоской наклейкой
	vec2 sun_scr = vec2(screen_size.x * 0.24, hy - screen_size.y * 0.26);
	float sd = length((scr - sun_scr) / screen_size.y);
	col += mix(vec3(0.4, 0.42, 0.5), vec3(1.0, 0.72, 0.42), day)
		* pow(max(0.0, 1.0 - sd * 1.25), 3.0) * 0.26 * (0.25 + 0.75 * day);

	// зерно, чтобы не полосили градиенты дымки
	col += (hash12(scr + fract(time_s) * 17.0) - 0.5) * 0.012;

	COLOR = vec4(col, 1.0);
}

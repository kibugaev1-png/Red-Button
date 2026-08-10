shader_type canvas_item;
render_mode blend_mix, unshaded;

// НЕБО И ДАЛИ.
//
// Считается в экранных координатах, а не в мировых: игрок стоит на уровне
// горизонта, и любая привязка неба к мировой высоте вырождается в одну ровную
// полосу. Горизонт держим на экране, а от камеры берём только параллакс.
//
// Слои по глубине: градиент — солнце в пыли — лучи — три ряда облаков —
// четыре ряда силуэтов разрушенного города — пыльная дымка — птицы.

uniform vec2 cam_pos = vec2(0.0);
uniform float zoom = 1.0;
uniform vec2 screen_size = vec2(1280.0, 720.0);
uniform float day : hint_range(0.0, 1.0) = 1.0;
uniform float time_s = 0.0;
uniform float horizon_y = 4160.0;      // мировая высота земли под игроком

uniform vec3 zenith_day : source_color = vec3(0.20, 0.26, 0.40);
uniform vec3 mid_day : source_color = vec3(0.55, 0.44, 0.42);
uniform vec3 horizon_day : source_color = vec3(0.92, 0.62, 0.36);
uniform vec3 zenith_night : source_color = vec3(0.02, 0.03, 0.07);
uniform vec3 mid_night : source_color = vec3(0.07, 0.07, 0.12);
uniform vec3 horizon_night : source_color = vec3(0.16, 0.12, 0.14);
uniform vec3 sun_tint : source_color = vec3(1.0, 0.66, 0.34);
uniform vec3 far_haze : source_color = vec3(0.62, 0.45, 0.36);

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash12(i), hash12(i + vec2(1.0, 0.0)), f.x),
		mix(hash12(i + vec2(0.0, 1.0)), hash12(i + vec2(1.0, 1.0)), f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 3; i++) {
		v += vnoise(p) * a;
		p = p * 2.07 + 11.1;
		a *= 0.5;
	}
	return v;
}

// СИЛУЭТ РАЗРУШЕННОГО ГОРОДА.
// Возвращает 1, если точка внутри силуэта. Считается в местных координатах ряда:
// lx — положение вдоль ряда, up — высота над линией земли в долях амплитуды.
// Кроме коробок домов ряд содержит опознаваемые вещи: водонапорную башню, опоры
// ЛЭП, краны и антенны. Именно они превращают полосу шума в разрушенный город.
float boxes(float lx, float up, float seed) {
	float cw = 0.5;
	float id = floor(lx / cw);
	float inside = fract(lx / cw);
	float r = hash12(vec2(id, seed));
	if (r < 0.34) {
		return 0.0;                                   // провал в застройке
	}
	float h = 0.2 + hash12(vec2(id, seed + 4.0)) * 0.62;
	// у части домов срезан верх — обрушенное перекрытие
	if (hash12(vec2(id, seed + 9.0)) > 0.55) {
		h *= mix(1.0, 0.52, inside);
	}
	// узкие простенки между домами
	float gap = step(0.9, inside) * 0.6;
	float body = step(up, h) * (1.0 - gap);
	// антенна на редких домах
	if (hash12(vec2(id, seed + 15.0)) > 0.82) {
		float ax = abs(inside - 0.5);
		body = max(body, step(ax, 0.03) * step(up, h + 0.3));
	}
	return body;
}

float water_tower(float lx, float up) {
	float x = abs(lx - 0.5);
	float legs = step(up, 0.52) * (step(abs(x - 0.1), 0.022) + step(abs(x - 0.26), 0.022));
	float braces = step(abs(up - 0.3), 0.016) * step(x, 0.3);
	float tank = step(up, 0.82) * step(0.5, up) * step(x, 0.3);
	float top = step(abs(up - 0.85), 0.035) * step(x, 0.2);
	return clamp(legs + braces + tank + top, 0.0, 1.0);
}

float pylon(float lx, float up) {
	float x = abs(lx - 0.5);
	float w = mix(0.2, 0.04, up);                     // сужается к верху
	float legs = step(abs(x - w), 0.02) * step(up, 0.95);
	float cross = step(abs(fract(up * 7.0) - 0.5), 0.06) * step(x, w);
	float arms = (step(abs(up - 0.66), 0.02) + step(abs(up - 0.84), 0.02)) * step(x, 0.26);
	return clamp(legs + cross * 0.9 + arms, 0.0, 1.0);
}

float crane(float lx, float up) {
	float x = lx - 0.42;
	float mast = step(abs(x), 0.025) * step(up, 0.92);
	float jib = step(abs(up - 0.88), 0.022) * step(-0.16, x) * step(x, 0.34);
	float stay = step(abs(up - 0.88 + (x - 0.02) * 1.4), 0.02) * step(0.0, x) * step(x, 0.3);
	return clamp(mast + jib + stay, 0.0, 1.0);
}

float city(float lx, float up, float seed) {
	float m = boxes(lx, up, seed);
	// опознаваемые постройки раскиданы редко, по хэшу крупной ячейки
	float lw = 3.7;
	float cellid = floor(lx / lw);
	float inner = fract(lx / lw);
	float pick = hash12(vec2(cellid, seed + 31.0));
	if (pick > 0.74) {
		m = max(m, water_tower(inner, up));
	} else if (pick > 0.52) {
		m = max(m, pylon(inner, up));
	} else if (pick > 0.4) {
		m = max(m, crane(inner, up));
	}
	// холмистая земля под застройкой
	m = max(m, step(up, vnoise(vec2(lx * 0.6 + seed, seed * 1.7)) * 0.3));
	return m;
}

void fragment() {
	vec2 scr = UV * screen_size;
	// Линия горизонта — там, где на экране оказывается уровень земли. Считаем её
	// от камеры: только так небо остаётся небом и когда игрок залез на высотку.
	float hy = screen_size.y * 0.5 + (horizon_y - cam_pos.y) * zoom;
	// 0 на линии горизонта, 1 высоко в зените
	float h = clamp((hy - scr.y) / (screen_size.y * 1.25), 0.0, 1.4);
	float rise = clamp((horizon_y - cam_pos.y) / 2400.0, -0.35, 1.6);
	float sy = h;

	vec3 zen = mix(zenith_night, zenith_day, day);
	vec3 mid = mix(mid_night, mid_day, day);
	vec3 hor = mix(horizon_night, horizon_day, day);
	// три опорных цвета вместо двух: только так небо перестаёт быть заливкой
	vec3 col = mix(hor, mid, smoothstep(0.0, 0.42, h));
	col = mix(col, zen, smoothstep(0.34, 1.0, h));

	// ---- солнце: низкое, в пыли, поэтому огромное и мутное ----
	vec2 sun_scr = vec2(screen_size.x * 0.26, hy - screen_size.y * 0.3);
	float aspect = screen_size.x / screen_size.y;
	vec2 dv = (scr - sun_scr) / screen_size.y;
	float sd = length(dv);
	float disc = smoothstep(0.075, 0.055, sd);
	col += sun_tint * disc * (1.1 + 0.9 * day) * day;
	col += sun_tint * pow(smoothstep(0.62, 0.0, sd), 2.6) * 0.85 * day;
	col += sun_tint * pow(smoothstep(1.3, 0.0, sd), 4.0) * 0.3 * day;

	// лучи: пыль в воздухе делает их видимыми
	float ang = atan(dv.y, dv.x);
	float rays = fbm(vec2(ang * 4.5, time_s * 0.03));
	rays *= rays;
	col += sun_tint * rays * pow(smoothstep(0.9, 0.05, sd), 2.0) * 0.55 * day;

	// ---- облака: три слоя, разная скорость и плотность ----
	float px = cam_pos.x * 0.00006;
	float c1 = fbm(vec2(scr.x * 0.0016 + px * 3.0 + time_s * 0.004, sy * 3.4));
	float c2 = fbm(vec2(scr.x * 0.0009 + px * 1.6 - time_s * 0.0022 + 9.0, sy * 2.1 + 4.0));
	float band = smoothstep(0.5, 0.8, c1) * smoothstep(0.18, 0.62, h) * 0.55;
	band += smoothstep(0.52, 0.86, c2) * smoothstep(0.1, 0.5, h) * 0.5;
	// низ облаков тёмный, верх подсвечен солнцем
	vec3 cloud_dark = mix(vec3(0.1, 0.1, 0.13), vec3(0.3, 0.24, 0.24), day);
	vec3 cloud_lit = mix(vec3(0.2, 0.2, 0.24), sun_tint * 1.05, day);
	float lit_side = smoothstep(0.8, 0.0, length((scr - sun_scr) / screen_size.y));
	vec3 cloud = mix(cloud_dark, cloud_lit, clamp(lit_side + 0.18, 0.0, 1.0));
	col = mix(col, cloud, clamp(band, 0.0, 0.8));

	// ---- дали: четыре ряда силуэтов с параллаксом ----
	// Чем ряд дальше, тем медленнее едет, тем выше стоит его линия и тем сильнее
	// он размыт дымкой — это и создаёт ощущение глубины пространства.
	for (int i = 0; i < 4; i++) {
		float fi = float(i);
		// ряд 0 самый дальний: едет медленнее всех и сильнее размыт дымкой
		// Коэффициент дальности умножает ТОЛЬКО сдвиг камеры. Если умножить им и
		// экранную координату, ряд сжимается в десятки раз и дома превращаются в
		// одну плиту на весь экран — на этом я и споткнулся.
		float par = 0.02 + fi * 0.05;
		float xs = (cam_pos.x * par + (scr.x - screen_size.x * 0.5) / zoom) * 0.0062;
		float base_y = hy + 4.0 - fi * 7.0;
		float amp = screen_size.y * (0.1 + fi * 0.055);
		float up = (base_y - scr.y) / amp;
		float m = 0.0;
		if (up > 0.0 && up < 1.4) {
			m = city(xs, up, fi * 23.0 + 2.0);
		}
		if (m > 0.0) {
			// Силуэт тёмный: против закатного свечения город обязан читаться
			// пятном, а не бледной плитой. Дымка только у дальних рядов.
			float fog = 0.42 - fi * 0.12;
			vec3 sc = mix(vec3(0.055, 0.05, 0.065), far_haze, fog);
			sc *= 0.45 + 0.55 * day;
			// окна: редкие тёплые точки в ближних рядах, ярче в темноте
			if (i >= 2) {
				float lit = step(0.994, hash12(vec2(floor(xs * 260.0), floor(scr.y / 5.0))));
				sc += vec3(1.0, 0.55, 0.22) * lit * (1.3 - day) * 0.7;
			}
			col = mix(col, sc, m * 0.97);
		}
	}

	// ---- пыльная дымка у горизонта ----
	float dust = pow(smoothstep(0.42, 0.0, h), 1.6);
	col = mix(col, mix(vec3(0.09, 0.08, 0.09), far_haze * 1.1, day), dust * 0.5);

	// ---- редкие птицы: живой мир, почти не заметно, но глаз ловит ----
	for (int i = 0; i < 3; i++) {
		float fi = float(i);
		float bx = fract(time_s * (0.012 + fi * 0.004) + fi * 0.37) * screen_size.x;
		float by = screen_size.y * (0.2 + fi * 0.07) + sin(time_s * 1.4 + fi) * 6.0;
		vec2 bd = (scr - vec2(bx, by));
		float wing = abs(bd.x) * 0.5 + abs(sin(time_s * 6.0 + fi) * 3.0);
		float b = smoothstep(2.4, 0.0, abs(bd.y - sin(bd.x * 0.5) * 1.5)) * smoothstep(7.0, 0.0, abs(bd.x)) * step(wing, 6.0);
		col = mix(col, vec3(0.05, 0.04, 0.05), b * 0.55);
	}

	// зерно, чтобы градиент не полосил на больших экранах
	col += (hash12(scr + fract(time_s) * 13.0) - 0.5) * 0.014;

	COLOR = vec4(col, 1.0);
}

shader_type canvas_item;
render_mode blend_mix, unshaded;

// ПОРОДА. Здесь рисуются все 5,7 миллиона частиц мира.
//
// Цвет и рельеф берутся из настоящих фотографических текстур (наборы CC0 с
// ambientCG): для каждой породы своя карта цвета и своя карта нормалей. Шум
// остался только на подмешивание — крупные пятна и вариации тона, чтобы одна и
// та же текстура не читалась повтором.
//
// Текстуры лежат слоями в sampler2DArray, а не в атласе: у массива работает
// обычное заворачивание и мип-уровни, поэтому нет ни швов между ячейками, ни
// ряби при отдалении.
//
// Форма: край породы это линия уровня непрерывного поля плотности, собранного
// по четырём соседним частицам. Поэтому частицы получаются скруглёнными и
// слипаются в органическую массу, а не в сетку кубиков.
//
// Освещение объёмное: нормаль складывается из наклона поля плотности (крупная
// форма) и карты нормалей текстуры (мелкий рельеф), дальше обычное направленное
// солнце, небесная полусфера, отсвет от земли и подземный полумрак.
//
// Вход — текстура сетки: R это id породы, G это свет от неба.

uniform sampler2D grid : filter_nearest, repeat_disable;
// та же текстура со сглаживанием: свет от неба надо читать плавно, иначе
// освещение ступенями по 8 пикселей выдаёт сетку
uniform sampler2D grid_lin : filter_linear, repeat_disable;

uniform sampler2DArray tex_color : filter_linear_mipmap, repeat_enable;
uniform sampler2DArray tex_normal : filter_linear_mipmap, repeat_enable;

uniform vec4 mat_col[32];    // rgb — подкраска текстуры, a — прозрачность
uniform vec4 mat_ore[32];    // rgb — цвет вкраплений руды
uniform vec4 mat_meta[32];   // r — разброс тона, g — вид, b — блеск, a — рельеф
uniform vec4 mat_tex[32];    // r — слой текстуры, g — частиц на плитку, b — поворот

uniform vec2 tex_cells;      // размер текстуры сетки в частицах, вместе с полями
uniform vec2 inner_from;     // где начинается «своя» часть тайла
uniform vec2 inner_to;
uniform vec2 tile_origin;    // мировые координаты своей части, в частицах

uniform vec3 sun_color : source_color = vec3(1.0, 0.78, 0.52);
uniform vec3 sky_color : source_color = vec3(0.44, 0.55, 0.72);
uniform vec3 cave_color : source_color = vec3(0.12, 0.13, 0.18);
uniform vec3 bounce_color : source_color = vec3(0.42, 0.28, 0.18);
uniform vec3 sun_dir = vec3(-0.46, -0.78, -0.43);   // z вниз: свет идёт в экран
uniform float day : hint_range(0.0, 1.0) = 1.0;
uniform float detail : hint_range(0.0, 1.0) = 1.0;
uniform float time_s = 0.0;
uniform float exposure = 1.55;

// ---- шум ----
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
		p = p * 2.03 + 19.19;
		a *= 0.5;
	}
	return v;
}

// ---- чтение сетки ----
float mat_at(vec2 cell) {
	return floor(texture(grid, (floor(cell) + 0.5) / tex_cells).r * 255.0 + 0.5);
}

// Свет от неба, размытый по площади. В сетке он посчитан по колонкам, и без
// размытия под каждым перекрытием получался бы тёмный прямоугольник с резкой
// вертикальной границей. Пять выборок дают мягкую полутень почти бесплатно.
float sky_light(vec2 cell_pos) {
	float l = texture(grid_lin, cell_pos / tex_cells).g * 0.36;
	l += texture(grid_lin, (cell_pos + vec2(-3.0, -1.0)) / tex_cells).g * 0.16;
	l += texture(grid_lin, (cell_pos + vec2(3.0, -1.0)) / tex_cells).g * 0.16;
	l += texture(grid_lin, (cell_pos + vec2(-6.5, -2.5)) / tex_cells).g * 0.16;
	l += texture(grid_lin, (cell_pos + vec2(6.5, -2.5)) / tex_cells).g * 0.16;
	return clamp(l, 0.0, 1.0);
}

float kind_of(float id) {
	return mat_meta[int(id)].g;
}

// Пустота для формы: листва, вода и фоновая обшивка объёма не держат
bool is_void(float id) {
	if (id < 0.5) {
		return true;
	}
	float k = kind_of(id);
	return k == 6.0 || k == 9.0 || k == 11.0;
}

float occ(vec2 cell) {
	return is_void(mat_at(cell)) ? 0.0 : 1.0;
}

// Непрерывное поле плотности по четырём ближайшим частицам и его производные.
// Возвращает (плотность, наклон по X, наклон по Y).
vec3 density(vec2 p) {
	vec2 q = p - 0.5;
	vec2 b = floor(q);
	vec2 f = q - b;
	float o00 = occ(b);
	float o10 = occ(b + vec2(1.0, 0.0));
	float o01 = occ(b + vec2(0.0, 1.0));
	float o11 = occ(b + vec2(1.0, 1.0));
	vec2 s = f * f * (3.0 - 2.0 * f);
	vec2 ds = 6.0 * f * (1.0 - f);
	float d = mix(mix(o00, o10, s.x), mix(o01, o11, s.x), s.y);
	float gx = mix(o10 - o00, o11 - o01, s.y) * ds.x;
	float gy = mix(o01 - o00, o11 - o10, s.x) * ds.y;
	return vec3(d, gx, gy);
}

void fragment() {
	vec2 cell_f = UV * tex_cells;
	vec2 cell = floor(cell_f);
	vec2 sub = fract(cell_f);
	vec2 world = tile_origin + (cell - inner_from);
	vec2 wp = world + sub;                            // точка мира в частицах

	if (cell.x < inner_from.x || cell.y < inner_from.y
			|| cell.x >= inner_to.x || cell.y >= inner_to.y) {
		discard;                                       // поля тайла не наши
	}

	float id = mat_at(cell);
	if (id < 0.5) {
		// ---- воздух: только травинки над дёрном ----
		float below = mat_at(cell + vec2(0.0, 1.0));
		if (below < 0.5 || below > 1.5 || sub.y < 0.2) {
			discard;
		}
		float lg_a = sky_light(cell_f);
		float t = (sub.y - 0.2) / 0.8;                 // 0 сверху, 1 у земли
		float sway = sin(time_s * 1.1 + world.x * 0.31) * 0.18 * (1.0 - t);
		float xx = (wp.x + sway) * 4.0;
		if (vnoise(vec2(xx, floor(world.y) * 0.7)) < 0.32 + (1.0 - t) * 0.5) {
			discard;
		}
		vec3 gc = mix(vec3(0.26, 0.3, 0.15), vec3(0.6, 0.54, 0.28), (1.0 - t) * 0.8);
		gc *= 0.8 + hash12(vec2(floor(xx), 3.0)) * 0.55;
		vec3 lit = sun_color * lg_a * day * (0.6 + 0.4 * (1.0 - t))
			+ sky_color * lg_a * 0.45 + cave_color;
		COLOR = vec4(gc * lit * exposure, 1.0);
	} else {
		vec4 base4 = mat_col[int(id)];
		vec4 meta = mat_meta[int(id)];
		vec4 tinfo = mat_tex[int(id)];
		float variance = meta.r;
		float gloss = meta.b;
		float relief = meta.a;
		float layer = tinfo.r;
		float per_tile = tinfo.g;                      // частиц на одну плитку
		float alpha = base4.a;
		float kind = meta.g;

		// сколько частиц на пиксель: при отдалении мелкую деталь гасим
		float ppx = fwidth(wp.x);
		float micro = clamp(1.3 - ppx * 1.2, 0.0, 1.0) * detail;

		float lg = sky_light(cell_f);
		float sun_vis = lg * day;

		// ---- форма ----
		vec3 dn3 = density(wp);
		float d = dn3.x;
		if (kind != 11.0 && kind != 9.0) {
			float jag = (fbm(wp * 3.1) - 0.5) * 0.14 * micro;
			alpha *= smoothstep(0.34, 0.56, d + jag);
		}
		if (alpha < 0.004) {
			discard;
		}

		// ---- текстура ----
		// Две плитки разного масштаба, смешанные крупным шумом: одна и та же
		// фотография перестаёт читаться повтором на большой площади.
		vec2 t1 = wp / per_tile;
		vec2 t2 = wp / (per_tile * 2.7) + 0.37;
		float blend = smoothstep(0.35, 0.65, fbm(wp * 0.02));
		vec3 c1 = texture(tex_color, vec3(t1, layer)).rgb;
		vec3 c2 = texture(tex_color, vec3(t2, layer)).rgb;
		vec3 alb = mix(c1, c2, blend * 0.55);

		vec3 n1 = texture(tex_normal, vec3(t1, layer)).xyz * 2.0 - 1.0;
		vec3 n2 = texture(tex_normal, vec3(t2, layer)).xyz * 2.0 - 1.0;
		vec3 tn = normalize(mix(n1, n2, blend * 0.55));

		// подкраска: одна текстура обслуживает несколько пород (земля и грядка,
		// камень и постройка), оттенок доводим множителем
		alb *= base4.rgb;

		// крупные пятна и вариация тона
		alb *= 1.0 + (fbm(wp * 0.045) - 0.5) * 0.5 * (0.4 + variance);
		alb *= 1.0 + (fbm(wp * 0.3) - 0.5) * 0.35 * (0.4 + variance);

		// ---- деталь по виду породы ----
		if (kind == 1.0) {
			// трава: дёрн только сверху, ниже проступает земля
			float depth_in = sub.y + (mat_at(cell + vec2(0.0, -1.0)) < 0.5 ? 0.0 : 1.0);
			vec3 soil = texture(tex_color, vec3(wp / 9.0, mat_tex[2].r)).rgb * mat_col[2].rgb;
			alb = mix(alb, soil, clamp(depth_in * 0.85 - 0.3, 0.0, 0.8));
		} else if (kind == 3.0) {
			// руда: вкрапления поверх камня
			float v = fbm(wp * 0.95 + 13.0);
			float m = smoothstep(0.55, 0.7, v);
			vec3 oc = mat_ore[int(id)].rgb * (0.9 + hash12(floor(wp * 2.5)) * 0.4);
			alb = mix(alb, oc, m * 0.9);
			alb += oc * smoothstep(0.68, 0.76, v) * 0.5;
			gloss = mix(gloss, 0.8, m);
		} else if (kind == 6.0) {
			// листва: рваная масса с просветами насквозь
			float v = fbm(wp * 1.25);
			if (v < 0.4) {
				discard;
			}
			alb *= 0.7 + v * 0.9;
		} else if (kind == 7.0) {
			// профлист: рёбра и потёки ржавчины
			float rib = abs(fract(wp.x * 0.5) - 0.5) * 2.0;
			alb *= 0.82 + rib * 0.45;
			float rust = fbm(vec2(wp.x * 0.6, wp.y * 0.12) + 21.0);
			alb = mix(alb, vec3(0.35, 0.19, 0.11), smoothstep(0.6, 0.9, rust) * 0.6);
		} else if (kind == 8.0) {
			// стекло: мутное, с бликом
			alb = mix(alb, vec3(0.5, 0.6, 0.66), 0.6);
			alpha *= 0.55;
			gloss = 0.9;
		} else if (kind == 9.0) {
			// вода: волны и просветление к поверхности
			float w = sin(wp.x * 0.42 + time_s * 1.5) * 0.5 + sin(wp.x * 0.15 - time_s * 0.8) * 0.5;
			alb = mix(alb, vec3(0.14, 0.28, 0.26), 0.75) + vec3(0.02, 0.05, 0.06) * w;
			if (mat_at(cell + vec2(0.0, -1.0)) < 0.5) {
				alb += vec3(0.06, 0.12, 0.12) * (1.0 - sub.y);
			}
			alpha *= 0.74;
			gloss = 1.0;
		} else if (kind == 11.0) {
			// фоновая обшивка: помещение читается, но не спорит с породой
			alb *= 0.55;
		}

		// ---- нормаль: крупная форма плюс рельеф текстуры ----
		vec3 n = normalize(vec3(
			-dn3.y * 2.4 + tn.x * relief * micro * 1.6,
			-dn3.z * 2.4 + tn.y * relief * micro * 1.6,
			1.0));

		// ---- освещение ----
		vec3 L = normalize(sun_dir);
		float ndl = max(dot(n, -L), 0.0);
		float wrap = max(dot(n, -L) * 0.5 + 0.5, 0.0);      // мягкий подсвет
		float sky_up = clamp(0.5 - n.y * 0.5, 0.0, 1.0);    // сколько видно неба

		vec3 light = sun_color * (ndl * 1.05 + wrap * 0.35) * sun_vis;
		light += sky_color * sky_up * lg * 0.75 * mix(0.35, 1.0, day);
		light += bounce_color * (1.0 - sky_up) * lg * 0.3;
		light += cave_color * (1.0 - lg * 0.7) * 1.15;
		light *= exposure;

		// блик: мокрый камень, металл, стекло, вода
		vec3 H = normalize(-L + vec3(0.0, 0.0, 1.0));
		light += sun_color * pow(max(dot(n, H), 0.0), mix(8.0, 48.0, gloss)) * gloss * sun_vis * 0.8;

		vec3 col = alb * light;

		// ---- контакт с воздухом ----
		float edge = 1.0 - smoothstep(0.45, 0.95, d);
		col *= 1.0 - edge * 0.3 * (1.0 - sun_vis * 0.5);    // тень под кромкой
		col += sun_color * edge * ndl * sun_vis * 0.45;     // пересвет по кромке

		// ---- затенение в глубине массива ----
		float wide = (occ(cell + vec2(-2.0, 0.0)) + occ(cell + vec2(2.0, 0.0))
			+ occ(cell + vec2(0.0, -2.0)) + occ(cell + vec2(0.0, 2.0))) * 0.25;
		col *= mix(1.0, 0.85, wide * (1.0 - edge));

		COLOR = vec4(col, alpha);
	}
}

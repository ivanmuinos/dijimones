shader_type spatial;
// Decorado de papel recortado (árboles, palmeras, rocas, cabinas de teléfono...): forma por SDF con
// borde blanco, una mitad más oscura para dar volumen y fibra de papel. Quad vertical que mira a la cámara.
// INSTANCE_CUSTOM.r = variante (0..1) para cambiar colores/forma entre instancias.
render_mode unshaded, cull_disabled;

uniform int shape = 0; // 0 árbol, 1 palmera, 2 roca, 3 cabina, 4 flor, 5 caracola, 6 arbusto, 7 montaña, 8 pasto, 9 cofre, 10 piedra sagrada
uniform vec3 color_a : source_color = vec3(0.3, 0.62, 0.3);
uniform vec3 color_b : source_color = vec3(0.55, 0.36, 0.2);
uniform vec3 color_c : source_color = vec3(0.9, 0.9, 0.95);
uniform float border = 0.035;

varying flat float v_var;
varying flat vec3 v_glow;

void vertex() {
	v_var = INSTANCE_CUSTOM.r;
	v_glow = INSTANCE_CUSTOM.gba;
	vec3 scale = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
	vec3 right = normalize(cross(vec3(0.0, 1.0, 0.0), INV_VIEW_MATRIX[2].xyz));
	vec3 fwd = normalize(cross(right, vec3(0.0, 1.0, 0.0)));
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(vec4(right * scale.x, 0.0), vec4(0.0, scale.y, 0.0, 0.0), vec4(fwd * scale.z, 0.0), MODEL_MATRIX[3]);
}

float sd_circle(vec2 p, vec2 c, float r) { return length(p - c) - r; }
float sd_box(vec2 p, vec2 c, vec2 b) { vec2 d = abs(p - c) - b; return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0); }
float sd_tri(vec2 p, vec2 a, vec2 b, vec2 c) {
	vec2 e0 = b - a, e1 = c - b, e2 = a - c;
	vec2 v0 = p - a, v1 = p - b, v2 = p - c;
	vec2 pq0 = v0 - e0 * clamp(dot(v0, e0) / dot(e0, e0), 0.0, 1.0);
	vec2 pq1 = v1 - e1 * clamp(dot(v1, e1) / dot(e1, e1), 0.0, 1.0);
	vec2 pq2 = v2 - e2 * clamp(dot(v2, e2) / dot(e2, e2), 0.0, 1.0);
	float s = sign(e0.x * e2.y - e0.y * e2.x);
	vec2 d = min(min(vec2(dot(pq0, pq0), s * (v0.x * e0.y - v0.y * e0.x)), vec2(dot(pq1, pq1), s * (v1.x * e1.y - v1.y * e1.x))), vec2(dot(pq2, pq2), s * (v2.x * e2.y - v2.y * e2.x)));
	return -sqrt(d.x) * sign(d.y);
}

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

void fragment() {
	// p: x en [-0.5, 0.5], y en [0, 1] desde el piso
	vec2 p = vec2(UV.x - 0.5, 1.0 - UV.y);
	float d = 1e3;      // forma completa
	float d2 = 1e3;     // parte con color_a (copa / hojas / vidrio)
	vec3 col_main = color_b;
	vec3 col_part = color_a;
	if (shape == 0) {
		float trunk = sd_box(p, vec2(0.0, 0.2), vec2(0.06, 0.2));
		float crown = min(min(sd_circle(p, vec2(0.0, 0.62), 0.27), sd_circle(p, vec2(-0.17, 0.5), 0.19)), sd_circle(p, vec2(0.17, 0.5), 0.19));
		d = min(trunk, crown); d2 = crown;
	} else if (shape == 1) {
		float trunk = sd_box(p + vec2(p.y * p.y * 0.25, 0.0), vec2(0.0, 0.35), vec2(0.045, 0.35));
		float leaves = 1e3;
		for (int i = 0; i < 5; i++) {
			float a = -1.2 + float(i) * 0.6;
			vec2 tip = vec2(sin(a) * 0.45, 0.78 + cos(a) * 0.12 - abs(sin(a)) * 0.25);
			leaves = min(leaves, sd_tri(p, vec2(-0.03, 0.74), vec2(0.03, 0.74), tip));
		}
		leaves -= 0.03;
		d = min(trunk, leaves); d2 = leaves;
	} else if (shape == 2) {
		d = min(sd_circle(p, vec2(0.0, 0.22), 0.26), sd_box(p, vec2(0.0, 0.1), vec2(0.36, 0.1)) - 0.06);
		d2 = 1e3; col_main = color_b;
	} else if (shape == 3) {
		float booth = sd_box(p, vec2(0.0, 0.45), vec2(0.2, 0.45)) - 0.02;
		float glass = sd_box(p, vec2(0.0, 0.5), vec2(0.13, 0.28));
		d = booth; d2 = glass; col_main = color_c; col_part = color_a;
	} else if (shape == 4) {
		float stem = sd_box(p, vec2(0.0, 0.2), vec2(0.03, 0.2));
		float petals = 1e3;
		for (int i = 0; i < 5; i++) {
			float a = float(i) * 1.2566;
			petals = min(petals, sd_circle(p, vec2(0.0, 0.48) + vec2(cos(a), sin(a)) * 0.13, 0.1));
		}
		float center = sd_circle(p, vec2(0.0, 0.48), 0.07);
		d = min(stem, petals); d2 = petals; col_part = color_a;
		if (center < 0.0) { d2 = 1e3; col_main = vec3(1.0, 0.85, 0.3); }
	} else if (shape == 5) {
		d = sd_circle(p * vec2(1.0, 1.4), vec2(0.0, 0.2), 0.22);
		d2 = 1e3; col_main = color_c;
	} else if (shape == 6) {
		d = min(min(sd_circle(p, vec2(-0.2, 0.28), 0.22), sd_circle(p, vec2(0.18, 0.3), 0.24)), sd_circle(p, vec2(0.0, 0.45), 0.25));
		d = max(d, -p.y + 0.02);
		d2 = d; col_part = color_a;
		// bayitas
		if (sd_circle(fract(p * 6.0) - 0.5, vec2(0.0), 0.12) < 0.0 && v_var > 0.5) { col_part = color_c; }
	} else if (shape == 7) {
		// montaña: triángulo con picos irregulares y nieve arriba
		float m = sd_tri(p, vec2(-0.5, 0.0), vec2(0.5, 0.0), vec2(0.04 * (v_var - 0.5), 0.95));
		m = min(m, sd_tri(p, vec2(-0.5, 0.0), vec2(0.15, 0.0), vec2(-0.25, 0.62)));
		d = m; d2 = 1e3; col_main = color_a;
		float snow_line = 0.72 + 0.04 * sin(p.x * 40.0);
		if (p.y > snow_line) { d2 = -1.0; col_part = color_c; }
	} else if (shape == 8) {
		float g = 1e3;
		for (int i = 0; i < 4; i++) {
			float x = -0.3 + float(i) * 0.2;
			g = min(g, sd_tri(p, vec2(x - 0.08, 0.0), vec2(x + 0.08, 0.0), vec2(x + 0.05 * sin(float(i) * 2.0), 0.7 + 0.25 * fract(float(i) * 0.61))));
		}
		d = g; d2 = g; col_part = color_a;
	} else if (shape == 10) {
		// piedra sagrada: monolito redondeado con el emblema que brilla (color por instancia en INSTANCE_CUSTOM.g..)
		float stone = sd_box(p, vec2(0.0, 0.42), vec2(0.26, 0.38)) - 0.1;
		float crest = abs(sd_circle(p, vec2(0.0, 0.55), 0.12)) - 0.03;
		d = stone; d2 = 1e3; col_main = color_b;
		if (crest < 0.0) { d2 = -1.0; col_part = v_glow; }
	} else {
		// cofre: caja con tapa y cerradura
		float box = sd_box(p, vec2(0.0, 0.28), vec2(0.38, 0.28)) - 0.03;
		float lid = sd_box(p, vec2(0.0, 0.62), vec2(0.4, 0.08)) - 0.03;
		float lock = sd_box(p, vec2(0.0, 0.48), vec2(0.06, 0.08));
		d = min(box, lid); d2 = lid; col_main = color_b; col_part = color_a;
		if (lock < 0.0) { d2 = -1.0; col_part = color_c; }
	}
	if (d > border) discard;
	vec3 col = d2 < 0.0 ? col_part : col_main;
	// variación por instancia
	col *= 0.9 + 0.2 * v_var;
	// mitad derecha en sombra (volumen de papel doblado)
	if (p.x > 0.02 * sin(p.y * 20.0)) col *= 0.86;
	if (d > 0.0) col = vec3(0.98, 0.96, 0.9);
	col *= 0.95 + 0.05 * hash(floor(UV * 64.0));
	ALBEDO = col;
}

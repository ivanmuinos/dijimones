shader_type spatial;
// Piso de papel: manchas de dos materiales (pasto/arena) recortadas a mano, con fibra de papel
// y un filo claro donde se superponen. Coordenadas de mundo, así el plano puede seguir al jugador.
render_mode unshaded, cull_disabled;

uniform vec3 base_color : source_color = vec3(0.47, 0.72, 0.38);
uniform vec3 base_dark : source_color = vec3(0.41, 0.65, 0.33);
uniform vec3 patch_color : source_color = vec3(0.93, 0.84, 0.6);
uniform vec3 patch_dark : source_color = vec3(0.88, 0.78, 0.53);
uniform float patch_amount = 0.45;
uniform float patch_scale = 0.06;
// mar: agua donde x de mundo > water_from (borde del mapa en la playa)
uniform float water_from = 100000.0;
uniform vec3 water_color : source_color = vec3(0.35, 0.72, 0.92);
uniform vec3 water_deep : source_color = vec3(0.22, 0.55, 0.85);

varying vec3 world_pos;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

float fbm(vec2 p) {
	return noise(p) * 0.6 + noise(p * 2.3) * 0.3 + noise(p * 5.1) * 0.1;
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_pos.xz;
	// manchas grandes con borde "cortado con tijera" (escalonado)
	float n = fbm(p * patch_scale);
	float cut = floor(noise(p * 0.8) * 3.0) / 3.0 * 0.015;
	float m = n + cut;
	float edge = 1.0 - patch_amount;
	vec3 col;
	// sin manchas de pasto cerca de la orilla: ahí es todo arena
	float near_shore = smoothstep(water_from - 7.0, water_from - 3.0, p.x);
	m -= near_shore;
	if (m > edge) {
		col = mix(patch_color, patch_dark, step(0.5, noise(p * 0.9)));
	} else {
		col = mix(base_color, base_dark, step(0.55, noise(p * 0.7 + 3.0)));
	}
	// filo claro y sombra fina en el borde de la mancha (papel superpuesto)
	float d = m - edge;
	if (d > 0.0 && d < 0.008) col = mix(col, vec3(1.0, 0.98, 0.92), 0.8);
	if (d < 0.0 && d > -0.008) col *= 0.85;
	// mar con orilla ondulada, espuma de papel y olas que van y vienen
	float shore = water_from + sin(p.y * 0.35) * 0.8 + sin(p.y * 0.11 + 2.0) * 1.2;
	float wave = sin(TIME * 0.9) * 0.4;
	if (p.x > shore + wave) {
		float depth = p.x - shore;
		col = mix(water_color, water_deep, smoothstep(2.0, 10.0, depth));
		float stripe = fract((p.x - TIME * 0.6) * 0.35 + sin(p.y * 0.5) * 0.2);
		if (stripe < 0.08 && depth > 1.5) col = mix(col, vec3(1.0), 0.35);
		if (depth < wave + 0.6) col = vec3(0.98, 0.96, 0.9);
	} else if (p.x > shore + wave - 1.2) {
		col = base_dark * 0.92;  // arena mojada
	}
	// fibra de papel
	col *= 0.94 + 0.06 * noise(p * 22.0);
	ALBEDO = col;
}

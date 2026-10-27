shader_type spatial;
// Pared de acantilado de papel: capas de cartón apiladas (franjas), más oscura abajo, con filo blanco arriba.
// UV.y = 0 arriba, 1 abajo; UV2.y = altura de la pared en metros (para que las capas tengan el mismo grosor).
render_mode unshaded, cull_disabled;

uniform vec3 cliff_color : source_color = vec3(0.78, 0.62, 0.42);
uniform vec3 cliff_dark : source_color = vec3(0.62, 0.47, 0.3);

varying vec3 world_pos;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float y = world_pos.y;
	// capas de 0.25 m con borde ondulado de recorte
	float wobble = sin((world_pos.x + world_pos.z) * 3.1) * 0.025;
	float layer = floor((y + wobble) / 0.25);
	vec3 col = mix(cliff_dark, cliff_color, 0.55 + 0.45 * fract(layer * 0.37));
	float f = fract((y + wobble) / 0.25);
	if (f > 0.9) col *= 0.82;  // sombra entre capas
	col *= mix(0.78, 1.0, UV.y < 0.5 ? 1.0 : 1.0 - (UV.y - 0.5));  // más oscuro abajo
	if (UV.y < 0.06) col = vec3(0.98, 0.96, 0.9);  // filo de papel arriba
	col *= 0.95 + 0.05 * hash(floor(world_pos.xy * 24.0) + floor(world_pos.zy * 24.0));
	ALBEDO = col;
}

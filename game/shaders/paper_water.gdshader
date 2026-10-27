shader_type spatial;
// Cascada y laguna de papel. COLOR.r = 0: cascada (franjas que bajan); 1: laguna al pie (ondas de espuma).
render_mode unshaded, cull_disabled;

uniform vec3 water_color : source_color = vec3(0.45, 0.78, 0.95);
uniform vec3 water_dark : source_color = vec3(0.28, 0.6, 0.88);

void fragment() {
	vec3 col;
	if (COLOR.r < 0.5) {
		float stripe = fract(UV.y * 3.0 - TIME * 1.6 + floor(UV.x * 4.0) * 0.37);
		col = mix(water_dark, water_color, step(0.45, stripe));
		if (stripe < 0.12) col = mix(col, vec3(1.0), 0.6);
		float edge = min(UV.x, 1.0 - UV.x);
		if (edge < 0.08) col = vec3(0.98, 0.96, 0.9);
		if (UV.y > 0.9) col = mix(col, vec3(1.0), 0.7);
	} else {
		vec2 p = UV * 2.0 - 1.0;
		float r = length(p);
		if (r > 1.0) discard;
		col = mix(water_color, water_dark, r);
		float ring = fract(r * 3.0 - TIME * 0.8);
		if (ring < 0.12) col = mix(col, vec3(1.0), 0.5);
		if (r > 0.88) col = vec3(0.98, 0.96, 0.9);
	}
	ALBEDO = col;
}

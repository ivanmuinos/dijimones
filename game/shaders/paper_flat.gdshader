shader_type spatial;
// Formas planas de papel para cosas chicas: sombras, gemas de XP, proyectiles, aura y onda expansiva.
// INSTANCE_CUSTOM = color (rgb) + alpha. `kind`: 0 sombra, 1 círculo con borde, 2 rombo, 3 anillo.
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;

uniform int kind = 0;
uniform bool billboard = false;

varying vec4 v_color;

void vertex() {
	v_color = INSTANCE_CUSTOM;
	if (billboard) {
		vec3 scale = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * scale.x, INV_VIEW_MATRIX[1] * scale.y, INV_VIEW_MATRIX[2] * scale.z, MODEL_MATRIX[3]);
	}
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	if (kind == 0) {
		if (r > 1.0) discard;
		ALBEDO = vec3(0.1, 0.12, 0.1);
		ALPHA = 0.35 * v_color.a;
	} else if (kind == 1) {
		if (r > 1.0) discard;
		ALBEDO = r > 0.72 ? vec3(0.98, 0.96, 0.9) : v_color.rgb * (r < 0.35 ? 1.25 : 1.0);
		ALPHA = 1.0;
	} else if (kind == 2) {
		float m = abs(p.x) * 1.4 + abs(p.y);
		if (m > 1.0) discard;
		ALBEDO = m > 0.72 ? vec3(0.98, 0.96, 0.9) : v_color.rgb * (p.x < 0.0 ? 1.15 : 0.9);
		ALPHA = 1.0;
	} else {
		float w = 0.08;
		if (abs(r - 0.92) > w) {
			if (r > 0.92) discard;
			ALBEDO = v_color.rgb;
			ALPHA = v_color.a * 0.35;
		} else {
			ALBEDO = mix(v_color.rgb, vec3(1.0), 0.4);
			ALPHA = v_color.a;
		}
	}
}

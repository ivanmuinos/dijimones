shader_type spatial;
// Recorte de papel (estilo Paper Mario): frame de una tira de sprites sobre un quad que mira a la cámara
// (billboard en Y), con borde blanco de papel y destello al recibir daño.
// Pensado para MultiMesh; INSTANCE_CUSTOM = (frame, escala x para el giro de "hoja", destello, -).
render_mode unshaded, cull_disabled, depth_draw_opaque;

uniform sampler2D sprite : source_color, filter_nearest;
uniform float frames = 1.0;
uniform float frame_size = 96.0;
uniform float border_texels = 2.0;
uniform vec3 paper_color : source_color = vec3(0.98, 0.96, 0.9);

varying flat float v_frame;
varying flat float v_flash;
varying float v_side;

void vertex() {
	v_frame = INSTANCE_CUSTOM.r;
	v_flash = INSTANCE_CUSTOM.b;
	// giro de hoja: la escala x va de 1 a -1 (en el medio el papel se ve de canto)
	VERTEX.x *= INSTANCE_CUSTOM.g;
	v_side = INSTANCE_CUSTOM.g;
	// billboard en Y conservando la escala de la instancia
	vec3 scale = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
	vec3 right = normalize(cross(vec3(0.0, 1.0, 0.0), INV_VIEW_MATRIX[2].xyz));
	vec3 fwd = normalize(cross(right, vec3(0.0, 1.0, 0.0)));
	mat4 bb = mat4(vec4(right * scale.x, 0.0), vec4(0.0, scale.y, 0.0, 0.0), vec4(fwd * scale.z, 0.0), MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = VIEW_MATRIX * bb;
}

float alpha_at(vec2 uv) {
	// uv dentro del frame (0..1); fuera del frame = transparente
	if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) return 0.0;
	return texture(sprite, vec2((v_frame + uv.x) / frames, uv.y)).a;
}

void fragment() {
	vec2 uv = UV;
	vec4 c = texture(sprite, vec2((v_frame + uv.x) / frames, uv.y));
	vec3 col = c.rgb;
	float a = c.a;
	if (a < 0.5) {
		// borde de papel: algún vecino opaco a `border_texels`
		float t = border_texels / frame_size;
		float n = 0.0;
		for (int i = 0; i < 8; i++) {
			float ang = float(i) * 0.785398;
			n = max(n, alpha_at(uv + vec2(cos(ang), sin(ang)) * t));
		}
		if (n < 0.5) discard;
		col = paper_color;
		a = 1.0;
	}
	// el dorso del papel (en pleno giro) se ve más oscuro
	col *= mix(0.75, 1.0, smoothstep(0.0, 0.35, abs(v_side)));
	col = mix(col, vec3(1.0), v_flash);
	ALBEDO = col;
}

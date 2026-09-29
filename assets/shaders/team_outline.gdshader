shader_type canvas_item;
// Contorno exterior del color del bando alrededor de la silueta del sprite.
// Un ShaderMaterial compartido por equipo mantiene el batching del canvas.

uniform vec4 outline_color : source_color = vec4(1.0);
// Grosor en píxeles de textura (los sprites se rasterizan a 2x: 6 px = 3 px de mundo).
uniform float outline_width = 6.0;

void fragment() {
	vec4 base = texture(TEXTURE, UV);
	vec2 step_uv = TEXTURE_PIXEL_SIZE * outline_width;
	float edge = 0.0;
	for (int i = 0; i < 8; i++) {
		float angle = float(i) * 0.785398;
		vec2 dir = vec2(cos(angle), sin(angle));
		edge = max(edge, texture(TEXTURE, UV + dir * step_uv).a);
		edge = max(edge, texture(TEXTURE, UV + dir * step_uv * 0.5).a);
	}
	vec4 ring = vec4(outline_color.rgb, edge * outline_color.a);
	COLOR = mix(ring, base, base.a);
}

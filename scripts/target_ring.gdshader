shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

void fragment() {
	float radius = length(UV - vec2(0.5)) * 2.2;
	float inner = smoothstep(0.60, 0.84, radius);
	float outer = 1.0 - smoothstep(0.96, 1.10, radius);
	ALBEDO = mix(vec3(1.0, 0.48, 0.10), vec3(1.0, 0.76, 0.37), smoothstep(0.73, 0.96, radius));
	ALPHA = inner * outer * 0.95;
}

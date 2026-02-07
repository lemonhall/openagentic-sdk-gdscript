shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_opaque;

uniform vec2 half_extents = vec2(0.6, 0.4);
uniform float radius = 2.0;

uniform vec4 color : source_color = vec4(0.35, 1.0, 0.55, 1.0);
uniform float ring_width = 0.12;
uniform float feather = 0.35;

uniform float ring_alpha = 0.38;
uniform float fill_alpha = 0.06;

uniform float pulse_speed = 2.0;
uniform float pulse_min = 0.35;
uniform float pulse_max = 0.95;

float sdf_rounded_box(vec2 p, vec2 b, float r) {
	vec2 q = abs(p) - b;
	return length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - r;
}

void fragment() {
	vec2 p = vec2(VERTEX.x, VERTEX.z);
	float sd = sdf_rounded_box(p, half_extents, radius);

	// Border ring around sd==0.
	float a_ring = 1.0 - smoothstep(ring_width, ring_width + feather, abs(sd));
	// Soft fill inside the zone.
	float a_fill = 1.0 - smoothstep(0.0, feather * 1.25, sd);

	float pulse = mix(pulse_min, pulse_max, 0.5 + 0.5 * sin(TIME * pulse_speed));
	float a = max(a_ring * ring_alpha, a_fill * fill_alpha) * pulse;

	ALBEDO = color.rgb;
	EMISSION = color.rgb * (a_ring * 1.35 + a_fill * 0.35) * pulse;
	ALPHA = a;
}

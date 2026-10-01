// Greybox "prototype grid" material: world-space 1m grid so jump distances are readable.
shader_type spatial;

uniform vec3 base_color : source_color = vec3(0.55, 0.56, 0.6);
uniform vec3 line_color : source_color = vec3(0.32, 0.33, 0.37);
uniform float cell_size = 1.0;
uniform float line_width = 1.2;

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 n = abs(world_normal);
	vec2 uv = n.y > 0.5 ? world_pos.xz : (n.x > 0.5 ? world_pos.zy : world_pos.xy);
	uv /= cell_size;
	vec2 grid = abs(fract(uv - 0.5) - 0.5) / (fwidth(uv) * line_width);
	float line = 1.0 - min(min(grid.x, grid.y), 1.0);
	ALBEDO = mix(base_color, line_color, line);
	ROUGHNESS = 0.9;
}

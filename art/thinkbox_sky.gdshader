shader_type sky;
// The sky as the operator's ThinkBox 2009 renders it: the engine's untextured fallback dome (flat blue-grey with a
// faint lat/long wireframe), plus ONE rectangle of the real HYPERION LEGENDS midday sky that managed to stream in,
// at its lowest mip level, around the sun (the scene's DirectionalLight, so it matches the shadows).
// Kept cool and dull on purpose: the yellow paint, the red hotfixes and the loot must stand out against it.

uniform float grid_strength = 0.35;  // 0 = no wireframe.
uniform bool show_patch = true;  // The streamed-in rectangle of real sky.

const float TAU_ = 6.2831853;

float grid_line(float v, float w) {
	float f = abs(fract(v) - 0.5);
	return smoothstep(0.5 - w, 0.5, f);
}

void sky() {
	vec3 d = normalize(EYEDIR);
	float h = d.y;
	float lon = atan(d.x, d.z) / TAU_ + 0.5;  // 0..1 around.
	float lat = asin(clamp(h, -1.0, 1.0)) / 1.5708;  // -1..1, 0 = horizon.

	vec3 top = vec3(0.30, 0.35, 0.42);
	vec3 hor = vec3(0.56, 0.59, 0.63);
	vec3 below = vec3(0.17, 0.18, 0.19);
	vec3 c = h > 0.0 ? mix(hor, top, pow(clamp(h, 0.0, 1.0), 0.55)) : mix(hor, below, pow(clamp(-h, 0.0, 1.0), 0.35));

	float g = max(grid_line(lon * 32.0, 0.035), grid_line(lat * 8.0, 0.07));
	c = mix(c, c * 1.18 + 0.03, g * smoothstep(0.0, 0.06, h) * grid_strength);

	if (show_patch) {
		vec3 sd = LIGHT0_ENABLED ? normalize(LIGHT0_DIRECTION) : normalize(vec3(-0.33, 0.82, 0.47));
		float slon = atan(sd.x, sd.z) / TAU_ + 0.5;
		float slat = asin(clamp(sd.y, -1.0, 1.0)) / 1.5708;
		float dl = fract(lon - slon + 0.5) - 0.5;
		if (abs(dl) < 0.085 && lat > max(slat - 0.30, 0.04) && lat < min(slat + 0.22, 0.98)) {
			vec2 cell = (floor(vec2(dl * 110.0, lat * 26.0)) + 0.5) / vec2(110.0, 26.0);
			vec3 blue = mix(vec3(0.55, 0.75, 0.95), vec3(0.16, 0.42, 0.85), smoothstep(0.0, 0.8, cell.y));
			float r = length(vec2(cell.x * 3.2, cell.y - slat));
			blue = mix(blue, vec3(0.80, 0.90, 1.0), smoothstep(0.16, 0.0, r) * 0.7);  // Halo.
			blue = mix(blue, vec3(1.0, 0.99, 0.94), step(r, 0.045));  // The sun: nearly white, not paint yellow.
			c = blue;
		}
	}
	COLOR = c;
}

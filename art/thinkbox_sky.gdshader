shader_type sky;
// The sky as the operator's ThinkBox 2009 renders it: the engine's untextured fallback dome (flat blue-grey with a
// faint lat/long wireframe), plus ONE rectangle of the real HYPERION LEGENDS sky that managed to stream in, at its
// lowest mip level. game.gd picks `variant` at random each time a level loads:
//   0 = midday: blue sky around the sun (the scene's DirectionalLight, so it matches the shadows)
//   1 = sunset: down at the horizon, under the sun's direction
//   2 = night: pixel stars and a moon where the sun would be
//   3 = missing texture (rare): even the fallback failed, the whole dome is the pink/black checker
// The grey boxes are lit the same whatever the sky says (the ThinkBox doesn't do time of day). Kept cool and dull so
// the yellow paint, the red hotfixes and the loot stand out.

uniform int variant = 0;
uniform float grid_strength = 0.35;  // 0 = no wireframe.
uniform bool show_patch = true;  // The streamed-in rectangle of real sky.

const float TAU_ = 6.2831853;

float grid_line(float v, float w) {
	float f = abs(fract(v) - 0.5);
	return smoothstep(0.5 - w, 0.5, f);
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void sky() {
	vec3 d = normalize(EYEDIR);
	float h = d.y;
	float lon = atan(d.x, d.z) / TAU_ + 0.5;  // 0..1 around.
	float lat = asin(clamp(h, -1.0, 1.0)) / 1.5708;  // -1..1, 0 = horizon.

	if (variant == 3) {
		// The iconic missing texture, everywhere, drawn on the six faces of a cube like a missing cubemap.
		vec3 a = abs(d);
		vec2 uv = a.x >= a.y && a.x >= a.z ? d.zy / a.x : (a.y >= a.z ? d.xz / a.y : d.xy / a.z);
		float k = mod(floor(uv.x * 4.0 + 8.0) + floor(uv.y * 4.0 + 8.0), 2.0);
		COLOR = mix(vec3(0.0), vec3(0.85, 0.0, 0.85), k);
	} else {
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
			if (variant == 1) {
				slat = 0.07;  // Sunset: the sun sits on the horizon, same direction.
			}
			float dl = fract(lon - slon + 0.5) - 0.5;
			float lo = variant == 1 ? 0.02 : max(slat - 0.30, 0.04);
			float hi = variant == 1 ? 0.34 : min(slat + 0.22, 0.98);
			float half_w = variant == 1 ? 0.11 : 0.085;
			if (abs(dl) < half_w && lat > lo && lat < hi) {
				// The lowest mip level: big blocks.
				vec2 cell = (floor(vec2(dl * 110.0, lat * 26.0)) + 0.5) / vec2(110.0, 26.0);
				float r = length(vec2(cell.x * 3.2, cell.y - slat));
				vec3 p;
				if (variant == 0) {
					p = mix(vec3(0.55, 0.75, 0.95), vec3(0.16, 0.42, 0.85), smoothstep(0.0, 0.8, cell.y));
					p = mix(p, vec3(0.80, 0.90, 1.0), smoothstep(0.16, 0.0, r) * 0.7);  // Halo.
					p = mix(p, vec3(1.0, 0.99, 0.94), step(r, 0.045));  // The sun: nearly white, not paint yellow.
				} else if (variant == 1) {
					float t = smoothstep(0.02, 0.34, cell.y);
					p = mix(vec3(0.96, 0.52, 0.30), vec3(0.62, 0.36, 0.55), smoothstep(0.0, 0.5, t));
					p = mix(p, vec3(0.28, 0.27, 0.52), smoothstep(0.45, 1.0, t));
					p = mix(p, vec3(1.0, 0.68, 0.45), smoothstep(0.14, 0.0, r) * 0.8);  // Glow.
					p = mix(p, vec3(1.0, 0.86, 0.74), step(r, 0.045));  // The sun: warm white, not paint yellow.
				} else {
					p = mix(vec3(0.10, 0.12, 0.26), vec3(0.03, 0.04, 0.11), smoothstep(0.0, 0.8, cell.y));
					// Pixel stars: small cells, a few percent lit. Static (TIME would re-render the sky every frame).
					float s = hash(floor(vec2(dl * 220.0, lat * 96.0)) + 17.0);
					if (s > 0.955) {
						p = mix(p, vec3(0.85, 0.88, 1.0), 0.35 + 0.65 * fract(s * 37.0));
					}
					p = mix(p, vec3(0.20, 0.24, 0.40), smoothstep(0.2, 0.0, r) * 0.6);  // Moonlit haze.
					// The moon: a pale disc with a crescent bite, on a finer pixel grid than the rest of the patch.
					vec2 mc = (floor(vec2(dl * 380.0, lat * 90.0)) + 0.5) / vec2(380.0, 90.0);
					float mr = length(vec2(mc.x * 2.3, mc.y - slat));
					float bite = length(vec2(mc.x * 2.3 + 0.03, mc.y - slat - 0.012));
					if (mr < 0.06 && bite > 0.055) {
						p = vec3(0.90, 0.92, 0.86);
					}
				}
				c = p;
			}
		}
		COLOR = c;
	}
}

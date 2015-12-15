const float gamma = 2.2;

uniform float u_exposure = 1.0;

vec3 filmic_tonemap(vec3 color)
{
	color = max(vec3(0.), color - vec3(0.004));
	color = (color * (6.2 * color + .5)) / (color * (6.2 * color + 1.7) + 0.06);
	return color;
}

vec3 uncharted2_tonemap(vec3 x) {
	float A = 0.15;
	float B = 0.50;
	float C = 0.10;
	float D = 0.20;
	float E = 0.02;
	float F = 0.30;

	return ((x*(A*x+C*B)+D*E)/(x*(A*x+B)+D*F))-E/F;
}

vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
	vec4 bg  = texture2D(texture, texture_coords);
	// return vec4(filmic_tonemap(pow(bg.rgb * u_exposure, vec3(gamma))), 1.0);
	return vec4(uncharted2_tonemap(pow(bg.rgb * u_exposure * 3.0, vec3(gamma))), 1.0);
}

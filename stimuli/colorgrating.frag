/*
 * File: colorgrating.frag
 * Shader for drawing of color gratings.
 *
 * Copyright 2014, Ian Andolina <http://github.com/iandol>, licenced under the MIT Licence
 *
 */

uniform float radius;
uniform vec2  center;
float dist;
uniform vec4 color1;
uniform vec4 color2;

varying vec3 baseColor;
varying float alpha;
varying float phase;
varying float frequency;
varying float sigma;
varying float contrast;

void main() {
	//current position
	vec2 pos = gl_TexCoord[0].xy;

	/* find our distance from center, if distance to center (aka radius of pixel) > Radius, discard this pixel: */
	if (radius > 0.0) {
		dist = distance(pos, center);
		if (dist > radius) discard;
	}

	//create our sinusoid
	float sv = sin(pos.x * frequency + phase);

	//if sigma >= 0, we want a smoothed squarewave grating, smoothstep does this
	if (sigma >= 0.0) {
		sv = smoothstep(-sigma, sigma, sv); //converts into 0-1 range
	}
    else {
		sv = (sv + 1.0) / 2.0; //simply get sv into 0 - 1 range;
	}

	//we first blend our colours from base using 0-1 contrast range
	if (contrast < 1.0) {
		color1.rgb = mix(baseColor, color1.rgb, contrast);
		color2.rgb = mix(baseColor, color2.rgb, contrast);
	}
	
	// and then mix our two colors using our grating position
	vec3 color = mix(color1.rgb, color2.rgb, sv);
	
	// off to the display, bye little pixel!
	gl_FragColor = vec4(color,alpha);
}
//code for shadertoy.com
/*
 * File: PolarBoardShader.frag
 * Shader for drawing of polar board.
 *
 */
 
/////////////////////////////////////--VARIABLES
// In PTB variables will come from the MATLAB 
// calling code via the vertex shader.
// See http://psychtoolbox.org/docs/ProceduralShadingAPI
//
//

uniform vec2	center;
uniform vec4	color1;
uniform vec4	color2;
uniform float	radius;

varying vec3	baseColor;
varying float	alpha;
varying float	phase;
varying float	radialFrequency;
varying float	circularFrequency;
varying float	sigma;
varying float	phase2;
varying float	contrast;

void main() {
	//current position
	vec2 pos = gl_TexCoord[0].xy;
	// distance
	float dist = distance( pos, center );

	/* find our distance from center, if distance to center 
	(aka radius of pixel) > Radius, discard this pixel: */
	if ( radius > 0.0 ) {
		if ( dist > radius ) discard;
	}

	//Calculate the angle and radius from the center.
	float angleMatrix = atan(pos.y - radius, pos.x - radius);
	float radiusMatrix = length(pos - radius);

	//create our sinusoid in -1 to 1 range, radialFrequency need to be integer to avoid clipping effect
	float sv = sin( angleMatrix * radialFrequency + phase );
	float sv2 = sin( radiusMatrix * circularFrequency + phase2 );

	sv = (sv + sv2) / 2.0;

	//create our sinusoid in -1 to 1 range
	//float sv = sin( fragCoord.x * frequency + phase );

	//if sigma >= 0, we want a squarewave grating, step or smoothstep does this depending on sigma value
	if ( sigma == 0.0 ) {
		sv = step( sigma, sv ); //converts into 0-1 range
	}
	else if ( sigma > 0.0 ) {
		sv = smoothstep( -sigma, sigma, sv ); //converts into 0-1 range
	}
	else {
		sv = (sv + 1.0) / 2.0; //simply get sv into 0 - 1 range (preserving sinusoid);
	}

	// start to mix our colors
	vec3 colorA = color1.rgb;
	vec3 colorB = color2.rgb;
	if ( contrast < 1.0 ) { //blend our colours from base colour if contrast < 1
		colorA = mix( baseColor, color1.rgb, contrast );
		colorB = mix( baseColor, color2.rgb, contrast );
	}

	// and then mix our two colors using sv (our position in the grating)
	vec3 colorOut = mix( colorA, colorB, sv );

	// this normalises the color range to a generic 2.2 gamma
	//colorOut = pow( colorOut, vec3( 1./2.2 ) );

	// off to the display, byebye little pixel!
	gl_FragColor = vec4( colorOut, alpha ); 
}
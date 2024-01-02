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
varying float	contrast;

#define PI 3.1415926538

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
	
	float theta = atan(pos.y - center[1], pos.x - center[0]);
	float len = length(pos - center);
	int x_index = int(mod((theta * 18.0 / PI) + phase, 2.0));
	int y_index = int(mod((log(len) * 5.0) + 0.0, 2.0));
	
	// Time varying pixel color
	//int x_index = int(mod(p.x * 10., 2.));
	//int y_index = int(mod(p.y * 10., 2.));
	bool black = x_index != y_index;

	// Output to screen
	if (black) {
		gl_FragColor = vec4(0., 0., 0., 1.);
	} else{
		gl_FragColor = vec4(1., 1., 1., 1.);
	}
}
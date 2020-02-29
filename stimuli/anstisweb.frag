// Author: iandol
// Title: anstis+cavanaugh shader
// code for http://editor.thebookofshaders.com

#ifdef GL_ES
precision mediump float;
#endif

void main() {
	/* Query current output texel position: */
	/* vec2 pos = gl_TexCoord[0].xy; */
	vec2 pos = gl_FragCoord.xy;
	float frequency = 0.04;
	float phase = 1.0;
	vec3 color = vec3(0.0);
	vec3 color1 = vec3(1.0,0.0,0.0);
	vec3 color2 = vec3(0.0,1.0,0);
	vec3 color3 = vec3(0.5,0.0,0.0);
	vec3 color4 = vec3(0.0,0.5,0);

	float sv = sin(pos.x * frequency + phase);
	sv = (sv + 1.0) / 2.0; //get sv into 0 - 1 range;

	if (mod(pos.x,2.0) > 1.0) {
		if (sv > 0.5) {
			color = color1;
		}
		else {
			color = color3;
		}
	}
	else {
		if (sv > 0.5) {
			color = color2;
		}
		else {
			color = color4;
		}
	}
	gl_FragColor = vec4(color,1.0);
}
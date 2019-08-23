// Author: iandol
// Title: anstis+cavanaugh shader

#ifdef GL_ES
precision mediump float;
#endif

void main() {

	 /* Query current output texel position: */
	/* vec2 pos = gl_TexCoord[0].xy; */
	vec2 st = gl_FragCoord.xy;

	vec3 color = vec3(0.);
	vec3 color1 = vec3(1.0,0.0,0.0);
	vec3 color2 = vec3(0.0,1.0,0);
	vec3 color3 = vec3(0.5,0.0,0.0);
	vec3 color4 = vec3(0.0,0.5,0);

	if (mod(st.x,2.0) > 1.0) {
		if (st.x > 100.0) {
			color = color1;
		}
		else {
		color = color3;
		}
	}
	else {
		if (st.x > 100.0) {
			color = color2;
		}
		else {
		color = color4;
		}
	}
	
	gl_FragColor = vec4(color,1.0);
}
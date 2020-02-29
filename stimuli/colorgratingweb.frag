void mainImage( out vec4 fragColor, in vec2 fragCoord )
//code for shadertoy.com
{
	//current position
	vec2 pos = fragCoord.xy;
	//base color to blend from
	vec3 baseColor = vec3(0.5, 0.5, 0.5);
	//first color
	vec3 color1 = vec3(1.0,0.0,0.0);
	//second color
	vec3 color2 = vec3(0.0,1.0,0);
	//grating frequency
	float frequency = 0.03;
	float phase = iTime;
	// sigma < 0.0  = sin grating 
	// sigma == 0.0 = square grating no smoothing
	// sigma > 0.0  = square grating with smoothing in sigma pixels
	float sigma = -1.0;
	//contrast from 0 - 1
	float contrast = 1.0;

	//create our sinusoid in -1 to 1 range
	float sv = sin(pos.x * frequency + phase);

	//if sigma >= 0, we want a squarewave grating, step or smoothstep does this depending on sigma value
	if (sigma == 0.0) {
		sv = step(sigma, sv); //converts into 0-1 range
	}
	else if (sigma > 0.0) {
		sv = smoothstep(-sigma, sigma, sv); //converts into 0-1 range
	}
	else {
		sv = (sv + 1.0) / 2.0; //simply get sv into 0 - 1 range (preserving sinusoid);
	}

	vec3 colorA = color1.rgb;
	vec3 colorB = color2.rgb;
	if (contrast < 1.0) { //blend our colours from base colour if contrast < 1
		colorA = mix(baseColor, color1.rgb, contrast);
		colorB = mix(baseColor, color2.rgb, contrast);
	}

	// and then mix our two colors using sv (our position in the grating)
	vec3 colorOut = mix(colorA, colorB, sv);
	
	// off to the display, byebye little pixel!
	fragColor = vec4(colorOut,1.0); 
}
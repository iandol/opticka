/*
 * File: PolarBoardShader.vert
 * Shader for drawing of Polar board.
 */

/* Constants that we need 2*pi: */
const float		twopi = 6.2831853072;

/* Conversion factor from degrees to radians: */
const float		deg2rad = 3.141592654 / 180.0;

/* Attributes passed from Screen(): See the ProceduralShadingAPI.m file for info: */
attribute vec4	modulateColor;
attribute vec4	auxParameters0;
attribute vec4	auxParameters1;

/* Information passed to the fragment shader: Attributes and precalculated per patch constants: */
varying vec3	baseColor;
varying float	alpha;
varying float	phase;
varying float	phase2;
varying float	radialFrequency;
varying float	circularFrequency;
varying float	contrast;

void main()
{
	/* Apply standard geometric transformations to patch: */
	gl_Position = ftransform();

	/* Don't pass real texture coordinates, but ones corrected for hardware offsets (-0.5,0.5) */
	gl_TexCoord[0] = ( gl_TextureMatrix[0] * gl_MultiTexCoord0 ) + vec4( -0.5, 0.5, 0.0, 0.0 );

	/* Passed Values from PTB draw */
	phase = deg2rad * auxParameters0[0];

	phase2 = deg2rad * auxParameters0[1];

	circularFrequency = auxParameters0[2];

	radialFrequency = auxParameters0[3];

	contrast = auxParameters1[0];

	/* base colour */
	baseColor = modulateColor.rgb;
	
	/* global alpha */
	alpha = modulateColor.a;
}
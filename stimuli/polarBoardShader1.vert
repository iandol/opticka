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
varying float	radialFrequency;
varying float	circularFrequency;
varying float	contrast;
varying float	sigma;

void main()
{
    /* Apply standard geometric transformations to patch: */
    gl_Position = ftransform();

    /* Don't pass real texture coordinates, but ones corrected for hardware offsets (-0.5,0.5) */
    gl_TexCoord[0] = ( gl_TextureMatrix[0] * gl_MultiTexCoord0 ) + vec4( -0.5, 0.5, 0.0, 0.0 );

    /* Convert Phase from degrees to radians: */
    phase = deg2rad * auxParameters0[0];

    /* radialfrequency is stored in auxParameters0[1] */
    radialFrequency = auxParameters0[1] * twopi;

    /* Contrast value is stored in auxParameters0[2]: */
    contrast = auxParameters0[2];

    /* Sigma value is stored in auxParameters0[3]: */
    sigma = auxParameters0[3];

    /* circularFrequency is stored in auxParameters1[0] */
    circularFrequency = auxParameters1[0] * twopi;

    /* base colour */
    baseColor = modulateColor.rgb;
    
    /* global alpha */
    alpha = modulateColor.a;
}
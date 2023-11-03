/*
 * File: checkerboard.vert
 * Shader for drawing of checkerboards.
 *
 * Copyright 2014, Ian Andolina <http://github.com/iandol>, licenced under the MIT Licence
 *
 */

/* Constants that we need 2*pi: */
const float twopi = 6.2831853072;

/* Conversion factor from degrees to radians: */
const float deg2rad = 3.141592654 / 180.0;

/* Attributes passed from Screen(): See the ProceduralShadingAPI.m file for info: */
attribute vec4 modulateColor;
attribute vec4 auxParameters0;
attribute vec4 auxParameters1;
attribute vec4 auxParameters2;

/* Information passed to the fragment shader: Attributes and precalculated per patch constants: */
varying vec3    baseColor;
varying float   alpha;
varying float   ppd;
varying float   size;
varying float   contrast;
varying float   phase;
varying vec4    colour1;
varying vec4    colour2;

void main()
{
    /* Apply standard geometric transformations to patch: */
    gl_Position = ftransform();

    /* Don't pass real texture coordinates, but ones corrected for hardware offsets (-0.5,0.5) */
    gl_TexCoord[0] = ( gl_TextureMatrix[0] * gl_MultiTexCoord0 ) + vec4( -0.5, 0.5, 0.0, 0.0 );

    /* base colour */
    baseColor = modulateColor.rgb;
    
    /* global alpha */
    alpha = modulateColor.a;

    /* ppd: */
    ppd = auxParameters0[0];

    /* size sf convert to pixels: */
    size = ( ppd / auxParameters0[1] ) / 2.0;

    /* contrast: */
    contrast = auxParameters0[2];

    /* phase converted to pixels: */
    phase = ( ( auxParameters0[3] * deg2rad) / twopi ) * size * 2.0;

    colour1 = auxParameters1;
    colour2 = auxParameters2;

}

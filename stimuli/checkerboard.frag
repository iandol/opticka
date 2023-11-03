/*
 * File: checkerboard.frag
 * Shader for drawing of checkerboards.
 *
 * Copyright 2014, Ian Andolina <http://github.com/iandol>, licenced under the MIT Licence
 *
 */

uniform vec2    center;
uniform float   radius;

varying vec3    baseColor;
varying float   alpha;
varying float   phase;
varying float   ppd;
varying float   size;
varying float   contrast;
varying vec4    colour1;
varying vec4    colour2;

void main() {
    //current position
    vec2 pos = gl_TexCoord[0].xy;

    /* find our distance from center, if distance to center (aka radius of pixel) > Radius, discard this pixel: */
    if ( radius > 0.0 ) {
        if ( distance( pos, center ) > radius ) discard;
    }

    pos.x = pos.x + phase;

    /* scale to size */
    pos = floor( pos / size );

    float mask = mod( pos.x + pos.y, 2.0 );

    vec3 colorA = colour1.rgb;
    vec3 colorB = colour2.rgb;
    //blend our colours from the base colour if contrast < 1
    if ( contrast < 1.0 ) { 
        colorA = mix( baseColor, colorA, contrast );
        colorB = mix( baseColor, colorB, contrast );
    }

    // and then mix the two colors using mask
    vec3 colorOut = mix(colorA, colorB, mask);
    
    // off to the display, byebye little pixel!
    gl_FragColor = vec4(colorOut, alpha );
}

/*
 * File: checkerboard.frag
 * Shader for drawing of checkerboards.
 *
 * Copyright 2014, Ian Andolina <http://github.com/iandol>, licenced under the MIT Licence
 *
 */

uniform vec2    center;
uniform vec4    color1;
uniform vec4    color2;
uniform float   radius;

varying float   ppd;
varying float   size;
varying float   contrast;
varying float   phase;
varying vec3    baseColor;
varying vec4    colour1;
varying vec4    colour2;
varying float   alpha;

void main() {
    //current position
    vec2 pos = gl_TexCoord[0].xy;

    /* find our distance from center, if distance to center (aka radius of pixel) > Radius, discard this pixel: */
    if ( distance( pos, center ) > radius ) discard;

    pos.x = pos.x + phase;

    /* scale to size */
    pos = floor( pos / size );

    float mask = mod( pos.x + pos.y, 2.0 );

    vec3 colorA = colour1.rgb;
    vec3 colorB = colour2.rgb;
    //blend our colours from the base colour if contrast < 1
    if ( contrast < 1.0 ) { 
        vec3 colorA = mix( baseColor, colour1.rgb, contrast );
        vec3 colorB = mix( baseColor, colour2.rgb, contrast );
    }

    // and then mix the two colors using mask
    vec3 colorOut = mix(colorA, colorB, mask);
    
    // off to the display, byebye little pixel!
    gl_FragColor = vec4( colorOut, alpha );
}
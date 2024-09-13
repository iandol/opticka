/* MipMapDownsamplingShader.frag.txt
 *
 * Example shader for downsampling during building a OpenGL Mipmap image
 * resolution pyramid. This shader can be passed to CreateResolutionPyramid().
 *
 * This shader computes each "downfiltered" output sample from a 3-by-3 grid
 * of neighbouring input samples, weighted by a gaussian filter kernel of
 * standard deviation 1.0.
 *
 * This is a proof-of-concept shader. It demonstrates the principle, but is
 * not necessarilly perfect.
 *
 * (c) 2012 by Mario Kleiner. Licensed under MIT license.
 */

uniform sampler2D Image;
uniform vec2 srcSize;
uniform vec2 dstSize;

const mat3 kernel = mat3( 0.075113607954111,   0.123841403152974,   0.075113607954111, 0.123841403152974,   0.204179955571658,   0.123841403152974, 0.075113607954111,   0.123841403152974,   0.075113607954111);

void main()
{
    vec2 inpos = gl_TexCoord[0].st;
    float dx = 1.0 / srcSize.x;
    float dy = 1.0 / srcSize.y;

    /* Take 9 weighted samples in a 3x3 grid, to emulate sampling with a gaussian kernel: */
    vec4 incolor = vec4(0.0);
    incolor += texture2D(Image, inpos + vec2(-dx, -dy)) * kernel[0][0];
    incolor += texture2D(Image, inpos + vec2(0.0, -dy)) * kernel[1][0];
    incolor += texture2D(Image, inpos + vec2(+dx, -dy)) * kernel[2][0];

    incolor += texture2D(Image, inpos + vec2(-dx, 0.0)) * kernel[0][1];
    incolor += texture2D(Image, inpos + vec2(0.0, 0.0)) * kernel[1][1];
    incolor += texture2D(Image, inpos + vec2(+dx, 0.0)) * kernel[2][1];

    incolor += texture2D(Image, inpos + vec2(-dx, +dy)) * kernel[0][2];
    incolor += texture2D(Image, inpos + vec2(0.0, +dy)) * kernel[1][2];
    incolor += texture2D(Image, inpos + vec2(+dx, +dy)) * kernel[2][2];

    /* Simply pass sample unmodified: */
    gl_FragColor = incolor;

}

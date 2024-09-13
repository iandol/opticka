/* BlurredMipmapDemoShader.frag.txt
 * Shader used for BlurredMipmapDemo.m
 *
 * This shader computes the level of resolution for each output texel
 * during Screen('DrawTexture') of the video image texture. Resolution
 * directly depends on radial distance to the provided simulated center of gaze.
 *
 * Resolution level is used to determine the mip-map miplevel (lod) to use for
 * lookup of the mip-map filtered texel in the images mipmap pyramid.
 *
 * (C) 2012 Mario Kleiner - Licensed under MIT license.
 *
 */

#extension GL_ARB_shader_texture_lod : enable

/* Image is the mip-mapped texture with the image resolution pyramid: */
uniform sampler2D Image;

/* Passed from vertex shader: */
varying vec4  baseColor;
varying vec2  gazePosition;
varying float gazeRadius;

void main(void)
{
    /* Output pixel position in absolute window coordinates: */
    vec2 outpos = gl_FragCoord.xy;

    /* Compute distance to center of gaze, normalized to units of gazeRadius: */
    /* We take log2 of it, because lod selects mip-level, which selects for a */
    /* 2^lod decrease in resolution: */
    float lod = log2( gazeRadius - (distance(outpos, gazePosition) / 5.0) );

    /* Lookup texel color in image pyramid at input texture coordinate and
     * specific mip-map level 'lod': */
    vec4 texel = texture2DLod(Image, gl_TexCoord[0].st, lod);

    /* Apply modulation baseColor and write to framebuffer: */
    gl_FragColor = texel * baseColor;
}

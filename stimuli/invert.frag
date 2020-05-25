/* Invert fragment shader.
//
// 
*/

#extension GL_ARB_texture_rectangle : enable

uniform sampler2DRect Image;

void main()
{
    /* Fetch texel color at current location: */
    vec4 texcolor = texture2DRect(Image, gl_TexCoord[0].st);
    /* Invert rgb: */
    gl_FragColor.a = texcolor.a;
    gl_FragColor.rgb = 1.0 - texcolor.rgb;
}

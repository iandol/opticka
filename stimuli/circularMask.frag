/*
 * circularMask.frag
 * GLSL fragment shader for Psychtoolbox DrawTexture/MakeTexture.
 * Produces a circular alpha mask: alpha=1 at the center, alpha=0 at the edge, smooth transition.
 * Intended for masking an input image/texture with a soft-edged disc.
 *
 * Uniforms:
 *   uniform float Radius;   // Radius of the circular mask (in texel coordinates, e.g. 200 for half-width)
 *   uniform float Sigma;    // Smoothing width in texels (controls softness of edge)
 *   uniform vec2 Center;    // Center of the disc (in texel coordinates, e.g. [200, 200])
 */

#extension GL_ARB_texture_rectangle : enable

uniform sampler2DRect Image;
uniform vec2 Center;
uniform float Radius;
uniform float Sigma;

void main()
{
	// Get current texture coordinate
	vec2 pos = gl_TexCoord[0].xy;

	// Fetch texel color at current location:
	vec4 color = texture2DRect(Image, pos);

	// if texture alpha is close to 0, discard
	if (distance(color.a, 0.0) < 0.1) discard;

	// Compute distance from center
	float dist = distance(pos, Center);

	// Compute smooth alpha: 1 in center, 0 at edge, smooth transition over Sigma
	float edge0 = Radius - Sigma;
	float edge1 = Radius;
	float alpha = 1.0 - smoothstep(edge0, edge1, dist);

	// Output color with masked alpha
	gl_FragColor = vec4(color.rgb, alpha);
}
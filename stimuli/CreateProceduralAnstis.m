function [id, rect] = CreateProceduralAnstis(windowPtr, width, height)

% Global GL struct: Will be initialized in the LoadGLSLProgramFromFiles
% below:
global GL;

% Make sure we have support for shaders, abort otherwise:
AssertGLSL;

if nargin < 3 || isempty(windowPtr) || isempty(width) || isempty(height)
	error('You must provide "windowPtr", "width" and "height"!');
end

p = mfilename('fullpath');
p = [fileparts(p) filesep];

% Load grating shader with circular aperture and smoothing support:
aShader = LoadGLSLProgramFromFiles({[p 'anstis.vert'], [p 'anstis.frag']}, 1);

% Setup shader:
glUseProgram(discShader);

% Set the 'Center' parameter to the center position of the gabor image
% patch [tw/2, th/2]:
glUniform2f(glGetUniformLocation(aShader, 'Center'), width/2, height/2);

glUseProgram(0);

% Create a purely virtual procedural texture 'id' of size width x height virtual pixels.
% Attach the discShader to it to define its appearance:
id = Screen('SetOpenGLTexture', windowPtr, [], 0, GL.TEXTURE_RECTANGLE_EXT, width, height, 1, aShader);

% Query and return its bounding rectangle:
rect = Screen('Rect', id);

% Ready!
return;

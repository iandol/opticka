function [id, rect] = CreateProceduralColorGrating(windowPtr, width, height, ...
    color1, color2, radius)
% [id, rect] = CreateProceduralColorGrating(windowPtr, width, height [, color1=[1 0 0]]  [, color2=[0 1 0]] [, radius=0])
%
% color1 & color2 are the two colors which the grating will vary between.
% radius is an optional circular mask sized in pixels

% Global GL struct: Will be initialized in the LoadGLSLProgramFromFiles
% below:
global GL;

% Make sure we have support for shaders, abort otherwise:
AssertGLSL;

if nargin < 3 || isempty(windowPtr) || isempty(width) || isempty(height)
	error('You must provide "windowPtr", "width" and "height"!');
end

if nargin < 4 || isempty(color1)
    color1 = [1 0 0 1];
else
    if length(color1) < 4
        warning('color1 must be a 4 component RGBA vector [red green blue alpha], resetting color1 to red!');
		  color1 = [1 0 0 1];
    end
end

if nargin < 5 || isempty(color2)
    color2 = [0 1 0 1];
else
    if length(color2) < 4
        warning('color2 must be a 4 component RGBA vector [red green blue alpha], resetting color2 to green!');
		  color2 = [0 1 0 1];
    end
end

if nargin < 6 || isempty(radius)
    radius = 0;
end

% Switch to windowPtr OpenGL context:
Screen('GetWindowInfo', windowPtr);

% Load shader:
p = mfilename('fullpath');
p = [fileparts(p) filesep];
cShader = LoadGLSLProgramFromFiles({[p 'colorgrating.vert'], [p 'colorgrating.frag']}, 1);

% Setup shader:
glUseProgram(cShader);

glUniform2f(glGetUniformLocation(cShader, 'center'), width/2, height/2);
glUniform4f(glGetUniformLocation(cShader, 'color1'), color1(1),color1(2),color1(3),color1(4));
glUniform4f(glGetUniformLocation(cShader, 'color2'), color2(1),color2(2),color2(3),color2(4));
if radius>0; glUniform1f(glGetUniformLocation(cShader, 'radius'), radius); end

glUseProgram(0);

% Create a purely virtual procedural texture 'id' of size width x height virtual pixels.
% Attach the discShader to it to define its appearance:
id = Screen('SetOpenGLTexture', windowPtr, [], 0, GL.TEXTURE_RECTANGLE_EXT, width, height, 1, cShader);

% Query and return its bounding rectangle:
rect = Screen('Rect', id);

% Ready!
return;

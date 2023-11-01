function [id, rect, shader] = CreateProceduralCheckerboard(windowPtr, width, height, radius)
% [id, rect, shader] = CreateProceduralCheckerboard(windowPtr, width, height, [, radius=inf])
%
% A procedural checkerboard shader
%
% See also: CreateProceduralSineGrating, CreateProceduralSineSquareGrating

% History: 
% 06/06/2014 ima created by Ian Max Andolina <http://github.com/iandol>, licenced under the MIT Licence

global GL;

AssertGLSL;

if nargin < 1 || isempty(windowPtr) 
    error('You must provide a PTB window pointer!');
end

if nargin < 2 || isempty(width) 
    width = 500;
end

if nargin < 3 || isempty(height) 
    height = width;
end

if nargin < 4 || isempty(radius)
    radius = inf;
end

% Switch to windowPtr OpenGL context:
Screen('GetWindowInfo', windowPtr);

% Load shader:
p = [optickaRoot filesep];
shader = LoadGLSLProgramFromFiles({[p 'checkerboard.frag'] [p 'checkerboard.vert']}, 1);

% Setup shader:
glUseProgram(shader);
glUniform2f(glGetUniformLocation(shader, 'center'), width/2, height/2);
glUniform1f(glGetUniformLocation(shader, 'radius'), radius); 

glUseProgram(0);

% Create a purely virtual procedural texture 'id' of size width x height virtual pixels.
% Attach the shader to it to define its appearance:
id = Screen('SetOpenGLTexture', windowPtr, [], 0, GL.TEXTURE_RECTANGLE_EXT, width, height, 1, shader);

% Query and return its bounding rectangle:
rect = Screen('Rect', id);


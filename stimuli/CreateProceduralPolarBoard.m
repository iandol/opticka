function [id, rect, shader] = CreateProceduralPolarBoard(windowPtr, width, height, ...
	color1, color2, radius, type)
% [id, rect, shader] = CreateProceduralPolarBoard(windowPtr, width,
% height [, color1=[1 0 0]]  [, color2=[0 1 0]] [, radius=0])
%
% A procedural checkerboard shader that can generate either sinusoidal or
% square gratings varying between two colors. 

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

if nargin < 4 || isempty(color1)
	color1 = [1 0 0 1];
elseif length(color1) == 3
	color1 = [color1 1]; %add alpha
elseif length(color1) ~= 4
	warning('color1 must be a 4 component RGBA vector [red green blue alpha], resetting color1 to red!');
	color1 = [1 0 0 1];
end

if nargin < 5 || isempty(color2)
	color2 = [0 1 0 1];
elseif length(color2) == 3
	color2 = [color2 1]; %add alpha
elseif length(color2) ~= 4
	warning('color2 must be a 4 component RGBA vector [red green blue alpha], resetting color2 to green!');
	color2 = [0 1 0 1];
end

if nargin < 6 || isempty(radius)
	radius = 0;
end

if nargin < 7 || isempty(type)
	type = '';
end

% Switch to windowPtr OpenGL context:
Screen('GetWindowInfo', windowPtr);

% Load shader:
currentFolder = fileparts(which(mfilename));
if isempty(type)
	shaderPath = fullfile(currentFolder, 'polarBoardShader1');
else
	shaderPath = fullfile(currentFolder, 'polarBoardShader2');
end
shader = LoadGLSLProgramFromFiles(shaderPath, 1);

% Setup shader:
glUseProgram(shader);
glUniform2f(glGetUniformLocation(shader, 'center'), width/2, height/2);
glUniform4f(glGetUniformLocation(shader, 'color1'), color1(1),color1(2),color1(3),color1(4));
glUniform4f(glGetUniformLocation(shader, 'color2'), color2(1),color2(2),color2(3),color2(4));
if radius>0
	glUniform1f(glGetUniformLocation(shader, 'radius'), radius);
end
glUseProgram(0);

% Create a purely virtual procedural texture 'id' of size width x height virtual pixels.
% Attach the shader to it to define its appearance:
id = Screen('SetOpenGLTexture', windowPtr, [], 0, GL.TEXTURE_RECTANGLE_EXT, width, height, 1, shader);

% Query and return its bounding rectangle:
rect = Screen('Rect', id);


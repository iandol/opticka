function [id, rect] = CreateProceduralPseudoYellowGrating(windowPtr, width, height, color1, color2, color3, color4, radius)

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

if nargin < 6 || isempty(color3)
    color3 = [0.6 0 0 1];
else
    if length(color3) < 4
        warning('color3 must be a 4 component RGBA vector [red green blue alpha], resetting color3 to darker red!');
		  color3 = [0.6 0 0 1];
    end
end

if nargin < 7 || isempty(color4)
    color4 = [0 0.6 0 1];
else
    if length(color4) < 4
        warning('color4 must be a 4 component RGBA vector [red green blue alpha], resetting color4 to darker green!');
		  color4 = [0 0.6 0 1];
    end
end

if nargin < 8 || isempty(radius)
    radius = inf;
end

% Switch to windowPtr OpenGL context:
Screen('GetWindowInfo', windowPtr);

% Load shader:
p = mfilename('fullpath');
p = [fileparts(p) filesep];
aShader = LoadGLSLProgramFromFiles({[p 'anstis.vert'], [p 'anstis.frag']}, 1);

% Setup shader:
glUseProgram(aShader);

glUniform2f(glGetUniformLocation(aShader, 'center'), width/2, height/2);
glUniform4f(glGetUniformLocation(aShader, 'color1'), color1(1),color1(2),color1(3),color1(4));
glUniform4f(glGetUniformLocation(aShader, 'color2'), color2(1),color2(2),color2(3),color2(4));
glUniform4f(glGetUniformLocation(aShader, 'color3'), color3(1),color3(2),color3(3),color3(4));
glUniform4f(glGetUniformLocation(aShader, 'color4'), color4(1),color4(2),color4(3),color4(4));
if radius>0; glUniform1f(glGetUniformLocation(aShader, 'radius'), radius); end

glUseProgram(0);

% Create a purely virtual procedural texture 'id' of size width x height virtual pixels.
% Attach the discShader to it to define its appearance:
id = Screen('SetOpenGLTexture', windowPtr, [], 0, GL.TEXTURE_RECTANGLE_EXT, width, height, 1, aShader);

% Query and return its bounding rectangle:
rect = Screen('Rect', id);

% Ready!
return;

function ProceduralPolarGratingDemo(color1,color2,baseColor)
% ProceduralPolarGratingDemo() -- demo polar grating procedural shader
% stimuli, the shader is based on the colour grating shader, see
% ProceduralColorGratingDemo for details.
%
% History:
% 20/05/2021 initial version (Junxiang Luo)

if ~exist('color1','var') || isempty(color1)
	color1 = [1 1 1];
end

if ~exist('color2','var') || isempty(color2)
	color2 = [0 0 0];
end

if ~exist('baseColor','var') || isempty(baseColor)
	baseColor = [0.5 0.5 0.5 1];
end

% Setup defaults and unit color range:
PsychDefaultSetup(2);

% Disable synctests for this quick demo:
oldSyncLevel = Screen('Preference', 'SkipSyncTests', 2);

% Select screen with maximum id for output window:
screenid = max(Screen('Screens'));

% Open a fullscreen, onscreen window with gray background. Enable 32bpc
% floating point framebuffer via imaging pipeline on it, if this is possible
% on your hardware while alpha-blending is enabled. Otherwise use a 16bpc
% precision framebuffer together with alpha-blending. 
PsychImaging('PrepareConfiguration');
PsychImaging('AddTask', 'General', 'FloatingPoint32BitIfPossible');
[win, winRect] = PsychImaging('OpenWindow', screenid, baseColor);
[width, height] = RectSize(winRect);
% Query frame duration: We use it later on to time 'Flips' properly for an
% animation with constant framerate:
ifi = Screen('GetFlipInterval', win);

% Enable alpha-blending
Screen('BlendFunction', win, 'GL_SRC_ALPHA', 'GL_ONE_MINUS_SRC_ALPHA');

% default x + y size
virtualSize = 512;
% radius of the disc edge
radius = floor(virtualSize / 2);

% Build a procedural texture, 
texture = CreateProceduralPolarGrating(win, virtualSize, virtualSize,...
	 color1, color2, radius);

% These settings are the parameters passed in directly to DrawTexture
% angle
angle = 0;
% phase
phase = 0;
% spatial frequency
frequency = 0.06; % cycles/pixel
% calculate frequency of both radial and circular gratings
middleRadius = virtualSize/2;
middlePerimeter = 2*pi*middleRadius; % pixels
radiusFrequency = frequency*middlePerimeter / (2*pi); % cycles/degree, must be integral to avoid clip effect, corrected in the frag file
circularFrequency = 0;
% contrast
contrast = 0.75;
% sigma < 0 is a sinusoid.
sigma = -1;

% the center mask
% width, height, backgroundColorOffset, radius, sigma, useAlpha, method
[masktex, maskrect] = CreateProceduralSmoothedDisc(win,...
	150, 150, [], 60, 25, true, 1);
maskDstRects = CenterRectOnPointd(maskrect, width/2, height/2);

% Preperatory flip
showTime = 5;
phaseJump = 15;
WaitSecs(5);
vbl = Screen('Flip', win);
tstart = vbl + ifi; %start is on the next frame

while vbl < tstart + showTime
	% Draw a message
	Screen('DrawText', win, 'Radial Sine Grating', 10, 10, [1 1 1]);
	% Draw the shader with parameters
	Screen('DrawTexture', win, texture, [], [],...
		angle, [], [], baseColor, [], [],...
		[phase, radiusFrequency, contrast, sigma, circularFrequency, 0, 0, 0]);
	Screen('DrawTexture', win, masktex, [], maskDstRects, [], [], 1, baseColor, [], []);
	phase = phase + phaseJump;
	vbl = Screen('Flip', win, vbl + 0.5 * ifi);
end

tstart = vbl + ifi; %start is on the next frame
sigma = 0.5;

while vbl < tstart + showTime
	% Draw a message
	Screen('DrawText', win, 'Radial Square Grating', 10, 10, [1 1 1]);
	% Draw the shader with parameters
	Screen('DrawTexture', win, texture, [], [],...
		angle, [], [], baseColor, [], [],...
		[phase, radiusFrequency, contrast, sigma, circularFrequency, 0, 0, 0]);
	Screen('DrawTexture', win, masktex, [], maskDstRects, [], [], 1, baseColor, [], []);
	phase = phase + phaseJump;
	vbl = Screen('Flip', win, vbl + 0.5 * ifi);
end

tstart = vbl + ifi; %start is on the next frame
sigma = -1;
tmp = radiusFrequency;
radiusFrequency = 0;
circularFrequency = frequency;

while vbl < tstart + showTime
	% Draw a message
	Screen('DrawText', win, 'Circular Sine Grating', 10, 10, [1 1 1]);
	% Draw the shader texture with parameters
	Screen('DrawTexture', win, texture, [], [],...
		angle, [], [], baseColor, [], [],...
		[phase, radiusFrequency, contrast, sigma, circularFrequency, 0, 0, 0]);
	Screen('DrawTexture', win, masktex, [], maskDstRects, [], [], 1, baseColor, [], []);
	phase = phase + phaseJump;
	vbl = Screen('Flip', win, vbl + 0.5 * ifi);
end

tstart = vbl + ifi; %start is on the next frame
sigma = 0.5;

while vbl < tstart + showTime
	% Draw a message
	Screen('DrawText', win, 'Circular Square Grating', 10, 10, [1 1 1]);
	% Draw the shader texture with parameters
	Screen('DrawTexture', win, texture, [], [],...
		angle, [], [], baseColor, [], [],...
		[phase, radiusFrequency, contrast, sigma, circularFrequency, 0, 0, 0]);
	Screen('DrawTexture', win, masktex, [], maskDstRects, [], [], 1, baseColor, [], []);
	phase = phase + phaseJump;
	vbl = Screen('Flip', win, vbl + 0.5 * ifi);
end

tstart = vbl + ifi; %start is on the next frame
sigma = -1;
radiusFrequency = tmp;
circularFrequency = frequency;

while vbl < tstart + showTime
	% Draw a message
	Screen('DrawText', win, 'Spiral Sine Grating', 10, 10, [1 1 1]);
	% Draw the shader texture with parameters
	Screen('DrawTexture', win, texture, [], [],...
		angle, [], [], baseColor, [], [],...
		[phase, radiusFrequency, contrast, sigma, circularFrequency, 0, 0, 0]);
	Screen('DrawTexture', win, masktex, [], maskDstRects, [], [], 1, baseColor, [], []);
	phase = phase + phaseJump;
	vbl = Screen('Flip', win, vbl + 0.5 * ifi);
end

tstart = vbl + ifi; %start is on the next frame
sigma = 0.5;

while vbl < tstart + showTime
	% Draw a message
	Screen('DrawText', win, 'Spiral Square Grating', 10, 10, [1 1 1]);
	% Draw the shader texture with parameters
	Screen('DrawTexture', win, texture, [], [],...
		angle, [], [], baseColor, [], [],...
		[phase, radiusFrequency, contrast, sigma, circularFrequency, 0, 0, 0]);
	Screen('DrawTexture', win, masktex, [], maskDstRects, [], [], 1, baseColor, [], []);
	phase = phase + phaseJump;
	vbl = Screen('Flip', win, vbl + 0.5 * ifi);
end

WaitSecs(0.5);
% Close onscreen window, release all resources:
sca;

% Restore old settings for sync-tests:
Screen('Preference', 'SkipSyncTests', oldSyncLevel);


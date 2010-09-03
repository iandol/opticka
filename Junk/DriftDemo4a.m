function DriftDemo4(angle, cyclespersecond, freq, gratingsize, internalRotation)
% function DriftDemo4([angle=0][, cyclespersecond=1][, freq=1/360][, gratingsize=360][, internalRotation=0])
% ___________________________________________________________________
%
% Display an animated grating, using the new Screen('DrawTexture') command.
% This demo demonstrates fast drawing of such a grating via use of procedural
% texture mapping. It only works on hardware with support for the GLSL
% shading language, vertex- and fragmentshaders. The demo ends if you press
% any key on the keyboard.
%
% The grating is not encoded into a texture, but instead a little algorithm - a
% procedural texture shader - is executed on the graphics processor (GPU)
% to compute the grating on-the-fly during drawing.
%
% This is very fast and efficient! All parameters of the grating can be
% changed dynamically. For a similar approach wrt. Gabors, check out
% ProceduralGaborDemo. For an extremely fast aproach for drawing many Gabor
% patches at once, check out ProceduralGarboriumDemo. That demo could be
% easily customized to draw many sine gratings by mixing code from that
% demo with setup code from this demo.
%
% Optional Parameters:
% 'angle' = Rotation angle of grating in degrees.
% 'internalRotation' = Shall the rectangular image patch be rotated
% (default), or the grating within the rectangular patch?
% gratingsize = Size of 2D grating patch in pixels.
% freq = Frequency of sine grating in cycles per pixel.
% cyclespersecond = Drift speed in cycles per second.
%

% History:
% 3/1/9  mk   Written.

% Make sure this is running on OpenGL Psychtoolbox:
AssertOpenGL;

% Initial stimulus parameters for the grating patch:

if nargin < 5 || isempty(internalRotation)
    internalRotation = 0;
end

if internalRotation
    rotateMode = kPsychUseTextureMatrixForRotation;
else
    rotateMode = [];
end

if nargin < 4 || isempty(gratingsize)
    gratingsize = 360;
end

% res is the total size of the patch in x- and y- direction, i.e., the
% width and height of the mathematical support:
res = [gratingsize gratingsize];

if nargin < 3 || isempty(freq)
    % Frequency of the grating in cycles per pixel: Here 0.01 cycles per pixel:
    freq = 2/360;
end

if nargin < 2 || isempty(cyclespersecond)
    cyclespersecond = 1;
end

if nargin < 1 || isempty(angle)
    % Tilt angle of the grating:
    angle = 0;
end

% Amplitude of the grating in units of absolute display intensity range: A
% setting of 0.5 means that the grating will extend over a range from -0.5
% up to 0.5, i.e., it will cover a total range of 1.0 == 100% of the total
% displayable range. As we select a background color and offset for the
% grating of 0.5 (== 50% nominal intensity == a nice neutral gray), this
% will extend the sinewaves values from 0 = total black in the minima of
% the sine wave up to 1 = maximum white in the maxima. Amplitudes of more
% than 0.5 don't make sense, as parts of the grating would lie outside the
% displayable range for your computers displays:
amplitude = 0.5;

% Choose screen with maximum id - the secondary display on a dual-display
% setup for display:
screenid = max(Screen('Screens'));

PsychImaging('PrepareConfiguration');
PsychImaging('AddTask', 'General', 'FloatingPoint32BitIfPossible');

oldSyncLevel = Screen('Preference', 'SkipSyncTests', 0);
oldLevel = Screen('Preference', 'VisualDebugLevel', 1 );

% Open a fullscreen onscreen window on that display, choose a background
% color of 128 = gray, i.e. 50% max intensity:
%[win, winRect] = Screen('OpenWindow', screenid, 128);
[win winRect] = PsychImaging('OpenWindow', screenid, 128);

%Screen('BlendFunction', win, GL_ONE, GL_ONE);
Screen('BlendFunction', win, GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
%Screen('BlendFunction', win, GL_ONE, GL_ONE_MINUS_SRC_ALPHA);

% Query frame duration: We use it later on to time 'Flips' properly for an
% animation with constant framerate:
ifi = Screen('GetFlipInterval', win);

% Retrieve size of window in pixels, need it later to make sure that our
% moving gabors don't move out of the visible screen area:
[w, h] = RectSize(winRect);

% Make sure the GLSL shading language is supported:
AssertGLSL;

% Retrieve video redraw interval for later control of our animation timing:
ifi = Screen('GetFlipInterval', win);

% Phase is the phase shift in degrees (0-360 etc.)applied to the sine grating:
phase = 0;

% Compute increment of phase shift per redraw:
phaseincrement = (cyclespersecond * 360) * ifi;

nonsymmetric=1;

% Build a procedural sine grating texture for a grating with a support of
% res(1) x res(2) pixels and a RGB color offset of 0.5 -- a 50% gray.
[gratingtex,grt1] = CreateProceduralSineGrating(win, res(1), res(2),[0.5 0.5 0.5 0]);
[gratingtex2,grt2] = CreateProceduralSineGrating(win, res(1), res(2),[0.5 0.5 0.5 0]);
[gabortex,grt3] = CreateProceduralGabor(win, res(1),res(2), nonsymmetric,[0.5 0.5 0.5 0]);
% Wait for release of all keys on keyboard, then sync us to retrace:
KbReleaseWait;
vbl = Screen('Flip', win);

dstRect=OffsetRect(grt1/2,0,0);
dstRect3=OffsetRect(grt3,0,0);

inc=0;
jump=50;
try
	% Animation loop: Repeats until keypress...
	while ~KbCheck
		% Update some grating animation parameters:

		% Increment phase by 1 degree:
		phase = phase + phaseincrement;

		inc=inc+0.5;
		
		if inc > jump
			jump=jump+50;
			xj=round(w*rand)
			yj=round(h*rand)
			if xj+gratingsize > w
				xj = 0;
			end
			if yj+gratingsize > h
				yj = 0;
			end
			dstRect3=OffsetRect(grt3,xj,yj)
		end
		
		if inc == jump-25
			xj=round(w*rand);
			yj=round(h*rand);
			if xj+gratingsize > w
				xj = 0
			end
			if yj+gratingsize > h
				yj = 0
			end
			dstRect=OffsetRect(grt1/2,xj,yj)
		end

		% Draw the grating, centered on the screen, with given rotation 'angle',
		% sine grating 'phase' shift and amplitude, rotating via set
		% 'rotateMode'. Note that we pad the last argument with a 4th
		% component, which is 0. This is required, as this argument must be a
		% vector with a number of components that is an integral multiple of 4,
		% i.e. in our case it must have 4 components:
		Screen('DrawTexture', win, gratingtex, [], dstRect, angle, [], [], [], [], rotateMode, [phase, freq, amplitude, 0]);
		Screen('DrawTexture', win, gratingtex2, [], [300,100,700,360], angle+inc, [], [], [], [], rotateMode, [phase, freq*4, amplitude/2, 0]);
		Screen('DrawTexture', win, gabortex, [], [], angle, [], [], [], [], kPsychDontDoRotation, [phase+180, freq*2, 50, 50, 1, 0, 0, 0]);
		Screen('DrawTexture', win, gabortex, [], dstRect3, angle+45, [], [], [], [], kPsychDontDoRotation, [phase, freq*2, 50/2, 50/2, 1, 0, 0, 0]);
		Screen('DrawingFinished', win);
		% Show it at next retrace:
		vbl = Screen('Flip', win, vbl + 0.5 * ifi);
	end

	% We're done. Close the window. This will also release all other ressources:
	Screen('CloseAll');

	% Restore old settings for sync-tests:
	Screen('Preference', 'SkipSyncTests', oldSyncLevel);
	Screen('Preference', 'VisualDebugLevel', oldLevel);
	
	clear all

	% Bye bye!
	return;
catch ME
	% We're done. Close the window. This will also release all other ressources:
	Screen('CloseAll');
	
	% Restore old settings for sync-tests:
	Screen('Preference', 'SkipSyncTests', oldSyncLevel);
	Screen('Preference', 'VisualDebugLevel', oldLevel);
	throw(ME);
	error('Problem occured!')
	clear all
end

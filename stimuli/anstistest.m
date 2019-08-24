function anstistest()

bgColour = 0.5;
screen = max(Screen('Screens'));
screenSize = [];

ptb = mySetup(screen,bgColour,screenSize);

resolution = [500 500];
phase = 0;
angle = 0;
sf = 1 / ptb.ppd; %1c/d
contrast = 1; 
sigma = -1; % >=0 become a square wave smoothed with sigma. <0 = sinewave grating.
radius = 0; %if radius > 0 then we create a circular aperture radius pixels wide

colorA = [1 0 0 1];
colorB = [0 1 0 1];

% this is a two color grating, passing in colorA and colorB.
[cgrat, ~] = CreateProceduralColorGrating(ptb.win, resolution(1), resolution(2),...
	colorA, colorB, radius);

colorC = [0.6 0 0 1];
colorD = [0 0.6 0 1];

% procedural pseudo yellow square wave, see Anstis & Cavanaugh 1983
[anstis, arect] = CreateProceduralPseudoYellowGrating(ptb.win, resolution(1), resolution(2),...
	colorA,colorB,colorC,colorD,radius);

Priority(MaxPriority(ptb.win)); %bump our priority to maximum allowed

vbl(1)=Screen('Flip', ptb.win);

mvaRect = CenterRect(arect,ptb.winRect);
mvcRect = OffsetRect(mvaRect,-resolution(1),0);
mvccRect = OffsetRect(mvaRect,resolution(1),0);

while vbl(end) < vbl(1) + 4
	%if contrast < 1, then modulateColor is used as the middle point, so for
	%example if color1=red & color2=green & modulateColor=[0.5 0.5 0.5] then
	%as we decrease contrast, we blend red and green each with mid-grey.
	%The 4th value auxParameters is sigma. If sigma >= 0 then the grating 
	%becomes a square wave smoothed with sigma between color1 and color2.
	Screen('DrawTexture', ptb.win, cgrat, [], mvcRect,...
		angle, [], [], [0.5 0.5 0.5 1], [], [],...
		[phase, sf, contrast, sigma]);
	Screen('DrawTexture', ptb.win, cgrat, [], mvccRect,...
		angle, [], [], [0.5 0.5 0.5 1], [], [],...
		[phase, sf, 0.25, 0.1]); % this is a 0.25contrast smoothed square wave grating
				
	%only auxParameters phase and sf are used
	Screen('DrawTexture', ptb.win, anstis, [], mvaRect,...
		angle, [], [], [], [], [],...
		[phase, sf, 0, 0]);
	Screen('DrawingFinished',ptb.win);
	phase = phase + 20; 
	vbl(end+1) = Screen('Flip', ptb.win, vbl(end) + ptb.ifi/2);
end

Screen('Flip', ptb.win);

figure;plot(diff(vbl)*1e3);title(sprintf('VBL Times, should be ~%.2f ms',ptb.ifi*1e3));ylabel('Time (ms)')

end

%----------------------
function ptb = mySetup(screen, bgColour, ws)

ptb.cleanup = onCleanup(@myCleanup);
PsychDefaultSetup(2);
Screen('Preference', 'SkipSyncTests', 0);
if isempty(screen); screen = max(Screen('Screens')); end
ptb.ScreenID = screen;
PsychImaging('PrepareConfiguration');
PsychImaging('AddTask', 'General', 'FloatingPoint32BitIfPossible');
PsychImaging('AddTask', 'General', 'UseFastOffscreenWindows');
[ptb.win, ptb.winRect] = PsychImaging('OpenWindow', ptb.ScreenID, bgColour, ws, [], [], [], 1);

[ptb.w, ptb.h] = RectSize(ptb.winRect);
screenWidth = 405; % mm
viewDistance = 573; % mm
ptb.ppd = ptb.w/2/atand(screenWidth/2/viewDistance);
ptb.ifi = Screen('GetFlipInterval', ptb.win);
ptb.fps = 1 / ptb.ifi;
Screen('BlendFunction', ptb.win, GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);

end

%----------------------
function myCleanup()

disp('Clearing up...')
sca

end
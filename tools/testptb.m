function [  ] = testptb(  )

Screen('preference','skipsynctests',2)
backgroundColour = [0.3 0.3 0.3];
name = 'test';

%-----dots stimulus
n = dotsStimulus();
n.name = name;
n.size = 5;
n.speed = 4;
n.dotType = 2; %high quality dots
n.dotSize = 0.2;
n.density = 25;
n.colour = [0.45 0.45 0.45];
n.colourType = 'simple'; %try also randomBW
n.coherence = 0.5;
n.kill = 0.1;
n.mask = true;

%-----combine them into a single meta stimulus
stimuli = metaStimulus();
stimuli.name = name;
stimuli{1} = n;

%-----open the PTB screens
s = screenManager('verbose',false,'blend',true,'screen',1,...
	'bitDepth','FloatingPoint32Bit','debug',true, ...
	'srcMode','GL_SRC_ALPHA','dstMode','GL_ONE_MINUS_SRC_ALPHA',...
	'windowed',[],'backgroundColour',[backgroundColour 0]); %use a temporary screenManager object

try
	for i = 1:1000
		fprintf('RUN: %g screen open\n',i)
		screenVals = open(s); %open PTB screen
		setup(stimuli,s); %setup our stimulus object
		vbls = Screen('Flip',s.win); %flip the buffer
		vbl=vbls;
		while GetSecs <= vbls+1
			draw(stimuli); %draw stimulus
			Screen('DrawingFinished', s.win); %tell PTB/GPU to draw
			animate(stimuli); %animate stimulus, will be seen on next draw
			nextvbl = vbl + screenVals.halfisi;
			vbl = Screen('Flip',s.win, nextvbl); %flip the buffer
		end
		vbl = Screen('Flip',s.win);
		close(s)
		fprintf('RUN: %g screen closed\n',i)
		if KbCheck
			return
		end
	end
	
catch
	close(s)
end
close(s)


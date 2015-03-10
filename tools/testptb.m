function testptb()

Screen('preference','skipsynctests',2);
Screen('Preference', 'TextRenderer', 0);

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

%-----setup the PTB screen manager
s = screenManager('verbose', false, 'blend', true, 'screen', max(Screen('Screens')), ...
	'bitDepth', 'FloatingPoint32Bit', 'debug', false, ...
	'srcMode', 'GL_SRC_ALPHA', 'dstMode', 'GL_ONE_MINUS_SRC_ALPHA',...
	'windowed', [], 'backgroundColour', [backgroundColour 0]); 

try
	for i = 1:100
		fprintf('RUN %g: screen opening\n',i)
		screenVals = open(s); %open PTB screen
		setup(stimuli,s); %setup our stimulus object
		vbls = Screen('Flip',s.win); %flip the buffer
		vbl=vbls;
		while GetSecs <= vbls+1
			draw(stimuli); %draw stimulus
			Screen('Drawtext', s.win, 'Can Linux Draw Text?', 20, 20);
			Screen('DrawingFinished', s.win); %tell PTB/GPU to draw
			animate(stimuli); %animate stimulus, will be seen on next draw
			nextvbl = vbl + screenVals.halfisi;
			vbl = Screen('Flip',s.win, nextvbl); %flip the buffer
		end
		vbl = Screen('Flip',s.win);
		close(s)
		fprintf('RUN %g: screen closed\n',i)
		if KbCheck
			return
		end
	end
catch ME
	warning('CRASH!')
	close(s)
	rethrow ME
end
close(s)
clear s n stimuli


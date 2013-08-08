function dotstest()

runtime = 0.2;
n = dotsStimulus;
n.colour = [1 1 1];
n.coherence = 1;
s = screenManager('verbose',false,'blend',true,'screen',1,...
	'bitDepth','8bit','debug',false,...
		'backgroundColour',[0.2 0.2 0.2 0]); %use a temporary screenManager object
			
open(s); %open PTB screen
setup(n,s); %setup our stimulus object
%drawGrid(s); %draw +-5 degree dot grid
%drawScreenCenter(s); %centre spot
Screen('Flip',s.win);

%Set up up/down procedure:
up = 1;                     %increase after 1 wrong
down = 3;                   %decrease after 3 consecutive right
StepSizeDown = 0.05;        
StepSizeUp = 0.05;
stopcriterion = 'trials';   
stoprule = 50;
startvalue = 0.5;           %intensity on first trial

UD = PAL_AMUD_setupUD('up',up,'down',down);
UD = PAL_AMUD_setupUD(UD,'StepSizeDown',StepSizeDown,'StepSizeUp', ...
    StepSizeUp,'stopcriterion',stopcriterion,'stoprule',stoprule, ...
    'startvalue',startvalue);

breakloop = false;

while ~breakloop
	
	for i = 1:(s.screenVals.fps*runtime) %should be 2 seconds worth of flips
		draw(n); %draw stimulus
		Screen('DrawingFinished', s.win); %tell PTB/GPU to draw
		animate(n); %animate stimulus, will be seen on next draw
		Screen('Flip',s.win); %flip the buffer
	end	
	
	while keyIsDown ~= 1
		[keyIsDown, ~, keyCode] = KbCheck(-1);
		if keyIsDown == 1
			rchar = KbName(keyCode);
			if iscell(rchar);rchar=rchar{1};end
			switch rchar
				case {'LeftArrow','left'} %previous variable 1 value
					response = 0;
				case {'RightArrow','right'} %next variable 1 value
					
				case {'q'}
					breakloop = true;
					return
			end
		end
	end
end
WaitSecs(1);
Screen('Flip',s.win);
close(s); %close screen
clear s fps benchmark runtime b bb i; %clear up a bit
reset(n); %reset our stimulus ready for use again
end


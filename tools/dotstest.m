function dotstest()

runtime = 1.6;

n = dotsStimulus();
n.size = 2;
n.speed = 2;
n.dotSize = 0.1;
n.density = 25;
n.colour = [1 1 1];
n.colourType = 'simple';
n.coherence = 0.5;
n.kill = 0;
n.delayTime = 0.5;
n.offTime = 0.75;
n.mask = true;

a = apparentMotionStimulus();
a.barWidth = 0.75;
a.nBars = 6;
a.timing = [0.1 0.1];
a.barSpacing = 4;
a.direction = 'right';

stim = metaStimulus();
stim{1} = n;
stim{2} = a;

s = screenManager('verbose',false,'blend',true,'screen',0,...
	'bitDepth','8bit','debug',true,...
	'windowed',[1200 800],'backgroundColour',[0.2 0.2 0.2 0]); %use a temporary screenManager object
screenVals = open(s); %open PTB screen
setup(stim,s); %setup our stimulus object
%drawGrid(s); %draw +-5 degree dot grid
%drawScreenCenter(s); %centre spot

%Set up up/down procedure:
up = 1;                     %increase after 1 wrong
down = 3;                   %decrease after 3 consecutive right
StepSizeDown = 0.05;        
StepSizeUp = 0.1;
stopcriterion = 'reversals';   
stoprule = 3;
startvalue = 0.5;           %intensity on first trial
xMin = 0;

UDCONGRUENT = PAL_AMUD_setupUD('up',up,'down',down);
UDCONGRUENT = PAL_AMUD_setupUD(UDCONGRUENT,'StepSizeDown',StepSizeDown,'StepSizeUp', ...
    StepSizeUp,'stopcriterion',stopcriterion,'stoprule',stoprule, ...
    'startvalue',startvalue,'xMin',xMin);

UDINCONGRUENT = PAL_AMUD_setupUD('up',up,'down',down);
UDINCONGRUENT = PAL_AMUD_setupUD(UDINCONGRUENT,'StepSizeDown',StepSizeDown,'StepSizeUp', ...
    StepSizeUp,'stopcriterion',stopcriterion,'stoprule',stoprule, ...
    'startvalue',startvalue,'xMin',xMin);

WaitSecs(0.1)

try
	breakloop = false;

	vbl = Screen('Flip',s.win);
	Screen('DrawingFinished', s.win); %tell PTB/GPU to draw

	while ~breakloop

		%select new angle and coherence
		angleToggle = randi([0 1]) * 180;
		dirToggle = randi([0 1]);
		if dirToggle == 0;
			dirToggle = 'right';
		else
			dirToggle = 'left';
		end
		
		stim{1}.angleOut = angleToggle;
		stim{2}.direction = dirToggle;
		
		if (angleToggle == 180 && strcmpi(dirToggle,'left')) || (angleToggle == 0 && strcmpi(dirToggle,'right'))
			congruence = true;
		else
			congruence = false;
		end
		
		if congruence == true
			stim{1}.coherenceOut = UDCONGRUENT.xCurrent;
			st=UDCONGRUENT.stop;
			rev = UDCONGRUENT.reversal;
			up = UDCONGRUENT.u;
			down = UDCONGRUENT.d;
			x=length(UDCONGRUENT.x);
		else
			stim{1}.coherenceOut = UDINCONGRUENT.xCurrent;
			st=UDINCONGRUENT.stop;
			rev = UDINCONGRUENT.reversal;
			x=length(UDINCONGRUENT.x);
		end
		update(stim);
		fprintf('---> Angle: %i / %s | Coh: %.2g  | N: %i | U/D: %i/%i |Stop: %i / %i | ',angleToggle,dirToggle,n.coherenceOut,x,up,down,st,rev);

		drawSpot(s,0.1,[1 1 0]);
		Screen('Flip',s.win); %flip the buffer
		WaitSecs(0.5);

		vbls = Screen('Flip',s.win); %flip the buffer
		while GetSecs <= vbls+runtime
			draw(stim); %draw stimulus
			drawSpot(s,0.1,[1 1 0]);
			Screen('DrawingFinished', s.win); %tell PTB/GPU to draw
			animate(stim); %animate stimulus, will be seen on next draw
			vbl = Screen('Flip',s.win); %flip the buffer
		end	
		vbl = Screen('Flip',s.win);

		keyIsDown = false;
		response = [];
		while ~keyIsDown
			[keyIsDown, ~, keyCode] = KbCheck(-1);
			if keyIsDown == 1
				rchar = KbName(keyCode);
				if iscell(rchar);rchar=rchar{1};end
				switch rchar
					case {'LeftArrow','left'} %previous variable 1 value
						if angleToggle == 180
							response = 1;
						else
							response = 0;
						end
					case {'RightArrow','right'} %next variable 1 value
						if angleToggle == 0
							response = 1;
						else
							response = 0;
						end
					case {'q'}
						breakloop = true;
				end
			end
		end
		if congruence == true
			if ~UDCONGRUENT.stop && ~isempty(response)
				UDCONGRUENT = PAL_AMUD_updateUD(UDCONGRUENT, response); %update UD structure
			end
		else
			if ~UDINCONGRUENT.stop && ~isempty(response)
				UDINCONGRUENT = PAL_AMUD_updateUD(UDINCONGRUENT, response); %update UD structure
			end
		end

		Screen('Flip',s.win); %flip the buffer
		fprintf('RESPONSE = %i\n', response);
		
		if UDINCONGRUENT.stop == 1 && UDCONGRUENT.stop == 1
			breakloop = true;
		end
		WaitSecs(1);
	end
	
	Screen('Flip',s.win);
	WaitSecs(1);
	Priority(0); ListenChar(0); ShowCursor;
	close(s); %close screen
	reset(n); %reset our stimulus ready for use again

	%Threshold estimate as mean of all but the first three reversal points
	Mean = PAL_AMUD_analyzeUD(UDCONGRUENT, 'trials', 10);
	message = sprintf('\rThreshold CONGRUENT estimate of last 10 trials');
	message = strcat(message,sprintf(': %6.4f', Mean));
	disp(message);
	%Threshold estimate as mean of all but the first three reversal points
	Mean = PAL_AMUD_analyzeUD(UDINCONGRUENT, 'trials', 10);
	message = sprintf('\rThreshold INCONGRUENT estimate of last 10 trials');
	message = strcat(message,sprintf(': %6.4f', Mean));
	disp(message);
	
	t = 1:length(UDCONGRUENT.x);
	figure('name','Up/Down Adaptive Procedure');
	plot(t,UDCONGRUENT.x,'k');
	hold on;
	plot(t(UDCONGRUENT.response == 1),UDCONGRUENT.x(UDCONGRUENT.response == 1),'ko', 'MarkerFaceColor','k');
	plot(t(UDCONGRUENT.response == 0),UDCONGRUENT.x(UDCONGRUENT.response == 0),'ko', 'MarkerFaceColor','w');
	set(gca,'FontSize',16);
	title('CONGRUENT')
	axis([0 max(t)+1 min(UDCONGRUENT.x)-(max(UDCONGRUENT.x)-min(UDCONGRUENT.x))/10 max(UDCONGRUENT.x)+(max(UDCONGRUENT.x)-min(UDCONGRUENT.x))/10]);
	
	t = 1:length(UDINCONGRUENT.x);
	figure('name','Up/Down Adaptive Procedure');
	plot(t,UDINCONGRUENT.x,'k');
	hold on;
	plot(t(UDINCONGRUENT.response == 1),UDINCONGRUENT.x(UDINCONGRUENT.response == 1),'ko', 'MarkerFaceColor','k');
	plot(t(UDINCONGRUENT.response == 0),UDINCONGRUENT.x(UDINCONGRUENT.response == 0),'ko', 'MarkerFaceColor','w');
	set(gca,'FontSize',16);
	title('INCONGRUENT')
	axis([0 max(t)+1 min(UDINCONGRUENT.x)-(max(UDINCONGRUENT.x)-min(UDINCONGRUENT.x))/10 max(UDINCONGRUENT.x)+(max(UDINCONGRUENT.x)-min(UDINCONGRUENT.x))/10]);

catch ME
	Priority(0); ListenChar(0); ShowCursor;
	reset(n);
	close(s); %close screen
	ple(ME)
end
end


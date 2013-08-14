function dotstest()

runtime = 1.0;
useEyeLink = true;

%-----dots stimulus
n = dotsStimulus();
n.size = 3;
n.speed = 4;
n.dotType = 2; %high quality dots
n.dotSize = 0.1;
n.density = 25;
n.colour = [0.6 0.6 0.6];
n.colourType = 'simple'; %try also randomBW
n.coherence = 0.5;
n.kill = 0.1;
n.delayTime = 0.58; %time offset to first presentation
n.offTime = 0.78; %time to turn off dots
n.mask = true;

%-----apparent motion stimulus
a = apparentMotionStimulus();
a.yPosition = 0;
a.barWidth = 0.5;
a.nBars = 10;
a.timing = [0.1 0.02];
a.barSpacing = 4;
%a.delayTimeq = 0.48;
a.direction = 'right'; %initial direction of AM stimulus

%-----combine them into a single meta stimulus
stimuli = metaStimulus();
stimuli{1} = n;
stimuli{2} = a;

%-----open the PTB screens
s = screenManager('verbose',false,'blend',true,'screen',0,...
	'bitDepth','8bit','debug',false,'antiAlias',0,'nativeBeamPosition',1, ...
	'windowed',[],'backgroundColour',[0.3 0.3 0.3 0]); %use a temporary screenManager object
screenVals = open(s); %open PTB screen
setup(stimuli,s); %setup our stimulus object
%drawGrid(s); %draw +-5 degree dot grid
%drawScreenCenter(s); %centre spot

%-----setup eyelink
if useEyeLink == true;
	fixX = 0;
	fixY = 0;
	firstFixInit = 1;
	firstFixTime = 0.5;
	firstFixRadius = 1;
	targetFixInit = 1;
	targetFixTime = 0.5;
	targetRadius = 5;
	strictFixation = false;
	eL = eyelinkManager('IP',[]);
	eL.isDummy = false; %use dummy or real eyelink?
	eL.name = 'apparent-motion-test';
	eL.recordData = false; %save EDF file
	eL.sampleRate = 250;
	eL.remoteCalibration = true; % manual calibration?
	eL.calibrationStyle = 'HV5'; % calibration style
	eL.modify.calibrationtargetcolour = [1 1 0];
	eL.modify.calibrationtargetsize = 0.5;
	eL.modify.calibrationtargetwidth = 0.01;
	eL.modify.waitformodereadytime = 500;
	eL.modify.devicenumber = -1; % -1 = use any keyboard
	% X, Y, FixInitTime, FixTime, Radius, StrictFix
	updateFixationValues(eL, fixX, fixY, firstFixInit, firstFixTime, firstFixRadius, strictFixation);
	initialise(eL, s);
	setup(eL);
end

%-----Set up up/down procedure:
up				= 1; %increase after n wrong
down			= 2; %decrease after n consecutive right
StepSizeDown	= 0.05;
StepSizeUp		= 0.05;
stopcriterion	= 'trials';
stoprule		= 40;
startvalue		= 0.5; %intensity on first trial
xMin			= 0;

UDCONGRUENT = PAL_AMUD_setupUD('up',up,'down',down);
UDCONGRUENT = PAL_AMUD_setupUD(UDCONGRUENT,'StepSizeDown',StepSizeDown,'StepSizeUp', ...
	StepSizeUp,'stopcriterion',stopcriterion,'stoprule',stoprule, ...
	'startvalue',startvalue,'xMin',xMin);

UDINCONGRUENT = PAL_AMUD_setupUD('up',up,'down',down);
UDINCONGRUENT = PAL_AMUD_setupUD(UDINCONGRUENT,'StepSizeDown',StepSizeDown,'StepSizeUp', ...
	StepSizeUp,'stopcriterion',stopcriterion,'stoprule',stoprule, ...
	'startvalue',startvalue,'xMin',xMin);

try %our main experimental try catch loop
	breakloop = false;
	ts(1).x = -10 * s.ppd;
	ts(1).y = 0;
	ts(1).size = 10 * s.ppd;
	ts(1).selected = false;
	ts(2) = ts(1);
	ts(2).x = 10 * s.ppd;
	if useEyeLink == true; getSample(eL); end
	vbl = Screen('Flip',s.win);
	Screen('DrawingFinished', s.win); %tell PTB/GPU to draw
	
	loop = 1;
	while ~breakloop
		
		%-----select new angle and coherence
		angleToggle = randi([0 1]) * 180;
		dirToggle = randi([0 1]);
		if dirToggle == 0;
			dirToggle = 'right';
		else
			dirToggle = 'left';
		end
		
		stimuli{1}.angleOut = angleToggle;
		stimuli{2}.directionOut = dirToggle;
		
		if (angleToggle == 180 && strcmpi(dirToggle,'left')) || (angleToggle == 0 && strcmpi(dirToggle,'right'))
			congruence = true;
		else
			congruence = false;
		end
		
		%------draw bits to the eyelink
		if useEyeLink == true
			if angleToggle == 180
				ts(1).selected = true; ts(2).selected = false; 
			else
				ts(1).selected = false; ts(2).selected = true; 
			end
			updateFixationValues(eL, fixX, fixY, firstFixInit, firstFixTime, firstFixRadius, strictFixation);
			trackerClearScreen(eL);
			trackerDrawFixation(eL); %draw fixation window on eyelink computer
			trackerDrawStimuli(eL,ts);
		end
		
		%-----setup our coherence value and print some info for the trial
		if congruence == true
			stimuli{1}.coherenceOut = UDCONGRUENT.xCurrent;
			cc='CON';
			st=UDCONGRUENT.stop;
			rev = max(UDCONGRUENT.reversal);
			up = UDCONGRUENT.u;
			down = UDCONGRUENT.d;
			x=length(UDCONGRUENT.x);
		else
			stimuli{1}.coherenceOut = UDINCONGRUENT.xCurrent;
			cc='INCON';
			st=UDINCONGRUENT.stop;
			rev = max(UDINCONGRUENT.reversal);
			up = UDINCONGRUENT.u;
			down = UDINCONGRUENT.d;
			x=length(UDINCONGRUENT.x);
		end
		update(stimuli);
		fprintf('---> Angle: %i / %s | Coh: %.2g  | N(%s): %i | U/D: %i/%i |Stop/Rev: %i/%i \n',angleToggle,dirToggle,stimuli{1}.coherenceOut,cc,x,up,down,st,rev);
		
		%-----fire up eyelink
		if useEyeLink == true
			edfMessage(eL,['TRIALID ' num2str(loop)]); ...
			startRecording(eL);
			syncTime(eL);
			statusMessage(eL,'Initiate Fixation...')
			WaitSecs(0.1);
		end
		
		%-----draw initial fixation spot
		fixated = '';
		if useEyeLink == true
			while ~strcmpi(fixated,'fix') && ~strcmpi(fixated,'breakfix')
				drawSpot(s,0.1,[1 1 0]);
				Screen('Flip',s.win); %flip the buffer
				getSample(eL);
				fixated=testSearchHoldFixation(eL,'fix','breakfix');
			end
		else
			drawSpot(s,0.1,[1 1 0]);
			Waitsecs(0.5);
			fixated = 'fix';
		end
		
		%------Our main stimulus drawing loop
		if strcmpi(fixated,'fix') %initial fixation held
			if useEyeLink == true;statusMessage(eL,'Show Stimulus...');end
			drawSpot(s,0.1,[1 1 0]);
			vbls = Screen('Flip',s.win); %flip the buffer
			while GetSecs <= vbls+runtime
				draw(stimuli); %draw stimulus
				drawSpot(s,0.1,[1 1 0]);
				%if useEyeLink == true;getSample(eL);drawEyePosition(eL);end
				Screen('DrawingFinished', s.win); %tell PTB/GPU to draw
				animate(stimuli); %animate stimulus, will be seen on next draw
				vbl = Screen('Flip',s.win); %flip the buffer
			end
			vbl = Screen('Flip',s.win);
			
			%-----get our response
			response = [];
			if useEyeLink == true;
				if angleToggle == 180
					x = -10;
					correctwindow = 1;
				elseif angleToggle == 0
					x = 10;
					correctwindow = 2;
				else
					error('toggleerror');
				end

				statusMessage(eL,'Get Response...')
				updateFixationValues(eL, [-10 10], [0 0], targetFixInit, targetFixTime, targetRadius, strictFixation); ... %set target fix window
	
				fixated = '';
				while ~any(strcmpi(fixated,{'fix','breakfix'}))
					drawSpot(s,1,[1 1 1],x,0);
					drawSpot(s,1,[1 1 1],-x,0);
					Screen('DrawingFinished', s.win); %tell PTB/GPU to draw
					getSample(eL); %drawEyePosition(eL);
					[fixated, window] = testSearchHoldFixation(eL,'fix','breakfix');
					vbl = Screen('Flip',s.win);
				end
				fprintf('FIXATED WINDOW: %i (should be: %i)\n',window,correctwindow);
				if strcmpi(fixated,'fix') && window == correctwindow
					response = 1;
				elseif ~isempty(window)
					response = 0;
				else
					response = [];
				end
				
				%-----disengage eyelink
				vbl = Screen('Flip',s.win);
				stopRecording(eL);
				setOffline(eL);
			
			end
			
			%-----check keyboard
			if useEyeLink == true
				t = GetSecs+1;
			else
				t = GetSecs+10;
			end
			while GetSecs <= t
				[keyIsDown, ~, keyCode] = KbCheck(-1);
				if keyIsDown == 1
					rchar = KbName(keyCode);
					if iscell(rchar);rchar=rchar{1};end
					switch rchar
						case {'LeftArrow','left'}
							if angleToggle == 180
								response = 1;
							else
								response = 0;
							end
						case {'RightArrow','right'}
							if angleToggle == 0
								response = 1;
							else
								response = 0;
							end
						case {'q'}
							fprintf('\nQUIT!\n');
							breakloop = true;
						otherwise
							
					end
				end
			end
			
			%-----Update the staircase
			if congruence == true
				if UDCONGRUENT.stop ~= 1 && ~isempty(response)
					UDCONGRUENT = PAL_AMUD_updateUD(UDCONGRUENT, response); %update UD structure
				end
			else
				if UDINCONGRUENT.stop ~= 1 && ~isempty(response)
					UDINCONGRUENT = PAL_AMUD_updateUD(UDINCONGRUENT, response); %update UD structure
				end
			end
			if ~isempty(response)
				fprintf('RESPONSE = %i\n', response);
			else
				fprintf('RESPONSE EMPTY\n', response);
			end
			
			if UDINCONGRUENT.stop == 1 && UDCONGRUENT.stop == 1
				fprintf('\nBOTH LOOPS HAVE STOPPED\n', response);
				breakloop = true;
			end
		end
		fprintf('\n');
		Screen('Flip',s.win); %flip the buffer
		WaitSecs(0.5);
	end
	
	%-----Cleanup
	Screen('Flip',s.win);
	Priority(0); ListenChar(0); ShowCursor;
	close(s); %close screen
	
	if useEyeLink == true; close(eL); end
	reset(stimuli); %reset our stimulus ready for use again
	clear stim eL s
	
	%----------------Threshold estimates
	assignin('base','UDCONGRUENT',UDCONGRUENT)
	assignin('base','UDINCONGRUENT',UDINCONGRUENT)
	Mean = PAL_AMUD_analyzeUD(UDCONGRUENT, 'trials', 10);
	message = sprintf('\rThreshold CONGRUENT estimate of last 10 trials');
	message = strcat(message,sprintf(': %6.4f', Mean));
	disp(message);
	Mean = PAL_AMUD_analyzeUD(UDINCONGRUENT, 'trials', 10);
	message = sprintf('\rThreshold INCONGRUENT estimate of last 10 trials');
	message = strcat(message,sprintf(': %6.4f', Mean));
	disp(message);
	
	%--------------Plots
	t = 1:length(UDCONGRUENT.x);
	f=figure('name','Up/Down Staircase');
	p=panel(f);
	p.pack(2,1)
	p(1,1).select();
	plot(t,UDCONGRUENT.x,'k');
	hold on;
	plot(t(UDCONGRUENT.response == 1),UDCONGRUENT.x(UDCONGRUENT.response == 1),'ko', 'MarkerFaceColor','k');
	plot(t(UDCONGRUENT.response == 0),UDCONGRUENT.x(UDCONGRUENT.response == 0),'ko', 'MarkerFaceColor','w');
	set(gca,'FontSize',16);
	title('CONGRUENT')
	axis([0 max(t)+1 min(UDCONGRUENT.x)-(max(UDCONGRUENT.x)-min(UDCONGRUENT.x))/10 max(UDCONGRUENT.x)+(max(UDCONGRUENT.x)-min(UDCONGRUENT.x))/10]);
	t = 1:length(UDINCONGRUENT.x);
	p(2,1).select();
	plot(t,UDINCONGRUENT.x,'k');
	hold on;
	plot(t(UDINCONGRUENT.response == 1),UDINCONGRUENT.x(UDINCONGRUENT.response == 1),'ko', 'MarkerFaceColor','k');
	plot(t(UDINCONGRUENT.response == 0),UDINCONGRUENT.x(UDINCONGRUENT.response == 0),'ko', 'MarkerFaceColor','w');
	set(gca,'FontSize',16);
	title('INCONGRUENT')
	axis([0 max(t)+1 min(UDINCONGRUENT.x)-(max(UDINCONGRUENT.x)-min(UDINCONGRUENT.x))/10 max(UDINCONGRUENT.x)+(max(UDINCONGRUENT.x)-min(UDINCONGRUENT.x))/10]);
	

catch ME
	Priority(0); ListenChar(0); ShowCursor;
	reset(stimuli);
	close(s); %close screen
	if useEyeLink == true; close(eL); end
	clear stim eL s
	rethrow(ME);
end
end


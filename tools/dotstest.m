function dotstest()

useEyeLink = false;
useStaircase = false;
backgroundColour = [0.3 0.3 0.3];
subject = 'Ian';
fixx = 0;
fixy = 0;

if useStaircase; type = 'STAIR';else type = 'MOC';end %#ok<*UNRCH>
name = ['AM_' type '_' subject];
c = sprintf(' %i',fix(clock()));
c = regexprep(c,' ','_');
name = [name c];

p=uigetdir(pwd,'Select Directory to Save Data and Screenshot:');
cd(p);

%-----dots stimulus
n = dotsStimulus();
n.name = name;
n.size = 3;
n.speed = 4;
n.dotType = 2; %high quality dots
n.dotSize = 0.1;
n.density = 25;
n.colour = [0.45 0.45 0.45];
n.maskColour = backgroundColour + 0.1;
n.colourType = 'simple'; %try also randomBW
n.coherence = 0.5;
n.kill = 0.1;
n.delayTime = 0.58; %time offset to first presentation
n.offTime = 0.78; %time to turn off dots
n.mask = false;

%-----apparent motion stimulus
a = apparentMotionStimulus();
a.name = name;
a.yPosition = -30;
a.colour = [0.4 0.4 0.4];
a.barLength = 3;
a.barWidth = 3;
a.nBars = 10;
a.timing = [0.15 0.05];
a.barSpacing = 3;
%a.delayTime = 0.48;
%a.offTime = 0.62;
a.direction = 'right'; %initial direction of AM stimulus

%-----use a real driqfting bar
b = barStimulus();
b.yPosition = 0;
b.colour = a.colour;
b.barLength = a.barLength;
b.barWidth = a.barWidth;
b.speed = a.barSpacing / sum(a.timing);
b.startPosition = -b.speed;

%-----grey mask 
sp = barStimulus();
sp.yPosition = 0;
sp.barWidth = n.size;
sp.speed = 0;
sp.startPosition = 0;
sp.barLength = a.barLength + 40;
sp.colour = backgroundColour + 0.1;
sp.alpha = 1;

%-----tweak timing based on settings
t = (sum(a.timing) * a.nBars/2) - a.timing(2);
n.delayTime = t; %time offset to first presentation
n.offTime = t + 0.2; %time to turn off dots
runtime = sum(a.timing) * a.nBars;
%runtime = 1.0;

%-----combine them into a single meta stimulus
stimuli = metaStimulus();
stimuli.name = name;

amidx = 4;
dotsidx = 3;
baridx = 1;
maskidx = 2;
stimuli{amidx} = a;
stimuli{dotsidx} = n;
stimuli{baridx} = b;
stimuli{maskidx} = sp;

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
	eL.name = name;
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
	initialise(qeL, s);
	setup(eL);
end

%-----Set up up/down procedure:
up				= 1; %increase after n wrong
down			= 2; %decrease after n consecutive right
StepSizeDown	= 0.05;
StepSizeUp		= 0.1;
stopcriterion	= 'trials';
stoprule		= 40;
startvalue		= 0.35; %intensity on first trial
xMin			= 0;

UDCONGRUENT = PAL_AMUD_setupUD('up',up,'down',down);
UDCONGRUENT = PAL_AMUD_setupUD(UDCONGRUENT,'StepSizeDown',StepSizeDown,'StepSizeUp', ...
	StepSizeUp,'stopcriterion',stopcriterion,'stoprule',stoprule, ...
	'startvalue',startvalue,'xMin',xMin);

UDINCONGRUENT = PAL_AMUD_setupUD('up',up,'down',down);
UDINCONGRUENT = PAL_AMUD_setupUD(UDINCONGRUENT,'StepSizeDown',StepSizeDown,'StepSizeUp', ...
	StepSizeUp,'stopcriterion',stopcriterion,'stoprule',stoprule, ...
	'startvalue',startvalue,'xMin',xMin);

task = stimulusSequence();
task.name = name;
task.nBlocks = 20;
task.nVar(1).name = 'angle';
task.nVar(1).stimuli = dotsidx;
task.nVar(1).values = {0, 180};
task.nVar(2).name = 'direction';
task.nVar(2).stimuli = amidx;
task.nVar(2).values = {'left','right'};
task.nVar(3).name = 'coherence';
task.nVar(3).stimuli = dotsidx;
task.nVar(3).values = {0 0.1 0.2 0.3 0.4 0.5};
task.nVar(4).name = 'yPosition';
task.nVar(4).stimuli = baridx;
task.nVar(4).values = {0 0 -30};
randomiseStimuli(task);
initialiseTask(task)

if ~useStaircase
	UDCONGRUENT.startValue = task.outValues{1,3}{:};
	UDINCONGRUENT.startValue = task.outValues{1,3}{:};
end


try %our main experimental try catch loop
	
	%-----open the PTB screens
	s = screenManager('verbose',false,'blend',true,'screen',0,...
		'bitDepth','8bit','debug',false,'antiAlias',0,'nativeBeamPosition',0, ...
		'srcMode','GL_SRC_ALPHA','dstMode','GL_ONE_MINUS_SRC_ALPHA',...
		'windowed',[],'backgroundColour',[backgroundColour 0]); %use a temporary screenManager object
	screenVals = open(s); %open PTB screen
	setup(stimuli,s); %setup our stimulus object

	breakloop = false;

	%ts is our stimulus positions to draw to the eyetracker display
	ts(1).x = -10 * s.ppd;
	ts(1).y = 0;
	ts(1).size = 10 * s.ppd;
	ts(1).selected = false;
	ts(2) = ts(1);
	ts(2).x = 10 * s.ppd;
	
	if useEyeLink == true; getSample(eL); end
	vbl = Screen('Flip',s.win);
	
	loop = 1;
	response = [];
	while ~breakloop
		
		if useStaircase
			angleToggle = randi([0 1]) * 180;
			dirToggle = randi([0 1]);
			if dirToggle == 0;
				dirToggle = 'right';
			else
				dirToggle = 'left';
			end
		else
			angleToggle = task.outValues{task.totalRuns,1}{:};
			dirToggle = task.outValues{task.totalRuns,2}{:};
			yToggle = task.outValues{task.totalRuns,4}{:};
		end
		
		stimuli{dotsidx}.angleOut = angleToggle;
		stimuli{amidx}.directionOut = dirToggle;
		stimuli{baridx}.yPositionOut = yToggle;
			
		if length(stimuli) >= baridx
			if strcmpi(dirToggle,'right')
				stimuli{baridx}.angleOut = 0;
			else
				stimuli{baridx}.angleOut = 180;
			end
		end
		
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
		if useStaircase
			if congruence == true
				coherenceOut = UDCONGRUENT.xCurrent;
				cc='CON';
				st=UDCONGRUENT.stop;
				rev = max(UDCONGRUENT.reversal);
				up = UDCONGRUENT.u;
				down = UDCONGRUENT.d;
				x=length(UDCONGRUENT.x);
			else
				coherenceOut = UDINCONGRUENT.xCurrent;
				cc='INCON';
				st=UDINCONGRUENT.stop;
				rev = max(UDINCONGRUENT.reversal);
				up = UDINCONGRUENT.u;
				down = UDINCONGRUENT.d;
				x=length(UDINCONGRUENT.x);
			end
			stimuli{dotsidx}.coherenceOut = coherenceOut;
			update(stimuli);
			t = sprintf('---> Angle: %i / %s | Coh: %.2g  | N(%s): %i | U/D: %i/%i |Stop/Rev: %i/%i | ',stimuli{dotsidx}.angleOut,stimuli{amidx}.directionOut,stimuli{dotsidx}.coherenceOut,cc,x,up,down,st,rev);
		else
			if congruence == true
				cc='CON';
			else
				cc='INCON';
			end
			coherenceOut = task.outValues{task.totalRuns,3}{:};
			stimuli{dotsidx}.coherenceOut = coherenceOut;
			update(stimuli);
			t = sprintf('---> Angle: %i / %s | Coh: %.2g  | N(%s): %i | y: %g',stimuli{dotsidx}.angleOut,stimuli{amidx}.directionOut,stimuli{dotsidx}.coherenceOut,cc,task.totalRuns,yToggle);
		end
		
		disp(t);
		
		%-----fire up eyelink
		if useEyeLink == true
			edfMessage(eL,['TRIALID ' num2str(loop)]); ...
			startRecording(eL);
			syncTime(eL);
			statusMessage(eL,['t' ' FIX'])
			WaitSecs(0.1);
		end
		
		hide(stimuli)
		show(stimuli{maskidx});
		
		%-----draw initial fixation spot
		fixated = '';
		if useEyeLink == true
			while ~strcmpi(fixated,'fix') && ~strcmpi(fixated,'breakfix')
				draw(stimuli); %draw stimulus
				drawSpot(s,0.1,[1 1 0],fixx,fixy);
				Screen('DrawingFinished', s.win); %tell PTB/GPU to draw
				Screen('Flip',s.win); %flip the buffer
				getSample(eL);
				fixated=testSearchHoldFixation(eL,'fix','breakfix');
			end
		else
			draw(stimuli); %draw stimulus
			drawSpot(s,0.1,[1 1 0],fixx,fixy);
			Screen('Flip',s.win); %flip the buffer
			WaitSecs(0.5);			
			fixated = 'fix';
		end
		
		%------Our main stimulus drawing loop
		if strcmpi(fixated,'fix') %initial fixation held
			if useEyeLink == true;statusMessage(eL,[t 'Show Stimulus...']);end
			draw(stimuli); %draw stimulus
			drawSpot(s,0.1,[1 1 0],fixx,fixy);
			show(stimuli)
			vbls = Screen('Flip',s.win); %flip the buffer
			vbl=vbls;
			while GetSecs <= vbls+runtime
				draw(stimuli); %draw stimulus
				drawSpot(s,0.1,[1 1 0],fixx,fixy);
				%if useEyeLink == true;getSample(eL);drawEyePosition(eL);end
				Screen('DrawingFinished', s.win); %tell PTB/GPU to draw
				animate(stimuli); %animate stimulus, will be seen on next draw
				nextvbl = vbl + screenVals.halfisi;
				vbl = Screen('Flip',s.win, nextvbl); %flip the buffer
			end
			
			Screen('Drawtext', s.win, ['TRIAL: ' num2str(task.totalRuns)],10,10);
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

				statusMessage(eL,[t 'Get Response...'])
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
				timeout = GetSecs+1;
			else
				timeout = GetSecs+5;
			end
			breakloopkey = false;
			quitkey = false;
			while ~breakloopkey
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
							breakloopkey = true;
						case {'RightArrow','right'}
							if angleToggle == 0
								response = 1;
							else
								response = 0;
							end
							breakloopkey = true;
						case {'q'}
							fprintf('\nQUIT!\n');
							quitkey = true;
							breakloop = true;
							breakloopkey = true;
						otherwise
							
					end
				end
				if timeout<=GetSecs; breakloopkey = true; end
			end
			
			if useStaircase
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
			else
				if ~isempty(response) && (response == true || response == false)
					if congruence == true
						UDCONGRUENT.response(task.totalRuns) = response;
						UDCONGRUENT.x(task.totalRuns) = coherenceOut;
					else
						UDINCONGRUENT.response(task.totalRuns) = response;
						UDINCONGRUENT.x(task.totalRuns) = coherenceOut;
					end
					task.response{task.totalRuns,1} = response;
					task.response{task.totalRuns,2} = congruence;
					task.response{task.totalRuns,3} = coherenceOut;
					task.response{task.totalRuns,4} = angleToggle;
					task.response{task.totalRuns,5} = dirToggle;
					task.response{task.totalRuns,6} = yToggle;
					task.totalRuns = task.totalRuns + 1;
					fprintf('RESPONSE = %i\n', response);
				else
					fprintf('RESPONSE EMPTY\n', response);
				end
				
				if task.totalRuns > task.nRuns
					fprintf('\nTask finished!\n', response);
					breakloop = true;
				end
			end
		end
		Screen('Flip',s.win); %flip the buffer
		WaitSecs(0.5);
	end
	
	%-----Cleanup
	Screen('Flip',s.win);
	Priority(0); ListenChar(0); ShowCursor;
	close(s); %close screen
	
	if useEyeLink == true; close(eL); end
	reset(stimuli); %reset our stimulus ready for use again
	
	dat(1).name = name;
	dat.useEyeLink = useEyeLink;
	dat.useStaircase = useStaircase;
	dat.backgroundColour = backgroundColour;
	dat.runtime = runtime;
	dat.task = task;
	dat(1).sc(1).name='UDCONGRUENT';
	dat(1).sc(1).data=UDCONGRUENT;
	dat(1).sc(2).name='UDINCONGRUENT';
	dat(1).sc(2).data=UDINCONGRUENT;
	if useEyeLink == true;dat(1).eL = eL;end
	dat(1).screen = s;
	dat(1).stimuli = stimuli;
	assignin('base','dat',dat);
	
	if useStaircase
		%----------------Threshold estimates
		Mean1 = PAL_AMUD_analyzeUD(UDCONGRUENT, 'trials', 10);
		message = sprintf('\rThreshold CONGRUENT estimate of last 10 trials');
		message = strcat(message,sprintf(': %6.4f', Mean1));
		disp(message);
		Mean2 = PAL_AMUD_analyzeUD(UDINCONGRUENT, 'trials', 10);
		message = sprintf('\rThreshold INCONGRUENT estimate of last 10 trials');
		message = strcat(message,sprintf(': %6.4f', Mean2));
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
		title(['CONGRUENT = ' num2str(Mean1)])
		axis([0 max(t)+1 min(UDCONGRUENT.x)-(max(UDCONGRUENT.x)-min(UDCONGRUENT.x))/10 max(UDCONGRUENT.x)+(max(UDCONGRUENT.x)-min(UDCONGRUENT.x))/10]);
		t = 1:length(UDINCONGRUENT.x);

		p(2,1).select();
		plot(t,UDINCONGRUENT.x,'k');
		hold on;
		plot(t(UDINCONGRUENT.response == 1),UDINCONGRUENT.x(UDINCONGRUENT.response == 1),'ko', 'MarkerFaceColor','k');
		plot(t(UDINCONGRUENT.response == 0),UDINCONGRUENT.x(UDINCONGRUENT.response == 0),'ko', 'MarkerFaceColor','w');
		set(gca,'FontSize',16);
		title(['INCONGRUENT = ' num2str(Mean2)])
		axis([0 max(t)+1 min(UDINCONGRUENT.x)-(max(UDINCONGRUENT.x)-min(UDINCONGRUENT.x))/10 max(UDINCONGRUENT.x)+(max(UDINCONGRUENT.x)-min(UDINCONGRUENT.x))/10]);
	else
		
	end
	
	button = questdlg('Do you want to save this to a MAT file?');
	if strcmpi(button,'yes')
		uisave('dat',[name '.mat']);
		if useStaircase; p.export([name '.png']); end
	end

catch ME
	ple(ME)
	Priority(0); ListenChar(0); ShowCursor;
	reset(stimuli);
	close(s); %close screen
	if useEyeLink == true; close(eL); end
	clear stimuli task eL s
	rethrow(ME);
end
end


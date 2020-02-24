function VEPTest()

	global lM
	if ~exist('lM','var') || isempty(lM) || ~isa(lM,'labJackT')
		 lM = labJackT;
	end
	if ~lM.isOpen; open(lM); end %open our strobed word manager
	global rM
	if ~exist('rM','var') || isempty(rM) || ~isa(rM,'arduinoManager')
		 rM = arduinoManager;
	end
	if ~rM.isOpen; open(rM); end %open our reward manager

	bgColour			= 0.5;
	screen				= max(Screen('Screens'));
	windowed			= [];

	% ---- screenManager
	ptb					= mySetup(screen,bgColour,windowed);
	ptb.audio			= audioManager();
	ptb.audio.setup();
	if length(Screen('Screens')) > 1 %we have two screens so calibration can use 2 screens
		s					= screenManager;
		s.screen			= ptb.screen - 1;
		s.backgroundColour	= bgColour;
		s.windowed			= [];
		s.bitDepth			= '8bit';
		s.blend				= true;
		s.disableSyncTests	= true;
	end

	% ---- setup stimulus
	b					= barStimulus;
	b.barWidth			= 120;
	b.barLength			= 100;
	b.type				= 'checkerboard';
	b.phaseReverseTime	= 0.3;
	b.checkSize			= 2;
	setup(b,ptb);
	
	% ---- tobii manager
	t					= tobiiManager();
	t.isDummy			= true;
	t.name				= 'VEPTest';
	t.trackingMode		= 'macaque';
	t.sampleRate		= 600;
	t.calibrationStimulus = 'movie';
	t.fixation.X		= 0;
	t.fixation.Y		= 0;
	t.fixation.Radius	= 20;
	if exist('s','var') && ~t.isDummy
		initialise(t,ptb,s);
	else
		initialise(t,ptb);
	end
	
	t.settings.cal.pointPos = [0.3 0.3; 0.7 0.7];
	t.settings.val.pointPos = [0.5 0.5];
	
	trackerSetup(t); ShowCursor();
	if exist('s','var') && ~t.isDummy;try Screen('Close',s.win);end;end
    WaitSecs('YieldSecs',1);
	
	% ---- prepare tracker
	Priority(MaxPriority(ptb.win)); %bump our priority to maximum allowed
	startRecording(t); WaitSecs(1);
	trackerMessage(t,'!!! Starting VEPTest...')
	
	% ---- prepare variables
	endExp				= false;
	stopkey				= KbName('q');
	trialn				= 1;
	maxTrials			= 500;
	trialLength			= 6;
	ITDelay				= 2;
	
	ptb.drawPhotoDiodeSquare([0 0 0 1]);
	flip(ptb);
	WaitSecs('YieldSecs',0.5);
    ListenChar(2);
	
	while trialn <= maxTrials && endExp == 0
		trialtick = 1;
		trackerMessage(t,sprintf('TRIALID %i',trialn))
		drawPhotoDiodeSquare(ptb,[0 0 0 1]);
		vbl = flip(ptb); tstart=vbl;
		ptb.audio.play();
		while vbl < tstart + trialLength
			draw(b);
			drawCross(ptb,2,[1 1 0]);
			ptb.drawPhotoDiodeSquare([1 1 1 1]);
			finishDrawing(ptb);
			animate(b);
			getSample(t);
			vbl = ptb.flip(vbl);
			if trialtick == 1; lM.strobeServer(1); trackerMessage(t,'STARTVBL',tstart); end
			trialtick = trialtick + 1;
		end
		if endExp == 0
            drawPhotoDiodeSquare(ptb,[0 0 0 1]);
			vbl = flip(ptb); endt = vbl;
			lM.strobeServer(1);lM.strobeServer(1);
            rM.timedTTL(2,300);
			trackerMessage(t,'END_RT',vbl);
			trackerMessage(t,'TRIAL_RESULT 1')
			trackerMessage(t,sprintf('Ending trial %i @ %i',trialn,int64(round(vbl*1e6))))
			resetFixation(t);
			update(b);
            while vbl < endt + ITDelay
                drawPhotoDiodeSquare(ptb,[0 0 0 1]);
                % ---- handle keyboard
                [~, ~, keyCode] = KbCheck(-1);
                if keyCode(stopkey); endExp = 1; break; end
                vbl = ptb.flip();
            end
			trialn = trialn + 1;
		else
			drawPhotoDiodeSquare(ptb,[0 0 0 1]);
			vbl = flip(ptb);
			trackerMessage(t,'END_RT',vbl);
			trackerMessage(t,'TRIAL_RESULT -10 ABORT')
			trackerMessage(t,sprintf('Aborting %i @ %i', trialn, int64(round(vbl*1e6))))
		end
    end 
    reset(b);
	stopRecording(t);
	close(ptb);
	saveData(t);
	close(t);
	ListenChar(0); Priority(0); ShowCursor;
	ptb.flip();
	close(ptb);
end

function ptb = mySetup(screen, bgColour, win)
	ptb.cleanup = onCleanup(@myCleanup);
	PsychDefaultSetup(2);
	ptb = screenManager('backgroundColour',bgColour,'screen',screen,'windowed',win);
	ptb.bitDepth = '8bit';
	ptb.blend = true;
	ptb.open();
end

function myCleanup()
	disp('Clearing up...')
	sca
end

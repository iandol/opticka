function tobiidemo2b()

	bgColour = 0.25;
	screen = 1;
	windowed=[];

	% ---- screenManager
	ptb = mySetup(screen,bgColour,windowed);
	ptb.audio = audioManager();
	ptb.audio.setup();
	s = screenManager;
	s.screen = ptb.screen-1;
	s.windowed = [];
	s.bitDepth = '8bit';
	s.blend = true;
	s.disableSyncTests = true;

	% ---- setup movie path
	m=movieStimulus;
	m.mask = [0 0 0];
	setup(m,ptb);
	
	% ---- tobii manager
	t = tobiiManager();
	t.name = 'Tobii Demo 2b';
	t.trackingMode = 'macaque';
	t.sampleRate = 600;
	t.calibrationStimulus = 'movie';
	initialise(t,ptb,s);
	
	t.settings.cal.pointPos = [0.3 0.3; 0.7 0.7];
	t.settings.val.pointPos = [0.5 0.5];
	
	trackerSetup(t); ShowCursor();
	Screen('Close',s.win); WaitSecs('YieldSecs',1);
	
	% ---- prepare tracker
	Priority(MaxPriority(ptb.win)); %bump our priority to maximum allowed
	startRecording(t); WaitSecs(1);
	trackerMessage(t,'!!! Starting Demo...')
	
	% ---- prepare variables
	CloseWin = false;
	quit = KbName('escape');
	vbl = ptb.flip(); startT = vbl;
	trackerMessage(t,'STARTVBL',vbl);
	while ~CloseWin && vSbl <= startT + 4
		draw(m);
		finishDrawing(ptb);
		animate(m);
		getSample(t);
		
		vbl = ptb.flip(vbl);

		% ---- handle keyboard
		[~,~,keyCode] = KbCheck(-1);
		name = find(keyCode==1);
		if ~isempty(name)  
			switch name
				case quit
					CloseWin = true;
					trackerMessage(t,'END_RT',vbl);
				otherwise
					%disp('Cant match key!')
			end
		end
	end 
	ptb.flip();
	stopRecording(t);
	ListenChar(0); Priority(0); ShowCursor;
	reset(m);
	saveData(t);
	close(t); close(ptb);
end

function ptb = mySetup(screen, bgColour, win)
	ptb.cleanup = onCleanup(@myCleanup);
	ptb = screenManager('backgroundColour',bgColour,'screen',screen,'windowed',win);
	ptb.bitDepth = '8bit';
	ptb.blend = true;
	ptb.open();
end

function myCleanup()
	disp('Clearing up...')
	sca
end
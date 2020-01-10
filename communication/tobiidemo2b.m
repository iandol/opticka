function tobiidemo2b()

	bgColour = 0.25;
	screen = 2;
	windowed=[];

	% ---- screenManager
	ptb = mySetup(screen,bgColour,windowed);
	s = screenManager;
	s.screen = 1;
	s.windowed = [0 0 1000 1000];
	s.bitDepth = '8bit';
	s.blend = true;
	s.disableSyncTests = true;

	% ---- setup movie path
	m=movieStimulus;
	m.mask = [0 0 0];
	m.maskTolerance = 0.005;
	setup(m,ptb);
	
	% ---- tobii manager
	t = tobiiManager();
	t.trackingMode = 'human';
	t.sampleRate = 600;
	t.calibrationStimulus = 'movie';
	initialise(t,ptb,s2);
	trackerSetup(t);
	s2.close;
	Priority(MaxPriority(ptb.win)); %bump our priority to maximum allowed
	startRecording(t); WaitSecs(1);
	trackerMessage(t,'!!! Starting Demo...')
	
	% ---- prepare variables
	CloseWin = false;
	quit = KbName('escape');
	vbl = ptb.flip(); startT = vbl;
	trackerMessage(t,'STARTVBL',vbl);
	while ~CloseWin || vbl <= startT+2
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
	stopRecording(t);
	ListenChar(0); Priority(0); ShowCursor;
	close(ptb);
	saveData(t);
	close(t);
end

function ptb = mySetup(screen, bgColour, win)
	ptb.cleanup = onCleanup(@myCleanup);
	ptb = screenManager('backgroundColour',bgColour,'screen',screen,'windowed',win);
	ptb.blend = true;
	ptb.open();
end

function myCleanup()
	disp('Clearing up...')
	sca
end
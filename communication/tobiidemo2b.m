function tobiidemo2b()

	bgColour = 0.5;
	screen = 2;
	screenSize = [];

	% ---- screenManager
	ptb = mySetup(screen,bgColour,screenSize);

	% ---- setup movie path
	m=movieStimulus;
	m.mask = [0 0 0];
	m.maskTolerance = 0.005;
	setup(m,ptb);
	
	% ---- tobii manager
	t = tobiiManager;
	initialise(t,ptb);
	trackerSetup(t);
	startRecording(t); WaitSecs(1);
	trackerMessage(t,'!!! Starting Demo...')
	
	% ---- prepare variables
	CloseWin = false;
	quit = KbName('escape');
	Priority(MaxPriority(ptb.win)); %bump our priority to maximum allowed
	vbl = ptb.flip();
	trackerMessage(t,'STARTVBL',vbl);
	while ~CloseWin
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

function ptb = mySetup(screen, bgColour, ws)
	ptb.cleanup = onCleanup(@myCleanup);
	ptb = screenManager('backgroundColour',bgColour,'screen',screen);
	ptb.blend = true;
	ptb.open();
end

function myCleanup()
	disp('Clearing up...')
	sca
end
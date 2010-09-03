try
	benchmark=0;
	% Disable synctests for this quick demo:
	oldSyncLevel = Screen('Preference', 'SkipSyncTests', 0);
	oldLevel = Screen('Preference', 'VisualDebugLevel', 1 );
	
	%This allows a funky overlay mode for single screen debugging - screws
	%timing!
% 	Screen('Preference', 'ConserveVRAM', 16384);
% 	Screen('Preference', 'SkipSyncTests', 2);
% 	Screen('Preference', 'VBLTimestampingMode', -1);
% 	Screen('Preference', 'WindowShieldingLevel', 1250);

	scrn = max(Screen('Screens'));
	
	PsychImaging('PrepareConfiguration');
	PsychImaging('AddTask', 'General', 'FloatingPoint32BitIfPossible');
	%[ptr rect] = PsychImaging('OpenWindow', scrn, [128 128 128]);
	%Screen('BlendFunction', ptr, 'GL_ONE', 'GL_ONE');
	%Screen('BlendFunction', ptr, 'GL_SRC_ALPHA','GL_ONE_MINUS_SRC_ALPHA');
	
	[ptr rect]=Screen('OpenWindow',scrn,128);
	
	[oldmaximumvalue oldclampcolors] = Screen('ColorRange', ptr, 1);
	
	Screen('BlendFunction', ptr, 'GL_SRC_ALPHA', 'GL_ONE_MINUS_SRC_ALPHA');
	%Screen('BlendFunction', ptr, 'GL_ONE', 'GL_ONE');
	
	nobjs=40;
	pos = ones(2,nobjs)*mean([rect(3) rect(4)])/2;
	col = round(rand(4,nobjs)*255);
	col(end,:)=50;
	count=5000;
	randseed=(rand(2,nobjs)*2-1);
	x1=0;
	x2=0;
	y1=0;
	y2=0;
	telapsed=ones(count,1);

	si = 32;
	tw = 2*si+1;
	th = 2*si+1;
	phase = 0;
	sc = 10.0;
	freq = .1;
	contrast = 14.0;
	aspectratio = 1.0;
	gabortex = CreateProceduralSineGrating(ptr, tw, th);
	
	Screen('glPoint', ptr, [255,255,255,128], 50, 50, 100);
	Screen('Flip', ptr);
	Screen('Flip', ptr,GetSecs+2);
	ts=Screen('Flip', ptr);
	
	count=1;
	
	while count
		x1=round(abs(sin(count/100)*rect(3)));
		x2=round(abs(sin(count/100)*(rect(3)/2)));
		y1=round(abs(sin(count/100)*rect(4)));
		y2=round(abs(sin(count/1000)*rect(4)));
		
		contrast=abs(sin(count/10)*100);
		
		Screen('DrawDots',ptr,pos,32,col,[],1)
		Screen('gluDisk', ptr, [255,255,255,128]', x1, y1, 50);
		Screen('glPoint', ptr, [255,255,255,128]', x2, y2, 100);
		Screen('DrawTexture', ptr, gabortex, [], [x1 y1 x1+300 y1+300], [], [], [], [], [], 0, [phase, freq/2, sc, contrast, aspectratio, 0, 0, 0]);
		Screen('DrawTexture', ptr, gabortex, [], [x2 y2 x2+100 y2+100], [], [], [], [], [], 0, [phase, freq/8, sc, contrast, aspectratio, 0, 0, 0]);

		Screen('DrawingFinished', ptr);
		
		if benchmark > 0
			% Go as fast as you can without any sync to retrace and without
			% clearing the backbuffer -- we want to measure gabor drawing speed,
			% not how fast the display is going etc.
			Screen('Flip', ptr, 0, 2, 2);
		else
			% Go at normal refresh rate for good looking gabors:
			Screen('Flip', ptr);
	
		end
		pos = round((pos+(randseed+rand(2,nobjs)-0.5)*sin(count/10)*20));
		phase = phase+10;
		if KbCheck
            break;
		end
		count=count+1;
	end
	tend = Screen('Flip', ptr);
	Screen('Flip', ptr,GetSecs+2);

	% Done. Print some fps stats:
	avgfps = count / (tend - ts);
	fprintf('\n\nThe average framerate was %f frames per second.\n\n', avgfps);
	
	% Close window, release all ressources:
	Screen('CloseAll');

	% Restore old settings for sync-tests:
	Screen('Preference', 'SkipSyncTests', oldSyncLevel);
	Screen('Preference', 'VisualDebugLevel', oldLevel);
catch ME
	% Close window, release all ressources:
	disp('Error!');
	lasterror;
	Screen('CloseAll');
	% Restore old settings for sync-tests:
	Screen('Preference', 'SkipSyncTests', oldSyncLevel);
	Screen('Preference', 'VisualDebugLevel', oldLevel);
end
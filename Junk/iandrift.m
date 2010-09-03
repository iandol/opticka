function iandrift

movieDurationSecs=2;
waitTime=0.5;
angle=ang2rad(45);
angle2=angle+ang2rad(90);

trials=1;

size=400;

maskStimuli=0;
gaus=size/4;

sf1=0.01;
sf2=0.01;

angles=[0 45 90 135 180 225 270];
randindex=randperm(length(angles));

try
	% This script calls Psychtoolbox commands available only in OpenGL-based 
	% versions of the Psychtoolbox. (So far, the OS X Psychtoolbox is the
	% only OpenGL-base Psychtoolbox.)  The Psychtoolbox command AssertPsychOpenGL will issue
	% an error message if someone tries to execute this script on a computer without
	% an OpenGL Psychtoolbox
	AssertOpenGL;
	Screen('Preference', 'SkipSyncTests', 2);
	Screen('Preference', 'VisualDebugLevel', 2);
	
	% Get the list of screens and choose the one with the highest screen number.
	% Screen 0 is, by definition, the display with the menu bar. Often when 
	% two monitors are connected the one without the menu bar is used as 
	% the stimulus display.  Chosing the display with the highest dislay number is 
	% a best guess about where you want the stimulus displayed.  
	screens=Screen('Screens');
	screenNumber=max(screens);
	
    % Find the color values which correspond to white and black.  Though on OS
	% X we currently only support true color and thus, for scalar color
	% arguments,
	% black is always 0 and white 255, this rule is not true on other platforms will
	% not remain true on OS X after we add other color depth modes.  
	white=WhiteIndex(screenNumber);
	black=BlackIndex(screenNumber);
	gray=(white+black)/2;
	if round(gray)==white
		gray=black;
	end
	inc=white-gray;
	
	% Open a double buffered fullscreen window and draw a gray background 
	% to front and back buffers:
	w=Screen('OpenWindow',screenNumber, 0,[],[],2,[],1);
	Screen('FillRect',w, gray);
	Screen('Flip', w);
	Screen('FillRect',w, gray);
    
	% compute each frame of the movie and convert the those frames, stored in
	% MATLAB matices, into Psychtoolbox OpenGL textures using 'MakeTexture';
	numFrames=24; % temporal period, in frames, of the drifting grating

	timestamp=GetSecs;
	for i=1:numFrames
		phase=(i/numFrames)*2*pi;
		% grating
		[x,y]=meshgrid(-size:size,-size:size);
		f1=sf1*2*pi; % cycles/pixel
		f2=sf2*2*pi; % cycles/pixel
		a=cos(angle)*f1;
		b=sin(angle)*f1;
		c=cos(angle2)*f2;
		d=sin(angle2)*f2;
		
		m=sin(a*x+b*y+phase);
		n=sin(c*x+d*y+phase);
		
		%n=n/4;
		
		o=(m+n);
		
		o=o/4;
		
		if maskStimuli==1
			o=exp(-((x/gaus).^2)-((y/gaus).^2)).*o;
		end
		
		tex(i)=Screen('MakeTexture', w, gray+inc*o);
	end
	timestamp=GetSecs-timestamp
	
	% Run the movie animation for a fixed period.  
	frameRate=Screen('FrameRate',screenNumber);
	if(frameRate==0)  %if MacOSX does not know the frame rate the 'FrameRate' will return 0. 
	  frameRate=60;
	end

	movieDurationFrames=round(movieDurationSecs * frameRate);
	movieFrameIndices=mod(0:(movieDurationFrames-1), numFrames) + 1;
	priorityLevel=MaxPriority(w);
	Priority(priorityLevel);

	a=1;
	ftimes=zeros(movieDurationFrames*length(angles),1);
	
	for k=1:trials
		for j=1:length(angles)
			for i=1:movieDurationFrames
				%tic
				%timestamp=GetSecs;
				Screen('DrawTexture', w, tex(movieFrameIndices(i)),[],[],angles(randindex(j)));
				Screen('Flip', w);
				%ftimes(a)=GetSecs-timestamp;
				%ftimes(a)=toc;
				a=a+1;
			end
			Screen('FillRect',w, gray);
			Screen('Flip', w);
			WaitSecs(waitTime);
		end
		WaitSecs(waitTime);
	end
	 
	Screen('FillRect',w, gray);
	Screen('Flip', w);
	WaitSecs(1);

   Priority(0);
	
	%The same commands wich close onscreen and offscreen windows also close
	%textures.
	Screen('Close');
	Screen('CloseAll');

catch
	%this "catch" section executes in case of an error in the "try" section
	%above.  Importantly, it closes the onscreen window if its open.
	Priority(0);
	Screen('CloseAll');
	psychrethrow(psychlasterror);
end %try..catch..

% clear tex;
% figure;
% subplot(211)
% plot(ftimes,'ko');
% subplot(212)
% hist(ftimes,0.016:0.0001:0.019)
% [m,e]=stderr(ftimes);
% title(['Mean: ' num2str(m) '+-' num2str(e)])




    





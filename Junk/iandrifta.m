function iandrift
% DriftDemo
% ___________________________________________________________________
%
% Display an animated grating using the new Screen('DrawTexture') command.
% In the OS X Psychtoolbox Screen('DrawTexture') replaces
% Screen('CopyWindow').     
%
% CopyWindow vs. DrawTexture:
%
% In the OS 9 Psychtoolbox, Screen ('CopyWindow") was used for all
% time-critical display of images, in particular for display of the movie
% frames in animated stimuli. In contrast, Screen('DrawTexture') should not
% be used for display of all graphic elements,  but only for  display of
% MATLAB matrices.  For all other graphical elements, such as lines,  rectangles,
% and ovals we recommend that these be drawn directly to the  display
% window during the animation rather than rendered to offscreen  windows
% prior to the animation.
% _________________________________________________________________________
% 
% see also: PsychDemos, MovieDemo

% HISTORY
%  6/28/04    awi     Adapted from Denis Pelli's DriftDemo.m for OS 9 
%  7/18/04    awi     Added Priority call.  Fixed.
%  9/8/04     awi     Added Try/Catch, cosmetic changes to comments and see also.
%  4/23/05    mk      Added Priority(0) in catch section, moved Screen('OpenWindow')
%                     before first call to Screen('MakeTexture') in
%                     preparation of future improvements to 'MakeTexture'.

if (~isempty(daqfind))
    stop(daqfind)
end

%analog input
ai = analoginput('nidaq','Dev1');
set(ai,'InputType','SingleEnded');
set(ai,'TriggerType','Manual');
set(ai,'SampleRate',2000);
ActualRate = get(ai,'SampleRate');
set(ai,'SamplesPerTrigger',inf);
chans = addchannel(ai,0:1);

%digital input/output
dio = digitalio('nidaq','Dev1');
out=daqhwinfo(dio)
out.Port
addline(dio,0:7,'out');
dio.Line(1).LineName = 'TrigLine';
putvalue(dio,[0 0 0 0 0 0 0 0]);

movieDurationSecs=2;
waitTime=0.5;
angle=ang2rad(0);
angle2=ang2rad(angle+90);

size=400;

maskStimuli=1;
gaus=size/4;

sf=0.01;

angles=[0 45 90 135 180 225 270];
randindex=randperm(length(angles));

try
	% This script calls Psychtoolbox commands available only in OpenGL-based 
	% versions of the Psychtoolbox. (So far, the OS X Psychtoolbox is the
	% only OpenGL-base Psychtoolbox.)  The Psychtoolbox command AssertPsychOpenGL will issue
	% an error message if someone tries to execute this script on a computer without
	% an OpenGL Psychtoolbox
	AssertOpenGL;
	
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
	w=Screen('OpenWindow',screenNumber, 0,[],32,2);
	Screen('FillRect',w, gray);
	Screen('Flip', w);
	%Screen('FillRect',w, gray);
    
	% compute each frame of the movie and convert the those frames, stored in
	% MATLAB matices, into Psychtoolbox OpenGL textures using 'MakeTexture';
	numFrames=60; % temporal period, in frames, of the drifting grating

	timestamp=GetSecs;
	for i=1:numFrames
		phase=(i/numFrames)*2*pi;
		% grating
		[x,y]=meshgrid(-size:size,-size:size);
		f=sf*2*pi; % cycles/pixel
		a=cos(angle)*f;
		b=sin(angle)*f;
		c=cos(angle2)*f;
		d=sin(angle2)*f;
		
		m=sin(a*x+b*y+phase);
		n=sin(c*x+d*y+phase);
		
		o=(m+n);
		
		o=o/2;
		
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
	
	start(ai);

   movieDurationFrames=round(movieDurationSecs * frameRate);
	movieFrameIndices=mod(0:(movieDurationFrames-1), numFrames) + 1;
	priorityLevel=MaxPriority(w);
	Priority(priorityLevel);

	a=1;
	ftimes=zeros(movieDurationFrames*length(angles),1);
	
	trigger(ai)
	for j=1:length(angles)
		timestamp=GetSecs;
		putvalue(dio.Line(1),1);
		for i=1:movieDurationFrames
			Screen('DrawTexture', w, tex(movieFrameIndices(i)),[],[],angles(randindex(j)));
			Screen('Flip', w);
			ftimes(i)=GetSecs-timestamp;
			timestamp=GetSecs;
		end
		Screen('FillRect',w, gray);
		Screen('Flip', w);
		putvalue(dio.Line(1),0);
		WaitSecs(waitTime);
	end
	
	Screen('FillRect',w, gray);
	Screen('Flip', w);
	stop(ai);
	WaitSecs(2);

   Priority(0);
	
	%The same commands wich close onscreen and offscreen windows also close
	%textures.
	Screen('Close');
	Screen('CloseAll');

catch
	%this "catch" section executes in case of an error in the "try" section
	%above.  Importantly, it closes the onscreen window if its open.
	stop(ai);
	delete(ai);
	clear ai;

	putvalue(dio,[0 0 0 0 0 0 0 0]);
	delete(dio);
	clear dio;
	Priority(0);
	Screen('CloseAll');
	psychrethrow(psychlasterror);
end %try..catch..

stop(ai);
ai;
[data,time]=getdata(ai,ai.SamplesAvailable);

clear tex;
figure;
subplot(311)
plot(ftimes,'ko');
subplot(312)
histfit(ftimes)
[m,e]=stderr(ftimes);
title(['Mean: ' num2str(m) '+-' num2str(e)])
subplot(313)
plot(time,data);
axis tight

delete(ai);
clear ai;

putvalue(dio,[0 0 0 0 0 0 0 0]);
delete(dio);
clear dio;




    





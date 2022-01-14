% ========================================================================
%> @brief plaidStimulus TODO
%>
%> 
%>
%> Copyright ©2014-2022 Ian Max Andolina — released: LGPL3, see LICENCE.md
% ========================================================================
classdef plaidStimulus < baseStimulus
   properties
		sf1=0.01
		sf2=0.01
		tf1=0.01
		tf2=0.01
		procedural='yes'
	end
	properties (SetAccess = private, GetAccess = private)
		display
		white
		black
		gray
		inc
	end
   methods
		function obj = plaidStimulus(args)
			obj=obj@baseStimulus(args); %we call the superclass constructor first
			if ~strcmp(obj.family,'plaid')
				error('Sorry, you are trying to call a plaidStimulus with a family other than plaid');
			end
			if nargin>0 && isstruct(args)
				if isfield(args,'sf1');obj.sf1=args.sf1;end
				if isfield(args,'tf1');obj.tf1=args.tf1;end
				if isfield(args,'sf2');obj.sf2=args.sf2;end
				if isfield(args,'tf2');obj.tf=args.tf2;end
			end
		end
		function getColors(obj)
				obj.white=WhiteIndex(screenNumber);
				obj.black=BlackIndex(screenNumber);
				obj.gray=(obj.white+obj.black)/2;
				if round(obj.gray)==obj.white
					obj.gray=obj.black;
				end
				obj.inc=obj.white-obj.gray;
		end
		function setup(obj)
			try
				AssertOpenGL;
				Screen('Preference', 'SkipSyncTests', 2);
				Screen('Preference', 'VisualDebugLevel', 2);

				screens=Screen('Screens');
				screenNumber=max(screens);

				% Open a double buffered fullscreen window and draw a gray background 
				% to front and back buffers:
				w=Screen('OpenWindow',screenNumber, 0,[0 0 600 600],[],2,[],1);
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
		end
	end
	methods (Access = private)
			function construct(obj)
				
			end
	end
end
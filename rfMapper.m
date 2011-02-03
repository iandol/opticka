% ========================================================================
%> @brief single bar stimulus, inherits from baseStimulus
%> SPOTSTIMULUS single bar stimulus, inherits from baseStimulus
%>   The current properties are:
% ========================================================================
classdef rfMapper < barStimulus

	properties %--------------------PUBLIC PROPERTIES----------%
	   %> normally should be left at 1 (1 is added to this number so doublebuffering is enabled)
		doubleBuffer = 1 
		%> multisampling sent to the graphics card, try values []=disabled, 4, 8 and 16
		antiAlias = 4
		%> background of display during stimulus presentation
		backgroundColour = [0.5 0.5 0.5 0] 
		%> use OpenGL blending mode 1 = yes | 0 = no
		blend = 0 
		%> GL_ONE %src mode
		srcMode = 'GL_ONE' 
		%> GL_ONE % dst mode
		dstMode = 'GL_ZERO' 
	end
	
	properties (SetAccess = private, GetAccess = public)
		winRect
		buttons
		rchar
	end
	
	properties (SetAccess = private, GetAccess = private)
		allowedProperties='^(type|screen)$'
	end
	
	%=======================================================================
	methods %------------------PUBLIC METHODS
	%=======================================================================
		
		% ===================================================================
		%> @brief Class constructor
		%>
		%> More detailed description of what the constructor does.
		%>
		%> @param args are passed as a structure of properties which is
		%> parsed.
		%> @return instance of the class.
		% ===================================================================
		function obj = rfMapper(args) 
			%Initialise for superclass, stops a noargs error
			if nargin == 0
				args.family = 'rfmapper';
			end
			obj=obj@barStimulus(args); %we call the superclass constructor first
			if nargin>0 && isstruct(args)
				fnames = fieldnames(args); %find our argument names
				for i=1:length(fnames);
					if regexp(fnames{i},obj.allowedProperties) %only set if allowed property
						obj.salutation(fnames{i},'Configuring setting in rfMapper constructor');
						obj.(fnames{i})=args.(fnames{i}); %we set up the properies from the arguments as a structure
					end
				end
			end
			obj.verbose = 1;
			obj.family = 'rfmapper';
			obj.salutation('constructor','rfMapper initialisation complete');
		end
		
		
		function run(obj,rE)
			try
				Screen('Preference', 'SkipSyncTests', 2);
				Screen('Preference', 'VisualDebugLevel', 0);
				Screen('Preference', 'Verbosity', 2); 
				Screen('Preference', 'SuppressAllWarnings', 0);
				PsychImaging('PrepareConfiguration');
				PsychImaging('AddTask', 'General', 'FloatingPoint32BitIfPossible');
				PsychImaging('AddTask', 'General', 'NormalizedHighresColorRange');
				[obj.win, obj.winRect] = PsychImaging('OpenWindow', obj.screen, obj.backgroundColour,[1 1 800 600], [], obj.doubleBuffer+1,[],obj.antiAlias);
				
				obj.constructMatrix(rE.ppd);
				obj.setup(rE);
				AssertGLSL;
				
				% Enable alpha blending.
				if obj.blend==1
					Screen('BlendFunction', obj.win, obj.srcMode, obj.dstMode);
				end
				
				[obj.xCenter, obj.yCenter] = RectCenter(obj.winRect);
				Priority(MaxPriority(obj.win)); %bump our priority to maximum allowed
				
				obj.dstRect=Screen('Rect',obj.texture);
				obj.buttons = [0 0 0]; % When the user clicks the mouse, 'buttons' becomes nonzero.
				mX = 0; % The x-coordinate of the mouse cursor
				mY = 0; % The y-coordinate of the mouse cursor
				obj.rchar='nan';
				FlushEvents;
				ListenChar(2);
				
				while ~strcmpi(obj.rchar,'escape')
					[mX, mY, obj.buttons] = GetMouse;
					obj.dstRect=CenterRectOnPoint(obj.dstRect,mX,mY);
					[keyIsDown, ~, keyCode] = KbCheck;
					if keyIsDown == 1
						obj.rchar = KbName(keyCode);
					end
					flushevents('keyDown');

					% We need to redraw the text or else it will disappear after a
					% subsequent call to Screen('Flip').
					t=sprintf('Buttons: %d\t',obj.buttons);
					if ischar(obj.rchar);t=[t sprintf('| Char: %s',obj.rchar)];end
					Screen('DrawText', obj.win, t, 0, 0, [0 0 0]);

					% Draw the sprite at the new location.
					Screen('DrawTexture', obj.win, obj.texture, [], pbj.dstRect);
					
					Screen('DrawingFinished', obj.win); % Tell PTB that no further drawing commands will follow before Screen('Flip')
					
					% Call Screen('Flip') to update the screen.  Note that calling
					% 'Flip' after we have both erased and redrawn the sprite prevents
					% the sprite from flickering.
					Screen('Flip', obj.win);
				end
				
				obj.win=[];
				Priority(0);
				ListenChar(0)
				ShowCursor; 
				Screen('CloseAll');
				
			catch
				obj.win=[];
				Priority(0);
				ListenChar(0)
				% If there is an error in our try block, let's
				% return the user to the familiar MATLAB prompt.
				ShowCursor; 
				Screen('CloseAll');
				psychrethrow(psychlasterror);
			end
		end
	end
	
	%=======================================================================
	methods ( Access = private ) %-------PRIVATE METHODS-----%
	%=======================================================================
		% ===================================================================
		%> @brief setRect
		%>  setRect makes the PsychRect based on the texture and screen values
		% ===================================================================
		function setRect(obj)
			if isempty(obj.findprop('angleOut'));
				[dx dy]=pol2cart(obj.d2r(obj.angle),obj.startPosition);
			else
				[dx dy]=pol2cart(obj.d2r(obj.angleOut),obj.startPosition);
			end
			obj.dstRect=Screen('Rect',obj.texture);
			obj.dstRect=CenterRectOnPoint(obj.dstRect,obj.xCenter,obj.yCenter);
			if isempty(obj.findprop('xPositionOut'));
				obj.dstRect=OffsetRect(obj.dstRect,obj.xPosition*obj.ppd,obj.yPosition*obj.ppd);
			else
				obj.dstRect=OffsetRect(obj.dstRect,obj.xPositionOut+(dx*obj.ppd),obj.yPositionOut+(dy*obj.ppd));
			end
			obj.mvRect=obj.dstRect;
		end
	end
end
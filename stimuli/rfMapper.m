% ========================================================================
%> @brief receptive field mapper
%> rfMapper is a mouse driven receptive field mapper, using various keyboard
%> commands to change the stimulus and and ability to record where the mouse is
%> (i.e. draw) in screen co-ordinates to save as a hand map image for storage. It is
%> based on barStimulus, and you can change length + width (h, j, l & k on keyboard) and texture of the
%> bar (space), and angle (arrow keys), and colour of the bar and background
%> (numeric keys). Right/middle mouse draws the current position into a buffer, you can turn on and off 
%> visualising drawing buffer with ; and use ' to reset the drawn positions. See the
%> checkKeys method for better description of what the keyboard commands do.
% ========================================================================
classdef rfMapper < barStimulus
	
	properties %--------------------PUBLIC PROPERTIES----------%
		%> normally should be left at 1 (1 is added to this number so doublebuffering is enabled)
		doubleBuffer = 1
		%> multisampling sent to the graphics card, try values []=disabled, 4, 8 and 16
		antiAlias = []
		%> use OpenGL blending mode 1 = yes | 0 = no
		blend = true
		%> GL_ONE %src mode
		srcMode = 'GL_SRC_ALPHA'
		%> GL_ONE % dst mode
		dstMode = 'GL_ONE_MINUS_SRC_ALPHA'
	end
	
	properties (SetAccess = private, GetAccess = public)
		winRect = []
		buttons = []
		rchar = ''
		xClick = 0
		yClick = 0
		xyDots = [0;0]
		showClicks = 0
		stimulus = 'bar'
        tf = 0
		phase = 0
		backgroundColour = [0 0 0 0];
	end
	
	properties (SetAccess = private, GetAccess = private)
		fhandle
		dStartTick = 1
		dEndTick = 1
		gratingTexture
		colourIndex = 1
		bgcolourIndex = 2
		colourList = {[1 1 1];[0 0 0];[1 0 0];[0 1 0];[0 0 1];[1 1 0];[1 0 1];[0 1 1];[.5 .5 .5]}
		textureIndex = 1
		textureList = {'simple','checkerboard','random','randomColour','randomN','randomBW'};
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
		function obj = rfMapper(varargin)
			%Initialise for superclass, stops a noargs error
			if nargin == 0
				varargin.family = 'rfMapper';
			end
			
			obj=obj@barStimulus(varargin); %we call the superclass constructor first
			
			if nargin>0
				obj.parseArgs(varargin, obj.allowedProperties);
			end
			
			obj.backgroundColour = [0 0 0 0];
			obj.family = 'rfMapper';
			obj.salutation('constructor','rfMapper initialisation complete');
		end
		
		% ===================================================================
		%> @brief
		%>
		% ===================================================================
		function run(obj,rE)
			if exist('rE','var') 
				if isa(rE,'runExperiment')
					obj.sM = rE.screen;
				elseif isa(rE,'screenManager')
					obj.sM = rE;
				end
			end
			
			%obj.sM.windowed = [];
			
			try
				obj.sM.debug = true;
				
				open(obj.sM);
				
				obj.setup(obj.sM);
				
				secondaryFigure(obj);
				
				obj.buttons = [0 0 0]; % When the user clicks the mouse, 'buttons' becomes nonzero.
				mX = 0; % The x-coordinate of the mouse cursor
				mY = 0; % The y-coordinate of the mouse cursor
				xOut = 0;
				yOut = 0;
				obj.rchar='';
				Priority(MaxPriority(obj.sM.win)); %bump our priority to maximum allowed
				FlushEvents;
				HideCursor;
				%ListenChar(-1);
				obj.tick = 1;
				Finc = 6;
				keyHold = 1;
				
				vbl = Screen('Flip', obj.sM.win);
				
				while isempty(regexpi(obj.rchar,'^esc'))
					
					%draw background
					Screen('FillRect',obj.sM.win,obj.backgroundColour,[]);
					
					%draw text
					t=sprintf('X = %2.3g | Y = %2.3g ',xOut,yOut);
					if ischar(obj.rchar); t=[t sprintf('| Char: %s ',obj.rchar)]; end
					t=[t sprintf('| Scale = %2.2g ',obj.scale)];
					t=[t sprintf('| Texture = %g',obj.textureIndex)];
                    t=[t sprintf('Buttons: %i\t',obj.buttons)];
					Screen('DrawText', obj.sM.win, t, 5, 5, [1 1 0]);
					
					%draw central spot
					sColour = obj.backgroundColour./2;
					if max(sColour)==0;sColour=[0.5 0.5 0.5 1];end
					
					%draw clicked points
					if obj.showClicks == 1
						obj.xyDots = vertcat((obj.xClick.*obj.ppd),(obj.yClick*obj.ppd));
						Screen('DrawDots',obj.sM.win,obj.xyDots,2,sColour,[obj.sM.xCenter obj.sM.yCenter],1);
					end
					
					% Draw at the new location.
					if obj.isVisible == true
						switch obj.stimulus
							case 'bar'
								Screen('DrawTexture', obj.sM.win, obj.texture, [], obj.dstRect, obj.angleOut,[],obj.alpha);
							case 'grating'

						end
					end
					
					sM.drawCross();
					
					Screen('DrawingFinished', obj.sM.win); % Tell PTB that no further drawing commands will follow before Screen('Flip')
					
					[mX, mY, obj.buttons] = GetMouse(obj.sM.screen);
					xOut = (mX - obj.sM.xCenter)/obj.ppd;
					yOut = (mY - obj.sM.yCenter)/obj.ppd;
					if obj.buttons(2) == 1
						obj.xClick = [obj.xClick xOut];
						obj.yClick = [obj.yClick yOut];
						obj.dStartTick = obj.dEndTick;
						obj.dEndTick = length(obj.xClick);
						updateFigure(obj);
					end
					
					checkKeys(obj,mX,mY,keyHold,Finc);
					
					obj.dstRect=CenterRectOnPointd(obj.dstRect,mX,mY);
					
					FlushEvents('keyDown');
					
					vbl = Screen('Flip', obj.sM.win, vbl + obj.sM.screenVals.halfisi);
					
					obj.tick = obj.tick + 1;
				end
				
				close(obj.sM);
				Priority(0);
				ListenChar(0)
				ShowCursor;
				sca;
				if ~isempty(obj.xClick)
					obj.drawMap;
				end
				
			catch ME
				close(obj.sM)
				Priority(0);
				ListenChar(0);
				ShowCursor;
				sca;
				%psychrethrow(psychlasterror);
				rethrow(ME);
			end
		end
		
		% ===================================================================
		%> @brief
		%>
		%> @param
		%> @return
		% ===================================================================
		function set.colourIndex(obj,value)
			obj.colourIndex = value;
			if obj.colourIndex > length(obj.colourList) %#ok<*MCSUP>
				obj.colourIndex = 1;
			end
		end
		
		% ===================================================================
		%> @brief
		%>
		%> @param
		%> @return
		% ===================================================================
		function set.bgcolourIndex(obj,value)
			obj.bgcolourIndex = value;
			if obj.bgcolourIndex > length(obj.colourList)
				obj.bgcolourIndex = 1;
			end
		end
		
		% ===================================================================
		%> @brief
		%>
		%> @param
		%> @return
		% ===================================================================
		function set.textureIndex(obj,value)
			obj.textureIndex = value;
			if obj.textureIndex > length(obj.textureList)
				obj.textureIndex = 1;
			end
		end
		
		% ===================================================================
		%> @brief
		%>
		%> @param
		%> @return
		% ===================================================================
		function drawMap(obj)
			try
				%obj.xClick = unique(obj.xClick);
				%obj.yClick = unique(obj.yClick);
				obj.fhandle = figure;
				plot(obj.xClick,obj.yClick,'k.-.')
				xax = obj.sM.winRect(3)/obj.ppd;
				xax = xax - (xax/2);
				yax = obj.sM.winRect(4)/obj.ppd;
				yax = yax - (yax/2);
				axis([-xax xax -yax yax]);
				title('Marked Positions during RF Mapping')
				xlabel('X Position (degs)')
				ylabel('Y Position (degs)');
			catch ME
				rethrow ME
			end
		end
		
		% ===================================================================
		%> @brief
		%>
		%> @param
		%> @return
		% ===================================================================
		function updateFigure(obj)
			plot(obj.xClick(obj.dStartTick:end), obj.yClick(obj.dStartTick:end), 'r-o');
		end
		
		% ===================================================================
		%> @brief
		%>
		%> @param
		%> @return
		% ===================================================================
		function secondaryFigure(obj)
			obj.fhandle = figure;
			xax = obj.sM.winRect(3)/obj.ppd;
			xax = xax - (xax/2);
			yax = obj.sM.winRect(4)/obj.ppd;
			yax = yax - (yax/2);
			axis([-xax xax -yax yax]);
			title('Marked Positions during RF Mapping')
			xlabel('X Position (degs)')
			ylabel('Y Position (degs)')
			box on
			hold on
		end
		
		% ===================================================================
		%> @brief
		%>
		%> @param
		%> @return
		% ===================================================================
		function keyHold = checkKeys(obj,mX,mY,keyHold,Finc)
			[keyIsDown, ~, keyCode] = KbCheck;
			if keyIsDown == 1
				obj.rchar = KbName(keyCode);
				if iscell(obj.rchar);obj.rchar=obj.rchar{1};end
				switch obj.rchar
					case 'l' %increase length
						switch obj.stimulus
							case 'bar'
								obj.dstRect=ScaleRect(obj.dstRect,1,1.05);
								obj.dstRect=CenterRectOnPointd(obj.dstRect,mX,mY);
						end
					case 'k' %decrease length
						switch obj.stimulus
							case 'bar'
								obj.dstRect=ScaleRect(obj.dstRect,1,0.95);
								obj.dstRect=CenterRectOnPointd(obj.dstRect,mX,mY);
						end
					case 'j' %increase width
						switch obj.stimulus
							case 'bar'
								obj.dstRect=ScaleRect(obj.dstRect,1.05,1);
								obj.dstRect=CenterRectOnPointd(obj.dstRect,mX,mY);
						end
					case 'h' %decrease width
						switch obj.stimulus
							case 'bar'
								obj.dstRect=ScaleRect(obj.dstRect,0.95,1);
								obj.dstRect=CenterRectOnPointd(obj.dstRect,mX,mY);
						end
					case 'm' %increase size
						switch obj.stimulus
							case 'bar'
								[w,h]=RectSize(obj.dstRect);
								if w ~= h
									m = max(w,h);
									obj.dstRect = SetRect(0,0,m,m);

								end
								obj.dstRect=ScaleRect(obj.dstRect,1.05,1.05);
								obj.dstRect=CenterRectOnPointd(obj.dstRect,mX,mY);
						end
					case 'n' %decrease size
						switch obj.stimulus
							case 'bar'
								[w,h]=RectSize(obj.dstRect);
								if w ~= h
									m = max(w,h);
									obj.dstRect =  SetRect(0,0,m,m);
								end
								obj.dstRect=ScaleRect(obj.dstRect,0.95,0.95);
								obj.dstRect=CenterRectOnPointd(obj.dstRect,mX,mY);
						end
					case 's'
						switch obj.stimulus
							case 'bar'
								%obj.stimulus = 'grating';
							case 'grating'
								%obj.stimulus = 'bar';
						end
					case 'x'
						if obj.tick > keyHold
							if obj.isVisible == true
								obj.hide;
							else
								obj.show;
							end
							keyHold = obj.tick + Finc;
						end
					case {'LeftArrow','left'}
						obj.angleOut = obj.angleOut-3;
					case {'RightArrow','right'}
						obj.angleOut = obj.angleOut+3;
					case {'UpArrow','up'}
						obj.alpha = obj.alpha * 1.1;
						if obj.alpha > 1;obj.alpha = 1;end
					case {'DownArrow','down'}
						obj.alpha = obj.alpha * 0.9;
						if obj.alpha < 0;obj.alpha = 0;end
					case ',<'
						if max(obj.backgroundColour)>0.1
							obj.backgroundColour = obj.backgroundColour .* 0.9;
							obj.backgroundColour(obj.backgroundColour<0) = 0;
						end
					case '.>'
						obj.backgroundColour = obj.backgroundColour .* 1.1;
						obj.backgroundColour(obj.backgroundColour>1) = 1;
					case 'r'
						if obj.tick > keyHold
							obj.backgroundColour(1) = obj.backgroundColour(1) + 0.01;
							if obj.backgroundColour(1) > 1
								obj.backgroundColour(1) = 0;
							end
							keyHold = obj.tick + Finc;
						end

					case 'g'
						if obj.tick > keyHold
						obj.backgroundColour(2) = obj.backgroundColour(2) + 0.01;
						if obj.backgroundColour(2) > 1
							obj.backgroundColour(2) = 0;
						end
						keyHold = obj.tick + Finc;
						end
					case 'b'
						if obj.tick > keyHold
						obj.backgroundColour(3) = obj.backgroundColour(3) + 0.01;
						if obj.backgroundColour(3) > 1
							obj.backgroundColour(3) = 0;
						end
						keyHold = obj.tick + Finc;
						end
					case 'e'
						if obj.tick > keyHold
						obj.backgroundColour(1) = obj.backgroundColour(1) - 0.01;
						if obj.backgroundColour(1) < 0.01
							obj.backgroundColour(1) = 1;
						end
						keyHold = obj.tick + Finc;
						end
					case 'f'
						if obj.tick > keyHold
						obj.backgroundColour(2) = obj.backgroundColour(2) - 0.01;
						if obj.backgroundColour(2) < 0.01
							obj.backgroundColour(2) = 1;
						end
						keyHold = obj.tick + Finc;
						end
					case 'v'
						if obj.tick > keyHold
						obj.backgroundColour(3) = obj.backgroundColour(3) - 0.01;
						if obj.backgroundColour(3) < 0.01
							obj.backgroundColour(3) = 1;
						end
						keyHold = obj.tick + Finc;
						end
					case '1!'
						if obj.tick > keyHold
						obj.colourIndex = obj.colourIndex+1;
						obj.setColours;
						obj.regenerate;
						keyHold = obj.tick + Finc;
						end
					case '2@'
						if obj.tick > keyHold
						obj.bgcolourIndex = obj.bgcolourIndex+1;
						obj.setColours;
						WaitSecs(0.05);
						obj.regenerate;
						keyHold = obj.tick + Finc;
						end
					case '3#'
						if obj.tick > keyHold
						switch obj.stimulus
							case 'bar'
								obj.scale = obj.scale * 1.1;
								if obj.scale > 8;obj.scale = 8;end
						end
						keyHold = obj.tick + Finc;
						end
					case '4$'
						if obj.tick > keyHold
						switch obj.stimulus
							case 'bar'
								obj.scale = obj.scale * 0.9;
								if obj.scale <1;obj.scale = 1;end
						end
						keyHold = obj.tick + Finc;
						end
					case 'space'
						if obj.tick > keyHold
						switch obj.stimulus
							case 'bar'
								obj.textureIndex = obj.textureIndex + 1;
								obj.barWidth = obj.dstRect(3)/obj.ppd;
								obj.barHeight = obj.dstRect(4)/obj.ppd;
								obj.type = obj.textureList{obj.textureIndex};
								obj.regenerate;
							case 'grating'

						end
						keyHold = obj.tick + Finc;
						end
					case {';:',';'}
						if obj.tick > keyHold
						obj.showClicks = ~obj.showClicks;
						keyHold = obj.tick + Finc;
						end
					case {'''"',''''}
						obj.xClick = 0;
						obj.yClick = 0;
						obj.dStartTick = 1;
						obj.dEndTick = 1;
						obj.xyDots = vertcat((obj.xClick.*obj.ppd),(obj.yClick*obj.ppd));
				end
			end
		end
		
		
	end
	
	%=======================================================================
	methods ( Access = private ) %-------PRIVATE METHODS-----%
	%=======================================================================
		% ===================================================================
		%> @brief setColours
		%>  sets the colours based on the current index
		% ===================================================================
		function setColours(obj)
			obj.colour = obj.colourList{obj.colourIndex};
			obj.backgroundColour = obj.colourList{obj.bgcolourIndex};
		end
		
		% ===================================================================
		%> @brief regenerate
		%>  regenerates the texture
		% ===================================================================
		function regenerate(obj)
            obj.barWidthOut = obj.barWidth;
            obj.barHeightOut = obj.barHeight;
            obj.colourOut = obj.colour;
            obj.regenerateTexture = true;
            update(obj);
		end
	end
end

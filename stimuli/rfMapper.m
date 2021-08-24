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
		%> use eyetracking loop
		useEyetracker = false
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
		ax
		dStartTick = 1
		dEndTick = 1
		gratingTexture
		colourIndex = 1
		bgcolourIndex = 2
		stopTask = false
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
		function me = rfMapper(varargin)
			args = optickaCore.addDefaults(varargin,struct('name','rfMapper'));
			
			me=me@barStimulus(args); %we call the superclass constructor first
			
			me.backgroundColour = [0 0 0 0];
			me.family = 'rfMapper';
			me.salutation('constructor','rfMapper initialisation complete');
		end
		
		% ===================================================================
		%> @brief
		%>
		% ===================================================================
		function run(me,rE)
			if exist('rE','var') 
				if isa(rE,'runExperiment')
					me.sM = rE.screen;
				elseif isa(rE,'screenManager')
					me.sM = rE;
				end
			else
				
			end
			
			%me.sM.windowed = [];
			
			try
				me.sM.debug = true;
				
				oldbg = me.sM.backgroundColour;
				me.sM.backgroundColour = [0 0 0];
				
				open(me.sM);
				
				me.setup(me.sM);
				
				secondaryFigure(me);
				commandwindow;
				
				me.buttons = [0 0 0]; % When the user clicks the mouse, 'buttons' becomes nonzero.
				mX = 0; % The x-coordinate of the mouse cursor
				mY = 0; % The y-coordinate of the mouse cursor
				xOut = 0;
				yOut = 0;
				me.rchar='';
				Priority(MaxPriority(me.sM.win)); %bump our priority to maximum allowed
				FlushEvents;
				HideCursor;
				ListenChar(-1);
				me.tick = 1;
				Finc = 6;
				keyHold = 1;
				me.stopTask = false;
				
				vbl = Screen('Flip', me.sM.win);
				
				while ~me.stopTask
					
					%draw background
					Screen('FillRect',me.sM.win,me.backgroundColour,[]);
					
					%draw central spot
					sColour = me.backgroundColour./2;
					if max(sColour)==0;sColour=[0.5 0.5 0.5 1];end
					
					%draw clicked points
					if me.showClicks == 1
						me.xyDots = vertcat((me.xClick.*me.ppd),(me.yClick*me.ppd));
						Screen('DrawDots',me.sM.win,me.xyDots,2,sColour,[me.sM.xCenter me.sM.yCenter],1);
					end
					
					% Draw at the new location.
					if me.isVisible == true
						switch me.stimulus
							case 'bar'
								Screen('DrawTexture', me.sM.win, me.texture, [], me.dstRect, me.angleOut,[],me.alpha);
							case 'grating'

						end
					end
					
					%draw text
					width=abs(me.dstRect(1)-me.dstRect(3))/me.ppd;
					height=abs(me.dstRect(2)-me.dstRect(4))/me.ppd;
					t=sprintf('X = %2.3g | Y = %2.3g ',xOut,yOut);
					t=[t sprintf('| W = %.2f H = %.2f ',width,height)];
					t=[t sprintf('| Scale = %i ',me.scaleOut)];
					t=[t sprintf('| SF = %.2f ',me.sfOut)];
					t=[t sprintf('| Texture = %g',me.textureIndex)];
                    t=[t sprintf('| Buttons: %i\t',me.buttons)];
					if ischar(me.rchar); t=[t sprintf(' | Char: %s ',me.rchar)]; end
					Screen('DrawText', me.sM.win, t, 5, 5, [0.6 0.3 0]);
					
					%drawCross(me,size,colour,x,y,lineWidth,showDisk,alpha)
					me.sM.drawCross(0.75,[],[],[],[],[],0.5);
					
					Screen('DrawingFinished', me.sM.win); % Tell PTB that no further drawing commands will follow before Screen('Flip')
					
					animate(me);
					
					[mX, mY, me.buttons] = GetMouse(me.sM.screen);
					xOut = (mX - me.sM.xCenter)/me.ppd;
					yOut = (mY - me.sM.yCenter)/me.ppd;
					if me.buttons(2) == 1
						me.xClick = [me.xClick xOut];
						me.yClick = [me.yClick yOut];
						me.dStartTick = me.dEndTick;
						me.dEndTick = length(me.xClick);
						updateFigure(me);
					end
					
					checkKeys(me,mX,mY);
					
					me.dstRect=CenterRectOnPointd(me.dstRect,mX,mY);
					
					FlushEvents('keyDown');
					
					vbl = Screen('Flip', me.sM.win,[],[],1);
					
					me.tick = me.tick + 1;
				end
				
				close(me.sM);
				me.sM.backgroundColour = oldbg;
				Priority(0);
				ListenChar(0)
				ShowCursor;
				sca;
				if ~isempty(me.xClick) && length(me.xClick)>1
					me.drawMap; 
				end
				me.fhandle = [];
				me.ax = [];
				
			catch ME
				close(me.sM)
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
		function set.colourIndex(me,value)
			me.colourIndex = value;
			if me.colourIndex > length(me.colourList) %#ok<*MCSUP>
				me.colourIndex = 1;
			end
		end
		
		% ===================================================================
		%> @brief
		%>
		%> @param
		%> @return
		% ===================================================================
		function set.bgcolourIndex(me,value)
			me.bgcolourIndex = value;
			if me.bgcolourIndex > length(me.colourList)
				me.bgcolourIndex = 1;
			end
		end
		
		% ===================================================================
		%> @brief
		%>
		%> @param
		%> @return
		% ===================================================================
		function set.textureIndex(me,value)
			me.textureIndex = value;
			if me.textureIndex > length(me.textureList)
				me.textureIndex = 1;
			end
		end
		
		% ===================================================================
		%> @brief
		%>
		%> @param
		%> @return
		% ===================================================================
		function drawMap(me)
			try
				%me.xClick = unique(me.xClick);
				%me.yClick = unique(me.yClick);
				figure;
				plot(me.xClick,me.yClick,'k.-.')
				xax = me.sM.winRect(3)/me.ppd;
				xax = xax - (xax/2);
				yax = me.sM.winRect(4)/me.ppd;
				yax = yax - (yax/2);
				axis([-xax xax -yax yax]);
				set(gca,'YDir','reverse');
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
		function updateFigure(me,clear)
			if ~exist('clear','var');clear = false; end
			if ~ishandle(me.fhandle);return;end
			figure(me.fhandle);
			if clear
				plot(0,0);
			else
			plot(me.xClick(me.dStartTick:end), me.yClick(me.dStartTick:end), 'r-.');
			end
		end
		
		% ===================================================================
		%> @brief
		%>
		%> @param
		%> @return
		% ===================================================================
		function secondaryFigure(me)
			me.fhandle = figure;
			xax = me.sM.winRect(3)/me.ppd;
			xax = xax - (xax/2);
			yax = me.sM.winRect(4)/me.ppd;
			yax = yax - (yax/2);
			axis([-xax xax -yax yax]);
			set(gca,'YDir','reverse');
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
		function checkKeys(me,mX,mY)
			persistent keyTicks
			fInc = 4;
			if isempty(keyTicks);keyTicks = 0; end
			keyTicks = keyTicks + 1;
			[keyIsDown, ~, keyCode] = KbCheck;
			if keyIsDown == 1
				me.rchar = KbName(keyCode);
				if iscell(me.rchar);me.rchar=me.rchar{1};end
				switch me.rchar
					case 'q' %quit
						me.stopTask = true;
					case 'l' %increase length
						
							switch me.stimulus
								case 'bar'
									me.dstRect=ScaleRect(me.dstRect,1,1.05);
									me.dstRect=CenterRectOnPointd(me.dstRect,mX,mY);
							end
					
					case 'k' %decrease length
						switch me.stimulus
						case 'bar'
							me.dstRect=ScaleRect(me.dstRect,1,0.95);
							me.dstRect=CenterRectOnPointd(me.dstRect,mX,mY);
						end
					case 'j' %increase width
						switch me.stimulus
							case 'bar'
								me.dstRect=ScaleRect(me.dstRect,1.05,1);
								me.dstRect=CenterRectOnPointd(me.dstRect,mX,mY);
						end
					case 'h' %decrease width
						switch me.stimulus
						case 'bar'
							me.dstRect=ScaleRect(me.dstRect,0.95,1);
							me.dstRect=CenterRectOnPointd(me.dstRect,mX,mY);
						end
					case 'm' %increase size
						
						switch me.stimulus
						case 'bar'
							[w,h]=RectSize(me.dstRect);
							if w ~= h
								m = max(w,h);
								me.dstRect = SetRect(0,0,m,m);

							end
							me.dstRect=ScaleRect(me.dstRect,1.05,1.05);
							me.dstRect=CenterRectOnPointd(me.dstRect,mX,mY);
						end
						
					case 'n' %decrease size
						
						switch me.stimulus
						case 'bar'
							[w,h]=RectSize(me.dstRect);
							if w ~= h
								m = max(w,h);
								me.dstRect =  SetRect(0,0,m,m);
							end
							me.dstRect=ScaleRect(me.dstRect,0.95,0.95);
							me.dstRect=CenterRectOnPointd(me.dstRect,mX,mY);
						end
						
					case 's'
						if keyTicks > fInc
							keyTicks = 0;
							switch me.stimulus
							case 'bar'
								%me.stimulus = 'grating';
							case 'grating'
								%me.stimulus = 'bar';
							end
						end
					case 'x'
						if keyTicks > fInc
							keyTicks = 0;
							if me.isVisible == true
								me.hide;
							else
								me.show;
							end
						end
					case {'LeftArrow','left'}
						me.angleOut = me.angleOut - 3;
					case {'RightArrow','right'}
						me.angleOut = me.angleOut + 3;
					case {'UpArrow','up'}
						me.alphaOut = me.alphaOut + 0.05;
						if me.alphaOut > 1;me.alphaOut = 1;end
					case {'DownArrow','down'}
						me.alphaOut = me.alphaOut - 0.05;
						if me.alpha < 0;me.alpha = 0;end
					case ',<'
						if keyTicks > fInc
							keyTicks = 0;
							if max(me.backgroundColour)>0.1
								me.backgroundColour = me.backgroundColour .* 0.9;
								me.backgroundColour(me.backgroundColour<0) = 0;
							end
						end
					case '.>'
						if keyTicks > fInc
							keyTicks = 0;
							me.backgroundColour = me.backgroundColour .* 1.1;
							me.backgroundColour(me.backgroundColour>1) = 1;
						end
					case 'r'
						if keyTicks > fInc
							keyTicks = 0;
							me.backgroundColour(1) = me.backgroundColour(1) + 0.01;
							if me.backgroundColour(1) > 1
								me.backgroundColour(1) = 0;
							end
						end

					case 'g'
						if keyTicks > fInc
							keyTicks = 0;
							me.backgroundColour(2) = me.backgroundColour(2) + 0.01;
							if me.backgroundColour(2) > 1
								me.backgroundColour(2) = 0;
							end
						end
					case 'b'
						if keyTicks > fInc
							keyTicks = 0;
							me.backgroundColour(3) = me.backgroundColour(3) + 0.01;
							if me.backgroundColour(3) > 1
								me.backgroundColour(3) = 0;
							end
						end
					case 'e'
						if keyTicks > fInc
							keyTicks = 0;
							me.backgroundColour(1) = me.backgroundColour(1) - 0.01;
							if me.backgroundColour(1) < 0.01
								me.backgroundColour(1) = 1;
							end
						end
					case 'f'
						if keyTicks > fInc
							keyTicks = 0;
							me.backgroundColour(2) = me.backgroundColour(2) - 0.01;
							if me.backgroundColour(2) < 0.01
								me.backgroundColour(2) = 1;
							end
						end
					case 'v'
						if keyTicks > fInc
							me.backgroundColour(3) = me.backgroundColour(3) - 0.01;
							if me.backgroundColour(3) < 0.01
								me.backgroundColour(3) = 1;
							end
							keyTicks = 0;
						end
					case '1!'
						if keyTicks > fInc
							me.colourIndex = me.colourIndex+1;
							me.setColours;
							me.regenerate;
							keyTicks = 0;
						end
					case '2@'
						if keyTicks > fInc
							me.bgcolourIndex = me.bgcolourIndex+1;
							me.setColours;
							WaitSecs(0.05);
							me.regenerate;
							keyTicks = 0;
						end
					case '3#'
						if keyTicks > fInc
							ol = me.scaleOut;
							switch me.stimulus
								case 'bar'
									me.scaleOut = me.scaleOut - 1;
									if me.scaleOut < 1;me.scaleOut = 1;end
									nw = me.scaleOut;
							end
							if ol~=nw;me.regenerate;end
							keyTicks = 0;
						end
					case '4$'
						if keyTicks > fInc
							ol = me.scaleOut;
							switch me.stimulus
								case 'bar'
									me.scaleOut = me.scaleOut + 1;
									if me.scaleOut >50;me.scaleOut = 50;end
									nw = me.scaleOut;
							end
							if ol~=nw;me.regenerate;end
							keyTicks = 0;
						end
					case '5%'
							ol = me.sfOut;
							switch me.stimulus
								case 'bar'
									me.sfOut = me.sfOut + 0.1;
									if me.sfOut > 10;me.scaleOut = 10;end
							end
							nw = me.sfOut;
							if ol~=nw;me.regenerate;end
							
					case '6^'
							ol = me.sfOut;
							switch me.stimulus
								case 'bar'
									me.sfOut = me.sfOut -0.1;
									if me.sfOut <0.1;me.sfOut = 0.1;end
							end
							nw = me.sfOut;
							if ol~=nw;me.regenerate;end
					case '/?'
						if keyTicks > fInc
							switch me.stimulus
							case 'bar'
								if me.phaseReverseTime == 0
									me.phaseReverseTime = 0.2;
									me.phaseCounter = round( me.phaseReverseTime / me.sM.screenVals.ifi );
								else
									me.phaseReverseTime = 0;
								end
								me.regenerate;
							end
							keyTicks = 0;
						end
					case 'space'
						if keyTicks > fInc
							switch me.stimulus
							case 'bar'
								me.textureIndex = me.textureIndex + 1;
								%me.barWidth = me.dstRect(3)/me.ppd;
								%me.barHeight = me.dstRect(4)/me.ppd;
								me.type = me.textureList{me.textureIndex};
								me.regenerate;
							case 'grating'
							end
							keyTicks = 0;
						end
					case {';:',';'}
						if keyTicks > fInc
							me.showClicks = ~me.showClicks;
							keyTicks = 0;
						end
					case {'''"',''''}
						if keyTicks > fInc
							figure(me.fhandle);
							cla;
							me.xClick = 0;
							me.yClick = 0;
							me.dStartTick = 1;
							me.dEndTick = 1;
							me.xyDots = vertcat((me.xClick.*me.ppd),(me.yClick*me.ppd));
							keyTicks = 0;
						end
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
		function setColours(me)
			me.colour = me.colourList{me.colourIndex};
			me.backgroundColour = me.colourList{me.bgcolourIndex};
		end
		
		% ===================================================================
		%> @brief regenerate
		%>  regenerates the texture
		% ===================================================================
		function regenerate(me)
			width = abs(me.dstRect(3)-me.dstRect(1));
			height = abs(me.dstRect(4)-me.dstRect(2));
			if width ~= height
				me.sizeOut = 0;
			end
            me.barWidthOut = width / me.ppd;
            me.barHeightOut = height / me.ppd;
            me.colourOut = me.colour;
            update(me);
		end
	end
end

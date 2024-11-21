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
%>
%> Copyright ©2014-2022 Ian Max Andolina — released: LGPL3, see LICENCE.md
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
		%> use dummy eyetracker
		dummyMode = true
		%> pass some settings
		eyeSettings = []
	end
	
	properties (Hidden = true)
		stimTime = 2;
		showText = true;
		showGrid = false;
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
		backgroundColour = [0.1 0.1 0.1 0];
	end
	
	properties (SetAccess = private, GetAccess = private)
		fhandle
		ax
		cursor = false
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
			args = optickaCore.addDefaults(varargin,...
				struct('backgroundColour',[0 0 0 0],...
				'barLength',6,...
				'name','rfMapper'));
			me=me@barStimulus(args); %we call the superclass constructor first
			me.salutation('constructor','rfMapper initialisation complete');
		end
		
		% ===================================================================
		%> @brief
		%>
		% ===================================================================
		function run(me, rE)
			if ~exist('rE','var') || ~isa(rE,'runExperiment'); rE = runExperiment; end
			%------initialise the rewardManager global object
			[rM, aM] = optickaCore.initialiseGlobals();
			if rM.isOpen
				try rM.close; rM.reset; end
			end
			try
				if isfield(rE.reward,'port') && ~isempty(rE.reward.port); rM.port = rE.reward.port; end
				if isfield(rE.reward,'board') && ~isempty(rE.reward.board); rM.board = rE.reward.board; end	
			end
					
			if isempty(rE.screen); rE.initialise; end
			me.useEyetracker = false;
			me.sM = rE.screen;
			if ~isempty(rE.eyetracker.device); me.useEyetracker = true; end
			
			try
				sM = me.sM;
				sM.blend = true;
				oldbd = sM.bitDepth;
				sM.bitDepth = '8bit';
				oldbg = sM.backgroundColour;
				sM.backgroundColour = me.colourList{me.bgcolourIndex};
				if ~sM.isOpen; open(sM); end
				setup(me, sM);
				if me.useEyetracker
					try rM.open; end
					rE.configureEyetracker;
					eT = rE.eyeTracker;
				end
				secondaryFigure(me);
				if ~isdeployed; commandwindow; end
				me.buttons = [0 0 0]; % When the user clicks the mouse, 'buttons' becomes nonzero.
				mX = 0; % The x-coordinate of the mouse cursor
				mY = 0; % The y-coordinate of the mouse cursor
				xOut = 0;
				yOut = 0;
				me.rchar='';
				Priority(MaxPriority(sM.win)); %bump our priority to maximum allowed
				%Screen('TextFont', sM.win, me.monoFont);
				FlushEvents;
				if ~sM.debug; ListenChar(-1); end
				me.tick = 1;
				me.stopTask = false;
				nTicks = round( me.stimTime / sM.screenVals.ifi );
				HideCursor(sM.win); me.cursor = false;
				nRewards = 0;
				while ~me.stopTask
					%================================================================
					if me.useEyetracker % intitate fixation
						resetAll(eT);
						isFix = '';
						updateFixationValues(eT, eT.fixation.X, eT.fixation.Y, eT.fixation.initTime, eT.fixation.time,eT.fixation.radius,eT.fixation.strict);
						trackerDrawStatus(eT,'Initiate Fixation',[],0);
						statusMessage(eT,'Initiate Fixation...');
						while ~strcmpi(isFix,'fix') && ~strcmpi(isFix,'break')
							drawBackground(sM,me.backgroundColour);
							if me.showGrid; drawGrid(sM); end
							drawCross(sM, 0.75, [1 1 1 1], eT.fixation.X, eT.fixation.Y, 0.15, true, 0.2);
							flip(sM);
							trackerFlip(eT);
							getSample(eT);
							isFix = testSearchHoldFixation(eT,'fix','break');
							[mX, mY, me.buttons] = GetMouse(sM.screen);
							checkKeys(me,mX,mY); FlushEvents('keyDown');
						end
						if strcmpi(isFix,'break')
							fprintf('-->> Broke initiate fixation...\n');
							trackerDrawStatus(eT,'Broke Initiate Fixation',[],0);
							statusMessage(eT,'Subject Broke Initial Fixation!');
							vbl = flip(sM); tNow = vbl + 0.75;
							while vbl <= tNow
								drawBackground(sM, me.backgroundColour);
								if me.showGrid; drawGrid(sM); end
								[mX, mY, me.buttons] = GetMouse(sM.screen);
								checkKeys(me, mX, mY); FlushEvents('keyDown');
								vbl = flip(sM);
								if me.stopTask; break; end
							end
							continue;
						end
						updateFixationValues(eT, [], [], [], me.stimTime);
						trackerDrawStatus(eT,'Show Stimulus',[],0);
						statusMessage(eT,'Show Stimulus...');
					end
					%================================================================
					switchTick = me.tick + nTicks;
					isFix = 'fixing';
					isBreak = false;
					%================================================================
					while isBreak==false && ~me.stopTask
						[mX, mY, me.buttons] = GetMouse(sM.screen);
						drawBackground(sM, me.backgroundColour);
						%draw clicked points
						if me.showClicks == 1
							sColour = me.backgroundColour./2;
							if max(sColour)==0;sColour=[0.5 0.5 0.5 1];end
							me.xyDots = vertcat((me.xClick.*me.ppd),(me.yClick*me.ppd));
							Screen('DrawDots',sM.win,me.xyDots,2,sColour,[sM.xCenter sM.yCenter],1);
						end
						if me.showGrid; drawGrid(sM); end
						% Draw at the new location.
						if me.isVisible == true
							switch me.stimulus
								case 'bar'
									Screen('DrawTexture', sM.win, me.texture, [], me.dstRect, me.angleOut,[],me.alpha);
								case 'grating'

							end
						end
						if me.useEyetracker
							drawCross(sM, 0.8, [1 1 1 1], eT.fixation.X, eT.fixation.Y, 0.15, true, 0.6); 
						end
						xOut = (mX - sM.xCenter)/me.ppd;
						yOut = (mY - sM.yCenter)/me.ppd;
						if me.showText %draw text
							width=abs(me.dstRect(1)-me.dstRect(3))/me.ppd;
							height=abs(me.dstRect(2)-me.dstRect(4))/me.ppd;
							t=sprintf('X = %+.2f | Y = %+.2f ',xOut,yOut);
							t=[t sprintf('| W = %.2f H = %.2f ',width,height)];
							t=[t sprintf('| Scale = %i ',me.scaleTextureOut)];
							t=[t sprintf('| SF = %.2f ',me.sfOut)];
							t=[t sprintf('| Texture = %g',me.textureIndex)];
							t=[t sprintf('| Buttons: %i\t',me.buttons)];
							if ischar(me.rchar); t=[t sprintf(' | Char: %s ',me.rchar)]; end
							Screen('DrawText', sM.win, t, 5, 5, [0 0 0]);
						end
						finishDrawing(sM);
						animate(me);
						if me.buttons(2) == 1
							me.xClick = [me.xClick xOut];
							me.yClick = [me.yClick yOut];
							me.dStartTick = me.dEndTick;
							me.dEndTick = length(me.xClick);
							updateFigure(me);
						end
						checkKeys(me, mX, mY); FlushEvents('keyDown');
						if me.useEyetracker
							getSample(eT);
							isFix = testHoldFixation(eT, 'fix', 'break');
							if ~strcmpi(isFix, 'fixing'); isBreak = true; end
						else
							if me.tick >= switchTick; isBreak = true; end
						end
						me.dstRect=CenterRectOnPointd(me.dstRect, mX, mY);
						flip(sM);
						if me.useEyetracker; trackerFlip(eT); end
						me.tick = me.tick + 1;
					end
					if me.useEyetracker
						statusMessage(eT,'Stimulus turned off...');
						trackerDrawStatus(eT,'End trial...',[],0);
						fprintf('-->> Fixation result: %s\n',isFix);
						if strcmpi(isFix,'fix')
							aM.beep(2000, 0.1, 0.1);
							rM.giveReward();
							nRewards = nRewards + 1;
							tOut = 0.5;
						else
							aM.beep(250, 0.6, 1);
							tOut = 2;
						end
						fprintf('-->> Given %i rewards...\n',nRewards);
						vbl = flip(sM); tNow = vbl + tOut;
						while vbl <= tNow
							drawBackground(sM,me.backgroundColour);
							drawGrid(sM);
							checkKeys(me, mX, mY); FlushEvents('keyDown');
							vbl=flip(sM);
							if me.stopTask; break; end
						end
					end
				end

				try close(eT); end
				try close(sM); end
				sM.bitDepth = oldbd;
				sM.backgroundColour = oldbg;
				Priority(0);ListenChar(0); ShowCursor;
				if ~isempty(me.xClick) && length(me.xClick)>1
					drawMap(me); 
				end
				me.fhandle = [];
				me.ax = [];
				
			catch ERR
				try close(eT); end
				try close(me.sM); end
				try reset(me); end
				Priority(0); ListenChar(0); ShowCursor;
				sca;
				rethrow(ERR);
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
				plot(me.xClick,me.yClick,'ko','MarkerFaceColor',[0 0 0])
				xax = me.sM.winRect(3)/me.ppd;
				xax = xax - (xax/2);
				yax = me.sM.winRect(4)/me.ppd;
				yax = yax - (yax/2);
				axis([-xax xax -yax yax]);
				set(gca,'YDir','reverse');
				title('Marked Positions during RF Mapping')
				xlabel('X Position (degs)')
				ylabel('Y Position (degs)');
				box on; grid on; grid minor;
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
				cla;
			else
			plot(me.xClick(me.dStartTick:end), me.yClick(me.dStartTick:end), 'ro','MarkerFaceColor',[1 0 0]);
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
			box on; grid on; grid minor;
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
			[keyIsDown, me.rchar, ~] = optickaCore.getKeys();
			if keyIsDown == 1
				if iscell(me.rchar);me.rchar=me.rchar{1};end
				switch me.rchar
					case 'q' %quit	

						me.stopTask = true;
						
					case 'a'
						
						me.showGrid = ~me.showGrid;
						
					case 's'
						
						me.showText = ~me.showText;
						
					case 'c'
						
						me.cursor = ~me.cursor;
						if me.cursor
							fprintf('Show cursor\n');
							ShowCursor('Hand',me.sM.win);
						else
							fprintf('Hide cursor\n');
							HideCursor(me.sM.win);
						end
						
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
						
					case 'x'

						if me.isVisible == true
							me.hide;
						else
							me.show;
						end
						
					case {'LeftArrow','left'}
						me.angleOut = me.angleOut - 10;
					case {'RightArrow','right'}
						me.angleOut = me.angleOut + 10;
					case {'UpArrow','up'}
						me.alphaOut = me.alphaOut + 0.05;
						if me.alphaOut > 1;me.alphaOut = 1;end
					case {'DownArrow','down'}
						me.alphaOut = me.alphaOut - 0.05;
						if me.alpha < 0;me.alpha = 0;end
					case ',<'
						
						if max(me.backgroundColour)>0.1
							me.backgroundColour = me.backgroundColour .* 0.9;
							me.backgroundColour(me.backgroundColour<0) = 0;
						end
						
					case '.>'
						
						me.backgroundColour = me.backgroundColour .* 1.1;
						me.backgroundColour(me.backgroundColour>1) = 1;
						
					case 'r'
						
						me.backgroundColour(1) = me.backgroundColour(1) + 0.01;
						if me.backgroundColour(1) > 1
							me.backgroundColour(1) = 0;
						end

					case 'g'
						
						me.backgroundColour(2) = me.backgroundColour(2) + 0.01;
						if me.backgroundColour(2) > 1
							me.backgroundColour(2) = 0;
						end
						
					case 'b'
						
						me.backgroundColour(3) = me.backgroundColour(3) + 0.01;
						if me.backgroundColour(3) > 1
							me.backgroundColour(3) = 0;
						end
						
					case 'e'
						
						me.backgroundColour(1) = me.backgroundColour(1) - 0.01;
						if me.backgroundColour(1) < 0.01
							me.backgroundColour(1) = 1;
						end
						
					case 'f'
						
						me.backgroundColour(2) = me.backgroundColour(2) - 0.01;
						if me.backgroundColour(2) < 0.01
							me.backgroundColour(2) = 1;
						end
						
					case 'v'
						
						if me.backgroundColour(3) < 0.01
							me.backgroundColour(3) = 1;
						end
					case '1!'
						
						me.colourIndex = me.colourIndex+1;
						me.setColours;
						me.regenerate;

					case '2@'
						
						me.bgcolourIndex = me.bgcolourIndex+1;
						me.setColours;
						WaitSecs(0.05);
						me.regenerate;
						
					case '3#'
						
						ol = me.scaleTextureOut;
						switch me.stimulus
							case 'bar'
								me.scaleTextureOut = me.scaleTextureOut - 1;
								if me.scaleTextureOut < 1;me.scaleTextureOut = 1;end
								nw = me.scaleTextureOut;
						end
						if ol~=nw;me.regenerate;end
							
					case '4$'
						
						ol = me.scaleTextureOut;
						switch me.stimulus
							case 'bar'
								me.scaleTextureOut = me.scaleTextureOut + 1;
								if me.scaleTextureOut >50;me.scaleTextureOut = 50;end
								nw = me.scaleTextureOut;
						end
						if ol~=nw;me.regenerate;end
							
					case '6^'
						ol = me.sfOut;
						switch me.stimulus
							case 'bar'
								me.sfOut = me.sfOut + 0.1;
								if me.sfOut > 10;me.scaleTextureOut = 10;end
						end
						nw = me.sfOut;
						if ol~=nw;me.regenerate;end

					case '5%'
						ol = me.sfOut;
						switch me.stimulus
							case 'bar'
								me.sfOut = me.sfOut -0.1;
								if me.sfOut <0.1;me.sfOut = 0.1;end
						end
						nw = me.sfOut;
						if ol~=nw;me.regenerate;end
					case '/?'

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
							

					case 'space'
						
						switch me.stimulus
							case 'bar'
								me.textureIndex = me.textureIndex + 1;
								%me.barWidth = me.dstRect(3)/me.ppd;
								%me.barHeight = me.dstRect(4)/me.ppd;
								% me.type = me.textureList{me.textureIndex};
								me.regenerate;
							case 'grating'
						end

					case {';:',';'}

						me.showClicks = ~me.showClicks;

					case {'''"',''''}

						figure(me.fhandle);
						cla;
						me.xClick = 0;
						me.yClick = 0;
						me.dStartTick = 1;
						me.dEndTick = 1;
						me.xyDots = vertcat((me.xClick.*me.ppd),(me.yClick*me.ppd));
							
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
			[~ , name]=getP(me,'colour');
			me.(name) = me.colourList{me.colourIndex};
			me.backgroundColour = me.colourList{me.bgcolourIndex};
		end
		
		% ===================================================================
		%> @brief regenerate
		%>  regenerates the texture
		% ===================================================================
		function regenerate(me)
			width = abs(me.dstRect(3)-me.dstRect(1));
			height = abs(me.dstRect(4)-me.dstRect(2));
			if width < 5; width = 5; end
			if height < 5; height = 5; end
			if width ~= height
				me.sizeOut = 0;
			end
            me.barWidthOut = width / me.ppd;
            me.barHeightOut = height / me.ppd;
            update(me);
		end
	end
end

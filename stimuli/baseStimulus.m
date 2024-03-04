% ========================================================================
classdef baseStimulus < optickaCore & dynamicprops
%> @class baseStimulus
%> @brief baseStimulus is the superclass for all stimulus objects
%>
%> Superclass providing basic structure for all stimulus classes. This is a dynamic properties
%> descendant, allowing for the temporary run variables used, which get appended "name"Out, i.e.
%> speed is duplicated to a dymanic property called speedOut; it is the dynamic propertiy which is
%> used during runtime, and whose values are converted from definition units like degrees to pixel
%> values that PTB uses. The transient copies are generated on setup and removed on reset.
%>
%> @todo build up animatorManager functions
%>
%> Copyright ©2014-2022 Ian Max Andolina — released: LGPL3, see LICENCE.md
% ========================================================================

	%--------------------ABSTRACT PROPERTIES----------%
	properties (Abstract = true)
		%> stimulus type
		type char
	end

	%--------------------ABSTRACT PROPERTIES----------%
	properties (Abstract = true, SetAccess = protected)
		%> the stimulus family (grating, dots etc.)
		family char
	end

	%--------------------PUBLIC PROPERTIES----------%
	properties
		%> X Position ± degrees relative to screen center (0,0)
		xPosition double		= 0
		%> Y Position ± degrees relative to screen center (0,0)
		yPosition double		= 0
		%> Size in visual degrees (°), can also be used to scale images/movies
		%> or define length of a bar etc.
		size double				= 4
		%> Colour as a 0-1 range RGB or RGBA vector (if you pass A it also
		%> modifies alpha and visa-versa
		colour double			= [1 1 1 1]
		%> Alpha (opacity) [0-1], this gets combined with the RGB colour
		alpha double			= 1
		%> For moving stimuli do we start "before" our initial position? This allows you to
		%> center a stimulus at a screen location, but then drift it across that location, so
		%> if xyPosition is 0,0 and startPosition is -2 then the stimulus will start at -2 drifing
		%> towards 0.
		startPosition double	= 0
		%> speed in degs/s - this mostly afffects linear motion, but with an
		%> animationManager is also used to define initial motion value
		speed double			= 0
		%> angle in degrees (0 - 360)
		angle double			= 0
		%> delay time to display relative to stimulus onset, can set upper and lower range
		%> for random interval. This allows for a group of stimuli some to be delayed relative
		%> to others for a global stimulus onset time.
		delayTime double		= 0
		%> time to turn stimulus off, relative to stimulus onset
		offTime double			= Inf
		%> true or false, whether to draw() this object
		isVisible logical		= true
		%> animation manager: can assign an animationManager() object that handles
		%> more complex animation paths than simple builtin linear motion WIP
		animator				= []
		%> override X and Y position with mouse input? Useful for RF mapping
		mouseOverride logical	= false
		%> show the position on the Eyetracker display?
		showOnTracker logical	= true
		%> Do we print details to the commandline?
		verbose					= false
	end

	%--------------------TRANSIENT PROPERTIES-----------%
	properties (Transient = true)
		%> final centered X position in pixel coordinates PTB uses: 0,0 top-left
		%> see computePosition();
		xFinal double			= []
		%> final centerd Y position in pixel coordinates PTB uses: 0,0 top-left
		%> see computePosition();
		yFinal double			= []
		%> current screen rectangle position [LEFT TOP RIGHT BOTTOM]
		mvRect double			= []
	end

	%--------------------HIDDEN PROPERTIES-----------%
	properties(Transient = true, Hidden = true)
		%> size in pixels
		szPx					= []
		%> position in degrees
		xFinalD					= []
		yFinalD					= []
	end
	
	%--------------------VISIBLE PROPERTIES-----------%
	properties (SetAccess = protected, GetAccess = public)
		%> initial screen rectangle position [LEFT TOP RIGHT BOTTOM]
		dstRect double			= []
		%> tick updates +1 on each call of draw (even if delay or off is true and no stimulus is drawn, resets on each update
		tick double				= 0
		%> draw tick only updates when a draw command is called, resets on each update
		drawTick double			= 0
		%> pixels per degree (normally inhereted from screenManager)
		ppd double				= 36
		%> is stimulus position defined as rect [true] or point [false]
		isRect logical			= true
	end
	
	%--------------------DEPENDENT PROPERTIES----------%
	properties (Dependent = true, SetAccess = protected, GetAccess = public)
		%> What our per-frame motion delta is
		delta double
		%> X update which is computed from our speed and angle
		dX double
		%> X update which is computed from our speed and angle
		dY double
	end
	
	%--------------------TRANSIENT PROPERTIES----------%
	properties (SetAccess = protected, Transient = true)
		%> Our texture pointer for texture-based stimuli
		texture double
		%> handles for the GUI
		handles struct
		%> our screen manager
		sM screenManager
		%> screen settings generated by sM on setup
		screenVals struct	= struct('ifi',1/60,'fps',60,'winRect',[0 0 1920 1080])
		%. is object set up?
		isSetup logical		= false
		%> is panel constructed?
		isGUI logical		= false
	end
	
	%--------------------PROTECTED PROPERTIES----------%
	properties (Access = protected)
		%> is mouse position within screen co-ordinates?
		mouseValid logical	= false
		%> mouse X position
		mouseX double		= 0
		%> mouse Y position
		mouseY double		= 0
		%> delay ticks to wait until display
		delayTicks double	= 0
		%> ticks before stimulus turns off
		offTicks double		= Inf
		%>are we setting up?
		inSetup logical		= false
		%> delta cache
		delta_		= []
		%> dX cache
		dX_			= []
		%> dY cache
		dY_			= []
		% deal with interaction of colour and alpha
		isInSetColour logical	= false
		setLoop		= 0
		%> Which properties to ignore cloning when making transient copies in setup
		ignorePropertiesBase = {'dp','animator','specialFlags','handles','ppd','sM',...
			'name','comment','fullName','family','type','dX','dY','delta','verbose',...
			'texture','dstRect','xFinal','yFinal','isVisible','dateStamp','paths',...
			'uuid','tick','delayTicks','mouseOverride','isRect','dstRect','mvRect','sM',...
			'screenVals','isSetup','isGUI','showOnTracker','doDots','doMotion',...
			'doDrift','doFlash','doAnimator','mouseX','mouseY','szPx','xFinalD','yFinalD'}
		%> Which properties to not draw in the UI panel
		ignorePropertiesUIBase = {'animator','fullName','mvRect','xFinal','yFinal','szPx','xFinalD','yFinalD'}
	end
	
	%--------------------PRIVATE PROPERTIES----------%
	properties (SetAccess = private, GetAccess = private)
		%> properties allowed to be passed on construction
		allowedProperties = {'xPosition','yPosition','size','colour','verbose',...
			'alpha','startPosition','angle','speed','delayTime','mouseOverride','isVisible'...
			'showOnTracker','animator'}
	end
	
	events
		%> triggered when reading from a UI panel,
		readPanelUpdate
	end

	%> ALL Children must implement these 5 methods!
	%=======================================================================
	methods (Abstract)%------------------ABSTRACT METHODS
	%=======================================================================
		%> initialise the stimulus with the PTB screenManager
		out = setup(runObject)
		%>draw to the screen buffer, ready for flip()
		out = draw(runObject)
		%> animate the stimulus, normally called after a draw
		out = animate(runObject)
		%> update the stimulus, normally called between trials if any
		%>variables have changed
		out = update(runObject)
		%> reset back to pre-setup state (removes the transient cache
		%> properties, resets the various timers etc.)
		out = reset(runObject)
	end %---END ABSTRACT METHODS---%
	
	%=======================================================================
	methods %----------------------------PUBLIC METHODS
	%=======================================================================
		
		% ===================================================================
		%> @brief Class constructor
		%>
		%> @param varargin are passed as a structure / cell of properties which is
		%> parsed.
		%> @return instance of class.
		% ===================================================================
		function me = baseStimulus(varargin)
			me=me@optickaCore(varargin); %superclass constructor
			me.parseArgs(varargin, me.allowedProperties);
		end

		% ===================================================================
		%> @brief colour set method
		%> Allow 1 (R=G=B) 3 (RGB) or 4 (RGBA) value colour
		% ===================================================================
		function set.colour(me,value)
			if me.isSetup; warning('You should set colourOut to affect drawing...'); end
			me.isInSetColour = true; %#ok<*MCSUP>
			len=length(value);
			switch len
				case 4
					c = value(1:4);
					me.alpha = value(4);
				case 3
					c = [value(1:3) me.alpha]; %force our alpha to override
				case 1
					c = [value value value me.alpha]; %construct RGBA
				otherwise
					if isa(me,'gaborStimulus') || isa(me,'gratingStimulus')
						c = []; %return no colour to procedural gratings
					else
						c = [1 1 1 me.alpha]; %return white for everything else
					end
			end
			c(c<0)=0; c(c>1)=1;
			me.colour = c;
			if isprop(me,'correctBaseColour') && me.correctBaseColour %#ok<*MCSUP> 
				me.baseColour = (me.colour(1:3) + me.colour2(1:3))/2;
			end
			me.isInSetColour = false;
		end

		% ===================================================================
		%> @brief alpha set method
		%>
		% ===================================================================
		function set.alpha(me,value)
			if me.isSetup; warning('You should set alphaOut to affect drawing...'); end
			if value<0; value=0;elseif value>1; value=1; end
			me.alpha = value;
			if ~me.isInSetColour
				me.colour = me.colour(1:3); %force colour to be regenerated
				if ~isempty(findprop(me,'colour2')) && ~isempty(me.colour2)
					me.colour2 = [me.colour2(1:3) me.alpha];
				end
				if ~isempty(findprop(me,'baseColour')) && ~isempty(me.baseColour)
					me.baseColour = [me.baseColour(1:3) me.alpha];
				end
			end
		end

		% ===================================================================
		%> @brief delta Get method
		%> delta is the normalised number of pixels per frame to move a stimulus
		% ===================================================================
		function value = get.delta(me)
			value = (getP(me,'speed') * me.ppd) * me.screenVals.ifi;
		end

		% ===================================================================
		%> @brief dX Get method
		%> X position increment for a given delta and angle
		% ===================================================================
		function value = get.dX(me)
			value = 0;
			if ~isempty(findprop(me,'directionOut'))
				[value,~]=me.updatePosition(me.delta,me.directionOut);
			elseif ~isempty(findprop(me,'angleOut'))
				[value,~]=me.updatePosition(me.delta,me.angleOut);
			end
		end

		% ===================================================================
		%> @brief dY Get method
		%> Y position increment for a given delta and angle
		% ===================================================================
		function value = get.dY(me)
			value = 0;
			if ~isempty(findprop(me,'directionOut'))
				[~,value]=me.updatePosition(me.delta,me.directionOut);
			elseif ~isempty(findprop(me,'angleOut'))
				[~,value]=me.updatePosition(me.delta,me.angleOut);
			end
		end

		% ===================================================================
		%> @brief Method to set isVisible=true.
		%>
		% ===================================================================
		function show(me)
			me.isVisible = true;
		end

		% ===================================================================
		%> @brief Method to set isVisible=false.
		%>
		% ===================================================================
		function hide(me)
			me.isVisible = false;
		end

		% ===================================================================
		%> @brief set offTime
		%>
		% ===================================================================
		function setOffTime(me, time)
			me.offTime = time;
		end

		% ===================================================================
		%> @brief set offTime
		%>
		% ===================================================================
		function setDelayTime(me, time)
			me.delayTime = time;
		end


		% ===================================================================
		%> @brief reset the various tick counters for our stimulus
		%>
		% ===================================================================
		function resetTicks(me)
			global mouseTick %#ok<*GVMIS> %shared across all stimuli
			if max(me.delayTime) > 0 %delay display a number of frames
				if length(me.delayTime) == 1
					me.delayTicks = round(me.delayTime/me.screenVals.ifi);
				elseif length(me.delayTime) == 2
					time = randi([me.delayTime(1)*1000 me.delayTime(2)*1000])/1000;
					me.delayTicks = round(time/me.screenVals.ifi);
				end
			else
				me.delayTicks = 0;
			end
			if min(me.offTime) < Inf %delay display a number of frames
				if length(me.offTime) == 1
					me.offTicks = round(me.offTime/me.screenVals.ifi);
				elseif length(me.offTime) == 2
					time = randi([me.offTime(1)*1000 me.offTime(2)*1000])/1000;
					me.offTicks = round(time/me.screenVals.ifi);
				end
			else
				me.offTicks = Inf;
			end
			mouseTick = 0;
			me.tick = 0;
			me.drawTick = 0;
		end

		% ===================================================================
		%> @brief get mouse position
		%> we make sure this is only called once per animation tick to
		%> improve performance and ensure all stimuli that are following
		%> mouse position have consistent X and Y per frame update
		%> This sets mouseX and mouseY and mouseValid if mouse is within
		%> PTB screen (useful for mouse override positioning for stimuli)
		% ===================================================================
		function getMousePosition(me)
			global mouseTick mouseGlobalX mouseGlobalY mouseValid
			if me.tick > mouseTick
				if ~isempty(me.sM) && isa(me.sM,'screenManager') && me.sM.isOpen
					[me.mouseX, me.mouseY] = GetMouse(me.sM.win);
				else
					[me.mouseX, me.mouseY] = GetMouse;
				end
				if me.mouseX > -1 && me.mouseY > -1
					me.mouseValid = true;
				else
					me.mouseValid = false;
				end
				mouseTick = me.tick; %set global so no other object with same tick number can call this again
				mouseValid = me.mouseValid;
				mouseGlobalX = me.mouseX; mouseGlobalY = me.mouseY;
			else
				if ~isempty(mouseGlobalX) && ~isempty(mouseGlobalY)
					me.mouseX = mouseGlobalX; me.mouseY = mouseGlobalY;
					me.mouseValid = mouseValid;
				end
			end
		end

		% ===================================================================
		%> @fn run
		%> @brief Run stimulus in a window to preview it
		%>
		%> @param benchmark true|false [optional, default = false]
		%> @param runtime time to show stimulus [optional, default = 2]
		%> @param screenManager to use [optional]
		%> @param forceScreen for a particulr monitor/screen to use
		%> @param showVBL show a plot of the VBL times
		% ===================================================================
		function run(me, benchmark, runtime, s, forceScreen, showVBL)
		% run(me, benchmark, runtime, s, forceScreen, showVBL)
			try

				if ~exist('benchmark','var') || isempty(benchmark)
					benchmark=false;
				end
				if ~exist('runtime','var') || isempty(runtime)
					runtime = 2; %seconds to run
				end
				if ~exist('s','var') || ~isa(s,'screenManager')
					if isempty(me.sM); me.sM=screenManager; end
					s = me.sM;
					s.blend = true;
					s.disableSyncTests = true;
					s.visualDebug = true;
					s.bitDepth = '8bit';
				end
				if ~exist('forceScreen','var') || isempty(forceScreen); forceScreen = -1; end
				if ~exist('showVBL','var') || isempty(showVBL); showVBL = false; end

				oldscreen = s.screen;
				oldbitdepth = s.bitDepth;
				oldwindowed = s.windowed;
				if forceScreen >= 0
					s.screen = forceScreen;
					if forceScreen == 0
						s.bitDepth = '8bit';
					end
				end
				prepareScreen(s);

				if benchmark
					s.windowed = false;
				elseif forceScreen > -1
					if ~isempty(s.windowed) && (length(s.windowed) == 2 || length(s.windowed) == 4)
						% use existing setting
					else
						s.windowed = [0 0 s.screenVals.screenWidth/2 s.screenVals.screenHeight/2]; %half of screen
					end
				end

				if me.verbose; s.debug = true; end

				if ~s.isOpen; open(s);end
				sv = s.screenVals;
				setup(me,s); %setup our stimulus object

				Priority(MaxPriority(s.win)); %bump our priority to maximum allowed

				if ~any(strcmpi(me.family,{'movie','revcor'})); draw(me); resetTicks(me); end
				if benchmark
					drawText(s, 'BENCHMARK: screen won''t update properly, see FPS in command window at end.');
				else
					drawGrid(s); %draw degree dot grid
					drawScreenCenter(s);
					drawText(s, ['Preview ALL with grid = ±1°; static for 1 seconds, then animate for ' num2str(runtime) ' seconds...'])
				end
				if ismethod(me,'resetLog'); resetLog(me); end
				flip(s);
				if ~any(strcmpi(me.family,{'movie','revcor'})); update(me); end
				if benchmark
					WaitSecs('YieldSecs',0.25);
				else
					WaitSecs('YieldSecs',2);
				end
				if runtime < sv.ifi; runtime = sv.ifi; end
				nFrames = 0;
				notFinished = true;
				benchmarkFrames = floor(sv.fps * runtime);
				vbl = zeros(benchmarkFrames+1,1);
				startT = GetSecs; lastvbl = startT;
				while notFinished
					nFrames = nFrames + 1;
					draw(me); %draw stimulus
					if ~benchmark && s.debug; drawGrid(s); end
					finishDrawing(s); %tell PTB/GPU to draw
 					animate(me); %animate stimulus, will be seen on next draw
					if benchmark
						Screen('Flip',s.win,0,2,2);
						notFinished = nFrames < benchmarkFrames;
					else
						vbl(nFrames) = flip(s, lastvbl + sv.halfifi); %flip the buffer
						lastvbl = vbl(nFrames);
						% the calculation needs to take into account the
						% first and last frame times, so we subtract ifi*2
						notFinished = lastvbl < ( vbl(1) + ( runtime - (sv.ifi * 2) ) );
					end
				end
				endT = flip(s);
				if ~benchmark;startT = vbl(1);end
				diffT = endT - startT;
				WaitSecs(0.5);
				vbl = vbl(1:nFrames);
				if showVBL && ~benchmark
					figure;
					plot(diff(vbl)*1e3,'k*');
					line([0 length(vbl)-1],[sv.ifi*1e3 sv.ifi*1e3],'Color',[0 0 0]);
					title(sprintf('VBL Times, should be ~%.4f ms',sv.ifi*1e3));
					ylabel('Time (ms)')
					xlabel('Frame #')
				end
				Priority(0); ShowCursor; ListenChar(0);
				reset(me); %reset our stimulus ready for use again
				close(s); %close screen
				s.screen = oldscreen;
				s.windowed = oldwindowed;
				s.bitDepth = oldbitdepth;
				fps = nFrames / diffT;
				fprintf('\n\n======>>> Stimulus: %s\n',me.fullName);
				fprintf('======>>> <strong>SPEED</strong> (%i frames in %.3f secs) = <strong>%g</strong> fps\n\n',nFrames, diffT, fps);
				if ~benchmark;fprintf('\b======>>> First - Last frame time: %.3f\n\n',vbl(end)-startT);end
				clear s fps benchmark runtime b bb i vbl; %clear up a bit
			catch ERR
				try getReport(ERR); end
				try Priority(0); end
				if exist('s','var') && isa(s,'screenManager')
					try close(s); end
				end
				clear fps benchmark runtime b bb i; %clear up a bit
				reset(me); %reset our stimulus ready for use again
				rethrow(ERR)
			end
		end
		
		% ===================================================================
		%> @brief make a GUI properties panel for this object
		%>
		% ===================================================================
		function handles = makePanel(me, parent)
			if ~isempty(me.handles) && isfield(me.handles, 'root') && isa(me.handles.root,'matlab.ui.container.Panel')
				fprintf('---> Panel already open for %s\n', me.fullName);
				return
			end
			
			handles = [];
			setPaths(me); % refresh our paths for the current machine
			if isempty(me.sansFont); getFonts(me); end
			
			if ~exist('parent','var')
				parent = uifigure('Tag','gFig',...
					'Name', [me.fullName 'Properties'], ...
					'Position', [ 10 10 800 500 ],...
					'MenuBar', 'none', ...
					'CloseRequestFcn', @me.closePanel, ...
					'NumberTitle', 'off');
				me.handles(1).parent = parent;
				handles(1).parent = parent;
			end
			
			bgcolor = [0.95 0.95 0.95];
			bgcoloredit = [1 1 1];
			fsmall = 11;
			fmed = 12;
			handles.root = uipanel('Parent', parent,...
				'Units', 'normalized',...
				'Position', [0 0 1 1],...
				'Title', me.fullName,...
				'TitlePosition','centertop',...
				'FontName', me.sansFont,...
				'FontSize', fmed,...
				'FontAngle', 'italic',...
				'BackgroundColor', [0.94 0.94 0.94]);
			handles.grid = uigridlayout(handles.root,[1 3]);
			handles.grid1 = uigridlayout(handles.grid,'Padding',[5 5 5 5],'BackgroundColor',bgcolor);
			handles.grid2 = uigridlayout(handles.grid,'Padding',[5 5 5 5],'BackgroundColor',bgcolor);
			handles.grid.ColumnWidth = {'1x','1x',130};
			handles.grid1.ColumnWidth = {'2x','1x'};
			handles.grid2.ColumnWidth = {'2x','1x'};
			
			idx = {'handles.grid1','handles.grid2','handles.grid3'};
			
			disableList = 'fullName';

			tic
			mc = metaclass(me);
			pl = string({mc.PropertyList.Name});
			d1 = {mc.PropertyList.Description};
			d2 = {mc.PropertyList.DetailedDescription};
			for i = 1:length(d1)
				a = regexprep(d1{i},'^\s*>\s*','');
				a = regexprep(a,'''','`');
				b = d2{i};
				if isempty(b)
					dl{i} = string(a);
				else
					b = strsplit(b,'\n');
					for j = 1:length(b)
						b{j} = regexprep(b{j},'^\s*>\s*','');
						b{j} = regexprep(b{j},'''','`');
					end
					dl{i} = string([{a} b(:)']);
				end
			end
			toc
			pr = findAttributesandType(me,'SetAccess','public','notlogical');
			pr = sort(pr);
			igA = {}; igB = {};
			val = findPropertyDefault(me,'ignorePropertiesUI');
			if ~isempty(val)
				igA = val;
			elseif isprop(me,'ignorePropertiesUI')
				igA = me.ignorePropertiesUI;
			end
			if isprop(me,'ignorePropertiesUIBase'); igB = findPropertyDefault(me,'ignorePropertiesUIBase'); end
			if ischar(igA);igA = strsplit(igA,'|');end
			if ischar(igB); igB = {'animator','fullName','mvRect','xFinal','yFinal','xFinalD','yFinalD'}; end
			excl = [igA igB];	
			eidx = [];
			for i = 1:length(pr)
				if matches(pr{i}, excl)
					eidx = [eidx i];
				end
			end
			pr(eidx) = [];
			lp = ceil(length(pr)/2);
			
			pr2 = findAttributesandType(me,'SetAccess','public','logical');
			pr2 = sort(pr2);
			eidx = [];
			for i = 1:length(pr2)
				if matches(pr2{i},excl)
					eidx = [eidx i];
				end
			end
			pr2(eidx) = [];
			lp2 = length(pr2);
			if lp2 > 0; handles.grid3 = uigridlayout(handles.grid,[lp2 1],'Padding',[1 1 1 1],'BackgroundColor',bgcolor); end

			for i = 1:2
				for j = 1:lp
					cur = lp*(i-1)+j;
					if cur <= length(pr)
						nm = pr{cur};
						val = me.(nm);
						% this gets descriptions
						ix = find(pl == nm);
						if ~isempty(ix)
							desc = dl{ix};
						else
							desc = nm;
						end
						if ischar(val)
							if isprop(me,[nm 'List'])
								if strcmp(me.([nm 'List']),'filerequestor')
									val = regexprep(val,'\s+','  ');
									handles.([nm '_char']) = uieditfield(...
										'Parent',eval(idx{i}),...
										'Tag',[nm '_char'],...
										'HorizontalAlignment','center',...
										'ValueChangedFcn',@me.readPanel,...
										'Value',val,...
										'FontName',me.monoFont,...
										'Tooltip', desc, ...
										'BackgroundColor',bgcoloredit);
									if ~isempty(regexpi(nm,disableList,'once')) 
										handles.([nm '_char']).Enable = false; 
									end
								else
									txt=findPropertyDefault(me,[nm 'List']);
									if contains(val,txt)
										handles.([nm '_list']) = uidropdown(...
										'Parent',eval(idx{i}),...
										'Tag',[nm '_list'],...
										'Items',txt,...
										'ValueChangedFcn',@me.readPanel,...
										'Value',val,...
										'Tooltip', desc, ...
										'BackgroundColor',bgcolor);
										if ~isempty(regexpi(nm,disableList,'once')) 
											handles.([nm '_list']).Enable = false; 
										end
									else
										handles.([nm '_list']) = uidropdown(...
										'Parent',eval(idx{i}),...
										'Tag',[nm '_list'],...
										'Items',txt,...
										'Tooltip', desc, ...
										'ValueChangedFcn',@me.readPanel,...
										'BackgroundColor',bgcolor);
									end
								end
							else
								val = regexprep(val,'\s+','  ');
								handles.([nm '_char']) = uieditfield(...
									'Parent',eval(idx{i}),...
									'Tag',[nm '_char'],...
									'HorizontalAlignment','center',...
									'ValueChangedFcn',@me.readPanel,...
									'Value',val,...
									'Tooltip', desc, ...
									'BackgroundColor',bgcoloredit);
								if ~isempty(regexpi(nm,disableList,'once')) 
									handles.([nm '_char']).Enable = false; 
								end
							end
						elseif isnumeric(val)
							val = num2str(val);
							val = regexprep(val,'\s+','  ');
							handles.([nm '_num']) = uieditfield('text',...
								'Parent',eval(idx{i}),...
								'Tag',[nm '_num'],...
								'HorizontalAlignment','center',...
								'Value',val,...
								'Tooltip', desc, ...
								'ValueChangedFcn',@me.readPanel,...
								'FontName',me.monoFont,...
								'BackgroundColor',bgcoloredit);
							if ~isempty(regexpi(nm,disableList,'once')) 
								handles.([nm '_num']).Enable = false; 
							end
						else
							uilabel('Parent',eval(idx{i}),'Text','','BackgroundColor',bgcolor,'Enable','off');
						end
						if isprop(me,[nm 'List'])
							if strcmp(me.([nm 'List']),'filerequestor')
								handles.([nm '_button']) = uibutton(...
								'Parent',eval(idx{i}),...
								'HorizontalAlignment','left',...
								'Text','Select file...',...
								'FontName',me.sansFont,...
								'Tag',[nm '_button'],...
								'Tooltip', desc, ...
								'Icon', [me.paths.root '/ui/images/edit.svg'],...
								'ButtonPushedFcn', @me.selectFilePanel,...
								'FontSize', 8);
							else
								uilabel(...
								'Parent',eval(idx{i}),...
								'HorizontalAlignment','left',...
								'Text',nm,...
								'FontName',me.sansFont,...
								'FontSize', fsmall,...
								'BackgroundColor',bgcolor);
							end
						else
							uilabel(...
							'Parent',eval(idx{i}),...
							'HorizontalAlignment','left',...
							'Text',nm,...
							'FontName',me.sansFont,...
							'FontSize', fsmall,...
							'BackgroundColor',bgcolor);
						end
					else
						uilabel('Parent',eval(idx{i}),'Text','','BackgroundColor',bgcolor,'Enable','off');
					end
				end
			end
			for j = 1:lp2
				nm = pr2{j};
				val = me.(nm);
				% this gets descriptions
				ix = find(pl == nm);
				if ~isempty(ix)
					desc = dl{ix};
				else
					desc = nm;
				end
				if j <= length(pr2)
					handles.([nm '_bool']) = uicheckbox(...
						'Parent',eval(idx{end}),...
						'Tag',[nm '_bool'],...
						'Text',nm,...
						'Tooltip', desc, ...
						'FontName',me.sansFont,...
						'FontSize', fsmall,...
						'ValueChangedFcn',@me.readPanel,...
						'Value',val);
				end
			end
			%handles.readButton = uibutton(...
			%	'Parent',eval(idx{end}),...
			%	'Tag','readButton',...%'Callback',@me.readPanel,...
			%	'Text','Update');
			me.handles = handles;
			me.isGUI = true;
		end
		
		% ===================================================================
		%> @brief read values from a GUI properties panel for this object
		%>
		% ===================================================================
		function selectFilePanel(me,varargin)
			if nargin > 0
				hin = varargin{1};
				if ishandle(hin)
					[f,p] = uigetfile('*.*','Select File:');
					re = regexp(get(hin,'Tag'),'(.+)_button','tokens','once');
					hout = me.handles.([re{1} '_char']);
					if ishandle(hout)
						set(hout,'Value', [p f]);
						me.readPanel(hout);
					end
				end
			end
		end
		
		% ===================================================================
		%> @brief read values from a GUI properties panel for this object
		%>
		% ===================================================================
		function readPanel(me,varargin)
			if isempty(me.handles) || ~(isfield(me.handles, 'root') && isa(me.handles.root,'matlab.ui.container.Panel'))
				return
			end
			if isempty(varargin) || isempty(varargin{1}); return; end
			source = varargin{1};
			tag = source.Tag;
			if isempty(tag); return; end
			tagName = regexprep(tag,'_.+$','');
			tagType = regexprep(tag,'^.+_','');
			
			pList = findAttributes(me,'SetAccess','public'); %our public properties
			
			if ~any(contains(pList,tagName)); return; end
			
			switch tagType
				case 'list'
					me.(tagName) = source.Value;
				case 'bool'	
					me.(tagName) = logical(source.Value);
				case 'num'
					me.(tagName) = str2num(source.Value);
				case 'char'
					me.(tagName) = source.Value;
				otherwise
					warning('Can''t set property');
			end
			
			if strcmpi(tagName,'name')
				me.handles.fullName_char.Value = me.fullName;
				me.handles.root.Title = me.fullName;
			end
			
			if strcmpi(tagName,'alpha')
				me.handles.colour_num.Value = num2str(me.colour, '%g ');
				if isprop(me,'colour2') 
					me.handles.colour2_num.Value = num2str(me.colour2, '%g ');
				end
				if isprop(me,'baseColour') 
					me.handles.baseColour_num.Value = num2str(me.baseColour, '%g ');
				end
			end

			if strcmpi(tagName,'alpha2')
				if isprop(me,'colour2');me.handles.colour2_num.Value = num2str(me.colour2, '%g ');end
			end
			
			if strcmpi(tagName,'colour')
				me.handles.alpha_num.Value = num2str(me.alpha, '%g ');
				if isprop(me,'correctBaseColour') && me.correctBaseColour
					me.handles.baseColour_num.Value = num2str(me.baseColour, '%g ');
				end
			end

			if strcmpi(tagName,'colour2')
				if isprop(me,'alpha2');me.handles.alpha2_num.Value = num2str(me.alpha2, '%g ');end
				if isprop(me,'correctBaseColour') && me.correctBaseColour
					me.handles.baseColour_num.Value = num2str(me.baseColour, '%g ');
				end
			end

			if strcmpi(tagName,'filePath') && isa(me,'imageStimulus')
				me.checkfilePath();
			end
			
			notify(me,'readPanelUpdate');
		end
			
		% ===================================================================
		%> @brief show GUI properties panel for this object
		%>
		% ===================================================================
		function showPanel(me)
			if isempty(me.handles)
				return
			end
			set(me.handles.root,'Enable','on');
			set(me.handles.root,'Visible','on');
		end
		
		% ===================================================================
		%> @brief hide GUI properties panel for this object
		%>
		% ===================================================================
		function hidePanel(me)
			if isempty(me.handles)
				return
			end
			set(me.handles.root,'Enable','off');
			set(me.handles.root,'Visible','off');
		end
		
		% ===================================================================
		%> @brief close GUI panel for this object
		%>
		% ===================================================================
		function closePanel(me,varargin)
			if isfield(me.handles,'root') && isgraphics(me.handles.root)
				delete(me.handles.root);
			end
			if isfield(me.handles,'parent') && isgraphics(me.handles.parent,'figure')
				delete(me.handles.parent)
			end
			me.cleanHandles();
			me.isGUI = false;
		end
		
		% ===================================================================
		%> @fn cleanHandles
		%> @brief clean any handles
		%>
		%> @param
		%> @return
		% ===================================================================
		function cleanHandles(me, ~)
			if isprop(me,'handles')
				me.handles = [];
			end
			if isprop(me,'h')
				me.h = [];
			end
			fprintf('===>>> baseStimulus: Ran clean handles!!!\n')
			me.isGUI = false;
		end

		% ===================================================================
		%> @fn getP
		%> @brief gets a property copy or original property
		%>
		%> When stimuli are run, their properties are copied, so e.g. angle
		%> is copied to angleOut and this is used during the task. This
		%> method checks if the copy is available and returns that, otherwise
		%> return the original.
		%>
		%> @param name of property
		%> @param range of property to return
		%> @return value of property
		% ===================================================================
		function [value, name] = getP(me, name, range)
		% [value, name] = getP(me, name, range)
			if isprop(me, [name 'Out'])
				name = [name 'Out'];
				value = me.(name);
				if exist('range','var'); value = value(range); end
			elseif isprop(me, name)
				value = me.(name);
				if exist('range','var'); value = value(range); end
			else
				if me.verbose;fprintf('Property %s doesn''t exist...\n',name);end
				value = []; name = [];
			end
		end

		% ===================================================================
		%> @fn setP
		%> @brief sets a property copy or original property
		%>
		%> When stimuli are run, their properties are copied, so e.g. angle
		%> is copied to angleOut and this is used during the task. This
		%> method checks if the copy is available and returns that, otherwise
		%> return the original.
		%>
		%> @param name of property
		%> @param range of property to return
		%> @return value of property
		% ===================================================================
		function setP(me, name, value)
		% setP(me, name, value)
			if isprop(me,[name 'Out'])
				me.([name 'Out']) = value;
			elseif isprop(me, name)
				me.(name) = value;
			else
				if me.verbose;fprintf('Property %s doesn''t exist...\n',name);end
			end
		end

		% ===================================================================
		%> @fn updateXY
		%> @brief Update only position info, faster and doesn't reset image etc.
		%>
		% ===================================================================
		function updateXY(me,x,y,degrees)
		% updateXY(me, x, y, degrees)
			if ~exist('degrees','var') || isempty(degrees); degrees = false; end
			if degrees
				if ~isempty(x); me.xFinal = me.sM.toPixels(x, 'x'); me.xFinalD = x; end
				if ~isempty(y); me.yFinal = me.sM.toPixels(y, 'y'); me.yFinalD = y; end
			else
				if ~isempty(x); me.xFinal = x; me.xFinalD = me.sM.toDegrees(x, 'x'); end
				if ~isempty(y); me.yFinal = y; me.yFinalD = me.sM.toDegrees(y, 'y'); end
			end
			if length(me.mvRect) == 4
				me.mvRect=CenterRectOnPointd(me.mvRect, me.xFinal, me.yFinal);
			end
		end

	end %---END PUBLIC METHODS---%

	%=======================================================================
	methods ( Static ) %----------STATIC METHODS
	%=======================================================================

		% ===================================================================
		%> @brief degrees2radians
		%>
		% ===================================================================
		function r = d2r(degrees)
		% d2r(degrees)
			r=degrees*(pi/180);
		end

		% ===================================================================
		%> @brief radians2degrees
		%>
		% ===================================================================
		function degrees = r2d(r)
		% r2d(radians)
			degrees=r*(180/pi);
		end

		% ===================================================================
		%> @brief findDistance in X and Y coordinates
		%>
		% ===================================================================
		function distance = findDistance(x1, y1, x2, y2)
		% findDistance(x1, y1, x2, y2)
			distance=sqrt((x2 - x1)^2 + (y2 - y1)^2);
		end

		% ===================================================================
		%> @brief updatePosition returns dX and dY given an angle and delta
		%>
		% ===================================================================
		function [dX, dY] = updatePosition(delta, angle)
		% updatePosition(delta, angle)
			dX = delta .* cos(baseStimulus.d2r(angle));
			if length(dX)== 1 && abs(dX) < 1e-3; dX = 0; end
			dY = delta .* sin(baseStimulus.d2r(angle));
			if length(dY)==1 && abs(dY) < 1e-3; dY = 0; end
		end

	end%---END STATIC METHODS---%

	%=======================================================================
	methods ( Access = protected ) %-------PRIVATE (protected) METHODS-----%
	%=======================================================================

		% ===================================================================
		%> @fn addRuntimeProperties
		%> @brief These are transient properties that specify actions during runtime
		% ===================================================================
		function addRuntimeProperties(me)
			if isempty(me.findprop('doFlash')); me.addprop('doFlash');end
			if isempty(me.findprop('doDots')); me.addprop('doDots');end
			if isempty(me.findprop('doMotion')); me.addprop('doMotion');end
			if isempty(me.findprop('doDrift')); me.addprop('doDrift');end
			if isempty(me.findprop('doAnimator')); me.addprop('doAnimator');end
			updateRuntimeProperties(me);
		end

		% ===================================================================
		%> @fn updateRuntimeProperties
		%> @brief Update transient properties that specify actions during runtime
		% ===================================================================
		function updateRuntimeProperties(me)
			me.doDots		= false;
			me.doMotion		= false;
			me.doDrift		= false;
			me.doFlash		= false;
			me.doAnimator	= false;
			[v,n] = getP(me,'tf');
			if ~isempty(n) && v > 0; me.doDrift = true; end
			[v,n] = getP(me,'speed');
			if ~isempty(n) && v > 0; me.doMotion = true; end
			if strcmpi(me.family,'dots'); me.doDots = true; end
			if strcmpi(me.type,'flash'); me.doFlash = true; end
			if ~isempty(me.animator) && isa(me.animator,'animationManager')
				me.doAnimator = true;
			end
		end

		% ===================================================================
		%> @brief compute xFinal and yFinal (in pixels) taking startPosition,
		%> xPosition, yPosition and direction/angle into account
		%>
		% ===================================================================
		function computePosition(me)
			if me.mouseOverride && me.mouseValid
				me.xFinal = me.mouseX; me.yFinal = me.mouseY;
			else
				sP = getP(me, 'startPosition');
				if isprop(me,'direction')
					[dx, dy]=pol2cart(me.d2r(getP(me,'direction')), sP);
				else
					[dx, dy]=pol2cart(me.d2r(getP(me,'angle')), sP);
				end
				me.xFinal = me.xPositionOut + (dx * me.ppd) + me.sM.xCenter;
				me.yFinal = me.yPositionOut + (dy * me.ppd) + me.sM.yCenter;
				me.xFinalD = me.sM.toDegrees(me.xFinal,'x');
				me.yFinalD = me.sM.toDegrees(me.yFinal,'y');
				if me.verbose; fprintf('---> computePosition: %s X = %gpx | %gpx | %gdeg <> Y = %gpx | %gpx | %gdeg\n',me.fullName, me.xFinal, me.xPositionOut, dx, me.yFinal, me.yPositionOut, dy); end
			end
			setAnimationDelta(me);
		end

		% ===================================================================
		%> @fn setAnimationDelta
		%> setAnimationDelta for performance better not to use get methods for dX dY and
		%> delta during animation, so we have to cache these properties to private copies so that
		%> when we call the animate method, it uses the cached versions not the
		%> public versions. This method simply copies the properties to their cached
		%> equivalents.
		% ===================================================================
		function setAnimationDelta(me)
			me.delta_ = me.delta;
			me.dX_ = me.dX;
			me.dY_ = me.dY;
		end

		% ===================================================================
		%> @fn setRect
		%> setRect makes the PsychRect based on the texture and screen
		%> values, you should call computePosition() first to get xFinal and
		%> yFinal.
		% ===================================================================
		function setRect(me)
			if isempty(me.texture); me.mvRect = [0 0 100 100]; return; end
			if isprop(me,'scale')
				me.dstRect = ScaleRect(Screen('Rect',me.texture(1)), me.scale, me.scale);
			else
				me.dstRect=Screen('Rect',me.texture(1));
			end
			if me.mouseOverride && me.mouseValid
				me.dstRect = CenterRectOnPointd(me.dstRect, me.mouseX, me.mouseY);
			else
				me.dstRect=CenterRectOnPointd(me.dstRect, me.xFinal, me.yFinal);
			end
			me.mvRect=me.dstRect;
			if me.isRect; me.szPx=RectWidth(me.mvRect); end
			if me.verbose
				fprintf('---> %s setRect = [%.2f %.2f %.2f %.2f] width = %.2f height = %.2f\n',...
					me.fullName, me.dstRect(1), me.dstRect(2),me.dstRect(3),me.dstRect(4),...
					RectWidth(me.dstRect),RectHeight(me.dstRect));
			end
		end

		% ===================================================================
		%> @fn toStructure
		%> @brief Converts properties to a structure
		%>
		%> @param me this instance object
		%> @param tmp is whether to use the temporary or permanent properties
		%> @return out the structure
		% ===================================================================
		function out=toStructure(me,tmp)
			if ~exist('tmp','var')
				tmp = 0; %copy real properties, not temporary ones
			end
			fn = fieldnames(me);
			for j=1:length(fn)
				if tmp == 0
					out.(fn{j}) = me.(fn{j});
				else
					out.(fn{j}) = me.([fn{j} 'Out']);
				end
			end
		end

		% ===================================================================
		%> @fn removeTmpProperties
		%> @brief Finds and removes dynamic properties
		%>
		%> @param me
		%> @return
		% ===================================================================
		function removeTmpProperties(me)
			allprops = properties(me);
			for i=1:numel(allprops)
				m = findprop(me, allprops{i});
				if isa(m,'meta.DynamicProperty')
					delete(m)
				end
			end
			me.xFinal	= [];
			me.xFinalD	= [];
			me.yFinal	= [];
			me.yFinalD	= [];
			me.szPx		= [];
			me.isSetup	= false;
		end

		% ===================================================================
		%> @fn Delete method
		%>
		%> @param me
		%> @return
		% ===================================================================
		function delete(me)
			if ~isempty(me.texture)
				for i = 1:length(me.texture)
					if Screen(me.texture, 'WindowKind')~=0 ;try Screen('Close',me.texture); end; end %#ok<*TRYNC>
				end
			end
			if isprop(me,'buffertex') && ~isempty(me.buffertex)
				if Screen(me.buffertex, 'WindowKind')~=0 ; try Screen('Close',me.buffertex); end; end
			end
			
			if me.verbose; fprintf('--->>> Delete: %s\n',me.fullName); end
		end
		
	end%---END PRIVATE METHODS---%
end

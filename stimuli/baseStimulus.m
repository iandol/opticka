% ========================================================================
%> @brief baseStimulus is the superclass for all opticka stimulus objects
%>
%> Superclass providing basic structure for all stimulus classes. This is a dynamic properties
%> descendant, allowing for the temporary run variables used, which get appended "name"Out, i.e.
%> speed is duplicated to a dymanic property called speedOut; it is the dynamic propertiy which is
%> used during runtime, and whose values are converted from definition units like degrees to pixel
%> values that PTB uses. The transient copies are generated on setup and removed on reset.
%>
% ========================================================================
classdef baseStimulus < optickaCore & dynamicprops
	
	properties (Abstract = true, SetAccess = protected)
		%> the stimulus family
		family
	end
	
	properties
		%> X Position in degrees relative to screen center
		xPosition = 0
		%> Y Position in degrees relative to screen center
		yPosition = 0
		%> Size in degrees
		size = 4
		%> Colour as a 0-1 range RGBA
		colour = [0.5 0.5 0.5]
		%> Alpha as a 0-1 range
		alpha = 1
		%> Do we print details to the commandline?
		verbose = false
		%> For moving stimuli do we start "before" our initial position?
		startPosition = 0
		%> speed in degs/s
		speed = 0
		%> angle in degrees
		angle = 0
		%> delay time to display, can set upper and lower range for random interval
		delayTime = 0
		%> time to turn stimulus off
		offTime = Inf
		%> override X and Y position with mouse input?
		mouseOverride = false
		%> true or false, whether to draw() this object
		isVisible = true
	end
	
	properties (SetAccess = protected, GetAccess = public)
		%> Our source screen rectangle position in PTB format
		dstRect
		%> Our screen rectangle position in PTB format, update during animations
		mvRect
		%> tick updates +1 on each draw, resets on each update
		tick = 1
		%> pixels per degree (normally inhereted from screenManager)
		ppd = 44
	end
	
	properties (SetAccess = protected, GetAccess = public, Transient = true)
		%> Our texture pointer for texture-based stimuli
		texture
		%> handles for the GUI
		handles
		%> our screen manager
		sM
	end
	
	properties (Dependent = true, SetAccess = private, GetAccess = public)
		%> What our per-frame motion delta is
		delta
		%> X update which is computed from our speed and angle
		dX
		%> X update which is computed from our speed and angle
		dY
	end
	
	properties (SetAccess = protected, GetAccess = protected)
		%> computed X position for stimuli that don't use rects
		xOut = 0
		%> computed Y position for stimuli that don't use rects
		yOut = 0
		%> is mouse position within screen co-ordinates?
		mouseValid = false
		%> mouse X position
		mouseX = 0
		%> mouse Y position
		mouseY = 0
		%> delay ticks to wait until display
		delayTicks = 0
		%> ticks before stimulus turns off
		offTicks = Inf
		%>are we setting up?
		inSetup = false
		%> delta cache
		delta_
		%> dX cache
		dX_
		%> dY cache
		dY_
		%> Which properties to ignore to clone when making transient copies in
		%> the setup method
		ignorePropertiesBase='handles|ppd|sM|name|comment|fullName|family|type|dX|dY|delta|verbose|texture|dstRect|mvRect|isVisible|dateStamp|paths|uuid|tick';
	end
	
	properties (SetAccess = private, GetAccess = private)
		%> properties allowed to be passed on construction
		allowedProperties='xPosition|yPosition|size|colour|verbose|alpha|startPosition|angle|speed|delayTime|mouseOverride|isVisible'
	end
	
	events
		%> triggered when reading from a UI panel,
		readPanelUpdate
	end
	
	%=======================================================================
	methods %------------------PUBLIC METHODS
		%=======================================================================
		
		% ===================================================================
		%> @brief Class constructor
		
		%>
		%> @param varargin are passed as a structure / cell of properties which is
		%> parsed.
		%> @return instance of class.
		% ===================================================================
		function obj = baseStimulus(varargin)
			if nargin == 0; varargin.name = 'baseStimulus'; end
			obj=obj@optickaCore(varargin); %superclass constructor
			
			if nargin > 0; obj.parseArgs(varargin,obj.allowedProperties); end
			
			if isempty(obj.sM) %add a default screenManager, overwritten on setup
				obj.sM = screenManager('verbose',false,'name','default');
				obj.ppd = obj.sM.ppd;
			end
		end
		
		% ===================================================================
		%> @brief colour Get method
		%> Allow 1 (R=G=B) 3 (RGB) or 4 (RGBA) value colour
		% ===================================================================
		function value = get.colour(obj)
			len=length(obj.colour);
			if len == 4 || len == 3
				value = [obj.colour(1:3) obj.alpha]; %force our alpha to override
			elseif len == 1
				value = [obj.colour obj.colour obj.colour obj.alpha]; %construct RGBA
			else
				if isa(obj,'gaborStimulus') || isa(obj,'gratingStimulus')
					value = []; %return no colour to procedural gratings
				else
					value = [1 1 1 obj.alpha]; %return white for everything else
				end
			end
		end
		
		% ===================================================================
		%> @brief delta Get method
		%> delta is the normalised number of pixels per frame to move a stimulus
		% ===================================================================
		function value = get.delta(obj)
			if isempty(obj.findprop('speedOut'));
				value = (obj.speed * obj.ppd) * obj.sM.screenVals.ifi;
			else
				value = (obj.speedOut * obj.ppd) * obj.sM.screenVals.ifi;
			end
		end
		
		% ===================================================================
		%> @brief dX Get method
		%> X position increment for a given delta and angle
		% ===================================================================
		function value = get.dX(obj)
			if ~isempty(obj.findprop('motionAngle'))
				if isempty(obj.findprop('motionAngleOut'));
					[value,~]=obj.updatePosition(obj.delta,obj.motionAngle);
				else
					[value,~]=obj.updatePosition(obj.delta,obj.motionAngleOut);
				end
			else
				if isempty(obj.findprop('angleOut'));
					[value,~]=obj.updatePosition(obj.delta,obj.angle);
				else
					[value,~]=obj.updatePosition(obj.delta,obj.angleOut);
				end
			end
		end
		
		% ===================================================================
		%> @brief dY Get method
		%> Y position increment for a given delta and angle
		% ===================================================================
		function value = get.dY(obj)
			if ~isempty(obj.findprop('motionAngle'))
				if isempty(obj.findprop('motionAngleOut'));
					[~,value]=obj.updatePosition(obj.delta,obj.motionAngle);
				else
					[~,value]=obj.updatePosition(obj.delta,obj.motionAngleOut);
				end
			else
				if isempty(obj.findprop('angleOut'));
					[~,value]=obj.updatePosition(obj.delta,obj.angle);
				else
					[~,value]=obj.updatePosition(obj.delta,obj.angleOut);
				end
			end
		end
		
		% ===================================================================
		%> @brief Shorthand to set isVisible=true.
		%>
		% ===================================================================
		function show(obj)
			obj.isVisible = true;
		end
		
		% ===================================================================
		%> @brief Shorthand to set isVisible=false.
		%>
		% ===================================================================
		function hide(obj)
			obj.isVisible = false;
		end
		
		% ===================================================================
		%> @brief we reset the various tick counters for our stimulus
		%>
		% ===================================================================
		function resetTicks(obj)
			global mouseTick %shared across all stimuli
			if max(obj.delayTime) > 0 %delay display a number of frames 
				if length(obj.delayTime) == 1
					obj.delayTicks = round(obj.delayTime/obj.sM.screenVals.ifi);
				elseif length(obj.delayTime) == 2
					time = randi([obj.delayTime(1)*1000 obj.delayTime(2)*1000])/1000;
					obj.delayTicks = round(time/obj.sM.screenVals.ifi);
				end
			else
				obj.delayTicks = 0;
			end
			if min(obj.offTime) < Inf %delay display a number of frames 
				if length(obj.offTime) == 1
					obj.offTicks = round(obj.offTime/obj.sM.screenVals.ifi);
				elseif length(obj.offTime) == 2
					time = randi([obj.offTime(1)*1000 obj.offTime(2)*1000])/1000;
					obj.offTicks = round(time/obj.sM.screenVals.ifi);
				end
			else
				obj.offTicks = Inf;
			end
			mouseTick = 1;
			if obj.mouseOverride
				getMousePosition(obj);
			end
			obj.tick = 0; 
		end
		
		% ===================================================================
		%> @brief get mouse position
		%> we make sure this is only called once per animation tick to
		%> improve performance and ensure all stimuli that are following
		%> mouse position have consistent X and Y per frame update
		%> This sets mouseX and mouseY and mouseValid if mouse is within
		%> PTB screen (useful for mouse override positioning for stimuli)
		% ===================================================================
		function getMousePosition(obj)
			global mouseTick
			obj.mouseValid = false;
			if obj.tick > mouseTick
				if isa(obj.sM,'screenManager') && obj.sM.isOpen
					[obj.mouseX,obj.mouseY] = GetMouse(obj.sM.win);
					if obj.mouseX <= obj.sM.screenVals.width && obj.mouseY <= obj.sM.screenVals.height
						obj.mouseValid = true;
					end
				else
					[obj.mouseX,obj.mouseY] = GetMouse;
				end
				mouseTick = obj.tick; %set global so no other object with same tick number can call this again
			end
		end
		
		% ===================================================================
		%> @brief Run Stimulus in a window to preview
		%>
		% ===================================================================
		function run(obj,benchmark,runtime,s)
			try
				warning off
				if ~exist('benchmark','var') || isempty(benchmark)
					benchmark=false;
				end
				if ~exist('runtime','var') || isempty(runtime)
					runtime = 2; %seconds to run
				end
				if ~exist('s','var') || ~isa(s,'screenManager')
					s = screenManager('verbose',false,'blend',true,'screen',0,...
						'bitDepth','8bit','debug',false,...
						'backgroundColour',[0.5 0.5 0.5 0]); %use a temporary screenManager object
				end
				oldwindowed = s.windowed;
				if benchmark
					s.windowed = false;
				else
					wR = Screen('Rect',0);
					s.windowed = [wR(3)/2 wR(4)/2];
					%s.windowed = CenterRect([0 0 s.screenVals.width/2 s.screenVals.height/2], s.winRect); %middle of screen
				end
				open(s); %open PTB screen
				setup(obj,s); %setup our stimulus object
				draw(obj); %draw stimulus
				drawGrid(s); %draw +-5 degree dot grid
				drawScreenCenter(s); %centre spot
				if benchmark; 
					Screen('DrawText', s.win, 'Benchmark, screen will not update properly, see FPS on command window at end.', 5,5,[0 0 0]);
				else
					Screen('DrawText', s.win, 'Stimulus unanimated for 1 second, animated for 2, then unanimated for a final second...', 5,5,[0 0 0]);
				end
				Screen('Flip',s.win);
				WaitSecs(1);
				if benchmark; b=GetSecs; end
				for i = 1:(s.screenVals.fps*runtime) %should be 2 seconds worth of flips
					draw(obj); %draw stimulus
					if s.visualDebug
						drawGrid(s); %draw +-5 degree dot grid
						drawScreenCenter(s); %centre spot
					end
					Screen('DrawingFinished', s.win); %tell PTB/GPU to draw
					animate(obj); %animate stimulus, will be seen on next draw
					if benchmark
						Screen('Flip',s.win,0,2,2);
					else
						Screen('Flip',s.win); %flip the buffer
					end
				end
				if benchmark; bb=GetSecs; end
				WaitSecs(1);
				Screen('Flip',s.win);
				WaitSecs(0.25);
				if benchmark
					fps = (s.screenVals.fps*runtime) / (bb-b);
					fprintf('\n------> SPEED = %g fps\n', fps);
				end
				s.windowed = oldwindowed;
				close(s); %close screen
				clear s fps benchmark runtime b bb i; %clear up a bit
				reset(obj); %reset our stimulus ready for use again
				warning on
			catch ME
				if exist('s','var')
					close(s);
				end
				warning on
				clear s fps benchmark runtime b bb i; %clear up a bit
				reset(obj); %reset our stimulus ready for use again
				rethrow(ME)				
			end
		end
		
		% ===================================================================
		%> @brief make a GUI properties panel for this object
		%>
		% ===================================================================
		function handles = makePanel(obj, parent)
			
			if ~isempty(obj.handles) && isa(obj.handles.root,'uiextras.BoxPanel') && ishandle(obj.handles.root)
				fprintf('---> Panel already open for %s\n', obj.fullName);
				return
			end
			
			if ~exist('parent','var')
				parent = figure('Tag','gFig',...
					'Name', [obj.fullName 'Properties'], ...
					'CloseRequestFcn', @obj.closePanel,...
					'MenuBar', 'none', ...
					'NumberTitle', 'off');
				figpos(1,[800 300]);
			end
			
			bgcolor = [0.91 0.91 0.91];
			bgcoloredit = [0.95 0.95 0.95];
			fsmall = 10;
			SansFont = 'Calibri';
			MonoFont = 'Menlo';
			
			handles.parent = parent;
			handles.root = uiextras.BoxPanel('Parent',parent,...
				'Title',obj.fullName,...
				'FontName',SansFont,...
				'FontSize',fsmall,...
				'FontWeight','normal',...
				'Padding',0,...
				'TitleColor',[0.8 0.78 0.76],...
				'BackgroundColor',bgcolor);
			handles.hbox = uiextras.HBox('Parent', handles.root,'Padding',1,'Spacing',1,'BackgroundColor',bgcolor);
			handles.grid1 = uiextras.Grid('Parent', handles.hbox,'Padding',1,'Spacing',1,'BackgroundColor',bgcolor);
			handles.grid2 = uiextras.Grid('Parent', handles.hbox,'Padding',1,'Spacing',1,'BackgroundColor',bgcolor);
			handles.grid3 = uiextras.VButtonBox('Parent',handles.hbox,'Padding',0,...
				'ButtonSize', [100 25],'Spacing',0,'BackgroundColor',bgcolor);
			set(handles.hbox,'Sizes', [-1 -1 102]);
			
			idx = {'handles.grid1','handles.grid2','handles.grid3'};
			
			pr = findAttributesandType(obj,'SetAccess','public','notlogical');
			pr = sort(pr);
			lp = ceil(length(pr)/2);
			
			pr2 = findAttributesandType(obj,'SetAccess','public','logical');
			pr2 = sort(pr2);
			lp2 = length(pr2);

			for i = 1:2
				for j = 1:lp
					cur = lp*(i-1)+j;
					if cur <= length(pr);
						val = obj.(pr{cur});
						if ischar(val)
							if isprop(obj,[pr{cur} 'List'])
								if strcmp(obj.([pr{cur} 'List']),'filerequestor')
									val = regexprep(val,'\s+',' ');
									handles.([pr{cur} '_char']) = uicontrol('Style','edit',...
										'Parent',eval(idx{i}),...
										'Tag',['panel' pr{cur}],...
										'Callback',@obj.readPanel,...
										'String',val,...
										'FontName',MonoFont,...
										'BackgroundColor',bgcoloredit);
								else
									txt=obj.([pr{cur} 'List']);
									fidx = strcmpi(txt,obj.(pr{cur}));
									fidx = find(fidx > 0);
									handles.([pr{cur} '_list']) = uicontrol('Style','popupmenu',...
										'Parent',eval(idx{i}),...
										'Tag',['panel' pr{cur} 'List'],...
										'String',txt,...
										'Callback',@obj.readPanel,...
										'Value',fidx,...
										'BackgroundColor',bgcolor);
								end
							else
								val = regexprep(val,'\s+',' ');
								handles.([pr{cur} '_char']) = uicontrol('Style','edit',...
									'Parent',eval(idx{i}),...
									'Tag',['panel' pr{cur}],...
									'Callback',@obj.readPanel,...
									'String',val,...
									'BackgroundColor',bgcoloredit);
							end
						elseif isnumeric(val)
							val = num2str(val);
							val = regexprep(val,'\s+',' ');
							handles.([pr{cur} '_num']) = uicontrol('Style','edit',...
								'Parent',eval(idx{i}),...
								'Tag',['panel' pr{cur}],...
								'String',val,...
								'Callback',@obj.readPanel,...
								'FontName',MonoFont,...
								'BackgroundColor',bgcoloredit);
						else
							uiextras.Empty('Parent',eval(idx{i}),'BackgroundColor',bgcolor);
						end
					else
						uiextras.Empty('Parent',eval(idx{i}),'BackgroundColor',bgcolor);
					end
				end
				
				for j = 1:lp
					cur = lp*(i-1)+j;
					if cur <= length(pr);
						if isprop(obj,[pr{cur} 'List'])
							if strcmp(obj.([pr{cur} 'List']),'filerequestor')
								uicontrol('Style','pushbutton',...
								'Parent',eval(idx{i}),...
								'HorizontalAlignment','left',...
								'String','Select file...',...
								'FontName',SansFont,...
								'Tag',[pr{cur} '_button'],...
								'Callback',@obj.selectFilePanel,...
								'FontSize', fsmall);
							else
								uicontrol('Style','text',...
								'Parent',eval(idx{i}),...
								'HorizontalAlignment','left',...
								'String',pr{cur},...
								'FontName',SansFont,...
								'FontSize', fsmall,...
								'BackgroundColor',bgcolor);
							end
						else
							uicontrol('Style','text',...
							'Parent',eval(idx{i}),...
							'HorizontalAlignment','left',...
							'String',pr{cur},...
							'FontName',SansFont,...
							'FontSize', fsmall,...
							'BackgroundColor',bgcolor);
						end
					else
						uiextras.Empty('Parent',eval(idx{i}),...
							'BackgroundColor',bgcolor);
					end
				end
				set(eval(idx{i}),'ColumnSizes',[-2 -1]);
			end
			for j = 1:lp2
				val = obj.(pr2{j});
				if j <= length(pr2)
					handles.([pr2{j} '_bool']) = uicontrol('Style','checkbox',...
						'Parent',eval(idx{end}),...
						'Tag',['panel' pr2{j}],...
						'String',pr2{j},...
						'FontName',SansFont,...
						'FontSize', fsmall,...
						'Value',val,...
						'BackgroundColor',bgcolor);
				end
			end
			handles.readButton = uicontrol('Style','pushbutton',...
				'Parent',eval(idx{end}),...
				'Tag','readButton',...
				'Callback',@obj.readPanel,...
				'String','Update');
			obj.handles = handles;
			
		end
		
		% ===================================================================
		%> @brief read values from a GUI properties panel for this object
		%>
		% ===================================================================
		function selectFilePanel(obj,varargin)
			if nargin > 0
				hin = varargin{1};
				if ishandle(hin)
					[f,p] = uigetfile('*.*','Select File:');
					re = regexp(get(hin,'Tag'),'(.+)_button','tokens','once');
					hout = obj.handles.([re{1} '_char']);
					if ishandle(hout)
						set(hout,'String', [p f]);
					end
				end
			end
		end
		
		% ===================================================================
		%> @brief read values from a GUI properties panel for this object
		%>
		% ===================================================================
		function readPanel(obj,varargin)
			if isempty(obj.handles) || ~isa(obj.handles.root,'uiextras.BoxPanel')
				return
			end
				
			pList = findAttributes(obj,'SetAccess','public'); %our public properties
			dList = findAttributes(obj,'Dependent', true); %find dependent properties
			pList = setdiff(pList,dList); %remove dependent properties as we don't want to set them!
			handleList = fieldnames(obj.handles); %the handle name list
			handleListMod = regexprep(handleList,'_.+$',''); %we remove the suffix so names are equivalent
			outList = intersect(pList,handleListMod);
			
			for i=1:length(outList)
				hidx = strcmpi(handleListMod,outList{i});
				handleNameOut = handleListMod{hidx};
				handleName = handleList{hidx};
				handleType = regexprep(handleName,'^.+_','');
				while iscell(handleType);handleType=handleType{1};end
				switch handleType
					case 'list'
						str = get(obj.handles.(handleName),'String');
						v = get(obj.handles.(handleName),'Value');
						obj.(handleNameOut) = str{v};
					case 'bool'
						obj.(handleNameOut) = logical(get(obj.handles.(handleName),'Value'));
						if isempty(obj.(handleNameOut))
							obj.(handleNameOut) = false;
						end
					case 'num'
						val = get(obj.handles.(handleName),'String');
						if strcmpi(val,'true') %convert to logical
							obj.(handleNameOut) = true;
						elseif strcmpi(val,'false') %convert to logical
							obj.(handleNameOut) = true;
						else
							obj.(handleNameOut) = str2num(val); %#ok<ST2NM>
						end
					case 'char'
						obj.(handleNameOut) = get(obj.handles.(handleName),'String');
				end
			end
			notify(obj,'readPanelUpdate');
		end
			
		% ===================================================================
		%> @brief show GUI properties panel for this object
		%>
		% ===================================================================
		function showPanel(obj)
			if isempty(obj.handles)
				return
			end
			set(obj.handles.root,'Enable','on');
			set(obj.handles.root,'Visible','on');
		end
		
		% ===================================================================
		%> @brief hide GUI properties panel for this object
		%>
		% ===================================================================
		function hidePanel(obj)
			if isempty(obj.handles)
				return
			end
			set(obj.handles.root,'Enable','off');
			set(obj.handles.root,'Visible','off');
		end
		
		% ===================================================================
		%> @brief close GUI panel for this object
		%>
		% ===================================================================
		function closePanel(obj,varargin)
			if isempty(obj.handles)
				return
			end
			if isfield(obj.handles,'root') && isgraphics(obj.handles.root)
				readPanel(obj);
				delete(obj.handles.root);
			end
			if isfield(obj.handles,'parent') && isgraphics(obj.handles.parent,'figure')
				delete(obj.handles.parent)
			end
			obj.handles = [];
		end
		
		% ===================================================================
		%> @brief checkPaths
		%>
		%> @param
		%> @return
		% ===================================================================
		function varargout=cleanHandles(obj,varargin)
			if isprop(obj,'handles')
				obj.handles = [];
			end
			if isprop(obj,'h')
				obj.handles = [];
			end
		end
		
	end %---END PUBLIC METHODS---%
	
	%=======================================================================
	methods (Abstract)%------------------ABSTRACT METHODS
	%=======================================================================
		%> initialise the stimulus
		out = setup(runObject)
		%> update the stimulus
		out = update(runObject)
		%>draw to the screen buffer
		out = draw(runObject)
		%> animate the settings
		out = animate(runObject)
		%> reset to default values
		out = reset(runObject)
	end %---END ABSTRACT METHODS---%
	
	%=======================================================================
	methods ( Static ) %----------STATIC METHODS
	%=======================================================================
		
		% ===================================================================
		%> @brief degrees2radians
		%>
		% ===================================================================
		function r = d2r(degrees)
			r=degrees*(pi/180);
		end
		
		% ===================================================================
		%> @brief radians2degrees
		%>
		% ===================================================================
		function degrees=r2d(r)
			degrees=r*(180/pi);
		end
		
		% ===================================================================
		%> @brief findDistance in X and Y coordinates
		%>
		% ===================================================================
		function distance=findDistance(x1,y1,x2,y2)
			dx = x2 - x1;
			dy = y2 - y1;
			distance=sqrt(dx^2 + dy^2);
		end
		
		% ===================================================================
		%> @brief updatePosition returns dX and dY given an angle and delta
		%>
		% ===================================================================
		function [dX, dY] = updatePosition(delta,angle)
			dX = delta .* cos(baseStimulus.d2r(angle));
			dY = delta .* sin(baseStimulus.d2r(angle));
		end
		
	end%---END STATIC METHODS---%
	
	%=======================================================================
	methods ( Access = protected ) %-------PRIVATE (protected) METHODS-----%
	%=======================================================================
		
		% ===================================================================
		%> @brief setRect
		%> setRect makes the PsychRect based on the texture and screen
		%> values, you should call computePosition() first to get xOut and
		%> yOut
		% ===================================================================
		function setRect(obj)
			if ~isempty(obj.texture)
				obj.dstRect=Screen('Rect',obj.texture);
				if obj.mouseOverride && obj.mouseValid
					obj.dstRect = CenterRectOnPointd(obj.dstRect, obj.mouseX, obj.mouseY);
				else
					obj.dstRect=CenterRectOnPointd(obj.dstRect, obj.xOut, obj.yOut);
				end
				obj.mvRect=obj.dstRect;
			end
		end
		
		% ===================================================================
		%> @brief setAnimationDelta
		%> setAnimationDelta for performance better not to use get methods for dX dY and
		%> delta during animation, so we have to cache these properties to private copies so that
		%> when we call the animate method, it uses the cached versions not the
		%> public versions. This method simply copies the properties to their cached
		%> equivalents.
		% ===================================================================
		function setAnimationDelta(obj)
			obj.delta_ = obj.delta;
			obj.dX_ = obj.dX;
			obj.dY_ = obj.dY;
		end
		
		% ===================================================================
		%> @brief compute xOut and yOut
		%>
		% ===================================================================
		function computePosition(obj)
			if obj.mouseOverride && obj.mouseValid
				obj.xOut = obj.mouseX; obj.yOut = obj.mouseY;
			else
				if isempty(obj.findprop('angleOut'));
					[dx, dy]=pol2cart(obj.d2r(obj.angle),obj.startPosition);
				else
					[dx, dy]=pol2cart(obj.d2r(obj.angleOut),obj.startPositionOut);
				end
				obj.xOut = obj.xPositionOut + (dx * obj.ppd) + obj.sM.xCenter;
				obj.yOut = obj.yPositionOut + (dy * obj.ppd) + obj.sM.yCenter;
				if obj.verbose; fprintf('--->computePosition: %s X = %gpx / %gpx / %gdeg | Y = %gpx / %gpx / %gdeg\n',obj.fullName, obj.xOut, obj.xPositionOut, dx, obj.yOut, obj.yPositionOut, dy); end
			end
			setAnimationDelta(obj);
		end
		
		% ===================================================================
		%> @brief xPositionOut Set method
		%>
		% ===================================================================
		function set_xPositionOut(obj,value)
			obj.xPositionOut = value*obj.ppd;
			if ~obj.inSetup; obj.setRect; end
		end
		
		% ===================================================================
		%> @brief yPositionOut Set method
		%>
		% ===================================================================
		function set_yPositionOut(obj,value)
			obj.yPositionOut = value*obj.ppd;
			if ~obj.inSetup; obj.setRect; end
		end
		
		% ===================================================================
		%> @brief Converts properties to a structure
		%>
		%>
		%> @param obj this instance object
		%> @param tmp is whether to use the temporary or permanent properties
		%> @return out the structure
		% ===================================================================
		function out=toStructure(obj,tmp)
			if ~exist('tmp','var')
				tmp = 0; %copy real properties, not temporary ones
			end
			fn = fieldnames(obj);
			for j=1:length(fn)
				if tmp == 0
					out.(fn{j}) = obj.(fn{j});
				else
					out.(fn{j}) = obj.([fn{j} 'Out']);
				end
			end
		end
		
		% ===================================================================
		%> @brief Finds and removes transient properties
		%>
		%> @param obj
		%> @return
		% ===================================================================
		function removeTmpProperties(obj)
			fn=fieldnames(obj);
			for i=1:length(fn)
				if ~isempty(regexp(fn{i},'Out$','once'))
					delete(obj.findprop(fn{i}));
				end
			end
		end
		
	end%---END PRIVATE METHODS---%
end
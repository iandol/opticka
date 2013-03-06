% ========================================================================
%> @brief single bar stimulus, inherits from baseStimulus
%> SPOTSTIMULUS single bar stimulus, inherits from baseStimulus
%>   The current properties are:
% ========================================================================
classdef spotStimulus < baseStimulus
	
	properties %--------------------PUBLIC PROPERTIES----------%
		%> type can be "simple" or "flash"
		type = 'simple'
		%> time to flash on and off in seconds
		flashTime = [0.5 0.5]
		%> is the ON flash the first flash we see?
		flashOn = true
		%> contrast is realy a multiplier to the stimulus colour, not
		%> formally defined contrast in this case
		contrast = 1
		%> colour for flash, empty to inherit from screen background with 0 alpha
		flashOffColour = []
	end
	
	properties (SetAccess = protected, GetAccess = public)
		%> stimulus family
		family = 'spot'
	end
	
	properties (SetAccess = private, GetAccess = public, Hidden = true)
		typeList = {'simple','flash'}
	end
	
	properties (Dependent = true, SetAccess = private, GetAccess = private)
		%> a dependant property to track when to switch from ON to OFF of
		%flash.
		flashSwitch
	end
	
	properties (SetAccess = private, GetAccess = private)
		%> internal counter
		flashCounter = 1
		%> the OFF colour of the flash, usually this is set to the screen background
		flashBG = [0.5 0.5 0.5]
		%> ON flash colour, reset on setup
		flashFG = [1 1 1]
		currentColour = [1 1 1]
		colourOutTemp = [1 1 1]
		stopLoop = false
		allowedProperties='type|flashTime|flashOn|flashOffColour|contrast'
		ignoreProperties = 'flashSwitch|FlashOn';
	end
	
	events
		%> triggered when changing size, so we can change sf etc to compensate
		changeColour
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
		function obj = spotStimulus(varargin)
			%Initialise for superclass, stops a noargs error
			if nargin == 0; varargin.family = 'spot'; end
			
			obj=obj@baseStimulus(varargin); %we call the superclass constructor first
			obj.colour = [1 1 1];
			
			if nargin>0
				obj.parseArgs(varargin, obj.allowedProperties);
			end
			
			obj.ignoreProperties = ['^(' obj.ignorePropertiesBase '|' obj.ignoreProperties ')$'];
			obj.salutation('constructor','Stimulus initialisation complete');
		end
		
		% ===================================================================
		%> @brief Setup an structure for runExperiment
		%>
		%> @param sM handle to the current screenManager object
		% ===================================================================
		function setup(obj,sM)
			
			reset(obj);
			obj.inSetup = true;
			if isempty(obj.isVisible)
				obj.show;
			end
			
			addlistener(obj,'changeColour',@obj.computeColour);
			
			obj.sM = [];
			obj.sM = sM;
			obj.ppd=sM.ppd;
			
			fn = fieldnames(spotStimulus);
			for j=1:length(fn)
				if isempty(obj.findprop([fn{j} 'Out'])) && isempty(regexp(fn{j},obj.ignoreProperties, 'once'))%create a temporary dynamic property
					p=obj.addprop([fn{j} 'Out']);
					p.Transient = true;%p.Hidden = true;
					if strcmp(fn{j},'size');p.SetMethod = @set_sizeOut;end
					if strcmp(fn{j},'xPosition');p.SetMethod = @set_xPositionOut;end
					if strcmp(fn{j},'yPosition');p.SetMethod = @set_yPositionOut;end
					if strcmp(fn{j},'colour');p.SetMethod = @set_colourOut;end
					if strcmp(fn{j},'contrast');p.SetMethod = @set_contrastOut;end
				end
				if isempty(regexp(fn{j},obj.ignoreProperties, 'once'))
					obj.([fn{j} 'Out']) = obj.(fn{j}); %copy our property value to our tempory copy
				end
			end
			
			if isempty(obj.findprop('doFlash'));p=obj.addprop('doFlash');p.Transient = true;end
			if isempty(obj.findprop('doDots'));p=obj.addprop('doDots');p.Transient = true;end
			if isempty(obj.findprop('doMotion'));p=obj.addprop('doMotion');p.Transient = true;end
			if isempty(obj.findprop('doDrift'));p=obj.addprop('doDrift');p.Transient = true;end
			obj.doDots = false;
			obj.doMotion = false;
			obj.doDrift = false;
			obj.doFlash = false;
			
			if obj.speedOut > 0; obj.doMotion = true; end
			
			if strcmpi(obj.type,'flash')
				obj.doFlash = true;
				if ~isempty(obj.flashOffColour)
					obj.flashBG = [obj.flashOffColour(1:3) 0];
				else
					obj.flashBG = [obj.sM.backgroundColour(1:3) 0]; %make sure alpha is 0
				end
				setupFlash(obj);
			end
			
			obj.inSetup = false;
			
			computePosition(obj);
			setAnimationDelta(obj);
		end
		
		% ===================================================================
		%> @brief Update a structure for runExperiment
		%>
		%> @param
		%> @return
		% ===================================================================
		function update(obj)
			resetTicks(obj);
			computePosition(obj);
			setAnimationDelta(obj);
			if obj.doFlash
				obj.resetFlash;
			end
		end
		
		% ===================================================================
		%> @brief Draw an structure for runExperiment
		%>
		%> @param sM runExperiment object for reference
		%> @return stimulus structure.
		% ===================================================================
		function draw(obj)
			if obj.isVisible && obj.tick >= obj.delayTicks
				if obj.doFlash == false
					Screen('gluDisk',obj.sM.win,obj.colourOut,obj.xOut,obj.yOut,obj.sizeOut/2);
				else
					Screen('gluDisk',obj.sM.win,obj.currentColour,obj.xOut,obj.yOut,obj.sizeOut/2);
				end
				obj.tick = obj.tick + 1;
			end
		end
		
		% ===================================================================
		%> @brief Animate an structure for runExperiment
		%>
		%> @param sM runExperiment object for reference
		%> @return stimulus structure.
		% ===================================================================
		function animate(obj)
			if obj.isVisible && obj.tick >= obj.delayTicks
				if obj.mouseOverride
					getMousePosition(obj);
					if obj.mouseValid
						obj.xOut = obj.mouseX;
						obj.yOut = obj.mouseY;
					end
				end
				if obj.doMotion == true
					obj.xOut = obj.xOut + obj.dX_;
					obj.yOut = obj.yOut + obj.dY_;
				end
				if obj.doFlash == true
					if obj.flashCounter <= obj.flashSwitch
						obj.flashCounter=obj.flashCounter+1;
					else
						obj.flashCounter = 1;
						obj.flashOnOut = ~obj.flashOnOut;
						if obj.flashOnOut == true
							obj.currentColour = obj.flashFG;
						else
							obj.currentColour = obj.flashBG;
							%fprintf('Current: %s | %s\n',num2str(obj.colourOut), num2str(obj.flashOnOut));
						end
					end
				end
			end
		end
		
		% ===================================================================
		%> @brief Reset an structure for runExperiment
		%>
		%> @param sM runExperiment object for reference
		%> @return stimulus structure.
		% ===================================================================
		function reset(obj)
			resetTicks(obj);
			obj.texture=[];
			obj.removeTmpProperties;
		end
		
		% ===================================================================
		%> @brief flashSwitch Get method
		%>
		% ===================================================================
		function flashSwitch = get.flashSwitch(obj)
			if isempty(obj.findprop('flashOnOut'))
				trigger = obj.flashOn;
			else
				trigger = obj.flashOnOut;
			end
			if trigger
				flashSwitch = round(obj.flashTime(1) / obj.sM.screenVals.ifi);
			else
				flashSwitch = round(obj.flashTime(2) / obj.sM.screenVals.ifi);
			end
		end
		
		
	end %---END PUBLIC METHODS---%
	
	%=======================================================================
	methods ( Access = private ) %-------PRIVATE METHODS-----%
		%=======================================================================
		% ===================================================================
		%> @brief sizeOut Set method
		%>
		% ===================================================================
		function set_sizeOut(obj,value)
			obj.sizeOut = value * obj.ppd; %divide by 2 to get diameter
		end
		
		% ===================================================================
		%> @brief colourOut SET method
		%>
		% ===================================================================
		function set_colourOut(obj, value)
			if length(value) == 1
				value = [value value value obj.alphaOut];
			end
			obj.colourOutTemp = value;
			obj.colourOut = value;
			if obj.stopLoop == false; notify(obj,'changeColour'); end
		end
		
		% ===================================================================
		%> @brief contrastOut SET method
		%>
		% ===================================================================
		function set_contrastOut(obj, value)
			obj.contrastOut = value;
			notify(obj,'changeColour');
		end
		
		% ===================================================================
		%> @brief computeColour triggered event
		%> Use an event to recalculate as get method is slower (called
		%> many more times), than an event which is only called on update
		% ===================================================================
		function computeColour(obj,~,~)
			if ~isempty(obj.findprop('contrastOut')) && ~isempty(obj.findprop('colourOut'))
				obj.stopLoop = true;
				obj.colourOut = [(obj.colourOutTemp(1:3) .* obj.contrastOut) obj.alpha];
				obj.stopLoop = false;
			end
		end
		
		% ===================================================================
		%> @brief setupFlash
		%>
		% ===================================================================
		function setupFlash(obj)
			obj.flashFG = obj.colourOut;
			obj.flashCounter = 1;
			if obj.flashOnOut == true
				obj.currentColour = obj.flashFG;
			else
				obj.currentColour = obj.flashBG;
			end
		end
		
		% ===================================================================
		%> @brief resetFlash
		%>
		% ===================================================================
		function resetFlash(obj)
			obj.flashFG = obj.colourOut;
			obj.flashOnOut = obj.flashOn;
			if obj.flashOnOut == true
				obj.currentColour = obj.flashFG;
			else
				obj.currentColour = obj.flashBG;
			end
			obj.flashCounter = 1;
		end
	end
end
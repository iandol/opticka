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
		%> contrast is actually a multiplier to the stimulus colour, not
		%> formally defined contrast in this case
		contrast = 1
	end
	
	properties (SetAccess = protected, GetAccess = public)
		%> stimulus family
		family = 'spot'
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
		allowedProperties='^(type|flashTime|flashOn|contrast|backgroundColour)$'
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
			if nargin == 0
				varargin.family = 'spot';
				varargin.colour = [1 1 1];
			end
			
			obj=obj@baseStimulus(varargin); %we call the superclass constructor first
			
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
			
			if isempty(obj.isVisible)
				obj.show;
			end
			
			addlistener(obj,'changeColour',@obj.computeColour);
			
			if exist('sM','var')
				obj.ppd=sM.ppd;
				obj.ifi=sM.screenVals.ifi;
				obj.xCenter=sM.xCenter;
				obj.yCenter=sM.yCenter;
				obj.win=sM.win;
			end
			
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
			
			if strcmp(obj.type,'flash')
				obj.doFlash = true;
				bg = [sM.backgroundColour(1:3) 0]; %make sure alpha is 0
				obj.setupFlash(bg);
			end
			
			if isempty(obj.findprop('xTmp'));p=obj.addprop('xTmp');p.Transient = true;end
			if isempty(obj.findprop('yTmp'));p=obj.addprop('yTmp');p.Transient = true;end
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
			if obj.isVisible == true
				if obj.doFlash == false
					Screen('gluDisk',obj.win,obj.colourOut,obj.xTmp,obj.yTmp,obj.sizeOut);
				else
					Screen('gluDisk',obj.win,obj.currentColour,obj.xTmp,obj.yTmp,obj.sizeOut);
				end
			end
		end
		
		% ===================================================================
		%> @brief Animate an structure for runExperiment
		%>
		%> @param sM runExperiment object for reference
		%> @return stimulus structure.
		% ===================================================================
		function animate(obj)
			if obj.doMotion == true
				obj.xTmp = obj.xTmp + obj.dX_;
				obj.yTmp = obj.yTmp + obj.dY_;
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
		
		% ===================================================================
		%> @brief Reset an structure for runExperiment
		%>
		%> @param sM runExperiment object for reference
		%> @return stimulus structure.
		% ===================================================================
		function reset(obj)
			obj.texture=[];
			obj.removeTmpProperties;
			delete(obj.findprop('xTmp'));
			delete(obj.findprop('yTmp'));
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
				flashSwitch = round(obj.flashTime(1) / obj.ifi);
			else
				flashSwitch = round(obj.flashTime(2) / obj.ifi);
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
			obj.sizeOut = (value*obj.ppd) / 2; %divide by 2 to get diameter
		end
		
		% ===================================================================
		%> @brief xPositionOut Set method
		%>
		% ===================================================================
		function set_xPositionOut(obj,value)
			obj.xPositionOut = (value*obj.ppd) + obj.xCenter;
			if ~isempty(obj.findprop('xTmp'));obj.computePosition;end
		end
		
		% ===================================================================
		%> @brief yPositionOut Set method
		%>
		% ===================================================================
		function set_yPositionOut(obj,value)
			obj.yPositionOut = (value*obj.ppd) + obj.yCenter;
			if ~isempty(obj.findprop('xTmp'));obj.computePosition;end
		end
		
		% ===================================================================
		%> @brief colourOut SET method
		%>
		% ===================================================================
		function set_colourOut(obj, value)
			if length(value) == 1
				value = [value value value];
			end
			obj.colourOutTemp = value;
			obj.colourOut = value;
			if obj.stopLoop == false;
				notify(obj,'changeColour');
			end
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
		function setupFlash(obj,bg)
			obj.flashFG = obj.colourOut;
			obj.flashBG = bg;
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
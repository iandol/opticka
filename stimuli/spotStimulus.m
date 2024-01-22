% ========================================================================
%> @brief single disc stimulus, inherits from baseStimulus
%> SPOTSTIMULUS single spot stimulus, inherits from baseStimulus
%>   The current properties are:
%>
%> Copyright ©2014-2022 Ian Max Andolina — released: LGPL3, see LICENCE.md
% ========================================================================
classdef spotStimulus < baseStimulus
	
	properties %--------------------PUBLIC PROPERTIES----------%
		%> type can be "simple" or "flash"
		type char = 'simple'
		%> colour for flash, empty to inherit from screen background with 0 alpha
		flashColour double = []
		%> time to flash on and off in seconds
		flashTime double {mustBeVector(flashTime)} = [0.25 0.25]
		%> is the ON flash the first flash we see?
		flashOn logical = true
		%> contrast scales from foreground to screen background colour
		contrast double {mustBeInRange(contrast,0,1)} = 1
	end
	
	properties (SetAccess = protected, GetAccess = public)
		%> stimulus family
		family char = 'spot'
	end
	
	properties (SetAccess = private, GetAccess = public, Hidden = true)
		typeList cell = {'simple','flash'}
	end
	
	properties (Dependent = true, SetAccess = private, GetAccess = private)
		%> a dependant property to track when to switch from ON to OFF of
		%flash.
		flashSwitch
	end
	
	properties (SetAccess = private, GetAccess = private)
		%> current flash state
		flashState
		%> internal counter
		flashCounter = 1
		%> the OFF colour of the flash, usually this is set to the screen background
		flashBG = [0.5 0.5 0.5]
		%> ON flash colour, reset on setup
		flashFG = [1 1 1]
		currentColour = [1 1 1]
		colourOutTemp = [1 1 1]
		flashColourOutTemp = [1 1 1]
		isInCompute = false
		allowedProperties={'type', 'flashTime', 'flashOn', 'flashColour', 'contrast'}
		ignoreProperties = {'flashSwitch','flashOn'}
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
		function me = spotStimulus(varargin)
			args = optickaCore.addDefaults(varargin,...
				struct('name','Spot','colour',[1 1 0 1]));
			me=me@baseStimulus(args); %we call the superclass constructor first
			me.parseArgs(args, me.allowedProperties);
			
			me.isRect = false; %uses a rect for drawing?

			me.ignoreProperties = [me.ignorePropertiesBase me.ignoreProperties];
			me.salutation('constructor','Stimulus initialisation complete');
		end
		
		% ===================================================================
		%> @brief Setup an structure for runExperiment
		%>
		%> @param sM handle to the current screenManager object
		% ===================================================================
		function setup(me,sM)
			
			reset(me); %reset object back to its initial state
			me.inSetup = true; me.isSetup = false;
			if isempty(me.isVisible); show(me); end
		
			me.sM = sM;
			if ~sM.isOpen; error('Screen needs to be Open!'); end
			me.ppd=sM.ppd;
			me.screenVals = sM.screenVals;
			me.texture = []; %we need to reset this
			
			fn = sort(properties(me));
			for j=1:length(fn)
				if ~matches(fn{j}, me.ignoreProperties)%create a temporary dynamic property
					p=me.addprop([fn{j} 'Out']);
					if strcmp(fn{j},'size'); p.SetMethod = @set_sizeOut; end
					if strcmp(fn{j},'xPosition'); p.SetMethod = @set_xPositionOut; end
					if strcmp(fn{j},'yPosition'); p.SetMethod = @set_yPositionOut; end
					if strcmp(fn{j},'colour'); p.SetMethod = @set_colourOut; end
					if strcmp(fn{j},'flashColour'); p.SetMethod = @set_flashColourOut; end
					if strcmp(fn{j},'contrast'); p.SetMethod = @set_contrastOut; end
					if strcmp(fn{j},'alpha'); p.SetMethod = @set_alphaOut; end
					me.([fn{j} 'Out']) = me.(fn{j}); %copy our property value to our tempory copy
				end
			end
			
			addRuntimeProperties(me);
			
			if me.doFlash
				if ~isempty(me.flashColourOut)
					me.flashBG = [me.flashColourOut(1:3) me.alphaOut];
				else
					me.flashBG = [me.sM.backgroundColour(1:3) 0]; %make sure alpha is 0
				end
				setupFlash(me);
			end
			
			me.inSetup = false; me.isSetup = true;
			computeColour(me);
			computePosition(me);
			setAnimationDelta(me);
			if me.doAnimator;setup(me.animator, me);end

			function set_xPositionOut(me, value)
				me.xPositionOut = value * me.ppd;
			end
			function set_yPositionOut(me,value)
				me.yPositionOut = value*me.ppd;
			end
			function set_sizeOut(me,value)
				me.sizeOut = value * me.ppd; %divide by 2 to get diameter
			end
			function set_colourOut(me, value)
				me.isInSetColour = true;
				if length(value)==4 
					alpha = value(4);
				else 
					alpha = getP(me,'alpha');
				end
				switch length(value)
					case 4
						setP(me,'alpha',alpha);
					case 3
						value = [value(1:3) alpha];
					case 1
						value = [value value value alpha];
				end
				me.colourOut = value;
				if ~me.isInCompute; me.colourOutTemp = value; end
				me.isInSetColour = false;
				if ~me.inSetup && ~me.isInCompute
					disp('colourOut compute')
					computeColour(me);
				end
			end
			function set_flashColourOut(me, value)
				me.isInSetColour = true;
				if length(value) < 4 
					alpha = getP(me,'alpha');
				end
				switch length(value)
					case 3
						value = [value(1:3) alpha];
					case 1
						value = [value value value alpha];
				end
				me.flashColourOut = value;
				if ~me.isInCompute; me.flashColourOutTemp = value; end
				me.isInSetColour = false;
				if ~me.inSetup && ~me.isInCompute
					disp('flashcolourOut compute')
					computeColour(me);
				end
			end
			function set_alphaOut(me, value)
				if me.isInSetColour; return; end
				me.alphaOut = value;
				c = getP(me,'colour');
				fc = getP(me,'flashColour');
				setP(me,'colour', [c(1:3) me.alphaOut]);
				if ~isempty(fc); setP(me,'flashColour', [fc(1:3) me.alphaOut]); end
			end
			function set_contrastOut(me, value)
				if iscell(value); value = value{1}; end
				me.contrastOut = value;
				if ~me.inSetup
					disp('contrastOut compute')
					computeColour(me);
				end
			end
		end
		
		% ===================================================================
		%> @brief Update a structure for runExperiment
		%>
		%> @param
		%> @return
		% ===================================================================
		function update(me)
			resetTicks(me);
			me.isInCompute = false;
			me.inSetup = false;
			computePosition(me);
			setAnimationDelta(me);
			if me.doFlash
				me.colourOutTemp = [];
				me.flashColourOutTemp = [];
				me.setupFlash; 
			end
		end
		
		% ===================================================================
		%> @brief Draw an structure for runExperiment
		%>
		%> @param sM runExperiment object for reference
		%> @return stimulus structure.
		% ===================================================================
		function draw(me)
			if me.isVisible && me.tick >= me.delayTicks && me.tick < me.offTicks
				if me.doFlash == false
					Screen('gluDisk',me.sM.win,me.colourOut,me.xFinal,me.yFinal,me.sizeOut/2);
				else
					Screen('gluDisk',me.sM.win,me.currentColour,me.xFinal,me.yFinal,me.sizeOut/2);
				end
			end
			me.tick = me.tick + 1;
		end
		
		% ===================================================================
		%> @brief Animate an structure for runExperiment
		%>
		%> @param sM runExperiment object for reference
		%> @return stimulus structure.
		% ===================================================================
		function animate(me)
			if me.isVisible && me.tick >= me.delayTicks
				if me.mouseOverride
					getMousePosition(me);
					if me.mouseValid
						me.xFinal = me.mouseX;
						me.yFinal = me.mouseY;
					end
				end
				if me.doMotion == true
					me.xFinal = me.xFinal + me.dX_;
					me.yFinal = me.yFinal + me.dY_;
				end
				if me.doFlash == true
					if me.flashCounter <= me.flashSwitch
						me.flashCounter=me.flashCounter+1;
					else
						me.flashCounter = 1;
						me.flashState = ~me.flashState;
						if me.flashState == true
							me.currentColour = me.flashFG;
						else
							me.currentColour = me.flashBG;
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
		function reset(me)
			resetTicks(me);
			removeTmpProperties(me);
			me.texture=[];
			me.isInCompute = false;
			me.inSetup = false; me.isSetup = false;
			me.colourOutTemp = [];
			me.flashColourOutTemp = [];
			me.flashFG = [];
			me.flashBG = [];
			me.flashCounter = [];
		end
		
		% ===================================================================
		%> @brief flashSwitch Get method
		%>
		% ===================================================================
		function flashSwitch = get.flashSwitch(me)
			if me.flashState
				flashSwitch = round(me.flashTimeOut(1) / me.sM.screenVals.ifi);
			else
				flashSwitch = round(me.flashTimeOut(2) / me.sM.screenVals.ifi);
			end
		end
		
	end %---END PUBLIC METHODS---%
	
	%=======================================================================
	methods ( Access = protected ) %-------PROTECTED METHODS-----%
	%=======================================================================
		
		% ===================================================================
		%> @brief computeColour triggered event
		%> Use an event to recalculate as get method is slower (called
		%> many more times), than an event which is only called on update
		% ===================================================================
		function computeColour(me,~,~)
			if me.inSetup || me.isInCompute; return; end
			disp('computeColour')
			me.isInCompute = true;
			if isprop(me,'contrastOut') && me.contrastOut < 1
				me.colourOut = [me.mix(me.colourOutTemp(1:3)) me.alphaOut];
				if ~isempty(me.flashColourOut)
					me.flashColourOut = [me.mix(me.flashColourOutTemp(1:3)) me.alphaOut];
				end
			else
				me.colourOut = me.colourOutTemp;
				if ~isempty(me.flashColourOut);me.flashColourOut = me.flashColourOutTemp; end
			end
			me.isInCompute = false;
			me.setupFlash();
		end
		
		% ===================================================================
		%> @brief setupFlash
		%>
		% ===================================================================
		function setupFlash(me)
			me.flashState = me.flashOn;
			me.flashFG = me.colourOut;
			me.flashCounter = 1;
			if me.doFlash
				if ~isempty(me.flashColourOut)
					me.flashBG = [me.flashColourOut(1:3) me.alphaOut];
				else
					me.flashBG = [me.sM.backgroundColour(1:3) 0]; %make sure alpha is 0
				end
			end
			if me.flashState
				me.currentColour = me.flashFG;
			else
				me.currentColour = me.flashBG;
			end
		end
		
		% ===================================================================
		%> @brief linear interpolation between two arrays
		%>
		% ===================================================================
		function out = mix(me,c)
			out = me.sM.backgroundColour(1:3) * (1 - me.contrastOut) + c(1:3) * me.contrastOut;
		end
	end
end

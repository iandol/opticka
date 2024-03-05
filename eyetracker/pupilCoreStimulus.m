% ========================================================================
%> @brief single disc stimulus, inherits from baseStimulus
%> SPOTSTIMULUS single spot stimulus, inherits from baseStimulus
%>   The current properties are:
%>
%> Copyright ©2014-2022 Ian Max Andolina — released: LGPL3, see LICENCE.md
% ========================================================================
classdef pupilCoreStimulus < baseStimulus
	
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
		%> stop marker?
		stop = false
	end
	
	properties (SetAccess = protected, GetAccess = public)
		%> stimulus family
		family char = 'marker'
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
		function me = pupilCoreStimulus(varargin)
			args = optickaCore.addDefaults(varargin,...
				struct('name','pupilcorestim','colour',[1 1 0 1]));
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
					if strcmp(fn{j},'xPosition'); p.SetMethod = @set_xPositionOut; end
					if strcmp(fn{j},'yPosition'); p.SetMethod = @set_yPositionOut; end
					me.([fn{j} 'Out']) = me.(fn{j}); %copy our property value to our tempory copy
				end
			end
			
			addRuntimeProperties(me);
			
			me.inSetup = false; me.isSetup = true;
			computePosition(me);
			setAnimationDelta(me);
			if me.doAnimator;setup(me.animator, me);end

			function set_xPositionOut(me, value)
				me.xPositionOut = value * me.ppd;
			end
			function set_yPositionOut(me,value)
				me.yPositionOut = value * me.ppd; 
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
		end
		
		% ===================================================================
		%> @brief Draw an structure for runExperiment
		%>
		%> @param sM runExperiment object for reference
		%> @return stimulus structure.
		% ===================================================================
		function draw(me)
			if me.isVisible && me.tick >= me.delayTicks && me.drawTick < me.offTicks
				me.sM.drawPupilCoreMarker(me.sizeOut,me.xFinalD,me.yFinalD,me.stop);
				me.drawTick = me.drawTick + 1;
			end
			if me.isVisible; me.tick = me.tick + 1; end
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
					me.xFinalD = me.sM.toDegrees(me.xFinal,'x');
					me.yFinalD = me.sM.toDegrees(me.yFinal,'y');
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
		end

		
	end %---END PUBLIC METHODS---%
	
	%=======================================================================
	methods ( Access = protected ) %-------PROTECTED METHODS-----%
	%=======================================================================
		
	end
end
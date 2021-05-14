% ========================================================================
%> @brief draw fixation cross from Thaler L, Schütz AC, 
%>  Goodale MA, & Gegenfurtner KR (2013) "What is the best fixation target:
%>  The effect of target shape on stability of fixational eye movements."
%>  Vision research 76, 31-42 <http://doi.org/10.1016/j.visres.2012.10.012>
% ========================================================================
classdef fixationCrossStimulus < baseStimulus
	
	properties %--------------------PUBLIC PROPERTIES----------%
		%> type can be "simple" or "flash"
		type = 'simple'
		%> time to flash on and off in seconds
		flashTime = [0.25 0.25]
		%> is the ON flash the first flash we see?
		flashOn = true
		%> contrast is realy a multiplier to the stimulus colour, not
		%> formally defined contrast in this case
		contrast = 1
		%> colour for flash, empty to inherit from screen background with 0 alpha
		flashColour = []
		%> second colour
		colour2 = [0 0 0 1]
		%> width of the cross lines in degrees
		lineWidth = 0.075
		%> show background disk
		showDisk = true
	end
	
	properties (SetAccess = protected, GetAccess = public)
		%> stimulus family
		family = 'fixationcross'
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
		stopLoop = false
		allowedProperties='showDisk|type|flashTime|flashOn|flashColour|contrast|colour2|lineWidth'
		ignoreProperties = 'flashSwitch';
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
		function me = fixationCrossStimulus(varargin)
			args = optickaCore.addDefaults(varargin,...
				struct('name','fix','colour',[1 1 1 1],'size',0.8));
			me=me@baseStimulus(args); %we call the superclass constructor first
			me.parseArgs(args, me.allowedProperties);
			
			me.isRect = false; %uses a rect for drawing

			me.ignoreProperties = ['^(' me.ignorePropertiesBase '|' me.ignoreProperties ')$'];
			me.salutation('constructor','Stimulus initialisation complete');
		end
		
		% ===================================================================
		%> @brief Setup an structure for runExperiment
		%>
		%> @param sM handle to the current screenManager object
		% ===================================================================
		function setup(me,sM)
			
			reset(me);
			me.inSetup = true;
			if isempty(me.isVisible); me.show; end
			
			me.sM = sM;
			me.ppd=sM.ppd;
			
			fn = fieldnames(fixationCrossStimulus);
			for j=1:length(fn)
				if isempty(me.findprop([fn{j} 'Out'])) && isempty(regexp(fn{j},me.ignoreProperties, 'once'))%create a temporary dynamic property
					p=me.addprop([fn{j} 'Out']);
					p.Transient = true;%p.Hidden = true;
					if strcmp(fn{j},'size');p.SetMethod = @set_sizeOut;end
					if strcmp(fn{j},'lineWidth');p.SetMethod = @set_lineWidthOut;end
					if strcmp(fn{j},'xPosition');p.SetMethod = @set_xPositionOut;end
					if strcmp(fn{j},'yPosition');p.SetMethod = @set_yPositionOut;end
					if strcmp(fn{j},'colour');p.SetMethod = @set_colourOut;end
					if strcmp(fn{j},'colour2');p.SetMethod = @set_colour2Out;end
					if strcmp(fn{j},'contrast');p.SetMethod = @set_contrastOut;end
					if strcmp(fn{j},'alpha');p.SetMethod = @set_alphaOut;end
				end
				if isempty(regexp(fn{j},me.ignoreProperties, 'once'))
					me.([fn{j} 'Out']) = me.(fn{j}); %copy our property value to our tempory copy
				end
			end
			
			doProperties(me);
			
			if me.doFlash
				if ~isempty(me.flashColour)
					me.flashBG = [me.flashColour(1:3) me.alphaOut];
				else
					me.flashBG = [me.sM.backgroundColour(1:3) 0]; %make sure alpha is 0
				end
				setupFlash(me);
			end
			
			me.inSetup = false;
			
			computeColour(me);
			computePosition(me);
			setAnimationDelta(me);
		end
		
		% ===================================================================
		%> @brief Update a structure for runExperiment
		%>
		%> @param
		%> @return
		% ===================================================================
		function update(me)
			resetTicks(me);
			me.colourOutTemp = [];
			me.stopLoop = false;
			me.inSetup = false;
			computePosition(me);
			setAnimationDelta(me);
			if me.doFlash; me.setupFlash; end
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
					if me.showDisk;Screen('gluDisk', me.sM.win, me.colourOut, me.xOut,me.yOut,me.sizeOut/2);end
					Screen('FillRect', me.sM.win, [me.colour2Out(1:3) 1], CenterRectOnPointd([0 0 me.sizeOut me.lineWidthOut], me.xOut,me.yOut));
					Screen('FillRect', me.sM.win, [me.colour2Out(1:3) 1], CenterRectOnPointd([0 0 me.lineWidthOut me.sizeOut], me.xOut,me.yOut));
					Screen('gluDisk', me.sM.win, [me.colourOut(1:3) 1], me.xOut, me.yOut, me.lineWidthOut);
				else
					if me.showDisk;Screen('gluDisk', me.sM.win, me.currentColour, me.xOut,me.yOut,me.sizeOut/2);end
					Screen('FillRect', me.sM.win, me.colour2Out, CenterRectOnPointd([0 0 me.sizeOut me.lineWidthOut], me.xOut,me.yOut));
					Screen('FillRect', me.sM.win, me.colour2Out, CenterRectOnPointd([0 0 me.lineWidthOut me.sizeOut], me.xOut,me.yOut));
					Screen('gluDisk', me.sM.win, me.currentColour, me.xOut, me.yOut, me.lineWidthOut);
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
						me.xOut = me.mouseX;
						me.yOut = me.mouseY;
					end
				end
				if me.doMotion == true
					me.xOut = me.xOut + me.dX_;
					me.yOut = me.yOut + me.dY_;
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
			me.texture=[];
			me.removeTmpProperties;
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
		%> @brief sizeOut Set method
		%>
		% ===================================================================
		function set_sizeOut(me,value)
			me.sizeOut = value * me.ppd; %divide by 2 to get diameter
		end
		
		% ===================================================================
		%> @brief sizeOut Set method
		%>
		% ===================================================================
		function set_lineWidthOut(me,value)
			me.lineWidthOut = value * me.ppd; %divide by 2 to get diameter
			if me.lineWidthOut < 2; me.lineWidthOut = 2; end
		end
		
		% ===================================================================
		%> @brief colourOut SET method
		%>
		% ===================================================================
		function set_colourOut(me, value)
			me.isInSetColour = true;
			if length(value)==4 
				alpha = value(4);
			elseif isempty(me.findprop('alphaOut'))
				alpha = me.alpha;
			else
				alpha = me.alphaOut;
			end
			switch length(value)
				case 4
					if isempty(me.findprop('alphaOut'))
						me.alpha = alpha;
					else
						me.alphaOut = alpha;
					end
				case 3
					value = [value(1:3) alpha];
				case 1
					value = [value value value alpha];
			end
			if isempty(me.colourOutTemp);me.colourOutTemp = value;end
			me.colourOut = value;
			me.isInSetColour = false;
			if isempty(me.findprop('contrastOut'))
				contrast = me.contrast; %#ok<*PROPLC>
			else
				contrast = me.contrastOut;
			end
			if ~me.inSetup && ~me.stopLoop && contrast < 1
				computeColour(me);
			end
		end
		
		% ===================================================================
		%> @brief colourOut SET method
		%>
		% ===================================================================
		function set_colour2Out(me, value)
			me.isInSetColour = true;
			alpha = 1;
			switch length(value)
				case {3,4}
					value = [value(1:3) alpha];
				case 1
					value = [value value value alpha];
			end
			me.colour2Out = value;
			me.isInSetColour = false;
		end
		
		% ===================================================================
		%> @brief alphaOut SET method
		%>
		% ===================================================================
		function set_alphaOut(me, value)
			if ~me.isInSetColour
				me.alphaOut = value;
				if isempty(me.findprop('colourOut'))
					me.colour = [me.colour(1:3) me.alphaOut];
				else
					me.colourOut = [me.colourOut(1:3) me.alphaOut];
				end
			end
		end
		
		% ===================================================================
		%> @brief contrastOut SET method
		%>
		% ===================================================================
		function set_contrastOut(me, value)
			if iscell(value); value = value{1}; end
			me.contrastOut = value;
			if ~me.inSetup && ~me.stopLoop && value < 1
				computeColour(me);
			end
		end
		
		% ===================================================================
		%> @brief computeColour triggered event
		%> Use an event to recalculate as get method is slower (called
		%> many more times), than an event which is only called on update
		% ===================================================================
		function computeColour(me,~,~)
			if me.inSetup || me.stopLoop; return; end
			me.stopLoop = true;
			me.colourOut = [me.mix(me.colourOutTemp(1:3)) me.alphaOut];
			me.stopLoop = false;
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
			if me.flashState == true
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
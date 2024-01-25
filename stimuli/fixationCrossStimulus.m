% ========================================================================
%> @brief draw fixation cross from Thaler L, Schütz AC, 
%>  Goodale MA, & Gegenfurtner KR (2013) "What is the best fixation target:
%>  The effect of target shape on stability of fixational eye movements."
%>  Vision research 76, 31-42 <http://doi.org/10.1016/j.visres.2012.10.012>
%>
%> Copyright ©2014-2022 Ian Max Andolina — released: LGPL3, see LICENCE.md
% ========================================================================
classdef fixationCrossStimulus < baseStimulus
	
	properties %--------------------PUBLIC PROPERTIES----------%
		%> alpha for cross colour, can be controlled independently of alpha for
		%> disc
		alpha2 = 1
		%> second colour, used for the cross
		colour2 = [0 0 0 1]
		%> width of the cross lines in degrees
		lineWidth = 0.1
		%> show background disk
		showDisk = true
		%> type can be "simple", "pulse" or "flash"
		type char				= 'simple'
		%> time to flash on and off in seconds
		flashTime double		= [0.25 0.1]
		%> is the ON flash the first flash we see?
		flashOn logical			= true
		%> colour for flash, empty to inherit from screen background with 0 alpha
		flashColour = []
		%> pulse frequency Hz
		pulseFrequency = 2
		%> pulse size range in %
		pulseRange = 50

	end
	
	properties (SetAccess = protected, GetAccess = public)
		%> stimulus family
		family = 'fixationcross'
	end
	
	properties (SetAccess = private, GetAccess = public, Hidden = true)
		typeList = {'simple','pulse','flash'}
	end
	
	properties (Dependent = true, SetAccess = private, GetAccess = private)
		%> dependant property to track when to switch from ON to OFF flash.
		flashSwitch
	end

	properties (SetAccess = ?baseStimulus, GetAccess = ?baseStimulus)
		ignorePropertiesUI = {'speed','startPosition','angle'}
	end
	
	properties (SetAccess = private, GetAccess = private)
		%> current flash state
		flashState
		%> internal counter
		flashCounter				= 1
		%> the OFF colour of the flash, usually this is set to the screen background
		flashBG						= [0.5 0.5 0.5]
		%> ON flash colour, reset on setup
		flashFG						= [1 1 1]
		%> values for pulse animation
		currentSize					= 0
		pulseMod					= 0
		pulseStep					= 0
		pulsePosition				= 0
		currentColour				= [1 1 1]
		colourOutTemp				= [1 1 1]
		colour2OutTemp				= [1 1 1]
		allowedProperties = {'showDisk', 'type', 'flashTime', 'flashOn', ...
			'flashColour', 'colour2', 'alpha2', 'lineWidth'}
		ignoreProperties  = {'flashSwitch','flashOn'}
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
				struct('name','fix','colour',[1 1 1 0.75],'alpha', 0.75, ...
				'showOnTracker',false,'size',0.8,...
				'comment','colour&alpha apply to disk, colour2&alpha2 apply to cross'));
			me=me@baseStimulus(args); %we call the superclass constructor first
			me.parseArgs(args, me.allowedProperties);
			
			me.isRect = false; %uses a rect for drawing

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
			if isempty(me.isVisible); me.show; end
			
			me.sM = sM;
			if ~sM.isOpen; error('Screen needs to be Open!'); end
			me.ppd=sM.ppd;
			me.screenVals = sM.screenVals;
			
			fn = sort(properties(me));
			for j=1:length(fn)
				if ~matches(fn{j}, me.ignoreProperties)%create a temporary dynamic property
					p = addprop(me, [fn{j} 'Out']);
					if strcmp(fn{j},'size'); p.SetMethod = @set_sizeOut; end
					if strcmp(fn{j},'lineWidth'); p.SetMethod = @set_lineWidthOut; end
					if strcmp(fn{j},'xPosition'); p.SetMethod = @set_xPositionOut; end
					if strcmp(fn{j},'yPosition'); p.SetMethod = @set_yPositionOut; end
					if strcmp(fn{j},'colour'); p.SetMethod = @set_colourOut; end
					if strcmp(fn{j},'colour2'); p.SetMethod = @set_colour2Out; end
					if strcmp(fn{j},'alpha'); p.SetMethod = @set_alphaOut; end
					if strcmp(fn{j},'alpha2'); p.SetMethod = @set_alpha2Out; end
					me.([fn{j} 'Out']) = me.(fn{j}); %copy our property value to our tempory copy
				end
			end
			
			addRuntimeProperties(me);
			
			if me.doFlash
				if ~isempty(me.flashColour)
					me.flashBG = [me.flashColour(1:3) me.alphaOut];
				else
					me.flashBG = [me.sM.backgroundColour(1:3) 0]; %make sure alpha is 0
				end
				setupFlash(me);
			end

			me.pulsePosition = 0;
			me.pulseStep = (pi * (2*me.pulseFrequency)) / me.screenVals.fps;
			
			me.inSetup = false; me.isSetup = true;			
			computePosition(me);

			function set_xPositionOut(me, value)
				me.xPositionOut = value * me.ppd;
				if ~me.inSetup; me.setRect; end
			end
			function set_yPositionOut(me,value)
				me.yPositionOut = value*me.ppd;
				if ~me.inSetup; me.setRect; end
			end
			function set_alphaOut(me, value)
				if me.isInSetColour; return; end
				me.alphaOut = value;
				[~,name] = getP(me,'colour');
				me.(name) = [me.(name)(1:3) value];
				[val,name] = getP(me,'flashColour');
				if ~isempty(val)
					me.(name) = [me.(name)(1:3) value];
				end
			end
			function set_alpha2Out(me, value)
				if me.isInSetColour; return; end
				me.alpha2Out = value;
				[~,name] = getP(me,'colour2');
				me.(name) = [me.(name)(1:3) value];
			end
			function set_sizeOut(me,value)
				me.sizeOut = value * me.ppd; %divide by 2 to get diameter
				me.szPx = me.sizeOut;
				me.currentSize = me.sizeOut;
				me.pulseMod = ((me.sizeOut/me.ppd) / 100) * (me.pulseRange/2);
			end
			function set_lineWidthOut(me,value)
				me.lineWidthOut = value * me.ppd; %divide by 2 to get diameter
				if me.lineWidthOut < 2; me.lineWidthOut = 2; end
			end
			function set_colourOut(me, value)
				me.isInSetColour = true;
				[aold,name] = getP(me,'alpha');
				if length(value)==4 && value(4) ~= aold
					alpha = value(4);
				else
					alpha = aold;
				end
				switch length(value)
					case 4
						if alpha ~= aold; me.(name) = alpha; end
					case 3
						value = [value(1:3) alpha];
					case 1
						value = [value value value alpha];
				end
				if isempty(me.colourOutTemp);me.colourOutTemp = value;end
				me.colourOut = value; me.isInSetColour = false;
			end
			function set_colour2Out(me, value)
				me.isInSetColour = true;
				[aold,name] = getP(me,'alpha2');
				if length(value)==4 && value(4) ~= aold
					alpha = value(4);
				else
					alpha = aold;
				end
				switch length(value)
					case 4
						if alpha ~= aold; me.(name) = alpha; end
					case 3
						value = [value(1:3) alpha];
					case 1
						value = [value value value alpha];
				end
				if isempty(me.colour2OutTemp);me.colour2OutTemp = value;end
				me.colour2Out = value; me.isInSetColour = false;
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
			me.colourOutTemp = [];
			me.inSetup = false;
			computePosition(me);
			me.currentSize = me.sizeOut;
			me.szPx = me.currentSize;
			me.pulseMod = ((me.sizeOut/me.ppd) / 100) * (me.pulseRange/2);
			me.pulsePosition = 0;
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
				if ~me.doFlash
					if me.showDisk;Screen('gluDisk', me.sM.win, me.colourOut, me.xFinal,me.yFinal,me.currentSize/2);end
					Screen('FillRect', me.sM.win, me.colour2Out, CenterRectOnPointd([0 0 me.currentSize me.lineWidthOut], me.xFinal,me.yFinal));
					Screen('FillRect', me.sM.win, me.colour2Out, CenterRectOnPointd([0 0 me.lineWidthOut me.currentSize], me.xFinal,me.yFinal));
					Screen('gluDisk', me.sM.win, me.colourOut, me.xFinal, me.yFinal, me.lineWidthOut);
				else
					if me.showDisk;Screen('gluDisk', me.sM.win, me.currentColour, me.xFinal,me.yFinal,me.sizeOut/2);end
					Screen('FillRect', me.sM.win, me.colour2Out, CenterRectOnPointd([0 0 me.sizeOut me.lineWidthOut], me.xFinal,me.yFinal));
					Screen('FillRect', me.sM.win, me.colour2Out, CenterRectOnPointd([0 0 me.lineWidthOut me.sizeOut], me.xFinal,me.yFinal));
					Screen('gluDisk', me.sM.win, me.currentColour, me.xFinal, me.yFinal, me.lineWidthOut);
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
				elseif strcmp(me.type,'pulse')
					me.currentSize = me.sizeOut + (sin(me.pulsePosition) * (me.pulseMod*me.ppd));
					me.pulsePosition = me.pulsePosition + me.pulseStep;
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
			me.texture			= [];
			me.colourOutTemp	= [];
			me.currentColour	= [];
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
		
		% ===================================================================
		%> @brief colour set method
		%> Allow 1 (R=G=B) 3 (RGB) or 4 (RGBA) value colour
		% ===================================================================
		function set.colour2(me,value)
			me.isInSetColour = true; %#ok<*MCSUP>
			len=length(value);
			switch len
				case 4
					me.colour2 = value(1:4);
					me.alpha2 = value(4);
				case 3
					me.colour2 = [value(1:3) me.alpha2]; %force our alpha to override
				case 1
					me.colour2 = [value value value me.alpha2]; %construct RGBA
				otherwise
					me.colour2 = [1 1 1 me.alpha2]; %return white for everything else	
			end
			me.colour2(me.colour2<0)=0; me.colour2(me.colour2>1)=1;
			me.isInSetColour = false;
		end
		
		% ===================================================================
		%> @brief alpha set method
		%> 
		% ===================================================================
		function set.alpha2(me,value)
			if value<0; value=0;elseif value>1; value=1; end
			me.alpha2 = value;
			if ~me.isInSetColour
				me.colour2 = me.colour2(1:3); %force colour to be regenerated
			end
		end
		
	end %---END PUBLIC METHODS---%
	
	%=======================================================================
	methods ( Access = protected ) %-------PROTECTED METHODS-----%
	%=======================================================================
		
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

	end
end

% ========================================================================
%> @brief single disc stimulus, inherits from baseStimulus
%> DISCSTIMULUS single disc stimulus, inherits from baseStimulus
%>
%> Copyright ©2014-2022 Ian Max Andolina — released: LGPL3, see LICENCE.md
% ========================================================================
classdef discStimulus < baseStimulus
	
	properties %--------------------PUBLIC PROPERTIES----------%
		%> type can be "simple" or "flash"
		type = 'simple'
		%> colour for flash, empty to inherit from screen background with 0 alpha
		flashColour double = []
		%> time to flash on and off in seconds
		flashTime double {mustBeVector(flashTime)} = [0.25 0.25]
		%> is the ON flash the first flash we see?
		flashOn logical = true
		%> contrast scales from foreground to screen background colour
		contrast double {mustBeInRange(contrast,0,1)} = 1
		%> cosine smoothing sigma in pixels for mask
		sigma double = 31.0
		%> use colour or alpha [default] channel for smoothing?
		useAlpha logical = true
		%> use cosine (0), hermite (1, default), or inverse hermite (2)
		smoothMethod double = 1
	end
	
	properties (SetAccess = protected, GetAccess = public)
		%> stimulus family
		family = 'disc'
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
		%> change blend mode?
		changeBlend = false
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
		stopLoop = 0
		scale = 1
		allowedProperties='type|flashTime|flashOn|flashColour|contrast|sigma|useAlpha|smoothMethod'
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
		function me = discStimulus(varargin)
			args = optickaCore.addDefaults(varargin,...
				struct('name','Disc','colour',[1 1 0 1]));
			me=me@baseStimulus(args); %we call the superclass constructor first
			me.parseArgs(args, me.allowedProperties);
			
			me.isRect = true; %uses a rect for drawing?
			
			me.ignoreProperties = ['^(' me.ignorePropertiesBase '|' me.ignoreProperties ')$'];
			me.salutation('constructor','Stimulus initialisation complete');
		end
		
		% ===================================================================
		%> @brief Setup the stimulus object. The major purpose of this is to create a series
		%> of properties that are copies of the user controlled ones. The user specifies
		%> properties in degrees etc., but internally we must convert to pixels etc. So the
		%> setup function uses dynamic transient properties, for each property we create a temporary 
		%> propertyOut which is used for the actual drawing/animation.
		%>
		%> @param sM handle to the current screenManager object
		% ===================================================================
		function setup(me,sM)
			
			reset(me);
			me.inSetup = true;
			if isempty(me.isVisible); me.show; end
			
			me.sM = sM;
			if ~sM.isOpen; warning('Screen needs to be Open!'); end
			me.screenVals = sM.screenVals;
			me.ppd = sM.ppd;			
			
			me.texture = []; %we need to reset this
			
			fn = fieldnames(me);
			for j=1:length(fn)
				prop = [fn{j} 'Out'];
				if isempty(me.findprop(prop)) && isempty(regexp(fn{j},me.ignoreProperties, 'once'))%create a temporary dynamic property
					p = addprop(me, prop);
					p.Transient = true;
					if strcmp(fn{j},'size');p.SetMethod = @set_sizeOut;end
					if strcmp(fn{j},'xPosition');p.SetMethod = @set_xPositionOut;end
					if strcmp(fn{j},'yPosition');p.SetMethod = @set_yPositionOut;end
					if strcmp(fn{j},'colour');p.SetMethod = @set_colourOut;end
					if strcmp(fn{j},'flashColour');p.SetMethod = @set_flashColourOut;end
					if strcmp(fn{j},'alpha');p.SetMethod = @set_alphaOut;end
					if strcmp(fn{j},'contrast');p.SetMethod = @set_contrastOut;end
				end
				if isempty(regexp(fn{j},me.ignoreProperties, 'once'))
					me.(prop) = me.(fn{j}); %copy our property value to our tempory copy
				end
			end
			
			addRuntimeProperties(me); % create transient runtime action properties
			
			if isempty(me.findprop('discSize'));p=me.addprop('discSize');p.Transient=true;end
			me.discSize = me.ppd * me.size;
			
			if isempty(me.findprop('res'));p=me.addprop('res');p.Transient=true;end
			me.res = round([me.discSize me.discSize]);
			
			if isempty(me.findprop('radius'));p=me.addprop('radius');p.Transient=true;end
			me.radius = floor(me.discSize/2);
			
			if isempty(me.findprop('texture'));p=me.addprop('texture');p.Transient=true;end
			
			me.texture = CreateProceduralSmoothedDisc(me.sM.win, me.res(1), ...
						me.res(2), [0 0 0 0], me.radius, me.sigmaOut, ...
						me.useAlpha, me.smoothMethod);
			
			if me.doFlash
				if ~isempty(me.flashColourOut)
					me.flashBG = [me.flashColourOut(1:3) me.alphaOut];
				else
					me.flashBG = [me.sM.backgroundColour(1:3) 0]; %make sure alpha is 0
				end
				setupFlash(me);
			end
			
			if me.sM.blend && strcmpi(me.sM.srcMode,'GL_SRC_ALPHA') && strcmpi(me.sM.dstMode,'GL_ONE_MINUS_SRC_ALPHA')
				me.changeBlend = false;
			else
				me.changeBlend = true;
			end
			
			me.inSetup = false;
			computePosition(me);
			setRect(me);
			if me.doAnimator;setup(me.animator, me);end

			% a super annoying bug in matlab: if set methods are
			% standard protected or private, they trigger recursions.
			% Placing them as inline functions like here and they work!
			function set_sizeOut(me, value)
				me.sizeOut = value * me.ppd;
				if isprop(me,'discSize') && ~isempty(me.discSize) && ~isempty(me.texture)
					me.scale = me.sizeOut / me.discSize;
					setRect(me);
				end
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
			function set_contrastOut(me, value)
				if iscell(value); value = value{1}; end
				me.contrastOut = value;
				if ~me.inSetup && ~me.stopLoop && value < 1
					computeColour(me);
				end
			end
			function set_xPositionOut(me, value)
				me.xPositionOut = value * me.ppd;
			end
			function set_yPositionOut(me,value)
				me.yPositionOut = value*me.ppd;
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
				me.colourOut = value;
				me.isInSetColour = false;
				contrast = getP(me,'contrast');
				if ~me.inSetup && ~me.stopLoop && contrast < 1
					computeColour(me);
				end
			end
			function set_flashColourOut(me, value)
				if isempty(value);me.flashColourOut=value;me.setLoop = 0;return;end
				me.isInSetColour = true;
				[aold,name] = getP(me,'alpha');
				if length(value)==4 && value(4) ~= aold
					alpha = value(4);
				else
					alpha = aold;
				end
				switch length(value)
					case 3
						value = [value(1:3) alpha];
					case 1
						value = [value value value alpha];
				end
				if isempty(me.flashColourOutTemp);me.flashColourOutTemp = value;end
				me.flashColourOut = value;
				me.isInSetColour = false;
				contrast = getP(me,'contrast');
				if ~isempty(value) && ~me.inSetup && ~me.stopLoop && contrast < 1
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
			me.colourOutTemp = [];
			me.flashColourOutTemp = [];
			me.stopLoop = false;
			me.inSetup = false;
			computePosition(me);
			setRect(me);
			if me.doFlash; me.setupFlash; end
			if me.doAnimator; me.animator.reset(); end
		end
		
		% ===================================================================
		%> @brief Draw an structure for runExperiment
		%>
		%> @param sM runExperiment object for reference
		%> @return stimulus structure.
		% ===================================================================
		function draw(me)
			if me.isVisible && me.tick >= me.delayTicks && me.tick < me.offTicks
				%Screen('DrawTexture', windowPointer, texturePointer [,sourceRect] [,destinationRect] 
				%[,rotationAngle] [, filterMode] [, globalAlpha] [, modulateColor] [, textureShader] 
				%[, specialFlags] [, auxParameters]);
				if me.mouseOverride && ~me.mouseValid; fprintf('II %i\n',me.tick);me.tick = me.tick + 1;return; end
				if me.changeBlend;Screen('BlendFunction', me.sM.win, 'GL_SRC_ALPHA', 'GL_ONE_MINUS_SRC_ALPHA');end
				if me.doFlash == false
					Screen('DrawTexture', me.sM.win, me.texture, [], me.mvRect,...
					me.angleOut, [], [], me.colourOut, [], [],...
					[]);
				else
					Screen('DrawTexture', me.sM.win, me.texture, [], me.mvRect,...
					me.angleOut, [], [], me.currentColour, [], [],...
					[]);
				end
				if me.changeBlend;Screen('BlendFunction', me.sM.win, me.sM.srcMode, me.sM.dstMode);end
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
						me.mvRect = CenterRectOnPoint(me.mvRect, me.mouseX, me.mouseY);
					end
					return
				end
				if me.doMotion && me.doAnimator
					me.mvRect = update(me.animator);
				elseif me.doMotion && ~me.doAnimator	
					me.mvRect=OffsetRect(me.mvRect,me.dX_,me.dY_);
				end
				if me.doFlash == true
					if me.flashCounter <= me.flashSwitch
						me.flashCounter=me.flashCounter+1;
					else
						me.flashCounter = 1;
						me.flashState = ~me.flashState;
						if me.flashState
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
			me.stopLoop = false; me.setLoop = 0;
			me.inSetup = false; me.isSetup = false;
			me.colourOutTemp = [];
			me.flashColourOutTemp = [];
			me.flashFG = [];
			me.flashBG = [];
			me.flashCounter = [];
			if isprop(me,'texture')
				if ~isempty(me.texture) && me.texture > 0 && Screen(me.texture,'WindowKind') == -1
					try Screen('Close',me.texture); end %#ok<*TRYNC>
				end
				me.texture = []; 
			end
			if isprop(me,'discSize'); me.discSize = []; end
			if isprop(me,'radius'); me.radius = []; end
			if isprop(me,'res'); me.res = []; end
			me.removeTmpProperties;
			%if ~isempty(me.findprop('discSize'));delete(me.findprop('discSize'));end
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
		%> @brief setRect
		%> setRect makes the PsychRect based on the texture and screen values
		%> this is modified over parent method as textures have slightly different
		%> requirements.
		% ===================================================================
		function setRect(me)
			
			me.dstRect = ScaleRect(Screen('Rect',me.texture), me.scale, me.scale);
			if me.mouseOverride && me.mouseValid
					me.dstRect = CenterRectOnPointd(me.dstRect, me.mouseX, me.mouseY);
			else
				if isempty(me.findprop('angleOut'))
					[sx, sy]=pol2cart(me.d2r(me.angle),me.startPosition);
				else
					[sx, sy]=pol2cart(me.d2r(me.angleOut),me.startPosition);
				end
				me.dstRect=CenterRectOnPointd(me.dstRect,me.sM.xCenter,me.sM.yCenter);
				if isempty(me.findprop('xPositionOut'))
					me.dstRect=OffsetRect(me.dstRect,(me.xPosition)*me.ppd,(me.yPosition)*me.ppd);
				else
					me.dstRect=OffsetRect(me.dstRect,me.xPositionOut+(sx*me.ppd),me.yPositionOut+(sy*me.ppd));
				end
			end
			me.mvRect=me.dstRect;
			me.setAnimationDelta();
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
			if ~isempty(me.flashColourOut)
				me.flashColourOut = [me.mix(me.flashColourOutTemp(1:3)) me.alphaOut];
			end
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
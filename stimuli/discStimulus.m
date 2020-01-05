% ========================================================================
%> @brief single disc stimulus, inherits from baseStimulus
%> DISCSTIMULUS single disc stimulus, inherits from baseStimulus
% ========================================================================
classdef discStimulus < baseStimulus
	
	properties %--------------------PUBLIC PROPERTIES----------%
		%> type can be "simple" or "flash"
		type = 'simple'
		%> time to flash on and off in seconds
		flashTime = [0.5 0.5]
		%> is the ON flash the first flash we see?
		flashOn = true
		%> colour for flash, empty to inherit from screen background with 0 alpha
		flashOffColour = []
		%> cosine smoothing sigma in pixels for mask
		sigma = 11.0
		%> use colour or alpha [default] channel for smoothing?
		useAlpha = true
		%> use cosine (0), hermite (1, default), or inverse hermite (2)
		smoothMethod = 1
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
		%> internal counter
		flashCounter = 1
		%> the OFF colour of the flash, usually this is set to the screen background
		flashBG = [0.5 0.5 0.5]
		%> ON flash colour, reset on setup
		flashFG = [1 1 1]
		currentColour = [1 1 1]
		colourOutTemp = [1 1 1]
		stopLoop = false
		scale = 1
		allowedProperties='type|flashTime|flashOn|flashOffColour|sigma|useAlpha|smoothMethod'
		ignoreProperties = 'type|name|flashSwitch|FlashOn';
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
			if nargin == 0;varargin.name = 'disc stimulus';end
			args = optickaCore.addDefaults(varargin,...
				struct('colour',[1 1 0 1]));
			me=me@baseStimulus(args); %we call the superclass constructor first
			me.parseArgs(args, me.allowedProperties);
			
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
			if isempty(me.isVisible)
				me.show;
			end
			
			me.sM = sM;
			me.ppd=sM.ppd;
			
			me.texture = []; %we need to reset this
			
			fn = fieldnames(me);
			for j=1:length(fn)
				if isempty(me.findprop([fn{j} 'Out'])) && isempty(regexp(fn{j},me.ignoreProperties, 'once'))%create a temporary dynamic property
					p=me.addprop([fn{j} 'Out']);
					p.Transient = true;%p.Hidden = true;
					if strcmp(fn{j},'size');p.SetMethod = @set_sizeOut;end
					if strcmp(fn{j},'xPosition');p.SetMethod = @set_xPositionOut;end
					if strcmp(fn{j},'yPosition');p.SetMethod = @set_yPositionOut;end
					if strcmp(fn{j},'colour');p.SetMethod = @set_colourOut;end
				end
				if isempty(regexp(fn{j},me.ignoreProperties, 'once'))
					me.([fn{j} 'Out']) = me.(fn{j}); %copy our property value to our tempory copy
				end
			end
			
			if isempty(me.findprop('doFlash'));p=me.addprop('doFlash');p.Transient = true;end
			if isempty(me.findprop('doDots'));p=me.addprop('doDots');p.Transient = true;end
			if isempty(me.findprop('doMotion'));p=me.addprop('doMotion');p.Transient = true;end
			if isempty(me.findprop('doDrift'));p=me.addprop('doDrift');p.Transient = true;end
			me.doDots = false;
			me.doMotion = false;
			me.doDrift = false;
			me.doFlash = false;
			
			if me.speedOut > 0; me.doMotion = true; end
			
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
			
			if strcmpi(me.type,'flash')
				me.doFlash = true;
				if ~isempty(me.flashOffColour)
					me.flashBG = [me.flashOffColour(1:3) 0];
				else
					me.flashBG = [me.sM.backgroundColour(1:3) 0]; %make sure alpha is 0
				end
				setupFlash(me);
			end
			
			me.inSetup = false;
			computePosition(me);
			setRect(me);
			
		end
		
		% ===================================================================
		%> @brief Update a structure for runExperiment
		%>
		%> @param
		%> @return
		% ===================================================================
		function update(me)
			resetTicks(me);
			computePosition(me);
			setRect(me);
			if me.doFlash
				me.resetFlash;
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
				%Screen('DrawTexture', windowPointer, texturePointer [,sourceRect] [,destinationRect] 
				%[,rotationAngle] [, filterMode] [, globalAlpha] [, modulateColor] [, textureShader] 
				%[, specialFlags] [, auxParameters]);
				Screen('BlendFunction', me.sM.win, 'GL_SRC_ALPHA', 'GL_ONE_MINUS_SRC_ALPHA');
				if me.doFlash == false
					Screen('DrawTexture', me.sM.win, me.texture, [], me.mvRect,...
					me.angleOut, [], [], me.colourOut, [], [],...
					[]);
				else
					Screen('DrawTexture', me.sM.win, me.texture, [], me.mvRect,...
					me.angleOut, [], [], me.currentColour, [], [],...
					[]);
				end
				Screen('BlendFunction', me.sM.win, me.sM.srcMode, me.sM.dstMode);
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
						me.mvRect = CenterRectOnPointd(me.mvRect, me.mouseX, me.mouseY);
					end
				end
				if me.doMotion == true
					me.mvRect=OffsetRect(me.mvRect,me.dX_,me.dY_);
				end
				if me.doFlash == true
					if me.flashCounter <= me.flashSwitch
						me.flashCounter=me.flashCounter+1;
					else
						me.flashCounter = 1;
						me.flashOnOut = ~me.flashOnOut;
						if me.flashOnOut == true
							me.currentColour = me.flashFG;
						else
							me.currentColour = me.flashBG;
							%fprintf('Current: %s | %s\n',num2str(me.colourOut), num2str(me.flashOnOut));
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
			if isprop(me,'texture'); me.texture = []; end
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
			if isempty(me.findprop('flashOnOut'))
				trigger = me.flashOn;
			else
				trigger = me.flashOnOut;
			end
			if trigger
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
			dstRect=Screen('Rect', me.texture);
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
		%> @brief sizeOut Set method
		%>
		% ===================================================================
		function set_sizeOut(me,value)
			me.sizeOut = value * me.ppd; %divide by 2 to get diameter
			if isprop(me,'discSize') && ~isempty(me.discSize) && ~isempty(me.texture)
				me.scale = me.sizeOut / me.discSize;
				setRect(me);
			end
		end
		
		% ===================================================================
		%> @brief colourOut SET method
		%>
		% ===================================================================
		function set_colourOut(me, value)
			if length(value) == 1
				value = [value value value me.alphaOut];
			elseif length(value) == 3
				value = [value me.alphaOut];
			end
			me.colourOutTemp = value;
			me.colourOut = value;
		end
		
		
		% ===================================================================
		%> @brief setupFlash
		%>
		% ===================================================================
		function setupFlash(me)
			me.flashFG = me.colourOut;
			me.flashCounter = 1;
			if me.flashOnOut == true
				me.currentColour = me.flashFG;
			else
				me.currentColour = me.flashBG;
			end
		end
		
		% ===================================================================
		%> @brief resetFlash
		%>
		% ===================================================================
		function resetFlash(me)
			me.flashFG = me.colourOut;
			me.flashOnOut = me.flashOn;
			if me.flashOnOut == true
				me.currentColour = me.flashFG;
			else
				me.currentColour = me.flashBG;
			end
			me.flashCounter = 1;
		end
	end
end
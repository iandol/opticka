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
		%> use colour or alpha channel for smoothing?
		useAlpha = true
		%> use cosine (0) or hermite interpolation (1, default)
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
		function obj = discStimulus(varargin)
			%Initialise for superclass, stops a noargs error
			if nargin == 0; varargin.family = 'disc'; end
			
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
			
			obj.sM = sM;
			obj.ppd=sM.ppd;
			
			obj.texture = []; %we need to reset this
			
			fn = fieldnames(discStimulus);
			for j=1:length(fn)
				if isempty(obj.findprop([fn{j} 'Out'])) && isempty(regexp(fn{j},obj.ignoreProperties, 'once'))%create a temporary dynamic property
					p=obj.addprop([fn{j} 'Out']);
					p.Transient = true;%p.Hidden = true;
					if strcmp(fn{j},'size');p.SetMethod = @set_sizeOut;end
					if strcmp(fn{j},'xPosition');p.SetMethod = @set_xPositionOut;end
					if strcmp(fn{j},'yPosition');p.SetMethod = @set_yPositionOut;end
					if strcmp(fn{j},'colour');p.SetMethod = @set_colourOut;end
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
			
			if isempty(obj.findprop('gratingSize'));p=obj.addprop('gratingSize');p.Transient=true;end
			obj.gratingSize = round(obj.ppd*obj.size);
			
			if isempty(obj.findprop('res'));p=obj.addprop('res');p.Transient=true;end
			obj.res = round([obj.gratingSize obj.gratingSize]);
			
			if isempty(obj.findprop('radius'));p=obj.addprop('radius');p.Transient=true;end
			obj.radius = floor((obj.ppd*obj.size)/2);
			
			if isempty(obj.findprop('texture'));p=obj.addprop('texture');p.Transient=true;end
			
			obj.texture = CreateProceduralSmoothDisc(obj.sM.win, obj.res(1), ...
						obj.res(2), [0 0 0 0], obj.radius, obj.sigmaOut, ...
						obj.useAlpha, obj.smoothMethod);
			
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
			setRect(obj);
			
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
			setRect(obj);
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
			if obj.isVisible && obj.tick >= obj.delayTicks && obj.tick < obj.offTicks
				%Screen('DrawTexture', windowPointer, texturePointer [,sourceRect] [,destinationRect] 
				%[,rotationAngle] [, filterMode] [, globalAlpha] [, modulateColor] [, textureShader] 
				%[, specialFlags] [, auxParameters]);
				Screen('BlendFunction', obj.sM.win, 'GL_SRC_ALPHA', 'GL_ONE_MINUS_SRC_ALPHA');
				if obj.doFlash == false
					Screen('DrawTexture', obj.sM.win, obj.texture, [], obj.mvRect,...
					obj.angleOut, [], [], obj.colourOut, [], [],...
					[]);
				else
					Screen('DrawTexture', obj.sM.win, obj.texture, [], obj.mvRect,...
					obj.angleOut, [], [], obj.currentColour, [], [],...
					[]);
				end
				Screen('BlendFunction', obj.sM.win, obj.sM.srcMode, obj.sM.dstMode);
			end
			obj.tick = obj.tick + 1;
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
						obj.mvRect = CenterRectOnPointd(obj.mvRect, obj.mouseX, obj.mouseY);
					end
				end
				if obj.doMotion == true
					obj.mvRect=OffsetRect(obj.mvRect,obj.dX_,obj.dY_);
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
				flashSwitch = round(obj.flashTimeOut(1) / obj.sM.screenVals.ifi);
			else
				flashSwitch = round(obj.flashTimeOut(2) / obj.sM.screenVals.ifi);
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
		function setRect(obj)
			obj.dstRect=Screen('Rect',obj.texture);
			if obj.mouseOverride && obj.mouseValid
					obj.dstRect = CenterRectOnPointd(obj.dstRect, obj.mouseX, obj.mouseY);
			else
				if isempty(obj.findprop('angleOut'));
					[sx, sy]=pol2cart(obj.d2r(obj.angle),obj.startPosition);
				else
					[sx, sy]=pol2cart(obj.d2r(obj.angleOut),obj.startPosition);
				end
				obj.dstRect=CenterRectOnPointd(obj.dstRect,obj.sM.xCenter,obj.sM.yCenter);
				if isempty(obj.findprop('xPositionOut'));
					obj.dstRect=OffsetRect(obj.dstRect,(obj.xPosition)*obj.ppd,(obj.yPosition)*obj.ppd);
				else
					obj.dstRect=OffsetRect(obj.dstRect,obj.xPositionOut+(sx*obj.ppd),obj.yPositionOut+(sy*obj.ppd));
				end
			end
			obj.mvRect=obj.dstRect;
			obj.setAnimationDelta();
		end
		
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
			elseif length(value) == 3
				value = [value obj.alphaOut];
			end
			obj.colourOutTemp = value;
			obj.colourOut = value;
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
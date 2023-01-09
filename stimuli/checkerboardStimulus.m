% ========================================================================
%> @brief checkerBoardStimulus -- using a GLSL shader to make the
%> checkerboard
%>
%> See docs for more property details
%>
%> Copyright ©2014-2022 Ian Max Andolina — released: LGPL3, see LICENCE.md
% ========================================================================
classdef checkerboardStimulus < baseStimulus
	
	properties %--------------------PUBLIC PROPERTIES----------%
		%> family type
		type char					= 'checkerboard'
		%> spatial frequency of the checkerboard
		sf double					= 1
		%> temporal frequency of the checkerboard
		tf double					= 1
		%> second colour of the checkerboard
		colour2 double				= [0 1 0 1]
		%> base colour from which colour and colour2 are blended via contrast value
		%> if empty [default], uses the background colour from screenManager
		baseColour double			= []
		%> rotate the grating patch (false) or the grating texture within the patch (default = true)?
		rotateTexture logical	= true
		%> phase of grating
		phase double				= 0
		%> contrast of grating (technically the contrast from the baseColour)
		contrast double			= 0.5
		%> use a circular mask for the grating (default = true).
		mask logical				= true
		%> direction of the drift; default = false means drift left>right when angle is 0deg.
		%This switch can be accomplished simply setting angle, but this control enables
		%simple reverse direction protocols.
		reverseDirection logical = false
		%> the direction of the grating object if moving.
		direction double			= 0
		%> Do we need to correct the phase to be relative to center not edge? This enables
		%> centre surround stimuli are phase matched, and if we enlarge a grating object its
		%> phase stays identical at the centre of the object (where we would imagine our RF)
		correctPhase logical		= false
		%> Reverse phase of grating X times per second? Useful with a static grating for linearity testing
		phaseReverseTime double = 0
		%> What phase to use for reverse?
		phaseOfReverse double	= 180
		%> aspect ratio of the grating
		aspectRatio double		= 1;
	end
	
	properties (SetAccess = protected, GetAccess = public)
		%stimulus family
		family char					= 'checkerboard'
		%> scale is used when changing size as an independent variable to keep sf accurate
		scale double				= 1
		%> the phase amount we need to add for each frame of animation
		phaseIncrement double	= 0
	end
	
	properties (SetAccess = private, GetAccess = public, Hidden = true)
		typeList cell				= {'checkerboard'}
	end
	
	properties (SetAccess = protected, GetAccess = protected)
		%> as get methods are slow, we cache sf, then recalculate sf whenever
		%> changeScale event is called
		sfCache					= []
		%>to stop a loop between set method and an event
		sfRecurse				= false
		%> allowed properties passed to object upon construction
		allowedProperties = {'colour2', 'sf', 'tf', 'angle', 'direction', 'phase', 'rotateTexture' ... 
			'contrast', 'mask', 'reverseDirection', 'speed', 'startPosition', 'aspectRatio' ... 
			'sigma', 'correctPhase', 'phaseReverseTime', 'phaseOfReverse'}
		%>properties to not create transient copies of during setup phase
		ignoreProperties = {'name', 'type', 'scale', 'phaseIncrement', 'correctPhase', 'contrastMult', 'mask'}
		%> how many frames between phase reverses
		phaseCounter			= 0
		%> mask value (radius for the procedural shader)
		maskValue
		%> the raw shader, we can try to change colours.
		shader
	end
	
	events (ListenAccess = 'protected', NotifyAccess = 'protected') %only this class can access these
		%> triggered when changing size, so we can change sf etc to compensate
		changeScale 
		%> triggered when changing tf or drift direction
		changePhaseIncrement 
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
		%> @return instance of class.
		% ===================================================================
		function me = checkerboardStimulus(varargin)
			args = optickaCore.addDefaults(varargin,...
				struct('name','checkerboard','colour',[1 1 1 1],'colour2',[0 0 0 1]));
			me=me@baseStimulus(args); %we call the superclass constructor first
			me.parseArgs(args, me.allowedProperties);
			
			me.isRect = true; %uses a rect for drawing
			
			me.ignoreProperties = [me.ignorePropertiesBase me.ignoreProperties];
			me.salutation('constructor method','Stimulus initialisation complete');
		end
		
		% ===================================================================
		%> @brief Setup this object in preparation for use
		%> When displaying a stimulus object, the main properties that are to be
		%> modified are copied into cache copies of the property, both to convert from 
		%> visual description (c/d, Hz, degrees) to
		%> computer metrics, and to be animated and modified as independant
		%> variables. So xPosition is copied to xPositionOut and converted from
		%> degrees to pixels. The animation and drawing functions use these modified
		%> properties, and when they are updated, for example to change to a new
		%> xPosition, internal methods ensure reconversion and update any dependent
		%> properties. This method initialises the object with all the cache properties 
		%> for display.
		%>
		%> @param sM screenManager object to use
		% ===================================================================
		function setup(me,sM)
			
			reset(me); %reset object back to its initial state
			me.inSetup = true; me.isSetup = false;
			if isempty(me.isVisible); show(me); end

			addlistener(me,'changeScale',@me.calculateScale); %use an event to keep scale accurate
			addlistener(me,'changePhaseIncrement',@me.calculatePhaseIncrement);
			
			me.sM = sM;
			if ~sM.isOpen; error('Screen needs to be Open!'); end
			me.ppd=sM.ppd;
			me.screenVals = sM.screenVals;
			me.texture = []; %we need to reset this

			fn = sort(properties(me));
			for j=1:length(fn)
				if ~matches(fn{j}, me.ignoreProperties) %create a temporary dynamic property
					p=me.addprop([fn{j} 'Out']);
					if strcmp(fn{j},'sf');p.SetMethod = @set_sfOut;end
					if strcmp(fn{j},'tf');p.SetMethod = @set_tfOut;end
					if strcmp(fn{j},'reverseDirection');p.SetMethod = @set_reverseDirectionOut;end
					if strcmp(fn{j},'size');p.SetMethod = @set_sizeOut;end
					if strcmp(fn{j},'xPosition');p.SetMethod = @set_xPositionOut;end
					if strcmp(fn{j},'yPosition');p.SetMethod = @set_yPositionOut;end
					me.([fn{j} 'Out']) = me.(fn{j}); %copy our property value to our tempory copy
				end
			end
			
			addRuntimeProperties(me);
			
			if isempty(me.findprop('rotateMode'));p=me.addprop('rotateMode');p.Transient=true;p.Hidden=true;end
			if me.rotateTexture
				me.rotateMode = kPsychUseTextureMatrixForRotation;
			else
				me.rotateMode = [];
			end
			
			if isempty(me.findprop('gratingSize'));p=me.addprop('gratingSize');p.Transient=true;end
			me.gratingSize = round(me.ppd*me.size); %virtual support larger than initial size
			
			if isempty(me.findprop('phaseIncrement'))
				p=me.addprop('phaseIncrement');
			end
			
			if isempty(me.findprop('driftPhase'));p=me.addprop('driftPhase');p.Transient=true;end
			if me.correctPhase
				ps=me.calculatePhase;
				me.driftPhase=me.phaseOut-ps;
			else
				me.driftPhase=me.phaseOut;
			end
			
			if isempty(me.findprop('res'));p=me.addprop('res');p.Transient=true;end
			
			switch length(me.aspectRatio)
				case 1
					me.res = round([me.gratingSize*me.aspectRatio me.gratingSize]);
				case 2
					me.res = round([me.gratingSize*me.aspectRatio(1) me.gratingSize*me.aspectRatio(2)]);
			end
			if max(me.res) > me.sM.screenVals.width %scale to be no larger than screen width
				me.res = floor( me.res / (max(me.res) / me.sM.screenVals.width));
			end
			
			if me.mask == true
				me.maskValue = floor((me.ppd*me.size))/2;
			else
				me.maskValue = [];
			end
			
			if me.phaseReverseTime > 0
				me.phaseCounter = round(me.phaseReverseTime / me.sM.screenVals.ifi);
			end
			
			if isempty(me.baseColour)
				me.baseColourOut = me.sM.backgroundColour;
				me.baseColourOut(4) = me.alpha;
			end
				
			% this is a checkerboard shader
			[me.texture, ~, me.shader] = CreateProceduralCheckerboard(me.sM.win, ...
				me.res(1), me.res(2), me.maskValue);
			
			me.inSetup = false; me.isSetup = true;
			computePosition(me);
			setRect(me);

			function set_sfOut(me,value)
				me.sfCache = value;
				me.sfOut = me.sfCache;
				%fprintf('SET SFOut: %.2f | in: %.2f | scale: %.2f | size: %.2f\n', me.sfOut, me.sfCache, me.scale, me.sizeOut);
			end
			function set_tfOut(me,value)
				me.tfOut = value;
				notify(me,'changePhaseIncrement');
			end
			function set_reverseDirectionOut(me,value)
				me.reverseDirectionOut = value;
				notify(me,'changePhaseIncrement');
			end
			function set_sizeOut(me,value)
				me.sizeOut = ceil(value*me.ppd);
				%fprintf('SET sizeOut: %.2f | in: %.2f \n', me.sizeOut, value);
			end
			function set_xPositionOut(me, value)
				me.xPositionOut = value * me.ppd;
			end
			function set_yPositionOut(me,value)
				me.yPositionOut = value*me.ppd; 
			end
			
		end
		
		% ===================================================================
		%> @brief Update this stimulus object for display
		%>
		% ===================================================================
		function update(me)
			resetTicks(me);
			if me.correctPhase
				ps=me.calculatePhase;
				me.driftPhase=me.phaseOut-ps;
			else
				me.driftPhase=me.phaseOut;
			end
			glUseProgram(me.shader);
			if me.mask == true
				me.maskValue = me.sizeOut/2;
			else
				me.maskValue = 0;
			end
			glUniform1f(glGetUniformLocation(me.shader, 'radius'), me.maskValue);
			glUseProgram(0);
			computePosition(me);
			setRect(me);
		end
		
		% ===================================================================
		%> @brief Draw this stimulus object for display
		%>
		%> 
		% ===================================================================
		function draw(me)
			if me.isVisible && me.tick >= me.delayTicks && me.tick < me.offTicks
				Screen('DrawTexture', me.sM.win, me.texture, [],me.mvRect,...
					me.angleOut, [], [], me.baseColourOut, [], me.rotateMode,...
					[me.ppd, me.sfOut, me.contrastOut, me.driftPhase, ...
					me.colourOut,me.colour2Out]);
			end
			me.tick = me.tick + 1;
		end
		
		% ===================================================================
		%> @brief Animate this object for runExperiment
		%>
		% ===================================================================
		function animate(me)
			if me.isVisible && me.tick >= me.delayTicks
				if me.mouseOverride
					getMousePosition(me);
					if me.mouseValid
						me.mvRect = CenterRectOnPointd(me.mvRect, me.mouseX, me.mouseY);
					end
				end
				if me.doMotion
					me.mvRect=OffsetRect(me.mvRect,me.dX_,me.dY_);
				end
				if me.doDrift
					me.driftPhase = me.driftPhase + me.phaseIncrement;
					fprintf('Drift Phase: %.2f\n',me.driftPhase);
				end
				if mod(me.tick,me.phaseCounter) == 0
					tmp = me.colourOut;
					me.colourOut = me.colour2Out;
					me.colour2Out = tmp;
					%me.driftPhase = me.driftPhase + me.phaseOfReverse;
				end
			end
		end
		
		% ===================================================================
		%> @brief Reset an structure for runExperiment
		%>
		%> @param rE runExperiment object for reference
		%> @return stimulus structure.
		% ===================================================================
		function reset(me)
			resetTicks(me);
			if ~isempty(me.texture) && Screen(me.texture,'WindowKind') == -1
				try Screen('Close',me.texture); end
			end
			me.texture=[];
			me.shader=[];
			if me.mask > 0
				me.mask = true;
			end
			me.maskValue = [];
			removeTmpProperties(me);
		end
		
		% ===================================================================
		%> @brief sf Set method
		%>
		% ===================================================================
		function set.sf(me,value)
			if value <= 0
				value = 0.05;
			end
			me.sf = value;
			me.salutation(['set sf: ' num2str(value)],'Custom set method')
		end
		
		% ===================================================================
		%> @brief SET Colour2 method
		%> Allow 1 (R=G=B) 3 (RGB) or 4 (RGBA) value colour
		% ===================================================================
		function set.colour2(me,value)
			len=length(value);
			switch len
				case {4,3}
					me.colour2 = [value(1:3) me.alpha]; %force our alpha to override
				case 1
					me.colour2 = [value value value me.alpha]; %construct RGBA
				otherwise
					me.colour2 = [1 1 1 me.alpha]; %return white for everything else
			end
			me.colour2(me.colour2<0)=0; me.colour2(me.colour2>1)=1;
		end
		
		% ===================================================================
		%> @brief SET baseColour method
		%> Allow 1 (R=G=B) 3 (RGB) or 4 (RGBA) value colour
		% ===================================================================
		function set.baseColour(me,value)
			len=length(value);
			switch len
				case 4
					me.baseColour = value;
				case 3
					me.baseColour = [value(1:3) me.alpha]; %force our alpha to override
				case 1
					me.baseColour = [value value value me.alpha]; %construct RGBA
				otherwise
					me.baseColour = [1 1 1 me.alpha]; %return white for everything else	
			end
			me.baseColour(me.baseColour<0)=0; me.baseColour(me.baseColour>1)=1;
		end
			
		% ===================================================================
		%> @brief calculate phase offset
		%>
		% ===================================================================
		function phase = calculatePhase(me)
			phase = 0;
			if me.correctPhase > 0
				ppd = me.ppd;
				size = (me.sizeOut/2); %divide by 2 to get the 0 point
				sfTmp = (me.sfOut/me.scale)*me.ppd;
				md = size / (ppd/sfTmp);
				md=md-floor(md);
				phase = (360*md);
			end
		end
		
	end %---END PUBLIC METHODS---%
	
	
	%=======================================================================
	methods ( Access = protected ) %-------PROTECTED METHODS-----%
	%=======================================================================
	
		% ===================================================================
		%> @brief setRect
		%> setRect makes the PsychRect based on the texture and screen values
		%> this is modified over parent method as gratings have slightly different
		%> requirements.
		% ===================================================================
		function setRect(me)
			%me.dstRect=Screen('Rect',me.texture);
			me.dstRect=ScaleRect([0 0 me.res(1) me.res(2)],me.scale,me.scale);
			if me.mouseOverride && me.mouseValid
					me.dstRect = CenterRectOnPointd(me.dstRect, me.mouseX, me.mouseY);
			else
				if isempty(me.findprop('directionOut'))
					[sx, sy]=pol2cart(me.d2r(me.direction),me.startPosition);
				else
					[sx, sy]=pol2cart(me.d2r(me.directionOut),me.startPosition);
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
		%> @brief calculateScale 
		%> Use an event to recalculate scale as get method is slower (called
		%> many more times), than an event which is only called on update
		% ===================================================================
		function calculateScale(me,~,~)
			me.scale = me.sizeOut/(me.size*me.ppd);
			me.maskValue = me.sizeOut / 2;
			fprintf('Calculate SFOut: %.2f | in: %.2f | scale: %.2f | size: %.2f\n', me.sfOut, me.sfCache, me.scale, me.sizeOut);
		end
		
		% ===================================================================
		%> @brief calculatePhaseIncrement
		%> Use an event to recalculate as get method is slower (called
		%> many more times), than an event which is only called on update
		% ===================================================================
		function calculatePhaseIncrement(me,~,~)
			if ~isempty(me.findprop('tfOut'))
				me.phaseIncrement = (me.tfOut * 360) * me.sM.screenVals.ifi;
				if ~isempty(me.findprop('reverseDirectionOut'))
					if me.reverseDirectionOut == false
						me.phaseIncrement = -me.phaseIncrement;
					end
				end
			end
		end
		
	end
end
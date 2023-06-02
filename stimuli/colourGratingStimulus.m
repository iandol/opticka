% ========================================================================
%> @brief colour grating stimulus, inherits from baseStimulus
%> COLOURGRATINGSTIMULUS colour grating stimulus, inherits from baseStimulus
%>   The basic properties are:
%>   type = 'sinusoid' or 'square', if square you should set sigma which
%>		smoothes the interface and stops pixel motion artifacts that normally
%>		inflict square wave gratings, set sigma to 0 to remove smoothing.
%>	 colour = first grating colour
%>   colour2 = second grating colour
%>   baseColour = the midpoint between the two from where contrast works,
%>		defult just inherits the background colour from screenManager
%>   correctBaseColour = automatically generate baseColour as the average
%>		of colour and colour2
%>   contrast = contrast from 0 - 1
%>   sf = spatial frequency in degrees
%>   tf = temporal frequency in degs/s
%>   angle = angle in degrees
%>   rotateTexture = do we rotate the grating texture (true) or the patch itself (false)
%>   phase = phase of grating
%>   mask = use circular mask (true) or not (false)
%>
%> See docs for more property details.
%>
%> @todo phase appears different to gratingStimulus, work out why
%>
%> Copyright ©2014-2022 Ian Max Andolina — released: LGPL3, see LICENCE.md
% ========================================================================
classdef colourGratingStimulus < baseStimulus
	
	properties %--------------------PUBLIC PROPERTIES----------%
		%> family type, can be 'sinusoid' or 'square'
		type char 				= 'sinusoid'
		%> spatial frequency of the grating
		sf(1,1) double			= 1
		%> temporal frequency of the grating
		tf(1,1) double			= 1
		%> second colour of a colour grating stimulus
		colour2(1,:) double		= [0 1 0 1]
		%> base colour from which colour and colour2 are blended via contrast value
		%> if empty [default], uses the background colour from screenManager
		baseColour(1,:) double		= []
		%> rotate the grating patch (false) or the grating texture within the patch (default = true)?
		rotateTexture logical	= true
		%> phase of grating
		phase(1,1) double			= 0
		%> contrast of grating (technically the contrast from the baseColour)
		contrast(1,1) double			= 0.5
		%> use a circular mask for the grating (default = true).
		mask logical			= true
		%> direction of the drift; default = false means drift left>right when angle is 0deg.
		%This switch can be accomplished simply setting angle, but this control enables
		%simple reverse direction protocols.
		reverseDirection logical = false
		%> the direction of the grating object if moving.
		direction double		= 0
		%> Do we need to correct the phase to be relative to center not edge? This enables
		%> centre surround stimuli are phase matched, and if we enlarge a grating object its
		%> phase stays identical at the centre of the object (where we would imagine our RF)
		correctPhase logical	= false
		%> In certain cases the base colour should be calculated
		%> dynamically from colour and colour2, and this enables this to
		%> occur blend
		correctBaseColour logical = false
		%> Reverse phase of grating X times per second? Useful with a static grating for linearity testing
		phaseReverseTime(1,1) double = 0
		%> What phase to use for reverse?
		phaseOfReverse(1,1) double	= 180
		%> sigma of square wave smoothing, use -1 for sinusoidal gratings
		sigma(1,1) double			= -1
		%> aspect ratio of the grating
		aspectRatio(1,1) double		= 1;
        %> turn stimulus on/off at X hz, [] diables this
        visibleRate             = []
	end
	
	properties (SetAccess = protected, GetAccess = public)
		%stimulus family
		family char				= 'grating'
		%> scale is used when changing size as an independent variable to keep sf accurate
		scale double			= 1
		%> the phase amount we need to add for each frame of animation
		phaseIncrement double	= 0
	end
	
	properties (Constant)
		typeList cell			= {'sinusoid';'square'}
	end

	properties (SetAccess = protected, GetAccess = {?baseStimulus})
		%> properties to not show in the UI panel
		ignorePropertiesUI = 'alpha';
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
			'sigma', 'correctPhase', 'phaseReverseTime', 'phaseOfReverse','visibleRate'}
		%> properties to not create transient copies of during setup phase
		ignoreProperties = {'type', 'scale', 'phaseIncrement', 'correctPhase', 'contrastMult', 'mask', 'typeList'}
		%> how many frames between phase reverses
		phaseCounter			= 0
		%> mask value (radius for the procedural shader)
		maskValue
		%> the raw shader, we can try to change colours.
		shader
		%> these store the current colour so we can check if update needs
		%to regenerate the shader
		colourCache
		colour2Cache
        visibleTick				= 0
		visibleFlip				= Inf
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
		function me = colourGratingStimulus(varargin)
			args = optickaCore.addDefaults(varargin,...
				struct('name','colour-grating','colour',[1 0 0 1],'colour2',[0 1 0 1]));
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
			
			me.sM = sM;
			if ~sM.isOpen; error('Screen needs to be Open!'); end
			me.ppd=sM.ppd;
			me.screenVals = sM.screenVals;
			me.texture = []; %we need to reset this

			fn = sort(properties(me));
			for j=1:length(fn)
				if ~matches(fn{j}, me.ignoreProperties)
					p=me.addprop([fn{j} 'Out']);
					if strcmp(fn{j}, 'sf'); p.SetMethod = @set_sfOut; end
					if strcmp(fn{j}, 'tf')
						p.SetMethod = @set_tfOut; p.SetObservable = true;
						addlistener(me, [fn{j} 'Out'], 'PostSet', @me.calculatePhaseIncrement);
					end
					if strcmp(fn{j}, 'reverseDirection')
						p.SetMethod = @set_reverseDirectionOut; p.SetObservable = true;
						addlistener(me, [fn{j} 'Out'], 'PostSet', @me.calculatePhaseIncrement);
					end
					if strcmp(fn{j}, 'size') 
						p.SetMethod = @set_sizeOut; p.SetObservable = true;
						addlistener(me, [fn{j} 'Out'], 'PostSet', @me.calculateScale);
					end
					if strcmp(fn{j}, 'xPosition'); p.SetMethod = @set_xPositionOut; end
					if strcmp(fn{j}, 'yPosition'); p.SetMethod = @set_yPositionOut; end
					if strcmp(fn{j}, 'colour')
						p.SetMethod = @set_cOut; p.SetObservable = true;
						addlistener(me, [fn{j} 'Out'], 'PostSet', @me.fixBaseColour);
					end
					if strcmp(fn{j}, 'colour2')
						p.SetMethod = @set_c2Out; p.SetObservable = true;
						addlistener(me, [fn{j} 'Out'], 'PostSet', @me.fixBaseColour);
					end
					me.([fn{j} 'Out']) = me.(fn{j}); %copy our property value to our temporary copy
				end
			end
			
			addRuntimeProperties(me);
			
			if ~isprop(me,'rotateMode'); addprop(me,'rotateMode'); end
			if me.rotateTexture
				me.rotateMode = kPsychUseTextureMatrixForRotation;
			else
				me.rotateMode = [];
			end
			
			if ~isprop(me,'gratingSize'); addprop(me,'gratingSize'); end
			me.gratingSize = round(me.ppd*me.size); %virtual support larger than initial size
			
			if ~isprop(me,'driftPhase'); addprop(me,'driftPhase'); end
			if me.correctPhase
				ps = me.calculatePhase;
				me.driftPhase = me.phaseOut-ps;
			else
				me.driftPhase = me.phaseOut;
			end
			
			if ~isprop(me,'res'); addprop(me,'res'); end
			
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
				if me.correctBaseColour
					me.baseColourOut = (me.colourOut(1:3) + me.colour2Out(1:3)) / 2;
					me.baseColourOut(4) = me.alpha;
				else
					me.baseColourOut = me.sM.backgroundColour;
					me.baseColourOut(4) = me.alpha;
				end
			end
			
			if strcmpi(me.type,'square')
				if me.sigma < 0; me.sigma = 0.05; me.sigmaOut = me.sigma; end
			else
				me.salutation('SETUP', 'Reset sigma to -1 as type=squarewave', true)
				me.sigmaOut = -1; %just make sure type overrides sigma if conflict
			end
				
			% this is a two color grating, passing in colorA and colorB.
			[me.texture, ~, me.shader] = CreateProceduralColorGrating(me.sM.win, me.res(1),...
				me.res(2), me.colourOut, me.colour2Out, me.maskValue);
			me.colourCache = me.colourOut; me.colour2Cache = me.colour2Out;

			if ~isempty(me.visibleRateOut) && isnumeric(me.visibleRateOut)
                me.visibleTick = 0;
                me.visibleFlip = round((me.screenVals.fps/2) / me.visibleRateOut);
			else
				me.visibleFlip = Inf; me.visibleTick = 0;
			end
			
			me.inSetup = false; me.isSetup = true;
			computePosition(me);
			setRect(me);

			function set_cOut(me, value)
				len=length(value);
				switch len
					case {4,3}
						c = [value(1:3) me.alpha]; %force our alpha to override
					case 1
						c = [value value value me.alpha]; %construct RGBA
					otherwise
						c = [1 1 1 me.alpha]; %return white for everything else
				end
				c(c<0)=0; c(c>1)=1;
				me.colourOut = c;
			end
			function set_c2Out(me, value) %#ok<*MCSGP> 
				len=length(value);
				switch len
					case {4,3}
						c = [value(1:3) me.alpha]; %force our alpha to override
					case 1
						c = [value value value me.alpha]; %construct RGBA
					otherwise
						c = [1 1 1 me.alpha]; %return white for everything else
				end
				c(c<0)=0; c(c>1)=1;
				me.colour2Out = c;
			end
			function set_sfOut(me,value)
				if me.sfRecurse == false
					me.sfCache = (value / me.ppd);
					me.sfOut = me.sfCache * me.scale;
				else
					me.sfOut = value;
					me.sfRecurse = false;
				end
				%fprintf('\nSET SFOut: %d | cache: %d | in: %d\n', me.sfOut, me.sfCache, value);
			end
			function set_tfOut(me,value)
				me.tfOut = value;
			end
			function set_reverseDirectionOut(me,value)
				me.reverseDirectionOut = value;
			end
			function set_sizeOut(me,value)
				me.sizeOut = value*me.ppd;
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
            me.isVisible = true;
            me.visibleTick = 0;
			if me.correctPhase
				ps=me.calculatePhase;
				me.driftPhase=me.phaseOut-ps;
			else
				me.driftPhase=me.phaseOut;
			end
			if ~all(me.colourCache(1:3) == me.colourOut(1:3)) || ...
				~all(me.colour2Cache(1:3) == me.colour2Out(1:3))
				glUseProgram(me.shader);
				glUniform4f(glGetUniformLocation(me.shader, 'color1'),...
					me.colourOut(1),me.colourOut(2),me.colourOut(3),me.alphaOut);
				glUniform4f(glGetUniformLocation(me.shader, 'color2'),...
					me.colour2Out(1),me.colour2Out(2),me.colour2Out(3),me.alphaOut);
				if me.mask == true
					me.maskValue = me.sizeOut/2;
				else
					me.maskValue = 0;
				end
				glUniform1f(glGetUniformLocation(me.shader, 'radius'), me.maskValue);
				glUseProgram(0);
				me.colourCache = me.colourOut; me.colour2Cache = me.colour2Out;
			end
			if ~isempty(me.visibleRateOut) && isnumeric(me.visibleRateOut)
                me.visibleTick = 0;
                me.visibleFlip = round((me.screenVals.fps/2) / me.visibleRateOut);
			else
				me.visibleFlip = Inf; me.visibleTick = 0;
			end
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
				Screen('DrawTexture', me.sM.win, me.texture, [], me.mvRect,...
					me.angleOut, [], [], me.baseColourOut, [], me.rotateMode,...
					[me.driftPhase, me.sfOut, me.contrastOut, me.sigmaOut]);
			end
			me.tick = me.tick + 1;
		end
		
		% ===================================================================
		%> @brief Animate this object for runExperiment
		%>
		% ===================================================================
		function animate(me)
			if (me.isVisible || ~isempty(me.visibleRate)) && me.tick >= me.delayTicks
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
				end
				if mod(me.tick,me.phaseCounter) == 0
					me.driftPhase = me.driftPhase + me.phaseOfReverse;
				end
                me.visibleTick = me.visibleTick + 1;
                if me.visibleTick == me.visibleFlip
                    me.isVisible = ~me.isVisible;
                    me.visibleTick = 0;
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
			me.inSetup = false; me.isSetup = false;
			if ~isempty(me.texture) && Screen(me.texture,'WindowKind') == -1
				try Screen('Close',me.texture); end %#ok<*TRYNC>
			end
			me.visibleFlip = Inf; me.visibleTick = 0;
			me.texture=[];
			me.shader=[];
			if me.mask > 0
				me.mask = true;
			end
			me.maskValue = [];
			me.removeTmpProperties;
			list = {'res','gratingSize','driftPhase','rotateMode'};
			for l = list; if isprop(me,l{1});delete(me.findprop(l{1}));end;end
		end

		% ===================================================================
		%> @brief calculate phase offset
		%>
		% ===================================================================
		function phase = calculatePhase(me)
			phase = 0;
			if me.correctPhase > 0
				ppd		= me.ppd;
				size	= (me.sizeOut / 2); %divide by 2 to get the 0 point
				sfTmp	= (me.sfOut / me.scale) * ppd;
				md		= size / (ppd / sfTmp);
				md		= md - floor(md);
				% note for some reason colourgratings are 180° different to
				% gratings, so we compensate here so they should align if
				% correctPhase is true
				phase	= (360 * md) + 180;
			end
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
				case 4
					c = value;
				case 3
					c = [value(1:3) me.alpha]; %force our alpha to override
				case 1
					c = [value value value me.alpha]; %construct RGBA
				otherwise
					c = [1 1 1 me.alpha]; %return white for everything else
			end
			c(c<0)=0; c(c>1)=1;
			me.colour2 = c;
			if isprop(me, 'baseColour') && me.correctBaseColour %#ok<*MCSUP> 
				me.baseColour = (me.colour(1:3) + me.colour2(1:3))/2;
			end
		end
		
		% ===================================================================
		%> @brief SET baseColour method
		%> Allow 1 (R=G=B) 3 (RGB) or 4 (RGBA) value colour
		% ===================================================================
		function set.baseColour(me,value)
			len=length(value);
			switch len
				case 4
					c = value;
				case 3
					c = [value(1:3) me.alpha]; %force our alpha to override
				case 1
					c = [value value value me.alpha]; %construct RGBA
				otherwise
					c = [1 1 1 me.alpha]; %return white for everything else	
			end
			c(c<0)=0; c(c>1)=1;
			me.baseColour = c;
		end


		% ===================================================================
		%> @brief sfOut Pseudo Get method
		%>
		% ===================================================================
		function sf = getsfOut(me)
			sf = 0;
			if ~isempty(me.sfCache)
				sf = me.sfCache * me.ppd;
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
				if isprop(me, 'directionOut')
					[sx, sy]=pol2cart(me.d2r(me.directionOut),me.startPosition);
				else
					[sx, sy]=pol2cart(me.d2r(me.direction),me.startPosition);
				end
				me.dstRect=CenterRectOnPointd(me.dstRect,me.sM.xCenter,me.sM.yCenter);
				if isprop(me, 'xPositionOut')
					me.dstRect=OffsetRect(me.dstRect,me.xPositionOut+(sx*me.ppd),me.yPositionOut+(sy*me.ppd));
				else
					me.dstRect=OffsetRect(me.dstRect,(me.xPosition)*me.ppd,(me.yPosition)*me.ppd);
				end
			end
			me.mvRect=me.dstRect;
			setAnimationDelta(me);
		end
		
		% ===================================================================
		%> @brief calculateScale 
		%> Use an event to recalculate scale as get method is slower (called
		%> many more times), than an event which is only called on update
		% ===================================================================
		function calculateScale(me,~,~)
			me.scale = me.sizeOut/(me.size*me.ppd);
			me.maskValue = me.sizeOut / 2;
			me.sfRecurse = true;
			me.sfOut = me.sfCache * me.scale;
			%fprintf('\nCalculate SFOut: %d | in: %d | scale: %d\n', me.sfOut, me.sfCache, me.scale);
		end
		
		% ===================================================================
		%> @brief calculatePhaseIncrement
		%> Use an event to recalculate as get method is slower (called
		%> many more times), than an event which is only called on update
		% ===================================================================
		function calculatePhaseIncrement(me,~,~)
			if isprop(me,'tfOut')
				me.phaseIncrement = (me.tfOut * 360) * me.sM.screenVals.ifi;
				if isprop(me,'reverseDirectionOut')
					if me.reverseDirectionOut == false
						me.phaseIncrement = -me.phaseIncrement;
					end
				end
			end
		end

		% ===================================================================
		%> @brief fixBaseColour POST SET
		%> 
		% ===================================================================
		function fixBaseColour(me,varargin)
			if me.correctBaseColour %#ok<*MCSUP> 
				if isprop(me, 'baseColourOut')
					me.baseColourOut = (me.getP('colour',[1:3]) + me.getP('colour2',[1:3])) / 2;
				else
					me.baseColour = (me.getP('colour',[1:3]) + me.getP('colour2',[1:3])) / 2;
				end
			end
		end
		
	end
end
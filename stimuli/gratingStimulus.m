% ========================================================================
%> @brief single grating stimulus, inherits from baseStimulus
%> GRATINGSTIMULUS single grating stimulus, inherits from baseStimulus
%>   The basic properties are:
%>   sf = spatial frequency in degrees
%>   tf = temporal frequency in degs/s
%>   angle = angle in degrees
%>   rotateTexture = do we rotate the grating texture (true) or the patch itself (false)
%>   phase = phase of grating
%>   contrast = contrast from 0 - 1
%>   mask = use circular mask (true) or not (false)
%>   correctPhase = set the phase from the center rather than edge
%>   sigma = optional smoothing for circular masks
%>
%> See docs for more property details
%>
%> Copyright ©2014-2022 Ian Max Andolina — released: LGPL3, see LICENCE.md
% ========================================================================
classdef gratingStimulus < baseStimulus

	properties %--------------------PUBLIC PROPERTIES----------%
		%> family type, can be 'sinusoid' or 'square'
		type					= 'sinusoid'
		%> spatial frequency of the grating
		sf						= 1
		%> temporal frequency of the grating
		tf						= 1
		%> rotate the grating patch (false) or the grating texture within the patch (true [default])?
		rotateTexture logical	= true
		%> phase of grating
		phase					= 0
		%> contrast of grating
		contrast				= 0.5
		%> use a circular mask for the grating (default = true), note this can also be smoothed at the edge.
		mask logical			= true
		%> direction of the drift; default = false means drift left>right when angle is 0deg.
		%This switch can be accomplished simply setting angle, but this control enables
		%simple reverse direction protocols.
		reverseDirection logical = false
		%> the direction of the whole grating object - i.e. the object can
		%> move as well as the grating texture rotate within the object.
		direction				= 0
		%> Do we need to correct the phase to be relative to center not edge? This enables
		%> centre surround stimuli are phase matched, and if we enlarge a grating object its
		%> phase stays identical at the centre of the object (where we would imagine our RF)
		correctPhase logical	= false
		%> Reverse phase of grating X times per second? Useful with a static grating for linearity testing
		phaseReverseTime		= 0
		%> What phase to use for reverse?
		phaseOfReverse			= 180
		%> If mask == true, cosine smoothing sigma in pixels for mask
		sigma					= 0
		%> If mask == true, use colour or alpha channel for smoothing?
		useAlpha logical		= true
		%> If mask == true, use hermite interpolation (true, default) or cosine (false)
		smoothMethod logical	= true
		%> aspect ratio of the grating, can be [x y] to select width height differently
		aspectRatio				= 1;
	end
	
	properties (Hidden = true)
		%> PTB Contrast Multiplier, 0.5 gives "standard" 0-1 contrast measure (see PTB docs)
		contrastMult			= 0.5
	end

	properties (SetAccess = protected, GetAccess = public)
		%stimulus family
		family					= 'grating'
		%> scale is used when changing size as an independent variable to keep sf accurate
		scale					= 1
		%> the phase amount we need to add for each frame of animation
		phaseIncrement			= 0
	end

	properties (SetAccess = private, GetAccess = public, Hidden = true)
		typeList				= {'sinusoid';'square'}
	end

	properties (SetAccess = protected, GetAccess = protected)
		%> beware alpha blending affects alpha so you need to change the
		%> modulateColour
		modulateColor			= [1 1 1 0]
		%> we need different blend mode depending on square or sin wave
		src						= 'GL_SRC_ALPHA'
		dst						= 'GL_ONE_MINUS_SRC_ALPHA'
		%> as get methods are slow, we cache sf, then recalculate sf whenever
		%> changeScale event is called
		sfCache					= []
		%>to stop a loop between set method and an event
		sfRecurse				= false
		%> allowed properties passed to object upon construction
		allowedProperties = ['type|sf|tf|angle|direction|phase|rotateTexture|' ...
			'contrast|mask|reverseDirection|speed|startPosition|aspectRatio|' ...
			'contrastMult|sigma|useAlpha|smoothMethod|' ...
			'correctPhase|phaseReverseTime|phaseOfReverse']
		%>properties to not create transient copies of during setup phase
		ignoreProperties		= 'name|type|scale|phaseIncrement|correctPhase|contrastMult|mask'
		%> how many frames between phase reverses
		phaseCounter			= 0
		%> do we generate a square wave?
		squareWave				= false
		%> mask value
		maskValue
		%> change blend?
		changeBlend				= false
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
		function me = gratingStimulus(varargin)
			args = optickaCore.addDefaults(varargin,...
				struct('name','grating','colour',[0.5 0.5 0.5 1],'alpha',1));
			me=me@baseStimulus(args); %we call the superclass constructor first
			me.parseArgs(args, me.allowedProperties);
			
			me.isRect = true; %uses a rect for drawing

			me.ignoreProperties = ['^(' me.ignorePropertiesBase '|' me.ignoreProperties ')$'];
			me.salutation('constructor','Initialisation complete');
		end

		% ===================================================================
		%> @brief Setup this object in preperation for use
		%> When displaying a stimulus object, the main properties that are to be
		%> modified are copied into cache copies of the property, both to convert from
		%> visual description (c/d, Hz, degrees) to
		%> computer metrics, and to be animated and modified as independant
		%> variables. So xPosition is copied to xPositionOut and converyed from
		%> degrees to pixels. The animation and drawing functions use these modified
		%> properties, and when they are updated, for example to change to a new
		%> xPosition, internal methods ensure reconversion and update any dependent
		%> properties. This method initialises the object for display.
		%>
		%> @param sM screenManager object for reference
		% ===================================================================
		function setup(me,sM)

			reset(me); %reset it back to its initial state
			me.inSetup = true;
			if isempty(me.isVisible)
				show(me);
			end
			
			me.sM = sM;
			if ~sM.isOpen; warning('Screen needs to be Open!'); end
			me.screenVals = sM.screenVals;
			me.ppd = sM.ppd;			

			me.texture = []; %we need to reset this

			props = properties(me);
			for pn = 1:numel(props)
				pr = props{pn};
				if isempty(regexp(pr, me.ignoreProperties, 'once')) %create a temporary dynamic property
					p=me.addprop([pr 'Out']);
					if strcmp(pr,'sf'); p.SetMethod = @set_sfOut; end
					if strcmp(pr,'tf'); ...
							p.SetMethod = @set_tfOut; ...
							p.SetObservable = true; ...
							addlistener(me, [pr 'Out'], 'PostSet', @me.calculatePhaseIncrement); end
					if strcmp(pr,'reverseDirection'); ...
							p.SetMethod = @set_reverseDirectionOut; ...
							p.SetObservable = true; ...
							addlistener(me, [pr 'Out'], 'PostSet', @me.calculatePhaseIncrement); end
					if strcmp(pr,'size'); ...
							p.SetMethod = @set_sizeOut; ...
							p.SetObservable = true; ...
							addlistener(me, [pr 'Out'], 'PostSet', @me.calculateScale); end
					if strcmp(pr,'xPosition');p.SetMethod = @set_xPositionOut;end
					if strcmp(pr,'yPosition');p.SetMethod = @set_yPositionOut;end
					me.([pr 'Out']) = me.(pr); %copy our property value to our temporary copy
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
			me.gratingSize = round(me.ppd*me.size);

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

			if me.mask == true
				me.maskValue = floor((me.ppd*me.size)/2);
			else
				me.maskValue = [];
			end

			if isempty(me.findprop('texture'));p=me.addprop('texture');p.Transient=true;end

			if me.phaseReverseTime > 0
				me.phaseCounter = round(me.phaseReverseTime / me.sM.screenVals.ifi);
			end

			if strcmpi(me.type,'square')
				me.src = 'GL_ONE';
				me.dst = 'GL_ZERO';
				me.modulateColor = [1 1 1 1];
				me.texture = CreateProceduralSquareWaveGrating(me.sM.win, me.res(1),...
					me.res(2), me.colourOut, me.maskValue, me.contrastMult);
			else
				me.src = 'GL_SRC_ALPHA';
				me.dst = 'GL_ONE_MINUS_SRC_ALPHA';
				me.modulateColor = [1 1 1 0];
				if me.sigmaOut > 0
					me.texture = CreateProceduralSmoothedApertureSineGrating(me.sM.win, me.res(1), ...
						me.res(2), me.colourOut, me.maskValue, me.contrastMult, me.sigmaOut, ...
						me.useAlpha, me.smoothMethod);
				else
					me.texture = CreateProceduralSineGrating(me.sM.win, me.res(1),...
						me.res(2), me.colourOut, me.maskValue, me.contrastMult);
				end
			end
			
			if me.sM.blend == true && strcmpi(me.sM.srcMode,me.src) && strcmpi(me.sM.dstMode,me.dst)
				me.changeBlend = false;
			else
				me.changeBlend = true;
			end

			me.inSetup = false;
			computePosition(me);
			setRect(me);

			function set_sfOut(me,value)
				if me.sfRecurse == false
					me.sfCache = (value/me.ppd);
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
				me.setLoop = me.setLoop + 1;
				if me.setLoop == 1; me.xPositionOut = value * me.ppd; else; warning('Recursion: xPositionOut'); end
				me.setLoop = 0;
			end
			function set_yPositionOut(me,value)
				me.setLoop = me.setLoop + 1;
				if me.setLoop == 1; me.yPositionOut = value*me.ppd; else; warning('Recursion: yPositionOut'); end
				me.setLoop = 0;	
			end

		end

		% ===================================================================
		%> @brief Update this stimulus object for display
		%>
		% ===================================================================
		function update(me)
			resetTicks(me);
			updateShader(me);
			if me.correctPhase
				ps = me.calculatePhase;
				me.driftPhase = me.phaseOut - ps;
			else
				me.driftPhase = me.phaseOut;
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
				if me.changeBlend;Screen('BlendFunction', me.sM.win, me.src, me.dst);end
				Screen('DrawTexture', me.sM.win, me.texture, [],me.mvRect,...
					me.angleOut, [], [], me.modulateColor, [], me.rotateMode,...
					[me.driftPhase, me.sfOut, me.contrastOut, me.sigmaOut]);
				if me.changeBlend; Screen('BlendFunction', me.sM.win, me.sM.srcMode, me.sM.dstMode); end
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
				end
				if mod(me.tick,me.phaseCounter) == 0
					me.driftPhase = me.driftPhase + me.phaseOfReverse;
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
			me.setLoop = 0;
			me.inSetup = false; me.isSetup = false;
			if isprop(me,'texture')
				if ~isempty(me.texture) && me.texture > 0 && Screen(me.texture,'WindowKind') == -1
					try Screen('Close',me.texture); end %#ok<*TRYNC>
				end
				me.texture = []; 
			end
			me.phaseCounter = 0;
			if me.mask > 0
				me.mask = true;
			end
			me.maskValue = [];
			me.removeTmpProperties;
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
				phase	= (360 * md);
			end
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
			if isempty(me.texture);return;end
			me.dstRect=ScaleRect(Screen('Rect',me.texture),me.scale,me.scale);
			if me.mouseOverride && me.mouseValid
				me.dstRect = CenterRectOnPointd(me.dstRect, me.mouseX, me.mouseY);
			else
				[~, name] = getP(me, 'direction');
				[sx, sy]=pol2cart(me.d2r(me.(name)),me.startPosition);
				me.dstRect=CenterRectOnPointd(me.dstRect,me.sM.xCenter,me.sM.yCenter);
				if ~isprop(me,'xPositionOut')
					me.dstRect=OffsetRect(me.dstRect, me.xPosition*me.ppd, me.yPosition*me.ppd);
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
			me.sfRecurse = true;
			me.sfOut = me.sfCache * me.scale;
			setRect(me);
			%fprintf('\nCalculate SF ScaleOut: %d | in: %d | scale: %d\n', me.sfOut, me.sfCache, me.scale);
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
		%> @brief updateShader 
		%> check if we need and update shader texture
		%> 
		% ===================================================================
		function updateShader(me)
			if ~all(me.colour == me.colourOut)
				if isprop(me,'texture')
					if ~isempty(me.texture) && me.texture > 0 && Screen(me.texture,'WindowKind') == -1
						try Screen('Close',me.texture); end %#ok<*TRYNC>
					end
					me.texture = []; 
				end
				if strcmpi(me.type,'square')
					me.texture = CreateProceduralSquareWaveGrating(me.sM.win, me.res(1),...
						me.res(2), me.colourOut, me.maskValue, me.contrastMult);
				else
					if me.sigmaOut > 0
						me.texture = CreateProceduralSmoothedApertureSineGrating(me.sM.win, me.res(1), ...
							me.res(2), me.colourOut, me.maskValue, me.contrastMult, me.sigmaOut, ...
							me.useAlpha, me.smoothMethod);
					else
						me.texture = CreateProceduralSineGrating(me.sM.win, me.res(1),...
							me.res(2), me.colourOut, me.maskValue, me.contrastMult);
					end
				end
			end
		end

	end
end
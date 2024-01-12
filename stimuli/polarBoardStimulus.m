% ========================================================================
%> @brief polar checkerboard stimulus, inherits from baseStimulus
%> POLARBOARDSTIMULUS inherits from baseStimulus
%>   The basic properties are:
%>   type = '', 'randdrift', 'spiraldrift', 'sine'
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
%> @todo spatial and temporal frequency is approximated
%>
%> Copyright ©2014-2022 Ian Max Andolina — released: LGPL3, see LICENCE.md
% ========================================================================
classdef polarBoardStimulus < baseStimulus
	
	properties %--------------------PUBLIC PROPERTIES----------%
		%> default = '' | random dir changes = 'randdrift'
		%> tf affects circular and radial = 'spiraldrift'
		%> sine option with a different shader = 'sine'
		type char 				= ''
		%> second colour of a colour grating stimulus
		colour2(1,:) double		= [0 0 0 1]
		%> base colour from which colour and colour2 are blended via contrast value
		%> if empty [default], uses the background colour from screenManager
		baseColour(1,:) double		= []
		%> arc segment start angle and width in degrees (0 disable)
		arcValue(1,2) double	= [0 0]
		%> shoud arc be symmetrical
		arcSymmetry logical		= false
		%> do we mask (size in degrees) the centre part?
		centerMask(1,1) double	= 0
		%> "spatial frequency" of the circular grating at ~5deg
		%> sf is pretty relative as it changes from the center
		sf(1,1) double			= 1
		%> temporal frequency of the grating
		tf(1,1) double			= 1
		%> "spatial frequency" of the radial grating (number of spokes)
		sf2(1,1) double			= 20
		%> only used for type='sine'
		sigma(1,1) double		= -1
		%> rotate the grating patch (false) or the grating texture within the patch (default = true)?
		rotateTexture logical	= true
		%> phase of grating
		phase(1,1) double		= 0
		%> contrast of grating (technically the contrast from the baseColour)
		contrast(1,1) double	= 0.5
		%> use a circular mask for the grating (default = true).
		mask logical			= true
		%> direction of the drift; default = false means drift left>right when angle is 0deg.
		%> This switch can be accomplished simply setting angle, but this control enables
		%? simple reverse direction protocols.
		reverseDirection logical = false
		%> the direction of the grating object if speed > 0.
		direction double		= 0
		%> In certain cases the base colour should be calculated
		%> dynamically from colour and colour2, and this enables this to
		%> occur blend
		correctBaseColour logical = false
		%> Reverse phase of grating X times per second? Useful with a static grating for linearity testing
		phaseReverseTime(1,1) double = 0
		%> What phase to use for reverse?
		phaseOfReverse(1,1) double	= 180
        %> turn stimulus on/off at X hz, [] diables this
        visibleRate             = []
	end
	
	properties (SetAccess = protected, GetAccess = public)
		%stimulus family
		family char				= 'checkerboard'
		%> scale is used when changing size as an independent variable to keep sf accurate
		scale double			= 1
		%> the phase amount we need to add for each frame of animation
		phaseIncrement double	= 0
	end
	
	properties (Constant)
		typeList cell			= {'';'randdrift';'spiraldrift';'sine'}
	end

	properties (SetAccess = protected, GetAccess = {?baseStimulus})
		%> properties to not show in the UI panel
		ignorePropertiesUI = 'alpha';
	end
	
	properties (SetAccess = protected, GetAccess = protected)
		sfCache
		sf2Cache
		%> allowed properties passed to object upon construction
		allowedProperties = {'type','colour2', 'sf', 'tf', 'angle', 'direction', 'phase', 'rotateTexture' ... 
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
		needUpdate				= false;
		colourCache
		colour2Cache
        visibleTick				= 0
		visibleFlip				= Inf
		cMaskTex
		cMaskRect
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
		function me = polarBoardStimulus(varargin)
			args = optickaCore.addDefaults(varargin,...
				struct('name','polar-board','colour',[1 1 1 1],'colour2',[0 0 0 1]));
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
					if strcmp(fn{j}, 'sf2'); p.SetMethod = @set_sf2Out; end
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
			me.driftPhase = me.phaseOut;
			if ~isprop(me,'driftPhase2'); addprop(me,'driftPhase2'); end
			me.driftPhase2 = me.phaseOut;
			
			if ~isprop(me,'res'); addprop(me,'res'); end
			me.res = round([me.gratingSize me.gratingSize]);	
			if max(me.res) > me.sM.screenVals.width*1.5 %scale to be no larger than screen width
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
			
			if matches(me.type,'sine')
				[me.texture, ~, me.shader] = CreateProceduralPolarBoard(me.sM.win, me.res(1),...
					me.res(2), me.colourOut, me.colour2Out, me.maskValue,'sine');
			else
				[me.texture, ~, me.shader] = CreateProceduralPolarBoard(me.sM.win, me.res(1),...
					me.res(2), me.colourOut, me.colour2Out, me.maskValue,'');
			end
			me.colourCache = me.colourOut; me.colour2Cache = me.colour2Out;

			if ~isempty(me.visibleRateOut) && isnumeric(me.visibleRateOut)
                me.visibleTick = 0;
                me.visibleFlip = round((me.screenVals.fps/2) / me.visibleRateOut);
			else
				me.visibleFlip = Inf; me.visibleTick = 0;
			end

			updateSFs(me);
			
			me.inSetup = false; me.isSetup = true;
			computePosition(me);
			setRect(me);

			if me.centerMask > 0
				sz = round(me.centerMask * me.ppd);
				[me.cMaskTex, me.cMaskRect] = CreateProceduralSmoothedDisc(me.sM.win,...
					sz, sz, [], round(sz/2), round(sz/10), true, 1);
				me.cMaskRect = CenterRectOnPointd(me.cMaskRect, me.xFinal, me.yFinal);
			end

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
				me.needUpdate = true;
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
				me.needUpdate = true;
			end
			function set_sfOut(me,value)
				me.sfOut = value * (me.ppd*3*(1/me.ppd)) * me.scale;
				me.sfCache = me.sfOut;
			end
			function set_sf2Out(me,value)
				me.sf2Out = round(value * me.scale);
				me.sf2Cache = me.sf2Out;
			end
			function set_tfOut(me,value)
				me.tfOut = value;
			end
			function set_reverseDirectionOut(me,value)
				me.reverseDirectionOut = value;
			end
			function set_sizeOut(me,value)
				me.sizeOut = value*me.ppd;
				me.needUpdate = true;
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

			me.driftPhase=me.phaseOut;
			me.driftPhase2=me.driftPhase;

			if me.mask == true
				me.maskValue = floor(me.sizeOut/2);
			else
				me.maskValue = [];
			end

			if me.needUpdate
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
				me.needUpdate = false;
			end

			if ~isempty(me.visibleRateOut) && isnumeric(me.visibleRateOut)
				me.visibleTick = 0;
				me.visibleFlip = round((me.screenVals.fps/2) / me.visibleRateOut);
			else
				me.visibleFlip = Inf; me.visibleTick = 0;
			end

			updateSFs(me);
			computePosition(me);
			setRect(me);

			if me.centerMask > 0
				me.cMaskRect = CenterRectOnPointd(me.cMaskRect, me.xFinal, me.yFinal);
			end
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
					[me.driftPhase, me.driftPhase2, me.sfOut, me.sf2Out, ...
					me.contrastOut, me.sigmaOut, 0, 0]);
				if me.arcValueOut(2) > 0
					if me.arcSymmetry
						a = me.arcValueOut(1) + (me.arcValueOut(2) / 2);
						b = 180 - me.arcValueOut(2);
						c = a + 180;
						Screen('FillArc', me.sM.win, me.baseColourOut, ...
							[me.mvRect(1)-2 me.mvRect(2)-2 me.mvRect(3)+2 me.mvRect(4)+2], a, b);
						Screen('FillArc', me.sM.win, me.baseColourOut, ...
							[me.mvRect(1)-2 me.mvRect(2)-2 me.mvRect(3)+2 me.mvRect(4)+2], c, b);
					else
						a = me.arcValueOut(1) + (me.arcValueOut(2) / 2);
						b = 360 - me.arcValueOut(2);
						Screen('FillArc', me.sM.win, me.baseColourOut, ...
							[me.mvRect(1)-2 me.mvRect(2)-2 me.mvRect(3)+2 me.mvRect(4)+2], a, b);
					end
				end
				if me.centerMask > 0
					Screen('DrawTexture', me.sM.win, me.cMaskTex, [], me.cMaskRect, [], [], 1, me.baseColourOut, [], []);
				end
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
					if matches(me.type,'randdrift') && rand > 0.975; me.phaseIncrement = -me.phaseIncrement; end
					me.driftPhase = me.driftPhase + me.phaseIncrement;
					if matches(me.type,'spiraldrift'); me.driftPhase2=me.driftPhase; end
				end
				if me.phaseReverseTime > 0 && mod(me.tick, me.phaseCounter) == 0
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
			me.phaseCounter = [];
			me.removeTmpProperties;
			list = {'res','gratingSize','driftPhase','rotateMode'};
			for l = list; if isprop(me,l{1});delete(me.findprop(l{1}));end;end
		end

		% ===================================================================
		%> @brief sf Set method
		%>
		% ===================================================================
		function set.sf(me,value)
			if value <= 0
				value = 0.01;
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
				me.dstRect = CenterRectOnPointd(me.dstRect, me.xFinal, me.yFinal);
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
			if me.mask == true
				me.maskValue = floor(me.sizeOut/2);
			else
				me.maskValue = [];
			end
			try me.sfOut = me.sfCache; end
			try me.sf2Out = me.sf2Cache; end
			updateSFs(me);
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
					me.baseColourOut = (me.getP('colour',1:3) + me.getP('colour2',1:3)) / 2;
				else
					me.baseColour = (me.getP('colour',1:3) + me.getP('colour2',1:3)) / 2;
				end
			end
		end

		% ===================================================================
		%> @brief updateSFs
		%> 
		% ===================================================================
		function updateSFs(me)
			if me.verbose;fprintf('SF modification: ppd: %.2f | SF circular: %.2f | SF radial: %.2f\n',me.ppd, me.sfOut,me.sf2Out);end
		end
		
	end
end
% ========================================================================
%> @class dotlineStimulus
%> @brief Show lines made of dots
%>
%> Class providing basic structure for dotline (texture) stimulus classes.
%> You can control multiple aspects of the image presentation, and scale
%> images to values in degrees, rotate them, animate them etc.
%>
%> Copyright ©2014-2024 Ian Max Andolina — released: LGPL3, see LICENCE.md
% ========================================================================
classdef dotlineStimulus < baseStimulus
	properties %--------------------PUBLIC PROPERTIES----------%
		%> stimulus type: 'circle', 'square'
		type char					= 'circle'
		%> item size
		itemSize					= 0.8
		%> inter-item distance
		itemDistance				= 1
		%> phase (0 - 360)
		phase						= 0
		%> direction for motion of the image, different to angle
		direction					= 0
		%> force the angle to be orthogonal to the direction
		forceOrthogonal				= false
		%> use even and odd colours?
		useEven						= false
		%> even colour
		colour2						= [0 0 0 1]
		%> contrast multiplier 
		contrast double				= 1
		%> precision: 0 = 8bit | 1 = 16bit | 2 = 32bit
		precision					= 0
		%> special flags: 0 = hardware filter, 2 = PTB
		%> filter, 4 = fast texture creation, 8 = prevent
		%> auto mip-map generation, 32 = stop Screen('Close')
		%> clearing texture
		specialFlags				= []
		%> How to compute the pixel color values when the texture is drawn 
		%> magnified, minified or drawn shifted, e.g., if
		%> sourceRect and destinationRect do not have the same size or if
		%> sourceRect specifies fractional pixel values. 0 = Nearest
		%> neighbour filtering, 1 = Bilinear filtering - this is the
		%> default. Values 2 or 3 select use of OpenGL mip-mapping for
		%> improved quality: 2 = Bilinear filtering for nearest mipmap
		%> level, 3 = Trilinear filtering across mipmap levels, 4 = Nearest
		%> neighbour filtering for nearest mipmap level, 5 = nearest
		%> neighbour filtering with linear interpolation between mipmap
		%> levels. Mipmap filtering is only supported for GL_TEXTURE_2D
		%> textures (see description of 'specialFlags' flag 1 below). A
		%> negative filterMode value will also use mip-mapping for fast
		%> drawing of blurred textures if the GL_TEXTURE_2D format is used:
		%> Mip-maps are essentially image resolution pyramids, the
		%> filterMode value selects a specific layer in that pyramid. A
		%> value of -1 draws the highest resolution layer, a value of -2
		%> draws a half-resolution layer, a value of -3 draws a quarter
		%> resolution layer and so on. Each layer has half the resolution of
		%> the preceeding layer. This allows for very fast drawing of
		%> blurred or low-pass filtered images, e.g., for gaze-contingent
		%> displays.
		filter						= 1
	end

	properties (SetAccess = protected, GetAccess = public, Transient = true)
		%> scale is set by size
		scale						= 1
		%>
		matrix
		%> pixel width
		width
		%> pixel height
		height
		%> base colour (usually the background of the screen)
		baseColour
	end

	properties (SetAccess = protected, GetAccess = public)
		family						= 'texture'
	end

	properties (SetAccess = protected, GetAccess = public, Hidden = true)
		typeList			= {'circle','square'}
		interpMethodList	= {'nearest','linear','spline','cubic'}
		%> properties to ignore in the UI
		ignorePropertiesUI	= {}
		filePath			= [];
	end

	properties (Access = protected)
		%> allowed properties passed to object upon construction
		allowedProperties = {'type', 'contrast', ...
			'itemSize','itemDistance','phase','direction',...
			'forceOrthogonal','useEven','colour2',...
			'precision','filter', 'specialFlags'}
		%>properties to not create transient copies of during setup phase
		ignoreProperties = {'type', 'scale', 'width', 'height'}
	end

	%=======================================================================
	methods %------------------PUBLIC METHODS
	%=======================================================================

		% ===================================================================
		%> @brief Class constructor
		%>
		%> This parses any input values and initialises the object.
		%>
		%> @param varargin are passed as a list of parametoer or a structure
		%> of properties which is parsed.
		%>
		%> @return instance of class.
		% ===================================================================
		function me = dotlineStimulus(varargin)
			args = optickaCore.addDefaults(varargin,struct('size',10,...
				'name','DotLine'));
			me=me@baseStimulus(args); %we call the superclass constructor first
			me.parseArgs(args, me.allowedProperties);

			me.isRect = true; %uses a rect for drawing

			me.ignoreProperties = [me.ignorePropertiesBase me.ignoreProperties];
			me.logOutput('constructor','DotLine Stimulus initialisation complete');
		end

		% ===================================================================
		%> @brief Setup this object in preperation for use
		%> When displaying a stimulus object, the main properties that are to be
		%> modified are copied into cache copies of the property, both to convert from
		%> visual description (c/d, Hz, degrees) to
		%> computer metrics; and to be animated and modified as independant
		%> variables. So xPosition is copied to xPositionOut and converted from
		%> degrees to pixels. The animation and drawing functions use these modified
		%> properties, and when they are updated, for example to change to a new
		%> xPosition, internal methods ensure reconversion and update any dependent
		%> properties. This method initialises the object in preperation for display.
		%>
		%> @param sM screenManager object for reference
		% ===================================================================
		function setup(me, sM)

			reset(me); %reset object back to its initial state
			me.inSetup = true; me.isSetup = false;
			if isempty(me.isVisible); show(me); end

			me.sM = sM;
			if ~sM.isOpen; error('Screen needs to be Open!'); end
			me.ppd = sM.ppd;
			me.screenVals = sM.screenVals;
			
			if isempty(me.direction); me.direction = me.angle; end

			fn = sort(properties(me));
			for j=1:length(fn)
				if ~matches(fn{j}, me.ignoreProperties) %create a temporary dynamic property
					p = me.addprop([fn{j} 'Out']);
					if strcmp(fn{j},'xPosition'); p.SetMethod = @set_xPositionOut; end
					if strcmp(fn{j},'yPosition'); p.SetMethod = @set_yPositionOut; end
					if strcmp(fn{j},'size'); p.SetMethod = @set_sizeOut; end
					me.([fn{j} 'Out']) = me.(fn{j}); %copy our property value to our tempory copy
				end
			end

			addRuntimeProperties(me);

			if me.forceOrthogonal
				me.angleOut = me.directionOut + 90;
			end

			me.inSetup = false; me.isSetup = true;

			makeLine(me);
			computePosition(me);
			if me.doAnimator
				setup(me.animator, me);
			end
			setRect(me);

			function set_xPositionOut(me, value)
				me.xPositionOut = value * me.ppd;
			end
			function set_yPositionOut(me,value)
				me.yPositionOut = value * me.ppd; 
			end
			function set_sizeOut(me,value)
				me.sizeOut = value * me.ppd;
				me.szPx = me.sizeOut;
			end
			
		end

		% ===================================================================
		%> @brief Make the line texture
		%>
		% ===================================================================
		function makeLine(me)
			tt = tic;

			ep = me.sizeOut;
			es = me.itemSize * me.ppd;
			mp = ep / 2;
			dp = me.itemDistance * me.ppd;

			phase = me.phaseOut / 360;

			pos = [fliplr([mp:-dp:0]) [mp+dp:dp:ep]] + (phase * dp);
			if pos(1) > dp
				pos = [pos(1) - dp pos];
			end
			lrect = [0 0 ep es*1.5];
			me.width = RectWidth(lrect);
			me.height = RectHeight(lrect);
			crect =[0 0 es es];
			%[windowPtr,rect]=Screen('OpenOffscreenWindow',windowPtrOrScreenNumber 
			%[,color] [,rect] [,pixelSize] [,specialFlags] 
			% [,multiSample]);
			owin = Screen('OpenOffscreenWindow',me.sM.win,[me.sM.backgroundColour(1:3) 0], ...
				lrect,8,1,[]);

			c1 = me.colourOut(1:3) * me.contrast;
			c2 = me.colour2Out(1:3) * me.contrast;
			
			% make the position rects and the colours of each dot
			for i = 1:length(pos)
				trect = CenterRectOnPointd(crect,pos(i),lrect(4)/2);
				orects(:,i) = trect';
				if me.useEven && me.isOdd(i) || ~me.useEven
					colours(:,i) = [c1 me.alphaOut]';
				elseif me.useEven && ~me.isOdd(i)
					colours(:,i) = [c2 me.alphaOut]';
				end
			end
		
			% circle or square
			if strcmpi(me.type,'circle')
				Screen('FillOval', owin, colours, orects, 100);
			else
				Screen('FillRect', owin, colours, orects);
			end
		
			% dram a small frame around the texture for debugging
			debug = false;
			if debug
				Screen('FrameRect', owin, [0 0 0 0.2], lrect, 2);
			end

			me.texture = owin;

			if me.verbose;me.logOutput('makeLine',['Made dotline in ' num2str(toc(tt)) ' secs']);end
		end

		% ===================================================================
		%> @brief Update this stimulus object structure for screenManager
		%>
		% ===================================================================
		function update(me)
			if me.forceOrthogonal
				me.angleOut = me.directionOut + 90;
			end
			makeLine(me);
			resetTicks(me);
			computePosition(me);
			setRect(me);
		end

		% ===================================================================
		%> @brief Draw this stimulus object
		%>
		% ===================================================================
		function draw(me, win)
			if me.isVisible && me.tick >= me.delayTicks && me.tick < me.offTicks
				if ~exist('win','var');win = me.sM.win; end
				% Screen('DrawTexture', windowPointer, texturePointer [,sourceRect] [,destinationRect] [,rotationAngle]
				% [, filterMode] [, globalAlpha] [, modulateColor] [, textureShader] [, specialFlags] [, auxParameters]);
				Screen('DrawTexture', win, me.texture, [], me.mvRect,...
					me.angleOut, me.filter, me.alphaOut);
			end
			me.tick = me.tick + 1;
		end

		% ===================================================================
		%> @brief Animate this stimulus object
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
				if me.doAnimator
					animate(me.animator);
					me.updateXY(me.animator.x, me.animator.y, true);
					me.angleOut = -rad2deg(me.animator.angle);
				elseif me.doMotion == 1
					me.mvRect=OffsetRect(me.mvRect,me.dX_,me.dY_);
				end
			end
		end

		% ===================================================================
		%> @brief Reset this object
		%>
		% ===================================================================
		function reset(me)
			if ~isempty(me.texture) && me.texture > 0 && Screen(me.texture,'WindowKind') == -1
				try Screen('Close',me.texture); end %#ok<*TRYNC>
			end
			if isprop(me,'doAnimator') && me.doAnimator; reset(me.animator); end
			resetTicks(me);
			me.texture=[];
			me.matrix = [];
			me.scale = 1;
			me.mvRect = [];
			me.dstRect = [];
			me.width = [];
			me.height = [];
			removeTmpProperties(me);
		end

	end %---END PUBLIC METHODS---%

	%=======================================================================
	methods ( Access = protected ) %-------PROTECTED METHODS-----%
	%=======================================================================

		function result = isOdd(~,n)
			result = logical(mod(n,2));
		end

	end

end

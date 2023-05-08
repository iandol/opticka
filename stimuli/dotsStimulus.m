% ========================================================================
%> @brief dotsStimulus simple variable coherence dots stimulus, inherits from baseStimulus
%>
%>
%>
%> Copyright ©2014-2022 Ian Max Andolina — released: LGPL3, see LICENCE.md
% ========================================================================
classdef dotsStimulus < baseStimulus
	
	properties %--------------------PUBLIC PROPERTIES----------%
		%> dot type, only simple supported at present
		type				= 'simple'
		%> dots per degree
		density				= 100
		%> how to colour the dots: simple, random, randomN, randomBW, randomNBW, binary
		colourType			= 'randomBW'
		%> width of dot (deg)
		dotSize				= 0.05
		%> dot coherence from 0 - 1, non-coherent dots are given a random direction
		coherence			= 0.5
		%> what proportion of dots are in the same direction, other dots are given the opposite direction
		angleProbability	= 1
		%> fraction of dots to kill each frame  (limited lifetime)
		kill				= 0
		%> type of dot (integer, where 0 means filled square, 1
		%> means filled circle, and 2/3 means filled circle with high-quality
		%> anti-aliasing)
		dotType				= 3
		%> whether to use a circular mask or not
		mask				= true
		%> whether to use a procedural (true) or texture (false) mask
		maskIsProcedural	= true
		%> colour of the mask, empty sets mask colour to = background of screen
		maskColour			= []
		%> smooth the alpha edge of the mask by this number of pixels, 0 is
		%> off
		maskSmoothing		= 11
		%> mask OpenGL blend modes
		msrcMode			= 'GL_SRC_ALPHA'
		mdstMode			= 'GL_ONE_MINUS_SRC_ALPHA'
	end
	
	properties (Dependent = true, SetAccess = private, GetAccess = public)
		%> number of dots
		nDots
	end
	
	properties (SetAccess = protected, GetAccess = public)
		%> stimulus family
		family				= 'dots'
		%> row are x and y and columns are each dot
		xy
		%> delta x and y for each dot
		dxdy
		%> colour for each dot
		colours
	end
	
	properties (SetAccess = private, GetAccess = public, Hidden = true, Transient = true)
		%> allows makePanel method to offer a UI menu of settings
		typeList = {'simple'}
		%> allows makePanel method to offer a UI menu of settings
		colourTypeList = {'simple','randomBW','randomNBW','random','randomN','binary'}
		%> allows makePanel method to offer a UI menu of settings
		msrcModeList = {'GL_ZERO','GL_ONE','GL_DST_COLOR','GL_ONE_MINUS_DST_COLOR',...
			'GL_SRC_ALPHA','GL_ONE_MINUS_SRC_ALPHA'}
		%> allows makePanel method to offer a UI menu of settings
		mdstModeList = {'GL_ZERO','GL_ONE','GL_DST_COLOR','GL_ONE_MINUS_DST_COLOR',...
			'GL_SRC_ALPHA','GL_ONE_MINUS_SRC_ALPHA'}
	end
	
	properties (SetAccess = private, GetAccess = private)
		%nDots cache
		nDots_
		%> we must scale the dots larger than the mask by this factor
		fieldScale			= 1.05
		%> resultant size of the mask after scaling
		fieldSize
		%> this holds the mask texture
		maskTexture
		%> the stimulus rect of the mask
		maskRect
		%> was mask blank when initialised?
		wasMaskColourBlank = false
		%> rDots used in coherence calculation
		rDots
		%> angles used in coherence calculation
		angles
		%> used during updateDots calculations
		dxs
		dys
		%> the smoothing kernel for the texture mask
		kernel				= []
		shader				= 0
		%> regexes for object management during construction
		allowedProperties={'msrcMode', 'mdstMode', 'type', 'density', ...
			'dotSize', 'colourType', 'coherence', 'dotType', 'kill', 'mask', ...
			'maskIsProcedural', 'maskSmoothing', 'maskColour'}
		%> regexes for object management during setup
		ignoreProperties={'name', 'family', 'xy', 'dxdy', 'colours', 'mask', ...
			'maskTexture', 'maskIsProcedural', 'maskColour', 'colourType', ...
			'msrcMode', 'mdstMode'}
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
		function me = dotsStimulus(varargin)
			args = optickaCore.addDefaults(varargin,...
				struct('name','dots','colour',[1 1 1],'speed',2));
			me=me@baseStimulus(args); %we call the superclass constructor first
			me.parseArgs(args, me.allowedProperties);
			
			me.isRect = false; %uses a point for drawing
			
			me.ignoreProperties = [me.ignorePropertiesBase me.ignoreProperties];
			me.salutation('constructor','Dots Stimulus initialisation complete');
		end
		
		% ===================================================================
		%> @brief Setup the stimulus object
		%>
		%> @param sM screenManager object for reference
		% ===================================================================
		function setup(me,sM)
			
			reset(me);
			me.inSetup = true; me.isSetup = false;
			if isempty(me.isVisible); me.show; end
			
			me.sM = sM;
			if ~sM.isOpen; warning('Screen needs to be Open!'); end
			me.screenVals = sM.screenVals;
			me.ppd = sM.ppd;
			
			fn = sort(fieldnames(me));
			for j=1:length(fn)
				if ~matches(fn{j}, me.ignoreProperties) %create a temporary dynamic property
					p=me.addprop([fn{j} 'Out']);
					if strcmp(fn{j},'size');p.SetMethod = @set_sizeOut;end
					if strcmp(fn{j},'dotSize');p.SetMethod = @set_dotSizeOut;end
					if strcmp(fn{j},'xPosition');p.SetMethod = @set_xPositionOut;end
					if strcmp(fn{j},'yPosition');p.SetMethod = @set_yPositionOut;end
					if strcmp(fn{j},'density');p.SetMethod = @set_densityOut;end
					me.([fn{j} 'Out']) = me.(fn{j}); %copy our property value to our tempory copy
				end
			end
			
			addRuntimeProperties(me);
			
			%build the mask
			if me.mask
				makeMask(me);
			end
			
			me.inSetup = false; me.isSetup = true;
			computePosition(me);
			setRect(me);
			updateDots(me);

			function set_xPositionOut(me, value)
				me.xPositionOut = value * me.ppd;
			end
			function set_yPositionOut(me,value)
				me.yPositionOut = value*me.ppd;
			end
			function set_sizeOut(me,value)
				me.sizeOut = value * me.ppd;
				if me.mask == true
					me.fieldSize = round(me.sizeOut + me.maskSmoothing); %mask needs to be bigger!
				else
					me.fieldSize = me.sizeOut;
				end
				me.nDots; %remake our cache
			end
			function set_dotSizeOut(me,value)
				me.dotSizeOut = value * me.ppd;
				if me.dotSizeOut < 1; me.dotSizeOut = 1; end
			end
			function set_densityOut(me,value)
				me.densityOut = value;
				me.nDots; %remake our cache
			end
			
		end
		
		% ===================================================================
		%> @brief Update object
		%>  We update the object once per trial (if we change parameters
		%>  for example)
		% ===================================================================
		function update(me)
			resetTicks(me);
			computePosition(me);
			setRect(me);
			updateDots(me);
		end
		
		% ===================================================================
		%> @brief Draw our stimulus structure
		%>
		% ===================================================================
		function draw(me)
			if me.isVisible && me.tick >= me.delayTicks && me.tick < me.offTicks
				if me.mask
					Screen('BlendFunction', me.sM.win, me.msrcMode, me.mdstMode);
					Screen('DrawDots', me.sM.win,me.xy,me.dotSizeOut,me.colours,...
						[me.xFinal me.yFinal],me.dotTypeOut);
					if me.maskIsProcedural
						Screen('DrawTexture', me.sM.win, me.maskTexture, [], me.maskRect,...
						[], [], 1, me.maskColour);
					else
						Screen('DrawTexture', me.sM.win, me.maskTexture, [], me.maskRect,...
						[], [], [], [], me.shader);
					end
					Screen('BlendFunction', me.sM.win, me.sM.srcMode, me.sM.dstMode);
				else
					Screen('DrawDots',me.sM.win,me.xy,me.dotSizeOut,me.colours,[me.xFinal me.yFinal],me.dotTypeOut);
				end
			end
			me.tick = me.tick + 1;
		end
		
		% ===================================================================
		%> @brief Animate this object by one frame
		%>
		% ===================================================================
		function animate(me)
			if me.isVisible && me.tick >= me.delayTicks && me.tick < me.offTicks
				if me.mouseOverride
					getMousePosition(me);
					if me.mouseValid
						me.xFinal = me.mouseX;
						me.yFinal = me.mouseY;
					end
				end
% 				if me.doMotion == true
% 					if me.doAnimator
% 						out = update(me.animator);
% 						me.xFinal = out(1);
% 						me.xFinal = out(2);
% 					else
% 						me.xFinal = me.xFinal + me.dX_;
% 						me.yFinal = me.yFinal + me.dY_;
% 					end
% 					me.maskRect=CenterRectOnPointd(me.maskRect,me.xFinal,me.yFinal);
% 				end
				me.xy = me.xy + me.dxdy; %increment position
				sz = me.sizeOut + me.maskSmoothing-(me.dotSizeOut*1.5);
				fix = find(me.xy > sz/2); %cull positive
				me.xy(fix) = me.xy(fix) - sz;
				fix = find(me.xy < -sz/2);  %cull negative
				me.xy(fix) = me.xy(fix) + sz;
				%me.xy(me.xy > sz) = me.xy(me.xy > sz) - me.sizeOut; % this is not faster
				%me.xy(me.xy < -sz) = me.xy(me.xy < -sz) + me.sizeOut; % this is not faster
				if me.killOut > 0 && me.tick > 1
					kidx = rand(me.nDots,1) <  me.killOut;
					ks = length(find(kidx > 0));
					me.xy(:,kidx) = (me.sizeOut .* rand(2,ks)) - me.sizeOut/2;
					%me.colours(3,kidx) = ones(1,ks);
				end
			end
		end
		
		% ===================================================================
		%> @brief reset the object, deleting the temporary .Out properties
		%>
		% ===================================================================
		function reset(me)
			me.removeTmpProperties;
			if me.wasMaskColourBlank;me.maskColour=[];end
			me.wasMaskColourBlank=false;
			me.angles = [];
			me.xy = [];
			me.dxs = [];
			me.dys = [];
			me.dxdy = [];
			me.colours = [];
			resetTicks(me);
		end
		
		% ===================================================================
		%> @brief density set method
		%>
		%> We need to update nDots if density is changed
		% ===================================================================
		function set.density(me,value)
			me.density = value;
			me.nDots; %#ok<MCSUP>
		end
		
		% ===================================================================
		%> @brief nDots is dependant property, this get method also caches
		%> the value in me.nDots_ fo speed
		%>
		% ===================================================================
		function value = get.nDots(me)
			if ~me.inSetup && isprop(me,'sizeOut')
				sz = me.sizeOut + me.maskSmoothing - (me.dotSizeOut*1.5);
				me.nDots_ = round(me.densityOut * (sz/me.ppd)^2);
			else
				me.nDots_ = round(me.density * me.size^2);
			end
			value = me.nDots_;
		end
		
	end %---END PUBLIC METHODS---%
	
	%=======================================================================
	methods ( Access = protected ) %-------PROTECTED METHODS-----%
		%=======================================================================
		
		% ===================================================================
		%> @brief setRect
		%> setRect makes the PsychRect based on the texture and screen
		%> values, you should call computePosition() first to get xOut and
		%> yOut
		% ===================================================================
		function setRect(me)
			if ~isempty(me.maskTexture)
				me.dstRect= [ 0 0 me.fieldSize me.fieldSize];
				if me.mouseOverride && me.mouseValid
					me.dstRect = CenterRectOnPointd(me.dstRect, me.mouseX, me.mouseY);
				else
					me.dstRect=CenterRectOnPointd(me.dstRect, me.xFinal, me.yFinal);
				end
				me.mvRect=me.dstRect; me.maskRect=me.dstRect;
			end
		end
		% ===================================================================
		%> @brief Update the dots based on current variable settings
		%>
		% ===================================================================
		function updateDots(me)
			makeColours(me)
			%sort out our angles and percent incoherent
			me.angles = ones(me.nDots_,1) .* me.angleOut;
			if me.angleProbability < 1
				n = round(me.nDots_*me.angleProbability);
				me.angles(1:n) = me.angleOut + 180;
			end
			me.rDots=me.nDots_-floor(me.nDots_*(me.coherenceOut));
			if me.rDots>0
				me.angles(1:me.rDots) = me.r2d((2*pi).*rand(1,me.rDots));
				me.angles = Shuffle(me.angles(1:me.nDots_)); %if we don't shuffle them, all coherent dots show on top!
			end
			%calculate positions and vector offsets
			sz=me.sizeOut+me.maskSmoothing-(me.dotSizeOut*1.5);
			me.xy = sz .* rand(2,me.nDots_);
			me.xy = me.xy - sz / 2; %so we are centered for -xy to +xy
			[me.dxs, me.dys] = me.updatePosition(repmat(me.delta,size(me.angles)),me.angles);
			me.dxdy=[me.dxs';me.dys'];
		end
		
		% ===================================================================
		%> @brief Make colour matrix for dots
		%>
		% ===================================================================
		function makeColours(me)
			switch me.colourType
				case 'simple'
					me.colours = repmat(me.colourOut',1,me.nDots_);
					me.colours(4,:) = me.alphaOut;
				case 'random'
					me.colours = rand(4,me.nDots_);
					me.colours(4,:) = me.alphaOut;
				case 'randomN'
					me.colours = randn(4,me.nDots_);
					me.colours(4,:) = me.alphaOut;
				case 'randomBW'
					me.colours=zeros(4,me.nDots_);
					for i = 1:me.nDots_
						me.colours(:,i)=rand;
					end
					me.colours(4,:)=me.alphaOut;
				case 'randomNBW'
					me.colours=zeros(4,me.nDots_);
					for i = 1:me.nDots_
						me.colours(:,i)=randn;
					end
					me.colours(4,:)=me.alphaOut;
				case 'binary'
					me.colours=zeros(4,me.nDots_);
					rix = round(rand(me.nDots_,1)) > 0;
					me.colours(:,rix) = 1;
					me.colours(4,:)=me.alphaOut; %set the alpha level
				otherwise
					me.colours = repmat(me.colourOut',1,me.nDots_);
					me.colours(4,:) = me.alphaOut;
			end
		end
		
		% ===================================================================
		%> @brief Make circular mask 
		%>
		% ===================================================================
		function makeMask(me)
			if isempty(me.maskColour)
				me.wasMaskColourBlank = true;
				me.maskColour = me.sM.backgroundColour;
				if me.maskIsProcedural
					me.maskColour(4) = 1; %set alpha to 1
				else
					me.maskColour(4) = 0; %set alpha to 0
				end
			else
				me.wasMaskColourBlank = false;
			end
			if me.maskIsProcedural
				[me.maskTexture, me.maskRect] = CreateProceduralSmoothedDisc(me.sM.win,...
					me.fieldSize, me.fieldSize, [], round(me.sizeOut/2 + (me.maskSmoothing/2)), me.maskSmoothing, true, 2);
			else
				wrect = SetRect(0, 0, me.fieldSize, me.fieldSize);
				mrect = SetRect(0, 0, me.sizeOut, me.sizeOut);
				mrect = CenterRect(mrect,wrect);
				bg = [me.sM.backgroundColour(1:3) 1];
				me.maskTexture = Screen('OpenOffscreenwindow', me.sM.win, bg, wrect);
				Screen('FillOval', me.maskTexture, me.maskColour, mrect);
				me.maskRect = CenterRectOnPointd(wrect,me.xPositionOut,me.yPositionOut);
				if me.maskSmoothing > 0
					if ~rem(me.maskSmoothing, 2)
						me.maskSmoothing = me.maskSmoothing + 1;
					end
					if exist('fspecial','file')
						me.kernel = fspecial('gaussian',me.maskSmoothing,me.maskSmoothing);
						me.shader = EXPCreateStatic2DConvolutionShader(me.kernel, 4, 4, 0, 2);
					else
						p = mfilename('fullpath');
						p = fileparts(p);
						ktmp = load([p filesep 'gaussian52kernel.mat']); %'gaussian73kernel.mat' 'disk5kernel.mat'
						me.kernel = ktmp.kernel;
						me.shader = EXPCreateStatic2DConvolutionShader(me.kernel, 4, 4, 0, 2);
						me.salutation('No fspecial, had to use precompiled kernel');
					end
				else
					me.kernel = [];
					me.shader = 0;
				end
			end
		end
		
	end
end
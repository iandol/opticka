% ========================================================================
%> @brief dotsStimulus simple variable coherence dots stimulus, inherits from baseStimulus
%>
%> 
% ========================================================================
classdef dotsStimulus < baseStimulus

	properties %--------------------PUBLIC PROPERTIES----------%
		%> dot type, only simple supported at present
		type		= 'simple'
		%> dots per degree
		density		= 100
		%> how to colour the dots: random, randomN, randomBW, randomNBW, binary
		colourType	= 'randomBW'
		%> width of dot (deg)
		dotSize		= 0.05
		%> dot coherence from 0 - 1
		coherence	= 0.5
		%> fraction of dots to kill each frame  (limited lifetime)
		kill		= 0
		%> type of dot (integer, where 0 means filled square, 1
		%> means filled circle, and 2 means filled circle with high-quality
		%> anti-aliasing)
		dotType		= 2
		%> whether to use a circular mask or not
		mask		= false
		%> colour of the mask, empty sets mask colour to = background of screen
		maskColour	= []
		%> smooth the alpha edge of the mask by this number of pixels, 0 is
		%> off
		maskSmoothing = 0
		%> mask OpenGL blend modes
		msrcMode	= 'GL_SRC_ALPHA'
		mdstMode	= 'GL_ONE_MINUS_SRC_ALPHA'
	end
	
	properties (Dependent = true, SetAccess = private, GetAccess = public)
		%> number of dots
		nDots
	end
	
	properties (SetAccess = protected, GetAccess = public)
		%> stimulus family
		family		= 'dots'
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
		%> we must scale the dots lager than the mask by this factor
		fieldScale	= 1.15
		%> resultant size of the dotfield after scaling
		fieldSize
		%> this holds the mask texture
		maskTexture
		%> the stimulus rect of the mask
		maskRect
		%> rDots used in coherence calculation
		rDots
		%> angles used in coherence calculation
		angles
		%> used during updateDots calculations
		dxs
		dys
		%> the smoothing kernel for the mask
		kernel		= []
		shader		= 0
		%> regexes for object management during construction
		allowedProperties='msrcMode|mdstMode|type|density|dotSize|colourType|coherence|dotType|kill|mask|maskSmoothing|maskColour';
		%> regexes for object management during setup
		ignoreProperties='name|family|xy|dxdy|colours|mask|maskTexture|maskColour|colourType|msrcMode|mdstMode'
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
		function obj = dotsStimulus(varargin)
			%Initialise for superclass, stops a noargs error
			if nargin == 0
				varargin.family = 'dots';
				varargin.colour = [1 1 1 1];
				varargin.speed = 2;
			end
			
			obj=obj@baseStimulus(varargin); %we call the superclass constructor first
			
			if nargin>0
				obj.parseArgs(varargin, obj.allowedProperties);
			end
			
			obj.ignoreProperties = ['^(' obj.ignorePropertiesBase '|' obj.ignoreProperties ')$'];
			obj.salutation('constructor','Dots Stimulus initialisation complete');
		end
		
		% ===================================================================
		%> @brief Setup the stimulus object 
		%>
		%> @param sM screenManager object for reference
		% ===================================================================
		function setup(obj,sM)
			
			obj.reset; %reset it back to its initial state
			obj.inSetup = true;
			if isempty(obj.isVisible)
				obj.show;
			end
			
			obj.sM = sM;
			obj.ppd=sM.ppd;
			
			fn = sort(properties('dotsStimulus'));
			for j=1:length(fn)
				if isempty(obj.findprop([fn{j} 'Out'])) && isempty(regexp(fn{j},obj.ignoreProperties, 'once')) %create a temporary dynamic property
					p=obj.addprop([fn{j} 'Out']);
					p.Transient = true;%p.Hidden = true;
					if strcmp(fn{j},'size');p.SetMethod = @set_sizeOut;end
					if strcmp(fn{j},'dotSize');p.SetMethod = @set_dotSizeOut;end
					if strcmp(fn{j},'xPosition');p.SetMethod = @set_xPositionOut;end
					if strcmp(fn{j},'yPosition');p.SetMethod = @set_yPositionOut;end
					if strcmp(fn{j},'density');p.SetMethod = @set_densityOut;end
				end
				if isempty(regexp(fn{j},obj.ignoreProperties, 'once'))
					obj.([fn{j} 'Out']) = obj.(fn{j}); %copy our property value to our tempory copy
				end
			end
			
			if isempty(obj.findprop('doDots'));p=obj.addprop('doDots');p.Transient = true;end
			if isempty(obj.findprop('doMotion'));p=obj.addprop('doMotion');p.Transient = true;end
			if isempty(obj.findprop('doDrift'));p=obj.addprop('doDrift');p.Transient = true;end
			if isempty(obj.findprop('doFlash'));p=obj.addprop('doFlash');p.Transient = true;end
			obj.doDots = true;
			obj.doMotion = false;
			obj.doDrift = false;
			obj.doFlash = false;
			
			%build the mask
			if obj.mask == true
				if isempty(obj.maskColour)
					obj.maskColour = obj.sM.backgroundColour;
				end
				wrect = SetRect(0, 0, obj.fieldSize, obj.fieldSize);
				mrect = SetRect(0, 0, obj.sizeOut, obj.sizeOut);
				mrect = CenterRect(mrect,wrect);
				bg = [obj.sM.backgroundColour(1:3) 1];
				obj.maskTexture = Screen('OpenOffscreenwindow', obj.sM.win, bg, wrect);
				Screen('FillOval', obj.maskTexture, obj.maskColour, mrect);
				obj.maskRect = CenterRectOnPointd(wrect,obj.xPositionOut,obj.yPositionOut);
				if obj.maskSmoothing > 0
					if ~rem(obj.maskSmoothing, 2)
						obj.maskSmoothing = obj.maskSmoothing + 1;
					end
					if exist('fspecial','file')
						obj.kernel = fspecial('gaussian',obj.maskSmoothing,obj.maskSmoothing);
						obj.shader = EXPCreateStatic2DConvolutionShader(obj.kernel, 4, 4, 0, 2);
					else
						p = mfilename('fullpath');
						p = fileparts(p);
						ktmp = load([p filesep 'gaussian52kernel.mat']); %'gaussian73kernel.mat' 'disk5kernel.mat'
						obj.kernel = ktmp.kernel;
						obj.shader = EXPCreateStatic2DConvolutionShader(obj.kernel, 4, 4, 0, 2);
						obj.salutation('No fspecial, had to use precompiled kernel');
					end
				else
					obj.kernel = [];
					obj.shader = 0;
				end
			end
			
			obj.inSetup = false;
			computePosition(obj);
			updateDots(obj);
			
		end
		
		% ===================================================================
		%> @brief Update object
		%>  We update the object once per trial (if we change parameters
		%>  for example)
		% ===================================================================
		function update(obj)
			resetTicks(obj);
			computePosition(obj);
			updateDots(obj);
		end
		
		% ===================================================================
		%> @brief Draw our stimulus structure
		%>
		% ===================================================================
		function draw(obj)
			if obj.isVisible && obj.tick >= obj.delayTicks && obj.tick < obj.offTicks
				try
					if obj.mask == true
						Screen('BlendFunction', obj.sM.win, obj.msrcMode, obj.mdstMode);
						Screen('DrawDots', obj.sM.win,obj.xy,obj.dotSizeOut,obj.colours,...
							[obj.xOut obj.yOut],obj.dotTypeOut);
						Screen('DrawTexture', obj.sM.win, obj.maskTexture, [], obj.maskRect, [], [], [], [], obj.shader);
						Screen('BlendFunction', obj.sM.win, obj.sM.srcMode, obj.sM.dstMode);
					else
						Screen('DrawDots',obj.sM.win,obj.xy,obj.dotSizeOut,obj.colours,[obj.xOut obj.yOut],obj.dotTypeOut);
					end
				catch ME
					ple(ME)
				end
			end
			obj.tick = obj.tick + 1;
		end
		
		% ===================================================================
		%> @brief Animate this object by one frame
		%>
		% ===================================================================
		function animate(obj)
			if obj.isVisible == true && obj.tick > obj.delayTicks && obj.tick < obj.offTicks
				if obj.mouseOverride
					getMousePosition(obj);
					if obj.mouseValid
						obj.xOut = obj.mouseX;
						obj.yOut = obj.mouseY;
					end
				end
				obj.xy = obj.xy + obj.dxdy; %increment position
				sz = obj.sizeOut/2;
				fix = find(obj.xy > sz); %cull positive
				obj.xy(fix) = obj.xy(fix) - obj.sizeOut;
				fix = find(obj.xy < -sz);  %cull negative
				obj.xy(fix) = obj.xy(fix) + obj.sizeOut;
				%obj.xy(obj.xy > sz) = obj.xy(obj.xy > sz) - obj.sizeOut; % this is not faster
				%obj.xy(obj.xy < -sz) = obj.xy(obj.xy < -sz) + obj.sizeOut; % this is not faster
				if obj.killOut > 0 && obj.tick > 1
					kidx = rand(obj.nDots,1) <  obj.killOut;
					ks = length(find(kidx > 0));
					obj.xy(:,kidx) = (obj.sizeOut .* rand(2,ks)) - obj.sizeOut/2;
					%obj.colours(3,kidx) = ones(1,ks); 
				end
			end
		end
		
		% ===================================================================
		%> @brief reset the object, deleting the temporary .Out properties
		%>
		% ===================================================================
		function reset(obj)
			obj.removeTmpProperties;
			obj.angles = [];
			obj.xy = [];
			obj.dxs = [];
			obj.dys = [];
			obj.dxdy = [];
			obj.colours = [];
			resetTicks(obj);
		end
		
		% ===================================================================
		%> @brief density set method
		%>
		%> We need to update nDots if density is changed 
		% ===================================================================
		function set.density(obj,value)
			obj.density = value;
			obj.nDots; %#ok<MCSUP>
		end
		
		% ===================================================================
		%> @brief nDots is dependant property, this get method also caches
		%> the value in obj.nDots_ fo speed
		%>
		% ===================================================================
		function value = get.nDots(obj)
			if ~obj.inSetup && isprop(obj,'sizeOut')
				obj.nDots_ = round(obj.densityOut * (obj.sizeOut/obj.ppd)^2);
			else
				obj.nDots_ = round(obj.density * obj.size^2);
			end
			value = obj.nDots_;
		end
		
	end %---END PUBLIC METHODS---%
	
	%=======================================================================
	methods ( Access = protected ) %-------PROTECTED METHODS-----%
	%=======================================================================
		
		% ===================================================================
		%> @brief Update the dots based on current variable settings
		%>
		% ===================================================================
		function updateDots(obj)
			makeColours(obj)
			%sort out our angles and percent incoherent
			obj.angles = ones(obj.nDots_,1) .* obj.angleOut;
			obj.rDots=obj.nDots_-floor(obj.nDots_*(obj.coherenceOut));
			if obj.rDots>0
				obj.angles(1:obj.rDots) = obj.r2d((2*pi).*rand(1,obj.rDots));
				obj.angles = Shuffle(obj.angles(1:obj.nDots_)); %if we don't shuffle them, all coherent dots show on top!
			end
			%calculate positions and vector offsets
			obj.xy = obj.sizeOut .* rand(2,obj.nDots_);
			obj.xy = obj.xy - obj.sizeOut/2; %so we are centered for -xy to +xy
			[obj.dxs, obj.dys] = obj.updatePosition(repmat(obj.delta,size(obj.angles)),obj.angles);
			obj.dxdy=[obj.dxs';obj.dys'];
			if obj.mask == true
				obj.maskRect = CenterRectOnPointd(obj.maskRect,obj.xOut,obj.yOut);
			end
		end
		
		% ===================================================================
		%> @brief Make colour matrix for dots
		%>
		% ===================================================================
		function makeColours(obj)
			switch obj.colourType
				case 'simple'
					obj.colours = repmat(obj.colourOut',1,obj.nDots_);
					obj.colours(4,:) = obj.alphaOut;
				case 'random'
					obj.colours = rand(4,obj.nDots_);
					obj.colours(4,:) = obj.alphaOut;
				case 'randomN'
					obj.colours = randn(4,obj.nDots_);
					obj.colours(4,:) = obj.alphaOut;
				case 'randomBW'
					obj.colours=zeros(4,obj.nDots_);
					for i = 1:obj.nDots_
						obj.colours(:,i)=rand;
					end
					obj.colours(4,:)=obj.alphaOut;
				case 'randomNBW'
					obj.colours=zeros(4,obj.nDots_);
					for i = 1:obj.nDots_
						obj.colours(:,i)=randn;
					end
					obj.colours(4,:)=obj.alphaOut;
				case 'binary'
					obj.colours=zeros(4,obj.nDots_);
					rix = round(rand(obj.nDots_,1)) > 0;
					obj.colours(:,rix) = 1;
					obj.colours(4,:)=obj.alphaOut; %set the alpha level
				otherwise
					obj.colours = repmat(obj.colourOut',1,obj.nDots_);
					obj.colours(4,:) = obj.alphaOut;
			end
		end
		
		% ===================================================================
		%> @brief sizeOut Set method
		%>
		% ===================================================================
		function set_sizeOut(obj,value)
			obj.sizeOut = value * obj.ppd;
			if obj.mask == 1
				obj.fieldSize = (obj.sizeOut * obj.fieldScale) ; %for masking!
			else
				obj.fieldSize = obj.sizeOut;
			end
			obj.nDots; %remake our cache
		end
		
		% ===================================================================
		%> @brief dotSizeOut Set method
		%>
		% ===================================================================
		function set_dotSizeOut(obj,value)
			obj.dotSizeOut = value * obj.ppd;
		end
		
		% ===================================================================
		%> @brief density Set method
		%>
		% ===================================================================
		function set_densityOut(obj,value)
			obj.densityOut = value;
			obj.nDots; %remake our cache
		end

	end
end
classdef dotsStimulus < baseStimulus
	%DOTSSTIMULUS single coherent dots stimulus, inherits from baseStimulus
	%   The current properties are:
	
	properties %--------------------PUBLIC PROPERTIES----------%
		family = 'dots'
		type = 'simple'
		density = 100
		colourType = 'randomBW'
		dotSize  = 0.05  % width of dot (deg)
		coherence = 0.5
		kill      = 0 % fraction of dots to kill each frame  (limited lifetime)
		dotType = 1
		mask = true
		maskColour = []
		%> smooth the alpha edge of the mask by this number of pixels, 0 is
		%> off
		maskSmoothing = 0
		msrcMode = 'GL_SRC_ALPHA'
		mdstMode = 'GL_ONE_MINUS_SRC_ALPHA'
	end
	
	properties (Dependent = true, SetAccess = private, GetAccess = public)
		%> number of dots
		nDots
	end
	
	properties (SetAccess = private, GetAccess = public)
		%> row are x and y and columns are each dot
		xy
		%> delta x and y for each dot
		dxdy
		%> colour for each dot
		colours
	end
	properties (SetAccess = private, GetAccess = private)
		nDots_
		fieldScale = 1.1
		fieldSize
		maskTexture
		maskRect
		srcMode = 'GL_ONE'
		dstMode = 'GL_ZERO'
		rDots
		nDotsMax = 5000
		angles
		dSize
		fps = 60
		dxs
		dys
		kernel = []
		shader = 0
		allowedProperties='msrcMode|mdstMode|type|density|nDots|dotSize|colourType|coherence|dotType|kill|mask|maskSmoothing|maskColour';
		ignoreProperties='xy|dxdy|colours|mask|maskTexture|maskColour|colourType|msrcMode|mdstMode'
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
		%> @brief Setup an structure for runExperiment
		%>
		%> @param rE runExperiment object for reference
		%> @return
		% ===================================================================
		function setup(obj,rE)
			
			obj.dateStamp = clock;
			
			if exist('rE','var')
				obj.ppd=rE.ppd;
				obj.ifi=rE.screenVals.ifi;
				obj.xCenter=rE.xCenter;
				obj.yCenter=rE.yCenter;
				obj.win=rE.win;
				obj.srcMode=rE.srcMode;
				obj.dstMode=rE.dstMode;
				obj.backgroundColour = rE.backgroundColour;
			else
				obj.mask = false; %we can't open offscreen windows to make the mask
			end
			
			fn = properties('dotsStimulus');
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
			
			if isempty(obj.findprop('xTmp'));p=obj.addprop('xTmp');p.Transient = true;end
			if isempty(obj.findprop('yTmp'));p=obj.addprop('yTmp');p.Transient = true;end
			obj.xTmp = obj.xPositionOut; %xTmp and yTmp are temporary position stores.
			obj.yTmp = obj.yPositionOut;
			
			%build the mask
			if obj.mask == true
				if isempty(obj.maskColour)
					obj.maskColour = obj.backgroundColour;
				end
				wrect = SetRect(0, 0, obj.fieldSize, obj.fieldSize);
				mrect = SetRect(0, 0, obj.sizeOut, obj.sizeOut);
				mrect = CenterRect(mrect,wrect);
				bg = [obj.backgroundColour(1:3) 1];
				obj.maskTexture = Screen('OpenOffscreenwindow', obj.win, bg, wrect);
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
						ktmp = load([p filesep 'gaussian52kernel.mat']); %'gaussian73kernel.mat''disk5kernel.mat'
						obj.kernel = ktmp.kernel;
						obj.shader = EXPCreateStatic2DConvolutionShader(obj.kernel, 4, 4, 0, 2);
						obj.salutation('No fspecial, had to use precompiled kernel');
					end
				else
					obj.kernel = [];
					obj.shader = 0;
				end
			end
			
			%make our dot colours
			switch obj.colourType
				case 'random'
					obj.colours = rand(4,obj.nDots);
					obj.colours(4,:) = obj.alpha;
				case 'randomN'
					obj.colours = randn(4,obj.nDots);
					obj.colours(4,:) = obj.alpha;
				case 'randomBW'
					obj.colours=zeros(4,obj.nDots);
					for i = 1:obj.nDots
						obj.colours(:,i)=rand;
					end
					obj.colours(4,:)=obj.alpha;
				case 'randomNBW'
					obj.colours=zeros(4,obj.nDots);
					for i = 1:obj.nDots
						obj.colours(:,i)=randn;
					end
					obj.colours(4,:)=obj.alpha;
				case 'binary'
					obj.colours=zeros(4,obj.nDots);
					rix = round(rand(obj.nDots,1)) > 0;
					obj.colours(:,rix) = 1;
					obj.colours(4,:)=obj.alpha; %set the alpha level
				otherwise
					obj.colours=obj.colour;
					obj.colours(4)=obj.alpha;
			end
			
			obj.updateDots; %runExperiment will call update
			
		end
		
		% ===================================================================
		%> @brief Update an structure for runExperiment
		%>
		%> @param rE runExperiment object for reference
		%> @return stimulus structure.
		% ===================================================================
		function update(obj)
			obj.updateDots;
		end
		
		% ===================================================================
		%> @brief Draw an structure for runExperiment
		%>
		%> @param rE runExperiment object for reference
		%> @return stimulus structure.
		% ===================================================================
		function draw(obj)
			if obj.isVisible == true
				if obj.mask == true
					Screen('BlendFunction', obj.win, obj.msrcMode, obj.mdstMode);
					Screen('DrawDots', obj.win,obj.xy,obj.dotSizeOut,obj.colours,...
						[obj.xPositionOut obj.yPositionOut],obj.dotTypeOut);
					Screen('DrawTexture', obj.win, obj.maskTexture, [], obj.maskRect, [], [], [], [], obj.shader);
					Screen('BlendFunction', obj.win, obj.srcMode, obj.dstMode);
				else
					Screen('DrawDots',obj.win,obj.xy,obj.dotSizeOut,obj.colours,...
						[obj.xPositionOut obj.yPositionOut],obj.dotTypeOut);
				end
			end
		end
		
		% ===================================================================
		%> @brief Animate an structure for runExperiment
		%>
		%> @param rE runExperiment object for reference
		%> @return stimulus structure.
		% ===================================================================
		function animate(obj)
			obj.xy = obj.xy + obj.dxdy; %increment position
			fix = find(obj.xy > obj.sizeOut/2); %cull positive
			obj.xy(fix) = obj.xy(fix) - obj.sizeOut;
			fix = find(obj.xy < -obj.sizeOut/2);  %cull negative
			obj.xy(fix) = obj.xy(fix) + obj.sizeOut;
			%obj.xy(obj.xy > obj.sizeOut/2) = obj.xy(obj.xy > obj.sizeOut/2) - obj.sizeOut; % this is not faster
			%obj.xy(obj.xy < -obj.sizeOut/2) = obj.xy(obj.xy < -obj.sizeOut/2) + obj.sizeOut; % this is not faster
			if obj.killOut > 0 && obj.tick > 1
				kidx = rand(obj.nDots,1) <  obj.killOut;
				ks = length(find(kidx > 0));
				obj.xy(:,kidx) = (obj.sizeOut .* rand(2,ks)) - obj.sizeOut/2;
				%obj.colours(3,kidx) = ones(1,ks); 
			end
			obj.tick = obj.tick + 1;
		end
		
		% ===================================================================
		%> @brief Reset an structure for runExperiment
		%>
		%> @param rE runExperiment object for reference
		%> @return stimulus structure.
		% ===================================================================
		function reset(obj)
			obj.removeTmpProperties;
			obj.angles = [];
			obj.xy = [];
			obj.dxs = [];
			obj.dys = [];
			obj.dxdy = [];
			obj.colours = [];
		end
		
		% ===================================================================
		%> @brief density set method
		%>
		%> We need to update nDots if density is changed but don't want it
		%> dependent yet 
		% ===================================================================
		function set.density(obj,value)
			obj.density = value;
			obj.nDots;
		end
		
		% ===================================================================
		%> @brief Setup an structure for runExperiment
		%>
		%> @param rE runExperiment object for reference
		%> @return
		% ===================================================================
		function value = get.nDots(obj)
			obj.nDots_ = obj.density * obj.size^2;
			value = obj.nDots_;
		end
		
		% ===================================================================
		%> @brief Test method to play with dot generation
		%>
		%> @param rE runExperiment object for reference
		%> @return stimulus structure.
		% ===================================================================
		function runTest(obj)
			try
				antiAlias = 0;
				obj.xCenter=0;
				obj.yCenter=0;
				obj.backgroundColour = [0.5 0.5 0.5];
				obj.dSize = obj.dotSize * obj.ppd;
				Screen('Preference', 'SkipSyncTests', 2);
				Screen('Preference', 'VisualDebugLevel', 0);
				PsychImaging('PrepareConfiguration');
				PsychImaging('AddTask', 'General', 'FloatingPoint32BitIfPossible');
				PsychImaging('AddTask', 'General', 'UseFastOffscreenWindows');
				PsychImaging('AddTask', 'General', 'NormalizedHighresColorRange');
				[obj.win, rect]=PsychImaging('OpenWindow', 0, obj.backgroundColour, [1 1 801 601], [], 2,[],antiAlias);
				[center(1), center(2)] = RectCenter(rect);
				obj.setup();
				obj.fps=Screen('FrameRate',obj.win);      % frames per second
				obj.ifi=Screen('GetFlipInterval', obj.win);
				if obj.fps==0
					obj.fps=1/obj.ifi;
				end;
				%build the mask
				if obj.mask == true
					wrect = SetRect(0, 0, obj.fieldSize, obj.fieldSize);
					mrect = SetRect(0, 0, obj.sizeOut, obj.sizeOut);
					mrect = CenterRect(mrect,wrect);
					bg = [obj.backgroundColour(1:3) 1];
					obj.maskTexture = Screen('OpenOffscreenwindow', obj.win, bg, wrect);
					Screen('FillOval', obj.maskTexture, obj.maskColour, mrect);
					obj.maskRect = CenterRectOnPointd(wrect,center(1),center(2));
					if obj.maskSmoothing > 0 && exist('fspecial','file')
						obj.kernel = fspecial('disk',obj.maskSmoothing);
						obj.shader = EXPCreateStatic2DConvolutionShader(obj.kernel, 4, 4, 1, 2);
					else
						obj.kernel = [];
						obj.shader = 0;
					end
				end
				vbl=Screen('Flip', obj.win);
				while 1
					if obj.mask==true
						Screen('BlendFunction', obj.win, obj.msrcMode, obj.mdstMode);
						Screen('DrawDots', obj.win, obj.xy, obj.dSize, obj.colours, center, obj.dotType);
						Screen('DrawTexture', obj.win, obj.maskTexture, [], obj.maskRect, [], [], [], [], obj.shader);
						Screen('BlendFunction', obj.win, obj.srcMode, obj.dstMode);
					else
						Screen('DrawDots', obj.win, obj.xy, obj.dSize, obj.colours, center, obj.dotType);
					end
					Screen('gluDisk',obj.win,[1 0 1],center(1),center(2),2);
					Screen('DrawingFinished', obj.win); % Tell PTB that no  further drawing commands will follow before Screen('Flip')
					
					[~, ~, buttons]=GetMouse(0);
					if any(buttons) % break out of loop
						break;
					end;
					obj.animate();
					vbl=Screen('Flip', obj.win);
				end
				
				obj.reset;
				Priority(0);
				Screen('CloseAll');
				
			catch ME
				obj.reset;
				Priority(0);
				Screen('CloseAll');
				rethrow(ME)
			end
		end
	end
	%---END PUBLIC METHODS---%
	
	%=======================================================================
	methods ( Access = private ) %-------PRIVATE METHODS-----%
	%=======================================================================
		
		% ===================================================================
		%> @brief Update the dots based on current variable settings
		%>
		% ===================================================================
		function updateDots(obj)
			%sort out our angles and percent incoherent
			obj.angles = ones(obj.nDots,1) .* obj.angleOut;
			obj.rDots=obj.nDots-floor(obj.nDots*(obj.coherenceOut));
			if obj.rDots>0
				obj.angles(1:obj.rDots) = obj.r2d((2*pi).*rand(1,obj.rDots));
				%obj.angles=flipud(obj.angles);
				obj.angles = Shuffle(obj.angles); %if we don't shuffle them, all coherent dots show on top!
			end
			%calculate positions and vector offsets
			obj.xy = obj.sizeOut .* rand(2,obj.nDots);
			obj.xy = obj.xy - obj.sizeOut/2; %so we are centered for -xy to +xy
			[obj.dxs, obj.dys] = obj.updatePosition(repmat(obj.delta,size(obj.angles)),obj.angles);
			obj.dxdy=[obj.dxs';obj.dys'];
			if obj.mask == true
				obj.maskRect = CenterRectOnPointd(obj.maskRect,obj.xPositionOut,obj.yPositionOut);
			end
			obj.tick = 1;
		end
		
		% ===================================================================
		%> @brief sizeOut Set method
		%>
		% ===================================================================
		function set_sizeOut(obj,value)
			obj.sizeOut = value * obj.ppd;
			if obj.mask == 1
				obj.fieldSize = obj.sizeOut * obj.fieldScale; %for masking!
			else
				obj.fieldSize = obj.sizeOut;
			end
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
		end
		
		% ===================================================================
		%> @brief xPositionOut Set method
		%>
		% ===================================================================
		function set_xPositionOut(obj,value)
			obj.xPositionOut = obj.xCenter + (value * obj.ppd);
		end
		
		% ===================================================================
		%> @brief yPositionOut Set method
		%>
		% ===================================================================
		function set_yPositionOut(obj,value)
			obj.yPositionOut = obj.yCenter + (value * obj.ppd);
		end
	end
end
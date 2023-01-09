% ========================================================================
%> @brief ndotsStimulus limited lifetime coherence dots stimulus
%>
%>
%>
%> Copyright ©2014-2022 Ian Max Andolina — released: LGPL3, see LICENCE.md
% ========================================================================
classdef ndotsStimulus < baseStimulus
	properties
		%> dot type, only simple supported at present
		type = 'simple'
		%> the size of dots in the kinetogram (pixels)
		dotSize = 4
		%> type of dot (integer, where 0 means filled square, 1
		%> means filled circle, and 2 means filled circle with high-quality
		%> anti-aliasing)
		dotType = 2
		%> percentage of dots that carry the intended motion signal
		coherence = 0.5
		%> density of dots in the kinetogram (dots per degree-visual-angle^2
		%> per second)
		density = 200
		%> when angle is an array, the relative frequency of each
		%> angle (the pdf).  If directionWeights is incomplete, defaults
		%> to equal weights.
		directionWeights = 1
		%> width of angular error to add to each dot's motion (degrees)
		drunkenWalk = 0
		%> number disjoint sets of dots to interleave frame-by-frame
		interleaving = 1
		%> how to move coherent dots: as one rigid unit (true), or each dot
		%> independently (false)
		isMovingAsHerd = true
		%> how to move non-coherent dots: by replotting from scratch (true),
		%> or by local increments (false)
		isFlickering = false
		%> how to move dots near the edges: by wrapping to the other side
		%> (true), or by replotting from scratch (false)
		isWrapping = true
		%> how to pick coherent dots: favoring recently non-coherent dots
		%> (true), or indiscriminately (false)
		isLimitedLifetime = true
		%> show mask or not?
		mask = false
		%> mask GL modes
		msrcMode = 'GL_SRC_ALPHA'
		mdstMode = 'GL_ONE_MINUS_SRC_ALPHA'
	end
	
	properties (SetAccess = private, GetAccess = public, Hidden = true)
		%> allows makePanel method to offer a UI menu of settings
		typeList = {'simple'}
		%> allows makePanel method to offer a UI menu of settings
		msrcModeList = {'GL_ZERO','GL_ONE','GL_DST_COLOR','GL_ONE_MINUS_DST_COLOR',...
			'GL_SRC_ALPHA','GL_ONE_MINUS_SRC_ALPHA'}
		%> allows makePanel method to offer a UI menu of settings
		mdstModeList = {'GL_ZERO','GL_ONE','GL_DST_COLOR','GL_ONE_MINUS_DST_COLOR',...
			'GL_SRC_ALPHA','GL_ONE_MINUS_SRC_ALPHA'}
	end
	
	properties (SetAccess = protected, GetAccess = public)
		%> number of dots in the kinetogram, includes all interleaving
		%> frames.
		nDots
		%> family of stimulus
		family = 'ndots'
		%> 2xn matrix of dot x and y coordinates, (normalized units, from
		%> top-left of kinetogram)
		normalizedXY
		%> scale factor from kinetogram normalized units to pixels
		pixelScale
		%> 2xn matrix of dot x and y coordinates, (pixels, from top-left of
		%> kinetogram)
		pixelXY
		%> center of the kinetogram (pixels, from the top-left of the
		%> window)
		pixelOrigin
		%> lookup table to pick random dot direction by directionWeights
		directionCDFInverse
		%> resolution of directionCDFInverse
		directionCDFSize = 1e3
		%> counter to keep track of interleaving frames
		frameNumber = 0
		%> logical array to select dots for a frame
		frameSelector
		%> count of how many consecutive frames each dot has moved
		%> coherently
		dotLifetimes
		%> radial step size for dots moving by local increments (normalized
		%> units)
		deltaR
	end
	
	properties (SetAccess = private, GetAccess = private)
		winRect
		%> fraction of diameter that determines the width of the field of
		%> moving dots.  When fieldScale > 1, some dots will be hidden
		%> behind the aperture.
		fieldScale = 1.1
		%> Psychtoolbox Screen texture index for the dot field aperture mask
		maskTexture
		%> [x,y,x2,y2] rect, where to draw the dot field aperture mask,
		%> (pixels, from the top-left of the window)
		maskDestinationRect
		%> [x,y,x2,y2] rect, spanning the entire dot field aperture mask,
		%> (pixels, from the top-left of the window)
		maskSourceRect
		maskColour
		maskRect
		maskSmoothing = 0
		%> was mask blank when initialised?
		wasMaskColourBlank = false
		fieldSize
		kernel = []
		shader = 0
		allowedProperties = {'msrcMode', 'mdstMode', 'directionWeights', ...
			'mask', 'isMovingAsHerd', 'isWrapping', 'isLimitedLifetime', ...
			'dotType', 'speed', 'density', 'dotSize', 'angle', 'coherence', ...
			'density', 'interleaving', 'drunkenWalk'}
		ignoreProperties = {'msrcMode', 'mdstMode', 'pixelXY', 'pixelOrigin', ...
			'deltaR', 'frameNumber', 'frameSelector', 'dotLifetimes', 'nDots', ...
			'normalizedXY', 'pixelScale', 'maskTexture', 'maskDestinationRect', 'maskSourceRect'}
	end 
	
	methods
		% ===================================================================
		%> @brief Class constructor
		%>
		%> More detailed description of what the constructor does.
		%>
		%> @param args are passed as a structure of properties which is
		%> parsed.
		%> @return instance of class.
		% ===================================================================
		function me = ndotsStimulus(varargin)
			args = optickaCore.addDefaults(varargin,...
				struct('name','n-dots','colour',[1 1 1 1],'speed',2));
			me=me@baseStimulus(args); %we call the superclass constructor first
			me.parseArgs(args, me.allowedProperties);
			
			me.ignoreProperties = [me.ignorePropertiesBase me.ignoreProperties];
			me.salutation('constructor','nDots Stimulus initialisation complete');
		end
		
		% ===================================================================
		%> @brief Setup an structure for runExperiment
		%>
		%> @param rE runExperiment object for reference
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
				if ~matches(fn{j}, me.ignoreProperties) %create a temporary dynamic property
					p=me.addprop([fn{j} 'Out']);
					if strcmp(fn{j},'size');p.SetMethod = @set_sizeOut;end
					if strcmp(fn{j},'dotSize');p.SetMethod = @set_dotSizeOut;end
					if strcmp(fn{j},'xPosition');p.SetMethod = @set_xPositionOut;end
					if strcmp(fn{j},'yPosition');p.SetMethod = @set_yPositionOut;end
					me.([fn{j} 'Out']) = me.(fn{j}); %copy our property value to our tempory copy
				end
			end
			
			addRuntimeProperties(me);
			
			computePosition(me); %do it now so we can give mask a position
			
			%build the mask
			if me.mask == true
				if isempty(me.maskColour)
					me.wasMaskColourBlank = true;
					me.maskColour = me.sM.backgroundColour;
					me.maskColour(4) = 0; %set alpha to 0
				else
					me.wasMaskColourBlank = false;
				end
				wrect = SetRect(0, 0, me.fieldSize+me.dotSizeOut, me.fieldSize+me.dotSizeOut);
				mrect = SetRect(0, 0, me.sizeOut, me.sizeOut);
				mrect = CenterRect(mrect,wrect);
				bg = [me.sM.backgroundColour(1:3) 1];
				me.maskTexture = Screen('OpenOffscreenwindow', me.sM.win, bg, wrect);
				Screen('FillOval', me.maskTexture, me.maskColour, mrect);
				me.maskRect = CenterRectOnPointd(wrect,me.xFinal,me.yFinal);
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
						ktmp = load([p filesep 'gaussian52kernel.mat']); %'gaussian73kernel.mat''disk5kernel.mat'
						me.kernel = ktmp.kernel;
						me.shader = EXPCreateStatic2DConvolutionShader(me.kernel, 4, 4, 0, 2);
						me.salutation('No fspecial, had to use precompiled kernel');
					end
				else
					me.kernel = [];
					me.shader = 0;
				end
			end
			
			me.inSetup = false; me.isSetup = true;
			initialiseDots(me);
			computeNextFrame(me);

			function set_xPositionOut(me, value)
				me.xPositionOut = value * me.ppd;
			end
			function set_yPositionOut(me,value)
				me.yPositionOut = value*me.ppd;
			end
			function set_sizeOut(me,value)
				me.sizeOut = value * me.ppd;
				if me.mask == 1
					me.fieldSize = me.sizeOut * me.fieldScale; %for masking!
				else
					me.fieldSize = me.sizeOut;
				end
			end
			function set_dotSizeOut(me,value)
				me.dotSizeOut = value * me.ppd;
			end
			
		end
		
		% ===================================================================
		%> @brief Update an structure for runExperiment
		%>
		% ===================================================================
		function update(me)
			computePosition(me);
			initialiseDots(me);
			computeNextFrame(me);
			resetTicks(me);
		end
		
		% ===================================================================
		%> @brief Draw an structure for runExperiment
		%>
		% ===================================================================
		function draw(me)
			if me.isVisible && me.tick >= me.delayTicks
				if me.mask == true
					Screen('BlendFunction', me.sM.win, me.msrcMode, me.mdstMode);
					Screen('DrawDots', ...
						me.sM.win, ...
						me.pixelXY(:,me.frameSelector), ...
						me.dotSize, ...
						me.colour, ...
						me.pixelOrigin, ...
						me.dotType);
					Screen('DrawTexture', me.sM.win, me.maskTexture, [], me.maskRect);
					Screen('BlendFunction', me.sM.win, me.sM.srcMode, me.sM.dstMode);
				else
					Screen('DrawDots', ...
						me.sM.win, ...
						me.pixelXY(:,me.frameSelector), ...
						me.dotSize, ...
						me.colour, ...
						me.pixelOrigin, ...
						me.dotType);
				end
				me.tick = me.tick + 1;
			end
		end
		
		% ===================================================================
		%> @brief Animate an structure for runExperiment
		%>
		% ===================================================================
		function animate(me)
			if me.isVisible == true && me.tick > me.delayTicks
				computeNextFrame(me);
			end
		end
		
		% ===================================================================
		%> @brief Reset an structure for runExperiment
		%>
		% ===================================================================
		function reset(me)
			me.removeTmpProperties;
			if me.wasMaskColourBlank;	me.maskColour = []; end
			resetTicks(me);
		end
		
	end%---END PUBLIC METHODS---%
	
	%=======================================================================
	methods ( Access = protected ) %-------PRIVATE METHODS-----%
	%=======================================================================
		
		% ===================================================================
		%> @brief initialise dot positions
		%>
		% ===================================================================
		%-------------------Set up our dot matrices----------------------%
		function initialiseDots(me)
			fr=round(1/me.sM.screenVals.ifi);
			% size the dot field and the aperture circle
			fieldWidth = me.size*me.fieldScale;
			marginWidth = (me.fieldScale - 1) * me.size / 2;
			fieldPixels = ceil(fieldWidth * me.ppd);
			maskPixels = fieldPixels + me.dotSize;
			marginPixels = ceil(marginWidth * me.ppd);
			
			% count dots
			me.nDots = ceil(me.density * fieldWidth^2 / fr);
			me.frameSelector = false(1, me.nDots);
			me.dotLifetimes = zeros(1, me.nDots);
			
			% account for speed as step per interleaved frame
			me.deltaR = me.speed / me.size ...
				* (me.interleaving / fr);
			
			% account for pixel real estate
			me.pixelScale = fieldPixels;
			me.pixelOrigin(1) = me.sM.xCenter + me.xPositionOut - fieldPixels/2;
			me.pixelOrigin(2) = me.sM.yCenter	- me.yPositionOut - fieldPixels/2;
			
			% 			me.maskSourceRect = [0 0, maskPixels, maskPixels];
			% 			me.maskDestinationRect = me.maskSourceRect ...
			% 				+ me.pixelOrigin([1 2 1 2]) - me.dotSize/2;
			
			% build a lookup table to pick weighted directions from a
			% uniform random variable.
			if ~isequal(size(me.directionWeights), size(me.angle))
				me.directionWeights = ones(1, length(me.angle));
			end
			
			directionCDF = cumsum(me.directionWeights) ...
				/ sum(me.directionWeights);
			me.directionCDFInverse = ones(1, me.directionCDFSize);
			probs = linspace(0, 1, me.directionCDFSize);
			for ii = 1:me.directionCDFSize
				nearest = find(directionCDF >= probs(ii), 1, 'first');
				me.directionCDFInverse(ii) = me.angle(nearest);
			end
			
			% pick random start positions for all dots
			me.normalizedXY = rand(2, me.nDots);
			
			if me.mask == true
				me.maskRect = CenterRectOnPointd(me.maskRect,me.xFinal,me.yFinal);
			end
		end
		
		% ===================================================================
		%> @brief Compute dot positions for the next frame of animation.
		%>
		% ===================================================================
		function computeNextFrame(me)
			% cache some properties as local variables because it's faster
			nFrames = me.interleaving;
			frame = me.frameNumber;
			frame = 1 + mod(frame, nFrames);
			me.frameNumber = frame;
			
			thisFrame = me.frameSelector;
			thisFrame(thisFrame) = false;
			thisFrame(frame:nFrames:end) = true;
			me.frameSelector = thisFrame;
			nFrameDots = sum(thisFrame);
			
			% pick coherent dots
			cohSelector = false(size(thisFrame));
			cohCoinToss = rand(1, nFrameDots) < me.coherence;
			nCoherentDots = sum(cohCoinToss);
			nNonCoherentDots = nFrameDots - nCoherentDots;
			lifetimes = me.dotLifetimes;
			if me.isLimitedLifetime
				% would prefer not to call sort
				%   should be able to do accounting as we go
				[frameSorted, frameOrder] = ...
					sort(lifetimes(thisFrame));
				isInFrameAndShortLifetime = false(1, nFrameDots);
				isInFrameAndShortLifetime(frameOrder(1:nCoherentDots)) = true;
				cohSelector(thisFrame) = isInFrameAndShortLifetime;
				
			else
				cohSelector(thisFrame) = cohCoinToss;
			end
			lifetimes(cohSelector) = ...
				lifetimes(cohSelector) + 1;
			
			% account for non-coherent dots
			nonCohSelector = false(size(thisFrame));
			nonCohSelector(thisFrame) = true;
			nonCohSelector(cohSelector) = false;
			lifetimes(nonCohSelector) = 0;
			me.dotLifetimes = lifetimes;
			
			% pick motion direction(s) for coherent dots
			if me.isMovingAsHerd
				nDirections = 1;
			else
				nDirections = nCoherentDots;
			end
			
			if numel(me.angle) == 1
				% use the one constant direction
				degrees = me.angle(1) * ones(1, nDirections);
				
			else
				% pick from the direction distribution
				CDFIndexes = 1 + ...
					floor(rand(1, nDirections)*(me.directionCDFSize));
				degrees = me.directionCDFInverse(CDFIndexes);
			end
			
			if me.drunkenWalk > 0
				% jitter the direction from a uniform distribution
				degrees = degrees + ...
					me.drunkenWalk * (rand(1, nDirections) - .5);
			end
			
			% move the coherent dots
			XY = me.normalizedXY;
			R = me.deltaR;
			radians = pi*degrees/180;
			deltaX = R*cos(radians);
			deltaY = R*sin(radians);
			XY(1,cohSelector) = XY(1,cohSelector) + deltaX;
			XY(2,cohSelector) = XY(2,cohSelector) - deltaY;
			
			% move the non-coherent dots
			if me.isFlickering
				XY(:,nonCohSelector) = rand(2, nNonCoherentDots);
				
			else
				radians = 2*pi*rand(1, nNonCoherentDots);
				deltaX = R*cos(radians);
				deltaY = R*sin(radians);
				XY(1,nonCohSelector) = XY(1,nonCohSelector) + deltaX;
				XY(2,nonCohSelector) = XY(2,nonCohSelector) - deltaY;
			end
			
			% keep dots from moving out of the field
			tooBig = XY > 1;
			tooSmall = XY < 0;
			componentOverrun = tooBig | tooSmall;
			if me.isWrapping
				% wrap the overrun component
				%   carry the overrun to prevent striping
				XY(tooBig) = XY(tooBig) - 1;
				XY(tooSmall) = XY(tooSmall) + 1;
				
				% randomize the other component
				wrapRands = rand(1, sum(componentOverrun(1:end)));
				XY(componentOverrun([2,1],:)) = wrapRands;
				
			else
				% randomize both components when either overruns
				overrun = any(componentOverrun, 1);
				XY([1,2],overrun) = rand(2, sum(overrun));
			end
			
			me.normalizedXY = XY;
			me.pixelXY = XY*me.pixelScale;
		end
		
	end
	
end


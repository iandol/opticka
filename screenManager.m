% ========================================================================
%> @brief screenManager Manages a Screen object
%> screenManager manages PTB screen settings for opticka. You can set many
%> properties of this class to control PTB screens, and use it to open and
%> close the screen based on those properties. It also manages movie
%> recording of the screen buffer and some basic drawing commands like grids,
%> spots and the hide flash trick from Mario.
% ========================================================================
classdef screenManager < optickaCore
	
	properties
		%> MBP 1440x900 is 33.2x20.6cm so approx 44px/cm, Flexscan is 32px/cm @1280 26px/cm @ 1024
		pixelsPerCm@double = 44
		%> distance of subject from CRT -- rad2ang(2*(atan((0.5*1cm)/57.3cm))) equals 1deg
		distance@double = 57.3
		%> hide the black flash as PTB tests its refresh timing, uses a gamma
		%> trick from Mario
		hideFlash@logical = false
		%> windowed: when FALSE use fullscreen; set to TRUE and it is windowed 800x600pixels or you
		%> can add in a window width and height i.e. [800 600] to specify windowed size. Remember
		%> that windowed presentation should never be used for real experimental
		%> presentation due to poor timing...
		windowed = false
		%> true = change the debug parameters for poorer temporal fidelity but no sync testing etc.
		debug@logical = false
		%> true = shows the info text and position grid during stimulus presentation
		visualDebug = false
		%> normally should be left at 1 (1 is added to this number so doublebuffering is enabled)
		doubleBuffer = 1
		%> bitDepth of framebuffer, '8bit' is best for old GPUs
		bitDepth = 'FloatingPoint32BitIfPossible'
		%> timestamping mode 1=beamposition,kernel fallback | 2=beamposition crossvalidate with kernel
		timestampingMode = 1
		%> multisampling sent to the graphics card, try values []=disabled, 4, 8
		%> and 16 -- useful for textures to minimise aliasing, but this
		%> does provide extra work for the GPU
		antiAlias = []
		%> background RGBA of display during stimulus presentation
		backgroundColour = [0.5 0.5 0.5 0]
		%> shunt screen center by X degrees
		screenXOffset = 0
		%> shunt screen center by Y degrees
		screenYOffset = 0
		%> the monitor to use, 0 is the main display
		screen = []
		%> use OpenGL blending mode
		blend = false
		%> GL_ONE %src mode
		srcMode = 'GL_SRC_ALPHA'
		%> GL_ONE % dst mode
		dstMode = 'GL_ONE_MINUS_SRC_ALPHA'
		%> show a white square in the top-left corner to trigger a
		%> photodiode attached to screen. This is only displayed when the
		%> stimulus is shown, not during the blank and can therefore be used
		%> for timing validation
		photoDiode = false
		%> gamma correction info saved as a calibrateLuminance object
		gammaTable
		%> settings for movie output
		movieSettings = []
		%> useful screen info and initial gamma tables and the like
		screenVals
		%> verbosity
		verbose = false
		%> level of PTB verbosity, set to 10 for full PTB logging
		verbosityLevel = 4
		%> Use retina resolution natively
		useRetina = false
	end
	
	properties (SetAccess = private, GetAccess = public, Dependent = true)
		%> dependent pixels per degree property calculated from distance and pixelsPerCm
		ppd
	end
	
	properties (SetAccess = private, GetAccess = public)
		%> do we have a working PTB, if not go into a silent mode
		isPTB = false
		%> is a PTB currently open?
		isOpen = false
		%> the handle returned by opening a PTB window
		win
		%> the window rectangle
		winRect
		%> computed X center
		xCenter = 0
		%> computed Y center
		yCenter = 0
		%> set automatically on construction
		maxScreen
	end
	
	properties (SetAccess = private, GetAccess = private)
		%> linux font name;
		linuxFontName = '-adobe-helvetica-bold-o-normal--11-80-100-100-p-60-iso8859-1'
		%> properties allowed to be modified during construction
		allowedProperties='gammaTable|useRetina|bitDepth|pixelsPerCm|distance|screen|windowed|backgroundColour|screenXOffset|screenYOffset|blend|srcMode|dstMode|antiAlias|debug|photoDiode|verbose|hideFlash'
		%> the photoDiode rectangle in pixel values
		photoDiodeRect = [0;0;50;50]
		%> the values computed to draw the 1deg dotted grid in visualDebug mode
		grid
		%> the movie pointer
		moviePtr = []
		%> movie mat structure
		movieMat = []
		%screen flash logic
		flashInterval = 20
		flashTick = 0
		flashOn = 1
		% timed spot logic
		timedSpotTime = 0
		timedSpotTick = 0
		timedSpotNextTick = 0
		ppd_
	end
	
	methods
		% ===================================================================
		%> @brief Class constructor
		%>
		%> screenManager constructor
		%>
		%> @param varargin can be simple name value pairs, a structure or cell array
		%> @return instance of the class.
		% ===================================================================
		function obj = screenManager(varargin)
			if nargin == 0; varargin.name = ''; end
			obj=obj@optickaCore(varargin); %superclass constructor
			if nargin>0
				obj.parseArgs(varargin,obj.allowedProperties);
			end
			try
				AssertOpenGL
				obj.isPTB = true;
				if strcmpi(computer,'MACI64')
					obj.salutation('64bit OS X PTB currently supported!')
				else
					obj.salutation('PTB currently supported!')
				end
			catch %#ok<*CTCH>
				obj.isPTB = false;
				obj.salutation('OpenGL support needed by PTB!')
			end
			obj.prepareScreen;
		end
		
		% ===================================================================
		%> @brief prepare the Screen values on the local machine
		%>
		%> @param obj object
		%> @return screenVals structure of screen values
		% ===================================================================
		function screenVals = prepareScreen(obj)
			if obj.isPTB == false
				obj.maxScreen = 0;
				obj.screen = 0;
				obj.screenVals.resetGamma = false;
				obj.screenVals.fps = 60;
				obj.screenVals.ifi = 1/60;
				obj.screenVals.width = 0;
				obj.screenVals.height = 0;
				obj.makeGrid;
				screenVals = obj.screenVals;				
				return
			end
			obj.maxScreen=max(Screen('Screens'));
			
			%by default choose the (largest number) screen
			if isempty(obj.screen) || obj.screen > obj.maxScreen
				obj.screen = obj.maxScreen;
			end
			
			% initialise our movie settings
			obj.movieSettings.loop = Inf;
			obj.movieSettings.record = 0;
			obj.movieSettings.size = [400 400];
			obj.movieSettings.quality = 0;
			obj.movieSettings.nFrames = 100;
			obj.movieSettings.type = 1;
			obj.movieSettings.codec = 'rle '; %space is important for 'rle '
			
			%get the gammatable and dac information
			[obj.screenVals.gammaTable,obj.screenVals.dacBits,obj.screenVals.lutSize]=Screen('ReadNormalizedGammaTable', obj.screen);
			obj.screenVals.originalGammaTable = obj.screenVals.gammaTable;
			
			%get screen dimensions
			setScreenSize(obj);
			
			obj.screenVals.resetGamma = false;
			
			%this is just a rough initial setting, it will be recalculated when we
			%open the screen before showing stimuli.
			obj.screenVals.fps=Screen('FrameRate',obj.screen);
			if obj.screenVals.fps == 0
				obj.screenVals.fps = 60;
			end
			obj.screenVals.ifi=1/obj.screenVals.fps;
			
			%Screen('Preference', 'TextRenderer', 0); %fast text renderer
			
			if obj.debug == true %we yoke these together but they can then be overridden
				obj.visualDebug = true;
			end
			
			obj.ppd; %generate our dependent propertie and caches it to ppd_ for speed
			obj.makeGrid; %our visualDebug size grid
			
			obj.screenVals.white = WhiteIndex(obj.screen);
			obj.screenVals.black = BlackIndex(obj.screen);
			obj.screenVals.gray = GrayIndex(obj.screen);
			
			screenVals = obj.screenVals;
			
		end
		
		% ===================================================================
		%> @brief open a screen with object defined settings
		%>
		%> @param debug, whether we show debug status, called from runExperiment
		%> @param tL timeLog object to add timing info on screen construction
		%> @return screenVals structure of basic info from the opened screen
		% ===================================================================
		function screenVals = open(obj,debug,tL)
			if obj.isPTB == false
				screenVals = obj.screenVals;
				return;
			end
			if ~exist('debug','var')
				debug = obj.debug;
			end
			if ~islogical(obj.windowed) && isnumeric(obj.windowed) %force debug for windowed stimuli!
				debug = true;
			end
			if ~exist('tL','var')
				tL = struct;
			end
			try
				obj.screenVals.resetGamma = false;
				
				obj.hideScreenFlash();
				
				%1=beamposition,kernel fallback | 2=beamposition crossvalidate with kernel
				Screen('Preference', 'VBLTimestampingMode', obj.timestampingMode);
				
				if debug == true || (length(obj.windowed)==1 && obj.windowed ~= 0)
					fprintf('\n---> screenManager: Skipping Sync Tests etc.\n');
					Screen('Preference', 'SkipSyncTests', 2);
					Screen('Preference', 'VisualDebugLevel', 0);
					Screen('Preference', 'Verbosity', 2);
					Screen('Preference', 'SuppressAllWarnings', 0);
				else
					fprintf('\n---> screenManager: Sync Tests enabled.\n');
					Screen('Preference', 'SkipSyncTests', 0);
					Screen('Preference', 'VisualDebugLevel', 3);
					Screen('Preference', 'Verbosity', obj.verbosityLevel); %errors and warnings
					Screen('Preference', 'SuppressAllWarnings', 0);
				end
				
				tL.screenLog.preOpenWindow=GetSecs;
				
				PsychImaging('PrepareConfiguration');
				PsychImaging('AddTask', 'General', 'UseFastOffscreenWindows');
				PsychImaging('AddTask', 'General', 'NormalizedHighresColorRange'); %we always want 0-1 colour range!
				if obj.useRetina == true
					PsychImaging('AddTask', 'General', 'UseRetinaResolution');
				end
				if ischar(obj.bitDepth) && ~strcmpi(obj.bitDepth,'8bit')
					PsychImaging('AddTask', 'General', obj.bitDepth);
				end
				
				if isempty(obj.windowed); obj.windowed = false; end
				if obj.windowed == false %fullscreen
					winSize = [];
				else %windowed
					if length(obj.windowed) == 2
						winSize = [0 0 obj.windowed(1) obj.windowed(2)];
					elseif length(obj.windowed) == 4
						winSize = obj.windowed;
					else
						winSize=[0 0 800 600];
					end
				end
				[obj.win] = PsychImaging('OpenWindow', obj.screen, obj.backgroundColour, winSize, [], obj.doubleBuffer+1,[],obj.antiAlias);
				
				tL.screenLog.postOpenWindow=GetSecs;
				tL.screenLog.deltaOpenWindow=(tL.screenLog.postOpenWindow-tL.screenLog.preOpenWindow)*1000;
				
				try
					AssertGLSL;
				catch
					obj.close();
					error('GLSL Shading support is required for Opticka!');
				end
				
				obj.screenVals.win = obj.win; %make a copy
				
				Priority(MaxPriority(obj.win)); %bump our priority to maximum allowed
				%find our fps if not defined before
				obj.screenVals.ifi = Screen('GetFlipInterval', obj.win);
				if obj.screenVals.fps==0
					obj.screenVals.fps=round(1/obj.screenVals.ifi);
				end
				if obj.windowed == false %fullscreen
					obj.screenVals.halfisi=obj.screenVals.ifi/2;
				else
					% windowed presentation doesn't handle the preferred method
					% of specifying lastvbl+halfisi properly so we set halfisi to 0 which
					% effectively makes flip occur ASAP.
					obj.screenVals.halfisi = 0;
				end
				
				%get screen dimensions -- check !!!!!
				setScreenSize(obj);
				
				if obj.hideFlash == true && isempty(obj.gammaTable)
					Screen('LoadNormalizedGammaTable', obj.screen, obj.screenVals.gammaTable);
					obj.screenVals.resetGamma = false;
				elseif isa(obj.gammaTable,'calibrateLuminance') && (obj.gammaTable.choice > 0)
					choice = obj.gammaTable.choice;
					obj.screenVals.resetGamma = true;
					gTmp = repmat(obj.gammaTable.gammaTable{choice},1,3);
					Screen('LoadNormalizedGammaTable', obj.screen, gTmp);
					fprintf('\n---> screenManager: SET GAMMA CORRECTION using: %s\n', obj.gammaTable.modelFit{choice}.method);
				else
					Screen('LoadNormalizedGammaTable', obj.screen, obj.screenVals.gammaTable);
					%obj.screenVals.oldCLUT = LoadIdentityClut(obj.win);
					obj.screenVals.resetGamma = false;
				end
				
				Priority(0); %be lazy for a while and let other things get done
				
				% Enable alpha blending.
				if obj.blend==1
					Screen('BlendFunction', obj.win, obj.srcMode, obj.dstMode);
					fprintf('\n---> screenManager: Initial OpenGL blending set to %s | %s\n', obj.srcMode, obj.dstMode);
				end
				
				if ismac == 0 && isunix == 1
					Screen('TextFont', obj.win, obj.linuxFontName);
				end
				
				obj.screenVals.white = WhiteIndex(obj.screen);
				obj.screenVals.black = BlackIndex(obj.screen);
				obj.screenVals.gray = GrayIndex(obj.screen);
				
				obj.isOpen = true;
				screenVals = obj.screenVals;
				
			catch ME
				obj.close();
				screenVals = obj.prepareScreen();
				rethrow(ME)
			end
			
		end
		
		% ===================================================================
		%> @brief Flip the screen
		%>
		%> @param
		%> @return
		% ===================================================================
		function vbl = flip(obj)
			vbl = Screen('Flip',obj.win);
		end
		
		% ===================================================================
		%> @brief Flip the screen
		%>
		%> @param
		%> @return
		% ===================================================================
		function forceWin(obj,win)
			obj.win = win;
			obj.isOpen = true;
			obj.isPTB = true;
			obj.screenVals.ifi = Screen('GetFlipInterval', obj.win);
			obj.screenVals.white = WhiteIndex(obj.win);
			obj.screenVals.black = BlackIndex(obj.win);
			obj.screenVals.gray = GrayIndex(obj.win);
			setScreenSize(obj);
			fprintf('---> screenManager slaved to external win: %i\n',win);
		end
		
		% ===================================================================
		%> @brief This is the trick Mario told us to "hide" the colour changes as PTB starts -- we could use backgroundcolour here to be even better
		%>
		%> @param
		%> @return
		% ===================================================================
		function hideScreenFlash(obj)
			% This is the trick Mario told us to "hide" the colour changes as PTB
			% intialises -- we could use backgroundcolour here to be even better
			if obj.hideFlash == true && all(obj.windowed == false)
				if isa(obj.gammaTable,'calibrateLuminance') && (obj.gammaTable.choice > 0)
					obj.screenVals.oldGamma = Screen('LoadNormalizedGammaTable', obj.screen, repmat(obj.gammaTable.gammaTable{obj.gammaTable.choice}(128,:), 256, 3));
					obj.screenVals.resetGamma = true;
				else
					table = repmat(obj.backgroundColour(:,1:3), 256, 1);
					obj.screenVals.oldGamma = Screen('LoadNormalizedGammaTable', obj.screen, table);
					obj.screenVals.resetGamma = true;
				end
			end
		end
		
		% ===================================================================
		%> @brief close the screen when finished or on error
		%>
		%> @param
		%> @return
		% ===================================================================
		function close(obj)
			if obj.isPTB == true
				if isfield(obj.screenVals,'originalGammaTable') && ~isempty(obj.screenVals.originalGammaTable)
					Screen('LoadNormalizedGammaTable', obj.screen, obj.screenVals.originalGammaTable);
					fprintf('\n---> screenManager: RESET GAMMA TABLES\n');
				end
				Screen('Close');
				Screen('CloseAll');
				obj.win=[];
				obj.isOpen = false;
				Priority(0);
				ListenChar(0);
				ShowCursor;
				sca;
			end
		end
		

		% ===================================================================
		%> @brief reset the gamma table
		%>
		%> @param
		%> @return
		% ===================================================================
		function resetScreenGamma(obj)
			if obj.hideFlash == true || obj.windowed(1) ~= 1 || (~isempty(obj.screenVals) && obj.screenVals.resetGamma == true && ~isempty(obj.screenVals.originalGammaTable))
				fprintf('\n---> screenManager: RESET GAMMA TABLES\n');
				Screen('LoadNormalizedGammaTable', obj.screen, obj.screenVals.originalGammaTable);
			end
		end
		
		% ===================================================================
		%> @brief Set method for distance
		%>
		%> @param
		% ===================================================================
		function set.distance(obj,value)
			if ~(value > 0)
				value = 57.3;
			end
			obj.distance = value;
			obj.ppd; %recalculate ppd and cache it
			obj.makeGrid();
		end
		
		% ===================================================================
		%> @brief Set method for pixelsPerCm
		%>
		%> @param
		% ===================================================================
		function set.pixelsPerCm(obj,value)
			if ~(value > 0)
				value = 44;
			end
			obj.pixelsPerCm = value;
			obj.ppd; %recalculate ppd and cache it
			obj.makeGrid();
			%obj.salutation(['set pixelsPerCm: ' num2str(obj.pixelsPerCm) '|ppd: ' num2str(obj.ppd)],'Custom set method')
		end		
		
		% ===================================================================
		%> @brief Get method for ppd (a dependent property)
		%>
		%> @param
		% ===================================================================
		function ppd = get.ppd(obj)
			if obj.useRetina %note pixelsPerCm is normally recorded using non-retina mode so we fix that here if we are now in retina mode
				ppd = round( (obj.pixelsPerCm*2) * (obj.distance / 57.3) ); %set the pixels per degree
			else
				ppd = round( obj.pixelsPerCm * (obj.distance / 57.3) ); %set the pixels per degree
			end
			obj.ppd_ = ppd; %cache value for speed!!!
		end
		
		% ===================================================================
		%> @brief Set method for windowed
		%>
		%> @param
		% ===================================================================
		function set.windowed(obj,value)
			if length(value) == 2 && isnumeric(value)
				obj.windowed = [0 0 value];
			elseif length(value) == 4 && isnumeric(value)
				obj.windowed = value;
			elseif islogical(value)
				obj.windowed = value;
			elseif value == 1
				obj.windowed = true;
			elseif value == 0
				obj.windowed = false;
			else
				obj.windowed = false;
			end	
		end
		
		% ===================================================================
		%> @brief Set method for pixelsPerCm
		%>
		%> @param
		% ===================================================================
		function set.screenXOffset(obj,value)
			obj.screenXOffset = value;
			obj.updateCenter();
		end
		
		% ===================================================================
		%> @brief Set method for pixelsPerCm
		%>
		%> @param
		% ===================================================================
		function set.screenYOffset(obj,value)
			obj.screenYOffset = value;
			obj.updateCenter();
		end
		
		% ===================================================================
		%> @brief Screen('DrawingFinished')
		%>
		%> @param
		% ===================================================================
		function finishDrawing(obj)
			Screen('DrawingFinished', obj.win); 
		end
		
		% ===================================================================
		%> @brief Flash the screen until keypress
		%>
		%> @param
		% ===================================================================
		function flashScreen(obj,interval)			
			if obj.isOpen			
				int = round(interval / obj.screenVals.ifi);
				KbReleaseWait;
				while ~KbCheck(-1)
					if mod(obj.flashTick,int) == 0
						obj.flashOn = not(obj.flashOn);
						obj.flashTick = 0;
					end
					if obj.flashOn == 0
						Screen('FillRect',obj.win,[0 0 0 1]);
					else
						Screen('FillRect',obj.win,[1 1 1 1]);
					end
					Screen('Flip',obj.win);
					obj.flashTick = obj.flashTick + 1;
				end
				drawBackground(obj);
				Screen('Flip',obj.win);
			end
		end
		
		% ===================================================================
		%> @brief draw small spot centered on the screen
		%>
		%> @param size in degrees
		%> @param colour of spot
		%> @param x position in degrees relative to screen center
		%> @param y position in degrees relative to screen center
		%> @return
		% ===================================================================
		function drawSpot(obj,size,colour,x,y)
			if nargin < 5 || isempty(y); y = 0; end
			if nargin < 4 || isempty(x); x = 0; end
			if nargin < 3 || isempty(colour); colour = [1 1 1 1]; end
			if nargin < 2 || isempty(size); size = 1; end
			
			x = obj.xCenter + (x * obj.ppd_);
			y = obj.yCenter + (y * obj.ppd_);
			size = size/2 * obj.ppd_;
			
			Screen('gluDisk', obj.win, colour, x, y, size);
		end
		
		% ===================================================================
		%> @brief draw small cross
		%>
		%> @param size size in degrees
		%> @param colour of cross
		%> @param x position in degrees relative to screen center
		%> @param y position in degrees relative to screen center
		%> @param lineWidth of lines
		%> @return
		% ===================================================================
		function drawCross(obj,size,colour,x,y,lineWidth)
			if nargin < 6 || isempty(lineWidth); lineWidth = 2; end
			if nargin < 5 || isempty(y); y = 0; end
			if nargin < 4 || isempty(x); x = 0; end
			if nargin < 3 || isempty(colour)
				if mean(obj.backgroundColour(1:3)) <= 0.5
					colour = [1 1 1 1]; 
				elseif  mean(obj.backgroundColour(1:3)) > 0.5
					colour = [0 0 0 1]; 
				elseif length(colour) < 4
					colour = [0 0 0 1];
				end
			end
			if nargin < 2 || isempty(size); size = 0.5; end
			
			x = obj.xCenter + (x * obj.ppd_);
			y = obj.yCenter + (y * obj.ppd_);
			size = size/2 * obj.ppd_;
			
			Screen('DrawLines', obj.win, [-size size 0 0;0 0 -size size],...
				lineWidth, colour, [x y]);
		end
		
		% ===================================================================
		%> @brief draw timed small spot centered on the screen
		%>
		%> @param
		%> @return
		% ===================================================================
		function drawTimedSpot(obj,size,colour,time,reset)
			if nargin < 5; reset = false; end
			if nargin < 4; time = 0.2; end
			if nargin < 3; colour = [1 1 1 1]; end
			if nargin < 2; size = 1; end
			if reset == true
				if length(time) == 2
					obj.timedSpotTime = randi(time*1000)/1000;
				else
					obj.timedSpotTime = time;
				end
				obj.timedSpotNextTick = round(obj.timedSpotTime / obj.screenVals.ifi);
				obj.timedSpotTick = 1;
				return
			end
			if obj.timedSpotTick <= obj.timedSpotNextTick
				size = size/2 * obj.ppd_;
				Screen('gluDisk',obj.win,colour,obj.xCenter,obj.yCenter,size);
			end
			obj.timedSpotTick = obj.timedSpotTick + 1;
		end
		
		% ===================================================================
		%> @brief draw small spot centered on the screen
		%>
		%> @param
		%> @return
		% ===================================================================
		function drawGreenSpot(obj,size)
			if ~exist('size','var')
				size = 1;
			end
			size = size/2 * obj.ppd_;
			Screen('gluDisk',obj.win,[0 1 0 1],obj.xCenter,obj.yCenter,size);
		end
		
		% ===================================================================
		%> @brief draw small spot centered on the screen
		%>
		%> @param
		%> @return
		% ===================================================================
		function drawRedSpot(obj,size)
			if ~exist('size','var')
				size = 1;
			end
			size = size/2 * obj.ppd_;
			Screen('gluDisk',obj.win,[1 0 0 1],obj.xCenter,obj.yCenter,size);
		end
		
		% ===================================================================
		%> @brief draw small spot centered on the screen
		%>
		%> @param
		%> @return
		% ===================================================================
		function drawScreenCenter(obj)
			Screen('gluDisk',obj.win,[1 0 1 1],obj.xCenter,obj.yCenter,2);
		end
		
		% ===================================================================
		%> @brief draw a 5x5 1deg dot grid for visual debugging
		%>
		%> @param
		%> @return
		% ===================================================================
		function drawGrid(obj)
			Screen('DrawDots',obj.win,obj.grid,1,[1 0 1 1],[obj.xCenter obj.yCenter],1);
		end
		
		% ===================================================================
		%> @brief draw a white square in top-left of screen to trigger photodiode
		%> 
		%> @param colour colour of square
		%> @return
		% ===================================================================
		function drawPhotoDiodeSquare(obj,colour)
			Screen('FillRect',obj.win,colour,obj.photoDiodeRect);
		end
		
		% ===================================================================
		%> @brief Draw the background colour
		%>
		%> @param
		%> @return
		% ===================================================================
		function drawBackground(obj)
			Screen('FillRect',obj.win,obj.backgroundColour,[]);
		end
		
		% ===================================================================
		%> @brief return mouse position in degrees
		%>
		%> @param
		% ===================================================================
		function [xPos, yPos] = mousePosition(obj, verbose)
			if ~exist('verbose','var') || isempty(verbose); verbose = obj.verbose; end
			if obj.isOpen
				[xPos,yPos] = GetMouse(obj.win);
			else
				[xPos,yPos] = GetMouse();
			end
			xPos = (xPos - obj.xCenter) / obj.ppd_;
			yPos = (yPos - obj.yCenter) / obj.ppd_;
			if verbose
				fprintf('--->>> MOUSE POSITION: \tX = %5.5g \t\tY = %5.5g\n',xPos,yPos);
			end
		end
		
				% ===================================================================
		%> @brief prepare the recording of stimulus frames
		%>
		%> @param
		%> @return
		% ===================================================================
		function prepareMovie(obj)
			% Set up the movie settings
			if obj.movieSettings.record == true
				obj.movieSettings.outsize=CenterRect([0 0 obj.movieSettings.size(1) obj.movieSettings.size(2)],obj.winRect);
				disp(num2str(obj.movieSettings.outsize));
				disp('---');
				obj.movieSettings.loop=1;
				if ismac || isunix
					oldp = cd('~');
					homep = pwd;
					cd(oldp);
				else
					homep = 'c:';
				end
				if ~exist([homep filesep 'MatlabFiles' filesep 'Movie' filesep],'dir')
					mkdir([homep filesep 'MatlabFiles' filesep 'Movie' filesep])
					obj.movieSettings.moviepath = [homep filesep 'MatlabFiles' filesep 'Movie' filesep];
				end
				switch obj.movieSettings.type
					case 1
						if ispc || isunix || isempty(obj.movieSettings.codec)
							settings = 'EncodingQuality=1';
						else
							settings = ['EncodingQuality=1; CodecFOURCC=' obj.movieSettings.codec];
						end
						obj.movieSettings.movieFile = [obj.movieSettings.moviepath 'Movie' datestr(clock) '.mov'];
						obj.moviePtr = Screen('CreateMovie', obj.win,...
							obj.movieSettings.movieFile,...
							obj.movieSettings.size(1), obj.movieSettings.size(2), ...
							obj.screenVals.fps, settings);
					case 2
						obj.movieMat = zeros(obj.movieSettings.size(2),obj.movieSettings.size(1),3,obj.movieSettings.nFrames);
				end
			end
		end
		
		% ===================================================================
		%> @brief add current frame to recorded stimulus movie
		%>
		%> @param
		%> @return
		% ===================================================================
		function addMovieFrame(obj)
			if obj.movieSettings.record == true
				if obj.movieSettings.loop <= obj.movieSettings.nFrames
					switch obj.movieSettings.type
						case 1
							Screen('AddFrameToMovie', obj.win, obj.movieSettings.outsize, 'frontBuffer', obj.movieSettings.quality, 3);
						case 2
							obj.movieMat(:,:,:,obj.movieSettings.loop)=Screen('GetImage', obj.win, obj.movieSettings.outsize, 'frontBuffer', obj.movieSettings.quality, 3);
					end
					obj.movieSettings.loop=obj.movieSettings.loop+1;
				end
			end
		end
		
		% ===================================================================
		%> @brief finish stimulus recording
		%>
		%> @param
		%> @return
		% ===================================================================
		function finaliseMovie(obj,wasError)
			if obj.movieSettings.record == 1
				switch obj.movieSettings.type
					case 1
						if ~isempty(obj.moviePtr)
							Screen('FinalizeMovie', obj.moviePtr);
						end
					case 2
						if wasError == true
							
						else
							save([obj.movieSettings.moviepath 'Movie' datestr(clock) '.mat'],'mimg');
						end
				end
				obj.moviePtr = [];
				obj.movieMat = [];
			end
		end
		
		% ===================================================================
		%> @brief play back the recorded stimulus
		%>
		%> @param
		%> @return
		% ===================================================================
		function playMovie(obj)
			if obj.movieSettings.record == 1  && obj.movieSettings.type == 2 && exist('implay','file') && ~isempty(obj.movieSettings.movieFile)
				try %#ok<TRYNC>
					mimg = load(obj.movieSettings.movieFile);
					implay(mimg);
					clear mimg
				end
			end
		end
		
		% ===================================================================
		%> @brief Delete method
		%>
		% ===================================================================
		function delete(obj)
			if obj.isOpen
				obj.close();
				obj.salutation('DELETE method','Screen closed');
			end
		end
		
	end
		
	%=======================================================================
	methods (Access = private) %------------------PRIVATE METHODS
	%=======================================================================
	
		% ===================================================================
		%> @brief Sets screen size, taking retina mode into account
		%>  
		% ===================================================================
		function setScreenSize(obj)
			%get screen dimensions
			if ~isempty(obj.win)
				swin = obj.win;
			else
				swin = obj.screen;
			end
			[obj.screenVals.width, obj.screenVals.height] = Screen('WindowSize',swin);
			obj.winRect = Screen('Rect',swin);
			updateCenter(obj);
		end
		% ===================================================================
		%> @brief Makes a 15x15 1deg dot grid for debug mode
		%> This is always updated on setting distance or pixelsPerCm 
		% ===================================================================
		function makeGrid(obj)
			obj.grid = [];
			rnge = -15:15;
			for i=rnge
				obj.grid = horzcat(obj.grid, [rnge;ones(1,length(rnge))*i]);
			end
			obj.grid = obj.grid .* obj.ppd_;
		end
		
		% ===================================================================
		%> @brief update our screen centre to use any offsets we've defined
		%>
		%> @param
		% ===================================================================
		function updateCenter(obj)
			if length(obj.winRect) == 4
				%get the center of our screen, along with user defined offsets
				[obj.xCenter, obj.yCenter] = RectCenter(obj.winRect);
				obj.xCenter = obj.xCenter + (obj.screenXOffset * obj.ppd_);
				obj.yCenter = obj.yCenter + (obj.screenYOffset * obj.ppd_);
			end
		end
	
	end
	
end


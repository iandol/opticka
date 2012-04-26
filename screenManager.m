classdef screenManager < handle
	%screenManager Manages a Screen object
	%   screenManager manages PTB screen objects for opticka
	
	properties
		%> MBP 1440x900 is 33.2x20.6cm so approx 44px/cm, Flexscan is 32px/cm @1280 26px/cm @ 1024
		pixelsPerCm = 44
		%> distance of subject from CRT -- rad2ang(2*(atan((0.5*1cm)/57.3cm))) equals 1deg
		distance = 57.3
		%> hide the black flash as PTB tests it refresh timing, uses a gamma trick
		hideFlash = false
		%> windowed: if 1 useful for debugging, but remember timing will be poor
		windowed = 0
		%> change the parameters for poorer temporal fidelity during debugging
		debug = false
		%> shows the info text and position grid during stimulus presentation
		visualDebug = false
		%> normally should be left at 1 (1 is added to this number so doublebuffering is enabled)
		doubleBuffer = 1
		%>bitDepth of framebuffer
		bitDepth = '8bit'
		%> multisampling sent to the graphics card, try values []=disabled, 4, 8
		%> and 16 -- essential for textures to stop aliasing
		antiAlias = []
		%> background of display during stimulus presentation
		backgroundColour = [0.5 0.5 0.5 0]
		%> shunt screen center by X degrees
		screenXOffset = 0
		%> shunt screen center by Y degrees
		screenYOffset = 0
		%> the monitor to use
		screen = []
		%> use OpenGL blending mode
		blend = false
		%> GL_ONE %src mode
		srcMode = 'GL_ONE'
		%> GL_ONE % dst mode
		dstMode = 'GL_ZERO'
		%> show a centered spot?
		fixationPoint = false
		%> show a white square to trigger a photodiode attached to screen
		photoDiode = false
		%> gamma correction info saved as a calibrateLuminance object
		gammaTable
		%> settings for movie output
		movieSettings = []
		%> useful screen info and initial gamma tables and the like
		screenVals
		%> verbosity
		verbose = true
		%> level of PTB verbosity
		verbosityLevel = 4
	end
	
	properties (SetAccess = private, GetAccess = public, Dependent = true)
		%> dependent property calculated from distance and pixelsPerCm
		ppd
	end
	
	properties (SetAccess = private, GetAccess = public)
		%> do we have a working PTB, if not go into a silent mode
		isPTB = false
		%> the handle returned by opening a PTB window
		win
		%> the window rectangle
		winRect
		%> computed X center
		xCenter
		%> computed Y center
		yCenter
		%> set automatically on construction
		maxScreen
	end
	
	properties (SetAccess = private, GetAccess = private)
		%> properties allowed to be modified during construction
		allowedProperties='^(bitDepth|pixelsPerCm|distance|screen|windowed|backgroundColor|screenXOffset|screenYOffset|blend|fixationPoint|srcMode|dstMode|antiAlias|debug|photoDiode|verbose|hideFlash)$'
		%> the photoDiode rectangle
		photoDiodeRect = [0;0;50;50]
		%> the values computed to draw the 1deg dotted grid in debug mode
		grid
		%> the movie pointer
		moviePtr = []
		%> movie mat structure
		movieMat = []
	end
	
	methods
		% ===================================================================
		%> @brief Class constructor
		%>
		%> More detailed description of what the constructor does.
		%>
		%> @param args are passed as a structure of properties which is
		%> parsed.
		%> @return instance of the class.
		% ===================================================================
		function obj = screenManager(varargin)
			if nargin>0
				obj.parseArgs(varargin);
			end
			if strcmpi(computer,'MACI64')
				obj.isPTB = false;
				obj.salutation('64bit Matlab not currently supported by PTB!')
			else
				try
					AssertOpenGL
					obj.isPTB = true;
				catch %#ok<*CTCH>
					obj.isPTB = false;
					obj.salutation('OpenGL support needed by PTB!')
				end
			end
			obj.prepareScreen;
		end
		
		% ===================================================================
		%> @brief prepare the Screen values on the local machine
		%>
		%> @param
		%> @return
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
			
			%get screen dimensions
			[obj.screenVals.width, obj.screenVals.height] = Screen('WindowSize',obj.screen);
			obj.winRect = Screen('Rect',obj.screen);
			
			obj.screenVals.resetGamma = false;
			
			%this is just a rough initial setting, it will be recalculated when we
			%open the screen before showing stimuli.
			obj.screenVals.fps=Screen('FrameRate',obj.screen);
			if obj.screenVals.fps == 0
				obj.screenVals.fps = 60;
			end
			obj.screenVals.ifi=1/obj.screenVals.fps;
			
			Screen('Preference', 'TextRenderer', 0); %fast text renderer
			
			if obj.debug == true
				obj.visualDebug = true;
			end
			
			obj.makeGrid;
			
			screenVals = obj.screenVals;
			
		end
		
		% ===================================================================
		%> @brief prepare the Screen values on the local machine
		%>
		%> @param debug, whether we show debug status, called from runExperiment
		%> @param tL timLog object to add timing info on screen construction
		%> @return screenVals basic info on the screen
		% ===================================================================
		function screenVals = open(obj,debug,tL)
			if obj.isPTB == false
				screenVals = obj.screenVals;
				return;
			end
			if ~exist('debug','var')
				debug = true;
			end
			if ~exist('tL','var')
				tL = struct;
			end
			try
				obj.screenVals.resetGamma = false;
				
				obj.hideScreenFlash;
				
				if debug == true || obj.windowed(1)>0
					Screen('Preference', 'SkipSyncTests', 2);
					Screen('Preference', 'VisualDebugLevel', 0);
					Screen('Preference', 'Verbosity', 2);
					Screen('Preference', 'SuppressAllWarnings', 0);
				else
					Screen('Preference', 'SkipSyncTests', 0);
					Screen('Preference', 'VisualDebugLevel', 3);
					Screen('Preference', 'Verbosity', obj.verbosityLevel); %errors and warnings
					Screen('Preference', 'SuppressAllWarnings', 0);
				end
				
				tL.screen.preOpenWindow=GetSecs;
				
				PsychImaging('PrepareConfiguration');
				PsychImaging('AddTask', 'General', 'UseFastOffscreenWindows');
				if ischar(obj.bitDepth) && ~strcmpi(obj.bitDepth,'8bit')
					PsychImaging('AddTask', 'General', obj.bitDepth);
				end
				PsychImaging('AddTask', 'General', 'NormalizedHighresColorRange'); %we always want 0-1 colourrange!
				
				if isempty(obj.windowed) || length(obj.windowed) == 1 %fullscreen
					[obj.win, obj.winRect] = PsychImaging('OpenWindow', obj.screen, obj.backgroundColour,[], [], obj.doubleBuffer+1,[],obj.antiAlias);
				else %windowed
					if length(obj.windowed)==1
						obj.windowed=[1 1 801 601];
					elseif length(obj.windowed) == 2
						obj.windowed = [1 1 obj.windowed(1)+1 obj.windowed(2)+1];
					end
					[obj.win, obj.winRect] = PsychImaging('OpenWindow', obj.screen, obj.backgroundColour,obj.windowed, [], obj.doubleBuffer+1,[],obj.antiAlias);
				end
				
				tL.screen.postOpenWindow=GetSecs;
				tL.screen.deltaOpenWindow=(tL.screen.postOpenWindow-tL.screen.preOpenWindow)*1000;
				
				obj.screenVals.win = obj.win; %make a copy
				
				try
					AssertGLSL;
				catch ME
					obj.close();
					error('GLSL Shading support is required for Opticka!');
				end
				
				Priority(MaxPriority(obj.win)); %bump our priority to maximum allowed
				%find our fps if not defined before
				obj.screenVals.ifi = Screen('GetFlipInterval', obj.win);
				if obj.screenVals.fps==0
					obj.screenVals.fps=round(1/obj.screenVals.ifi);
				end
				obj.screenVals.halfisi=obj.screenVals.ifi/2;
				Priority(0); %be lazy for a while and let other things get done
				
				
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
				
				% Enable alpha blending.
				if obj.blend==1
					Screen('BlendFunction', obj.win, obj.srcMode, obj.dstMode);
				end
				
				%get the center of our screen, along with user defined offsets
				[obj.xCenter, obj.yCenter] = RectCenter(obj.winRect);
				obj.xCenter=obj.xCenter+(obj.screenXOffset*obj.ppd);
				obj.yCenter=obj.yCenter+(obj.screenYOffset*obj.ppd);
				
				obj.screenVals.black = BlackIndex(obj.win);
				obj.screenVals.white = WhiteIndex(obj.win);
				
				screenVals = obj.screenVals;
				
			catch ME
				obj.close();
				obj.screenVals = [];
				screenVals = obj.screenVals;
				rethrow(ME)
			end
			
		end
		
		% ===================================================================
		%> @brief prepare the Screen values on the local machine
		%>
		%> @param
		%> @return
		% ===================================================================
		function hideScreenFlash(obj)
			% This is the trick Mario told us to "hide" the colour changes as PTB
			% intialises -- we could use backgroundcolour here to be even better
			if obj.hideFlash == true && length(obj.windowed) == 1 && obj.windowed(1) == 0
				if isa(obj.gammaTable,'calibrateLuminance') && (obj.gammaTable.choice > 0)
					obj.screenVals.oldGamma = Screen('LoadNormalizedGammaTable', obj.screen, repmat(obj.gammaTable.gammaTable{obj.gammaTable.choice}(128,:), 256, 3));
					obj.screenVals.resetGamma = true;
				else
					%table = repmat(obj.screenVals.gammaTable(128,:), 256, 1); %use midpoint in system gamma table
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
				Screen('Close');
				Screen('CloseAll');
				obj.win=[];
				Priority(0);
				ShowCursor;
			end
		end
		
		% ===================================================================
		%> @brief prepare the Screen values on the local machine
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
		%> @brief prepare the Screen values on the local machine
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
		%> @brief prepare the Screen values on the local machine
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
		%> @brief prepare the Screen values on the local machine
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
		%> @brief prepare the Screen values on the local machine
		%>
		%> @param
		%> @return
		% ===================================================================
		function resetScreenGamma(obj)
			if obj.screenVals.resetGamma == true || obj.hideFlash == true || obj.windowed(1) ~= 1
				fprintf('\n---> screenManager: RESET GAMMA TABLES\n');
				Screen('LoadNormalizedGammaTable', obj.screen, obj.screenVals.gammaTable);
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
			obj.makeGrid();
			%obj.salutation(['set distance: ' num2str(obj.distance) '|ppd: ' num2str(obj.ppd)],'Custom set method')
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
			obj.makeGrid();
			%obj.salutation(['set pixelsPerCm: ' num2str(obj.pixelsPerCm) '|ppd: ' num2str(obj.ppd)],'Custom set method')
		end
		
		% ===================================================================
		%> @brief Configure grating specific variables
		%>
		%> @param i
		%> @return
		% ===================================================================
		function drawFixationPoint(obj)
			Screen('gluDisk',obj.win,[1 0 1 1],obj.xCenter,obj.yCenter,2);
		end
		
		% ===================================================================
		%> @brief Configure grating specific variables
		%>
		%> @param i
		%> @return
		% ===================================================================
		function drawGrid(obj)
			Screen('DrawDots',obj.win,obj.grid,1,[1 0 1 1],[obj.xCenter obj.yCenter],1);
		end
		
		% ===================================================================
		%> @brief Configure grating specific variables
		%>
		%> @param i
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
		%> @brief Makes a 5x5 1deg dot grid for debug mode
		%> This is always updated on setting distance or pixelsPerCm 
		% ===================================================================
		function makeGrid(obj)
			obj.grid=[];
			for i=-5:5
				obj.grid=horzcat(obj.grid,[-5 -4 -3 -2 -1 0 1 2 3 4 5;i i i i i i i i i i i]);
			end
			obj.grid=obj.grid.*obj.ppd; %we use ppd so we can cache ppd_ for elsewhere
		end
		
		% ===================================================================
		%> @brief Get method for ppd (a dependent property)
		%>
		%> @param
		% ===================================================================
		function ppd = get.ppd(obj)
			ppd=round(obj.pixelsPerCm*(obj.distance/57.3)); %set the pixels per degree
		end
		
		% ===================================================================
		%> @brief Sets properties from a structure, ignores invalid properties
		%>
		%> @param args input structure
		% ===================================================================
		function parseArgs(obj,args)
			while iscell(args) && length(args) == 1
				args = args{1};
			end
			if iscell(args)
				if mod(length(args),2) == 1 % odd
					args = args(1:end-1); %remove last arg
				end
				odd = logical(mod(1:length(args),2));
				even = logical(abs(odd-1));
				args = cell2struct(args(even),args(odd),2);
			end
			fnames = fieldnames(args); %find our argument names
			for i=1:length(fnames);
				if regexp(fnames{i},obj.allowedProperties) %only set if allowed property
					obj.salutation(fnames{i},'Configuring setting');
					obj.(fnames{i})=args.(fnames{i}); %we set up the properies from the arguments as a structure
				end
			end
		end
		
		% ===================================================================
		%> @brief Prints messages dependent on verbosity
		%>
		%> Prints messages dependent on verbosity
		%> @param in the calling function
		%> @param message the message that needs printing to command window
		% ===================================================================
		function salutation(obj,in,message)
			if obj.verbose==true
				if ~exist('in','var') || isempty(in)
					in = 'undefined';
				end
				if exist('message','var')
					fprintf(['---> screenManager: ' message ' | ' in '\n']);
				else
					fprintf(['---> screenManager: ' in '\n']);
				end
			end
		end
		
		% ===================================================================
		%> @brief Delete method
		%>
		% ===================================================================
		function delete(obj)
			obj.close();
			obj.salutation('DELETE method','Screen object has been closed/reset...');
		end
		
	end
	
end


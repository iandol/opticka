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
		%> the monitor to use, 0 is the main display on macOS/Linux
		%> default value will be set to max(Screen('Screens'))
		screen double = []
		%> MBP 1440x900 is 33.2x20.6cm so approx 44px/cm, Flexscan is 32px/cm @1280 26px/cm @ 1024
		%> use calibrateSize.m to measure this value for each monitor you
		%> will use.
		pixelsPerCm double = 36
		%> distance of subject from CRT -- rad2ang(2*(atan((0.5*1cm)/57.3cm))) equals 1deg
		distance double = 57.3
		%> hide the black flash as PTB tests its refresh timing, uses a gamma
		%> trick from Mario
		hideFlash logical = false
		%> windowed: when FALSE use fullscreen; set to TRUE and it is windowed 800x600pixels or you
		%> can add in a window width and height i.e. [800 600] to specify windowed size. Remember
		%> that windowed presentation should never be used for real experimental
		%> presentation due to poor timing...
		windowed = false
		%> change the debug parameters for poorer temporal fidelity but no sync testing etc.
		debug logical = false
		%> shows the info text and position grid during stimulus presentation if true
		visualDebug logical = false
		%> normally should be left at 1 (1 is added to this number so doublebuffering is enabled)
		doubleBuffer uint8 = 1
		%> bitDepth of framebuffer, '8bit' is best for old GPUs, but prefer
		%> 'FloatingPoint32BitIfPossible' for newer GPUS, and can pass 
		%> options to enable Display++ modes 'EnableBits++Bits++Output'
		%> 'EnableBits++Mono++Output' or 'EnableBits++Color++Output'
		bitDepth char = 'FloatingPoint32BitIfPossible'
		%> timestamping mode 1=beamposition,kernel fallback | 2=beamposition crossvalidate with kernel
		timestampingMode double = 1
		%> multisampling sent to the graphics card, try values 0[disabled], 4, 8
		%> and 16 -- useful for textures to minimise aliasing, but this
		%> does provide extra work for the GPU
		antiAlias double = 0
		%> background RGBA of display during stimulus presentation
		backgroundColour double = [0.5 0.5 0.5 0]
		%> shunt center by X degrees (coordinates are in degrees from centre of monitor)
		screenXOffset double = 0
		%> shunt center by Y degrees (coordinates are in degrees from centre of monitor)
		screenYOffset double = 0
		%> use OpenGL blending mode
		blend logical = false
		%> GL_ONE %src mode
		srcMode char = 'GL_SRC_ALPHA'
		%> GL_ONE % dst mode
		dstMode char = 'GL_ONE_MINUS_SRC_ALPHA'
		%> show a white square in the top-left corner to trigger a
		%> photodiode attached to screen. This is only displayed when the
		%> stimulus is shown, not during the blank and can therefore be used
		%> for timing validation
		photoDiode logical = false
		%> gamma correction info saved as a calibrateLuminance object
		gammaTable calibrateLuminance
		%> settings for movie output
		movieSettings = []
		%> useful screen info and initial gamma tables and the like
		screenVals struct
		%> verbosity
		verbose = false
		%> level of PTB verbosity, set to 10 for full PTB logging
		verbosityLevel double = 4
		%> Use retina resolution natively
		useRetina logical = false
		%> Screen To Head Mapping, a Nx3 vector: Screen('Preference', 'ScreenToHead', screen, head, crtc);
		%> Each N should be a different display
		screenToHead = []
		%> framerate for Display++ (120Hz or 100Hz, empty uses the default OS setup)
		displayPPRefresh double = []
	end
	
	properties (Hidden = true)
		%> for some development macOS machines we have to disable sync tests,
		%> but we hide this as we should remember this is for development
		%> ONLY!
		disableSyncTests logical = false
	end
	
	properties (SetAccess = private, GetAccess = public, Dependent = true)
		%> dependent pixels per degree property calculated from distance and pixelsPerCm
		ppd
	end
	
	properties (SetAccess = private, GetAccess = public)
		%> do we have a working PTB, if not go into a silent mode
		isPTB logical = false
		%> is a PTB currently open?
		isOpen logical = false
		%> did we ask for a bitsPlusPlus mode?
		isPlusPlus logical = false
		%> the handle returned by opening a PTB window
		win
		%> the window rectangle
		winRect
		%> computed X center
		xCenter double = 0
		%> computed Y center
		yCenter double = 0
		%> set automatically on construction
		maxScreen
	end
	
	properties (SetAccess = private, GetAccess = private)
		%> linux font name;
		linuxFontName char = '-adobe-helvetica-bold-o-normal--11-80-100-100-p-60-iso8859-1'
		%> properties allowed to be modified during construction
		allowedProperties char = 'disableSyncTests|displayPPRefresh|screenToHead|gammaTable|useRetina|bitDepth|pixelsPerCm|distance|screen|windowed|backgroundColour|screenXOffset|screenYOffset|blend|srcMode|dstMode|antiAlias|debug|photoDiode|verbose|hideFlash'
		%> possible bitDepths
		bitDepths cell = {'FloatingPoint32BitIfPossible'; 'FloatingPoint32Bit'; 'FixedPoint16Bit'; 'FloatingPoint16Bit'; '8bit'; 'EnableBits++Bits++Output'; 'EnableBits++Mono++Output'; 'EnableBits++Color++Output'; 'EnablePseudoGrayOutput'; 'EnableNative10BitFramebuffer' }
		%> possible blend modes
		blendModes cell = {'GL_ZERO'; 'GL_ONE'; 'GL_DST_COLOR'; 'GL_ONE_MINUS_DST_COLOR'; 'GL_SRC_ALPHA'; 'GL_ONE_MINUS_SRC_ALPHA'; 'GL_DST_ALPHA'; 'GL_ONE_MINUS_DST_ALPHA'; 'GL_SRC_ALPHA_SATURATE' }
		%> the photoDiode rectangle in pixel values
		photoDiodeRect(1,4) double = [0, 0, 45, 45]
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
		function me = screenManager(varargin)
			if nargin == 0; varargin.name = ''; end
			me=me@optickaCore(varargin); %superclass constructor
			if nargin>0
				me.parseArgs(varargin,me.allowedProperties);
			end
			try
				AssertOpenGL
				me.isPTB = true;
				if strcmpi(computer,'MACI64')
					me.salutation('64bit OS X PTB currently supported!')
				else
					me.salutation('PTB currently supported!')
				end
			catch %#ok<*CTCH>
				me.isPTB = false;
				me.salutation('OpenGL support needed by PTB!')
			end
			prepareScreen(me);
		end
		
		% ===================================================================
		%> @brief prepare the Screen values on the local machine
		%>
		%> @param me object
		%> @return screenVals structure of screen values
		% ===================================================================
		function screenVals = prepareScreen(me)
			if me.isPTB == false
				me.maxScreen = 0;
				me.screen = 0;
				me.screenVals.resetGamma = false;
				me.screenVals.fps = 60;
				me.screenVals.ifi = 1/60;
				me.screenVals.width = 0;
				me.screenVals.height = 0;
				me.makeGrid;
				screenVals = me.screenVals;
				return
			end
			me.maxScreen=max(Screen('Screens'));
			
			%by default choose the (largest number) screen
			if isempty(me.screen) || me.screen > me.maxScreen
				me.screen = me.maxScreen;
			end
			
			me.screenVals = struct();
			
			checkWindowValid(me);
			
			%get the gammatable and dac information
			try
			[me.screenVals.gammaTable,me.screenVals.dacBits,me.screenVals.lutSize]=Screen('ReadNormalizedGammaTable', me.screen);
			me.screenVals.originalGammaTable = me.screenVals.gammaTable;
			catch
				me.screenVals.gammaTable = [];
				me.screenVals.dacBits = [];
				me.screenVals.lutSize = 256;
			end
			
			%get screen dimensions
			setScreenSize(me);
			
			me.screenVals.resetGamma = false;
			
			%this is just a rough initial setting, it will be recalculated when we
			%open the screen before showing stimuli.
			me.screenVals.fps=Screen('FrameRate',me.screen);
			if me.screenVals.fps == 0 || (me.screenVals.fps == 59 && IsWin)
				me.screenVals.fps = 60;
			end
			me.screenVals.ifi=1/me.screenVals.fps;
			
			% initialise our movie settings
			me.movieSettings.loop = Inf;
			me.movieSettings.record = false;
			me.movieSettings.size = [600 600];
			me.movieSettings.fps = 30;
			me.movieSettings.quality = 0.7;
			me.movieSettings.keyframe = 5;
			me.movieSettings.nFrames = me.screenVals.fps * 2;
			me.movieSettings.type = 1;
			me.movieSettings.codec = 'x264enc'; %space is important for 'rle '
			
			if me.debug == true %we yoke these together but they can then be overridden
				me.visualDebug = true;
			end
			if ismac
				me.disableSyncTests = true;
			end
			
			me.ppd; %generate our dependent propertie and caches it to ppd_ for speed
			me.makeGrid; %our visualDebug size grid
			
			me.screenVals.white = WhiteIndex(me.screen);
			me.screenVals.black = BlackIndex(me.screen);
			me.screenVals.gray = GrayIndex(me.screen);
			
			if IsLinux
				d=Screen('ConfigureDisplay','Scanout',me.screen,0);
				me.screenVals.name = d.name;
				me.screenVals.widthMM = d.displayWidthMM;
				me.screenVals.heightMM = d.displayHeightMM;
				me.screenVals.display = d;
			end
			
			screenVals = me.screenVals;
			
		end
		
		% ===================================================================
		%> @brief open a screen with object defined settings
		%>
		%> @param debug, whether we show debug status, called from runExperiment
		%> @param tL timeLog object to add timing info on screen construction
		%> @return screenVals structure of basic info from the opened screen
		% ===================================================================
		function screenVals = open(me,debug,tL,forceScreen)
			if me.isPTB == false
				warning('No PTB found!')
				screenVals = me.screenVals;
				return;
			end
			if ~exist('debug','var') || isempty(debug)
				debug = me.debug;
			end
			if ~exist('tL','var') || isempty(tL)
				tL = struct;
			end
			if ~exist('forceScreen','var')
				forceScreen = [];
			end
			
			try
				PsychDefaultSetup(2);
				me.screenVals.resetGamma = false;
				
				me.hideScreenFlash();
				
				if ~isempty(me.screenToHead) && isnumeric(me.screenToHead)
					for i = 1:size(me.screenToHead,1)
						sth = me.screenToHead(i,:);
						if lengtht(stc) == 3
							fprintf('\n---> screenManager: Custom Screen to Head: %i %i %i\n',sth(1), sth(2), sth(3));
							Screen('Preference', 'ScreenToHead', sth(1), sth(2), sth(3));
						end
					end
				end
				
				%1=beamposition,kernel fallback | 2=beamposition crossvalidate with kernel
				%Screen('Preference', 'VBLTimestampingMode', me.timestampingMode);
				
				if ~islogical(me.windowed) && isnumeric(me.windowed) %force debug for windowed stimuli!
					debug = true;
				end
				
				if debug == true || (length(me.windowed)==1 && me.windowed ~= 0)
					fprintf('\n---> screenManager: Skipping Sync Tests etc. - ONLY FOR DEVELOPMENT!\n');
					Screen('Preference', 'SkipSyncTests', 2);
					Screen('Preference', 'VisualDebugLevel', 0);
					Screen('Preference', 'Verbosity', 2);
					Screen('Preference', 'SuppressAllWarnings', 0);
				else
					if me.disableSyncTests
						fprintf('\n---> screenManager: Sync Tests OVERRIDDEN, do not use for real experiments!!!\n');
						Screen('Preference', 'SkipSyncTests', 2);
					else
						fprintf('\n---> screenManager: Normal Screen Preferences used.\n');
						Screen('Preference', 'SkipSyncTests', 0);
					end
					Screen('Preference', 'VisualDebugLevel', 3);
					Screen('Preference', 'Verbosity', me.verbosityLevel); %errors and warnings
					Screen('Preference', 'SuppressAllWarnings', 0);
				end
				
				tL.screenLog.preOpenWindow=GetSecs;
				
				PsychImaging('PrepareConfiguration');
				PsychImaging('AddTask', 'General', 'UseFastOffscreenWindows');
				%PsychImaging('AddTask', 'General', 'NormalizedHighresColorRange'); %we always want 0-1 colour range!
				fprintf('---> screenManager: Probing for a Display++... ');
				bitsCheckOpen(me);
				if me.isPlusPlus; fprintf('Found Display++...\n'); else; fprintf('NO Display++...\n'); end
				if regexpi(me.bitDepth, '^EnableBits')
					if me.isPlusPlus
						fprintf('\t-> Display++ mode: %s\n', me.bitDepth);
						PsychImaging('AddTask', 'FinalFormatting', 'DisplayColorCorrection', 'ClampOnly');
						if regexp(me.bitDepth, 'Color')
							PsychImaging('AddTask', 'General', me.bitDepth, 2);
						else
							PsychImaging('AddTask', 'General', me.bitDepth);
						end
					else
						fprintf('---> screenManager: No Display++ found, revert to FloatingPoint32Bit mode.\n');
						PsychImaging('AddTask', 'General', 'FloatingPoint32BitIfPossible');
						me.isPlusPlus = false;
					end
				else
					fprintf('\n---> screenManager: Bit Depth mode set to: %s\n', me.bitDepth);
					PsychImaging('AddTask', 'General', me.bitDepth);
					me.isPlusPlus = false;
				end
				if me.useRetina == true
					fprintf('---> screenManager: Retina mode enabled\n');
					PsychImaging('AddTask', 'General', 'UseRetinaResolution');
				end
				
				try %#ok<*TRYNC>
					if me.isPlusPlus && ~isempty(me.displayPPRefresh) && IsLinux
						outputID = 0;
						fprintf('\n---> screenManager: Set Display++ to %iHz\n',me.displayPPRefresh);
						Screen('ConfigureDisplay','Scanout',me.screen,outputID,[],[],me.displayPPRefresh);
					end
				end
				
				if isempty(me.windowed); me.windowed = false; end
				thisScreen = me.screen;
				if me.windowed == false %fullscreen
					winSize = [];
				else %windowed
					if length(me.windowed) == 2
						winSize = [0 0 me.windowed(1) me.windowed(2)];
					elseif length(me.windowed) == 4
						winSize = me.windowed;
					else
						winSize=[0 0 800 800];
					end
				end
				if ~isempty(forceScreen)
					thisScreen = forceScreen;
				end
				
				[me.win, me.winRect] = PsychImaging('OpenWindow', thisScreen, me.backgroundColour, winSize, [], me.doubleBuffer+1,[],me.antiAlias);
				
				tL.screenLog.postOpenWindow=GetSecs;
				tL.screenLog.deltaOpenWindow=(tL.screenLog.postOpenWindow-tL.screenLog.preOpenWindow)*1000;
				
				try
					AssertGLSL;
				catch
					close(me);
					error('GLSL Shading support is required for Opticka!');
				end
				
				if IsLinux
					d=Screen('ConfigureDisplay','Scanout',me.screen,0);
					me.screenVals.name = d.name;
					me.screenVals.widthMM = d.displayWidthMM;
					me.screenVals.heightMM = d.displayHeightMM;
					me.screenVals.display = d;
				end
				
				me.screenVals.win = me.win; %make a copy
				me.screenVals.winRect = me.winRect; %make a copy
				
				me.screenVals.ifi = Screen('GetFlipInterval', me.win);
				me.screenVals.fps=Screen('NominalFramerate', me.win);
				%find our fps if not defined above
				if me.screenVals.fps == 0
					me.screenVals.fps=round(1/me.screenVals.ifi);
					if me.screenVals.fps == 0 || (me.screenVals.fps == 59 && IsWin)
						me.screenVals.fps = 60;
					end
				elseif me.screenVals.fps == 59 && IsWin
					me.screenVals.fps = 60;
					me.screenVals.ifi = 1 / 60;
				end
				if me.windowed == false %fullscreen
					me.screenVals.halfifi = me.screenVals.ifi/2;
                    me.screenVals.halfisi = me.screenVals.halfifi;
				else
					% windowed presentation doesn't handle the preferred method
					% of specifying lastvbl+halfifi properly so we set halfifi to 0 which
					% effectively makes flip occur ASAP.
					me.screenVals.halfifi = 0; me.screenVals.halfisi = 0;
				end
				
				%get screen dimensions -- check !!!!!
				setScreenSize(me);
				
				if me.hideFlash == true && isempty(me.gammaTable)
					Screen('LoadNormalizedGammaTable', me.screen, me.screenVals.gammaTable);
					me.screenVals.resetGamma = false;
				elseif ~isempty(me.gammaTable) && (me.gammaTable.choice > 0)
					choice = me.gammaTable.choice;
					me.screenVals.resetGamma = true;
					if size(me.gammaTable.gammaTable,2) > 1
						if isprop(me.gammaTable,'finalCLUT') && ~isempty(me.gammaTable.finalCLUT)
							gTmp = me.gammaTable.finalCLUT;
						else
							gTmp = [me.gammaTable.gammaTable{choice,2:4}];
						end
					else
						gTmp = repmat(me.gammaTable.gammaTable{choice,1},1,3);
					end
					Screen('LoadNormalizedGammaTable', me.screen, gTmp);
					fprintf('\n---> screenManager: SET GAMMA CORRECTION using: %s\n', me.gammaTable.modelFit{choice}.method);
					if isprop(me.gammaTable,'correctColour') && me.gammaTable.correctColour == true
						fprintf('---> screenManager: GAMMA CORRECTION used independent RGB Correction \n');
					end
				else
					%Screen('LoadNormalizedGammaTable', me.screen, me.screenVals.gammaTable);
					%me.screenVals.oldCLUT = LoadIdentityClut(me.win);
					me.screenVals.resetGamma = false;
				end
				
				% Enable alpha blending.
				if me.blend==1
					[me.screenVals.oldSrc,me.screenVals.oldDst,me.screenVals.oldMask]...
						= Screen('BlendFunction', me.win, me.srcMode, me.dstMode);
					fprintf('\n---> screenManager: Previous OpenGL blending was %s | %s\n', me.screenVals.oldSrc, me.screenVals.oldDst);
					fprintf('---> screenManager: OpenGL blending now set to %s | %s\n', me.srcMode, me.dstMode);
				end
				
				if IsLinux
					Screen('Preference', 'DefaultFontName', 'DejaVu Sans');
				end
				
				me.screenVals.white = WhiteIndex(me.screen);
				me.screenVals.black = BlackIndex(me.screen);
				me.screenVals.gray = GrayIndex(me.screen);
				
				me.isOpen = true;
				flip(me);
				screenVals = me.screenVals;
				
			catch ME
				close(me);
				Priority(0);
				prepareScreen(me);
				rethrow(ME)
			end
			
		end
		
		% ===================================================================
		%> @brief Small demo
		%>
		%> @param
		%> @return
		% ===================================================================
		function demo(me)
			if ~me.isOpen
				stim = textureStimulus('speed',4,'xPosition',-6,'yPosition',0,'size',1);
				prepareScreen(me);
				open(me);
				disp('--->>> screenManager running a quick demo...')
				disp(me.screenVals);
				setup(stim, me);
				vbl = flip(me);
				for i = 1:me.screenVals.fps*2
					draw(stim);
					finishDrawing(me);
					animate(stim);
					vbl = flip(me, vbl);
				end
				WaitSecs(1);
				clear stim;
				close(me);
			end
		end
		
		% ===================================================================
		%> @brief Flip the screen
		%>
		%> @param vbl - a vbl time from a previous flip
		%> @return vbl - a vbl from this flip
		% ===================================================================
		function [vbl, when] = flip(me,vbl,varargin)
			if ~me.isOpen; return; end
			if exist('vbl','var')
				[vbl, when] = Screen('Flip',me.win, vbl + me.screenVals.halfifi,varargin);
			else
				[vbl, when] = Screen('Flip',me.win);
			end
		end
		
		% ===================================================================
		%> @brief check for display++, and keep open or close again
		%>
		%> @param port optional serial USB port
		%> @param keepOpen should we keep it open after check (default yes)
		%> @return connected - is the Display++ connected?
		% ===================================================================
		function connected = bitsCheckOpen(me,port,keepOpen)
			connected = false;
			if ~exist('keepOpen','var') || isempty(keepOpen)
				keepOpen = true;
			end
			try
				if ~exist('port','var')
					ret = BitsPlusPlus('OpenBits#');
				else
					ret = BitsPlusPlus('OpenBits#',port);
				end
				if ret == 1; connected = true; end
				if ~keepOpen; BitsPlusPlus('Close'); end
				return;
			end
			me.isPlusPlus = connected;
		end
		
		% ===================================================================
		%> @brief Flip the screen
		%>
		%> @param
		%> @return
		% ===================================================================
		function bitsSwitchStatusScreen(me)
			BitsPlusPlus('SwitchToStatusScreen');
		end
		
		% ===================================================================
		%> @brief force this object to use antother window
		%>
		%> @param win - the window handle to bind to
		%> @return
		% ===================================================================
		function forceWin(me,win)
			me.win = win;
			me.isOpen = true;
			me.isPTB = true;
			me.screenVals.ifi = Screen('GetFlipInterval', me.win);
			me.screenVals.white = WhiteIndex(me.win);
			me.screenVals.black = BlackIndex(me.win);
			me.screenVals.gray = GrayIndex(me.win);
			setScreenSize(me);
			fprintf('---> screenManager slaved to external win: %i\n',win);
		end
		
		% ===================================================================
		%> @brief This is the trick Mario told us to "hide" the colour changes
		%> as PTB starts -- we could use backgroundcolour here to be even better
		%>
		%> @param
		%> @return
		% ===================================================================
		function hideScreenFlash(me)
			% This is the trick Mario told us to "hide" the colour changes as PTB
			% intialises -- we could use backgroundcolour here to be even better
			if me.hideFlash == true && all(me.windowed == false)
				if isa(me.gammaTable,'calibrateLuminance') && (me.gammaTable.choice > 0)
					me.screenVals.oldGamma = Screen('LoadNormalizedGammaTable', me.screen, repmat(me.gammaTable.gammaTable{me.gammaTable.choice}(128,:), 256, 3));
					me.screenVals.resetGamma = true;
				else
					table = repmat(me.backgroundColour(:,1:3), 256, 1);
					me.screenVals.oldGamma = Screen('LoadNormalizedGammaTable', me.screen, table);
					me.screenVals.resetGamma = true;
				end
			end
		end
		
		% ===================================================================
		%> @brief close the screen when finished or on error
		%>
		%> @param
		%> @return
		% ===================================================================
		function close(me)
			if ~me.isPTB; return; end
			Priority(0);
			ListenChar(0);
			ShowCursor;
			if isfield(me.screenVals,'originalGammaTable') && ~isempty(me.screenVals.originalGammaTable)
				Screen('LoadNormalizedGammaTable', me.screen, me.screenVals.originalGammaTable);
				fprintf('\n---> screenManager: RESET GAMMA TABLES\n');
			end
			wk = Screen(me.win, 'WindowKind');
			if me.blend == true & wk ~= 0
				%this needs to be done to not trigger a Linux+Polaris bug
				%matlab bug
				Screen('BlendFunction', me.win, 'GL_ONE','GL_ZERO');
				fprintf('---> screenManager: RESET OPENGL BLEND MODE to GL_ONE & GL_ZERO\n');
			end
			if me.isPlusPlus
				BitsPlusPlus('Close');
			end
			me.finaliseMovie(); me.moviePtr = [];
			Screen('CloseAll');
			me.win=[]; 
			if isfield(me.screenVals,'win');me.screenVals=rmfield(me.screenVals,'win');end
			me.isOpen = false;
			me.isPlusPlus = false;
			sca; % PTB function also run just in case ;-)
		end
		
		
		% ===================================================================
		%> @brief reset the gamma table
		%>
		%> @param
		%> @return
		% ===================================================================
		function resetScreenGamma(me)
			if me.hideFlash == true || me.windowed(1) ~= 1 || (~isempty(me.screenVals) && me.screenVals.resetGamma == true && ~isempty(me.screenVals.originalGammaTable))
				fprintf('\n---> screenManager: RESET GAMMA TABLES\n');
				Screen('LoadNormalizedGammaTable', me.screen, me.screenVals.originalGammaTable);
			end
		end
		
		% ===================================================================
		%> @brief Set method for bitDepth
		%>
		%> @param
		% ===================================================================
		function set.bitDepth(me,value)
			check = strcmpi(value,me.bitDepths);
			if any(check)
				me.bitDepth = me.bitDepths{check};
			else
				warning('Wrong Value given, select from list below')
				disp(me.bitDepths)
			end
		end
		
		% ===================================================================
		%> @brief Set method for distance
		%>
		%> @param
		% ===================================================================
		function set.distance(me,value)
			if ~(value > 0)
				value = 57.3;
			end
			me.distance = value;
			me.makeGrid();
		end
		
		% ===================================================================
		%> @brief Set method for pixelsPerCm
		%>
		%> @param
		% ===================================================================
		function set.pixelsPerCm(me,value)
			if ~(value > 0)
				value = 36;
			end
			me.pixelsPerCm = value;
			me.makeGrid();
		end
		
		% ===================================================================
		%> @brief Get method for ppd (a dependent property)
		%>
		%> @param
		% ===================================================================
		function ppd = get.ppd(me)
			if me.useRetina %note pixelsPerCm is normally recorded using non-retina mode so we fix that here if we are now in retina mode
				ppd = ( (me.pixelsPerCm*2) * (me.distance / 57.3) ); %set the pixels per degree
			else
				ppd = ( me.pixelsPerCm * (me.distance / 57.3) ); %set the pixels per degree
			end
			me.ppd_ = ppd; %cache value for speed!!!
		end
		
		% ===================================================================
		%> @brief Set method for windowed
		%>
		%> @param
		% ===================================================================
		function set.windowed(me,value)
			if length(value) == 2 && isnumeric(value)
				me.windowed = [0 0 value];
			elseif length(value) == 4 && isnumeric(value)
				me.windowed = value;
			elseif islogical(value)
				me.windowed = value;
			elseif value == 1
				me.windowed = true;
			elseif value == 0
				me.windowed = false;
			else
				me.windowed = false;
			end
		end
		
		% ===================================================================
		%> @brief Set method for pixelsPerCm
		%>
		%> @param
		% ===================================================================
		function set.screenXOffset(me,value)
			me.screenXOffset = value;
			me.updateCenter();
		end
		
		% ===================================================================
		%> @brief Set method for pixelsPerCm
		%>
		%> @param
		% ===================================================================
		function set.screenYOffset(me,value)
			me.screenYOffset = value;
			me.updateCenter();
		end
		
		% ===================================================================
		%> @brief Set method for verbosityLevel
		%>
		%> @param
		% ===================================================================
		function set.verbosityLevel(me,value)
			me.verbosityLevel = value;
			Screen('Preference', 'Verbosity', me.verbosityLevel); %errors and warnings
		end
		
		% ===================================================================
		%> @brief Screen('DrawingFinished')
		%>
		%> @param
		% ===================================================================
		function finishDrawing(me)
			Screen('DrawingFinished', me.win);
		end
		
		% ===================================================================
		%> @brief Test if window is actully open
		%>
		%> @param
		% ===================================================================
		function testWindowOpen(me)
			if me.isOpen
				wk = Screen(me.win, 'WindowKind');
				if wk == 0
					warning(['===>>> ' me.fullName ' PTB Window is actually INVALID!']);
					me.isOpen = 0;
					me.win = [];
				else
					fprintf('===>>> %s VALID WindowKind = %i\n',me.fullName,wk);
				end
			end
		end
		
		% ===================================================================
		%> @brief Flash the screen until keypress
		%>
		%> @param
		% ===================================================================
		function flashScreen(me,interval)
			if me.isOpen
				int = round(interval / me.screenVals.ifi);
				KbReleaseWait;
				while ~KbCheck(-1)
					if mod(me.flashTick,int) == 0
						me.flashOn = not(me.flashOn);
						me.flashTick = 0;
					end
					if me.flashOn == 0
						Screen('FillRect',me.win,[0 0 0 1]);
					else
						Screen('FillRect',me.win,[1 1 1 1]);
					end
					Screen('Flip',me.win);
					me.flashTick = me.flashTick + 1;
				end
				drawBackground(me);
				Screen('Flip',me.win);
			end
		end
		
		% ===================================================================
		%> @brief draw small spot centered on the screen
		%>
		%> @param radius size in degrees
		%> @param colour of spot
		%> @param x position in degrees relative to screen center
		%> @param y position in degrees relative to screen center
		%> @return
		% ===================================================================
		function drawSpot(me,size,colour,x,y)
			if nargin < 5 || isempty(y); y = 0; end
			if nargin < 4 || isempty(x); x = 0; end
			if nargin < 3 || isempty(colour); colour = [1 1 1 1]; end
			if nargin < 2 || isempty(size); size = 1; end
			
			x = me.xCenter + (x * me.ppd_);
			y = me.yCenter + (y * me.ppd_);
			size = size/2 * me.ppd_;
			
			Screen('gluDisk', me.win, colour, x, y, size*2);
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
		function drawCross(me,size,colour,x,y,lineWidth)
			% drawCross(me, size, colour, x, y, lineWidth)
			if nargin < 6 || isempty(lineWidth); lineWidth = 2; end
			if nargin < 5 || isempty(y); y = 0; end
			if nargin < 4 || isempty(x); x = 0; end
			if nargin < 3 || isempty(colour)
				if mean(me.backgroundColour(1:3)) <= 0.5
					colour = [1 1 1 1];
				else
					colour = [0 0 0 1];
				end
			end
			if nargin < 2 || isempty(size); size = 0.5; end
			
			x = me.xCenter + (x * me.ppd_);
			y = me.yCenter + (y * me.ppd_);
			size = size/2 * me.ppd_;
			
			Screen('DrawLines', me.win, [-size size 0 0;0 0 -size size],...
				lineWidth, colour, [x y]);
		end
		
		% ===================================================================
		%> @brief draw timed small spot centered on the screen
		%>
		%> @param
		%> @return
		% ===================================================================
		function drawTimedSpot(me,size,colour,time,reset)
			% drawTimedSpot(me,size,colour,time,reset)
			if nargin < 5; reset = false; end
			if nargin < 4; time = 0.2; end
			if nargin < 3; colour = [1 1 1 1]; end
			if nargin < 2; size = 1; end
			if reset == true
				if length(time) == 2
					me.timedSpotTime = randi(time*1000)/1000;
				else
					me.timedSpotTime = time;
				end
				me.timedSpotNextTick = round(me.timedSpotTime / me.screenVals.ifi);
				me.timedSpotTick = 1;
				return
			end
			if me.timedSpotTick <= me.timedSpotNextTick
				size = size/2 * me.ppd_;
				Screen('gluDisk',me.win,colour,me.xCenter,me.yCenter,size);
			end
			me.timedSpotTick = me.timedSpotTick + 1;
		end
		
		% ===================================================================
		%> @brief draw small spot centered on the screen
		%>
		%> @param
		%> @return
		% ===================================================================
		function drawGreenSpot(me,size)
			% drawGreenSpot(me,size)
			if ~exist('size','var')
				size = 1;
			end
			size = size/2 * me.ppd_;
			Screen('gluDisk',me.win,[0 1 0 1],me.xCenter,me.yCenter,size);
		end
		
		% ===================================================================
		%> @brief draw small spot centered on the screen
		%>
		%> @param
		%> @return
		% ===================================================================
		function drawRedSpot(me,size)
			% drawRedSpot(me,size)
			if ~exist('size','var')
				size = 1;
			end
			size = size/2 * me.ppd_;
			Screen('gluDisk',me.win,[1 0 0 1],me.xCenter,me.yCenter,size);
		end
		
		% ===================================================================
		%> @brief draw text and flip immediately
		%>
		%> @param
		%> @return
		% ===================================================================
		function drawTextNow(me,text)
			% drawTextNow(me,text)
			if ~exist('text','var');return;end
			Screen('DrawText',me.win,text,0,0,[1 1 1],[0.5 0.5 0.5]);
			flip(me);
		end
		
		% ===================================================================
		%> @brief draw small spot centered on the screen
		%>
		%> @param
		%> @return
		% ===================================================================
		function drawScreenCenter(me)
			Screen('gluDisk',me.win,[1 0 1 1],me.xCenter,me.yCenter,2);
		end
		
		% ===================================================================
		%> @brief draw a 5x5 1deg dot grid for visual debugging
		%>
		%> @param
		%> @return
		% ===================================================================
		function drawGrid(me)
			Screen('DrawDots',me.win,me.grid,1,[1 0 1 1],[me.xCenter me.yCenter],1);
		end
		
		% ===================================================================
		%> @brief draw a square in top-left of screen to trigger photodiode
		%>
		%> @param colour colour of square
		%> @return
		% ===================================================================
		function drawPhotoDiodeSquare(me,colour)
			% drawPhotoDiodeSquare(me,colour)
			Screen('FillRect',me.win,colour,me.photoDiodeRect);
		end
		
		% ===================================================================
		%> @brief conditionally draw a white square to trigger photodiode
		%>
		%> @param colour colour of square
		%> @return
		% ===================================================================
		function drawPhotoDiode(me,colour)
			% drawPhotoDiode(me,colour)
			if me.photoDiode;Screen('FillRect',me.win,colour,me.photoDiodeRect);end
		end
		
		% ===================================================================
		%> @brief Draw the background colour
		%>
		%> @param
		%> @return
		% ===================================================================
		function drawBackground(me)
			Screen('FillRect',me.win,me.backgroundColour,[]);
		end
		
		
		% ===================================================================
		%> @brief Identify screens
		%>
		%> @param
		%> @return
		% ===================================================================
		function identifyScreens(me)
			screens = Screen('Screens');
			olds = Screen('Preference', 'SkipSyncTests', 2);
			PsychDefaultSetup(2)
			wins = [];
			a = 1;
			for i = screens
				wins(a) = PsychImaging('OpenWindow', i, 0.5, [0 0 100 100]);
				Screen('DrawText',wins(a),['W:' num2str(i)], 0, 0);
				Screen('Flip',wins(a));
				a = a + 1;
			end
			WaitSecs(2)
			for i = 1:length(wins)
				Screen('Close',wins(i));
			end
			Screen('Preference', 'SkipSyncTests', olds);
		end
		
		% ===================================================================
		%> @brief return mouse position in degrees
		%>
		%> @param
		% ===================================================================
		function [xPos, yPos] = mousePosition(me, verbose)
			if ~exist('verbose','var') || isempty(verbose); verbose = me.verbose; end
			if me.isOpen
				[xPos,yPos] = GetMouse(me.win);
			else
				[xPos,yPos] = GetMouse();
			end
			xPos = (xPos - me.xCenter) / me.ppd_;
			yPos = (yPos - me.yCenter) / me.ppd_;
			if verbose
				fprintf('--->>> MOUSE POSITION: \tX = %5.5g \t\tY = %5.5g\n',xPos,yPos);
			end
		end
		
		% ===================================================================
		%> @brief Check window handle is valid
		%>
		% ===================================================================
		function check = checkWindowValid(me)
			check = false;
			if me.isOpen && ~isempty(me.win)
				try
					Screen('WindowSize',me.win);
					check = true;
				catch
					fprintf('\n!!! Invalid Window handle, cleaning up...\n');
					me.isOpen = false;
					me.win = [];
					me.screenVals.win = [];
				end
			end
		end
		
		% ===================================================================
		%> @brief prepare the recording of stimulus frames
		%>
		%> @param
		%> @return
		% ===================================================================
		function prepareMovie(me)
			% Set up the movie settings
			if me.movieSettings.record == true
				me.movieSettings.outsize=CenterRect([0 0 me.movieSettings.size(1) me.movieSettings.size(2)],me.winRect);
				me.movieSettings.loop=1;
				if ismac || isunix
					oldp = cd('~');
					homep = pwd;
					cd(oldp);
				else
					homep = 'c:';
				end
				if ~exist([homep filesep 'MatlabFiles' filesep 'Movie' filesep],'dir')
					mkdir([homep filesep 'MatlabFiles' filesep 'Movie' filesep])
				end
				me.movieSettings.moviepath = [homep filesep 'MatlabFiles' filesep 'Movie' filesep];
				switch me.movieSettings.type
					case 1
						if isempty(me.movieSettings.codec)
							settings = sprintf(':CodecSettings= Profile=3 Keyframe=%g Videoquality=%g',...
								me.movieSettings.keyframe, me.movieSettings.quality);
						else
							settings = sprintf(':CodecType=%s Profile=3 Keyframe=%g Videoquality=%g',...
								me.movieSettings.codec, me.movieSettings.keyframe, me.movieSettings.quality);
						end
						me.movieSettings.movieFile = [me.movieSettings.moviepath 'Movie' datestr(now,'dd-mm-yyyy-HH-MM-SS') '.mov'];
						me.moviePtr = Screen('CreateMovie', me.win,...
							me.movieSettings.movieFile,...
							me.movieSettings.size(1), me.movieSettings.size(2),...
							me.movieSettings.fps, settings);
						fprintf('\n---> screenManager: Movie [enc:%s] [rect:%s] will be saved to:\n\t%s\n',settings,...
							num2str(me.movieSettings.outsize),me.movieSettings.movieFile);
					case 2
						me.movieMat = zeros(me.movieSettings.size(2),me.movieSettings.size(1),3,me.movieSettings.nFrames);
				end
			end
		end
		
		% ===================================================================
		%> @brief add current frame to recorded stimulus movie
		%>
		%> @param
		%> @return
		% ===================================================================
		function addMovieFrame(me)
			if me.movieSettings.record == true
				if me.movieSettings.loop <= me.movieSettings.nFrames
					switch me.movieSettings.type
						case 1
							Screen('AddFrameToMovie', me.win, me.movieSettings.outsize, 'frontBuffer', me.moviePtr);
						case 2
							me.movieMat(:,:,:,me.movieSettings.loop)=Screen('GetImage', me.win,...
								me.movieSettings.outsize, 'frontBuffer', me.movieSettings.quality, 3);
					end
					me.movieSettings.loop=me.movieSettings.loop+1;
				end
			end
		end
		
		% ===================================================================
		%> @brief finish stimulus recording
		%>
		%> @param
		%> @return
		% ===================================================================
		function finaliseMovie(me,wasError)
			if me.movieSettings.record == true
				switch me.movieSettings.type
					case 1
						if ~isempty(me.moviePtr)
							Screen('FinalizeMovie', me.moviePtr);
							fprintf(['\n---> screenManager: movie saved to ' me.movieSettings.movieFile '\n']);
						end
					case 2
% 						if wasError == true
% 							
% 						else
% 							save([me.movieSettings.moviepath 'Movie' datestr(clock) '.mat'],'mimg');
% 						end
				end
			end
			me.moviePtr = [];
			me.movieMat = [];
		end
		
		% ===================================================================
		%> @brief play back the recorded stimulus
		%>
		%> @param
		%> @return
		% ===================================================================
		function playMovie(me)
			if me.movieSettings.record == true  && me.movieSettings.type == 2 && exist('implay','file') && ~isempty(me.movieSettings.movieFile)
				try %#ok<TRYNC>
					mimg = load(me.movieSettings.movieFile);
					implay(mimg);
					clear mimg
				end
			end
		end
		
		% ===================================================================
		%> @brief Delete method
		%>
		% ===================================================================
		function delete(me)
			if me.isOpen
				me.close();
				me.salutation('DELETE method','Screen closed');
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
		function setScreenSize(me)
			%get screen dimensions
			if ~isempty(me.win)
				swin = me.win;
			else
				swin = me.screen;
			end
			[me.screenVals.width, me.screenVals.height] = Screen('WindowSize',swin);
			me.winRect = Screen('Rect',swin);
			updateCenter(me);
		end
		
		% ===================================================================
		%> @brief Makes a 15x15 1deg dot grid for debug mode
		%> This is always updated on setting distance or pixelsPerCm
		% ===================================================================
		function makeGrid(me)
			me.grid = [];
			rnge = -15:15;
			for i=rnge
				me.grid = horzcat(me.grid, [rnge;ones(1,length(rnge))*i]);
			end
			me.grid = me.grid .* me.ppd;
		end
		
		% ===================================================================
		%> @brief update our screen centre to use any offsets we've defined
		%>
		%> @param
		% ===================================================================
		function updateCenter(me)
			if length(me.winRect) == 4
				%get the center of our screen, along with user defined offsets
				[me.xCenter, me.yCenter] = RectCenter(me.winRect);
				me.xCenter = me.xCenter + (me.screenXOffset * me.ppd_);
				me.yCenter = me.yCenter + (me.screenYOffset * me.ppd_);
			end
		end
		
	end
	
end


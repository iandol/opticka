% ========================================================================
%> @class screenManager
%> @brief screenManager — manage opening and configuring the PTB screen
%>
%> screenManager manages the (many!) PTB screen settings. You can set many
%> properties of this class to control PTB screens, and use it to open and
%> close the screen based on those properties. This class controls the
%> transformation from degrees into pixels, and it can offset the screen
%> co-ordinates (i.e. you can set a global X and Y position offset, to a
%> screen position and then all other positions will be relative to this
%> global screen center). By setting `bitDepth` you can enable Display++,
%> DataPixx, HDR and high bit-depth display modes. This class also manages
%> movie recording of the screen buffer. Finally it wraps some generic
%> drawing commands like grids, text, spots or other basic things that would
%> be overkill for aa dedicated stimulus class.
%>
%> Copyright ©2014-2024 Ian Max Andolina — released: LGPL3, see LICENCE.md
% ========================================================================
classdef screenManager < optickaCore

	properties
		%> the display to use, 0 is the main display on macOS/Linux
		%> default value will be set to `max(Screen('Screens'))`
		screen double {mustBeInteger}
		%> Pixels Per Centimeter — used for calculating the number of pixels
		%> per visual degree (ppd). Use the calibrateSize.m function to
		%> measure this value accurately for each monitor you will use.
		%> Examples: MBP 1440x900 is 33.2x20.6cm so 44px/cm; Flexscan is
		%> 32px/cm @1280 26px/cm @ 1024; Display++ is 27px/cm @1920x1080
		pixelsPerCm(1,1) double				= 36
		%> distance in centimeters of subject from Display
		%> rad2ang(2 * atan( size / (2 * distance) ) ) = Xdeg
		%> when size == 1cm & distance == 57.3cm; X == 1deg
		distance(1,1) double				= 57.3
		%> windowed: when FALSE use fullscreen; set to TRUE and it is
		%> windowed 800x600pixels or you can add in a window width and
		%> height i.e. [800 600] to specify windowed size. Remember that
		%> windowed presentation should *never* be used for real
		%> experimental presentation due to poor timing…
		windowed							= false
		%> stereo mode
		stereoMode(1,1) double				= 0
		%> enable debug for poorer temporal fidelity but no sync testing
		%> etc.
		debug(1,1) logical					= false
		%> shows some info text and position grid during stimulus
		%> presentation if true
		visualDebug(1,1) logical			= false
		%> normally should be left at 1 (1 is added to this number so
		%> doublebuffering is enabled)
		doubleBuffer(1,1) uint8				= 1
		%> Mirror the content to a second window. In this case we need a
		%> screen 0 and screen 1 and the main output to screen 1. We will get
		%> an overlay window for this too we can draw to.
		mirrorDisplay(1,1) logical			= false
		%> float precision and bitDepth of framebuffer/output: '8bit' is
		%> best for old GPUs, but choose 'FloatingPoint32BitIfPossible' for
		%> newer GPUs. Native high bitdepths (assumes FloatingPoint32Bit
		%> internal processing): 'PseudoGray', 'HDR', 'Native10Bit',
		%> 'Native11Bit', 'Native16Bit', 'Native16BitFloat' Options to
		%> enable Display++ or VPixx modes: 'EnableBits++Bits++Output',
		%> 'EnableBits++Mono++Output', 'EnableBits++Mono++OutputWithOverlay'
		%> or 'EnableBits++Color++Output' 'EnableDataPixxM16Output',
		%> 'EnableDataPixxC48Output'
		bitDepth char {mustBeMember(bitDepth,{'FloatingPoint32BitIfPossible';...
			'FloatingPoint32Bit'; '8bit'; 'HDR'; 'PseudoGray'; 'Native10Bit';...
			'Native11Bit'; 'Native16Bit'; 'Native16BitFloat';...
			'EnableNative10BitFrameBuffer'; 'EnableNative11BitFrameBuffer';...
			'EnableNative16BitFrameBuffer'; 'FixedPoint16Bit'; 'FloatingPoint16Bit';...
			'Bits++Bits++'; 'Bits++Mono++'; 'Bits++Color++';...
			'Bits++Bits++Output'; 'Bits++Mono++Output'; 'Bits++Color++Output';...
			'EnableBits++Bits++Output'; 'EnableBits++Color++Output';...
			'EnableBits++Mono++Output';'EnableBits++Mono++OutputWithOverlay';...
			'EnableDataPixxM16Output';...
			'EnableDataPixxC48Output'})} = '8bit'
		%> timestamping mode 1=beamposition,kernel fallback | 2=beamposition
		%> crossvalidate with kernel
		timestampingMode double				= 1
		%> multisampling sent to the graphics card, try values 0[disabled], 4, 8
		%> and 16 -- useful for textures to minimise aliasing, but this does
		%> provide extra work for the GPU
		antiAlias(1,1) double 				= 0
		%> background RGBA of display during stimulus presentation
		backgroundColour(1,:) double		= [0.5 0.5 0.5 1.0]
		%> use OpenGL blending mode
		blend logical						= true
		%> OpenGL blending source mode
		srcMode char {mustBeMember(srcMode,{'GL_ZERO'; 'GL_ONE';...
		'GL_DST_COLOR'; 'GL_ONE_MINUS_DST_COLOR';...
		'GL_SRC_ALPHA'; 'GL_ONE_MINUS_SRC_ALPHA'; 'GL_DST_ALPHA';...
		'GL_ONE_MINUS_DST_ALPHA'; 'GL_SRC_ALPHA_SATURATE' })} = 'GL_SRC_ALPHA'
		%> OpenGL blending dst mode
		dstMode char {mustBeMember(dstMode,{'GL_ZERO'; 'GL_ONE';...
		'GL_DST_COLOR'; 'GL_ONE_MINUS_DST_COLOR';...
		'GL_SRC_ALPHA'; 'GL_ONE_MINUS_SRC_ALPHA'; 'GL_DST_ALPHA';...
		'GL_ONE_MINUS_DST_ALPHA'; 'GL_SRC_ALPHA_SATURATE' })} = 'GL_ONE_MINUS_SRC_ALPHA'
		%> shunt center by X degrees (coordinates are in degrees from centre of
		%> monitor)
		screenXOffset(1,1) double			= 0
		%> shunt center by Y degrees (coordinates are in degrees from centre of
		%> monitor)
		screenYOffset(1,1) double			= 0
		%> gamma correction info saved as a calibrateLuminance object
		gammaTable calibrateLuminance
		%> settings for movie output
		%> type 1 = video file, 2 = mat array, 3 = single pictures
		movieSettings						= struct('record',false,'type',1,'loop',inf,...
											'size',[],'fps',[],'quality',0.7,...
											'channels',3,'keyframe',5,'nFrames', inf,...
											'prefix','Movie','codec','x264enc')
		%> populated on window open; useful screen info, initial gamma tables 
		%> and the like
		screenVals struct					= struct('ifi',1/60,'fps',60,...
											'winRect',[0 0 1920 1080])
		%> verbose output?
		verbose								= false
		%> level of PTB verbosity, set to 10 for full PTB logging
		verbosityLevel double				= 3
		%> Use retina resolution natively (worse performance but double
		%> resolution)
		useRetina logical					= false
		%> Screen To Head Mapping, a Nx3 vector: Screen('Preference',
		%> 'ScreenToHead', screen, head, crtc); Each N should be a different
		%> display
		screenToHead						= []
		%> force framerate for Display++ (120Hz or 100Hz, empty uses the default
		%> OS setup)
		displayPPRefresh double				= []
		%> hide the black flash as PTB tests its refresh timing, uses a gamma
		%> trick from Mario
		hideFlash logical					= false
		%> Details for drawing fonts, either sets defaults if window is closed or
		%> or updates values if window open...
		font struct							= struct('TextSize',16,...
											'TextColor',[0.95 0.95 0.95 1],...
											'TextBackgroundColor',[0.2 0.3 0.3 0.8],...
											'TextRenderer', 1,...
											'FontName', 'Source Sans 3');
	end

	properties (SetAccess = private, GetAccess = public, Dependent = true)
		%> dependent Pixels Per Degree property; calculated from distance and
		%> pixelsPerCm.
		%> pixelsPerDegree = pixelsPerCm  ×  (distance ÷ 57.3)
		ppd
	end

	properties (Constant)
		%> possible bitDepth or display modes
		bitDepths cell = {'FloatingPoint32BitIfPossible'; 'FloatingPoint32Bit'; '8bit';...
			'HDR'; 'PseudoGray'; 'Native10Bit'; 'Native11Bit'; 'Native16Bit'; 'Native16BitFloat';...
			'EnableNative10BitFrameBuffer'; 'EnableNative11BitFrameBuffer';...
			'EnableNative16BitFrameBuffer'; 'FixedPoint16Bit'; 'FloatingPoint16Bit';...
			'Bits++Bits++'; 'Bits++Mono++'; 'Bits++Color++';...
			'Bits++Bits++Output'; 'Bits++Mono++Output'; 'Bits++Color++Output';...
			'EnableBits++Bits++Output'; 'EnableBits++Color++Output';...
			'EnableBits++Mono++Output';'EnableBits++Mono++OutputWithOverlay';...
			'EnableDataPixxM16Output';'EnableDataPixxC48Output'}
		%> possible OpenGL blend modes (src or dst)
		blendModes cell = {'GL_ZERO'; 'GL_ONE'; 'GL_DST_COLOR'; 'GL_ONE_MINUS_DST_COLOR';...
			'GL_SRC_ALPHA'; 'GL_ONE_MINUS_SRC_ALPHA'; 'GL_DST_ALPHA';...
			'GL_ONE_MINUS_DST_ALPHA'; 'GL_SRC_ALPHA_SATURATE' }
	end

	properties (Hidden = true)
		%> anaglyph channel gains
		anaglyphLeft						= [];
		anaglyphRight						= [];
		%> The mode to use for color++ mode
		colorMode							= 2
		%> for some development macOS and windows machines we have to disable
		%> sync tests, but we hide this as we should remember this is for
		%> development ONLY!
		disableSyncTests logical			= false
		%> The acceptable variance in flip timing tests performed when
		%> screen opens, set with Screen('Preference', 'SyncTestSettings',
		%> syncVariance) AMD cards under Ubuntu are very low variance, PTB
		%> default is 2e-04. DO NOT change this unless you know what you are
		%> doing.
		syncVariance double					= 2e-04
		%> overlay window if mirrorDisplay was enabled
		overlayWin							= -1
		%> e.g. kPsychGUIWindow
		specialFlags						= []
		%> try to enable vulkan?
		useVulkan							= false
	end
	
	properties (SetAccess = private, GetAccess = public)
		%> do we have a working PTB, if not go into a silent mode
		isPTB logical						= false
		%> is a window currently open?
		isOpen logical						= false
		%> did we ask for a bitsPlusPlus mode?
		isPlusPlus logical					= false
		%> the handle returned by opening a PTB window
		win
		%> the window rectangle
		winRect
		%> computed X center
		xCenter double						= 0
		%> computed Y center
		yCenter double						= 0
		%> set automatically on construction
		maxScreen
	end

	properties (Access = private)
		%> we cache ppd as it is used frequently
		ppd_ double
		%> properties allowed to be modified during construction
		allowedProperties = {'colorMode','overlayWin','specialFlags','syncVariance',...
			'disableSyncTests','displayPPRefresh','screenToHead','gammaTable',...
			'useRetina','bitDepth','pixelsPerCm','distance','screen','windowed','backgroundColour',...
			'screenXOffset','screenYOffset','blend','srcMode','dstMode','antiAlias',...
			'debug','photoDiode','verbose','hideFlash',...
			'stereoMode','anaglyphLeft','anaglyphRight'}
		%> the photoDiode rectangle in pixel values
		photoDiodeRect(1,4) double			= [0, 0, 45, 45]
		%> colour of the grid dots
		gridColour							= [0 0 0 1]
		%> the values computed to draw the 1deg dotted grid in visualDebug mode
		grid
		%> the movie pointer
		moviePtr							= []
		%> movie mat structure
		movieMat							= []
		%screen flash logic
		flashInterval						= 20
		flashTick							= 0
		flashOn								= 1
		% timed spot logic
		timedSpotTime						= 0
		timedSpotTick						= 0
		timedSpotNextTick					= 0
		% async flip management
		isInAsync							= false
	end

	methods
		% ===================================================================
		function me = screenManager(varargin)
		%> @fn me = screenManager(varargin)
		%>
		%> screenManager CONSTRUCTOR
		%>
		%> @param varargin can be simple name value pairs, a structure or cell array
		%> @return instance of the class.
		% ===================================================================
			args = optickaCore.addDefaults(varargin,struct('name','screenManager'));
			me=me@optickaCore(args); %superclass constructor
			me.parseArgs(args,me.allowedProperties); %check remaining properties from varargin
			try
				AssertOpenGL;
				me.isPTB = true;
				salutation(me,'PTB + OpenGL supported!')
			catch %#ok<*CTCH>
				me.isPTB = false;
				salutation(me,'CONSTRUCTOR','OpenGL support needed for PTB!!!',true)
			end

			me.font.FontName = me.monoFont;

			prepareScreen(me);
		end

		% ===================================================================
		function screenVals = prepareScreen(me)
		%> @fn prepareScreen
		%>
		%> prepare the initial Screen values on the local machine
		%>
		%> @return screenVals structure of screen values
		% ===================================================================
			if me.isPTB == false; warning('No PTB!!!'); return; end
			me.maxScreen		= max(Screen('Screens'));

			%by default choose the (largest number) screen
			if isempty(me.screen) || me.screen > me.maxScreen
				me.screen		= me.maxScreen;
			end

			sv					= struct();

			checkWindowValid(me);

			%get the gammatable and dac information
			sv.resetGamma		= false;
			try
				[sv.originalGamma, sv.dacBits, sv.lutSize]=Screen('ReadNormalizedGammaTable', me.screen);
				sv.linearGamma  = repmat(linspace(0,1,sv.lutSize)',1,3);
				sv.gammaTable	= sv.originalGamma;
			catch
				sv.gammaTable	= [];
				sv.dacBits		= [];
				if IsWin
					sv.lutSize	= 256;
				else
					sv.lutSize	= 1024;
				end
			end

			%get screen dimensions
			sv					= setScreenSize(me, sv);

			%this is just a rough initial setting, it will be recalculated when we
			%open the screen before showing stimuli.
			sv.fps=Screen('FrameRate',me.screen);
			if sv.fps == 0 || (sv.fps == 59 && IsWin)
				sv.fps = 60;
			end
			sv.ifi				= 1/sv.fps;

			me.movieSettings.fps = sv.fps;

			if me.debug == true %we yoke these together but they can then be overridden
				me.visualDebug	= true;
			end
			if ismac
				me.disableSyncTests = true;
			end

			me.ppd; %generate our dependent propertie and caches it to ppd_ for speed
			me.makeGrid; %our visualDebug size grid
			if mean(me.backgroundColour) > 0.5
				me.gridColour = [0.0 0 0.2];
			else
				me.gridColour = [0.7 1 0.7];
			end

			sv.white			= WhiteIndex(me.screen);
			sv.black			= BlackIndex(me.screen);
			sv.gray				= GrayIndex(me.screen);

			try sv.isVulkan			= PsychVulkan('Supported'); end

			if IsLinux
				try
					sv.display	= Screen('ConfigureDisplay','Scanout',me.screen,0);
					sv.name		= sv.display.name;
					sv.widthMM	= sv.display.displayWidthMM;
					sv.heightMM	= sv.display.displayHeightMM;
				end
			end

			me.screenVals		= sv;
			screenVals			= sv;

		end

		% ===================================================================
		function sv = open(me,debug,tL,forceScreen)
		%> @fn open
		%> @brief open a screen with object defined settings
		%>
		%> @param debug, whether we show debug status, called from runExperiment
		%> @param tL timeLog object to add timing info on screen construction
		%> @param forceScreen force a particular screen number to open
		%> @return sv structure of basic info from the opened screen
		% ===================================================================
			if me.isOpen; fprintf('===>>> screenManager.open(): Screen already open!');return; end
			if me.isPTB == false
				warning('No PTB found!');
				sv = me.screenVals;
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

			sv = me.screenVals;

			try
				PsychDefaultSetup(2);
				sv.resetGamma = false;

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
					Screen('Preference','SyncTestSettings', 0.002); %up to 2ms variability
					Screen('Preference', 'SkipSyncTests', 2);
					Screen('Preference', 'VisualDebugLevel', 0);
					Screen('Preference', 'Verbosity', me.verbosityLevel);
					Screen('Preference', 'SuppressAllWarnings', 0);
				else
					if me.disableSyncTests
						fprintf('\n---> screenManager: Sync Tests OVERRIDDEN, do not use for real experiments!!!\n');
						warning('---> screenManager: Sync Tests OVERRIDDEN, do not use for real experiments!!!')
						Screen('Preference', 'SkipSyncTests', 2);
					else
						fprintf('\n---> screenManager: Normal Screen Preferences used.\n');
						Screen('Preference', 'SkipSyncTests', 0);
					end
					Screen('Preference','SyncTestSettings', me.syncVariance); %set acceptable variability
					Screen('Preference', 'VisualDebugLevel', 3);
					Screen('Preference', 'Verbosity', me.verbosityLevel); %errors and warnings
					Screen('Preference', 'SuppressAllWarnings', 0);
				end

				tL.screenLog.preOpenWindow=GetSecs;

				%=== check if system supports HDR mode
				isHDR = logical(PsychHDR('Supported'));
				if strcmp(me.bitDepth,'HDR') && ~isHDR
					me.bitDepth = 'Native10Bit';
					error('---> screenManager: tried to use HDR but it is not supported!\n');
				end

				%=== check stereomode is anaglyph
				if ismember(me.stereoMode, 6:9)
					stereo = me.stereoMode;
				elseif me.stereoMode > 0
					warning('Only Anaglyph stereo supported at present...')
					stereo = 0;
				else
					stereo = 0;
				end

				%=== start to set up PTB screen
				PsychImaging('PrepareConfiguration');
				PsychImaging('AddTask', 'General', 'UseFastOffscreenWindows');
				if me.useVulkan
					if ~me.screenVals.isVulkan; fprintf('---> screenManager: Probing for Vulkan failed...\n'); end
					try
						PsychImaging('AddTask', 'General', 'UseVulkanDisplay');
						fprintf('---> screenManager: Vulkan appears to be activated...\n');
					catch
						warning('Vulkan failed to be initialised...')
					end
				end
				me.isPlusPlus = screenManager.bitsCheckOpen();
				fprintf('---> screenManager: Probing for a Display++...');
				bD = me.bitDepth;
				normalMode = true;
				if ~me.isPlusPlus && contains(bD, 'Bits++')
					error('---> screenManager: You specified a Bits++ colour mode but cannot connect to the Display++!');
				end
				if me.isPlusPlus
					fprintf('\tFound Display++ ');
					if contains(bD, 'Bits++')
						normalMode = false;
						if isempty(regexpi(bD, '^Enable','ONCE')); bD = ['Enable' bD]; end
						if isempty(regexpi(bD, 'Output$','ONCE')); bD = [bD 'Output']; end
						fprintf('-> mode: %s\n', bD);
						PsychImaging('AddTask', 'FinalFormatting', 'DisplayColorCorrection', 'ClampOnly');
						if contains(me.bitDepth, 'Color')
							PsychImaging('AddTask', 'General', bD, me.colorMode);
						else
							PsychImaging('AddTask', 'General', bD);
						end
					else
						warning('---> screenManager: You are connected to a Display++ but not using a Bits++ mode...');
					end
				else
					fprintf('\tNO Display++\n');
				end
				if normalMode
					switch lower(bD)
						case {'hdr','enablehdr'}
							PsychImaging('AddTask', 'General', 'FloatingPoint32BitIfPossible');
							PsychImaging('AddTask', 'General', 'EnableHDR');
						case {'native10bit','native11bit','native16bit'}
							if isempty(regexpi(bD, '^Enable','ONCE')); bD = ['Enable' bD]; end
							if isempty(regexpi(bD, 'Framebuffer$','ONCE')); bD = [bD 'Framebuffer']; end
							PsychImaging('AddTask', 'General', 'FloatingPoint32BitIfPossible');
							PsychImaging('AddTask', 'General', bD);
							fprintf('---> screenManager: 32-bit internal / %s Output bit-depth\n', bD);
						case {'native16bitfloat'}
							PsychImaging('AddTask', 'General', 'FloatingPoint32BitIfPossible');
							PsychImaging('AddTask', 'General', ['Enable' bD 'ingPointFramebuffer']);
							fprintf('---> screenManager: 32-bit internal / %s Output bit-depth\n', bD);
						case {'pseudogray','enablepseudograyoutput'}
							PsychImaging('AddTask', 'General', 'FloatingPoint32BitIfPossible');
							PsychImaging('AddTask', 'General', 'EnablePseudoGrayOutput');
							fprintf('---> screenManager: Internal processing set to: %s\n', 'PseudoGrayOutput');
						case {'floatingpoint32bitifpossible','floatingpoint32bit'}
							PsychImaging('AddTask', 'General', bD);
							fprintf('---> screenManager: Internal processing set to: %s\n', bD);
						case {'8bit'}
							PsychImaging('AddTask', 'General', 'UseVirtualFramebuffer');
							fprintf('---> screenManager: Internal processing set to: %s\n', '8 bits');
						otherwise
							fprintf('---> screenManager: No imaging pipeline requested...\n');
					end
				end

				if me.useRetina
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

				%===deal with windowed or full-screen
				if isempty(me.windowed); me.windowed = false; end
				if ~isempty(forceScreen)
					thisScreen = forceScreen;
				else
					thisScreen = me.screen;
				end
				if me.windowed == false %full-screen
					winSize = [];
					sf = me.specialFlags;
				else %windowed
					if length(me.windowed) == 2
						winSize = [0 0 me.windowed(1) me.windowed(2)];
					elseif length(me.windowed) == 4
						winSize = me.windowed;
					else
						winSize=[0 0 800 800];
					end
					if isempty(me.specialFlags)
						sf = kPsychGUIWindow;
					else
						sf = me.specialFlags;
					end
				end

				if thisScreen > 0 && me.mirrorDisplay
					PsychImaging('AddTask', 'General', 'MirrorDisplayTo2ndOutputHead', ...
						0, [0 0 900 600], [], 1);
				end

				% ==============================================================
				[me.win, me.winRect] = PsychImaging('OpenWindow', thisScreen, ...
					me.backgroundColour, winSize, [], me.doubleBuffer+1, stereo, ...
					me.antiAlias, [], sf);
				me.isOpen = true;
				% ==============================================================

				if thisScreen > 0 && me.mirrorDisplay
					me.overlayWin = PsychImaging('GetMirrorOverlayWindow', me.win);
					sv.mirror = true;
					sv.overlayWin = me.overlayWin;
				else
					sv.mirror = false;
					sv.overlayWin= [];
				end

				%===ANAGLYPH VALUES
				if stereo > 0 && ~isempty(me.anaglyphLeft) && ~isempty(me.anaglyphRight)
					SetAnaglyphStereoParameters('LeftGains', me.win,  me.anaglyphLeft);
    				SetAnaglyphStereoParameters('RightGains', me.win, me.anaglyphRight);
				elseif stereo > 0
					switch stereo
						case 6
    						SetAnaglyphStereoParameters('LeftGains', me.win,  [1.0 0.0 0.0]);
    						SetAnaglyphStereoParameters('RightGains', me.win, [0.0 0.6 0.0]);
						case 7
    						SetAnaglyphStereoParameters('LeftGains', me.win,  [0.0 0.6 0.0]);
    						SetAnaglyphStereoParameters('RightGains', me.win, [1.0 0.0 0.0]);
						case 8
    						SetAnaglyphStereoParameters('LeftGains', me.win, [0.4 0.0 0.0]);
    						SetAnaglyphStereoParameters('RightGains', me.win, [0.0 0.2 0.7]);
						case 9
    						SetAnaglyphStereoParameters('LeftGains', me.win, [0.0 0.2 0.7]);
    						SetAnaglyphStereoParameters('RightGains', me.win, [0.4 0.0 0.0]);
					end
				end

				sv.win			= me.win; % make a copy
				sv.winRect		= me.winRect;
				sv.useRetina	= me.useRetina;
				sv				= setScreenSize(me, sv);

				if me.verbose; fprintf('===>>>Made win: %i kind: %i\n',me.win,Screen(me.win,'WindowKind')); end

				tL.screenLog.postOpenWindow=GetSecs;
				tL.screenLog.deltaOpenWindow=(tL.screenLog.postOpenWindow-tL.screenLog.preOpenWindow);

				%===check we have GLSL
				try
					AssertGLSL;
				catch
					close(me);
					error('GLSL Shading support is required for octicka!');
				end

				% get HDR properties
				if strcmpi(me.bitDepth,'HDR') && isHDR
					sv.hdrProperties = PsychHDR('GetHDRProperties', me.win);
					if IsWin; oldDim = PsychHDR('HDRLocalDimming', me.win, 0); end
				else
					sv.hdrProperties = [];
				end

				%===Linux can give us some more information
				if IsLinux && ~isHDR && ~me.useVulkan
					try
						d			= Screen('ConfigureDisplay','Scanout',me.screen,0);
						sv.name		= d.name;
						sv.widthMM	= d.displayWidthMM;
						sv.heightMM = d.displayHeightMM;
						sv.display	= d;
					end
				end

				%===get timing info
				sv.ifi			= Screen('GetFlipInterval', me.win);
				sv.fps			= Screen('NominalFramerate', me.win);
				% find our fps if not defined above
				if sv.fps == 0
					sv.fps=round(1/sv.ifi);
					if sv.fps == 0 || (sv.fps == 59 && IsWin)
						sv.fps = 60;
					end
				elseif sv.fps == 59 && IsWin
					sv.fps = 60;
					sv.ifi = 1 / 60;
				end

				if me.windowed == false % full-screen
					sv.halfifi = sv.ifi/2; sv.halfisi = sv.halfifi;
				else
					% windowed presentation doesn't handle the preferred method
					% of specifying lastvbl+halfifi properly so we set halfifi to 0 which
					% effectively makes flip occur ASAP.
					sv.halfifi = 0; sv.halfisi = 0;
				end

				%===configure photodiode to top right
				if me.useRetina
					me.photoDiodeRect = [me.winRect(3)-90 0 me.winRect(3) 90];
				else
					me.photoDiodeRect = [me.winRect(3)-45 0 me.winRect(3) 45];
				end
				sv.photoDiodeRect = me.photoDiodeRect;

				%===get gamma table and info
				try
					[sv.originalGamma, sv.dacBits, sv.lutSize]=Screen('ReadNormalizedGammaTable', me.win);
				catch
					sv.originalGamma = [];
					sv.dacBits = 0;
					sv.lutSize = 0;
				end
				sv.linearGamma  = repmat(linspace(0,1,sv.lutSize)',1,3);
				sv.gammaTable	= sv.originalGamma;

				if me.hideFlash == true && isempty(me.gammaTable) && sv.lutSize > 0
					Screen('LoadNormalizedGammaTable', me.screen, sv.linearGamma);
					sv.gammaTable = sv.linearGamma;
					sv.resetGamma = false;
				elseif ~isempty(me.gammaTable) && ~isempty(me.gammaTable.gammaTable) && (me.gammaTable.choice > 0)
					choice = me.gammaTable.choice;
					sv.resetGamma = true;
					if size(me.gammaTable.gammaTable,2) > 1
						if isprop(me.gammaTable,'finalCLUT') && ~isempty(me.gammaTable.finalCLUT)
							gTmp = me.gammaTable.finalCLUT;
						else
							gTmp = [me.gammaTable.gammaTable{choice,2:4}];
						end
					else
						if isprop(me.gammaTable,'finalCLUT') && ~isempty(me.gammaTable.finalCLUT)
							gTmp = me.gammaTable.finalCLUT;
						else
							gTmp = repmat(me.gammaTable.gammaTable{choice,1},1,3);
						end
					end
					sv.gammaTable = gTmp;
					[sv.oldCLUT, success] = Screen('LoadNormalizedGammaTable', me.win, sv.gammaTable);
					if success < 1;error('Cannot load gamma table!!!');end
					fprintf('\n---> screenManager: SET GAMMA CORRECTION using: %s\n', me.gammaTable.modelFit{choice}.method);
					if isprop(me.gammaTable,'correctColour') && me.gammaTable.correctColour == true
						fprintf('---> screenManager: GAMMA CORRECTION used independent R, G & B Correction \n');
					end
				else
					sv.linearGamma = repmat(linspace(0,1,sv.lutSize)',1,3);
					%Screen('LoadNormalizedGammaTable', me.screen, sv.linearGamma);
					%sv.oldCLUT = LoadIdentityClut(me.win);
					sv.resetGamma = false;
				end

				% Enable alpha blending.
				sv.blending = false;
				sv.newSrc = me.srcMode;
				sv.newDst = me.dstMode;
				sv.srcdst = [me.srcMode '|' me.dstMode];
				if me.blend==1
					sv.blending = true;
					[sv.oldSrc,sv.oldDst,sv.oldMask]...
						= Screen('BlendFunction', me.win, me.srcMode, me.dstMode);
					fprintf('\n---> screenManager: Previous OpenGL blending: %s | %s\n', sv.oldSrc, sv.oldDst);
					fprintf('---> screenManager: OpenGL blending now: %s | %s\n', me.srcMode, me.dstMode);
				else
					[sv.oldSrc,sv.oldDst,sv.oldMask] = Screen('BlendFunction', me.win);
				end

				% set up text defaults
				updateFontValues(me);

				sv.ppd = me.ppd; %generate our dependent propertie and caches it to ppd_ for speed
				me.makeGrid; %our visualDebug size grid
				if mean(me.backgroundColour(1:3)) > 0.6
					me.gridColour = [0 0 0.2];
				else
					me.gridColour = [1 1 0.8];
				end

				if me.movieSettings.record
					prepareMovie(me);
				end

				sv.white = WhiteIndex(me.screen);
				sv.black = BlackIndex(me.screen);
				sv.gray = GrayIndex(me.screen);

				me.screenVals = sv;
			catch ME
				getReport(ME);
				close(me);
				Priority(0);
				prepareScreen(me);
				rethrow(ME);
			end

		end

		function switchChannel(me, channel)
			persistent thisChannel
			if me.isOpen
				if ~exist('channel','var'); channel = ~thisChannel;end
				thisChannel = channel;
				Screen('SelectStereoDrawBuffer', me.win, thisChannel);
			end
		end


		% ===================================================================
		function demo(me)
		%> @fn demo
		%> @brief Small demo of screen opening, drawing, closing
		%>
		% ===================================================================
			if ~me.isOpen
				stim = dotsStimulus('mask',true,'size',10,'speed',2,...
					'density',3,'dotSize',0.3);
				open(me);
				disp('--->>> screenManager running a quick demo...');
				if me.stereoMode > 0
					stim.mask = false;
					stim.type='simple';
					drawBackground(me,[0 0 0]);
					flip(me);
					WaitSecs(0.5);
				end
				disp(me.screenVals);
				setup(stim, me);
				x = stim.xFinal;
				td = me.screenVals.topInDegrees;
				bd = me.screenVals.bottomInDegrees;
				ld = me.screenVals.leftInDegrees;
				vbl = flip(me);
				for i = 1:me.screenVals.fps*6
					if me.stereoMode > 0
						drawBackground(me,[0 0 0]);
						stim.xFinal = x - 3;
						switchChannel(me,0);
						drawText(me,'Demo screenManager Left Channel...',ld+1,td+1);
						draw(stim);
						switchChannel(me,1);
						stim.xFinal = x + 3;
						drawText(me,'Demo screenManager Right...',ld+1,td+2);
						draw(stim);
					else
						drawText(me,'Running a quick demo of screenManager...');
						draw(stim);
					end
					finishDrawing(me);
					animate(stim);
					vbl = flip(me, vbl);
					if i == 1;KbWait;end
				end
				WaitSecs(1);
				clear stim;
				close(me);
			end
		end

		% ===================================================================
		function [vbl, when, flipTime, missed] = flip(me, varargin)
		%> @fn flip
		%> @brief Flip the screen
		%>
		%> [VBLTimestamp StimulusOnsetTime FlipTimestamp Missed Beampos] = 
		%>   Screen('Flip', me.win [, when] [, dontclear] [, dontsync] [, multiflip]);
		%>
		%> @param varargin - pass other options to screen flip
		%> @return vbl - a vbl from this flip
		% ===================================================================
			if ~me.isOpen; return; end
			[vbl, when, flipTime, missed] = Screen('Flip',me.win,varargin{:});
			if me.movieSettings.record; addMovieFrame(me); end
		end

		% ===================================================================
		function vbl = asyncFlip(me, when, varargin)
		%> @fn asyncFlip
		%> @brief Flip the screen asynchrounously
		%>
		%> @param when - when to flip
		%> @return vbl - a vbl from this flip
		% ===================================================================
			if ~me.isOpen; return; end
			if me.isInAsync
				vbl = Screen('AsyncFlipCheckEnd', me.win);
				if vbl == 0; return; end
			end
			if exist('when','var')
				vbl = Screen('AsyncFlipBegin',me.win, when, varargin{:});
			else
				vbl = Screen('AsyncFlipBegin',me.win);
			end
			me.isInAsync = true;
		end

		% ===================================================================
		function result = asyncCheck(me)
		%> @fn asyncCheck
		%> @brief Check async state?
		%>
		%> @return result - is in async state?
		% ===================================================================
			if ~me.isOpen; return; end
			result = false;
			if me.isInAsync
				vbl = Screen('AsyncFlipCheckEnd', me.win);
				if vbl == 0
					result = true;
				else
					me.isInAsync = false;
				end
			end
		end

		% ===================================================================
		function vbl = asyncEnd(me)
		%> @fn asyncEnd
		%> @brief end async state
		%>
		%>
		%> @return vbl - return time
		% ===================================================================
			if ~me.isOpen; return; end
			vbl = 0;
			if me.isInAsync
				vbl = Screen('AsyncFlipEnd', me.win);
				me.isInAsync = false;
			end
		end

		% ===================================================================
		function forceWin(me,win)
		%> @fn forceWin
		%> @brief force this object to use an existing window handle
		%>
		%> @param win - the window handle to bind to
		%> @return
		% ===================================================================
			me.win = win;
			me.isOpen = true;
			me.isPTB = true;
			me.screenVals.ifi = Screen('GetFlipInterval', me.win);
			me.screenVals.white = WhiteIndex(me.win);
			me.screenVals.black = BlackIndex(me.win);
			me.screenVals.gray = GrayIndex(me.win);
			me.screenVals = setScreenSize(me, me.screenVals);
			fprintf('---> screenManager slaved to external win: %i\n',win);
		end

		% ===================================================================
		function hideScreenFlash(me)
		%> @fn hideScreenFlash
		%> @brief This is the trick Mario told us to "hide" the colour changes
		%> as PTB starts -- we could use backgroundcolour here to be even better
		%>
		%> @param
		%> @return
		% ===================================================================
			% This is the trick Mario told us to "hide" the colour changes as PTB
			% intialises -- we could use backgroundcolour here to be even better
			if me.hideFlash == true && all(me.windowed == false)
				if ~isempty(me.gammaTable) && isa(me.gammaTable,'calibrateLuminance') && (me.gammaTable.choice > 0)
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
		function close(me)
		%> @fn close
		%> @brief close the screen when finished or on error
		%>
		%> @param
		%> @return
		% ===================================================================
			if ~me.isPTB; return; end
			try Priority(0); end
			try ListenChar(0); end
			ShowCursor;
			if me.screenVals.resetGamma && isfield(me.screenVals,'originalGamma') && ~isempty(me.screenVals.originalGamma)
				Screen('LoadNormalizedGammaTable', me.win, me.screenVals.originalGamma);
				fprintf('\n---> screenManager: REVERT GAMMA TABLES\n');
			end
			if me.isInAsync
				try Screen('ASyncFlipEnd',me.win); end
			end
			if me.movieSettings.record
				finaliseMovie(me);
			end
			me.isInAsync = false;
			if me.isPlusPlus
				try BitsPlusPlus('Close'); end
			end
			try me.finaliseMovie(); me.moviePtr = []; end
			kind = Screen(me.win, 'WindowKind');
			try
				if kind == 1
					fprintf('\n\n---> screenManager %s: Closing screen = %i, Win = %i, Kind = %i\n', me.uuid, me.screen, me.win, kind);
					Screen('Close',me.win);
				end
			catch ME
				getReport(ME);
			end
			me.win = [];
			if isfield(me.screenVals,'win');me.screenVals=rmfield(me.screenVals,'win');end
			me.isOpen = false;
			me.isPlusPlus = false;
		end


		% ===================================================================
		function resetScreenGamma(me)
		%> @fn resetScreenGamma
		%> @brief reset the gamma table
		%>
		%> @param
		%> @return
		% ===================================================================
			if me.hideFlash == true || me.windowed(1) ~= 1 || (~isempty(me.screenVals) && me.screenVals.resetGamma == true && ~isempty(me.screenVals.linearGamma))
				fprintf('\n---> screenManager: RESET GAMMA TABLES\n');
				Screen('LoadNormalizedGammaTable', me.screen, me.screenVals.linearGamma);
			end
		end

		function set.font(me,varargin)
			if ~isempty(varargin{1}) && isstruct(varargin{1})
				me.font = varargin{1};
				updateFontValues(me);
			end
		end

		% ===================================================================
		function set.backgroundColour(me, value)
		%> @fn set.backgroundColour
		%> @brief Set method for backgroundColour
		%>
		% ===================================================================
			switch length(value)
				case 1
					me.backgroundColour = [value value value 1];
				case 3
					me.backgroundColour = [value 1];
				case 4
					me.backgroundColour = value;
				otherwise
					disp('Wrong Input:')
					disp(value);
					warning('Wrong colour values given, enter 1, 3 or 4 values');
			end
		end

		% ===================================================================
		function set.bitDepth(me,value)
		%> @fn set.bitDepth
		%> @brief Set method for bitDepth
		%>
		% ===================================================================
			check = strcmpi(value,me.bitDepths);
			if any(check)
				me.bitDepth = me.bitDepths{check};
			else
				me.bitDepth = me.bitDepths{1};
				disp(me.bitDepths)
				warning('Wrong value given, select from list above')
			end
		end

		% ===================================================================
		function set.srcMode(me,value)
		%> @fn set.srcMode
		%> @brief Set method for GL blending src
		%>
		% ===================================================================
			check = strcmpi(value,me.blendModes);
			if any(check)
				me.srcMode = me.blendModes{check};
			else
				disp(me.blendModes)
				warning('Wrong value given, select from list above')
			end
		end

		% ===================================================================
		function set.dstMode(me,value)
		%> @fn set.dstMode
		%> @brief Set method for GL blending dst
		%>
		%> @param value
		% ===================================================================
			check = strcmpi(value,me.blendModes);
			if any(check)
				me.dstMode = me.blendModes{check};
			else
				disp(me.blendModes);
				warning('Wrong value given, select from list above');
			end
		end

		% ===================================================================
		function set.distance(me,value)
		%> @fn set.distance
		%> @brief Set method for distance
		%>
		%> @param value
		% ===================================================================
			assert(value > 0,'Distance must be greater than 0!');
			me.distance = value;
			me.makeGrid();
		end

		% ===================================================================
		function set.pixelsPerCm(me,value)
		%> @fn set.pixelsPerCm
		%> @brief Set method for pixelsPerCm
		%>
		%> @param value
		% ===================================================================
			assert(value > 0, 'Pixels per cm must be greater than 0!');
			me.pixelsPerCm = value;
			me.makeGrid();
		end

		% ===================================================================
		function ppd = get.ppd(me)
		%> @fn get.ppd
		%> @brief Get method for ppd (a dependent property)
		%>
		% ===================================================================
			if me.useRetina %note pixelsPerCm is normally recorded using non-retina mode so we fix that here if we are now in retina mode
				ppd = ( (me.pixelsPerCm * 2 ) * (me.distance / 57.3) ); %set the pixels per degree
			else
				ppd = ( me.pixelsPerCm * (me.distance / 57.3) ); %set the pixels per degree
			end
			me.ppd_ = ppd; %cache value for speed!!!
		end

		% ===================================================================
		function set.windowed(me,value)
		%> @fn set.windowed
		%> @brief Set method for windowed
		%>
		%> @param value
		% ===================================================================
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
		%> @brief Set method for screenXOffset
		%>
		%> @param
		% ===================================================================
		function set.screenXOffset(me,value)
			me.screenXOffset = value;
			me.updateCenter();
		end

		% ===================================================================
		%> @brief Set method for screenYOffset
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
		function finishDrawing(me)
		%> @fn finishDrawing
		%> @brief Screen('DrawingFinished')
		%>
		% ===================================================================
			if ~me.isOpen; return; end
			Screen('DrawingFinished', me.win);
		end

		% ===================================================================
		function testWindowOpen(me)
		%> @fn testWindowOpen
		%> @brief Test if window is actully open
		%>
		%> @param
		% ===================================================================
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
		function flashScreen(me,interval)
		%> @fn flashScreen
		%> @brief Flash the screen until keypress
		%>
		%> @param interval
		% ===================================================================
			if ~me.isOpen; return; end
			int = round(interval / me.screenVals.ifi);
			KbReleaseWait;
			while ~KbCheck()
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

		% ===================================================================
		function drawCross(me,size,colour,x,y,lineWidth,showDisk,alpha,alpha2)
		%> @fn drawCross
		%> @brief draw fixation cross from Thaler L, Schütz AC,
		%>  Goodale MA, & Gegenfurtner KR (2013) “What is the best fixation target?
		%>  The effect of target shape on stability of fixational eye movements.
		%>  Vision research 76, 31-42 <http://doi.org/10.1016/j.visres.2012.10.012>
		%>
		%> @param size size in degrees
		%> @param colour of cross
		%> @param x position in degrees relative to screen center
		%> @param y position in degrees relative to screen center
		%> @param lineWidth of lines in degrees (1px minimum)
		%> @param showDisk show background disc?
		%> @param alpha alpha for the lines
		%> @param alpha2 alpha for the disc
		%> @return
		% ===================================================================
			% drawCross(me, size,colour,x,y,lineWidth,showDisk,alpha,alpha2)
			if nargin < 9 || isempty(alpha2); alpha2 = 1; end
			if nargin < 8 || isempty(alpha); alpha = 1; end
			if nargin < 7 || isempty(showDisk); showDisk = true; end
			if nargin < 6 || isempty(lineWidth); lineWidth = 0.05; end
			if nargin < 5 || isempty(y); y = 0; end
			if nargin < 4 || isempty(x); x = 0; end
			if nargin < 3 || isempty(colour)
				if mean(me.backgroundColour(1:3)) <= 0.333
					colour = [1 1 1 alpha];
				else
					colour = [0 0 0 alpha];
				end
			end
			colour = [colour(1:3) alpha];
			if mean(colour(1:3)) <= 0.5
				lineColour = [1 1 1 alpha2];
			else
				lineColour = [0 0 0 alpha2];
			end
			if nargin < 2 || isempty(size); size = 0.6; end
			x = me.xCenter + (x * me.ppd_);
			y = me.yCenter + (y * me.ppd_);
			size = size * me.ppd_;
			dotSize = lineWidth * me.ppd_;
			if dotSize < 1; dotSize = 1; end
			spotSize = dotSize/2;
			if spotSize < 1; spotSize = 1; end
			for p = 1:length(x)
				if showDisk;Screen('gluDisk', me.win, colour, x(p), y(p), size/2);end
				Screen('FillRect', me.win, lineColour, CenterRectOnPointd([0 0 size dotSize], x(p), y(p)));
				Screen('FillRect', me.win, lineColour, CenterRectOnPointd([0 0 dotSize size], x(p), y(p)));
				Screen('gluDisk', me.win, colour, x(p), y(p), spotSize);
			end
		end

		% ===================================================================
		function drawSimpleCross(me, size, colour, x, y, lineWidth)
		%> @fn drawSimpleCross(me, size, colour, x, y, lineWidth)
		%> @brief draw small cross
		%>
		%> @param size size in degrees
		%> @param colour of cross
		%> @param x position in degrees relative to screen center
		%> @param y position in degrees relative to screen center
		%> @param lineWidth of lines
		% ===================================================================
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
		function drawPupilCoreMarker(me, sz, x, y, stop)
		%> @fn drawPupilCoreMarker(me, size, x, y, stop)
		%> @brief draw pupil core calibration marker
		%>
		%> @param size size in degrees
		%> @param x position in degrees relative to screen center
		%> @param y position in degrees relative to screen center
		%> @param is it a stop marker?
		% ===================================================================
			if nargin < 5 || isempty(stop); stop = false; end
			if nargin < 4 || isempty(y); y = 0; end
			if nargin < 3 || isempty(x); x = 0; end
			if nargin < 2 || isempty(sz); sz = 5; end

			xo = x;
			yo = y;

			x = me.xCenter + (x * me.ppd_);
			y = me.yCenter + (y * me.ppd_);
			sz = (sz(1) * me.ppd_)/4;

			r = [0 0 sz sz];
			r2 = [0 0 r(3)+sz r(4)+sz];
			r3 = [0 0 r2(3)+sz r2(4)+sz];
			r4 = [0 0 r3(3)+sz r3(4)+sz];
			r5 = [0 0 r4(3)+3 r4(4)+3];

			if stop
				c = [0 0 0 1; 1 1 1 1; 0 0 0 1; 1 1 1 1]';
				r = [r4;r3;r2;r]';
			else
				c = [0 0 0 1; 1 1 1 1; 0 0 0 1; 1 1 1 1; 0 0 0 1]';
				r = [r5;r4;r3;r2;r]';
			end

			for i = 1: size(r,2)
				r(:,i) = CenterRectOnPointd(r(:,i),x,y);
			end

			Screen('FillOval', me.win, c, r);
			if stop == false
				drawSimpleCross(me, sz/me.ppd_/3, [1 1 1], xo, yo, 3);
			end

		end

		% ===================================================================
		function drawSpot(me, size, colour, x, y)
		%> @fn drawSpot(me, size, colour, x, y)
		%> @brief draw small spot centered on the screen
		%>
		%> @param radius size in degrees
		%> @param colour of spot
		%> @param x position in degrees relative to screen center
		%> @param y position in degrees relative to screen center
		%> @return
		% ===================================================================
			if nargin < 5 || isempty(y); y = 0; end
			if nargin < 4 || isempty(x); x = 0; end
			if nargin < 3 || isempty(colour); colour = [1 1 1 1]; end
			if nargin < 2 || isempty(size); size = 1; end

			x = me.xCenter + (x * me.ppd_);
			y = me.yCenter + (y * me.ppd_);
			size = size * me.ppd_;
			for p = 1:length(x)
				Screen('gluDisk', me.win, colour, x(p), y(p), size);
			end
		end

		% ===================================================================
		%> @brief draw timed small spot centered on the screen
		%>
		%> @param
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
		%> @param text text to draw
		% ===================================================================
		function drawTextNow(me, text, x, y, wrapat)
			% drawTextNow(me,text,x,y,wrapat)
			if ~exist('text','var') || isempty(text); return; end
			if ~exist('x','var') || isempty(x); x = (-me.xCenter / me.ppd_) + 0.25;end
			if ~exist('y','var') || isempty(y); y = (-me.yCenter / me.ppd_) + 0.25;end
			if ~exist('wrapat','var') || isempty(wrapat)
				me.drawText(text, x, y);
			else
				me.drawTextWrapped(text, wrapat, x, y);
			end
			flip(me,[],[],2);
		end

		% ===================================================================
		%> @brief draw text
		%>
		%> @param text text to draw
		% ===================================================================
		function drawText(me, text, x, y)
			% drawText(me,text,x,y)
			if ~exist('text','var') || isempty(text); return; end
			if ~exist('x','var') || isempty(x); x = (-me.xCenter / me.ppd_) + 0.25;end
			if ~exist('y','var') || isempty(x); y = (-me.yCenter / me.ppd_) + 0.25;end
			Screen('DrawText', me.win, text, (x * me.ppd_) + me.xCenter, (y * me.ppd_) + me.yCenter);
		end

		% ===================================================================
		function drawTextWrapped(me, text, wrapat, x, y)
		%> @fn drawTextWrapped
		%> @brief draw text with wrapping
		%>
		%> @param text text to draw
		%> @param wrapat character to wrap at
		% ===================================================================
			if ~exist('text','var') || isempty(text); return; end
			if exist('wrapat','var') && ~isempty(wrapat); text = WrapString(text,wrapat); end
			if ~exist('x','var');x = (-me.xCenter / me.ppd_) + 0.25;end
			if ~exist('y','var');y = (-me.yCenter / me.ppd_) + 0.25;end
			c = strsplit(text,'\n');
			x = (x * me.ppd_) + me.xCenter;
			yy = (y * me.ppd_) + me.yCenter;
			for s = c
				Screen('DrawText',me.win,s{1},x,yy);
				yy = yy + me.font.TextSize;
				if me.useRetina
					yy = yy + me.font.TextSize;
				end
			end
		end

		% ===================================================================
		%> @brief draw lines specified in degrees to pixels
		%>
		%> @param xy x is row1 and y is row2
		%> @return
		% ===================================================================
		function drawLines(me,xy,width,colour)
			% drawLines(me, xy, width, colour)
			if ~exist('xy','var');return;end
			if ~exist('width','var') || isempty(width); width = 0.1; end
			if ~exist('colour','var') || isempty(colour); colour = [1 1 0]; end
			xy(1,:) = me.xCenter + (xy(1,:) * me.ppd_);
			xy(2,:) = me.yCenter + (xy(2,:) * me.ppd_);
			width	= width * me.ppd_;
			Screen('DrawLines', me.win, xy, width, colour,[],1);
		end

		% ===================================================================
		%> @brief draw box specified with x and y and size in degrees
		%>
		%> @param xy X is row1 and Y is row2 in degrees
		%> @param size in degrees, either 1 or 2 values
		%> @param colour RGB[A], use columns for multiple colours
		%> @return
		% ===================================================================
		function drawBox(me,xy,boxsize,colour)
			% drawBox(me, xy, size, colour)
			if ~exist('xy','var');return;end
			if ~exist('boxsize','var') || isempty(boxsize); boxsize = 2; end
			if ~exist('colour','var') || isempty(colour); colour = [1 1 0]'; end
			boxsize = boxsize .* me.ppd_;
			if size(xy,1)==1 && size(xy,2)==2;xy = xy'; end
			xy(1,:) = xy(1,:) * me.ppd_ + me.xCenter;
			xy(2,:) = xy(2,:) * me.ppd_ + me.yCenter;
			if length(boxsize) == 1
				xbs = boxsize;
				ybs = boxsize;
			else
				xbs = boxsize(1);
				ybs = boxsize(2);
			end
			for i = 1:size(xy,2)
				rect(:,i) = [0 0 xbs ybs]';
				rect(:,i) = CenterRectOnPointd(rect(:,i),xy(1,i),xy(2,i));
			end
			Screen('FillRect', me.win, colour, rect);
		end

		% ===================================================================
		%> @brief draw box specified with x and y and size in pixels
		%>
		%> @param xy X is row1 and Y is row2 in px
		%> @param size in px
		%> @param colour RGB[A], use columns for multiple colours
		%> @return
		% ===================================================================
		function drawBoxPx(me,xy,boxsize,colour)
			% drawBox(me, xy, size, colour)
			if ~exist('xy','var');return;end
			if ~exist('boxsize','var') || isempty(boxsize); boxsize = 50; end
			if ~exist('colour','var') || isempty(colour); colour = [1 1 0.75]'; end
			if length(boxsize) == 1
				xbs = boxsize;
				ybs = boxsize;
			else
				xbs = boxsize(1);
				ybs = boxsize(2);
			end
			for i = 1:size(xy,2)
				rect(:,i) = [0 0 xbs ybs]';
				rect(:,i) = CenterRectOnPointd(rect(:,i),xy(1,i),xy(2,i));
			end
			Screen('FillRect', me.win, colour, rect);
		end

		% ===================================================================
		%> @brief draw Rect specified in degrees
		%>
		%> @param rect [left, top, right, bottom] in degrees
		%> @param colour RGB[A]
		%> @return
		% ===================================================================
		function drawRect(me,rect,colour)
			if ~exist('rect','var');return;end
			if ~exist('colour','var') || isempty(colour); colour = [1 1 0]'; end
			x = me.xCenter + ([rect(1) rect(3)] * me.ppd_);
			y = me.yCenter + ([rect(2) rect(4)] * me.ppd_);
			Screen('FillRect', me.win, colour, [x(1) y(1) x(2) y(2)]);
		end

		% ===================================================================
		%> @brief draw dots specified in degrees to pixel center coordinates
		%>
		%> @param xy x is row1 and y is row2
		%> @return
		% ===================================================================
		function drawDots(me,xy,size,colour,center)
			if ~exist('xy','var');return;end
			if ~exist('size','var') || isempty(size); size = 0.5; end
			if ~exist('colour','var') || isempty(colour); colour = [1 1 0 0.5]; end
			if ~exist('center','var') || isempty(center); center = [0 0]; end
			size = size * me.ppd_;
			xy(1,:) = me.xCenter + (xy(1,:) * me.ppd_);
			xy(2,:) = me.yCenter + (xy(2,:) * me.ppd_);
			Screen('DrawDots', me.win, xy, size, colour, center, 1);
		end

		% ===================================================================
		%> @brief draw dots specified in degrees
		%>
		%> @param xy x is row1 and y is row2
		%> @return
		% ===================================================================
		function drawDotsDegs(me,xy,size,colour)
			if ~exist('xy','var');return;end
			if ~exist('size','var') || isempty(size); size = 0.5; end
			if ~exist('colour','var') || isempty(colour); colour = [1 1 0 0.5]; end
			size = size * me.ppd_;
			xy(1,:) = me.xCenter + (xy(1,:) * me.ppd_);
			xy(2,:) = me.yCenter + (xy(2,:) * me.ppd_);
			center(1) = round(mean(xy(1,:)));
			center(2) = round(mean(xy(2,:)));
			xy(1,:) = xy(1,:) - center(1);
			xy(2,:) = xy(2,:) - center(2);
			Screen('DrawDots', me.win, xy, size, colour, center, 1);
		end

		% ===================================================================
		%> @brief draw small spot centered on the screen
		%>
		%> @param
		%> @return
		% ===================================================================
		function drawScreenCenter(me)
			Screen('gluDisk',me.win,[1 0 1 1],me.xCenter,me.yCenter,3);
		end

		% ===================================================================
		%> @brief draw a 5x5 1deg dot grid for visual debugging
		%>
		%> @param
		%> @return
		% ===================================================================
		function drawGrid(me)
			if me.useRetina; sz=3; else; sz = 2; end
			Screen('DrawDots',me.win,me.grid,sz,me.gridColour,[me.xCenter me.yCenter],0);
		end

		% ===================================================================
		%> @brief draw a square in top-right of screen to trigger photodiode
		%>
		%> @param colour colour of square
		%> @return
		% ===================================================================
		function drawPhotoDiodeSquare(me,colour)
			% drawPhotoDiodeSquare(me,colour)
			Screen('FillRect',me.win,colour,me.photoDiodeRect);
		end

		% ===================================================================
		%> @brief draw the mouse X and Y position on screen
		%>
		%> @param force, override the global X and Y position which is only
		%> updated when stimuli are animating and visible...
		%> @return
		% ===================================================================
		function drawMousePosition(me,force)
			global mouseGlobalX mouseGlobalY %#ok<*GVMIS>
			if ~exist('force','var'); force = false; end
			if force == true
				[x,y] = mousePosition(me,false);
				val = [x y];
				txt = sprintf('X: %+.2f | Y: %+.2f',val(1),val(2));
				drawText(me, txt, 0, me.screenVals.topInDegrees);
			elseif ~isempty(mouseGlobalX) && ~isempty(mouseGlobalY)
				val = me.toDegrees([mouseGlobalX mouseGlobalY]);
				txt = sprintf('X: %+.2f | Y: %+.2f',val(1),val(2));
				drawText(me, txt, 0, me.screenVals.topInDegrees);
			end
		end

		% ===================================================================
		function drawBackground(me,background)
		%> @fn drawBackground(me,background)
		%> @brief Draw the background colour
		%>
		%> @param background an optional colour
		% ===================================================================
			% drawBackground(me,background)
			if ~exist('background','var'); background=me.backgroundColour; end
			Screen('FillRect',me.win,background,[]);
		end

		% ===================================================================
		function captureScreen(me, filename)
		%> @fn captureScreen(me,filename)
		%> @brief Copies the window to a screenshot
		%>
		%> @param filename optional filename
		% ===================================================================
			if ~exist('filename','var')
				filename=[me.paths.parent filesep 'Shot' datestr(now,'YYYY-mm-DD-HH-MM-SS') '.png'];
			end
			myImg = Screen('GetImage',me.win);
			imwrite(myImg, filename);
			fprintf('---> screenManager captureScreen saved to: %s\n', filename);
		end

		% ===================================================================
		%> @brief return mouse position in degrees
		%>
		%> @param
		% ===================================================================
		function [xPos, yPos] = mousePosition(me, verbose)
			if ~exist('verbose','var') || isempty(verbose); verbose = me.verbose; end
			global mouseGlobalX mouseGlobalY
			if me.isOpen
				[mouseGlobalX,mouseGlobalY] = GetMouse(me.win);
			else
				[mouseGlobalX,mouseGlobalY] = GetMouse();
			end
			xPos = (mouseGlobalX - me.xCenter) / me.ppd_;
			yPos = (mouseGlobalY - me.yCenter) / me.ppd_;
			if verbose
				fprintf('--->>> MOUSE POSITION: \tX = %+2.2f (%4.2f) \t\tY = %+2.2f (%4.2f)\n',xPos,mouseGlobalX,yPos,mouseGlobalY);
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
				if length(me.movieSettings.size) == 2
					me.movieSettings.size=CenterRect([0 0 me.movieSettings.size(1) me.movieSettings.size(2)],me.winRect);
				else
					me.movieSettings.size = me.winRect;
				end
				if isempty(me.movieSettings.fps)
					me.movieSettings.fps = me.screenVals.fps;
				end
				me.movieSettings.loop=1;
				if ismac || isunix
					oldp = cd('~');
					homep = pwd;
					cd(oldp);
				else
					homep = 'c:';
				end
				if ~exist([me.paths.parent filesep 'Movie' filesep],'dir')
					try mkdir([me.paths.parent filesep 'Movie' filesep]); end
				end
				me.movieSettings.moviePath = [me.paths.parent filesep 'Movie' filesep];
				switch me.movieSettings.type
					case {'movie',1}
						if isempty(me.movieSettings.codec)
							settings = [];
						else
							settings = sprintf(':CodecType=%s Profile=3 Keyframe=%g Videoquality=%g',...
								me.movieSettings.codec, me.movieSettings.keyframe, me.movieSettings.quality);
						end
						me.movieSettings.movieFile = [me.movieSettings.moviePath me.movieSettings.prefix datestr(now,'dd-mm-yyyy-HH-MM-SS') '.mp4'];
						% moviePtr = Screen('CreateMovie', windowPtr, movieFile [, width][, height]...
						% [, frameRate=30][, movieOptions][, numChannels=4]...
						% [, bitdepth=8]);
						me.moviePtr = Screen('CreateMovie', me.win,...
							me.movieSettings.movieFile,...
							RectWidth(me.movieSettings.size), RectHeight(me.movieSettings.size),...
							me.movieSettings.fps);
					case {'mat',2}
						me.movieSettings.movieFile = [me.movieSettings.moviePath me.movieSettings.prefix datestr(now,'dd-mm-yyyy-HH-MM-SS') '.mat'];
						settings = 'mat';
						nFrames = 120;
						me.movieMat = uint8(zeros(RectHeight(me.movieSettings.size),RectWidth(me.movieSettings.size), me.movieSettings.channels, nFrames));
					case {'image','png','jpg',3}
						settings = 'png';
						me.movieSettings.movieFile = [me.movieSettings.moviePath me.movieSettings.prefix '_' datestr(now,'dd-mm-yyyy-HH-MM-SS')];
				end
				fprintf('\n---> screenManager: Movie [enc:%s] [rect:%s] will be saved to:\n\t%s\n',settings,...
				  num2str(me.movieSettings.size),me.movieSettings.movieFile);
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
						case {'movie',1}
							Screen('AddFrameToMovie', me.win, me.movieSettings.size, 'frontBuffer', me.moviePtr);
						case {'mat',2}
							%Screen('GetImage', windowPtr [,rect] [,bufferName] [,floatprecision=0] [,nrchannels=3])
							me.movieMat(:,:,:,me.movieSettings.loop)=Screen('GetImage', me.win,...
								me.movieSettings.size, 'frontBuffer', 0, me.movieSettings.channels);
						otherwise
							try
								m = Screen('GetImage', me.win, me.movieSettings.size);
								imwrite(m,[me.movieSettings.movieFile '_' sprintf('%.4i',me.movieSettings.loop) '.png']);
							catch ME
								getReport(ME)
							end
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
		function finaliseMovie(me)
			if me.movieSettings.record == true
				switch me.movieSettings.type
					case 1
						if ~isempty(me.moviePtr)
							Screen('FinalizeMovie', me.moviePtr);
							fprintf(['\n---> screenManager: movie saved to ' me.movieSettings.movieFile '\n']);
							try Screen('CloseMovie', me.moviePtr); end
						end
					case 2
						if ~isempty(me.movieMat)
							mm = me.movieMat;
							mm = squeeze(mm);
							save(me.movieSettings.movieFile,'mm');
							fprintf(['\n---> screenManager: movie MAT saved to ' me.movieSettings.movieFile '\n']);
						end
					otherwise
						fprintf(['\n---> screenManager: movie file[s] saved to ' me.movieSettings.moviePath '\n']);
				end
			end
			me.movieSettings.loop = 1;
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
			if me.movieSettings.record == true  && ...
					me.movieSettings.type == 2 && ...
					exist('implay','file') && ...
					~isempty(me.movieSettings.movieFile) && ...
					~isdeployed
				try
					mimg = load(me.movieSettings.movieFile);
					implay(mimg);
					clear mimg;
				end
			else
				salutation(me,'playMovie method','Playing failed!',true);
			end
		end

		% ===================================================================
		%> @brief toDegrees - convert from pixels to degrees
		%>
		%> expects col1 = x, col2 = y for 'xy'
		% ===================================================================
		function out = toDegrees(me, in, axis)
			if ~exist('axis','var') || isempty(axis)
				if size(in, 2) == 2
					axis = 'xy';
				elseif size(in, 2) == 4
					axis = 'rect';
				else
					axis = 'x';
				end
			end
			switch axis
				case 'xy'
					out(:,1) = (in(:,1) - me.xCenter) / me.ppd_;
					out(:,2) = (in(:,2) - me.yCenter) / me.ppd_;
				case 'rect'
					out(:,1) = (in(:,1) - me.xCenter) / me.ppd_;
					out(:,2) = (in(:,2) - me.yCenter) / me.ppd_;
					out(:,3) = (in(:,3) - me.xCenter) / me.ppd_;
					out(:,4) = (in(:,4) - me.yCenter) / me.ppd_;
				case 'x'
					out = (in - me.xCenter) / me.ppd_;
				case 'y'
					out = (in - me.yCenter) / me.ppd_;
				otherwise
					if length(in)==4
						out(1:2) = (in(1:2) - me.xCenter) / me.ppd_;
						out(3:4) = (in(3:4) - me.yCenter) / me.ppd_;
					elseif length(in)==2
						out(1) = (in(1) - me.xCenter) / me.ppd_;
						out(2) = (in(2) - me.yCenter) / me.ppd_;
					else
						out = ones(size(in))+me.xCenter;
					end
			end
		end

		% ===================================================================
		%> @brief toPixels - convert from degrees to pixels
		%>
		% ===================================================================
		function out = toPixels(me, in, axis)
			if ~exist('axis','var') || isempty(axis)
				if size(in, 2) == 2
					axis='xy';
				elseif size(in, 2) == 4
					axis='rect';
				else
					axis = 'x';
				end
			end
			switch axis
				case 'xy'
					out(:,1) = (in(:,1) * me.ppd_) + me.xCenter;
					out(:,2) = (in(:,2) * me.ppd_) + me.yCenter;
				case 'rect'
					out(:,1) = (in(:,1) * me.ppd_) + me.xCenter;
					out(:,2) = (in(:,2) * me.ppd_) + me.yCenter;
					out(:,3) = (in(:,3) * me.ppd_) + me.xCenter;
					out(:,4) = (in(:,4) * me.ppd_) + me.yCenter;
				case 'x'
					out = (in * me.ppd_) + me.xCenter;
				case 'y'
					out = (in * me.ppd_) + me.yCenter;
				otherwise
					if length(in)==4
						out(1:2) = (in(1:2) * me.ppd_) + me.xCenter;
						out(3:4) = (in(3:4) * me.ppd_) + me.yCenter;
					elseif length(in)==2
						out(1) = (in(1) * me.ppd_) + me.xCenter;
						out(2) = (in(2) * me.ppd_) + me.yCenter;
					else
						out = ones(size(in))+me.xCenter;
					end
			end
		end

		% ===================================================================
		%> @brief Delete method
		%>
		% ===================================================================
		function delete(me)
			if me.isOpen
				close(me);
				logOutput(me, 'DELETE method', 'Screen closed');
			end
		end
	end

	%=======================================================================
	methods (Hidden = true) %------------------HIDDEN METHODS
	%=======================================================================
		function drawPhotoDiode(me,colour)
			Screen('FillRect',me.win,colour,me.photoDiodeRect);
		end
	end

	%=======================================================================
	methods (Static = true) %------------------STATIC METHODS
	%=======================================================================

		% ===================================================================
		function out = equidistantPoints(n,distance,phase)
		%> @fn rectToPos
		%>
		%> @param n number of points
		%> @param distance distance from center
		%> @return array of X,Y positions
		% ===================================================================
			th = linspace(0,360,n+1);
			th = th(1:end-1) + phase;
			out = zeros(2,length(th));
			for i = 1:length(th)
				[out(1,i),out(2,i)] = pol2cart(deg2rad(th(i)),distance);
			end
		end

		% ===================================================================
		function out = rectToPos(rect)
		%> @fn rectToPos
		%>
		%> @param
		%> @return
		% ===================================================================
			[out.X,out.Y] = RectCenter(rect);
			out.radius = [RectWidth(rect) RectHeight(rect)] / 2;
		end

		% ===================================================================
		function out = posToRect(pos)
		%> @fn posToRectpos
		%>
		%> @param
		%> @return
		% ===================================================================
			if ~isstruct(pos); out = []; return; end
			if length(pos.radius) == 1
				w = pos.radius * 2;
				h = w;
			else
				w = pos.radius(1);
				h = pos.radius(2);
			end
			out = [0 0 w h];
			out = CenterRectOnPointd(out, pos.X, pos.Y);
		end

		% ===================================================================
		%> @brief Set Refresh
		%> Screen('ConfigureDisplay', setting, screenNumber, outputId
		%>   [, newwidth][, newheight][, newHz][, newX][, newY]);
		% ===================================================================
		function setRefresh(value)
			if IsLinux
				inf=Screen('ConfigureDisplay','Scanout',1,0);
				disp('Previous Settings:');
				disp(inf);
				if ~exist('value','var'); return; end
				try Screen('ConfigureDisplay','Scanout',1,0,[],[],value); end
				inf=Screen('ConfigureDisplay','Scanout',1,0);
				disp('New Settings:');
				disp(inf);
			end
		end

		% ===================================================================
		%> @brief Set Resolution and refresh
		%> Screen('ConfigureDisplay', setting, screenNumber, outputId
		%>   [, newwidth][, newheight][, newHz][, newX][, newY]);
		% ===================================================================
		function setResolution(w,h,f)
			if IsLinux
				inf=Screen('ConfigureDisplay','Scanout',1,0);
				disp('Previous Settings:');
				disp(inf);

				if exist('w','var') && exist('h','var')
					try
						if exist('f','var')
							Screen('ConfigureDisplay','Scanout',1,0,w,h,f);
						else
							Screen('ConfigureDisplay','Scanout',1,0,w,f);
						end

						inf=Screen('ConfigureDisplay','Scanout',1,0);
						disp('New Settings:');
						disp(inf);
					end
				end
			end
		end

		% ===================================================================
		%> @brief Run validation for Display++
		%>
		% ===================================================================
		function validateDisplayPlusPlus(screen, vulkan)
			if ~exist('screen','var'); screen = max(Screen('Screens')); end
			if ~exist('vulkan','var'); vulkan = 0; end
			screenManager.bitsCheckOpen([], false);
			BitsPlusImagingPipelineTest(screen);
			BitsPlusIdentityClutTest(screen, [], [], [], vulkan);
		end

		% ===================================================================
		%> @brief Identify screens
		%>
		%> @param
		%> @return
		% ===================================================================
		function identifyScreens()
			PsychDefaultSetup(2);
			screens = Screen('Screens');
			olds = Screen('Preference', 'SkipSyncTests', 2);
			oldv = Screen('Preference', 'VisualDebugLevel', 0);
			wins = [];
			a = 1;
			for i = screens
				x = i*100;
				wins(a) = PsychImaging('OpenWindow', i, 0.5, [x 0 x+100 100]);
				os=Screen('TextSize', wins(a),  50);
				Screen('DrawText',wins(a),['W:' num2str(i)], 5, 30,[0.25 1 1]);
				Screen('Flip',wins(a));
				a = a + 1;
			end
			WaitSecs(2);
			for i = 1:length(wins)
				Screen('Close',wins(i));
			end
			Screen('Preference', 'SkipSyncTests', olds);
			Screen('Preference', 'VisualDebugLevel', oldv);
			sca
		end

		% ===================================================================
		%> @brief check for display++, and keep open or close again
		%>
		%> @param port optional serial USB port
		%> @param keepOpen should we keep it open after check (default yes)
		%> @return connected - is the Display++ connected?
		% ===================================================================
		function connected = bitsCheckOpen(port,keepOpen)
			connected = false;
			if ~exist('keepOpen','var') || isempty(keepOpen)
				keepOpen = true;
			end
			try
				if ~exist('port','var') || isempty(port)
					ret = BitsPlusPlus('OpenBits#');
				else
					ret = BitsPlusPlus('OpenBits#',port);
				end
				if ret == 1; connected = true; end
				if ~keepOpen; BitsPlusPlus('Close'); end
			end
		end

		% ===================================================================
		%> @brief Flip the screen
		%>
		%> @param
		%> @return
		% ===================================================================
		function bitsSwitchStatusScreen()
			BitsPlusPlus('SwitchToStatusScreen');
		end

	end

	%=======================================================================
	methods (Access = private) %------------------PRIVATE METHODS
	%=======================================================================

		% ===================================================================
		%> @brief Sets screen size, taking retina mode into account
		%>
		% ===================================================================
		function sv = setScreenSize(me, sv)
			%get screen dimensions
			if ~isempty(me.win)
				swin = me.win;
			else
				swin = me.screen;
			end
			[sv.screenWidth, sv.screenHeight] = Screen('WindowSize',swin);
			if me.useRetina
				sv.width = sv.screenWidth;
				sv.height = sv.screenHeight;
				me.winRect = Screen('Rect',swin);
			elseif ~isempty(me.windowed) && length(me.windowed)==4
				sv.width = me.windowed(end-1);
				sv.height = me.windowed(end);
				me.winRect = me.windowed;
			else
				sv.width = sv.screenWidth;
				sv.height = sv.screenHeight;
				me.winRect = Screen('Rect',swin);
			end
			sv.widthInDegrees = sv.width / me.ppd;
			sv.heightInDegrees = sv.height / me.ppd;
			updateCenter(me);
			sv.xCenter = me.xCenter;
			sv.yCenter = me.yCenter;
			sv.leftInDegrees = -me.xCenter / me.ppd;
			sv.topInDegrees = -me.yCenter / me.ppd;
			sv.rightInDegrees = -sv.leftInDegrees;
			sv.bottomInDegrees = -sv.topInDegrees;
			sv.rectInDegrees = [sv.leftInDegrees sv.topInDegrees sv.rightInDegrees sv.bottomInDegrees];
		end

		% ===================================================================
		%> @brief Makes a 20x20 1deg dot grid for debug mode
		%> This is always updated on setting distance or pixelsPerCm
		% ===================================================================
		function makeGrid(me)
			me.grid = [];
			rn = -20:20;
			for i=rn
				me.grid = horzcat(me.grid, [rn;ones(1,length(rn))*i]);
			end
			me.grid = me.grid .* me.ppd;
		end

		% ===================================================================
		%> @brief update our screen centre to use any offsets we've defined
		%>
		% ===================================================================
		function updateCenter(me)
			if length(me.winRect) == 4
				%get the center of our screen, along with user defined offsets
				[me.xCenter, me.yCenter] = RectCenter(me.winRect);
				me.xCenter = me.xCenter + (me.screenXOffset * me.ppd_);
				me.yCenter = me.yCenter + (me.screenYOffset * me.ppd_);
				if ~isempty(me.screenVals)
					me.screenVals.xCenter = me.xCenter;
					me.screenVals.yCenter = me.yCenter;
				end
			end
		end

		% ===================================================================
		%> @brief
		%>
		% ===================================================================
		function updateFontValues(me)
			if me.isOpen
				Screen('Preference', 'DefaultFontName', me.font.FontName);
				Screen('Preference', 'TextRenderer', me.font.TextRenderer);
				if me.useRetina
					Screen('Preference', 'DefaultFontSize', me.font.TextSize*2);
					if ~isempty(me.win);Screen('TextSize', me.win, me.font.TextSize*2);end
				else
					if IsWin
						Screen('Preference', 'DefaultFontSize', ceil(me.font.TextSize/1.6));
						if ~isempty(me.win);Screen('TextSize', me.win, ceil(me.font.TextSize/1.6));end
					else
						Screen('Preference', 'DefaultFontSize', me.font.TextSize);
						if ~isempty(me.win);Screen('TextSize', me.win, me.font.TextSize);end
					end
				end
				if ~isempty(me.win);Screen('TextColor', me.win, me.font.TextColor);end
				if ~isempty(me.win);Screen('TextBackgroundColor', me.win, me.font.TextBackgroundColor);end
				if ~isempty(me.win);Screen('TextFont', me.win, me.font.FontName);end
			else
				if me.useRetina
					Screen('Preference', 'DefaultFontSize', me.font.TextSize*2);
				else
					Screen('Preference', 'DefaultFontSize', me.font.TextSize);
				end
				Screen('Preference', 'DefaultFontName', me.font.FontName);
				Screen('Preference', 'TextRenderer', me.font.TextRenderer);
			end
		end

	end

end


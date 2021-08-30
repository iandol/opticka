% ========================================================================
%> @brief screenManager 
%> screenManager manages (wraps) the PTB screen settings. You can set many
%> properties of this class to control PTB screens, and use it to open and
%> close the screen based on those properties. It also manages movie
%> recording of the screen buffer and some basic drawing commands like grids,
%> spots and the hide flash trick from Mario.
% ========================================================================
classdef screenManager < optickaCore
	
	properties
		%> the monitor to use, 0 is the main display on macOS/Linux
		%> default value will be set to max(Screen('Screens'))
		screen double							= []
		%> MBP 1440x900 is 33.2x20.6cm so 44px/cm, Flexscan is 32px/cm @1280 26px/cm @ 1024
		%> Display++ is 27px/cm @1920x1080
		%> Use calibrateSize.m function to measure this value accurately for each monitor you will use.
		pixelsPerCm double						= 36
		%> distance of subject from Display -- rad2ang(2 * atan( sz / (2 * dis) ) ) = Xdeg
		%> when sz == 1cm and dis == 57.3cm, X == 1deg
		distance double							= 57.3
		%> hide the black flash as PTB tests its refresh timing, uses a gamma
		%> trick from Mario
		hideFlash logical						= false
		%> windowed: when FALSE use fullscreen; set to TRUE and it is windowed 800x600pixels or you
		%> can add in a window width and height i.e. [800 600] to specify windowed size. Remember
		%> that windowed presentation should never be used for real experimental
		%> presentation due to poor timing...
		windowed								= false
		%> change the debug parameters for poorer temporal fidelity but no sync testing etc.
		debug logical							= false
		%> shows the info text and position grid during stimulus presentation if true
		visualDebug logical						= false
		%> normally should be left at 1 (1 is added to this number so doublebuffering is enabled)
		doubleBuffer uint8						= 1
		%> float precision and bitDepth of framebuffer/output:  
		%>  '8bit' is best for old GPUs, but prefer 'FloatingPoint32BitIfPossible' for newer GPUs. 
		%> Native high bitdepths (assumes FloatingPoint32Bit internal processing): 
		%>   'PseudoGray', 'HDR', 'Native10Bit', 'Native11Bit', 'Native16Bit', 'Native16BitFloat'
		%> Options to enable Display++ modes: 
		%>  'EnableBits++Bits++Output', 'EnableBits++Mono++Output' or 'EnableBits++Color++Output'
		bitDepth char							= 'FloatingPoint32BitIfPossible'
		%> The acceptable variance in flip timing tests performed when
		%> screen opens, set with Screen('Preference', 'SyncTestSettings', syncVariance)
		%> AMD cards under Ubuntu are very low variance, PTB default is 2e-04
		syncVariance double						= 2e-04
		%> timestamping mode 1=beamposition,kernel fallback | 2=beamposition crossvalidate with kernel
		timestampingMode double					= 1
		%> multisampling sent to the graphics card, try values 0[disabled], 4, 8
		%> and 16 -- useful for textures to minimise aliasing, but this
		%> does provide extra work for the GPU
		antiAlias double						= 0
		%> background RGBA of display during stimulus presentation
		backgroundColour double					= [0.5 0.5 0.5 1.0]
		%> shunt center by X degrees (coordinates are in degrees from centre of monitor)
		screenXOffset double					= 0
		%> shunt center by Y degrees (coordinates are in degrees from centre of monitor)
		screenYOffset double					= 0
		%> use OpenGL blending mode
		blend logical							= false
		%> OpenGL blending source mode
		srcMode char							= 'GL_SRC_ALPHA'
		%> OpenGL blending dst mode
		dstMode char							= 'GL_ONE_MINUS_SRC_ALPHA'
		%> show a white square in the top-right corner to trigger a
		%> photodiode attached to screen. This is only displayed when the
		%> stimulus is shown, not during the blank and can therefore be used
		%> for timing validation. For stateMachine tasks you need to
		%> pass in the drawing command for this to take effect.
		photoDiode logical						= false
		%> gamma correction info saved as a calibrateLuminance object
		gammaTable calibrateLuminance
		%> settings for movie output
		movieSettings							= []
		%> useful screen info and initial gamma tables and the like
		screenVals struct						= struct('ifi',1/60,'fps',60,'winRect',[0 0 1920 1080])
		%> verbose output?
		verbose									= false
		%> level of PTB verbosity, set to 10 for full PTB logging
		verbosityLevel double					= 3
		%> Use retina resolution natively (worse performance but double resolution)
		useRetina logical						= false
		%> Screen To Head Mapping, a Nx3 vector: Screen('Preference', 'ScreenToHead', screen, head, crtc);
		%> Each N should be a different display
		screenToHead							= []
		%> force framerate for Display++ (120Hz or 100Hz, empty uses the default OS setup)
		displayPPRefresh double					= []
	end
	
	properties (Constant)
		%> possible bitDepths
		bitDepths cell = {''; 'FloatingPoint32BitIfPossible'; 'FloatingPoint32Bit';...
			'FixedPoint16Bit'; 'FloatingPoint16Bit'; '8bit'; 'PseudoGray';...
			'HDR'; 'Native10Bit'; 'Native11Bit'; 'Native16Bit'; 'Native16BitFloat';...
			'Bits++Bits++Output'; 'Bits++Mono++Output'; 'Bits++Color++Output' }
		%> possible blend modes
		blendModes cell = {'GL_ZERO'; 'GL_ONE'; 'GL_DST_COLOR'; 'GL_ONE_MINUS_DST_COLOR';...
			'GL_SRC_ALPHA'; 'GL_ONE_MINUS_SRC_ALPHA'; 'GL_DST_ALPHA';...
			'GL_ONE_MINUS_DST_ALPHA'; 'GL_SRC_ALPHA_SATURATE' }
	end
	
	properties (Hidden = true)
		%> an optional audioManager that experiments can use. can play
		%> samples or simple beeps
		audio audioManager
		%> for some development macOS and windows machines we have to disable sync tests,
		%> but we hide this as we should remember this is for development ONLY!
		disableSyncTests logical				= false
	end
	
	properties (SetAccess = private, GetAccess = public, Dependent = true)
		%> dependent pixels per degree property calculated from distance and pixelsPerCm
		ppd
	end
	
	properties (SetAccess = private, GetAccess = public)
		%> do we have a working PTB, if not go into a silent mode
		isPTB logical							= false
		%> is a window currently open?
		isOpen logical							= false
		%> did we ask for a bitsPlusPlus mode?
		isPlusPlus logical						= false
		%> the handle returned by opening a PTB window
		win
		%> the window rectangle
		winRect
		%> computed X center
		xCenter double							= 0
		%> computed Y center
		yCenter double							= 0
		%> set automatically on construction
		maxScreen
	end
	
	properties (SetAccess = private, GetAccess = private)
		%> we cache ppd as it is used frequently
		ppd_ double
		%> properties allowed to be modified during construction
		allowedProperties char = ['syncVariance|disableSyncTests|displayPPRefresh|screenToHead|'...
			'gammaTable|useRetina|bitDepth|pixelsPerCm|distance|screen|windowed|backgroundColour|'...
			'screenXOffset|screenYOffset|blend|srcMode|dstMode|antiAlias|debug|photoDiode|verbose|hideFlash']
		%> the photoDiode rectangle in pixel values
		photoDiodeRect(1,4) double				= [0, 0, 45, 45]
		%> the values computed to draw the 1deg dotted grid in visualDebug mode
		grid
		%> the movie pointer
		moviePtr								= []
		%> movie mat structure
		movieMat								= []
		%screen flash logic
		flashInterval							= 20
		flashTick								= 0
		flashOn									= 1
		% timed spot logic
		timedSpotTime							= 0
		timedSpotTick							= 0
		timedSpotNextTick						= 0
		% async flip management
		isInAsync								= false
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
			
			args = optickaCore.addDefaults(varargin,struct('name','screenManager'));
			me=me@optickaCore(args); %superclass constructor
			me.parseArgs(args,me.allowedProperties);
			
			try
				AssertOpenGL
				me.isPTB = true;
				me.salutation('PTB + OpenGL supported!')
			catch %#ok<*CTCH>
				me.isPTB = false;
				me.salutation('CONSTRUCTOR','OpenGL support needed for PTB!!!',true)
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
					sv.lutSize		= 256;
				else
					sv.lutSize		= 1024;
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
			
			% initialise our movie settings
			me.movieSettings = struct('record',false,'loop',inf,'size',[600 600],...
				'fps',30,'quality',0.7,'keyframe',5,...
				'nFrames',sv.fps * 2,'type',1,'codec','x264enc');
			
			if me.debug == true %we yoke these together but they can then be overridden
				me.visualDebug	= true;
			end
			if ismac
				me.disableSyncTests = true;
			end
			
			me.ppd; %generate our dependent propertie and caches it to ppd_ for speed
			me.makeGrid; %our visualDebug size grid
			
			sv.white			= WhiteIndex(me.screen);
			sv.black			= BlackIndex(me.screen);
			sv.gray				= GrayIndex(me.screen);
			
			if IsLinux
				try
					sv.display		= Screen('ConfigureDisplay','Scanout',me.screen,0);
					sv.name			= sv.display.name;
					sv.widthMM		= sv.display.displayWidthMM;
					sv.heightMM		= sv.display.displayHeightMM;
				end
			end
			
			me.screenVals		= sv;
			screenVals			= sv;
			
		end
		
		% ===================================================================
		%> @brief open a screen with object defined settings
		%>
		%> @param debug, whether we show debug status, called from runExperiment
		%> @param tL timeLog object to add timing info on screen construction
		%> @param forceScreen force a particular screen number to open
		%> @return sv structure of basic info from the opened screen
		% ===================================================================
		function sv = open(me,debug,tL,forceScreen)
			if me.isPTB == false
				warning('No PTB found!')
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
					if me.disableSyncTests;Screen('Preference', 'SkipSyncTests', 2);end
					Screen('Preference', 'VisualDebugLevel', 0);
					Screen('Preference', 'Verbosity', me.verbosityLevel);
					Screen('Preference', 'SuppressAllWarnings', 0);
				else
					if me.disableSyncTests
						fprintf('\n---> screenManager: Sync Tests OVERRIDDEN, do not use for real experiments!!!\n');
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
				
				%check if system supports HDR mode
				isHDR = PsychHDR('Supported');
				if strcmpi(me.bitDepth,'HDR') && ~isHDR
					warning('---> screenManager: tried to use HDR but it is not supported!');
					me.bitDepth = 'Native10Bit';
				end
				
				% start to set up PTB screen
				PsychImaging('PrepareConfiguration');
				PsychImaging('AddTask', 'General', 'UseFastOffscreenWindows');
				fprintf('---> screenManager: Probing for a Display++...');
				me.isPlusPlus = screenManager.bitsCheckOpen();
				if me.isPlusPlus
					fprintf('\tFound Display++ ');
					if contains(me.bitDepth, 'Bits++')
						if regexpi(me.bitDepth, '^Bits++','ONCE')
							me.bitDepth = ['Enable' me.bitDepth];
						end
						fprintf('-> mode: %s\n', me.bitDepth);
						PsychImaging('AddTask', 'FinalFormatting', 'DisplayColorCorrection', 'ClampOnly');
						if regexp(me.bitDepth, 'Color')
							PsychImaging('AddTask', 'General', me.bitDepth, 2);
						else
							PsychImaging('AddTask', 'General', me.bitDepth);
						end
					else
						me.isPlusPlus = false; %we just use a regular setup
					end
				end
				if ~me.isPlusPlus
					fprintf('\tNO Display++...\n'); 
					switch lower(me.bitDepth)
						case {'hdr','enablehdr'}
							PsychImaging('AddTask', 'General', 'FloatingPoint32BitIfPossible');
							PsychImaging('AddTask', 'General', 'EnableHDR');
						case {'native10bit','native11bit','native16bit'}
							PsychImaging('AddTask', 'General', 'FloatingPoint32BitIfPossible');
							PsychImaging('AddTask', 'General', ['Enable' me.bitDepth 'Framebuffer']);
							fprintf('\n---> screenManager: 32-bit internal / %s Output bit-depth\n', me.bitDepth);
						case {'native16bitfloat'}
							PsychImaging('AddTask', 'General', 'FloatingPoint32BitIfPossible');
							PsychImaging('AddTask', 'General', ['Enable' me.bitDepth 'ingPointFramebuffer']);
							fprintf('\n---> screenManager: 32-bit internal / %s Output bit-depth\n', me.bitDepth);
						case {'pseudogray','enablepseudograyoutput'}
							PsychImaging('AddTask', 'General', 'FloatingPoint32BitIfPossible');
							PsychImaging('AddTask', 'General', 'EnablePseudoGrayOutput');
							fprintf('\n---> screenManager: Internal processing set to: %s\n', 'PseudoGrayOutput');
						case {'floatingpoint32bitifpossible','floatingpoint32bit'}
							PsychImaging('AddTask', 'General', me.bitDepth);
							fprintf('\n---> screenManager: Internal processing set to: %s\n', me.bitDepth);
						case {'8bit'}
							PsychImaging('AddTask', 'General', 'UseVirtualFramebuffer');
							fprintf('\n---> screenManager: Internal processing set to: %s\n', '8 bits');
						otherwise
							fprintf('\n---> screenManager: No imaging pipeline requested...\n');
					end
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
				if me.verbose; fprintf('===>>>Made win: %i kind: %i\n',me.win,Screen(me.win,'WindowKind')); end
				tL.screenLog.postOpenWindow=GetSecs;
				tL.screenLog.deltaOpenWindow=(tL.screenLog.postOpenWindow-tL.screenLog.preOpenWindow)*1000;
				
				me.screenVals = setScreenSize(me, me.screenVals);
			
				if strcmpi(me.bitDepth,'HDR') && isHDR
					sv.hdrProperties = PsychHDR('GetHDRProperties', me.win);
					if IsWin; oldDim = PsychHDR('HDRLocalDimming', me.win, 0); end
				else 
					sv.hdrProperties = [];
				end
				
				try
					AssertGLSL;
				catch
					close(me);
					error('GLSL Shading support is required for Opticka!');
				end
				
				if IsLinux & ~isHDR
					d=Screen('ConfigureDisplay','Scanout',me.screen,0);
					sv.name		= d.name;
					sv.widthMM	= d.displayWidthMM;
					sv.heightMM = d.displayHeightMM;
					sv.display	= d;
				end
				
				sv.win			= me.win; %make a copy
				sv.winRect		= me.winRect; %make a copy
				
				sv.ifi			= Screen('GetFlipInterval', me.win);
				sv.fps			= Screen('NominalFramerate', me.win);
				%find our fps if not defined above
				if sv.fps == 0
					sv.fps=round(1/sv.ifi);
					if sv.fps == 0 || (sv.fps == 59 && IsWin)
						sv.fps = 60;
					end
				elseif sv.fps == 59 && IsWin
					sv.fps = 60;
					sv.ifi = 1 / 60;
				end
				if me.windowed == false %fullscreen
					sv.halfifi = sv.ifi/2;
                    sv.halfisi = sv.halfifi;
				else
					% windowed presentation doesn't handle the preferred method
					% of specifying lastvbl+halfifi properly so we set halfifi to 0 which
					% effectively makes flip occur ASAP.
					sv.halfifi = 0; sv.halfisi = 0;
				end
                
                me.photoDiodeRect = [me.winRect(3)-45 0 me.winRect(3) 45];
				
				
				[sv.originalGamma, sv.dacBits, sv.lutSize]=Screen('ReadNormalizedGammaTable', me.win);
				sv.linearGamma  = repmat(linspace(0,1,sv.lutSize)',1,3);
				sv.gammaTable	= sv.originalGamma;
				
				if me.hideFlash == true && isempty(me.gammaTable)
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
				if me.blend==1
					sv.newSrc = me.srcMode;
					sv.newDst = me.dstMode;
					sv.srcdst = [me.srcMode '|' me.dstMode];
					sv.blending = true;
					[sv.oldSrc,sv.oldDst,sv.oldMask]...
						= Screen('BlendFunction', me.win, me.srcMode, me.dstMode);
					fprintf('\n---> screenManager: Previous OpenGL blending: %s | %s\n', sv.oldSrc, sv.oldDst);
					fprintf('---> screenManager: OpenGL blending now: %s | %s\n', me.srcMode, me.dstMode);
				end
				
				if IsLinux
					Screen('Preference', 'DefaultFontName', 'Source Sans 3');
				end
				
				sv.white = WhiteIndex(me.screen);
				sv.black = BlackIndex(me.screen);
				sv.gray = GrayIndex(me.screen);
				
				me.screenVals = sv;
				me.isOpen = true;
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
				stim = textureStimulus('speed',4,'xPosition',-3,'yPosition',0);
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
		%> [VBLTimestamp StimulusOnsetTime FlipTimestamp Missed Beampos] = Screen('Flip', windowPtr [, when] [, dontclear] [, dontsync] [, multiflip]);
		%>
		%> @param varargin - pass other options to screen flip
		%> @return vbl - a vbl from this flip
		% ===================================================================
		function [vbl, when, flipTime, missed] = flip(me, varargin)
			if ~me.isOpen; return; end
			[vbl, when, flipTime, missed] = Screen('Flip',me.win,varargin{:});
		end
		
		% ===================================================================
		%> @brief Flip the screen asynchrounously
		%>
		%> @param when - when to flip
		%> @return vbl - a vbl from this flip
		% ===================================================================
		function vbl = asyncFlip(me, when, varargin)
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
		%> @brief Check async state?
		%>
		%> 
		%> @return result - is in async state?
		% ===================================================================
		function result = asyncCheck(me)
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
		%> @brief end async state
		%>
		%> 
		%> @return vbl - return time
		% ===================================================================
		function vbl = asyncEnd(me)
			if ~me.isOpen; return; end
			vbl = 0;
			if me.isInAsync
				vbl = Screen('AsyncFlipEnd', me.win);
				me.isInAsync = false;
			end
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
			me.screenVals = setScreenSize(me, me.screenVals);
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
		%> @brief close the screen when finished or on error
		%>
		%> @param
		%> @return
		% ===================================================================
		function close(me)
			if ~me.isPTB; return; end
			Priority(0); ListenChar(0); ShowCursor;
			if ~isempty(me.audio) && isa(me.audio, 'audioManager') && me.audio.isSetup
				me.audio.reset();
			end
			if me.screenVals.resetGamma && isfield(me.screenVals,'originalGamma') && ~isempty(me.screenVals.originalGamma)
				Screen('LoadNormalizedGammaTable', me.win, me.screenVals.originalGamma);
				fprintf('\n---> screenManager: REVERT GAMMA TABLES\n');
			end
			if me.isInAsync 
				Screen('ASyncFlipEnd',me.win);
			end
			me.isInAsync = false;
			if me.isPlusPlus
				BitsPlusPlus('Close');
			end
			me.finaliseMovie(); me.moviePtr = [];
			kind = Screen(me.win, 'WindowKind');
			try
				if kind == 1 
					fprintf('\n\n---> screenManager %s: Closing screen = %i, Win = %i, Kind = %i\n',me.uuid, me.screen,me.win,kind);
					Screen('Close',me.win);
				end
			catch ME
				if me.verbose 
					getReport(ME) 
				end
			end
			me.win=[]; 
			if isfield(me.screenVals,'win');me.screenVals=rmfield(me.screenVals,'win');end
			me.isOpen = false;
			me.isPlusPlus = false;
		end
		
		
		% ===================================================================
		%> @brief reset the gamma table
		%>
		%> @param
		%> @return
		% ===================================================================
		function resetScreenGamma(me)
			if me.hideFlash == true || me.windowed(1) ~= 1 || (~isempty(me.screenVals) && me.screenVals.resetGamma == true && ~isempty(me.screenVals.linearGamma))
				fprintf('\n---> screenManager: RESET GAMMA TABLES\n');
				Screen('LoadNormalizedGammaTable', me.screen, me.screenVals.linearGamma);
			end
		end
		
		% ===================================================================
		%> @brief Set method for bitDepth
		%>
		% ===================================================================
		function set.backgroundColour(me,value)
			switch length(value)
				case 1
					me.backgroundColour = [value value value 1];
				case 3
					me.backgroundColour = [value 1];
				case 4
					me.backgroundColour = value;
				otherwise
					warning('Wrong colour values given, enter 1, 3 or 4 values')
			end
		end
		
		% ===================================================================
		%> @brief Set method for bitDepth
		%>
		% ===================================================================
		function set.bitDepth(me,value)
			check = strcmpi(value,me.bitDepths);
			if any(check)
				me.bitDepth = me.bitDepths{check};
			else
				warning('Wrong value given, select from list below')
				disp(me.bitDepths)
			end
		end
		
		% ===================================================================
		%> @brief Set method for GL blending src
		%>
		% ===================================================================
		function set.srcMode(me,value)
			check = strcmpi(value,me.blendModes);
			if any(check)
				me.srcMode = me.blendModes{check};
			else
				warning('Wrong value given, select from list below')
				disp(me.blendModes)
			end
		end
		
		% ===================================================================
		%> @brief Set method for GL blending dst
		%>
		% ===================================================================
		function set.dstMode(me,value)
			check = strcmpi(value,me.blendModes);
			if any(check)
				me.dstMode = me.blendModes{check};
			else
				warning('Wrong value given, select from list below')
				disp(me.blendModes)
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
				ppd = ( (me.pixelsPerCm * 2 ) * (me.distance / 57.3) ); %set the pixels per degree
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
			if ~me.isOpen; return; end
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
			if ~me.isOpen; return; end
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
		
		% ===================================================================
		%> @brief draw fixation cross from Thaler L, Schütz AC, 
		%>  Goodale MA, & Gegenfurtner KR (2013) “What is the best fixation target? 
		%>  The effect of target shape on stability of fixational eye movements.�? 
		%>  Vision research 76, 31-42 <http://doi.org/10.1016/j.visres.2012.10.012>
		%>
		%> @param size size in degrees
		%> @param colour of cross
		%> @param x position in degrees relative to screen center
		%> @param y position in degrees relative to screen center
		%> @param lineWidth of lines in degrees (1px minimum)
		%> @return
		% ===================================================================
		function drawCross(me,size,colour,x,y,lineWidth,showDisk,alpha)
			if ~me.isOpen; fprintf('drawCross(me,size,colour,x,y,lineWidth,showDisk,alpha)\n');return; end
			% drawCross(me, size, colour, x, y, lineWidth)
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
			if mean(colour(1:3)) <= 0.5
				lineColour = [1 1 1 1];
			else
				lineColour = [0 0 0 1];
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
		%> @brief draw small cross
		%>
		%> @param size size in degrees
		%> @param colour of cross
		%> @param x position in degrees relative to screen center
		%> @param y position in degrees relative to screen center
		%> @param lineWidth of lines
		%> @return
		% ===================================================================
		function drawSimpleCross(me,size,colour,x,y,lineWidth)
			% drawSimpleCross(me, size, colour, x, y, lineWidth)
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
			size = size * me.ppd_;
			for p = 1:length(x)
				Screen('gluDisk', me.win, colour, x(p), y(p), size);
			end
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
			Screen('DrawText',me.win,text,10,10,[1 1 1],[0.3 0.3 0.1]);
			flip(me,[],[],2);
		end
		
		% ===================================================================
		%> @brief draw text and flip immediately
		%>
		%> @param
		%> @return
		% ===================================================================
		function drawText(me,text)
			% drawText(me,text)
			if ~exist('text','var');return;end
			Screen('DrawText',me.win,text,10,10,[1 1 1],[0.3 0.3 0.1]);
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
		%> @param size in degrees
		%> @param colour RGB[A], use columns for multiple colours
		%> @return
		% ===================================================================
		function drawBox(me,xy,boxsize,colour)
			% drawBox(me, xy, size, colour)
			if ~exist('xy','var');return;end
			if ~exist('size','var') || isempty(boxsize); boxsize = 2; end
			if ~exist('colour','var') || isempty(colour); colour = [1 1 0]'; end
			boxsize = boxsize * me.ppd_;
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
		%> @brief draw dots specified in degrees to pixel coordinates
		%>
		%> @param xy x is row1 and y is row2
		%> @return
		% ===================================================================
		function drawDots(me,xy,size,colour,center)
			if ~exist('xy','var');return;end
			if ~exist('size','var') || isempty(size); size = 5; end
			if ~exist('colour','var') || isempty(colour); colour = [1 1 1]; end
			if ~exist('center','var') || isempty(center); center = [0 0]; end
			xy(1,:) = me.xCenter + (xy(1,:) * me.ppd_);
			xy(2,:) = me.yCenter + (xy(2,:) * me.ppd_);
			Screen('DrawDots', me.win, xy, size, colour, center);
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
			Screen('DrawDots',me.win,me.grid,1,[1 1 0 1],[me.xCenter me.yCenter],1);
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
			% drawPhotoDiode(me,colour) % conditionally draw a white square to trigger photodiode
			if me.photoDiode;Screen('FillRect',me.win,colour,me.photoDiodeRect);end
		end
		
		% ===================================================================
		%> @brief Draw the background colour
		%>
		%> @param
		%> @return
		% ===================================================================
		function drawBackground(me,background)
			% drawBackground(me,background)
			if ~exist('background','var'); background=me.backgroundColour; end
			Screen('FillRect',me.win,background,[]);
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
			if me.movieSettings.record == true  && me.movieSettings.type == 2 && exist('implay','file') && ~isempty(me.movieSettings.movieFile)
				try
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
	methods (Static = true) %------------------STATIC METHODS
	%=======================================================================
	
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
		function validateDisplayPlusPlus()
			screenManager.bitsCheckOpen([],false)
			BitsPlusImagingPipelineTest
			BitsPlusIdentityClutTest
		end
		
		% ===================================================================
		%> @brief Identify screens
		%>
		%> @param
		%> @return
		% ===================================================================
		function identifyScreens()
			screens = Screen('Screens');
			olds = Screen('Preference', 'SkipSyncTests', 2);
			oldv = Screen('Preference', 'VisualDebugLevel', 0);
			wins = [];
			a = 1;
			for i = screens
				wins(a) = PsychImaging('OpenWindow', i, 0.5, [0 0 100 100]);
				os=Screen('TextSize', wins(a),  50);
				Screen('DrawText',wins(a),['W:' num2str(i)], 5, 30,[1 0 1]);
				Screen('Flip',wins(a));
				a = a + 1;
			end
			WaitSecs(2)
			for i = 1:length(wins)
				Screen('Close',wins(i));
			end
			Screen('Preference', 'SkipSyncTests', olds);
			Screen('Preference', 'VisualDebugLevel', oldv);
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
			if ~isempty(me.windowed) && length(me.windowed)==4
				sv.width = me.windowed(end-1);
				sv.height = me.windowed(end);
				me.winRect = me.windowed;
			else
				sv.width = sv.screenWidth;
				sv.height = sv.screenHeight;
				me.winRect = Screen('Rect',swin);
			end
			updateCenter(me);
			sv.xCenter = me.xCenter;
			sv.yCenter = me.yCenter;
		end
		
		% ===================================================================
		%> @brief Makes a 15x15 1deg dot grid for debug mode
		%> This is always updated on setting distance or pixelsPerCm
		% ===================================================================
		function makeGrid(me)
			me.grid = [];
			rn = -15:15;
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
		
	end
	
end


% ========================================================================
%> @brief movieStimulus is the class for movie based stimulus objects
%>
%>
%>
%> Copyright ©2014-2022 Ian Max Andolina — released: LGPL3, see LICENCE.md
% ========================================================================	
classdef movieStimulus < baseStimulus	
	properties %--------------------PUBLIC PROPERTIES----------%
		type = 'movie'
		%> the direction of the whole object - i.e. the motion direction 
		%> object can move in (different to the angle).
		direction double  = 0
		%> do we lock the texture angle to the direction? If so what is the offset
		%> (0 = parallel, 90 = orthogonal etc.)
		lockAngle double = []
		%> the name / path of a file or folder, if empty a default movie will be used
		filePath char = ''
		%> add a circular mask on the movie?
		circularMask logical = false
		%> selection if nVideos > 0
		selection double		= 0
		%> autoShuffle: time in secs to shuffle to a new video, 0 disables
		autoShuffle				= 0
		%> do we block when getting a frame? This is important, as if it is 1
		%> then you will drop frames waiting for the the synced video frame.
		%> Set to 0 to use double buffering to keep drawing the previous frame
		%> unitl a new frame is ready, ensuring other stimuli animate
		%> smoothly alongside the video. 
		blocking double = 0
		%> how to handle looping (1 = PTB default)
		loopStrategy double		= 1
		%> pixel format for opening movie? 6 is more efficient if H264
		%> used. 1 = Luminance/Greyscale image, 2 = Luminance+Alpha, 
		%> 3 = RGB 8 bit per channel, 4 = RGBA8, 5 = YUV 4:2:2 packed pixel format 
		%> on some graphics hardware, 6 = YUV-I420 planar format, using GLSL shaders 
		%> for color space conversion on suitable graphics cards. 
		%> 7 or 8 = Y8-Y800 planar format, using GLSL shaders, 
		%> 9 = 16 bit Luminance, 10 = 16 bpc RGBA image
		pixelFormat double = []
		%> how many seconds to preload, -1 tries all, 1 secs is PTB default
		preloadSecs double = 1
		%> additional special flags, numbers can be added together
		%> 1 = Use YUV video decoding instead of RGBA
		%> 2 = disable sound
		%> 4 = disable hardware
		%> 8 = skip all B-Frames during decoding to reduce processor load on very slow machines
		%> 16 = convert all video textures immediately into a format which makes them useable as offscreen windows
		%> 32,64,128 = different loop strategies
		%> 256 = prevent automatic deinterlacing of video
		%> 512 = marks the movie as encoded in Psychtoolbox's own proprietary 16 bpc high precision format
		%> 1024 = video frames are encoded as raw Bayer sensor data
		specialFlagsOpen double = 0
		%> special flags for 'GetMovieImage'
		%> 1 = use GL_TEXTURE_2D
		%> 2 = high precision
		%> 8 = no mipmap with GL_TEXTURE_2D
		%> 32 = prevent closing the texture by a call to Screen('Close')
		specialFlagsFrame double = []
		%> special flags for 'GetMovieImage'
		%> 1 = don't return any time info (maybe slightly faster?)
		%> 2 = don't return any textures, for bechmarking.
		specialFlags2Frame double = 1
		%> live mask out a colour? e.g. [0 0 0]
		mask double				= []
		%> mask tolerance
		maskTolerance double	= [];
		%> if movie has transparency, optionally enforce opengl blending?
		enforceBlending logical = false
	end

	properties (Hidden = true)
		%> async setting for OpenMovie, 4 may help performance, see OpenMovie help
		async				= []
		%> initial settings for circular mask
		circularMaskSize	= 500
		circularMaskRadius	= 250
		circularMaskSmoothing = 60
	end
	
	properties (SetAccess = protected, GetAccess = public)
		%> list of imagenames if selection > 0
		filePaths		= {}
		%> number of videos
		nVideos			= 0
		%> current randomly selected movie
		currentFile		= ''
		%> scale is dependent on stimulus size and movie width
		scale			= 1
		family			= 'movie'
		%> handle from OpenMovie
		movie
		%> details
		duration
		fps
		width
		height
		count
	end
	
	properties (SetAccess = protected, GetAccess = public, Transient = true, Hidden = true)
		typeList		= {'movie'}
		filePathList	= 'filerequestor';
		%> do we need to 'PlayMovie'?
		needPlayMovie	= false
		%> texture buffer for non-blocking movie playback, this is the
		%> previous frame until a new frame is available
		buffertex		= []
		%> circular mask texture
		masktex			= []
		%> shader for masking
		shader
		%> 
		shuffleTime		= inf
	end

	properties (SetAccess = protected, GetAccess = ?baseStimulus)
		%> properties to not show in the UI panel
		ignorePropertiesUI = {'alpha','type'}
	end
	
	properties (SetAccess = protected, GetAccess = protected)
		thisMovie			= ''
		msrcMode			= 'GL_SRC_ALPHA'
		mdstMode			= 'GL_ONE_MINUS_SRC_ALPHA'
		%> allowed properties passed to object upon construction
		allowedProperties = {'filePath', 'blocking', 'pixelFormat', 'preloadSecs', ...
			'specialFlagsOpen', 'specialFlagsFrame', 'specialFlags2Frame', 'loopStrategy', ...
			'mask', 'maskTolerance', 'enforceBlending', 'direction','selection','circularMask'}
		%> properties to not create transient copies of during setup phase
		ignoreProperties = {'masktex','circularMask','buffertex', 'shader', 'screenVals', 'movie', 'duration', ...
			'fps', 'width', 'height', 'count', 'scale', 'filePath', 'pixelFormat', ...
			'preloadSecs', 'specialFlagsOpen', 'specialFlagsFrame', 'specialFlags2Frame', ...
			'loopStrategy','needPlayMovie'}
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
		%> @return instance of opticka class.
		% ===================================================================
		function me = movieStimulus(varargin)
			args = optickaCore.addDefaults(varargin,...
				struct('name','movie','size',0));
			me=me@baseStimulus(args); %we call the superclass constructor first
			me.parseArgs(args, me.allowedProperties);
			
			me.isRect = true; %uses a rect for drawing
			me.szIsPx = false; % sizeOut will be in deg
			
			checkfilePath(me);
			
			me.ignoreProperties = [me.ignorePropertiesBase me.ignoreProperties];
			me.salutation('constructor','Movie Stimulus initialisation complete');
		end
		
		% ===================================================================
		%> @brief Setup this object in preperation for use
		%> When displaying a stimulus object, the main properties that are to be
		%> modified are copied into cache copies of the property, both to convert from 
		%> user-friendly visual description (c/d, Hz, degrees) to
		%> computer pixels metrics; and to be animated and modified as independant
		%> variables. So xPosition is copied to xPositionOut and converted from
		%> degrees to pixels. The animation and drawing functions use these modified
		%> properties, and when they are updated, for example to change to a new
		%> xPosition, internal methods ensure reconversion and update any dependent
		%> properties. This method initialises the object in preperation for display.
		%>
		%> @param sM screenManager object for reference
		% ===================================================================
		function setup(me, sM)
			
			reset(me);
			me.inSetup = true; me.isSetup = false;
			if isempty(me.isVisible); me.show; end
			
			me.sM = sM;
			if ~sM.isOpen; error('Screen needs to be Open!'); end
			
			checkfilePath(me);
			
			% On ARM set the default pixelFormat to 6 for shader based decode.
			% On a RaspberryPi-4 this makes a world of difference when playing
			% HD movies, between slow-motion 2 fps and proper 24 fps playback.
			if isempty(me.pixelFormat) && IsARM
				me.pixelFormat = 6;
			end
			
			me.ppd=sM.ppd;
			me.screenVals = sM.screenVals;
			me.texture = []; %we need to reset this
			
			fn = sort(fieldnames(me));
			for j=1:numel(fn)
				if ~matches(fn{j}, me.ignoreProperties)%create a temporary dynamic property
					p = addprop(me, [fn{j} 'Out']);
					if strcmp(fn{j},'xPosition');p.SetMethod = @set_xPositionOut;end
					if strcmp(fn{j},'yPosition');p.SetMethod = @set_yPositionOut;end
					me.([fn{j} 'Out']) = me.(fn{j}); %copy our property value to our tempory copy
				end
			end
			
			addRuntimeProperties(me);
			
			me.shader = [];
			if ~isempty(me.mask)
				me.shader = CreateSinglePassImageProcessingShader(me.sM.win, 'BackgroundMaskOut', me.mask, me.maskTolerance);
			end

			if me.circularMask
				me.masktex = CreateProceduralSmoothedDisc(me.sM.win, me.circularMaskSize, me.circularMaskSize, [], me.circularMaskRadius, me.circularMaskSmoothing, true, 2);
			end

			if me.autoShuffle > 0
				me.selection = randi(me.nVideos);
			end
			
			me.inSetup = false; me.isSetup = true;
			loadMovie(me);
			computePosition(me)
			setRect(me);

			function set_xPositionOut(me, value)
				me.xPositionOut = value * me.ppd;
			end
			function set_yPositionOut(me,value)
				me.yPositionOut = value*me.ppd; 
			end
		end

		% ===================================================================
		%> @brief Update this stimulus object structure for screenManager
		%>
		% ===================================================================
		function update(me)
			try Screen('PlayMovie', me.movie, 0); end
			Screen('SetMovieTimeIndex', me.movie, 0); %reset movie time
			if ~isempty(me.texture) && me.texture > 0 && Screen(me.texture,'WindowKind') == -1
				try Screen('Close',me.texture); end %#ok<*TRYNC>
			end
			if ~isempty(me.buffertex) && me.buffertex > 0 && Screen(me.buffertex,'WindowKind') == -1
				try Screen('Close',me.buffertex); end 
			end
			me.texture = []; me.buffertex = [];
			resetTicks(me);
			if ~matches(me.currentFile,me.filePaths{me.selectionOut})
				me.currentFile = me.filePaths{me.selectionOut};
				loadMovie(me);
			end
			if me.sizeOut > 0
				me.scale = me.sizeOut / (me.width / me.ppd);
			end
			computePosition(me);
			setRect(me);
		end
		
		% ===================================================================
		%> @brief Update only position info with pixels, faster and doesn't reset movie
		%>
		% ===================================================================
		function updatePositions(me,x,y)
			me.xFinal = x;
			me.yFinal = y;
			if length(me.mvRect) == 4
				me.mvRect=CenterRectOnPointd(me.mvRect, me.xFinal, me.yFinal);
			end
		end
		
		% ===================================================================
		%> @brief Draw this stimulus object
		%>
		% ===================================================================
		function draw(me)
			if me.isVisible && me.tick >= me.delayTicks && me.tick < me.offTicks

				if me.needPlayMovie
					fprintf('PLAY\n');
					Screen('PlayMovie', me.movie, 1, me.loopStrategy);
					me.shuffleTime = GetSecs;
					me.needPlayMovie = false;
				end

				if ~isempty(me.lockAngle); angle = me.directionOut+me.lockAngle; else; angle = me.angleOut; end

				if me.enforceBlending; Screen('BlendFunction', me.sM.win, me.msrcMode, me.mdstMode); end
				
				me.texture = Screen('GetMovieImage', me.sM.win, me.movie, me.blocking, [], me.specialFlagsFrame, me.specialFlags2Frame);
				if ~isempty(me.texture) && me.texture > 0
					if ~isempty(me.buffertex) && me.buffertex > 0 ...
					&& Screen(me.buffertex,'WindowKind') == -1
						Screen('Close', me.buffertex);
					end
					fprintf('*%i',me.tick);
					Screen('DrawTexture', me.sM.win, me.texture, [], me.mvRect,...
						angle,[],[],[],me.shader);
					me.buffertex = me.texture; %copy new texture to buffer
					me.texture = [];
				elseif ~isempty(me.buffertex) && me.buffertex > 0
					fprintf('.%i',me.tick);
					Screen('DrawTexture', me.sM.win, me.buffertex, [], me.mvRect,...
						angle,[],[],[],me.shader)
				end

				if me.circularMask
					Screen('DrawTexture', me.sM.win, me.masktex,   [], me.mvRect,...
						[], [], 1, me.sM.backgroundColour);
				end

				if me.enforceBlending; Screen('BlendFunction', me.sM.win, me.sM.srcMode, me.sM.dstMode); end

				me.drawTick = me.drawTick + 1;
			end
			if me.autoShuffle > 0 && GetSecs > (me.shuffleTime + me.autoShuffle)
				fprintf('SHUFFLE!\n');
				me.shuffleMovie();
				me.shuffleTime = GetSecs;
				me.tick = 0;
			end
			if me.isVisible; me.tick = me.tick + 1; end
		end
		
		% ===================================================================
		%> @brief Animate an structure for screenManager
		%>
		% ===================================================================
		function animate(me)
			if me.isVisible && me.tick >= me.delayTicks
				if me.mouseOverride
					getMousePosition(me);
					if me.mouseValid
						me.mvRect = CenterRectOnPoint(me.mvRect, me.mouseX, me.mouseY);
					end
					return
				end
				if me.doMotion == 1
					me.mvRect=OffsetRect(me.mvRect,me.dX_,me.dY_);
				end
			end
		end
		
		% ===================================================================
		%> @brief Reset an structure for screenManager
		%>
		% ===================================================================
		function reset(me)
			resetTicks(me);
			me.scale = 1;
			me.mvRect = [];
			me.dstRect = [];
			me.removeTmpProperties;
			ndrop=-1;
			if ~isempty(me.texture) && me.texture>0 ...
					&& Screen(me.texture,'WindowKind')==-1
				try Screen('Close',me.texture); end
			end
			if ~isempty(me.buffertex) && me.buffertex>0 ...
					&& Screen(me.buffertex,'WindowKind')==-1
				try Screen('Close',me.buffertex); end
			end
			me.buffertex = []; me.texture = []; ndrop = 0;
			if ~isempty(me.movie)
				try ndrop = Screen('Playmovie', me.movie, 0); end %#ok<*TRYNC>
				fprintf('---> Number of dropped movie frames: %i\n',ndrop)
				try Screen('CloseMovie', me.movie); end
			end
			if ~isempty(me.masktex) && me.masktex > 0 && Screen(me.masktex,'WindowKind') == -1
				try Screen('Close',me.masktex); end %#ok<*TRYNC>
				me.masktex = [];
			end
			me.shuffleTime = inf;
			me.needPlayMovie = false;
			me.shader = [];
			me.movie = [];
			me.duration = [];
			me.fps = [];
			me.width = [];
			me.height = [];
			me.inSetup = false; me.isSetup = false;
		end

		% ===================================================================
		%> @brief find a file or directory
		%>
		% ===================================================================
		function findFile(me, dir)
			if ~isprop(me, 'filePath'); return; end
			if ~exist('dir','var'); dir = true; end
			if dir
				p = uigetdir('Select Files Dir');
				f = '';
			else
				[f,p] = uigetfile({ '*.*',  'All Files (*.*)'},'Select File');
			end
			if ischar(f)
				me.filePath = [p f];
			end
			me.filePaths = {};
			me.currentFile = '';
			checkfilePath(me);
			fprintf('--->>> Found movie[s]:\n');
			for i = 1:length(me.filePaths)
				fprintf('\t %s\n',me.filePaths{i});
			end
		end

		% ===================================================================
		%> @brief switch to a new movie
		%>
		% ===================================================================
		function shuffleMovie(me)
			if me.nVideos < 2; return; end
			oldn = me.getP('selection');
			while true
				n = randi(me.nVideos);
				if n ~= oldn; break; end
			end
			me.setP('selection',n);
			update(me);
		end
		
	end %---END PUBLIC METHODS---%
	
	%=======================================================================
	methods ( Access = protected ) %-------PROTECTED METHODS-----%
	%=======================================================================
	
		% ===================================================================
		%> @brief loadMovie
		% ===================================================================
		function loadMovie(me)
			if ~me.isSetup; return; end
			if ~isempty(me.movie)
				try ndrop=Screen('Playmovie', me.movie, 0); end %#ok<*TRYNC>
				fprintf('---> Number of dropped movie frames: %i\n',ndrop)
				try Screen('CloseMovie', me.movie); end
				me.movie = []; me.width = []; me.height = [];
			end
			t=tic;
			% [ moviePtr [duration] [fps] [width] [height] [count] [aspectRatio] [hdrStaticMetaData]]=Screen('OpenMovie', 
			% windowPtr, moviefile [, async=0] [, preloadSecs=1] [, specialFlags1=0][, pixelFormat=4][, maxNumberThreads=-1][, movieOptions]);
			[me.movie, me.duration, me.fps, me.width, me.height] = Screen('OpenMovie', ...
				me.sM.win, me.currentFile, me.async, me.preloadSecs, me.specialFlagsOpen, me.pixelFormat);

			fprintf('\n--->>> movieStimulus: %s\n\t%.2f seconds duration, %i frames @ %f fps, w x h = %i x %i, in %ims\n', ...
				me.currentFile, me.duration, me.count, me.fps, me.width, me.height, round(toc(t)*1e3));
			fprintf('\tBlocking: %i | Loop: %i | Preloadsecs: %i | Pixelformat: %i | Flags: %i\n', me.blocking, ...
				me.loopStrategy, me.preloadSecs, me.pixelFormat, me.specialFlagsOpen);
			
			if ~isempty(me.movie)
				me.needPlayMovie = true; 
			else
				me.needPlay = false; 
			end
		end

		% ===================================================================
		%> @brief setRect
		%>  setRect makes the PsychRect based on the texture and screen values
		%>  This is overridden from parent class so we can scale texture
		%>  using the size value
		% ===================================================================
		function setRect(me)
			if ~isempty(me.movie)
				if me.sizeOut > 0
					me.scale = me.sizeOut / (me.width / me.ppd);
				end
				me.dstRect = ScaleRect([0 0 me.width me.height], me.scale, me.scale);
				if me.mouseOverride && me.mouseValid
					me.dstRect = CenterRectOnPointd(me.dstRect, me.mouseX, me.mouseY);
				else
					me.dstRect=CenterRectOnPointd(me.dstRect, me.xFinal, me.yFinal);
				end
				if me.verbose
					fprintf('---> stimulus TEXTURE dstRect = %5.5g %5.5g %5.5g %5.5g\n',me.dstRect(1), me.dstRect(2),me.dstRect(3),me.dstRect(4));
				end
				me.mvRect = me.dstRect;
				me.szPx = RectWidth(me.mvRect);
			end
		end
		
		% ===================================================================
		%> @brief 
		%>
		% ===================================================================
		function checkfilePath(me)
			me.filePath = regexprep(me.filePath, '^~\/', [getenv('HOME') filesep]);
			if isempty(me.filePath) || (me.selection==0 &&	exist(me.filePath,'file') ~= 2 && exist(me.filePath,'file') ~= 7)%use our default
				p = mfilename('fullpath');
				p = fileparts(p);
				me.filePath = [p filesep 'monkey-dance.avi'];
				me.filePaths{1} = me.filePath;
				me.selection = 1;
				fprintf('---> movieStimulus: Didn''t find specified file so replacing with default movie %s\n',me.filePath);
			elseif exist(me.filePath,'dir') == 7
				findFiles(me);
				if me.autoShuffle
					me.selection = randi(me.nVideos);
				end
			elseif me.selection > 1
				[p,f,e]=fileparts(me.filePath);
				for i = 1:me.selection
					me.filePaths{i} = [p filesep f num2str(i) e];
					if ~exist(me.filePaths{i},'file');warning('Movie %s not available!',me.filePaths{i});end
				end
			elseif exist(me.filePath,'file') == 2
				me.selection = 1;
				me.filePaths{1} = me.filePath;
			end
			me.currentFile = me.filePaths{me.selection};
		end

		% ===================================================================
		%> @brief findFiles
		%>  
		% ===================================================================
		function findFiles(me)	
			if exist(me.filePath,'dir') == 7
				d = dir(me.filePath);
				n = 0;
				for i = 1: length(d)
					if d(i).isdir; continue; end
					[~,f,e]=fileparts(d(i).name);
					if regexpi(e,'mp4|avi|mpeg')
						n = n + 1;
						me.filePaths{n} = [me.filePath filesep f e];
						me.filePaths{n} = regexprep(me.filePaths{n},'\/\/','/');
					end
				end
				me.nVideos = length(me.filePaths);
				if me.selection < 1 || me.selection > me.nVideos; me.selection = 1; end
			end
		end
		
	end %-------END PROTECTED METHODS-----%

end %-------END CLASSDEF-----%

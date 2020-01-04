% ========================================================================
%> @brief movieStimulus is the class for movie based stimulus objects
%>
%>
% ========================================================================	
classdef movieStimulus < baseStimulus	
	properties %--------------------PUBLIC PROPERTIES----------%
		type = 'movie'
		fileName = ''
		%> do we block when getting a frame? This is important, as if it is 1
		%> then you will drop frames waiting for the the synced video frame.
		%> Set to 0 this class uses double buffering to keep drawing the previous frame
		%> unitl a new frame is ready, ensuring other stimuli animate
		%> smoothly alongside the video. 
		blocking double = 0
		%> pixel format for opening movie? 6 is more efficient if H264 used
		pixelFormat double = []
		%> how many seconds to preload, -1 tries all
		preloadSecs double = -1
		%> additional special flags
		specialFlags1 double = []
		%> how to handle looping (1=PTB default)
		loopStrategy double = 1
		%> mask out a colour? e.g. [0 0 0]
		mask double = []
		%> mask tolerance
		maskTolerance double = [];
	end
	
	properties (SetAccess = protected, GetAccess = public)
		%> scale is dependent on stimulus size and movie width
		scale = 1
		family = 'movie'
		%> handle from OpenMovie
		movie
		duration
		fps
		width
		height
		count
	end
	
	properties (SetAccess = private, GetAccess = public, Hidden = true)
		typeList = {'movie'}
		fileNameList = 'filerequestor';
	end
	
	properties (SetAccess = private, GetAccess = private)
		%> shader for masking
		shader
		%> texture buffer for non-blocking movie playback, this is the
		%> previous frame until a new frame is available
		buffertex = []
		%> allowed properties passed to object upon construction
		allowedProperties='fileName|blocking|pixelFormat|preloadSecs|specialFlags1|loopStrategy|mask|maskTolerance';
		%>properties to not create transient copies of during setup phase
		ignoreProperties = 'movie|duration|fps|width|height|count|scale|fileName|pixelFormat|preloadSecs|specialFlags1|loopStrategy'
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
			if nargin == 0;varargin.name = 'movie stimulus';end
			args = optickaCore.addDefaults(varargin,...
				struct('size',0));
			me=me@baseStimulus(args); %we call the superclass constructor first
			me.parseArgs(args, me.allowedProperties);
			
			checkFileName(me);
			
			me.ignoreProperties = ['^(' me.ignorePropertiesBase '|' me.ignoreProperties ')$'];
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
			me.inSetup = true;
			
			checkFileName(me);
			
			if isempty(me.isVisible)
				me.show;
			end
			
			me.sM = sM;
			me.ppd=sM.ppd;

			fn = fieldnames(me);
			for j=1:length(fn)
				if isempty(me.findprop([fn{j} 'Out'])) && isempty(regexp(fn{j},me.ignoreProperties, 'once')) %create a temporary dynamic property
					p=me.addprop([fn{j} 'Out']);
					p.Transient = true;%p.Hidden = true;
					if strcmp(fn{j},'xPosition');p.SetMethod = @set_xPositionOut;end
					if strcmp(fn{j},'yPosition');p.SetMethod = @set_yPositionOut;end
				end
				if isempty(regexp(fn{j},me.ignoreProperties, 'once'))
					me.([fn{j} 'Out']) = me.(fn{j}); %copy our property value to our tempory copy
				end
			end
			
			if isempty(me.findprop('doDots'));p=me.addprop('doDots');p.Transient = true;end
			if isempty(me.findprop('doMotion'));p=me.addprop('doMotion');p.Transient = true;end
			if isempty(me.findprop('doDrift'));p=me.addprop('doDrift');p.Transient = true;end
			if isempty(me.findprop('doFlash'));p=me.addprop('doFlash');p.Transient = true;end
			me.doDots = false;
			me.doMotion = false;
			me.doDrift = false;
			me.doFlash = false;
			
			if me.speed>0 %we need to say this needs animating
				me.doMotion=true;
			else
				me.doMotion=false;
			end
			
			tic;
			[me.movie, me.duration, me.fps, me.width, me.height] = Screen('OpenMovie', ...
				me.sM.win, me.fileName, [], me.preloadSecs, me.specialFlags1, me.pixelFormat);
			fprintf('\n--->>> movieStimulus: %s\n\t%.2f seconds duration, %f fps, w x h = %i x %i, in %ims\n', ...
				me.fileName, me.duration, me.fps, me.width, me.height, round(toc*1e3));
			fprintf('\tBlocking: %i | Loop: %i | Preloadsecs: %i | Pixelformat: %i | Flags: %i\n', me.blocking, ...
				me.loopStrategy, me.preloadSecs, me.pixelFormat, me.specialFlags1);
			
			if me.sizeOut > 0
				me.scale = me.sizeOut / (me.width / me.ppd);
			end
			
			me.shader = [];
			if ~isempty(me.mask)
				me.shader = CreateSinglePassImageProcessingShader(me.sM.win, 'BackgroundMaskOut', me.mask, me.maskTolerance);
			end
			
			me.inSetup = false;
			computePosition(me)
			setRect(me);
		end

		% ===================================================================
		%> @brief Update this stimulus object structure for screenManager
		%>
		% ===================================================================
		function update(me)
			Screen('PlayMovie', me.movie, 0);
			Screen('SetMovieTimeIndex', me.movie, 0); %reset movie
			if ~isempty(me.texture) && me.texture > 0 && Screen(me.texture,'WindowKind') == -1
					try Screen('Close',me.texture); end %#ok<*TRYNC>
			elseif ~isempty(me.buffertex) && ~isempty(me.texture) && me.buffertex ~= me.texture && Screen(me.buffertex,'WindowKind') == -1
					try Screen('Close',me.buffertex); end 
			end
			me.texture = []; me.buffertex = [];
			if me.sizeOut > 0
				me.scale = me.sizeOut / (me.width / me.ppd);
			end
			resetTicks(me);
			computePosition(me);
			setRect(me);
		end
		
		% ===================================================================
		%> @brief Draw this stimulus object
		%>
		% ===================================================================
		function draw(me)
			if me.isVisible && me.tick >= me.delayTicks && me.tick < me.offTicks
				if me.tick == 0 || (me.delayTicks > 0 && me.tick == me.delayTicks) 
					Screen('PlayMovie', me.movie, 1, me.loopStrategy); 
				end
				me.texture = Screen('GetMovieImage', me.sM.win, me.movie, me.blocking);
				if me.texture > 0
					if ~isempty(me.buffertex) && ...
							me.buffertex > 0 && ...
							me.buffertex ~= me.texture && Screen(me.buffertex,'WindowKind') == -1
						try Screen('Close', me.buffertex); end
						me.buffertex=[]; 
					end
					Screen('DrawTexture', me.sM.win, me.texture, [], me.mvRect,[],[],[],[],me.shader);
					me.buffertex = me.texture; %copy new texture to buffer
				elseif me.buffertex > 0
					Screen('DrawTexture', me.sM.win, me.buffertex, [], me.mvRect,[],[],[],[],me.shader)
				end
				me.tick = me.tick + 1;
			end
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
						me.mvRect = CenterRectOnPointd(me.mvRect, me.mouseX, me.mouseY);
					end
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
			if ~isempty(me.texture) && me.texture>0 
				try Screen('Close',me.texture); end
				if me.texture ~= me.buffertex
					if ~isempty(me.buffertex) && me.buffertex>0; try Screen('Close',me.buffertex); end;	end
				end
				me.buffertex = []; me.texture = [];
			end
			if ~isempty(me.movie)
				try ndrop=Screen('Playmovie', me.movie, 0); end %#ok<*TRYNC>
				fprintf('---> Number of dropped movie frames: %i\n',ndrop)
				try Screen('CloseMovie', me.movie); end
			end
			me.movie = [];
		end
		
		% ===================================================================
		%> @brief 
		%>
		% ===================================================================
		function findFile(me)
			[f,p] = uigetfile({ '*.*',  'All Files (*.*)'},'Select Movie File');
			if ischar(f)
				me.fileName = [p f];
			end
		end
		
	end %---END PUBLIC METHODS---%
	
	%=======================================================================
	methods ( Access = protected ) %-------PROTECTED METHODS-----%
	%=======================================================================
	
		% ===================================================================
		%> @brief setRect
		%>  setRect makes the PsychRect based on the texture and screen values
		%>  This is overridden from parent class so we can scale texture
		%>  using the size value
		% ===================================================================
		function setRect(me)
			if ~isempty(me.movie)
				me.dstRect = CenterRect([0 0 me.width me.height],me.sM.winRect);
				me.dstRect = ScaleRect(me.dstRect, me.scale, me.scale);
				if me.mouseOverride && me.mouseValid
					me.dstRect = CenterRectOnPointd(me.dstRect, me.mouseX, me.mouseY);
				else
					me.dstRect=CenterRectOnPointd(me.dstRect, me.xOut, me.yOut);
				end
				if me.verbose
					fprintf('---> stimulus TEXTURE dstRect = %5.5g %5.5g %5.5g %5.5g\n',me.dstRect(1), me.dstRect(2),me.dstRect(3),me.dstRect(4));
				end
				me.mvRect = me.dstRect;
			end
		end
		
		% ===================================================================
		%> @brief 
		%>
		% ===================================================================
		function checkFileName(me)
			if isempty(me.fileName) || exist(me.fileName,'file') ~= 2
				p = mfilename('fullpath');
				p = fileparts(p);
				me.fileName = [p filesep 'monkey-dance.mp4'];
			end
		end
		
	end
	
	
	%=======================================================================
	methods ( Access = private ) %-------PRIVATE METHODS-----%
	%=======================================================================
		
	end
end
% ========================================================================
%> @brief movieStimulus is the class for movie based stimulus objects
%>
%>
% ========================================================================	
classdef movieStimulus < baseStimulus	
	properties %--------------------PUBLIC PROPERTIES----------%
		type = 'movie'
		fileName = ''
	end
	
	properties (SetAccess = protected, GetAccess = public)
		%> scale is set by size
		scale = 1
		family = 'movie'
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
		interpMethodList = {'nearest','linear','spline','cubic'}
	end
	
	properties (SetAccess = private, GetAccess = private)
		%> allowed properties passed to object upon construction
		allowedProperties='type|fileName';
		%>properties to not create transient copies of during setup phase
		ignoreProperties = 'movie|duration|fps|width|height|count|scale|fileName|interpMethod|pixelScale'
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
		function obj = movieStimulus(varargin)
			if nargin == 0;varargin.family = 'texture';end
			obj=obj@baseStimulus(varargin); %we call the superclass constructor first
			obj.size = 1; %override default
			if nargin>0
				obj.parseArgs(varargin, obj.allowedProperties);
			end
			
			if isempty(obj.fileName) %use our default
				p = mfilename('fullpath');
				p = fileparts(p);
				obj.fileName = [p filesep 'monkey.mp4'];
			end
			
			obj.ignoreProperties = ['^(' obj.ignorePropertiesBase '|' obj.ignoreProperties ')$'];
			obj.salutation('constructor','Texture Stimulus initialisation complete');
		end
		
		% ===================================================================
		%> @brief Setup this object in preperation for use
		%> When displaying a stimulus object, the main properties that are to be
		%> modified are copied into cache copies of the property, both to convert from 
		%> visual description (c/d, Hz, degrees) to
		%> computer metrics; and to be animated and modified as independant
		%> variables. So xPosition is copied to xPositionOut and converted from
		%> degrees to pixels. The animation and drawing functions use these modified
		%> properties, and when they are updated, for example to change to a new
		%> xPosition, internal methods ensure reconversion and update any dependent
		%> properties. This method initialises the object in preperation for display.
		%>
		%> @param sM screenManager object for reference
		%> @param in matrix for conversion to a PTB texture
		% ===================================================================
		function setup(obj,sM,in)
			
			reset(obj);
			obj.inSetup = true;
			if isempty(obj.isVisible)
				obj.show;
			end
			
			if ~exist('in','var')
				in = [];
			end
			
			if isempty(obj.isVisible)
				obj.show;
			end
			
			obj.sM = sM;
			obj.ppd=sM.ppd;

			fn = fieldnames(movieStimulus);
			for j=1:length(fn)
				if isempty(obj.findprop([fn{j} 'Out'])) && isempty(regexp(fn{j},obj.ignoreProperties, 'once')) %create a temporary dynamic property
					p=obj.addprop([fn{j} 'Out']);
					p.Transient = true;%p.Hidden = true;
					if strcmp(fn{j},'xPosition');p.SetMethod = @set_xPositionOut;end
					if strcmp(fn{j},'yPosition');p.SetMethod = @set_yPositionOut;end
				end
				if isempty(regexp(fn{j},obj.ignoreProperties, 'once'))
					obj.([fn{j} 'Out']) = obj.(fn{j}); %copy our property value to our tempory copy
				end
			end
			
			if isempty(obj.findprop('doDots'));p=obj.addprop('doDots');p.Transient = true;end
			if isempty(obj.findprop('doMotion'));p=obj.addprop('doMotion');p.Transient = true;end
			if isempty(obj.findprop('doDrift'));p=obj.addprop('doDrift');p.Transient = true;end
			if isempty(obj.findprop('doFlash'));p=obj.addprop('doFlash');p.Transient = true;end
			obj.doDots = false;
			obj.doMotion = false;
			obj.doDrift = false;
			obj.doFlash = false;
			
			if obj.speed>0 %we need to say this needs animating
				obj.doMotion=true;
 				%sM.task.stimIsMoving=[sM.task.stimIsMoving i];
			else
				obj.doMotion=false;
			end
			
			t=tic;
			preloadsecs = 2;
			flags1 = [];
			pixelformat = 4;
			[obj.movie, obj.duration, obj.fps, obj.width, obj.height] = Screen('OpenMovie', ...
				obj.sM.win, obj.fileName, [], preloadsecs, flags1, pixelformat);WaitSecs(0.5);
			fprintf('--->>> movieStimulus: %s  : %f seconds duration, %f fps, w x h = %i x %i, in %ims\n', obj.fileName, obj.duration, obj.fps, obj.width, obj.height, round(toc(t)*1e3));

			wdeg = obj.width / obj.ppd;
			hdeg = obj.height / obj.ppd;
			
			if obj.size > 0
				obj.scale = obj.sizeOut / wdeg;
			end
			
			obj.inSetup = false;
			computePosition(obj)
			setRect(obj);
		end

		% ===================================================================
		%> @brief Update this stimulus object structure for screenManager
		%>
		% ===================================================================
		function update(obj)
			obj.scale = obj.sizeOut;
			resetTicks(obj);
			computePosition(obj);
			setRect(obj);
			Screen('SetMovieTimeIndex', obj.movie, 0); %reset movie
		end
		
		% ===================================================================
		%> @brief Draw this stimulus object
		%>
		% ===================================================================
		function draw(obj)
			if obj.isVisible && obj.tick >= obj.delayTicks && obj.tick < obj.offTicks
				if obj.tick == 0; Screen('PlayMovie', obj.movie, 1, 1); end
				obj.texture = Screen('GetMovieImage', obj.sM.win, obj.movie);
				Screen('DrawTexture',obj.sM.win,obj.texture,[],obj.mvRect);
				Screen('Close',obj.texture);
				obj.tick = obj.tick + 1;
			end
		end
		
		% ===================================================================
		%> @brief Animate an structure for screenManager
		%>
		% ===================================================================
		function animate(obj)
			if obj.isVisible && obj.tick >= obj.delayTicks
				if obj.mouseOverride
					getMousePosition(obj);
					if obj.mouseValid
						obj.mvRect = CenterRectOnPointd(obj.mvRect, obj.mouseX, obj.mouseY);
					end
				end
				if obj.doMotion == 1
					obj.mvRect=OffsetRect(obj.mvRect,obj.dX_,obj.dY_);
				end
			end
		end
		
		% ===================================================================
		%> @brief Reset an structure for screenManager
		%>
		% ===================================================================
		function reset(obj)
			resetTicks(obj);
			obj.texture = [];
			obj.scale = 1;
			obj.mvRect = [];
			obj.dstRect = [];
			obj.removeTmpProperties;
			if ~isempty(obj.movie)
				try Screen('CloseMovie', obj.movie); end
			end
			obj.movie = [];
		end
		
		function findFile(me)
			[f,p] = uigetfile({ '*.*',  'All Files (*.*)'},'Select Movie File');
			if ischar(f)
				me.fileName = [p f];
			end
		end
		
		% ===================================================================
		%> @brief Run Stimulus in a window to preview
		%>
		% ===================================================================
		function run(obj, benchmark, runtime, s, forceScreen)
		% RUN stimulus: run(benchmark, runtime, s, forceScreen)
			try
				warning off
				if ~exist('benchmark','var') || isempty(benchmark)
					benchmark=false;
				end
				if ~exist('runtime','var') || isempty(runtime)
					runtime = 2; %seconds to run
				end
				if ~exist('s','var') || ~isa(s,'screenManager')
					s = screenManager('verbose',false,'blend',true,...
						'bitDepth','FloatingPoint32BitIfPossible','debug',false,...
						'disableSyncTests',true,...
						'srcMode','GL_SRC_ALPHA', 'dstMode', 'GL_ONE_MINUS_SRC_ALPHA',...
						'backgroundColour',[0.5 0.5 0.5 0]); %use a temporary screenManager object
				end
				if ~exist('forceScreen','var'); forceScreen = -1; end

				oldscreen = s.screen;
				oldbitdepth = s.bitDepth;
				if forceScreen >= 0
					s.screen = forceScreen;
					if forceScreen == 0
						s.bitDepth = 'FloatingPoint32BitIfPossible';
					end
				end
				prepareScreen(s);
				
				oldwindowed = s.windowed;
				if benchmark
					s.windowed = false;
				elseif forceScreen > -1
					s.windowed = [0 0 s.screenVals.width/2 s.screenVals.height/2]; %middle of screen
				end
				
				if ~s.isOpen
					open(s); %open PTB screen
				end
				setup(obj,s); %setup our stimulus object
				
				Priority(MaxPriority(s.win)); %bump our priority to maximum allowed
				
				if benchmark
					Screen('DrawText', s.win, 'BENCHMARK: screen won''t update properly, see FPS on command window at end.', 5,5,[0 0 0]);
				else
					Screen('DrawText', s.win, 'Stim will be static for 2 seconds, then animated...', 5,5,[0 0 0]);
				end
				
				Screen('Flip',s.win);
				WaitSecs('YieldSecs',2);
				vbl = Screen('Flip',s.win); b = vbl;
				
				while vbl <= b + runtime
					draw(obj); %draw stimulus
					Screen('DrawingFinished', s.win); %tell PTB/GPU to draw
					%animate(obj); %animate stimulus, will be seen on next draw
					if benchmark
						vbl = Screen('Flip',s.win,0,2,2);
					else
						vbl = Screen('Flip',s.win, vbl + s.screenVals.halfisi); %flip the buffer
					end
				end
				
				if benchmark; bb=GetSecs; end
				WaitSecs(1);
				Screen('Flip',s.win);
				WaitSecs(0.2);
				
				Priority(0);
				ShowCursor;
				ListenChar(0);
				reset(obj); %reset our stimulus ready for use again
				close(s); %close screen
				s.screen = oldscreen;
				s.windowed = oldwindowed;
				s.bitDepth = oldbitdepth;
				if benchmark
					fps = (s.screenVals.fps*runtime) / (bb-b);
					fprintf('\n\n======> SPEED = %g fps <=======\n', fps);
				end
				clear fps benchmark runtime b bb i; %clear up a bit
				warning on
			catch ME
				warning on
				getReport(ME)
				Priority(0);
				if exist('s','var') && isa(s,'screenManager')
					close(s);
				end
				warning on
				clear fps benchmark runtime b bb i; %clear up a bit
				reset(obj); %reset our stimulus ready for use again
				rethrow(ME)				
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
		function setRect(obj)
			if ~isempty(obj.movie)
				obj.dstRect = CenterRect([0 0 obj.width obj.height],obj.sM.winRect);
				obj.dstRect = ScaleRect(obj.dstRect, obj.scale, obj.scale);
				if obj.mouseOverride && obj.mouseValid
					obj.dstRect = CenterRectOnPointd(obj.dstRect, obj.mouseX, obj.mouseY);
				else
					obj.dstRect=CenterRectOnPointd(obj.dstRect, obj.xOut, obj.yOut);
				end
				if obj.verbose
					fprintf('---> stimulus TEXTURE dstRect = %5.5g %5.5g %5.5g %5.5g\n',obj.dstRect(1), obj.dstRect(2),obj.dstRect(3),obj.dstRect(4));
				end
				obj.mvRect = obj.dstRect;
			end
		end
		
	end
	
	
	%=======================================================================
	methods ( Access = private ) %-------PRIVATE METHODS-----%
	%=======================================================================
		
	end
end
classdef dotsStimulus < baseStimulus
	%DOTSSTIMULUS single coherent dots stimulus, inherits from baseStimulus
	%   The current properties are:
	
	properties %--------------------PUBLIC PROPERTIES----------%
		family = 'dots'
		type = 'simple'
		nDots = 100 % number of dots
		colourType = 'randomBW'
		dotSize  = 0.1  % width of dot (deg)
		coherence = 0.5
		kill      = 0.2 % fraction of dots to kill each frame  (limited lifetime)
		dotType = 2
	end
	
	properties (SetAccess = private, GetAccess = public)
		xy
		dxdy
		colours
	end
	properties (SetAccess = private, GetAccess = private)
		antiAlias = 4
		rDots
		angles
		dSize
		fps = 60
		dx
		dy
		allowedProperties='^(type|speed|nDots|dotSize|angle|colourType|coherence|dotType|kill)$';
		ignoreProperties='xy|dxdy|colours|colourType'
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
		function obj = dotsStimulus(args)
			%Initialise for superclass, stops a noargs error
			if nargin == 0
				args.family = 'dots';
			end
			obj=obj@baseStimulus(args); %we call the superclass constructor first
			%check we are a grating
			if ~strcmp(obj.family,'dots')
				error('Sorry, you are trying to call a dotsStimulus with a family other than dots');
			end
			%start to build our parameters
			if nargin>0 && isstruct(args)
				fnames = fieldnames(args); %find our argument names
				for i=1:length(fnames);
					if regexp(fnames{i},obj.allowedProperties) %only set if allowed property
						obj.salutation(fnames{i},'Configuring setting in dotsStimulus constructor');
						obj.(fnames{i})=args.(fnames{i}); %we set up the properies from the arguments as a structure
					end
				end
			end
			obj.ignoreProperties = ['^(' obj.ignorePropertiesBase '|' obj.ignoreProperties ')$'];
			obj.salutation('constructor','Dots Stimulus initialisation complete');
		end
		
		% ===================================================================
		%> @brief Setup an structure for runExperiment
		%>
		%> @param 
		%> @return 
		% ===================================================================
		%-------------------Set up our dot matrices----------------------%
		function initialiseDots(obj)
			
			%sort out our angles and percent incoherent
			obj.angles=ones(obj.nDots,1).*obj.d2r(obj.angle);
			obj.rDots=obj.nDots-floor(obj.nDots*(obj.coherence));
			if obj.rDots>0
				obj.angles(1:obj.rDots)=(2*pi).*rand(1,obj.rDots);
				obj.angles = Shuffle(obj.angles); %if we don't shuffle them, all coherent dots show on top!
			end
			
			%make our dot colours
			switch obj.colourType
				case 'random'
					obj.colours = randn(4,obj.nDots);
					obj.colours(4,:) = obj.alpha;
				case 'randomBW'
					obj.colours=zeros(4,obj.nDots);
					for i = 1:obj.nDots
						obj.colours(:,i)=rand;
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
			
			%calculate positions and vector offsets
			obj.xy = (obj.sizeOut).*rand(2,obj.nDots);
			obj.xy = obj.xy - (obj.size*obj.ppd)/2; %so we are centered for -xy to +xy
			[obj.dx, obj.dy] = obj.updatePosition(repmat(obj.delta,size(obj.angles)),obj.angles);
			obj.dxdy=[obj.dx';obj.dy'];
			
		end
		
		% ===================================================================
		%> @brief Update the dots per frame and wrap dots that exceed the size
		%>
		%> @param coherence
		%> @param angle
		% ===================================================================
		function updateDots(obj,coherence,angle)
			
			if exist('coherence','var') %we need a new full set of values
				if ~exist('angle','var')
					angle = obj.angle;
				end
				%sort out our angles and percent incoherent
				obj.angles=ones(obj.nDots,1).*obj.d2r(angle);
				obj.rDots=obj.nDots-floor(obj.nDots*(coherence));
				if obj.rDots>0
					obj.angles(1:obj.rDots)=(2*pi).*rand(1,obj.rDots);
					obj.angles = Shuffle(obj.angles); %if we don't shuffle them, all coherent dots show on top!
				end
				%calculate positions and vector offsets
				obj.xy = (obj.size*obj.ppd).*rand(2,obj.nDots);
				obj.xy = obj.xy - (obj.size*obj.ppd)/2; %so we are centered for -xy to +xy
				[obj.dx, obj.dy] = obj.updatePosition(repmat(obj.delta,size(obj.angles)),obj.angles);
				obj.dxdy=[obj.dx';obj.dy'];
			else %just update our dot positions
				obj.xy=obj.xy+obj.dxdy; %increment position
				fix=find(obj.xy > ((obj.size*obj.ppd)/2)); %cull positive
				obj.xy(fix)=obj.xy(fix)-(obj.size*obj.ppd);
				fix=find(obj.xy < -(obj.size*obj.ppd)/2);  %cull negative
				obj.xy(fix)=obj.xy(fix)+(obj.size*obj.ppd);
			end
		end
		
		% ===================================================================
		%> @brief Setup an structure for runExperiment
		%>
		%> @param rE runExperiment object for reference
		%> @return
		% ===================================================================
		function setup(obj,rE)
			
			if exist('rE','var')
				obj.ppd=rE.ppd;
				obj.ifi=rE.screenVals.ifi;
				obj.xCenter=rE.xCenter;
				obj.yCenter=rE.yCenter;
				obj.win=rE.win;
			end
			
			fn = fieldnames(dotsStimulus);
			for j=1:length(fn)
				if isempty(obj.findprop([fn{j} 'Out'])) && isempty(regexp(fn{j},obj.ignoreProperties, 'once')) %create a temporary dynamic property
					p=obj.addprop([fn{j} 'Out']);
					p.Transient = true;%p.Hidden = true;
					if strcmp(fn{j},'size');p.SetMethod = @setsizeOut;end
					if strcmp(fn{j},'dotSize');p.SetMethod = @setdotSizeOut;end
					if strcmp(fn{j},'xPosition');p.SetMethod = @setxPositionOut;end
					if strcmp(fn{j},'yPosition');p.SetMethod = @setyPositionOut;end
				end
				if isempty(regexp(fn{j},obj.ignoreProperties, 'once'))
					obj.([fn{j} 'Out']) = obj.(fn{j}); %copy our property value to our tempory copy
				end
			end
			
			if isempty(obj.findprop('doDots'));p=obj.addprop('doDots');p.Transient = true;end
			if isempty(obj.findprop('doMotion'));p=obj.addprop('doMotion');p.Transient = true;end
			if isempty(obj.findprop('doDrift'));p=obj.addprop('doDrift');p.Transient = true;end
			if isempty(obj.findprop('doFlash'));p=obj.addprop('doFlash');p.Transient = true;end
			obj.doDots = [];
			obj.doMotion = [];
			obj.doDrift = [];
			obj.doFlash = [];
			
			if isempty(obj.findprop('xTmp'));p=obj.addprop('xTmp');p.Transient = true;end
			if isempty(obj.findprop('yTmp'));p=obj.addprop('yTmp');p.Transient = true;end
			obj.xTmp = obj.xPositionOut; %xTmp and yTmp are temporary position stores.
			obj.yTmp = obj.yPositionOut;
			
			obj.initialiseDots();

		end
		
		% ===================================================================
		%> @brief Update an structure for runExperiment
		%>
		%> @param rE runExperiment object for reference
		%> @return stimulus structure.
		% ===================================================================
		function update(obj,rE)
			
		end
		
		% ===================================================================
		%> @brief Draw an structure for runExperiment
		%>
			%> @param rE runExperiment object for reference
		%> @return stimulus structure.
		% ===================================================================
		function draw(obj,rE)
			Screen('DrawDots',obj.win,obj.xy,obj.dotSizeOut,obj.colours,...
				[obj.xPositionOut obj.yPositionOut],obj.dotTypeOut);
		end
		
		% ===================================================================
		%> @brief Animate an structure for runExperiment
		%>
		%> @param rE runExperiment object for reference
		%> @return stimulus structure.
		% ===================================================================
		function animate(obj)
			obj.updateDots();
		end
		
		% ===================================================================
		%> @brief Reset an structure for runExperiment
		%>
		%> @param rE runExperiment object for reference
		%> @return stimulus structure.
		% ===================================================================
		function reset(obj,rE)
			
		end
		
		% ===================================================================
		%> @brief Reset an structure for runExperiment
		%>
		%> @param rE runExperiment object for reference
		%> @return stimulus structure.
		% ===================================================================
		function run(obj)
						
			obj.dSize = obj.dotSize * obj.ppd;
			
			try
				Screen('Preference', 'SkipSyncTests', 2);
				Screen('Preference', 'VisualDebugLevel', 0);
				PsychImaging('PrepareConfiguration');
				PsychImaging('AddTask', 'General', 'FloatingPoint32BitIfPossible');
				PsychImaging('AddTask', 'General', 'NormalizedHighresColorRange');
				[w, rect]=PsychImaging('OpenWindow', 0, 0.5,[1 1 801 601], [], 2,[],obj.antiAlias);
				%[w, rect] = Screen('OpenWindow', screenNumber, 0,[1 1 801 601],[], 2);
				Screen('BlendFunction', w, GL_ONE, GL_ONE);
				[center(1), center(2)] = RectCenter(rect);
				obj.fps=Screen('FrameRate',w);      % frames per second
				obj.ifi=Screen('GetFlipInterval', w);
				if obj.fps==0
					obj.fps=1/obj.ifi;
				end;
				
				obj.angles=ones(obj.nDots,1).*ang2rad(obj.angle);
				obj.rDots=obj.nDots-floor(obj.nDots*(obj.coherence));
				if obj.rDots>0
					obj.angles(1:obj.rDots)=(2*pi).*rand(1,obj.rDots);
				end
				
				switch obj.colourType
					case 'random'
						obj.colours = randn(4,obj.nDots);
						obj.colours(4,:) = obj.alpha;
					case 'randomBW'
						obj.colours=zeros(4,obj.nDots);
						for i = 1:obj.nDots
							obj.colours(:,i)=rand;
						end
						obj.colours(4,:)=obj.alpha;
					case 'binary'
						obj.colours=zeros(4,obj.nDots);
						rix = round(rand(obj.nDots,1)) > 0;
						obj.colours(:,rix) = 1;
						obj.colours(4,:)=obj.alpha; %set the alpha level
					otherwise
						obj.colours=obj.colour;
						obj.colours(4)=obj.dotAlpha;
				end
				
				obj.xy = (obj.size*obj.ppd).*rand(2,obj.nDots);
				obj.xy = obj.xy - (obj.size*obj.ppd)/2; %so we are centered for -xy to +xy
				[obj.dx, obj.dy] = obj.updatePosition(repmat(obj.pfs,size(obj.angles)),obj.angles);
				obj.dxdy=[obj.dx';obj.dy'];
				
				vbl=Screen('Flip', w);
				while 1
					Screen('DrawDots', w, obj.xy, obj.dSize, obj.colours, center, 1);  % change 1 to 0 to draw square dots
					Screen('gluDisk',w,[1 1 0],center(1),center(2),5);
					Screen('DrawingFinished', w); % Tell PTB that no  further drawing commands will follow before Screen('Flip')

					[~, ~, buttons]=GetMouse(0);
					if any(buttons) % break out of loop
						break;
					end;
					obj.xy=obj.xy+obj.dxdy;
					fix=find(obj.xy > ((obj.size*obj.ppd)/2));
					obj.xy(fix)=obj.xy(fix)-(obj.size*obj.ppd);
					fix=find(obj.xy < -(obj.size*obj.ppd)/2);
					obj.xy(fix)=obj.xy(fix)+(obj.size*obj.ppd);
					vbl=Screen('Flip', w);
				end
				
				Priority(0);
				ShowCursor
				Screen('CloseAll');
				
			catch ME
				Priority(0);
				ShowCursor
				Screen('CloseAll');
				rethrow(ME)
			end
		end
	end
	
	
	%---END PUBLIC METHODS---%
	
	methods ( Access = private ) %----------PRIVATE METHODS---------%
		% ===================================================================
		%> @brief sfOut Set method
		%>
		% ===================================================================
		function setsizeOut(obj,value)
			obj.sizeOut = value * obj.ppd;
		end
		
		% ===================================================================
		%> @brief sfOut Set method
		%>
		% ===================================================================
		function setdotSizeOut(obj,value)
			obj.dotSizeOut = value * obj.ppd;
		end
		
		% ===================================================================
		%> @brief xPositionOut Set method
		%>
		% ===================================================================
		function setxPositionOut(obj,value)
			obj.xPositionOut = obj.xCenter + (value * obj.ppd);
		end
		
		% ===================================================================
		%> @brief yPositionOut Set method
		%>
		% ===================================================================
		function setyPositionOut(obj,value)
			obj.yPositionOut = obj.yCenter + (value * obj.ppd);
		end
	end
end
classdef dotsStimulus < baseStimulus
	%DOTSSTIMULUS single coherent dots stimulus, inherits from baseStimulus
	%   The current properties are:
	
	properties %--------------------PUBLIC PROPERTIES----------%
		family = 'dots'
		type = 'simple'
		speed = 1    % dot speed (deg/sec)
		nDots = 100 % number of dots
		angle = 0
		colourType = 'randomBW'
		dotSize  = 0.2  % width of dot (deg)
		coherence = 0.5;
		kill      = 0.2 % fraction of dots to kill each frame  (limited lifetime)
		dotType = 2;
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
		ppd = 44
		ifi
		fps = 60
		delta
		dx
		dy
		allowedProperties='^(type|speed|nDots|dotSize|angle|colourType|coherence|dotType|kill)$';
	end
	
	methods %----------PUBLIC METHODS---------%
		%-------------------CONSTRUCTOR----------------------%
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
			
			obj.ifi = 1/obj.fps;
			obj.delta = obj.speed * obj.ppd * obj.ifi;% dot  speed (pixels/frame)
			obj.dSize = obj.dotSize* obj.ppd;
			
			obj.salutation('constructor','Dots Stimulus initialisation complete');
		end
		
		%-------------------Set up our dot matrices----------------------%
		function initialiseDots(obj,in)
			obj.ppd = in.ppd;
			obj.ifi = in.ifi;
			obj.delta = obj.speed * obj.ppd * obj.ifi;% dot  speed (pixels/frame)
			
			%sort out our angles and percent incoherent
			obj.angles=ones(obj.nDots,1).*obj.d2r(obj.angle);
			obj.rDots=obj.nDots-floor(obj.nDots*(obj.coherence));
			if obj.rDots>0
				obj.angles(1:obj.rDots)=(2*pi).*rand(1,obj.rDots);
				obj.angles = shuffle(obj.angles); %if we don't shuffle them, all coherent dots show on top!
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
			obj.xy = (obj.size*obj.ppd).*rand(2,obj.nDots);
			obj.xy = obj.xy - (obj.size*obj.ppd)/2; %so we are centered for -xy to +xy
			[obj.dx, obj.dy] = obj.updatePosition(repmat(obj.delta,size(obj.angles)),obj.angles);
			obj.dxdy=[obj.dx';obj.dy'];
			
		end
		
		function updateDots(obj,coherence)
			
			if exist('coherence','var') %we need a new full set of values
				%sort out our angles and percent incoherent
				obj.angles=ones(obj.nDots,1).*obj.d2r(obj.angle);
				obj.rDots=obj.nDots-floor(obj.nDots*(coherence));
				if obj.rDots>0
					obj.angles(1:obj.rDots)=(2*pi).*rand(1,obj.rDots);
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
		
		function run(obj)
			try
				Screen('Preference', 'SkipSyncTests', 2);
				Screen('Preference', 'VisualDebugLevel', 0);
				PsychImaging('PrepareConfiguration');
				PsychImaging('AddTask', 'General', 'FloatingPoint32BitIfPossible');
				PsychImaging('AddTask', 'General', 'NormalizedHighresColorRange');
				[w, rect]=PsychImaging('OpenWindow', 0, 0.5,[1 1 801 601], [], 2,[],obj.antiAlias);
				%[w, rect] = Screen('OpenWindow', screenNumber, 0,[1 1 801 601],[], 2);
				Screen('BlendFunction', w, GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
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
		
		function [dX dY] = updatePosition(obj,delta,angle)
			dX = delta .* cos(angle);
			dY = delta .* sin(angle);
		end
		
		function r = d2r(obj,degrees)
			r=degrees*(pi/180);
			return
		end
		
		function degrees=r2d(obj,radians)
			degrees=radians*(180/pi);
		end
		
		function distance=findDistance(obj,x1,y1,x2,y2)
			dx = x2 - x1;
			dy = y2 - y1;
			distance=sqrt(dx^2 + dy^2);
		end
	end
end
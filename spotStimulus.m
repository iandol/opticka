classdef spotStimulus < baseStimulus
%BARSTIMULUS single bar stimulus, inherits from baseStimulus
%   The current properties are:

   properties %--------------------PUBLIC PROPERTIES----------%
		family = 'spot'
		type = 'normal'
		flashTime = [0.5 0.5]
		speed = 0
		angle = 0
	end
	
	properties (SetAccess = private, GetAccess = public)
		flashSegment = 1
		dX
		dY
	end
	
	properties (SetAccess = private, GetAccess = private)
		allowedProperties='^(type|flashTime|speed)$';
	end
	
   methods %----------PUBLIC METHODS---------%
		%-------------------CONSTRUCTOR----------------------%
		function obj = spotStimulus(args) 
			%Initialise for superclass, stops a noargs error
			if nargin == 0
				args.family = 'spot';
			end
			obj=obj@baseStimulus(args); %we call the superclass constructor first
			if nargin>0 && isstruct(args)
				fnames = fieldnames(args); %find our argument names
				for i=1:length(fnames);
					if regexp(fnames{i},obj.allowedProperties) %only set if allowed property
						obj.salutation(fnames{i},'Configuring setting in spotStimulus constructor');
						obj.(fnames{i})=args.(fnames{i}); %we set up the properies from the arguments as a structure
					end
				end
			end
			obj.salutation('constructor','Spot Stimulus initialisation complete');
		end
		
		function updatePosition(obj,angle,delta)
			obj.dX= delta * cos(ang2rad(angle));
			obj.dY= delta * sin(ang2rad(angle));
		end
		
		
	end %---END PUBLIC METHODS---%
	
	methods ( Access = private ) %----------PRIVATE METHODS---------%
		
	end
end
classdef spotStimulus < baseStimulus
%SPOTSTIMULUS single bar stimulus, inherits from baseStimulus
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
	end
	
	properties (SetAccess = private, GetAccess = private)
		allowedProperties='^(type|flashTime|speed|angle)$';
	end
	
   methods %----------PUBLIC METHODS---------%
		% ===================================================================
		%> @brief Class constructor
		%>
		%> More detailed description of what the constructor does.
		%>
		%> @param args are passed as a structure of properties which is
		%> parsed.
		%> @return instance of the class.
		% ===================================================================
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
		
		% ===================================================================
		%> @brief Setup an structure for runExperiment
		%>
		%> @param rE runExperiment object for reference
		%> @return stimulus structure.
		% ===================================================================
		function out = setup(obj,rE)
			
			out.doDots = [];
			out.doMotion = [];
			out.doDrift = [];
			
			fn = fieldnames(obj);
			for j=1:length(fn)
				out.(fn{j}) = obj.(fn{j}); %copy our object propert value to our out
				if isempty(obj.findprop(['t' fn{j}])) %create a temporary dynamic property
					p=obj.addprop(['t' fn{j}]);
					p.Transient = true;
					p.Hidden = true;
				end
				obj.(['t' fn{j}]) = obj.(fn{j}); %copy our property value to our tempory copy
			end
			
			out.size = (out.size*rE.ppd) / 2; %divide by 2 to get diameter
			out.delta = out.speed * rE.ppd * rE.screenVals.ifi;
			out.xPosition = rE.xCenter+(out.xPosition*rE.ppd);
			out.yPosition = rE.yCenter+(out.yPosition*rE.ppd);
			
			out.xT = out.xPosition; %xT and yT are temporary position stores.
			out.yT = out.yPosition;
			
			[out.dX out.dY] = obj.updatePosition(out.delta,out.angle);
			
			if length(out.colour) == 3
				out.colour = [out.colour out.alpha];
			end
		end
		
		% ===================================================================
		%> @brief Update an structure for runExperiment
		%>
		%> @param rE runExperiment object for reference
		%> @return stimulus structure.
		% ===================================================================
		function out = update(obj,rE)
			
		end
		
		% ===================================================================
		%> @brief Draw an structure for runExperiment
		%>
		%> @param rE runExperiment object for reference
		%> @return stimulus structure.
		% ===================================================================
		function out = draw(obj,rE)
			
		end
		
		
	end %---END PUBLIC METHODS---%
	
	methods ( Access = private ) %----------PRIVATE METHODS---------%
		
	end
end
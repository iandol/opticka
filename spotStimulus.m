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

			fn = fieldnames(obj);
			for j=1:length(fn)
				if isempty(obj.findprop([fn{j} 'Out'])) %create a temporary dynamic property
					p=obj.addprop([fn{j} 'Out']);
					p.Transient = true;%p.Hidden = true;
				end
				obj.([fn{j} 'Out']) = obj.(fn{j}); %copy our property value to our tempory copy
			end
			
			if isempty(obj.findprop('doDots'));obj.addprop('doDots');end
			if isempty(obj.findprop('doMotion'));obj.addprop('doMotion');end
			if isempty(obj.findprop('doDrift'));obj.addprop('doDrift');end
			obj.doDots = [];
			obj.doMotion = [];
			obj.doDrift = [];
			
			obj.sizeOut = (obj.size*rE.ppd) / 2; %divide by 2 to get diameter
			obj.delta = obj.speed * rE.ppd * rE.screenVals.ifi;
			obj.xPositionOut = rE.xCenter+(obj.xPosition*rE.ppd);
			obj.yPositionOut = rE.yCenter+(obj.yPosition*rE.ppd);
			
			if isempty(obj.findprop('xTmp'));obj.addprop('xTmp');end
			if isempty(obj.findprop('yTmp'));obj.addprop('yTmp');end
			obj.xTmp = obj.xPositionOut; %xT and yT are temporary position stores.
			obj.yTmp = obj.yPositionOut;
			
			[obj.dX obj.dY] = obj.updatePosition(obj.delta,obj.angleOut);
			
			if length(obj.colour) == 3
				obj.colour = [obj.colour obj.alpha];
			end
			
			out = obj.toStructure;
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
			Screen('gluDisk',rE.win,obj.tcolour,obj.txT,obj.tyT,obj.tsize);
		end
		
		
	end %---END PUBLIC METHODS---%
	
	methods ( Access = private ) %----------PRIVATE METHODS---------%
		
	end
end
classdef spotStimulus < baseStimulus
%SPOTSTIMULUS single bar stimulus, inherits from baseStimulus
%   The current properties are:

   properties %--------------------PUBLIC PROPERTIES----------%
		family = 'spot'
		type = 'normal'
		flashTime = [0.5 0.5]
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
			
			if exist('rE','var')
				obj.ppd=rE.ppd;
				obj.ifi=rE.screenVals.ifi;
				obj.xCenter=rE.xCenter;
				obj.yCenter=rE.yCenter;
				obj.win=rE.win;
			end

			fn = fieldnames(spotStimulus);
			for j=1:length(fn)
				if isempty(obj.findprop([fn{j} 'Out'])) && isempty(regexp(fn{j},obj.ignoreProperties, 'once'))%create a temporary dynamic property
					p=obj.addprop([fn{j} 'Out']);
					p.Transient = true;%p.Hidden = true;
					if strcmp(fn{j},'size');p.SetMethod = @setsizeOut;end
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

			out = obj.toStructure;
		end
		
		% ===================================================================
		%> @brief Update an structure for runExperiment
		%>
		%> @param rE runExperiment object for reference
		%> @return stimulus structure.
		% ===================================================================
		function update(obj)
			
		end
		
		% ===================================================================
		%> @brief Draw an structure for runExperiment
		%>
		%> @param rE runExperiment object for reference
		%> @return stimulus structure.
		% ===================================================================
		function draw(obj)
			Screen('gluDisk',obj.win,obj.colourOut,obj.xTmp,obj.yTmp,obj.sizeOut);
		end
		
		% ===================================================================
		%> @brief Animate an structure for runExperiment
		%>
		%> @param rE runExperiment object for reference
		%> @return stimulus structure.
		% ===================================================================
		function animate(obj)
			
		end
		
		% ===================================================================
		%> @brief Reset an structure for runExperiment
		%>
		%> @param rE runExperiment object for reference
		%> @return stimulus structure.
		% ===================================================================
		function reset(obj)
			
		end
		
		
	end %---END PUBLIC METHODS---%
	
	%=======================================================================
	methods ( Access = private ) %-------PRIVATE METHODS-----%
	%=======================================================================
		% ===================================================================
		%> @brief sizeOut Set method
		%>
		% ===================================================================
		function setsizeOut(obj,value)
			obj.sizeOut = (value*obj.ppd) / 2; %divide by 2 to get diameter
		end
		
		% ===================================================================
		%> @brief xPositionOut Set method
		%>
		% ===================================================================
		function setxPositionOut(obj,value)
			obj.xPositionOut = obj.xCenter+(value*obj.ppd);
		end
		
		% ===================================================================
		%> @brief yPositionOut Set method
		%>
		% ===================================================================
		function setyPositionOut(obj,value)
			obj.yPositionOut = obj.yCenter+(value*obj.ppd);
		end
	end
end
% ========================================================================
%> @brief baseStimulus is the superclass for opticka stimulus objects
%>
%> Superclass providing basic structure for all stimulus classes
	%>
% ========================================================================
classdef baseStimulus < dynamicprops
	%BASESTIMULUS Superclass providing basic structure for all stimulus
	%classes
	%   Detailed explanation to come
	properties
		%> X Position in degrees relative to screen center
		xPosition = 0
		%> Y Position in degrees relative to screen center
		yPosition = 0
		%> Size in degrees
		size = 2
		%> Colour as a 0-1 range RGBA
		colour = [0.5 0.5 0.5]
		%> Alpha as a 0-1 range
		alpha = 1
		%> Do we print details to the commandline?
		verbose=0
		%> For moving stimuli do we start "before" our initial position?
		startPosition=0
		%> speed in degs/s
		speed = 0
		%> angle in degrees
		angle = 0
	end
	
	properties (SetAccess = protected, GetAccess = public)
		%> Our screen rectangle position in PTB format
		dstRect
		%> Our screen rectangle position in PTB format
		mvRect
		%> Our texture pointer for texture-based stimuli
		texture
	end
	
	properties (Dependent = true, SetAccess = private, GetAccess = public)
		%> What our per-frame motion delta is
		delta
		%> X update which is computed from our speed and angle
		dX
		%> X update which is computed from our speed and angle
		dY
	end
	
	properties (SetAccess = protected, GetAccess = protected)
		%> pixels per degree (calculated in runExperiment)
		ppd = 44
		%> Inter frame interval (calculated in runExperiment)
		ifi = 0.0167
		%> computed X center (calculated in runExperiment)
		xCenter = []
		%> computed Y center (calculated in runExperiment)
		yCenter = []
		%> window to attach to
		win = []
		%>screen to use
		screen = 0
		%> Which properties to ignore to clone when making transient copies in
		%> the setup method
		ignoreProperties=['^(dX|dY|delta|verbose|texture|dstRect|' ...
			'mvRect|xy|dxdy|colours|family|type|flashCounter|currentColour)$'];
	end
	
	properties (SetAccess = private, GetAccess = private)
		allowedPropertiesBase='^(xPosition|yPosition|size|colour|verbose|alpha|startPosition|angle|speed)$'
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
		function obj = baseStimulus(args)
			if nargin>0 && isstruct(args)
				if nargin>0 && isstruct(args)
					fnames = fieldnames(args); %find our argument names
					for i=1:length(fnames);
						if regexp(fnames{i},obj.allowedPropertiesBase) %only set if allowed property
							obj.salutation(fnames{i},'Configuring setting in baseStimulus constructor');
							obj.(fnames{i})=args.(fnames{i}); %we set up the properies from the arguments as a structure
						end
					end
				end
			end
		end 
	
		% ===================================================================
		%> @brief colour Get method
		%>
		% ===================================================================
		function value = get.colour(obj)
			if length(obj.colour) == 1
				value = [obj.colour obj.colour obj.colour];
			elseif length(obj.colour) == 3
				value = [obj.colour obj.alpha];
			else
				value = [obj.colour];
			end
		end
		
		% ===================================================================
		%> @brief delta Get method
		%>
		% ===================================================================
		function value = get.delta(obj)
			if isempty(obj.findprop('speedOut'));
				value = (obj.speed * obj.ppd) * obj.ifi;
			else
				value = (obj.speedOut * obj.ppd) * obj.ifi;
			end
		end
		
		% ===================================================================
		%> @brief dX Get method
		%>
		% ===================================================================
		function value = get.dX(obj)
			if isempty(obj.findprop('angleOut'));
				[value,~]=obj.updatePosition(obj.delta,obj.angle);
			else
				[value,~]=obj.updatePosition(obj.delta,obj.angleOut);
			end
		end
		
		% ===================================================================
		%> @brief dY Get method
		%>
		% ===================================================================
		function value = get.dY(obj)
			if isempty(obj.findprop('angleOut'));
				[~,value]=obj.updatePosition(obj.delta,obj.angle);
			else
				[~,value]=obj.updatePosition(obj.delta,obj.angleOut);
			end
		end
		
	end %---END PUBLIC METHODS---%
	
	%=======================================================================
	methods (Abstract)%------------------ABSTRACT METHODS
	%=======================================================================
		%> initialise the stimulus
		out = setup(runObject)
		%> update the stimulus
		out = update(runObject)
		%>draw to the screen buffer
		out = draw(runObject)
		%> animate the settings
		out = animate(runObject)
		%> reset to default values
		out = reset(runObject) 
	end %---END ABSTRACT METHODS---%
	
	%=======================================================================
	methods ( Static ) %----------STATIC METHODS
	%=======================================================================
	
		% ===================================================================
		%> @brief degrees2radians
		%>
		% ===================================================================
		function r = d2r(degrees)
			r=degrees*(pi/180);
		end
		
		% ===================================================================
		%> @brief radians2degrees
		%>
		% ===================================================================
		function degrees=r2d(r)
			degrees=r*(180/pi);
		end
		
		% ===================================================================
		%> @brief findDistance in X and Y coordinates
		%>
		% ===================================================================
		function distance=findDistance(x1,y1,x2,y2)
			dx = x2 - x1;
			dy = y2 - y1;
			distance=sqrt(dx^2 + dy^2);
		end
		
		% ===================================================================
		%> @brief updatePosition returns dX and dY given an angle and delta
		%>
		% ===================================================================
		function [dX dY] = updatePosition(delta,angle)
			dX = delta .* cos(baseStimulus.d2r(angle));
			dY = delta .* sin(baseStimulus.d2r(angle));
			if abs(dX) < 1e-6; dX = 0; end
			if abs(dY) < 1e-6; dY = 0; end
		end
		
	end%---END STATIC METHODS---%
	
	%=======================================================================
	methods ( Access = protected ) %-------PRIVATE (protected) METHODS-----%
	%=======================================================================
	
		% ===================================================================
		%> @brief Converts properties to a structure
		%>
		%> Prints messages dependent on verbosity
		%> @param tmp is whether to use the temporary or permanent properties
		%> @return out the structure
		% ===================================================================
		function out=toStructure(obj,tmp)
			if ~exist('tmp','var')
				tmp = 0; %copy real properties, not temporary ones
			end
			fn = fieldnames(obj);
			for j=1:length(fn)
				if tmp == 0
					out.(fn{j}) = obj.(fn{j});
				else
					out.(fn{j}) = obj.([fn{j} 'Out']);
				end
			end
		end
		
		% ===================================================================
		%> @brief Finds and removes transient properties
		%> 
		%> @param obj
		%> @return
		% ===================================================================
		function removeTmpProperties(obj)
			fn=fieldnames(obj);
			for i=1:length(fn)
				if ~isempty(regexp(fn{i},'Out$','once'))
					delete(obj.findprop(fn{i}));
				end
			end
		end
		
		% ===================================================================
		%> @brief Prints messages dependent on verbosity
		%>
		%> Prints messages dependent on verbosity
		%> @param in the calling function
		%> @param message the message that needs printing to command window
		% ===================================================================
		function salutation(obj,in,message)
			if obj.verbose==1
				if ~exist('in','var')
					in = 'undefined';
				end
				if exist('message','var')
					fprintf([message ' | ' in '\n']);
				else
					fprintf(['\n' obj.family ' stimulus, ' in '\n']);
				end
			end
		end
	end%---END PRIVATE METHODS---%
end
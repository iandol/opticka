classdef baseStimulus < dynamicprops
	%BASESTIMULUS Superclass providing basic structure for all stimulus
	%classes
	%   Detailed explanation to come
	properties
		xPosition = 0
		yPosition = 0
		size = 2
		colour = [0.5 0.5 0.5 1]
		alpha = 1
		verbose=0
		startPosition=0;
	end
	properties (SetAccess = private, GetAccess = private)
		allowedPropertiesBase='^(type|xPosition|yPosition|size|colour|verbose|alpha|startPosition)$'
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
	end %---END PUBLIC METHODS---%
	
	methods ( Access = protected ) %----------PRIVATE METHODS---------%
		
		function r = d2r(obj,degrees)
			r=degrees*(pi/180);
		end
		
		function degrees=r2d(obj,radians)
			degrees=radians*(180/pi);
		end
		
		function distance=findDistance(obj,x1,y1,x2,y2)
			dx = x2 - x1;
			dy = y2 - y1;
			distance=sqrt(dx^2 + dy^2);
		end
		
		function [dX dY] = updatePosition(obj,delta,angle)
			dX = delta * cos(obj.d2r(angle));
			dY = delta * sin(obj.d2r(angle));
		end
		
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
	end
end
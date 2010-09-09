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
		allowedPropertiesBase='^(type|xPosition|yPosition|size|colour|verbose|alpha)$'
	end
	methods
		%-------------------CONSTRUCTOR----------------------%
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
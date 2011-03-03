% ========================================================================
%> @brief textureStimulus is the superclass for texture based stimulus objects
%>
%> Superclass providing basic structure for texture stimulus classes
%>
% ========================================================================	
classdef textureStimulus < baseStimulus	
	properties %--------------------PUBLIC PROPERTIES----------%
		family = 'texture'
		type = 'simple'
		speed = 0
		angle = 0
	end
	
	properties (SetAccess = private, GetAccess = public)

	end
	properties (SetAccess = private, GetAccess = private)
		allowedProperties='^(type|speed|angle)$';
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
		%> @return instance of opticka class.
		% ===================================================================
		function obj = textureStimulus(args)
			%Initialise for superclass, stops a noargs error
			if nargin == 0
				args.family = 'texture';
			end
			obj=obj@baseStimulus(args); %we call the superclass constructor first
			%check we are a grating
			if ~strcmp(obj.family,'texture')
				error('Sorry, you are trying to call a textureStimulus with a family other than texture');
			end
			%start to build our parameters
			if nargin>0 && isstruct(args)
				fnames = fieldnames(args); %find our argument names
				for i=1:length(fnames);
					if regexp(fnames{i},obj.allowedProperties) %only set if allowed property
						obj.salutation(fnames{i},'Configuring setting in textureStimulus constructor');
						obj.(fnames{i})=args.(fnames{i}); %we set up the properies from the arguments as a structure
					end
				end
			end
			obj.salutation('constructor','Texture Stimulus initialisation complete');
		end
		
		% ===================================================================
		%> @brief Generate an structure for runExperiment
		%>
		%> @param in runExperiment object for reference
		%> @return stimulus structure.
		% ===================================================================
		function out = setup(obj,rE)
			
		end
		
		% ===================================================================
		%> @brief Update an structure for runExperiment
		%>
		%> @param in runExperiment object for reference
		%> @return stimulus structure.
		% ===================================================================
		function out = update(obj,rE)
			
		end
		
		
	end
	
	
	%---END PUBLIC METHODS---%
	
	methods ( Access = private ) %----------PRIVATE METHODS---------%

	end
end
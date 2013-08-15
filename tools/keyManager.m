classdef keyManager < optickaCore
	
	properties
		stateMachine
		runExperiment
		stimuli
	end
	
	methods
		function obj = keyManager(varargin) 
			if nargin == 0; varargin.name = 'keyManager'; end
			obj=obj@optickaCore(varargin); %superclass constructor
			if nargin>0
				obj.parseArgs(varargin, obj.allowedProperties);
			end
		end
		
		function checkKeys(obj)
			
		end
			
		end
	end
	
end


classdef eyelinkManager < optickaCore
	%UNTITLED Summary of this class goes here
	%   Detailed explanation goes here
	
	properties
		screen
		version
		defaults = struct()
	end
	
	properties (SetAccess = private, GetAccess = public)
		silentMode = false
		isConnected = false
		isDummy = false
	end
	
	properties (SetAccess = private, GetAccess = private)
		%> allowed properties passed to object upon construction
		allowedProperties = 'name|verbose'
	end
	
	methods
		
		function obj = eyelinkManager(varargin)
			if nargin>0
				obj.parseArgs(varargin,obj.allowedProperties);
			end
			obj.defaults = EyelinkInitDefaults();
		end
		
		function initialise(obj,sM)
			if exist('sM','var')
				obj.screen=sM;
			else
				error('Cannot initialise without a PTB screen')
			end
			[result,dummy] = EyelinkInit;
			obj.isConnected = logical(result);
			if sM.isOpen == true
				obj.defaults = EyelinkInitDefaults(sM.win);
			end
		end
		
	end
	
end


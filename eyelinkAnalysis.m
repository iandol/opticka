% ========================================================================
%> @brief eyelinkManager wraps around the eyelink toolbox functions
%> offering a simpler interface
%>
% ========================================================================
classdef eyelinkAnalysis < optickaCore
	
	properties
		file@char = ''
		dir@char = ''
	end
	
	properties (SetAccess = private, GetAccess = public)
		%> raw data
		raw@struct = []
	end
	
	properties (SetAccess = private, GetAccess = private)
		
		%> allowed properties passed to object upon construction
		allowedProperties@char = 'file|dir'
	end
	
	methods
		% ===================================================================
		%> @brief 
		%>
		% ===================================================================
		function obj = eyelinkAnalysis(varargin)
			if nargin == 0; varargin.name = 'eyelinkAnalysis';end
			if nargin>0
				obj.parseArgs(varargin,obj.allowedProperties);
			end
			if isempty(obj.file) || isempty(obj.dir)
				[obj.file, obj.dir] = uigetfile('*.edf','Load EDF File:');
			end	
		end
		
		% ===================================================================
		%> @brief 
		%>
		%> @param
		%> @return
		% ===================================================================
		function load(obj)
			
		end
		
		
	end%-------------------------END PUBLIC METHODS--------------------------------%
	
	%=======================================================================
	methods (Access = private) %------------------PRIVATE METHODS
	%=======================================================================
		
		
		
	end
	
end


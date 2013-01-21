% ========================================================================
%> @brief optickaCore base class inherited by many other opticka classes.
%> optickaCore is itself derived from handle
% ========================================================================
classdef behaviouralRecord < optickaCore
	
	%--------------------PUBLIC PROPERTIES----------%
	properties
		%> verbosity
		verbose = true
	end
	
	%--------------------PRIVATE PROPERTIES----------%
	properties (SetAccess = private, GetAccess = private)
		%> allowed properties passed to object upon construction
		allowedProperties = 'verbose'
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
		function obj = behaviouralRecord(args)
			if nargin>0
				obj.parseArgs(args,obj.allowedProperties);
			end
		end
		
		function createPlot(obj)
			
		end
		
		function updatePlot(obj)
			
		end
		
	end
	
	%=======================================================================
	methods ( Access = protected ) %-------PRIVATE (protected) METHODS-----%
	%=======================================================================
	
	end
end
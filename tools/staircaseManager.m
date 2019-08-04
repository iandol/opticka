% ========================================================================
%> @brief [WIP] staircaseManager links a stimulusSequence to Palamedes staircase
%> 
%> Use a stimulusSequence to randomise a variable, then for each value of  
%> that variable, run a Palamedes staricase
%> 
% ========================================================================
classdef staircaseManager < optickaCore & dynamicprops
	properties
		%> stimulusSequence task
		task stimulusSequence
		%> cell structure holding each independant variable staircase
		stair cell
		%> verbose
		verbose = false
	end
	
	properties (SetAccess = private, GetAccess = public)
		nStairCases
		currentRun
		totalRuns
	end
	
	properties (SetAccess = private, GetAccess = public, Transient = true, Hidden = true)
		
	end
	
	properties (Dependent = true,  SetAccess = private)
		
	end
	
	properties (SetAccess = private, GetAccess = private)
		%> properties allowed during initial construction
		allowedProperties='task|stair|verbose'
	end
	
	%=======================================================================	
	methods
	% ===================================================================
		
		% ===================================================================
		%> @brief Class constructor
		%>
		%> Send any parameters to parseArgs.
		%>
		%> @param varargin are passed as a structure of properties which is
		%> parsed.
		%> @return instance of the class.
		% ===================================================================
		function obj = staircaseManager(varargin) 
			if nargin == 0; varargin.name = 'staircaseManager'; end
			obj=obj@optickaCore(varargin); %superclass constructor
			if nargin > 0; obj.parseArgs(varargin,obj.allowedProperties); end
		end

		
	end % END METHODS
	
	%=======================================================================
	methods ( Access = private ) %------PRIVATE METHODS
	%=======================================================================
			
		
	end
	
	%=======================================================================
	methods (Static) %------------------STATIC METHODS
	%=======================================================================
		
		% ===================================================================
		%> @brief make a matrix from a cell array
		%> 
		%> 
		% ===================================================================
		function out=cellStruct(in)
			out = [];
			if iscell(in)
				for i = 1:size(in,2)
					cc = [in{:,i}]';
					if iscell(cc)
						out = [out, [in{:,i}]'];
					else
						out = [out, cc];
					end
				end
			end
		end
		
	end
	
end

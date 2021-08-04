% ========================================================================
%> @brief [WIP] staircaseManager links a taskSequence to Palamedes staircase
%> 
%> Use a taskSequence to randomise a variable, then for each value of  
%> that variable, run a Palamedes staricase
%> 
% ========================================================================
classdef staircaseManager < optickaCore & dynamicprops
	properties
		%> taskSequence task
		task taskSequence
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
		function me = staircaseManager(varargin) 
			args = optickaCore.addDefaults(varargin,struct('name','staircase manager'));
			me=me@optickaCore(args); %we call the superclass constructor first
			me.parseArgs(args, me.allowedProperties);
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

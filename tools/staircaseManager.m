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
		type = 'UD'
		udsettings cell = {struct('up',1,'down',3,'StepSizeDown',0.05,...
							'StepSizeUp',0.05,'stopcriterion','trials',...
							'stoprule',50,'startvalue',0.5);}
		psisettings cell 
		
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
		allowedProperties='type|task|stair|verbose'
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
		
		function setup(me)
			switch me.type
				case 'UD'
					for i = 1:length(me.udsettings)
						stair{i} = PAL_AMUD_setupUD(me.udsettings{i});
					end
				otherwise
					for i = 1:length(me.udsettings)
						stair{i} = PAL_AMUD_setupUD(me.udsettings{i});
					end
			end
			
		end

		
	end % END METHODS
	
	%=======================================================================
	methods ( Access = private ) %------PRIVATE METHODS
	%=======================================================================
			
		
	end
	
	%=======================================================================
	methods (Static) %------------------STATIC METHODS
	%=======================================================================
		
		
	end
	
end

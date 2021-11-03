% ========================================================================
%> @brief [WIP] staircaseManager links a taskSequence to Palamedes staircase
%>
%> Use a taskSequence to randomise a variable, then for each value of
%> that variable, run a Palamedes staricase
%>
%>
%> Copyright ©2014-2021 Ian Max Andolina — released: LGPL3, see LICENCE.md
% ========================================================================
classdef staircaseManager < optickaCore & dynamicprops
	properties
		%> taskSequence task
		task taskSequence
		%> verbose
		verbose = false
		%> type of staircase
		type = 'UD'
		%> settings for UD staircase
		udoptions cell = {struct('up',1,'down',3,'StepSizeDown',0.05,...
			'StepSizeUp',0.05,'stopcriterion','trials',...
			'stoprule',50,'startvalue',0.5)}
		%> settings for PSI staircase
		psioptions cell = {struct('priorAlphaRange',1,'priorBetaRange',1,'priorGammaRange',0.5,...
			'priorLambdaRange',0.02,'stimRange',1,...
			'numtrials',50,'startvalue',0.5,'PF',@PAL_Quick);}
		
	end
	
	properties (SetAccess = private, GetAccess = public)
		%> cell structure holding each independant variable staircase
		stair cell
		nStairCases
		currentRun
		totalRuns
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
		
		% ===================================================================
		%> @brief Setup
		%>
		%>
		% ===================================================================
		function setup(me)
			switch me.type
				case 'UD'
					for i = 1:length(me.udoptions)
						me.stair{i} = PAL_AMUD_setupUD(me.udoptions{i});
					end
				otherwise
					for i = 1:length(me.psioptions)
						me.stair{i} = PAL_AMPM_setupPM(me.psioptions{i});
					end
			end
		end
		
		% ===================================================================
		%> @brief Update
		%>
		%>
		% ===================================================================
		function update(me,num,response)
			switch me.type
				case 'UD'
					me.stair{num} = PAL_AMUD_updateUD(me.stair{num},response);
				otherwise
					me.stair{num} = PAL_AMPM_updatePM(me.stair{num},response);
			end
		end
		
	end % END PUBLIC METHODS

	%=======================================================================
	methods ( Access = private ) %------PRIVATE METHODS
	%=======================================================================


	end

	%=======================================================================
	methods (Static) %------------------STATIC METHODS
	%=======================================================================


	end

end

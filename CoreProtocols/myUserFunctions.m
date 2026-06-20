% ========================================================================
classdef myUserFunctions < userFunctions
%> @class myUserFunctions 
%> @brief Customised user functions for a task run
%>  
%> Copy and edit this file to add your own functions and variables for use
%> in your task. You can rename the class and file to something more
%> specific to your task if you like, but make sure the class name and file
%> name are the same. You must also keep the initialSetup() / shutdown
%> methods as these are specified as required by the parent class.
%>
% ========================================================================

	%% ADD YOUR OWN VARIABLES (PROPERTIES) HERE ↓
	properties
		comment string = "This is a custom user functions class object"
	end

	methods

		%===================================================================
		% Class constructor (should be same name as class)
		function me = myUserFunctions()
		%===================================================================

			
		end

		%===================================================================
		function initialSetup(me)
		% Initial setup to run BEFORE the task starts
		% all child classes MUST add this method, 
		% even if it is empty
		% ===================================================================

		end

		% ===================================================================
		function shutdown(me)
		% After the task finishes
		% ===================================================================
			fprintf("===>>> DMTS Task ended: %s", me.comment);
		end

		%% ADD YOUR FUNCTIONS BELOW ↓


	end

end
% ========================================================================
classdef myUserFunctions < userFunctions
%> @class myUserFunctions 
%> @brief Customised user functions for a task run, a child of
%> userFunctions. 
%>  
%> Copy and edit this file to add your own functions and variables for use
%> in your task. You can rename the class and file to something more
%> specific to your task if you like, but make sure the class name and file
%> name are the same. You must also keep the intialSetup() method
%>
% ========================================================================

	%% ADD YOUR OWN VARIABLES (PROPERTIES) HERE ↓
	properties
		comment string = "This is a custom user functions class object"
	end

	methods

		% Class constructor (should be same name as class)
		function me = myUserFunctions()
			
		end

		% Initial setup to run BEFORE the task starts
		% all child classes MUST add this method, 
		% even if it is empty
		function initialSetup(me)
			
		end

		%% ADD YOUR FUNCTIONS BELOW ↓


	end

end
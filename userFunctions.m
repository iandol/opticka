% ========================================================================
classdef userFunctions < handle %#ok<*MCFIL> 
%> @class userFunctions
%> @brief Customised user functions for a task run.
%>
%> The state machine's job is to run a set of functions when entering and
%> exiting states. Most required functions (methods in classes) are found in
%> the core opticka classes like screenManager, stateMachine etc. BUT if a
%> user wants to customise their own functions then we need to have a generic
%> class we can load and use where they can add their own methods. This
%> class serves this purpose. 
%> 
%> The user should make a copy of this file and save it somewhere alongside
%> their protocols (you can rename the file, but keep the class name the
%> same). They can add their own methods. The class will be added as a uF
%> object and these methods can be used via the state info file.
%>
%> Copyright ©2014-2022 Ian Max Andolina — released: LGPL3, see LICENCE.md
% ========================================================================

	% task object handles are added here by runExperiment, DO NOT EDIT
	properties 
		%> runExperiment
		rE 
		%> stateMachine
		sM
		%> screenManager
		s
		%> taskManager
		task
		%> metaStimulus stimluli
		stims
		%> reward manager
		rM
		%> I/O manager
		io
		%> eyetracker manager
		eT
		%> toggle to send messages to the command window
		verbose logical = true
	end

	% ADD YOUR OWN VARIABLES HERE
	properties 
		
	end

	%=======================================================================
	methods %------------------PUBLIC METHODS
	%=======================================================================

		% ===================================================================
		function me = userFunctions()
		%>userFunctions CONSTRUCT an instance of this class
		%>   Rename to the name of the class
		% ===================================================================
			if me.verbose; fprintf('\n\n===>>> User Functions instantiated…\n\n'); end
		end

		% ===================================================================
		function testFunction(me)
		%>testFunction test method
		%>   Just prints a message
		% ===================================================================
			if isa(me.rE, 'runExperiment')
				fprintf(['\n===>>> Hello from userFunctions.testFunction() for:' me.rE.fullName '\n'])
			else
				fprintf('\n===>>> Hello from userFunctions.testFunction()\n')
			end
		end

		% ADD YOUR FUNCTIONS BELOW ↓

		function myText(me)
			me.s.drawText('Hello from myFunctions')
		end

	end
end
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
%> Copyright ©2014-2023 Ian Max Andolina — released: LGPL3, see LICENCE.md
% ========================================================================

	% task object handles are added here by runExperiment, DO NOT EDIT
	properties 
		%> runExperiment
		rE 
		%> stateMachine
		sM
		%> screenManager
		s
		%> taskSequence
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
		function setDelayTimeWithStaircase(me, stim, duration)
		%> uses a staircase to set the off time for a specific stimulus
		%>   
		% ===================================================================
			if ~isempty(me.task.staircase)
				me.stims{stim}.delayTime = me.task.staircase(1).sc.xCurrent;
				if exist('duration','var')
					me.stims{stim}.offTime = me.stims{stim}.delayTime + duration;
				end
				me.stims{stim}.resetTicks();
				if me.verbose; fprintf('===>>> SET DELAYTIME on stim %i to %.2f off=%.2f\n', stim, me.stims{stim}.delayTime, me.stims{stim}.offTime);end
			end
		end

		% ===================================================================
		function resetDelayTime(me, stim, value)
		%> reset stimulus delay on time
		%>   
		% ===================================================================
			if ~isempty(me.task.staircase)
				me.stims{stim}.delayTime = value;
				me.stims{stim}.offTime = inf;
				me.stims{stim}.resetTicks();
				if me.verbose;fprintf('===>>> SET DELAYTIME on stim %i to %.2f\n', stim, me.stims{stim}.delayTime);end
			end
		end

		% ===================================================================
		function testFunction(me)
		%> testFunction test method
		%>   Just prints a message
		% ===================================================================
			if isa(me.rE, 'runExperiment')
				fprintf(['\n===>>> Hello from userFunctions.testFunction() for:' me.rE.fullName '\n'])
			else
				fprintf('\n===>>> Hello from userFunctions.testFunction()\n')
			end
		end


		% ADD YOUR FUNCTIONS BELOW ↓


	end
end
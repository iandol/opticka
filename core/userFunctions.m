% ========================================================================
classdef userFunctions < handle %#ok<*MCFIL> 
%> @class userFunctions
%> @brief Customised user functions for a task run.
%>
%> The state machine's job is to run a set of functions when entering and
%> exiting states. Most required functions (methods in classes) are found in
%> the core opticka classes like screenManager, stateMachine etc. BUT if a
%> user wants to customise their own functions then we need to have a generic
%> class we can load and use where you can add your own methods. This
%> class serves this purpose. 
%>
%> The user should either make a copy of this file or subclass it and add 
%> functions there and then save it as a new class somewhere alongside
%> their protocols (if you copy this you can rename the file, but keep the 
%> class name the same; if you subclass it then the file and class name can be the
%> same). The user can add their own methods. The class will be added as a uF
%> object and these methods can be used via the state info file, like:
%>
%> uF.myCustomFunction()
%>
%> REMEMBER: as these are stored as anonymous function handles in the state 
%> machine, any variables are set at instantiation time, not at run time. If
%> you need to get a run time variable, make a function. So if you need to 
%> get a value X that changes as the experiment runs, make a function like
%> X = getCurrentX() that returns the current value. Now when the state 
%> machine call the function the correct value is returned.
%>
%> Copyright ©2014-2026 Ian Max Andolina — released: LGPL3, see LICENCE.md
% ========================================================================

	%% task object handles are added here by runExperiment, DO NOT REMOVE
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
		%> touch manager
		tM
		%> time logger (saves timestamped messages
		tL
		%> alyx manager
		alyx
		%> toggle to send messages to the command window
		verbose logical = true
	end

	%% ADD YOUR OWN VARIABLES HERE ↓ if you copy this file
	properties 
		
	end

	%=======================================================================
	methods (Abstract) %------------------ABSTRACT METHODS
	%=======================================================================

		%> initial setup to run BEFORE the task starts; this will be called
		%> by runExperiment before the state machine starts, and before the
		%> first runExperiment.update(stims) call, so you can set up any
		%> variables or stimuli here that you want to use in the task. You
		%> can also call other functions from here to set things up.
		initialSetup(me)
		
	end

	%=======================================================================
	methods %------------------PUBLIC METHODS
	%=======================================================================

		% ===================================================================
		function me = userFunctions()
		%> @brief Construct an instance of this class.
		% ===================================================================
			if me.verbose; fprintf('\n\n===>>> User Functions instantiated…\n\n'); end
		end

		% ===================================================================
		function setDelayTimeWithStaircase(me, stim, duration)
		%> @brief Use the staircase to set stimulus delay/off time.
		%> @param stim Index of stimulus in `stims`.
		%> @param duration Optional extra duration added to off time.
		% ===================================================================
			arguments(Input)
				me % self
				stim (1,1) double
				duration (1,1) double = NaN
			end
			if ~isempty(me.task.staircase)
				me.stims{stim}.delayTime = me.task.staircase(1).sc.xCurrent;
				if ~isnan(duration)
					me.stims{stim}.offTime = me.stims{stim}.delayTime + duration;
				end
				me.stims{stim}.resetTicks();
				if me.verbose; fprintf('===>>> SET DELAYTIME on stim %i to %.2f off=%.2f\n', stim, me.stims{stim}.delayTime, me.stims{stim}.offTime);end
			end
		end

		% ===================================================================
		function resetDelayTime(me, stim, value)
		%> @brief Reset stimulus delay time to a specific value.
		%> @param stim Index of stimulus in `stims`.
		%> @param value Delay time value to apply.
		% ===================================================================
			arguments(Input)
				me % self
				stim (1,1) double
				value (1,1) double
			end
			if ~isempty(me.task.staircase)
				me.stims{stim}.delayTime = value;
				me.stims{stim}.offTime = inf;
				me.stims{stim}.resetTicks();
				if me.verbose;fprintf('===>>> SET DELAYTIME on stim %i to %.2f\n', stim, me.stims{stim}.delayTime);end
			end
		end

		% ===================================================================
		function testFunction(me)
		%> @brief Test method that prints a message.
		% ===================================================================
			arguments(Input)
				me % self
			end
			if isa(me.rE, 'runExperiment')
				fprintf(['\n===>>> Hello from userFunctions.testFunction() for:' me.rE.fullName '\n'])
			else
				fprintf('\n===>>> Hello from userFunctions.testFunction()\n')
			end
		end


		%% ADD YOUR FUNCTIONS BELOW ↓


	end
end

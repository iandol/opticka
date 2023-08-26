% ========================================================================
%> @class stateMachine
%> @brief run a task via a series of states.
%>
%> stateMachine allows a set of 'states' to be run, with functions executed
%> on entering state, within the state, and on exiting the state. States can
%> be linked, so a 'middle' state can be run after a 'start' state. States
%> can run in a loop (`run()` method) and use either real time as assesed
%> using the clockFcn fHandle property or via tick time, where each update()
%> to the stateMachine is a 'tick'. Tick time is useful when controlled via
%> an external manager like the Psychophysics toolbox which uses display
%> refresh as a natural tick timer.  
%>
%>`````````````````````
%>╔════════════════════════════════════════════════════════════════════════════════════════════════╗
%>║                  ┌─────────┐                                       ┌─────────┐                 ║
%>║                  │ STATE 1 │                                       │ STATE 2 │                 ║
%>║       ┌──────────┴─────────┴───────────┐                ┌──────────┴─────────┴──────────┐      ║
%>║  ┌────┴────┐      ┌────────┐      ┌────┴───┐       ┌────┴────┐      ┌────────┐     ┌────┴───┐  ║
%>╚═▶│  ENTER  │─────▶│ WITHIN │─────▶│  EXIT  │══════▶│  ENTER  │─────▶│ WITHIN │────▶│  EXIT  │══╣
%>   └────┬────┘      └────────┘      └────┬───┘       └────┬────┘      └────────┘     └────┬───┘  ║
%>        │          ┌──────────┐          │                │          ┌──────────┐         │      ║
%>        └──────────┤TRANSITION├──────────┘                └──────────┤TRANSITION├─────────┘      ║
%>                   └─────╦────┘                                      └──────────┘                ║
%>                         ║                  ┌─────────┐                                          ║
%>                         ║                  │ STATE 3 │                                          ║
%>                         ║       ┌──────────┴─────────┴───────────┐                              ║
%>                         ║  ┌────┴────┐      ┌────────┐      ┌────┴───┐                          ║
%>                         ╚═▶│  ENTER  │─────▶│ WITHIN │─────▶│  EXIT  │══════════════════════════╝
%>                            └────┬────┘      └────────┘      └────┬───┘
%>                                 │          ┌──────────┐          │
%>                                 └──────────┤TRANSITION├──────────┘
%>                                            └──────────┘
%>`````````````````````
%>
%> States have 4 fundamental evaluation points: ENTER, WITHIN, TRANSITION
%> and EXIT. Each evaluation point takes a cell array of functions to run.
%> TRANSITION evaluation is used to allow logic to switch from a default
%> transition path to an alternate. For example, you can imagine a default
%> stimulus > incorrect transition, but if the subject answers correctly you
%> can use the transition evaluation to switch instead to the correct state.
%>
%> To run a demo, try the following:
%>
%> ~~~~~~~~~~~~~~~~~~~~~~
%> >> sm = stateMachine;
%> >> runDemo(sm);
%> ~~~~~~~~~~~~~~~~~~~~~~
%>
%> To see how to run the stateMacine from a PTB loop, see
%> `runExperiment.runTask()`; and check DefaultStateInfo.m and METHODS.md
%>
%> Copyright ©2014-2022 Ian Max Andolina — released: LGPL3, see LICENCE.md
% ========================================================================
classdef stateMachine < optickaCore
	
	properties
		%> our state list, stored as a structure
		stateList struct			= struct([])
		%> use real time (true, using @clockFcn) or ticks (false) to mark state time. Real time is more
		%> accurate / robust against unexpected delays. Ticks uses timeDelta per tick and a
		%> tick timer (each update loop is 1 tick) for time measurement. This is simpler, can be
		%> controlled by an external driver that deals with timing, and without supervision
		%> but delays in the external update may cause drift.
		realTime logical			= false
		%> timedelta for time > ticks calculation, assume 0.1ms (1e-4) by default
		%> can set to IFI of display. This sets the "resolution" when
		%> realTime == false
		timeDelta double			= 1e-4
		%> clock function to use (GetSecs from PTB is optimal…)
		clockFcn function_handle	= @GetSecs
		%> N x 2 cell array of strings to compare, list to skip the current -> next state's exit functions; for example
		%> skipExitStates = {'fixate',{'incorrect','breakfix'}}; means that if the currentstate is
		%> 'fixate' and the next state is either incorrect OR breakfix, then skip the FIXATE exit
		%> state. Add multiple rows for skipping multiple state's exit states.
		skipExitStates cell			= {}
		%> for a state transition you can override the next state,
		%> but this is reset on the transition, so you need logic at runtime
		%> to set this value each time. This can be used in an experiment
		%> where you set this when you are in state A, and based on a
		%> probability you can transition to state B or state C for
		%> example. See taskSequence.trialVar and runExperiment.updateNextState
		%> for the tools to use this.
		tempNextState char			= ''
		%> verbose logging to command window?
		verbose						= false
		%> pause function (WaitSecs from PTB is optimal…)
		waitFcn function_handle		= @WaitSecs
		%> do we run timers for function evaluations?
		fnTimers logical			= false
	end

	properties (Hidden = true)
		%> size of the log arrays to preallocate
		logSize = 1
	end
	
	properties (SetAccess = protected, GetAccess = public, Transient = true)
		%> true or false, whether this object is currently busy running
		isRunning					= false
	end
	
	properties (SetAccess = protected, GetAccess = public)
		%> total number of ticks, updated via runBriefly() and update()
		totalTicks double
		%> time at start of stateMachine
		startTime double
		%> final time a finish
		finalTime double
		%> final ticks at finish
		finalTick double
		%> current state
		currentState
		%> current state name
		currentName char
		%> current state uuid
		currentUUID char
		%> current state index
		currentIndex
		%> ticks within the current state
		currentTick
		%> time within current state
		currentTime
		%> time entered current state
		currentEntryTime
		%> current entry function
		currentEntryFcn
		%> current within function
		currentWithinFcn
		%> current transition function
		currentTransitionFcn
		%> current exit function
		currentExitFcn
		%> number of ticks before next transition when realTime = false
		nextTickOut
		%> time before next transition when realTime = true
		nextTimeOut
		%> Index with name and index number for each state
		stateListIndex
		%> run state information
		log
	end
	
	properties (SetAccess = protected, GetAccess = protected)
		%> number of states
		nStates
		%> current state number
		thisN
		%> should we run the finish function
		isFinishing logical = false
		%> field names of allStates struct array, defining state behaviors
		stateFields cell = { 'name', 'next', 'entryFcn', 'withinFcn', 'time', 'transitionFcn','exitFcn', 'skipExitFcn' }
		%> default values of allStates struct array fields
		stateDefaults cell = { '', '', {}, {}, 1, {}, {}, false }
		%> properties allowed during construction
		allowedProperties = {'name','realTime','verbose','clockFcn','waitFcn'...
			'timeDelta','skipExitStates','tempNextState'}
		logFields = ["n","startTime","index","tnow","name","uuid",...
			"tick","entryTime","nextTimeOut", "nextTickOut",...
			"tempNextState","fevalEnter","fevalExit","fevalStore"]
		logValues = {[],[],[],[],"","",...
			[],[],[],[],...
			"",[],[],[]}
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
		function me = stateMachine(varargin)
			
			args = optickaCore.addDefaults(varargin,struct('name','state machine'));
			me=me@optickaCore(args); %superclass constructor
			me.parseArgs(args,me.allowedProperties);
			
			%initialise the statelist index
			reset(me);
			initialiseLog(me,1);
		end
		
		% ===================================================================
		%> @brief Add new states to the state machine.
		%> @param newStates a cell array with information defining a state.
		%> @return newStateIndexes indexes to newly added states
		% ===================================================================
		function newStateIndexes = addStates(me,newStates)
			sz = size(newStates);
			newStateIndexes = zeros(1,sz(1)-1);
			for ii = 2:sz(1)
				newState = cell2struct(newStates(ii,:), newStates(1,:), 2);
				if isfield(newState,'name') && ~isempty(newState.name)
					newStateIndexes(ii-1) = me.addState(newState);
				end
			end
		end
		
		% ===================================================================
		%> @brief add a single State to the state machine
		%> @param newState a state structure
		%> @return newStateIndex an index to the state position in the state list
		% ===================================================================
		function newStateIndex =  addState(me,newState)
			allowedFields = me.stateFields;
			allowedDefaults = me.stateDefaults;
			
			% pick newState fields that match allowed fields
			infoFields = fieldnames(newState);
			wrongFields = setdiff(infoFields, allowedFields);
			if ~isempty(wrongFields);warning('There are some unexpected items in your state info!');end
			infoValues = struct2cell(newState);
			[~, validIndices, defaultIndices] = intersect(infoFields, allowedFields);
			
			% merge valid newState and defaults into new struct
			mergedValues = allowedDefaults;
			mergedValues(defaultIndices) = infoValues(validIndices);
			newState = cell2struct(mergedValues, allowedFields, 2);
			
			% append the new state to allStates
			%   add to lookup table
			if isempty(me.stateList)
				newStateIndex = 1;
				me.stateList = newState;
			else
				[isState, newStateIndex] = me.isStateName(newState.name);
				if ~isState
					newStateIndex = me.nStates + 1;
				end
				me.stateList(newStateIndex) = newState;
			end
			me.nStates = length(me.stateList);
			me.stateListIndex(newState.name) = newStateIndex;
		end
		
		% ===================================================================
		%> Edit fields of an existing state.
		%> @param stateName string name of an existing state in allStates
		%> @param varargin flexible number of field-value paris to edit the
		%> fields of the @a stateName state.
		%> @details
		%> Assigns the given values to the given fields of the existing
		%> state that has the name @a stateName.  @a varargin represents a
		%> flexible number of traling arguments passed to editStateByName().
		%> The first argument in each pair should be one of the field names
		%> of the allStates struct, which include the default state fields
		%> described for addField() and the names of any sharedEntry or
		%> sharedExit fevalables.  The second argument in each pair should
		%> be a value to assign to the named field.
		%> @details
		%> Editing the @b name field of a state might cause the state
		%> machine to misbehave.
		%> @details
		%> Returns the index into allStates of the @a stateName state.  If
		%> @a stateName is not the name of an existing state, returns [].
		% ===================================================================
		function index = editStateByName(me, stateName, varargin)
			[isState, index] = isStateName(me,stateName);
			if isState
				for ii = 1:2:length(varargin)
					field = varargin{ii};
					if isfield(me.stateList, field)
						me.stateList(index).(field) = varargin{ii+1};
					end
				end
			end
		end
		
		% ===================================================================
		%> @brief getState retrieve a named state from the state list
		%> @param stateName name of a particular state
		%> @return state the individual state
		% ===================================================================
		function state = getState(me, stateName)
			if isStateName(me,stateName)
				state  = me.stateList(me.stateListIndex(stateName));
			end
		end
		
		% ===================================================================
		%> @brief update the state machine, normally run via an external loop
		%>
		%>
		% ===================================================================
		function update(me)
			if ~me.isRunning; return; end

			me.currentTick = me.currentTick + 1;
			me.totalTicks = me.totalTicks + 1;
			me.currentTime = feval(me.clockFcn);

			if me.realTime %are we running on time or ticks?
				trigger = me.currentTime >= me.nextTimeOut;
			else
				trigger = me.currentTick >= me.nextTickOut;
			end

			if trigger == true %we have exceeded the time (real|ticks): transition or exit
				if ~isempty(me.tempNextState) && isStateName(me, me.tempNextState)
					me.transitionToStateWithName(me.tempNextState);
				elseif ~isempty(me.stateList(me.currentIndex).next) 
					me.transitionToStateWithName(me.stateList(me.currentIndex).next);
				else %if no next state, exit the statemachine
					me.exitCurrentState;
					me.isRunning = false;
					me.isFinishing = true;
					finish(me);
				end
			else
				%transition function works by returning the name of a
				%next state when its criteria are met, so for example check
				%that the eye is fixated for the fixation time, returning
				%an empty string until that is met, then return the name of
				%a state to transition to.
				if ~isempty(me.currentTransitionFcn)
					tname = strtok(feval(me.currentTransitionFcn{1}));
					if ~isempty(tname)
						if isStateName(me,tname) % a valid name was returned, time to transition
							me.transitionToStateWithName(tname);
							return
						elseif strcmp(tname,'tempNextState') && ~isempty(me.tempNextState) && isStateName(me, me.tempNextState)
							me.transitionToStateWithName(me.tempNextState);
							return
						end
					end
				end
				%run our within state functions
				for i = 1:length(me.currentWithinFcn) %nested class
					me.currentWithinFcn{i}();
				end
			end
		end
		
		% ===================================================================
		%> @brief forceTransition force the state machine into a new named state
		%> @param stateName name of the state to transition to
		%>
		% ===================================================================
		function forceTransition(me, stateName)
			if me.isRunning == true
				if isStateName(me, stateName)
					me.currentTime = feval(me.clockFcn);
					transitionToStateWithName(me, stateName)
					return
				end
			else
				me.salutation('forceTransition method','stateMachine has not been started yet',true)
			end
		end
		
		% ===================================================================
		%> @brief start the state machine
		%>
		%>
		% ===================================================================
		function start(me)
			if me.isRunning == false
				initialiseLog(me);
				if me.timeDelta == 0; me.realTime = true; end %stops a divide by zero infinite loop
				me.isRunning = true;
				me.isFinishing = false;
				me.totalTicks = 0;
				me.currentTick = 0;
				me.thisN = 0;
				me.finalTime = [];
				me.startTime = feval(me.clockFcn);
				me.enterStateAtIndex(1);
			else
				me.salutation('start method','stateMachine already started...',true)
			end
		end
		
		% ===================================================================
		%> @brief finish stop the state machine
		%>
		%>
		% ===================================================================
		function finish(me, force)
			if ~exist('force','var'); force = me.isFinishing; end
			if force
				me.finalTime = feval(me.clockFcn) - me.startTime;
				me.finalTick = me.totalTicks;
				me.isRunning = false;
				me.isFinishing = false;
				fprintf('\n--->>> Total time to do state traversal: %g secs \n', me.finalTime);
				fprintf('--->>> Loops: %i thus ~%g ms per loop\n',me.finalTick, (me.finalTime/me.finalTick)*1e3);
			else
				me.salutation('finish method','stateMachine not running...',true)
			end
			finaliseLog(me)
		end
		
		% ===================================================================
		%> @brief run automomously run the state machine
		%>
		%>
		% ===================================================================
		function run(me)
			if me.isRunning == false
				start(me);
				while me.isRunning
					update(me);
					if ~me.realTime 
						%keep note of expected time:
						WaitSecs('UntilTime', me.currentEntryTime+((me.currentTick-1) * me.timeDelta));
					end
				end
				finish(me);
			else
				me.salutation('run method','stateMachine already running...',true)
			end
		end
		
		% ===================================================================
		%> @brief Check whether a string is the name of a state.
		%> @param stateName a state name
		%> @return isState logical
		%> @return index position in the state list
		% ===================================================================
		function [isState, index] = isStateName(me, stateName)
			isState = me.stateListIndex.isKey(stateName);
			if isState
				index = me.stateListIndex(stateName);
			else
				index = [];
			end
		end
		
		% ===================================================================
		%> @brief evalExitFcn sets current state skipExit value
		%>
		%>
		% ===================================================================
		function evalExitFcn(me, value)
			if me.isRunning == true
				me.currentState.skipExitFcn = value;
			end
		end
		
		% ===================================================================
		%> @brief printcurrentTick prints current (and total) ticks to command window
		%>
		%>
		% ===================================================================
		function printCurrentTick(me)
			fprintf('%i:%i', me.currentTick, me.totalTicks)
		end
		
		% ===================================================================
		%> @brief UUID function to return current UUID via a method
		%>
		%>
		% ===================================================================
		function uuid = UUID(me)
			uuid = me.currentUUID;
		end
		
		% ===================================================================
		%> @brief reset the object
		%>
		%>
		% ===================================================================
		function reset(me)
			me.stateList = struct([]);
			if verLessThan('matlab','9.13')
				me.stateListIndex = containers.Map('KeyType','char','ValueType','double');
			else
				me.stateListIndex = dictionary(string([]), []);
			end
			me.isRunning = false;
			if me.timeDelta == 0; me.realTime = true; end %stops a divide by zero infinite loop
			me.isFinishing = false;
			me.thisN = 0;
			me.totalTicks = [];
			me.currentName = '';
			me.currentUUID = '';
			me.currentTime = [];
			me.currentEntryFcn = {};
			me.currentExitFcn = {};
			me.currentTransitionFcn = {};
			me.currentWithinFcn = {};
			me.currentEntryTime = {};
			me.currentIndex = [];
			me.currentTick = [];
			me.currentState = [];
			me.startTime = [];
			me.finalTime = [];
			me.finalTick = [];
			me.nextTickOut = [];
			me.nextTimeOut = [];
		end
		
		% ===================================================================
		%> @brief runDemo runs a sample state machine session
		%>
		%>
		% ===================================================================
		function runDemo(me)
			oldVerbose = me.verbose;
			oldTimers = me.fnTimers;
			oldTimeDelta = me.timeDelta;
			fprintf('===>>> StateMachine Demo: time delta = %.3g | Real time mode = %i\n\n',me.timeDelta,me.realTime);
			me.verbose = true;
			me.fnTimers = true;
			beginFcn = { @()fprintf('\t\t\t\tbegin state: Hello there!\n'); };
			transitFcn = { @()fprintf('\t\t\t\ttransit state: Wait for it!\n'); };
			endFcn = { @()fprintf('\t\t\t\tend state: See you!\n'); };
			surpriseFcn = { @()fprintf('\t\t\t\tsurprise state: SURPRISE!!!\n'); };
			withinFcn = {}; %don't run anything within the state
			transitionFcn = { @()sprintf('surprise'); }; %returns a valid state name and thus triggers a transition
			exitFcn = { @()fprintf('\t\t\t\t<<---exit state--->>\n'); };
			statesInfo = {
				'name'		'next'		'time'	'entryFcn'	'withinFcn'	'transitionFcn'	'exitFcn';
				'begin'		'next1'		[2 4]	beginFcn	withinFcn	{}				exitFcn;
				'next1'		'next2'		0.05	{}			withinFcn	{}				exitFcn;
				'next2'		'next3'		0.1		{}			withinFcn	{}				exitFcn;
				'next3'		'transit'	0.2		{}			withinFcn	{}				exitFcn;
				'transit'	'end'		2		transitFcn	withinFcn	transitionFcn	exitFcn;
				'end'		''			2		endFcn		withinFcn	{}				exitFcn;
				'surprise'	'end'		2		surpriseFcn	withinFcn	{}				exitFcn;
				};
			addStates(me,statesInfo);
			disp('>--------------------------------------------------')
			disp(' The demo will run the following states settings:  ')
			disp(statesInfo)
			disp('>--------------------------------------------------')
			me.waitFcn(0.5);
			run(me);
			me.waitFcn(0.5);
			showLog(me);
			disp('>--------------------------------------------------')
			disp(' Demo finished, we will run the reset() method to ');
			disp(' cleanup this object...')
			disp('>--------------------------------------------------')
			reset(me);
			me.verbose = oldVerbose; %reset verbose back to original value
			me.timeDelta = oldTimeDelta;
			me.fnTimers = oldTimers;
		end

		% ===================================================================
		%> @brief warmup state machine
		%>
		%>
		% ===================================================================
		function warmUp(me)
			oldVerbose = me.verbose;
			oldTimers = me.fnTimers;
			me.verbose = false;
			me.fnTimers = true;
			beginFcn = { @()fprintf('begin state: stateMachine warmup... ') };
			middleFcn = { @()fprintf('middle state: stateMachine warmup... ') };
			endFcn = { @()fprintf('end state: stateMachine warmup... ') };
			surpriseFcn = { @()fprintf('surprise state: stateMachine warmup... ')};
			withinFcn = {};
			transitionFcn = { @()sprintf('surprise') }; 
			exitFcn = { @()fprintf('...exit\n') };
			statesInfo = {
				'name'		'next'		'time'	'entryFcn'	'withinFcn'	'transitionFcn'	'exitFcn';
				'begin'		'middle'	0.1		beginFcn	withinFcn	{}				exitFcn;
				'middle'	'end'		0.1		middleFcn	withinFcn	transitionFcn	exitFcn;
				'end'		''			0.1		endFcn		withinFcn	{}				exitFcn;
				'surprise'	'end'		0.1		surpriseFcn	withinFcn	{}				exitFcn;
			};
			addStates(me,statesInfo);
			me.waitFcn(0.01);
			run(me);
			me.waitFcn(0.01);
			reset(me);
			me.verbose = oldVerbose;
			me.fnTimers = oldTimers;
		end
		
		% ===================================================================
		%> @brief skip exit state functions: sets an N x 2 cell array 
		%> @param list Nx2 cell array list of strings to compare
		%> @return
		% ===================================================================
		function set.skipExitStates(me,list)
			if ~exist('list','var') || isempty(list) || ~iscell(list); return; end
			if size(list,2) == 2
				me.skipExitStates = list;
			else
				me.skipExitStates = [];
			end
		end
		
		% ===================================================================
		%> @brief show the log if present
		%> @param
		%> @return
		% ===================================================================
		function showLog(me)
			if ~isempty(me.log)
				stateMachine.plotLogs(me.log, me.fullName);
			else
				helpdlg('The current state machine log appears to be empty...')
			end
		end
		
	end
	
	%=======================================================================
	methods ( Access = protected ) %-------PROTECTED METHODS-----%
	%=======================================================================
		
		% ===================================================================
		%> @brief transition to a named state
		%> @param nextName the next state to switch to
		%> @return
		% ===================================================================
		% call transitionFevalable before exiting last and entering next state
		function transitionToStateWithName(me, nextName)
			if ~exist('nextName','var') || strcmpi(nextName,'useTemp'); nextName=me.tempNextState; end
			[isState, index] = isStateName(me, nextName);
			if isState
				if ~isempty(me.skipExitStates)
					for i=1:size(me.skipExitStates,1)
						if contains(me.currentName,me.skipExitStates{i,1}) && contains(nextName,me.skipExitStates{i,2})
							me.currentState.skipExitFcn = true;
						end
						if me.currentState.skipExitFcn; break; end
					end
				end
				exitCurrentState(me);
				enterStateAtIndex(me, index);
			else
				me.salutation('transitionToStateWithName method', 'ERROR, default to return to first state!!!\n',true)
				enterStateAtIndex(me, 1);
			end
			
		end
		
		% ===================================================================
		%> @brief exit current state
		%> @param
		%> @return
		% ===================================================================
		function exitCurrentState(me)
			if me.fnTimers; tx=tic; end
			if ~me.currentState.skipExitFcn 
				for i = 1:length(me.currentState.exitFcn) %nested class
					me.currentState.exitFcn{i}();
				end
			end
			if me.fnTimers 
				me.log.fevalExit(me.thisN) = toc(tx)*1000;
				tx = tic;
			end
			
			me.log.n					= me.thisN;
			me.log.index(me.thisN)		= me.currentIndex;
			me.log.tnow(me.thisN)		= me.currentTime;
			me.log.name{me.thisN}		= me.currentName;
			me.log.uuid{me.thisN}		= me.currentUUID;
			me.log.tick(me.thisN)		= me.currentTick;
			me.log.entryTime(me.thisN)	= me.currentEntryTime;
			me.log.nextTimeOut(me.thisN)= me.nextTimeOut;
			me.log.nextTickOut(me.thisN)= me.nextTickOut;
			if me.fnTimers
				me.log.fevalStore(me.thisN)	= toc(tx)*1000;
			end
			
			me.tempNextState = '';
			
			if me.verbose; me.salutation(['EXIT: ' me.currentName ...
					' @ ' num2str(me.log.tnow(me.log.n)-me.log.startTime,'%.2f') ...
					's | state time: ' num2str(me.log.tnow(me.log.n)-me.log.entryTime(me.log.n),'%.2f'), ...
					's | ' num2str(me.log.tick(me.log.n)) '/' num2str(me.totalTicks) ...
					' ticks'],''); end
		end
		
		% ===================================================================
		%> @brief enters a particular state
		%> @param thisIndex, the index number of the state 
		%> @return
		% ===================================================================
		function enterStateAtIndex(me, thisIndex)
			me.currentIndex = thisIndex;
			me.thisN = me.thisN + 1;
			if me.thisN == 1; me.log.startTime = me.startTime; end
			if me.nStates >= thisIndex
				if me.fnTimers; tt = tic; end	%run our enter state functions
				me.currentState = me.stateList(me.currentIndex);
				me.currentEntryTime = feval(me.clockFcn);
				me.currentTick = 0;
				me.currentName = me.currentState.name;
				me.currentUUID = num2str(dec2hex(floor((now - floor(now))*1e10)));
				me.currentEntryFcn = me.currentState.entryFcn;
				me.currentWithinFcn = me.currentState.withinFcn;
				me.currentTransitionFcn = me.currentState.transitionFcn;
				me.currentState = me.currentState;
				
				if length(me.currentState.time) == 2
					me.currentState.time = randi([me.currentState.time(1)*1e3, me.currentState.time(2)*1e3]) / 1e3;
				end
				me.nextTimeOut = me.currentEntryTime + me.currentState.time;
				me.nextTickOut = floor(me.currentState.time / me.timeDelta);
					
				for i = 1:length(me.currentEntryFcn)
					me.currentEntryFcn{i}();
				end
				%run our within state functions
				for i = 1:length(me.currentWithinFcn) %nested class
					me.currentWithinFcn{i}();
				end
				if me.fnTimers; me.log.fevalEnter(me.thisN) = toc(tt)*1000; end
				
				if me.verbose; me.salutation(['ENTER: ' me.currentName ...
						' @ ' num2str(me.currentEntryTime-me.startTime, ...
						'%.2f') 's - ' num2str(me.totalTicks) ' ticks'],''); end
			else
				if me.verbose; me.salutation('enterStateAtIndex method', 'newIndex is greater than stateList length'); end
				me.isFinishing = true;
				finish(me);
			end
		end

		% ===================================================================
		%> @brief initialise the log arrays to improve performance
		%> @param n number of entries 
		%> @return
		% ===================================================================
		function initialiseLog(me, n)
			if ~exist('n','var'); n = me.logSize; end
			if n == 1; me.log = cell2struct(me.logValues, me.logFields, 2); return; end
			me.log.(me.logFields(1)) = 0;
			for i = 3:length(me.logFields)
				if ~me.fnTimers && contains(me.logFields(i),'feval');continue;end
				if isnumeric(me.logValues{i})
					me.log.(me.logFields(i)) = NaN(1,n);
				else
					me.log.(me.logFields(i)) = repmat("",1,n);
				end
			end
		end

		% ===================================================================
		%> @brief clear up log arrays
		%> @param
		%> @return
		% ===================================================================
		function finaliseLog(me)
			if ~isempty(me.log.n) && me.log.n > 0 && length(me.log.tnow) > me.log.n
				for i = 3:length(me.logFields)
					if length(me.log.(me.logFields(i))) > 1
						me.log.(me.logFields(i)) = me.log.(me.logFields(i))(1:me.log.n);
					end
				end
			end
		end
		
	end
	
	%=======================================================================
	methods (Static) %------------------STATIC METHODS
	%=======================================================================
		
		% ===================================================================
		%> @brief loadobj handler
		%>
		% ===================================================================
		%function lobj=loadobj(in)
		%	lobj = in;
		%end
		
		% ===================================================================
		%> @brief plot timing logs
		%>
		% ===================================================================
		function plotLogs(log,tin)
			if ~exist('log','var') || isempty(log) || isempty(log.index); warndlg('No log data yet...');return;end
			if ~exist('tin','var')
				tout = ['State Machine with ' num2str(length(log)) ' states']; 
			else
				tout = [tin ' : ' num2str(length(log)) ' states'];
			end
			try
				f = figure('Position',[0 0 1500 1000],'Name','State Machine Time Logs');
				tl = tiledlayout(f,'flow','TileSpacing','tight','Padding','compact');
				tl.Title.String = tout;
				tl.Title.FontWeight = 'bold';
				ax1 = nexttile;
				s = plot([log.entryTime]-[log.startTime],'ko','MarkerSize',10, 'MarkerFaceColor', [1 1 1]);
				s.DataTipTemplate.DataTipRows(1).Label='State';
				s.DataTipTemplate.DataTipRows(2).Label='Time (s)';
				r = dataTipTextRow('Name',log.name);
				s.DataTipTemplate.DataTipRows(end+1)=r;
				hold on
				s = plot([log.tnow]-[log.startTime],'ro','MarkerSize',10, 'MarkerFaceColor', [1 1 1]);
				s.DataTipTemplate.DataTipRows(1).Label='State';
				s.DataTipTemplate.DataTipRows(2).Label='Time (s)';
				r = dataTipTextRow('Name',log.name);
				s.DataTipTemplate.DataTipRows(end+1)=r;
				r = dataTipTextRow('InTime',log.tnow-log.entryTime);
				s.DataTipTemplate.DataTipRows(end+1)=r;
				r = dataTipTextRow('Tick',log.tick);
				s.DataTipTemplate.DataTipRows(end+1)=r;
				legend('Enter time','Exit time','Location','southeast');
				%axis([-inf inf 0.97 1.02]);
				title('State Enter/Exit Times from State Machine Start');
				ylabel('Time (seconds)');
				set(gca,'XTick',1:length(log.name));
				set(gca,'XTickLabel',log.name);
				try set(gca,'XTickLabelRotation',30); end
				box on; grid on; axis tight;
				if isfield(log,'fevalEnter') && ~isnan(log.fevalEnter(1))
					ax2 = nexttile;
					s = plot(log.fevalEnter,'ko','MarkerSize',10, 'MarkerFaceColor', [1 1 1]);
					s.DataTipTemplate.DataTipRows(1).Label='State';
					s.DataTipTemplate.DataTipRows(2).Label='Time (ms)';
					r = dataTipTextRow('Name',log.name);
					try s.DataTipTemplate.DataTipRows(end+1)=r; end
					hold on;
					s = plot(log.fevalExit,'ro','MarkerSize',10, 'MarkerFaceColor', [1 1 1]);
					s.DataTipTemplate.DataTipRows(1).Label='State';
					s.DataTipTemplate.DataTipRows(2).Label='Time (ms)';
					r = dataTipTextRow('Name',log.name);
					try s.DataTipTemplate.DataTipRows(end+1)=r; end
					if isfield(log,'fevalStore')
						plot(log.fevalStore,'go','MarkerSize',10, 'MarkerFaceColor', [1 1 1]);
					end
					set(gca,'YScale','log');
					set(gca,'XTick',1:length(log.name));
					set(gca,'XTickLabel',log.name);
					try set(gca,'XTickLabelRotation',30); end
					legend('Enter feval','Exit feval', 'Store');
					title('Time the enter and exit state function evals ran');
					ylabel('Time (milliseconds)');
					box on; grid on; axis tight;
					linkaxes([ax1 ax2],'x');
				end
			end
		end
		
	end
end


% ========================================================================
%> @brief stateMachine a state machine object
%> 
%> stateMachine allows a set of 'states' to be run, with functions
%> executed on entering state, within the state, and on
%> exiting the state. States can be linked, so a 'middle' state can be
%> run after a 'start' state. States can run in a loop (run() method) and
%> use either real time as assesed using the clockFcn fHandle
%> property or via tick time, where each update() to the stateMachine is a
%> 'tick'. Tick time is useful when controlled via an external manager like 
%> the Psychophysics toolbox which uses display refresh as a natural
%> tick.
%> To run a demo, try the following:
%> >> sm = stateMachine
%> >> runDemo(sm);
%>
%> To see how to run the stateMacine from a PTB loop, see
%> runExperiment.runTrainingSession()
% ========================================================================
classdef stateMachine < optickaCore
	
	properties
		%>our main state list, stored as a structure
		stateList = struct([])
		%> timedelta for time > ticks calculation, assume 60Hz by default
		%> but set to correct IFI of display before use
		timeDelta = 0.0167
		%> use real time (true) or ticks (false) to mark state time
		realTime = false
		%> verbose logging to command window?
		verbose = false
		%> clock function to use
		clockFcn = @GetSecs
		%> pause function
		waitFcn = @WaitSecs
		%> transition function run globally between transitions
		globalTransitionFcn = {}
		%> log group name
		logName
		%> state to tranisition to to skip the previous state's exit
		%> functions
		skipExitStates = ''
	end
	
	properties (SetAccess = protected, GetAccess = public, Transient = true)
		%> total number of ticks, updated via runBriefly() and update()
		totalTicks
		%> time at start of stateMachine
		startTime
		%> final time a finish
		finalTime
		%> final ticks at finish
		finalTick
		%> current state
		currentState
		%> current state name
		currentName
		%> current state uuid
		currentUUID
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
		%> number of ticks before next transition realTime = false
		nextTickOut
		%> time before next transition realTime = true
		nextTimeOut
		%> Index with name and index number for each state
		stateListIndex
		%> true or false, whether this object is currently busy running
		isRunning = false
		%> previous state information
		log = [];
		%> log index
		logTick = 1;
	end
	
	properties (SetAccess = protected, GetAccess = protected)
		%> feval logging
		fevalTime
		%> is tops data logger present?
		isTops = false
		%> should we run the finish function
		isFinishing = false
		%> field names of allStates struct array, defining state behaviors
		stateFields = {'name', 'next', 'entryFcn', 'withinFcn', 'time', 'transitionFcn','exitFcn', 'skipExitFcn'}
		%> default values of allStates struct array fields
		stateDefaults = {'', '', {}, {}, 1, {}, {}, false}
		%> properties allowed during construction
		allowedProperties = 'name|realTime|verbose|clockFcn|waitFcn|timeDelta|globalTransitionFcn'
	end
	
	events
		%> called at run start
		runStart
		%> called at run end
		runFinish
		%> entering state
		enterState
		%> exiting state
		exitState
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
		function obj = stateMachine(varargin)
			%initialise the statelist index
			obj.stateList = struct([]);
			obj.stateListIndex = containers.Map('uniformValues', false);
			%parse any inputs
			if nargin>0
				parseArgs(obj, varargin, obj.allowedProperties);
			end
		end
		
		% ===================================================================
		%> @brief Add new states to the state machine.
        %> @param newStates a cell array with information defining a state.
		%> @return newStateIndexes indexes to newly added states
		% ===================================================================
		function newStateIndexes = addStates(obj,newStates)
			sz = size(newStates);
			newStateIndexes = zeros(1,sz(1)-1);
			for ii = 2:sz(1)
				newState = cell2struct(newStates(ii,:), newStates(1,:), 2);
				newStateIndexes(ii-1) = obj.addState(newState);
			end
		end
		
		% ===================================================================
		%> @brief add a single State to the state machine
		%> @param newState a state structure
		%> @return newStateIndex an index to the state position in the state list
		% ===================================================================
		function newStateIndex =  addState(obj,newState)
			allowedFields = obj.stateFields;
			allowedDefaults = obj.stateDefaults;
			
			% pick newState fields that match allowed fields
			infoFields = fieldnames(newState);
			infoValues = struct2cell(newState);
			[~, validIndices, defaultIndices] = intersect(infoFields, allowedFields);
			
			% merge valid newState and defaults into new struct
			mergedValues = allowedDefaults;
			mergedValues(defaultIndices) = infoValues(validIndices);
			newState = cell2struct(mergedValues, allowedFields, 2);
			
			% append the new state to allStates
			%   add to lookup table
			if isempty(obj.stateList)
				newStateIndex = 1;
				obj.stateList = newState;
			else
				[isState, newStateIndex] = obj.isStateName(newState.name);
				if ~isState
					newStateIndex = length(obj.stateList) + 1;
				end
				obj.stateList(newStateIndex) = newState;
			end
			obj.stateListIndex(newState.name) = newStateIndex;
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
		function index = editStateByName(obj, stateName, varargin)
            [isState, index] = isStateName(obj,stateName);
            if isState
                for ii = 1:2:length(varargin)
                    field = varargin{ii};
                    if isfield(obj.stateList, field)
                        obj.stateList(index).(field) = varargin{ii+1};
                    end
                end
            end
        end
		
		% ===================================================================
		%> @brief getState retrieve a named state from the state list
		%> @param stateName name of a particular state
		%> @return state the individual state
		% ===================================================================
		function state = getState(obj, stateName)
			if isStateName(obj,stateName)
				state  = obj.stateList(obj.stateListIndex(stateName));
			end
		end
		
		% ===================================================================
		%> @brief update the state machine, normally run via an external loop
		%> 
		%> 
		% ===================================================================
		function update(obj)
			if obj.isRunning == true
				
				if obj.realTime == true %are we running on time or ticks?
					obj.currentTime = feval(obj.clockFcn);
					trigger = obj.currentTime >= obj.nextTimeOut;
				else
					trigger = obj.currentTick >= obj.nextTickOut;
				end
				if trigger == true %we have exceeded the time (real|ticks), so time to transition or exit
					nextName = obj.stateList(obj.currentIndex).next;
					if isempty(nextName) %no next state, exit the statemachine
						obj.exitCurrentState;
						obj.isRunning = false;
						obj.isFinishing = true;
						finish(obj);
					else
						obj.transitionToStateWithName(nextName);
					end
					return
				end
				
				%transition function works by returning the name of the
				%next state when its criteria are met, so for example check
				%that the eye is fixated for the fixation time, returning
				%an empty string until that is met, then return the name of
				%a state to transition to.
				if ~isempty(obj.currentTransitionFcn) && isa(obj.currentTransitionFcn,'function_handle') %function handle, lets feval it
					tname = feval(obj.currentTransitionFcn);
					[tname, ~] = strtok(tname,' ');
					if ischar(tname) && isStateName(obj,tname) % a valid name was returned, time to transition
						obj.transitionToStateWithName(tname);
						return
					end
				end
				
				%run our within state functions
				if isa(obj.currentWithinFcn,'function_handle') %function handle, lets feval it
					feval(obj.currentWithinFcn);
				elseif iscell(obj.currentWithinFcn)
					for i = 1:size(obj.currentWithinFcn,1) %nested class
						feval(obj.currentWithinFcn{i});
					end
				end
				
				%TODO lets assume to update a tick here, we may miss a tick on
				%the tranition above, not sure of the implications of
				%updating ticks before or after? 
				obj.currentTick = obj.currentTick + 1;
				obj.totalTicks = obj.totalTicks + 1;

			else
				obj.salutation('update method','stateMachine has not been started yet',true)
			end
		end
		
		% ===================================================================
		%> @brief forceTransition force the state machine into a new named state
		%> @param stateName name of the state to transition to
		%> 
		% ===================================================================
		function forceTransition(obj,stateName)
			if obj.isRunning == true
				if isStateName(obj,stateName)
					obj.salutation('forceTransition method',['stateMachine forced to: ' stateName],false)
					transitionToStateWithName(obj, stateName)
					return
				else
					obj.salutation('forceTransition method',['state: ' stateName ' not found...'],false)
				end
			else
				obj.salutation('forceTransition method','stateMachine has not been started yet',true)
			end
		end
		
		% ===================================================================
		%> @brief start the state machine
		%> 
		%> 
		% ===================================================================
		function start(obj)
			if obj.isRunning == false
				obj.log = [];
				obj.logTick = 1;
				if obj.timeDelta == 0; obj.realTime = true; end %stops a divide by zero infinite loop
				obj.isRunning = true;
				obj.isFinishing = false;
				obj.totalTicks = 1;
				obj.currentTick = 1;
				obj.finalTime = [];
				obj.notify('runStart');
				obj.startTime = feval(obj.clockFcn);
				obj.enterStateAtIndex(1);
			else
				obj.salutation('start method','stateMachine already started...',true)
			end
		end
		
		% ===================================================================
		%> @brief finish stop the state machine
		%> 
		%> 
		% ===================================================================
		function finish(obj)
			if obj.isFinishing == true
				obj.notify('runFinish');
				obj.finalTime = feval(obj.clockFcn) - obj.startTime;
				obj.finalTick = obj.totalTicks;
				obj.isRunning = false;
				obj.isFinishing = false;
				fprintf('\n--->>> Total time to do state traversal: %g secs \n', obj.finalTime);
				fprintf('--->>> Loops: %i thus %g ms per loop\n',obj.finalTick, (obj.finalTime/obj.finalTick)*1000);
			else
				obj.salutation('finish method','stateMachine not running...',true)
			end
		end
		
		% ===================================================================
		%> @brief run automomously run the state machine
		%> 
		%> 
		% ===================================================================
		function run(obj)
			if obj.isRunning == false
				start(obj);
				while obj.isRunning
					update(obj);
					if obj.timeDelta > 0
						%this is much more accurate as it keeps note of expected time:
						WaitSecs('UntilTime', obj.startTime+(obj.totalTicks*obj.timeDelta));
					end
				end
				finish(obj);
			else
				obj.salutation('run method','stateMachine already running...',true)
			end
		end
		
		% ===================================================================
		%> @brief Check whether a string is the name of a state.
		%> @param stateName state name
		%> @return isState logical
		%> @return index position in the state list
		% ===================================================================
		function [isState, index] = isStateName(obj, stateName)
			isState = obj.stateListIndex.isKey(stateName);
			if isState
				index = obj.stateListIndex(stateName);
			else
				index = [];
			end
		end
		
		% ===================================================================
		%> @brief printcurrentTick fprints current tick to command window
		%> 
		%> 
		% ===================================================================
		function evalExitFcn(obj,value)
			if obj.isRunning == true
				obj.currentState.skipExitFcn = value;
				if value
					fprintf('SKIP EXIT STATE!!!\n')
				end
			end
		end
		
		% ===================================================================
		%> @brief printcurrentTick fprints current tick to command window
		%> 
		%> 
		% ===================================================================
		function printCurrentTick(obj)
			fprintf('%g:%g',obj.currentTick,obj.totalTicks)
		end
		
		% ===================================================================
		%> @brief UUID function to return current UUID via a method
		%> 
		%> 
		% ===================================================================
		function uuid = UUID(obj)
			uuid = obj.currentUUID;
		end
		
		% ===================================================================
		%> @brief runDemo runs a sample state machine session
		%> 
		%> 
		% ===================================================================
		function runDemo(obj)
			obj.verbose = true;
			obj.realTime = false;
			beginFcn = @()disp('::enter state: begin -- Hello there!');
			middleFcn = @()disp('::enter state: middle -- Still here?');
			surpriseFcn = @()disp('::SURPRISE!!!');
			endFcn = @()disp('::enter state: end -- See you soon!');
			withinFcn = [];
			transitionFcn = @()sprintf('false');
			transitionFcn2 = @()sprintf('surprise');
			exitFcn = { @()fprintf('\t--->>exit state'); @()fprintf('\n') };
			statesInfo = { ...
			'name'		'next'		'time'	'entryFcn'	'withinFcn'	'transitionFcn'	'exitFcn'; ...
			'begin'		'middle'	2	beginFcn	withinFcn	transitionFcn	exitFcn; ...
			'middle'	'end'		2	middleFcn	withinFcn	transitionFcn2	exitFcn; ...
			'end'		''			2	endFcn		withinFcn	transitionFcn	exitFcn; ...
			'surprise'	'end'		2	surpriseFcn	withinFcn	[]				exitFcn; ...
			};
			addStates(obj,statesInfo);
			disp('>--------------------------------------------------')
			disp(' The demo will run the following states settings:  ')
			disp(statesInfo)
			disp('>--------------------------------------------------')
			obj.waitFcn(1);
			run(obj);
		end
		
		
	end
	
	%=======================================================================
	methods ( Access = protected ) %-------PRIVATE (protected) METHODS-----%
	%=======================================================================
		
		% ===================================================================
		%> @brief enters a particular state
		%> @param
		%> @return
		% ===================================================================
		function enterStateAtIndex(obj, thisIndex)
			obj.currentIndex = thisIndex;
			if length(obj.stateList) >= thisIndex
				obj.notify('enterState');
				thisState = obj.stateList(obj.currentIndex);
				obj.currentEntryTime = feval(obj.clockFcn);
				obj.currentTick = 1;
				obj.currentName = thisState.name;
				obj.currentUUID = num2str(dec2hex(floor((now - floor(now))*1e10)));
				obj.currentEntryFcn = thisState.entryFcn;
				obj.currentWithinFcn = thisState.withinFcn;
				obj.currentTransitionFcn = thisState.transitionFcn;
				obj.currentState = thisState;
				
				if length(thisState.time) == 1
					obj.nextTimeOut = obj.currentEntryTime + thisState.time;
				else
					thisState.time = randi([thisState.time(1)*1e3, thisState.time(2)*1e3]) / 1e3;
					obj.nextTimeOut = obj.currentEntryTime + thisState.time;
				end
				obj.nextTickOut = round(thisState.time / obj.timeDelta);
				
				obj.salutation(['Enter state: ' obj.currentName ' @ ' num2str(obj.currentEntryTime-obj.startTime) 'secs / ' num2str(obj.totalTicks) 'ticks'],'',false)
				
				%tic;
				if isa(thisState.entryFcn,'function_handle') %function handle, lets feval it
					feval(thisState.entryFcn);
				elseif iscell(thisState.entryFcn) %nested class of function handles
					for i = 1:size(thisState.entryFcn,1) 
						feval(thisState.entryFcn{i});
					end
				end
				%obj.fevalTime.enter = toc*1000;
	
			else
				obj.salutation('enterStateAtIndex method', 'newIndex is greater than stateList length',false);
				obj.finish();
			end
		end
		
		% ===================================================================
		%> @brief transition to a named state
		%> @param
		%> @return
		% ===================================================================
		% call transitionFevalable before exiting last and entering next state
		function transitionToStateWithName(obj, nextName)
			[isState, index] = isStateName(obj, nextName);
			if isState
				if iscell(obj.skipExitStates)
					for i=1:size(obj.skipExitStates,1)
						if ~isempty(regexpi(obj.currentName,obj.skipExitStates{i,1})) && ~isempty(regexpi(nextName,obj.skipExitStates{i,2}));
							obj.currentState.skipExitFcn = true;
						end
					end
				end
				exitCurrentState(obj);
%				if isa(obj.globalTransitionFcn,'function_handle') %function handle, lets feval it
%					feval(obj.globalTransitionFcn);
%				end
				obj.salutation(['Transition @ ' num2str(feval(obj.clockFcn)-obj.startTime) 'secs / ' num2str(obj.totalTicks) 'ticks'],'',false)
				enterStateAtIndex(obj, index);
			else
				obj.salutation('transitionToStateWithName method', 'ERROR, default to return to first state!!!\n',true)
				enterStateAtIndex(obj, 1);
			end
				
		end
		
		% ===================================================================
		%> @brief clear current properties but leave currentIndex so it's checkable
		%> @param
		%> @return
		% ===================================================================
		function exitCurrentState(obj)
			thisState = obj.currentState;
			%tic;
			if thisState.skipExitFcn == false
				if iscell(thisState.exitFcn) %nested class of function handles	
					for i = 1:size(thisState.exitFcn, 1) %nested class
						feval(thisState.exitFcn{i});
					end
				elseif isa(thisState.exitFcn,'function_handle') %function handle, lets feval it
					feval(thisState.exitFcn);
				end
			end
			%obj.fevalTime.exit = toc*1000;
			
			storeCurrentStateInfo(obj);
			
			obj.currentEntryFcn = {};
			obj.currentEntryTime = [];
			obj.nextTickOut = [];
			obj.nextTimeOut = [];
			
			obj.salutation(['Exiting state:' thisState.name ' @ ' num2str(obj.log(end).tnow) 's | ' num2str(obj.log(end).totalTimeToNow) 's | ' num2str(obj.log(end).tick) '/' num2str(obj.totalTicks) 'ticks'],'',false);
		end
		
		% ===================================================================
		%> @brief clear current properties but leave currentIndex so it's checkable
		%> @param
		%> @return
		% ===================================================================
		function storeCurrentStateInfo(obj)
			in.name = obj.currentName;
			%in.state = obj.currentState;
			in.tick = obj.currentTick;
			in.time = obj.currentTime;
			in.entryTime = obj.currentEntryTime;
			in.nextTimeOut = obj.nextTimeOut;
			in.nextTickOut = obj.nextTickOut;
			in.tnow = feval(obj.clockFcn);
			in.totalTimeToNow = in.tnow - in.entryTime;
			in.totalTime = in.time - in.entryTime;
			in.timeError = in.time - in.nextTimeOut;
			in.tickError = in.tick - in.nextTickOut;
			in.fevalTime = obj.fevalTime;
			if obj.logTick > 1
				obj.log(obj.logTick) = in;
			else
				obj.log = in;
			end
			obj.logTick = obj.logTick + 1;
		end
		
		
		
		% ===================================================================
		%> @brief Converts properties to a structure
		%>
		%>
		%> @param obj this instance object
		%> @param tmp is whether to use the temporary or permanent properties
		%> @return out the structure
		% ===================================================================
		function out=toStructure(obj)
			fn = fieldnames(obj);
			for j=1:length(fn)
				out.(fn{j}) = obj.(fn{j});
			end
		end

	end
	
	%=======================================================================
	methods (Static) %------------------STATIC METHODS
	%=======================================================================
	
% 		% ===================================================================
% 		%> @brief loadobj handler
% 		%>
% 		% ===================================================================
% 		function lobj=loadobj(in)
% 			lobj = in;
% 		end

		% ===================================================================
		%> @brief plot timing logs
		%>
		% ===================================================================
		function plotLogs(log)
			for i = 1:length(log)
				
				int(i) = log(i).fevalTime.enter;
				outt(i) = log(i).fevalTime.exit;
				
			end
			figure;
			plot(int,'k-.')
			hold on
			plot(outt,'r-.')
			legend('enter','exit')
		end
		
	end
end


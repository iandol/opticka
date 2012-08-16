% ========================================================================
%> @brief stateMachine a state machine object
%> 
%> stateMachine allows a set of 'states' to be run, with functions
%> executed on entering state, within the state, and on
%> exiting the state. States can be linked, so a 'middle' state can be
%> run after a 'start' state. States can run in a loop (run() method) and
%> use either real time as assesed using the clockFunction fHandle
%> property or via tick time, where each update() to the stateMachine is a
%> 'tick'. Tick time is useful when controlled via an external manager like 
%> the Psychophysics toolbox which uses display refresh as a natural
%> tick.
%> To run a demo, try the following:
%> >> sm = stateMachine
%> >> runDemo(sm);
% ========================================================================
classdef stateMachine < handle
	
	properties
		%>our main state list, stored as a structure
		stateList = struct([])
		%> timedelta for time > ticks calculation, assume 60Hz by default
		%> but set to correct IFI of display before use
		timeDelta = 0.0167
		%> use real time to ticks to mark state time
		realTime = false
		%> verbose or not
		verbose = true
		%> clock function to use
		clockFunction = @GetSecs
		%> transition function run between during transitions
		transitionFcn = {}
	end
	
	properties (SetAccess = protected, GetAccess = public)
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
		%> current state namer
		currentName
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
		%> current exit function
		currentExitFcn
		%> number of ticks before next transition realTime = false
		nextTickOut
		%> time before next transition realTime = true
		nextTimeOut
		%> Index with name and index number for each state
		stateListIndex
		%> Index with tick timer values
		stateListTicks
		%> true or false, whether this object is currently busy running
		isRunning = false;
	end
	
	properties (SetAccess = protected, GetAccess = protected)
		%> field names of allStates struct array, defining state behaviors
		stateFields = {'name', 'next', 'entryFcn', 'withinFcn', 'time', 'exitFcn'}
		%> default values of allStates struct array fields
		stateDefaults = {'', '', {}, {}, 1, {}}
		allowedProperties = 'realTime|verbose|clockFunction|timeDelta'
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
			obj.stateListIndex = containers.Map('a', 1, 'uniformValues', false);
			obj.stateListIndex.remove(obj.stateListIndex.keys);
			obj.stateListTicks = containers.Map('a', 1, 'uniformValues', false);
			obj.stateListTicks.remove(obj.stateListTicks.keys);
			if nargin>0
				obj.parseArgs(varargin, obj.allowedProperties);
			end
		end
		
		% ===================================================================
		%> @brief
		%> @param
		%> @return
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
		%> @brief
		%> @param
		%> @return
		% ===================================================================
		function newStateIndex =  addState(obj,newState)
			allowedFields = obj.stateFields;
			allowedDefaults = obj.stateDefaults;
			
			% pick newState fields that match allowed fields
			infoFields = fieldnames(newState);
			infoValues = struct2cell(newState);
			[validFields, validIndices, defaultIndices] = intersect(infoFields, allowedFields);
			
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
			obj.stateListTicks(newState.name) = round(newState.time / obj.timeDelta);
		end
		
		% ===================================================================
		%> @brief
		%> @param
		%> @return
		% ===================================================================
		function state = getState(obj, stateName)
			if isStateName(obj,stateName)
				state  = obj.stateList(obj.stateListIndex(stateName));
			end
		end
		
		% ===================================================================
		%> @brief
		%> @param
		%> @return
		% ===================================================================
		function update(obj)
			if obj.isRunning == true
				if obj.realTime == false
					trigger = obj.currentTick >= obj.nextTickOut;
				else
					obj.currentTime = feval(obj.clockFunction);
					trigger = obj.currentTime >= obj.nextTimeOut;
				end
				if trigger == true
					nextName = obj.stateList(obj.currentIndex).next;
					if isempty(nextName)
						obj.exitCurrentState;
						obj.isRunning = false;
					else
						obj.transitionToStateWithName(nextName);
					end
				else
					if ~isempty(obj.currentWithinFcn)
						if size(obj.currentWithinFcn,1) == 1 %single class
							feval(obj.currentWithinFcn{:});
						else
							for i = 1:size(obj.currentWithinFcn,1) %nested class
								feval(obj.currentWithinFcn{i}{:});
							end
						end
					end
				end
				obj.currentTick = obj.currentTick + 1;
				obj.totalTicks = obj.totalTicks + 1;
			else
				obj.salutation('update method','stateMachine has not been started yet')
			end
		end
		
		% ===================================================================
		%> @brief
		%> @param
		%> @return
		% ===================================================================
		function forceTransition(obj,stateName)
			if obj.isRunning == true
				if isStateName(obj,stateName)
					obj.salutation('forceTransition method',['stateMachine forced to: ' stateName])
					transitionToStateWithName(obj, stateName)
				else
					obj.salutation('forceTransition method',['state: ' stateName ' not found...'])
				end
			else
				obj.salutation('forceTransition method','stateMachine has not been started yet')
			end
		end
		
		% ===================================================================
		%> @brief
		%> @param
		%> @return
		% ===================================================================
		function start(obj)
			if obj.isRunning == false
				obj.notify('runStart');
				obj.startTime = feval(obj.clockFunction);
				obj.currentTime = obj.startTime;
				obj.isRunning = true;
				obj.totalTicks = 1;
				obj.currentTick = 1;
				obj.finalTime = [];
				obj.enterStateAtIndex(1);
			else
				obj.salutation('start method','stateMachine already started...')
			end
		end
		
		% ===================================================================
		%> @brief
		%> @param
		%> @return
		% ===================================================================
		function finish(obj)
			if obj.isRunning == true
				obj.notify('runFinish');
				obj.finalTime = feval(obj.clockFunction) - obj.startTime;
				obj.finalTick = obj.currentTick;
				obj.isRunning = false;
				fprintf('\n--->>> Total time to do state traversal: %g secs \n', obj.finalTime);
				fprintf('--->>> Loops: %i thus %g ms per loop\n',obj.finalTick, (obj.finalTime/obj.finalTick)*1000);
			else
				obj.salutation('finish method','stateMachine not running...')
			end
		end
		
		% ===================================================================
		%> @brief
		%> @param
		%> @return
		% ===================================================================
		function run(obj)
			if obj.isRunning == false
				start(obj);
				while obj.isRunning
					update(obj);
					WaitSecs(obj.timeDelta);
				end
				finish(obj);
			else
				obj.salutation('run method','stateMachine already running...')
			end
		end
		
		% ===================================================================
		%> @brief Check whether a string is the name of a state.
		%> @param
		%> @return
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
		%> @brief
		%> @param
		%> @return
		% ===================================================================
		function runDemo(obj)
			obj.verbose = false;
			obj.realTime = false;
			beginFcn = {@disp, 'enter state: begin -- Hello!'};
			middleFcn = {@disp, 'enter state: middle -- Hello!'};
			endFcn = {@disp, 'enter state: end -- see you soon!'};
			withinFcn = {{@fprintf, '.'};{@fprintf, ' '}};
			exitfcn = {{@fprintf, '-exit state'};{@fprintf, '\n'}};
			statesInfo = { ...
				'name'      'next'   'time'     'entryFcn'	'withinFcn'		'exitFcn'; ...
				'begin'     'middle'  1			beginFcn		withinFcn		exitfcn; ...
				'middle'    'end'     1			middleFcn		withinFcn		exitfcn; ...
				'end'       ''        1         endFcn			withinFcn		exitfcn; ...
				};
			addStates(obj,statesInfo);
			disp('>--------------------------------------------------')
			disp(' The demo will run the following 3 states settings:')
			statesInfo
			disp('>--------------------------------------------------')
			run(obj);
		end
		
		
	end
	
	%=======================================================================
	methods ( Access = protected ) %-------PRIVATE (protected) METHODS-----%
		%=======================================================================
		
		% ===================================================================
		%> @brief reset all the current* properties for the given state
		%> @param
		%> @return
		% ===================================================================
		%
		function enterStateAtIndex(obj, thisIndex)
			obj.currentIndex = thisIndex;
			if length(obj.stateList) >= thisIndex
				obj.notify('enterState');
				thisState = obj.stateList(obj.currentIndex);
				obj.currentTick = 1;
				obj.currentState = thisState;
				obj.currentName = thisState.name;
				obj.currentEntryFcn = thisState.entryFcn;
				obj.currentEntryTime = feval(obj.clockFunction);
				obj.currentWithinFcn = thisState.withinFcn;
				obj.nextTimeOut = obj.currentEntryTime + thisState.time;
				obj.nextTickOut = obj.stateListTicks(thisState.name);
				obj.salutation(['Enter state: ' obj.currentName ' @ ' num2str(obj.currentEntryTime-obj.startTime) 'secs / ' num2str(obj.totalTicks) 'ticks'])
				if ~isempty(thisState.entryFcn)
					if size(thisState.entryFcn,1) == 1 %single class
						feval(thisState.entryFcn{:});
					else
						for i = 1:size(thisState.entryFcn,1) %nested class
							feval(thisState.entryFcn{i}{:});
						end
					end
				end
			else
				obj.salutation('enterStateAtIndex method', 'newIndex is greater than stateList length');
				obj.finish();
			end
		end
		
		% ===================================================================
		%> @brief
		%> @param
		%> @return
		% ===================================================================
		% call transitionFevalable before exiting last and entering next state
		function transitionToStateWithName(obj, nextName)
			nextIndex = obj.stateListIndex(nextName);
			obj.exitCurrentState;
			obj.salutation(['Transition @ ' num2str(feval(obj.clockFunction)-obj.startTime) 'secs / ' num2str(obj.totalTicks) 'ticks'])
 			if ~isempty(obj.transitionFcn)
 				feval(obj.transitionFcn{:});
 			end
			obj.enterStateAtIndex(nextIndex);
		end
		
		% ===================================================================
		%> @brief clear current* properties but leave currentIndex so it's checkable
		%> @param
		%> @return
		% ===================================================================
		function exitCurrentState(obj)
			thisState = obj.stateList(obj.currentIndex);
			obj.currentEntryFcn = {};
			obj.currentEntryTime = [];
			obj.nextTimeOut = [];
			obj.salutation(['Exiting state:' thisState.name ' @ ' num2str(feval(obj.clockFunction)-obj.startTime) 'secs / ' num2str(obj.totalTicks) 'ticks']);
			if ~isempty(thisState.exitFcn)
				if size(thisState.exitFcn, 1) == 1 %single class
					feval(thisState.exitFcn{:});
				else
					for i = 1:size(thisState.exitFcn, 1) %nested class
						feval(thisState.exitFcn{i}{:});
					end
				end
			end
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
		
		% ===================================================================
		%> @brief Sets properties from a structure or normal arguments,
		%> ignores invalid properties
		%>
		%> @param args input structure
		%> @param allowedProperties properties possible to set on construction
		% ===================================================================
		function parseArgs(obj, args, allowedProperties)
			allowedProperties = ['^(' allowedProperties ')$'];
			
			while iscell(args) && length(args) == 1
				args = args{1};
			end
			
			if iscell(args)
				if mod(length(args),2) == 1 % odd
					args = args(1:end-1); %remove last arg
				end
				odd = logical(mod(1:length(args),2));
				even = logical(abs(odd-1));
				args = cell2struct(args(even),args(odd),2);
			end
			
			if isstruct(args)
				fnames = fieldnames(args); %find our argument names
				for i=1:length(fnames);
					if regexp(fnames{i},allowedProperties) %only set if allowed property
						obj.salutation(fnames{i},'Configuring setting in constructor');
						obj.(fnames{i})=args.(fnames{i}); %we set up the properies from the arguments as a structure
					end
				end
			end
			
		end
		
		% ===================================================================
		%> @brief Prints messages dependent on verbosity
		%>
		%> Prints messages dependent on verbosity
		%> @param obj this instance object
		%> @param in the calling function
		%> @param message the message that needs printing to command window
		% ===================================================================
		function salutation(obj,in,message)
			if obj.verbose==true
				if ~exist('in','var')
					in = 'undefined';
				end
				if exist('message','var')
					fprintf(['---> stateMachine: ' message ' | ' in '\n']);
				else
					fprintf(['---> stateMachine: ' in '\n']);
				end
			end
		end
	end
end


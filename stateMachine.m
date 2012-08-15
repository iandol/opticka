classdef stateMachine < handle
	%>UNFINISHED Work in progress
	%>   Will be a stateMachine object when finished, with a set of states
	%>   and transitions. Running will traverse state list.
	
	properties
		%>our main state list
		stateList = struct([])
		%> timedelta for time > ticks calculation, assume 60Hz
		timeDelta = 0.0167
		realTime = false
		verbose = true
		clockFunction = @GetSecs
	end
	
	properties (SetAccess = protected, GetAccess = public)
		totalTick
		currentState
		currentName
		currentIndex
		currentTick
		currentTime
		currentEntryTime
		nextTickOut
		nextTimeOut
		currentEntryFcn
		currentWithinFcn
		currentExitFcn
		startTime
		finalTime
		finalTick
		%> Index with name and index number for each state
		stateListIndex
		%> Index with tick timer values
		stateListTicks
		%> true or false, whether this object is currently busy running
		isRunning = false;
		%> field names of allStates struct array, defining state behaviors
		stateFields = {'name', 'next', 'entryFcn', 'withinFcn', 'time', 'exitFcn'}
		%> default values of allStates struct array fields
		stateDefaults = {'', '', {}, {}, 1, {}}
	end
	
	properties (SetAccess = protected, GetAccess = protected)
		
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
		beforeState
		afterState
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
			obj.stateList = struct([])
			obj.stateListIndex = containers.Map('a', 1, 'uniformValues', false);
			obj.stateListIndex.remove(obj.stateListIndex.keys);
			obj.stateListTicks = containers.Map('a', 1, 'uniformValues', false);
			obj.stateListTicks.remove(obj.stateListTicks.keys);
		end
		
		% ===================================================================
		%> @brief
		%> @param
		%> @return
		% ===================================================================
		function initialise(obj)
			if isempty(obj.stateList)
				doBegin = {@disp, 'Hello'};
				doMiddle = {@disp, 'Wow!!!'};
				doEnd = {@disp, 'Oh bye!'};
				withinFcn = {@fprintf, '.'};
				exitfcn = {@fprintf, 'end\n'};
				statesInfo = { ...
					'name'      'next'   'time'     'entryFcn'	'withinFcn'		'exitFcn'; ...
					'begin'     'middle'  1			doBegin		withinFcn		exitfcn; ...
					'middle'    'end'     1			doMiddle	withinFcn		exitfcn; ...
					'end'       ''        1         doEnd		withinFcn		exitfcn; ...
					};
				addStates(obj,statesInfo);
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
			[validFields, validIndices, defaultIndices] = ...
				intersect(infoFields, allowedFields);
			
			% merge valid newState and defaults into new struct
			mergedValues = allowedDefaults;
			mergedValues(defaultIndices) = infoValues(validIndices);
			newState = cell2struct(mergedValues, allowedFields, 2);
			
			%assign defaults
% 			if isempty(newState.entryFcn)
% 				newState.entryFcn = {@disp, 'Entering'};
% 			end
% 			if isempty(newState.withinFcn)
% 				newState.withinFcn = {@disp, 'Within'};
% 			end
% 			if isempty(newState.exitFcn)
% 				newState.exitFcn = {@disp, 'Bye'};
% 			end
			
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
		function editState(obj,stateName,varin)
			
		end
		
		% ===================================================================
		%> @brief
		%> @param
		%> @return
		% ===================================================================
		function getState(obj, stateName)
			
		end
		
		% ===================================================================
		%> @brief
		%> @param
		%> @return
		% ===================================================================
		function update(obj)
			trigger = false;
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
			obj.totalTick = obj.totalTick + 1;
		end
		
		% ===================================================================
		%> @brief
		%> @param
		%> @return
		% ===================================================================
		function forceTransition(obj,stateName)
			if isStateName(obj,stateName)
				transitionToStateWithName(obj, stateName)
			end
		end
		
		% ===================================================================
		%> @brief
		%> @param
		%> @return
		% ===================================================================
		function start(obj)
			obj.notify('runStart');
			obj.startTime = feval(obj.clockFunction);
			obj.currentTime = obj.startTime;
			obj.isRunning = true;
			obj.totalTick = 1;
			obj.currentTick = 1;
			obj.finalTime = [];
			obj.enterStateAtIndex(1);
		end
		
		% ===================================================================
		%> @brief
		%> @param
		%> @return
		% ===================================================================
		function finish(obj)
			obj.notify('runFinish');
			obj.finalTime = feval(obj.clockFunction) - obj.startTime;
			obj.finalTick = obj.currentTick;
			obj.isRunning = false;
			fprintf('\n--->>> Total time to do state traversal: %g secs \n', obj.finalTime);
			fprintf('--->>> Loops: %i thus %g ms per loop\n',obj.finalTick, (obj.finalTime/obj.finalTick)*1000);
		end
		
		% ===================================================================
		%> @brief
		%> @param
		%> @return
		% ===================================================================
		function run(obj)
			obj.start;
			while obj.isRunning
				obj.runBriefly;
			end
			obj.finish;
		end
		
		% ===================================================================
		%> @brief
		%> @param
		%> @return
		% ===================================================================
		function runBriefly(obj)
			trigger = false;
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
					obj.finish;
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
			obj.totalTick = obj.totalTick + 1;
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
				thisState = obj.stateList(obj.currentIndex);
				obj.currentTick = 1;
				obj.currentState = thisState;
				obj.currentName = thisState.name;
				obj.currentEntryFcn = thisState.entryFcn;
				obj.currentEntryTime = feval(obj.clockFunction);
				obj.currentWithinFcn = thisState.withinFcn;
				obj.nextTimeOut = obj.currentEntryTime + thisState.time;
				obj.nextTickOut = obj.stateListTicks(thisState.name);
				obj.salutation(['Entering state: ' thisState.name ' @ ' num2str(obj.currentEntryTime-obj.startTime) 'secs'])
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
				obj.isRunning = false;
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
			obj.salutation(['Transitioning @ ' num2str(obj.currentTime-obj.startTime) 'secs'])
% 			if ~isempty(obj.transitionFcn)
% 				feval(obj.transitionFcn{:});
% 			end
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
			obj.salutation(['Exiting state:' thisState.name ' @ ' num2str(feval(obj.clockFunction)-obj.startTime) 'secs']);
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
		%> @brief Sets properties from a structure, ignores invalid properties
		%>
		%> @param args input structure
		% ===================================================================
		function parseArgs(obj, args, allowedProperties)
			allowedProperties = ['^(' allowedProperties ')$'];
			fnames = fieldnames(args); %find our argument names
			for i=1:length(fnames);
				if regexp(fnames{i},allowedProperties) %only set if allowed property
					obj.salutation(fnames{i},'Configuring setting in constructor');
					obj.(fnames{i})=args.(fnames{i}); %we set up the properies from the arguments as a structure
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


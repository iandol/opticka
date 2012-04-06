classdef stateMachine < handle
	%>UNFINISHED Work in progress
	%>   Will be a stateMachine object when finished, with a set of states
	%>   and transitions. Running will traverse state list.
	
	properties
		%>our main state list
		stateList = struct([])
		enterFunction
		exitFunction
		beforeFunction
		afterFunction
		transitionFunction
		verbose = true
		clockFunction = @GetSecs
	end
	
	properties (SetAccess = protected, GetAccess = public)
		currentState
		currentIndex
		currentTick
		currentTime
		currentEntryTime
		nextTickOut
		nextTimeOut
		currentEntryFunction
		currentExitFunction
		startTime
		finalTime
		finalTick
		%> Index with name and index number for each state
		stateListIndex
		%> true or false, whether this object is currently busy running
		isRunning = false;
	end
	
	properties (SetAccess = protected, GetAccess = protected)
		%> field names of allStates struct array, defining state behaviors
		stateFields = {'name', 'next', 'time',	'entry', 'within', 'withinTime', 'exit'}
		%> default values of allStates struct array fields
		stateDefaults = {'', '', 0, {}, {}, 0, {}}
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
			obj.stateListIndex = containers.Map('a', 1, 'uniformValues', false);
			obj.stateListIndex.remove(obj.stateListIndex.keys);
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
			% poll for state timeout
			tt = feval(obj.clockFunction);
			%fprintf('This Time: %g | Next Time: %g\n',tt, obj.nextTimeOut);
			if tt >= obj.nextTimeOut
				nextName = obj.stateList(obj.currentIndex).next;
				if isempty(nextName)
					obj.exitCurrentState;
					obj.isRunning = false;
				else
					obj.transitionToStateWithName(nextName);
				end
			end
			obj.currentTick = obj.currentTick + 1;
		end
		
		% ===================================================================
		%> @brief
		%> @param
		%> @return
		% ===================================================================
		function start(obj)
			obj.notify('runStart');
			obj.startTime = feval(obj.clockFunction);
			obj.isRunning = true;
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
			
			fprintf('Total time to do state traversal: %g secs \n', obj.finalTime);
			fprintf('Loops: %i thus %g ms per loop\n',obj.finalTick, (obj.finalTime/obj.finalTick)*1000);

			
		end
		
		% ===================================================================
		%> @brief
		%> @param
		%> @return
		% ===================================================================
		function tick = returnTick(obj)
			tick = obj.currentTick;
		end
		
		% ===================================================================
		%> @brief
		%> @param
		%> @return
		% ===================================================================
		function name = returnCurrentName(obj)
			name = obj.currentState.name;
		end
		
		% ===================================================================
		%> @brief Check whether a string is the name of a state.
		%> @param
		%> @return
		% ===================================================================
		function [isState, allStateIndex] = isStateName(obj, stateName)
			isState = obj.stateListIndex.isKey(stateName);
			if isState
				allStateIndex = obj.stateListIndex(stateName);
			else
				allStateIndex = [];
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
				obj.currentEntryFunction = thisState.entry;
				obj.currentEntryTime = feval(obj.clockFunction);
				obj.nextTimeOut = obj.currentEntryTime + thisState.time;
				obj.salutation(['Entering state: ' thisState.name '...'])
				feval(thisState.entry{:});
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
			% 			if ~isempty(obj.transitionFevalable)
			% 				inserted = cell(1, numel(obj.transitionFevalable) + 1);
			% 				inserted(1) = obj.transitionFevalable(1);
			% 				inserted{2} = obj.allStates([obj.currentIndex, nextIndex]);
			% 				inserted(3:end) = obj.transitionFevalable(2:end);
			% 				obj.logFeval(obj.transitionString, inserted)
			% 			end
			obj.salutation('Transitioning...')
			obj.enterStateAtIndex(nextIndex);
			
		end
		
		% ===================================================================
		%> @brief clear current* properties but leave currentIndex so it's checkable
		%> @param
		%> @return
		% ===================================================================
		function exitCurrentState(obj)
			
			thisState = obj.stateList(obj.currentIndex);
			obj.currentEntryFunction  = {};
			obj.currentEntryTime = [];
			obj.nextTimeOut = [];
			obj.salutation(['Exiting ' thisState.name '...']);
			feval(thisState.exit{:})
			
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


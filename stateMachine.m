classdef stateMachine < handle
	%UNTITLED Summary of this class goes here
	%   Detailed explanation goes here
	
	properties
		%>our main state list
		stateList = []
		enterFunction
		exitFunction
		beforeFunction
		afterFunction
		transitionFunction
		verbose = true
	end
	
	properties (SetAccess = protected, GetAccess = public)
		currentState
		currentTick
		currentTime
		nextTick
		nextTime
	end
	
	properties (SetAccess = protected, GetAccess = protected)
		%> field names of allStates struct array, defining state behaviors
		stateFields = {'name', 'next', 'time',	'entry', 'within', 'withinTime', 'exit'}
		%> default values of allStates struct array fields
		stateDefaults = {'', '', 0, {}, {}, 0, {}}
	end
	
	events
		enterState
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
		function obj = stateMachine(args)
			
		end
		
		function addStates(obj,in)
			sz = size(in);
         allStateIndexes = zeros(1,sz(1)-1);
            for ii = 2:sz(1)
                newState = cell2struct(in(ii,:), in(1,:), 2);
                allStateIndexes(ii-1) = obj.addState(newState);
            end
		end
		
		function addState(obj,in)
			allowedFields = cat(2, self.stateFields, ...
                self.sharedEntryFevalableNames, ...
                self.sharedExitFevalableNames);
            allowedDefaults = cat(2, self.stateDefaults, ...
                cell(size(self.sharedEntryFevalableNames)), ...
                cell(size(self.sharedExitFevalableNames)));
            
            % pick stateInfo fields that match allowed fields
            infoFields = fieldnames(stateInfo);
            infoValues = struct2cell(stateInfo);
            [validFields, validIndices, defaultIndices] = ...
                intersect(infoFields, allowedFields);
            
            % merge valid stateInfo and defaults into new struct
            mergedValues = allowedDefaults;
            mergedValues(defaultIndices) = infoValues(validIndices);
            newState = cell2struct(mergedValues, allowedFields, 2);
            
            % append the new state to allStates
            %   add to lookup table
            if isempty(self.allStates)
                allStateIndex = 1;
                self.allStates = newState;
            else
                [isState, allStateIndex] = self.isStateName(newState.name);
                if ~isState
                    allStateIndex = length(self.allStates) + 1;
                end
                self.allStates(allStateIndex) = newState;
            end
            self.stateNameToIndex(newState.name) = allStateIndex;
		end
		
		function editState(obj,stateName,varin)
			
		end
		
		function getState(obj, stateName)
			
		end
		
		function run(obj,in)
			
		end
		
		
	end
	
	%=======================================================================
	methods ( Access = protected ) %-------PRIVATE (protected) METHODS-----%
	%=======================================================================
	
		% ===================================================================
		%> @brief Converts properties to a structure
		%>
		%> 
		%> @param obj this instance object
		%> @param tmp is whether to use the temporary or permanent properties
		%> @return out the structure
		% ===================================================================
		function out=toStructure(obj,tmp)
			if ~exist('tmp','var')
				tmp = 0; %copy real properties, not temporary ones
			end
			fn = fieldnames(obj);
			for j=1:length(fn)
				if tmp == 0
					out.(fn{j}) = obj.(fn{j});
				else
					out.(fn{j}) = obj.([fn{j} 'Out']);
				end
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


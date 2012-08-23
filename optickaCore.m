% ========================================================================
%> @brief metaStimulus light wrapper for opticka stimuli
%> METASTIMULUS a collection of stimuli, wrapped in one structure
% ========================================================================
classdef optickaCore < handle
	
	properties %--------------------PUBLIC PROPERTIES----------%
		%> stimulus family
		name = ''
		%> verbose logging
		verbose = true
	end
	
	properties (SetAccess = private, GetAccess = public)
		dateStamp
	end
	
	properties (SetAccess = private, Dependent = true)
		
	end
	
	properties (SetAccess = private, GetAccess = private)
		%> allowed properties passed to object upon construction
		allowedProperties = 'name|verbose'
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
		function obj = optickaCore(args)
			obj.dateStamp = clock();
			if nargin>0
				obj.parseArgs(args,obj.allowedProperties);
			end
		end
		
	end
	
	%=======================================================================
	methods ( Access = protected ) %-------PRIVATE (protected) METHODS-----%
	%=======================================================================
		
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
					fprintf(['---> ' obj.name ': ' message ' | ' in '\n']);
				else
					fprintf(['---> ' obj.name ': ' in '\n']);
				end
			end
		end
	end
end
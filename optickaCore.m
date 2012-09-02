% ========================================================================
%> @brief optickaCore 
%> optickaCore baseclass derived from handle
% ========================================================================
classdef optickaCore < handle
	
	properties 
		%> object name
		name = ''
	end
	
	properties (Abstract = true)
		%> verbose logging, subclasses must assign this
		verbose
	end
	
	properties (SetAccess = protected, GetAccess = public)
		%> clock() dateStamp set on construction
		dateStamp
		%> universal ID
		uuid
		%> storage of various paths
		paths = struct()
	end
	
	properties (SetAccess = private, Dependent = true)
		
	end
	
	properties (SetAccess = protected, GetAccess = protected)
		%> matlab version we are running on
		mversion
		%> class name
		className
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
			obj.className = class(obj);
			obj.dateStamp = clock();
			obj.uuid = num2str(dec2hex(floor((now - floor(now))*1e10)));
			%obj.uuid = char(java.util.UUID.randomUUID); %128bit uuid;
			if nargin>0
				obj.parseArgs(args,obj.allowedProperties);
			end
			obj.mversion = str2double(regexp(version,'(?<ver>^\d\.\d\d)','match','once'));
			obj.paths.whoami = mfilename;
			obj.paths.whereami = fileparts(which(mfilename));
		end
		
		% ===================================================================
		%> @brief concatenate the name with a uuid at get.
		%> @param
		%> @return
		% ===================================================================
		function name = get.name(obj)
			if isempty(obj.name)
				name = [obj.className '#' obj.uuid];
			else
				name = [obj.name ' <' obj.className '#' obj.uuid '>'];
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
						obj.salutation(fnames{i},'Constructor parsing input argument');
						obj.(fnames{i})=args.(fnames{i}); %we set up the properies from the arguments as a structure
					else
						obj.salutation(fnames{i},'Constructor parsing: invalid input');
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
		function salutation(obj,in,message,override)
			if ~exist('override','var')
				override = false;
			end
			if obj.verbose==true || override == true
				if ~exist('in','var')
					in = 'undefined';
				end
				if exist('message','var')
					fprintf(['---> ' obj.className ': ' message ' | ' in '\n']);
				else
					fprintf(['---> ' obj.className ': ' in '\n']);
				end
			end
		end
	end
end
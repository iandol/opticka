% ========================================================================
%> @brief metaStimulus light wrapper for opticka stimuli
%> METASTIMULUS a collection of stimuli, wrapped in one structure
% ========================================================================
classdef metaStimulus < handle
	
	properties %--------------------PUBLIC PROPERTIES----------%
		%> stimulus family
		family = 'meta'
		verbose = true
		stimuli = {}
		screen
	end
	
	properties (SetAccess = private, Dependent = true)
		n
	end
	
	properties (SetAccess = private, GetAccess = private)
		%> allowed properties passed to object upon construction
		allowedProperties = 'stimuli|screen|verbose'
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
		function obj = metaStimulus(args)
			if nargin == 0
				varargin.family = 'meta';
			end
			
			if nargin>0
				obj.parseArgs(args);
			end
		end
		
		% ===================================================================
		%> @brief setup wrapper
		%>
		%> @param
		%> @return
		% ===================================================================
		function setup(obj,choice)
			if ~exist('choice','var')
				for i = 1:obj.n
					setup(obj.stimuli{i},obj.screen);
				end
			else
				setup(obj.stimuli{choice},obj.screen);
			end
		end
		
		% ===================================================================
		%> @brief update wrapper
		%>
		%> @param
		%> @return
		% ===================================================================
		function update(obj,choice)
			if ~exist('choice','var')
				for i = 1:obj.n
					update(obj.stimuli{i});
				end
			else
				update(obj.stimuli{choice});
			end
		end
		
		% ===================================================================
		%> @brief draw wrapper
		%>
		%> @param
		%> @return
		% ===================================================================
		function draw(obj,choice)
			if ~exist('choice','var')
				for i = 1:obj.n
					draw(obj.stimuli{i});
				end
			else
				draw(obj.stimuli{choice});
			end
		end
		
		% ===================================================================
		%> @brief animate wrapper
		%>
		%> @param
		%> @return
		% ===================================================================
		function animate(obj,choice)
			if ~exist('choice','var')
				for i = 1:obj.n
					animate(obj.stimuli{i});
				end
			else
				animate(obj.stimuli{choice});
			end
		end
		
		% ===================================================================
		%> @brief reset wrapper
		%>
		%> @param
		%> @return
		% ===================================================================
		function reset(obj,choice)
			if ~exist('choice','var')
				for i = 1:obj.n
					reset(obj.stimuli{i});
				end
			else
				reset(obj.stimuli{choice});
			end
		end
		
		% ===================================================================
		%> @brief get n dependent methos
		%> @param
		%> @return n number of stimuli
		% ===================================================================
		function n = get.n(obj)
			n = length(obj.stimuli);
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
					fprintf(['---> ' obj.family ': ' message ' | ' in '\n']);
				else
					fprintf(['---> ' obj.family ': ' in '\n']);
				end
			end
		end
	end
end
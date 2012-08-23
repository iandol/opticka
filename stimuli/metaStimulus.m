% ========================================================================
%> @brief metaStimulus light wrapper for opticka stimuli
%> METASTIMULUS a collection of stimuli, wrapped in one structure
% ========================================================================
classdef metaStimulus < optickaCore
	
	properties %--------------------PUBLIC PROPERTIES----------%
		%> stimulus family
		family = 'meta'
		%>cell array of stimuli to manage
		stimuli = {}
		%> screenManager handle
		screen
		%>
		verbose = true
	end
	
	properties (SetAccess = private, Dependent = true)
		%> n number of stimuli managed by metaStimulus
		n
	end
	
	properties (SetAccess = private, GetAccess = private)
		%> allowed properties passed to object upon construction
		allowedProperties = 'verbose|stimuli|screen|family'
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
		function obj = metaStimulus(varargin)
			if nargin == 0; varargin.name = 'metaStimulus';end
			obj=obj@optickaCore(varargin); %superclass constructor
			if nargin>0; obj.parseArgs(varargin,obj.allowedProperties); end
			if isempty(obj.name);obj.name = 'metaStimulus'; end
		end
		
		% ===================================================================
		%> @brief subsref allow {} to call stimuli cell array
		%>
		%> @param
		%> @return
		% ===================================================================
		function sref = subsref(obj,s)
			switch s(1).type
				% Use the built-in subsref for dot notation
				case '.'
					sref = builtin('subsref',obj,s);
				case '()'
					sref = builtin('subsref',obj,s);
				case '{}'
					sref = builtin('subsref',obj.stimuli,s);
					%error('MYDataClass:subsref','Not a supported subscripted reference')
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
		
	end
end
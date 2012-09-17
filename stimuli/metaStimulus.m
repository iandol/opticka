% ========================================================================
%> @brief metaStimulus is a  wrapper for opticka stimuli
%> METASTIMULUS a collection of stimuli, wrapped in one structure. It
%> allows you to reat a group of heterogenous stimuli as if it is a single
%> stimulus, so for example animate(metaStimulus) will run the animate method
%> for all stimuli in the group without having to call it for each stimulus.
%> You can also pick individual stimuli by using cell indexing of this
%> object. So for example metaStimulus{2} actually calls
%> metaStimulus.stimuli{2}.
% ========================================================================
classdef metaStimulus < optickaCore
	
	%--------------------PUBLIC PROPERTIES----------%
	properties 
		%>cell array of opticka stimuli to manage
		stimuli = {}
		%> screenManager handle
		screen
		%> verbose?
		verbose = true
		%> choice allows to call only 1 stimulus in the group
		choice = []
	end
	
	%--------------------DEPENDENT PROPERTIES----------%
	properties (SetAccess = private, Dependent = true) 
		%> n number of stimuli managed by metaStimulus
		n
	end
	
	%--------------------VISIBLE PROPERTIES----------%
	properties (SetAccess = private, GetAccess = public) 
		%> stimulus family
		family = 'meta'
		%> for heterogenous stimuli, we need a way to index into the stimulus so
		%> we don't waste time doing this on each iteration
		sList
	end
	
	%--------------------PRIVATE PROPERTIES----------%
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
		%> @param varargin are passed as a structure of properties which is
		%> parsed.
		%> @return instance of class.
		% ===================================================================
		function obj = metaStimulus(varargin)
			if nargin == 0; varargin.name = 'metaStimulus';end
			if nargin>0; obj.parseArgs(varargin,obj.allowedProperties); end
		end
		
		% ===================================================================
		%> @brief setup wrapper
		%>
		%> @param
		%> @return
		% ===================================================================
		function setup(obj)
			for i = 1:obj.n
				setup(obj.stimuli{i},obj.screen);
			end
		end
		
		% ===================================================================
		%> @brief update wrapper
		%>
		%> @param choice override a single choice
		%> @return
		% ===================================================================
		function update(obj,choice)
			if exist('choice','var') %user forces a single stimulus
				
				update(obj.stimuli{choice});
				
			elseif ~isempty(obj.choice) %object forces a single stimulus
				
				update(obj.stimuli{obj.choice});
				
			else
		
				for i = 1:obj.n
					update(obj.stimuli{i});
				end
				
			end
		end
		
		% ===================================================================
		%> @brief draw wrapper
		%>
		%> @param choice override a single choice
		%> @return
		% ===================================================================
		function draw(obj,choice)
			if exist('choice','var') %user forces a single stimulus
				
				draw(obj.stimuli{choice});
				
			elseif ~isempty(obj.choice) %object forces a single stimulus
				
				draw(obj.stimuli{obj.choice});
				
			else
				
				for i = 1:obj.n
					draw(obj.stimuli{i});
				end
				
			end
		end
		
		% ===================================================================
		%> @brief animate wrapper
		%>
		%> @param choice allow a single selected stimulus
		%> @return
		% ===================================================================
		function animate(obj,choice)
			if exist('choice','var') %user forces a single stimulus
				
				animate(obj.stimuli{choice});
				
			elseif ~isempty(obj.choice) %object forces a single stimulus
				
				animate(obj.stimuli{obj.choice});
				
			else
				
				for i = 1:obj.n
					animate(obj.stimuli{i});
				end
				
			end
		end
		
		% ===================================================================
		%> @brief reset wrapper
		%>
		%> @param
		%> @return
		% ===================================================================
		function reset(obj)

			for i = 1:obj.n
				reset(obj.stimuli{i});
			end
			
		end
		
		function printChoice(obj)
			fprintf('%s current choice is: %g\n',obj.fullName,obj.choice)
		end
		
		% ===================================================================
		%> @brief set stimuli sanity checker
		%> @param in a stimuli group
		%> @return 
		% ===================================================================
		function set.stimuli(obj,in)
			if iscell(in) % a cell array of stimuli
				obj.stimuli = [];
				obj.stimuli = in;
			elseif isa(in,'baseStimulus') %we are a single opticka stimulus
				obj.stimuli = {in};
			elseif isempty(in)
				obj.stimuli = {};
			else
				error([obj.name ':set stimuli | not a cell array or baseStimulus child']);
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
		
		% ===================================================================
		%> @brief subsref allow {} to call stimuli cell array directly
		%>
		%> @param  s is the subsref struct
		%> @return varargout any output for the reference
		% ===================================================================
		function varargout = subsref(obj,s)
			switch s(1).type
				% Use the built-in subsref for dot notation
				case '.'
					[varargout{1:nargout}] = builtin('subsref',obj,s);
				case '()'
					%error([obj.name ':subsref'],'Not a supported subscripted reference')
					[varargout{1:nargout}] = builtin('subsref',obj.stimuli,s);
				case '{}'
					[varargout{1:nargout}] = builtin('subsref',obj.stimuli,s);
			end
		end
		
		% ===================================================================
		%> @brief subsasgn allow {} to assign to the stimuli cell array
		%>
		%> @param  s is the subsref struct
		%> @param val is the value to assign
		%> @return obj object
		% ===================================================================
		function obj = subsasgn(obj,s,val)
			switch s(1).type
				% Use the built-in subsref for dot notation
				case '.'
					obj = builtin('subsasgn',obj,s,val);
				case '()'
					%error([obj.name ':subsasgn'],'Not a supported subscripted reference')
					sout = builtin('subsasgn',obj.stimuli,s,val);
					if ~isempty(sout)
						obj.stimuli = sout;
					else
						obj.stimuli = {};
					end
				case '{}'
					sout = builtin('subsasgn',obj.stimuli,s,val);
					if ~isempty(sout)
						if max(size(sout)) == 1
							sout = sout{1};
						end
						obj.stimuli = sout;
					else
						obj.stimuli = {};
					end
			end
		end
		
	end
end
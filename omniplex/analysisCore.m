% ========================================================================
%> @brief analysisCore base class inherited by other analysis classes.
%> analysidCore is itself derived from optickaCore. 
% ========================================================================
classdef analysisCore < optickaCore
	
	%--------------------PUBLIC PROPERTIES----------%
	properties
		doPlots@logical = true
	end
	
	%--------------------ABSTRACT PROPERTIES----------%
	properties (Abstract = true)
		
	end
	
	%--------------------HIDDEN PROPERTIES------------%
	properties (SetAccess = protected, Hidden = true)
		
	end
	
	%--------------------VISIBLE PROPERTIES-----------%
	properties (SetAccess = protected, GetAccess = public)
		
	end
	
	%--------------------DEPENDENT PROPERTIES----------%
	properties (SetAccess = private, Dependent = true)
		
	end
	
	%--------------------TRANSIENT PROPERTIES----------%
	properties (SetAccess = protected, GetAccess = protected, Transient = true)
		
	end
	
	%--------------------PROTECTED PROPERTIES----------%
	properties (SetAccess = protected, GetAccess = protected)
		
	end
	
	%--------------------PRIVATE PROPERTIES----------%
	properties (SetAccess = private, GetAccess = private)
		%> allowed properties passed to object upon construction
		allowedProperties@char = ''
	end
	
	%=======================================================================
	methods %------------------PUBLIC METHODS
	%=======================================================================
		
		% ==================================================================
		%> @brief Class constructor
		%>
		%> More detailed description of what the constructor does.
		%>
		%> @param args are passed as a structure of properties which is
		%> parsed.
		%> @return instance of class.
		% ==================================================================
		function ego = analysisCore(varargin)
			if nargin == 0; varargin.name = ''; end
			ego=ego@optickaCore(varargin); %superclass constructor
			if nargin>0; ego.parseArgs(varargin, ego.allowedProperties); end
		end
		
	end %---END PUBLIC METHODS---%
	
	%=======================================================================
	methods ( Static = true) %-------STATIC METHODS-----%
	%=======================================================================
	
		% ==================================================================
		%> @brief find nearest value in a vector
		%>
		%> @param in input vector
		%> @param value value to find
		%> @return idx index position of nearest value
		%> @return val value of nearest value
		%> @return delta the difference between val and value
		% ==================================================================
		function [idx,val,delta]=findNearest(in,value)
			tmp = abs(in-value);
			[~,idx] = min(tmp);
			val = in(idx);
			delta = abs(value - val);
		end
		
		% ===================================================================
		%> @brief set paths for object
		%>
		%> @param 
		% ===================================================================
		function [err]=var2SE(var,dof)
			err = sqrt(var ./ dof);
		end
		
		% ===================================================================
		%> @brief set paths for object
		%>
		%> @param 
		% ===================================================================
		function [row,col]=optimalLayout(len)
			row=1; col=1;
			if		len == 2	row = 2;	col = 1;
			elseif	len == 3	row = 3;	col = 1;
			elseif	len == 4	row = 2;	col = 2;
			elseif	len < 7	row = 3;	col = 2;
			elseif	len < 10	row = 3;	col = 3;
			elseif	len < 13	row = 4;	col = 3;
			elseif	len < 17	row = 4;	col = 4;
			elseif	len < 21	row = 5;	col = 4;
			end
		end
		
	end %---END STATIC METHODS---%
	
	%=======================================================================
	methods ( Access = protected ) %-------PROTECTED METHODS-----%
	%=======================================================================
		
		% ===================================================================
		%> @brief set paths for object
		%>
		%> @param 
		% ===================================================================
		
		
		
	end %---END PROTECTED METHODS---%
	
end %---END CLASSDEF---%
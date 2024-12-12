% ========================================================================
classdef alyxManager < optickaCore
%> @class alyxManager
%> @brief manage connection to an Alyx database
%>
%>
%> Copyright ©2014-2024 Ian Max Andolina — released: LGPL3, see LICENCE.md
% ========================================================================


	%--------------------PUBLIC PROPERTIES----------%
	properties
		IP						= '172.16.102.30'
		port					= 8000
		%> Do we log extra details to the command-line?
		verbose					= false
	end

	%--------------------TRANSIENT PROPERTIES-----------%
	properties (Transient = true)
		
	end

	%--------------------HIDDEN PROPERTIES-----------%
	properties(Transient = true, Hidden = true)
		
	end
	
	%--------------------VISIBLE PROPERTIES-----------%
	properties (SetAccess = protected, GetAccess = public)
		
	end
	
	%--------------------DEPENDENT PROTECTED PROPERTIES----------%
	properties (Dependent = true, SetAccess = protected, GetAccess = public)
		
	end
	
	%--------------------TRANSIENT PROTECTED PROPERTIES----------%
	properties (SetAccess = protected, Transient = true)
		
	end
	
	%--------------------PROTECTED PROPERTIES----------%
	properties (Access = protected)
		
	end
	
	%--------------------PRIVATE PROPERTIES----------%
	properties (SetAccess = private, GetAccess = private)
		%> properties allowed to be passed on construction
		allowedProperties = {''}
	end
	
	
	%=======================================================================
	methods %----------------------------PUBLIC METHODS
	%=======================================================================
		
		% ===================================================================
		%> @brief Class constructor
		%>
		%> @param varargin are passed as a structure / cell of properties which is
		%> parsed.
		%> @return instance of class.
		% ===================================================================
		function me = alyxManager(varargin)
			me=me@optickaCore(varargin); %superclass constructor
			me.parseArgs(varargin, me.allowedProperties);
		end

	end %---END PUBLIC METHODS---%

	%=======================================================================
	methods ( Static ) %----------STATIC METHODS
	%=======================================================================

		

	end%---END STATIC METHODS---%

	%=======================================================================
	methods ( Access = protected ) %-------PRIVATE (protected) METHODS-----%
	%=======================================================================


		% ===================================================================
		%> @fn Delete method
		%>
		%> @param me
		%> @return
		% ===================================================================
		function delete(me)
			if me.verbose; fprintf('--->>> Delete: %s\n',me.fullName); end
		end
		
	end%---END PRIVATE METHODS---%
end

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
		baseURL	char			= 'http://172.16.102.30:8000'
		queueDir char			= ''
		pageLimit				= 100
		sessionURL
		%> Do we log extra details to the command-line?
		verbose					= false
	end

	%--------------------TRANSIENT PROPERTIES-----------%
	properties (Transient = true)
		webOptions				= weboptions('MediaType','application/json','Timeout',10);
	end

	%--------------------HIDDEN PROPERTIES-----------%
	properties(Transient = true, Hidden = true)
		
	end
	
	%--------------------VISIBLE PROPERTIES-----------%
	properties (SetAccess = protected, GetAccess = public)
		user					= 'admin'
	end
	
	%--------------------DEPENDENT PROTECTED PROPERTIES----------%
	properties (Dependent = true, SetAccess = protected, GetAccess = public)
		loggedIn
	end
	
	%--------------------TRANSIENT PROTECTED PROPERTIES----------%
	properties (SetAccess = protected, Transient = true)
		token
	end
	
	%--------------------PROTECTED PROPERTIES----------%
	properties (Access = protected)
		
	end
	
	%--------------------PRIVATE PROPERTIES----------%
	properties (SetAccess = private, GetAccess = private)
		%> properties allowed to be passed on construction
		allowedProperties = {'baseURL'}
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

		function me = logout(me)
      		%LOGOUT Delete token and user data from object
      		% Unsets the User, Token and SessionURL attributes
      		% Example:
      		%   ai = Alyx;
      		%   ai.login; % Get token, set user
      		%   ai.logout; % Remove token, unset user
      		% See also LOGIN
      		me.Token = [];
      		me.WebOptions.HeaderFields = []; % Remove token from header field
      		me.User = [];
		end

		function bool = get.loggedIn(me)
      		bool = ~isempty(me.user) && ~isempty(me.token);
		end

		function set.queueDir(me, qDir)
			%SET.QUEUEDIR Ensure directory exists
			if ~exist(qDir, 'dir'); mkdir(qDir); end
			me.queueDir = qDir;
    	end
    	
    	function set.baseURL(me, value)
			% Drop trailing slash and ensure protocol defined
			if isempty(value); me.BaseURL = ''; return; end % return on empty
			if matches(value(1:4), 'http'); value = ['https://' value]; end
			if value(end)=='/'; me.baseURL = value(1:end-1); else; me.baseURL =  value; end
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

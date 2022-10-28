classdef touchManager < optickaCore
	
	%--------------------PUBLIC PROPERTIES----------%
	properties
		nTouchScreens = 1;
	end
	
	properties
		devices
	end

	%=======================================================================
	methods %------------------PUBLIC METHODS
	%=======================================================================

		% ===================================================================
		function me = touchManager(varargin)
		%> @fn touchManager
		%> @brief Class constructor
		%>
		%> Initialises the class sending any parameters to parseArgs.
		%>
		%> @param varargin are passed as a structure of properties which is
		%> parsed.
		%> @return instance of the class.
		% ===================================================================
			args = optickaCore.addDefaults(varargin,struct('name','touchManager'));
			me = me@optickaCore(args); %superclass constructor
			me.parseArgs(args,me.allowedProperties);
			devices = GetTouchDeviceIndices([], 1);
		end

		function outputArg = setup(me)
			info_front      = GetTouchDeviceInfo(devices(1));
			disp(info_front);
			info_back       = GetTouchDeviceInfo(devices(2));
			disp(info_back);
			TouchQueueCreate(win, dev(1));
			TouchQueueCreate(win, dev(2));
		end
	end
end
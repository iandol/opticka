classdef touchManager < optickaCore
	%UNTITLED Summary of this class goes here
	%   Detailed explanation goes here

	%--------------------PUBLIC PROPERTIES----------%
	properties
		device		= 1
		verbose		= false
	end

	properties (SetAccess=private,GetAccess=public)
		devices
		names
		allinfo
		nSlots = 1e5
		win			= []
	end

	properties (SetAccess = private, GetAccess = private)
		allowedProperties char	= ['device'...
			'verbose']
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
			me.parseArgs(args, me.allowedProperties);
			[me.devices,me.names,me.allinfo] = GetTouchDeviceIndices([], 1);
		end

		%================SET UP TOUCH INPUT============
		function  setup(me, sM)
			if sM.isOpen; me.win = sM.win; end
			if isempty(me.devices)
				me.comment = 'No Touch Screen are available, please check the usb end';
				fprintf('--->touchManager: %s\n',me.comment);
			elseif length(me.devices)==1
				me.comment = 'found one Touch Screen plugged ';
				fprintf('--->touchManager: %s\n',me.comment);
			elseif length(me.devices)==2
				me.comment = 'found two Touch Screens plugged ';
				fprintf('--->touchManager: %s\n',me.comment);
			end
		end

		%================SET UP TOUCH INPUT============
		function createQueue(me, choice)
			if ~exist('choice','var') || isempty(choice)
				choice=me.device;
			end
			for i = 1:length(choice)
				TouchQueueCreate(me.win, me.devices(choice(i)), me.nSlots);
			end
		end

		%===============START=========
		function start(me, choice)
			if ~exist('choice','var') || isempty(choice)
				choice=me.device;
			end
			for i = 1:length(choice)
				TouchQueueStart(me.devices(choice(i)));
			end
		end

		%===============FLUSH=========
		function flush(me, choice)
			if ~exist('choice','var') || isempty(choice)
				choice = me.device;
			end
			for i = 1:length(choice)
				TouchEventFlush(me.devices(choice(i)));
			end
		end

		%===========EVENT AVAIL=========
		function navail = eventAvail(me, choice)
			if ~exist('choice','var') || isempty(choice)
				choice=me.device;
			end
			for i = 1:length(choice)
				navail(i)=TouchEventAvail(me.devices(choice(i))); %#ok<*AGROW> 
			end
		end

		%===========GETEVENT=========
		function event = getEvent(me, choice)
			if ~exist('choice','var') || isempty(choice)
				choice=me.device;
			end
			for i = 1:length(choice)
				event{i} = TouchEventGet(me.devices(choice(i)), me.win);
			end
		end

		%===========STOP=========
		function stop(me)
			if ~exist('choice','var') || isempty(choice)
				choice=me.device;
			end
			for i = 1:length(choice)
				TouchQueueStop(me.devices(choice(i)));
			end
		end

	end
end
classdef touchManager < optickaCore
	%UNTITLED Summary of this class goes here
	%   Detailed explanation goes here

	%--------------------PUBLIC PROPERTIES----------%
	properties
		%> which touch device to connect to?
		device				= 1
		%> use the mouse instead of the touch screen for debugging
		isDummy				= false
		%> accept window (circular when radius is 1 value, rectangular when radius = [width height]) 
		%> doNegation allows to return -100 (like exclusion) if touch is outside window.
		window				= struct('X', 0, 'Y', 0, 'radius', 2, 'doNegation', false);
		%> Use exclusion zones where no eye movement allowed: [left,top,right,bottom]
		%> Add rows to generate multiple exclusion zones.
		exclusionZone		= []
		%> number of slots for touch events
		nSlots				= 1e5
		%> size in degrees around the window for negation to trigger
		negationBuffer		= 2
		%> verbosity
		verbose				= false
	end

	properties (SetAccess=private, GetAccess=public)
		devices				= []
		names				= []
		allInfo				= []
		x					= -1
		y					= -1
		isOpen				= false
		isQueue				= false
	end	

	properties (Access = private)
		ppd					= 36
		screen				= []
		win					= []
		screenVals			= []
		allowedProperties	= {'isDummy','device','verbose','window','nSlots','negationBuffer'}
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
			try [me.devices,me.names,me.allInfo] = GetTouchDeviceIndices([], 1); end %#ok<*TRYNC> 
		end

		%================SET UP TOUCH INPUT============
		function  setup(me, sM)
			if isa(sM,'screenManager') && sM.isOpen
				me.screen = sM;
				me.win = sM.win; 
				me.ppd = sM.ppd;
				me.screenVals = sM.screenVals;
			else
				error('Need to pass an open screenManager object!');
			end
			try [me.devices,me.names,me.allInfo] = GetTouchDeviceIndices([], 1); end
			if me.isDummy
				me.comment = 'Dummy Mode Active';
				fprintf('--->touchManager: %s\n',me.comment);
			elseif isempty(me.devices)
				me.comment = 'No Touch Screen are available, please check USB!';
				fprintf('--->touchManager: %s\n',me.comment);
			elseif length(me.devices)==1
				me.comment = 'found ONE Touch Screen...';
				fprintf('--->touchManager: %s\n',me.comment);
			elseif length(me.devices)==2
				me.comment = 'found TWO Touch Screens plugged...';
				fprintf('--->touchManager: %s\n',me.comment);
			end
		end

		%================SET UP TOUCH INPUT============
		function createQueue(me, choice)
			if me.isDummy; return; end
			if ~exist('choice','var') || isempty(choice)
				choice = me.device;
			end
			for i = 1:length(choice)
				try
					TouchQueueCreate(me.win, me.devices(choice(i)), me.nSlots);
				catch
					warning('touchManager: Cannot create touch queue!');
				end
			end
			me.isQueue = true;
			if me.verbose;me.logEvent('createQueue','Opened');end
		end

		%===============START=========
		function start(me, choice)
			if me.isDummy; return; end
			if ~exist('choice','var') || isempty(choice)
				choice=me.device;
			end
			if ~me.isQueue; createQueue(me,choice); end
			for i = 1:length(choice)
				TouchQueueStart(me.devices(choice(i)));
			end
			me.isOpen = true;
			if me.verbose;me.logEvent('start','Started queue');end
		end

		%===============FLUSH=========
		function flush(me, choice)
			if me.isDummy; return; end
			if ~exist('choice','var') || isempty(choice)
				choice = me.device;
			end
			for i = 1:length(choice)
				TouchEventFlush(me.devices(choice(i)));
			end
		end

		%===========EVENT AVAIL=========
		function navail = eventAvail(me, choice)
			navail = [];
			if me.isDummy
				[x,y,b] = GetMouse;
				if any(b); navail = true; end
				return
			end
			if ~exist('choice','var') || isempty(choice);choice=me.device;end
			for i = 1:length(choice)
				navail(i)=TouchEventAvail(me.devices(choice(i))); %#ok<*AGROW> 
			end
		end

		%===========GETEVENT=========
		function event = getEvent(me, choice)
			event = {};
			if me.isDummy
				[x,y,b] = GetMouse(me.win);
				if any(b)
					event{1} = struct('Type',2,'Time',GetSecs,...
					'X',x,'Y',y,'ButtonStates',b,...
					'NormX',x/me.screenVals.width,'NormY',y/me.screenVals.height);
				end
				return;
			end
			if ~exist('choice','var') || isempty(choice)
				choice=me.device;
			end
			for i = 1:length(choice)
				event{i} = TouchEventGet(me.devices(choice(i)), me.win);
			end
		end
		
		%===========CHECK TOUCH WINDOW=========
		function [result, x, y] = checkTouchWindow(me, choice)
			result = false; x = []; y = [];
			if me.isDummy
				event = getEvent(me);
				if isempty(event); return; end
				while iscell(event);event = event{1}; end
				if isempty(event); return; end
				xy = me.screen.toDegrees([event.X event.Y]);
				if me.verbose;fprintf('dummy touch: %i %.2f %i %.2f\n',event.X, xy(1), event.Y, xy(2));end
				result = calculateWindow(me, xy(1), xy(2));
				x = xy(1); y = xy(2);
			else
				if ~exist('choice','var') || isempty(choice);choice=me.device;end
				if ~isempty(eventAvail(me,choice))
					event = getEvent(me);
					if isempty(event); return; end
					while iscell(event);event = event{1}; end
					if isempty(event); return; end
					xy = me.screen.toDegrees([event.X event.Y]);
					if me.verbose;fprintf('touch: %i %.2f %i %.2f\n',event.X, xy(1), event.Y, xy(2));end
					result = calculateWindow(me, xy(1), xy(2));
					x = xy(1); y = xy(2);
				end
			end
			if result == -100; fprintf('NEGATION!\n'); end
		end

		%===========CLOSE=========
		function close(me, choice)
			me.isOpen = false;
			me.isQueue = false;
			if ~exist('choice','var') || isempty(choice)
				choice = me.device;
			end
			if me.isDummy
				salutation(me,'Closing dummy touchManager...');
			else
				for i = 1:length(choice)
					TouchQueueStop(me.devices(choice(i)));
				end
				salutation(me,'Closing touchManager...');
			end
		end

	end

	methods (Access = protected)
		%===========calculateWindow=========
		function result = calculateWindow(me, x, y)
			result = false; resultneg = false; match = false;
			window = false; windowneg = false; 
			radius = me.window.radius;
			negradius = radius + me.negationBuffer;
			xWin = me.window.X;
			yWin = me.window.Y;
			ez = me.exclusionZone;
			% ---- test for exclusion zones first
			if ~isempty(ez)
				for i = 1:size(ez,1)
					% [-x +x -y +y]
					if (x >= ez(i,1) && x <= ez(i,3)) && ...
						(y >= ez(i,2) && y <= ez(i,4))
						result = -100;
						return;
					end
				end
			end
			% ---- circular test
			if length(radius) == 1 
				r = sqrt((x - xWin).^2 + (y - yWin).^2); %fprintf('x: %g-%g y: %g-%g r: %g-%g\n',x, me.window.X, me.y, me.window.Y,r,me.window.radius);
				window = find(r < radius);
				windowneg = find(r < negradius);
			else % ---- x y rectangular window test
				for i = 1:length(xWin)
					if (x >= (xWin - radius(1))) && (x <= (xWin + radius(1))) ...
							&& (y >= (yWin - radius(2))) && (y <= (yWin + radius(2)))
						window(i) = i;
						match = true;
					end
					if (x >= (xWin - negradius(1))) && (x <= (xWin + negradius(1))) ...
							&& (y >= (yWin - negradius(2))) && (y <= (yWin + negradius(2)))
						windowneg(i) = i;
					end
					if match == true; break; end
				end
			end
			if any(window); result = true;end
			if any(windowneg); resultneg = true; end
			if me.window.doNegation && resultneg == false
				result = -100; 
			end
		end
	end
end

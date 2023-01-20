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

		% ===================================================================CONSTRUCTOR
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

		% ===================================================================SETUP
		function  setup(me, sM)
		%> @fn setup
		%>
		%> @param
		%> @return 
		% ===================================================================
			me.isOpen = false; me.isQueue = false;
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

		% ===================================================================
		function createQueue(me, choice)
		%> @fn setup
		%>
		%> @param
		%> @return 
		% ===================================================================
			if me.isDummy; me.isQueue = true; return; end
			if ~exist('choice','var') || isempty(choice); choice = me.device; end
			for i = 1:length(choice)
				try
					TouchQueueCreate(me.win, me.devices(choice(i)), me.nSlots);
				catch
					warning('touchManager: Cannot create touch queue!');
				end
			end
			me.isQueue = true;
			if me.verbose;me.salutation('createQueue','Opened');end
		end

		% ===================================================================
		function start(me, choice)
		%> @fn setup
		%>
		%> @param
		%> @return 
		% ===================================================================
			if me.isDummy; me.isOpen = true; return; end
			if ~exist('choice','var') || isempty(choice); choice = me.device; end
			if ~me.isQueue; createQueue(me,choice); end
			for i = 1:length(choice)
				TouchQueueStart(me.devices(choice(i)));
			end
			me.isOpen = true;
			if me.verbose;salutation(me,'start','Started queue...');end
		end
		
		% ===================================================================
		function stop(me, choice)
		%> @fn stop
		%>
		%> @param
		%> @return 
		% ===================================================================
			if me.isDummy; me.isOpen = false; return; end
			if ~exist('choice','var') || isempty(choice); choice = me.device; end
			for i = 1:length(choice)
				TouchQueueStop(me.devices(choice(i)));
			end
			me.isOpen = false;
			salutation(me,'stop','Stopped queue...');
		end

		% ===================================================================
		function close(me, choice)
		%> @fn close
		%>
		%> @param
		%> @return 
		% ===================================================================
			me.isOpen = false;
			me.isQueue = false;
			if me.isDummy; return; end
			if ~exist('choice','var') || isempty(choice); choice = me.device; end
			for i = 1:length(choice)
				TouchQueueRelease(me.devices(choice(i)));
			end
			salutation(me,'close','Closing...');
		end

		% ===================================================================
		function flush(me, choice)
		%> @fn flush
		%>
		%> @param
		%> @return 
		% ===================================================================
			if me.isDummy; return; end
			if ~exist('choice','var') || isempty(choice); choice = me.device; end
			for i = 1:length(choice)
				TouchEventFlush(me.devices(choice(i)));
			end
		end

		% ===================================================================
		function navail = eventAvail(me, choice)
		%> @fn eventAvail
		%>
		%> @param
		%> @return 
		% ===================================================================
			navail = [];
			if me.isDummy
				[~, ~, b] = GetMouse;
				if any(b); navail = true; end
				return
			end
			if ~exist('choice','var') || isempty(choice); choice=me.device; end
			for i = 1:length(choice)
				navail(i)=TouchEventAvail(me.devices(choice(i))); %#ok<*AGROW> 
			end
		end

		% ===================================================================
		function event = getEvent(me, choice)
		%> @fn getEvent
		%>
		%> @param
		%> @return 
		% ===================================================================
			event = {};
			if me.isDummy
				[mx, my, b] = GetMouse(me.win); 
				if any(b)
					event{1} = struct('Type',2,'Time',GetSecs,...
					'X',mx,'Y',my,'ButtonStates',b,...
					'NormX',mx/me.screenVals.width,'NormY',my/me.screenVals.height, ...
					'MappedX',mx,'MappedY',my);
				end
				return;
			end
			if ~exist('choice','var') || isempty(choice); choice=me.device; end
			for i = 1:length(choice)
				event{i} = TouchEventGet(me.devices(choice(i)), me.win);
			end
		end
		
		% ===================================================================
		function [result, x, y] = checkTouchWindow(me, window)
		%> @fn checkTouchWindow
		%>
		%> @param
		%> @return 
		% ===================================================================
			if ~exist('window','var'); window = []; end
			result = false; x = []; y = [];
			event = getEvent(me);
			while ~isempty(event) && iscell(event); event = event{1}; end
			if isempty(event) || ~isfield(event,'MappedX'); return; end
			xy = me.screen.toDegrees([event.MappedX event.MappedY]);
			result = calculateWindow(me, xy(1), xy(2), window);
			x = xy(1); y = xy(2);
			if me.verbose;fprintf('IN: %i Touch: x = %i (%.2f) y = %i (%.2f)\n',result, event.X, xy(1), event.Y, xy(2));end
		end

		% ===================================================================
		function [result, x, y] = checkTouchWindows(me, windows)
		%> @fn checkTouchWindow
		%>
		%> @param
		%> @return 
		% ===================================================================
			if ~exist('windows','var') || isempty(windows); return; end
			nWindows = size(windows,1);
			result = logical(zeros(nWindows,1)); x = zeros(nWindows,1); y = zeros(nWindows,1);
			event = getEvent(me);
			while ~isempty(event) && iscell(event); event = event{1}; end
			if isempty(event) || ~isfield(event,'MappedX'); return; end
			xy = me.screen.toDegrees([event.MappedX event.MappedY]);
			for i = 1 : nWindows
				result(i,1) = calculateWindow(me, xy(1), xy(2), windows(i,:));
				x(i,1) = xy(1); y(i,1) = xy(2);
				if result(i,1)==true; break; end
			end
		end

		% ===================================================================
		function demo(me)
		%> @fn demo
		%>
		%> @param
		%> @return 
		% ===================================================================
			if isempty(me.screen); me.screen = screenManager(); end
			oldWin = me.window;
			oldVerbose = me.verbose;
			me.verbose = true;
			sM = me.screen;
			if ~sM.isOpen; open(sM); end
			setup(me, sM); % !!! Run setup first
			im = imageStimulus('size', 5);
			setup(im, sM);

			createQueue(me); % !!! Create Queue
			start(me); % !!! Start touch collection
			try 
				for i = 1 : 5
					tx = randi(20)-10;
					ty = randi(20)-10;
					im.xPositionOut = tx;
					im.yPositionOut = ty;
					update(im);
					rect = toDegrees(sM, im.mvRect, 'rect');
	
					flush(me); %!!! flush the queue
					txt = '';
					ts = GetSecs;
					while GetSecs <= ts + 10
						x = []; y = [];
						drawText(sM,txt); drawGrid(sM);
						draw(im);
						flip(sM);
						[r,x,y] = checkTouchWindow(me, rect); %!!! check touch window
						if r
							txt = sprintf('IN window x = %.2f y = %.2f',x,y);
						elseif ~isempty(x)
							txt = sprintf('OUT window x = %.2f y = %.2f',x,y);
						end
						flush(me);
					end
					flip(sM); WaitSecs(1);
				end
				stop(me); close(me);
				me.window = oldWin;
				me.verbose = oldVerbose;
				try reset(im); end
				try close(sM); end
			catch ME
				try reset(im); end
				try close(s); end
				try close(me); end
			end
		end

	end

	%=======================================================================
	methods (Static = true) %------------------STATIC METHODS
	%=======================================================================

	end

	%=======================================================================
	methods (Access = protected) %------------------PROTECTED METHODS
	%=======================================================================

		% ===================================================================
		function [result, window] = calculateWindow(me, x, y, tempWindow)
		%> @fn setup
		%>
		%> @param
		%> @return 
		% ===================================================================
			if exist('tempWindow','var') && isnumeric(tempWindow) && length(tempWindow) == 4
				pos = screenManager.rectToPos(tempWindow);
				radius = pos.radius;
				xWin = pos.X;
				yWin = pos.Y;
			else
				radius = me.window.radius;
				xWin = me.window.X;
				yWin = me.window.Y;
			end
			result = false; resultneg = false; match = false;
			window = false; windowneg = false; 
			negradius = radius + me.negationBuffer;
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

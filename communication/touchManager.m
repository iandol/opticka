% ========================================================================
classdef touchManager < optickaCore
%> @class touchManager
%> @brief Manages touch screens (wraps the PTB TouchQueue* functions)
%> 
%> TOUCHMANAGER -- call this and setup with screen manager, then run your
%> task. This class can handles touch windows, exclusion zones and more for
%> multiple touch screens.
%> Copyright ©2014-2022 Ian Max Andolina — released: LGPL3, see LICENCE.md
% ========================================================================

	%--------------------PUBLIC PROPERTIES----------%
	properties
		%> which touch device to connect to?
		device				= 1
		%> use the mouse instead of the touch screen for debugging
		isDummy				= false
		%> accept window (circular when radius is 1 value, rectangular when radius = [width height])
		%> doNegation allows to return -100 (like exclusion) if touch is outside window.
		%> when using the testHold etc functions:
		%> init: a timer that measures time to first touch
		%> hold: a timer that determines how long to hold
		%> release: a timer to determine the time after hold to release the window
		window				= struct('X', 0, 'Y', 0, 'radius', 2, 'doNegation', false,...
								'init', 3, 'hold', 1, 'release', 1);
		%> Use exclusion zones where no touch allowed: [left,top,right,bottom]
		%> Add rows to generate multiple exclusion zones.
		exclusionZone		= []
		%> size in degrees around the window for negation to trigger
		negationBuffer		= 2
		%> verbosity
		verbose				= false
	end

	properties (Hidden = true)
		%> number of slots for touch events
		nSlots				= 1e5
	end

	properties (SetAccess=private, GetAccess=public)
		x					= []
		y					= []
		win					= []
		hold				= struct('N',0,'start',0,'now',0,'total',0,...
							'search',0,'init',0,'length',0,'release',0)
		isHeld				= false
		wasHeld				= false
		wasNegation			= false
		isSearching			= false
		isRelease			= false
		isOpen				= false
		isQueue				= false
		devices				= []
		names				= []
		allInfo				= []
	end

	properties (Access = private)
		ppd					= 36
		screen				= []
		swin				= []
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
		function setup(me, sM)
		%> @fn setup(me, sM)
		%>
		%> @param sM screenManager to use
		%> @return 
		% ===================================================================
			me.isOpen = false; me.isQueue = false;
			if isa(sM,'screenManager') && sM.isOpen
				me.screen = sM;
				me.swin = sM.win;
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
		%> @fn createQueue(me, choice)
		%>
		%> @param choice which touch device to use, default uses me.device
		%> @return 
		% ===================================================================
			if me.isDummy; me.isQueue = true; return; end
			if ~exist('choice','var') || isempty(choice); choice = me.device; end
			for i = 1:length(choice)
				try
					TouchQueueCreate(me.swin, me.devices(choice(i)), me.nSlots);
				catch
					warning('touchManager: Cannot create touch queue!');
				end
			end
			me.isQueue = true;
			if me.verbose; me.salutation('createQueue','Opened'); end
		end

		% ===================================================================
		function start(me, choice)
		%> @fn start(me, choice)
		%>
		%> @param choice which touch device to use, default uses me.device
		%> @return 
		% ===================================================================
			if me.isDummy; me.isOpen = true; return; end
			if ~exist('choice','var') || isempty(choice); choice = me.device; end
			if ~me.isQueue; createQueue(me,choice); end
			for i = 1:length(choice)
				TouchQueueStart(me.devices(choice(i)));
			end
			me.isOpen = true;
			if me.verbose; salutation(me,'start','Started queue...'); end
		end

		% ===================================================================
		function stop(me, choice)
		%> @fn stop(me, choice)
		%>
		%> @param choice which touch device to use, default uses me.device
		%> @return 
		% ===================================================================
			if me.isDummy; me.isOpen = false; return; end
			if ~exist('choice','var') || isempty(choice); choice = me.device; end
			for i = 1:length(choice)
				TouchQueueStop(me.devices(choice(i)));
			end
			me.isOpen = false;
			if me.verbose; salutation(me,'stop','Stopped queue...'); end
		end

		% ===================================================================
		function close(me, choice)
		%> @fn close(me, choice)
		%>
		%> @param choice which touch device to use, default uses me.device
		%> @return 
		% ===================================================================
			me.isOpen = false;
			me.isQueue = false;
			if me.isDummy; return; end
			if ~exist('choice','var') || isempty(choice); choice = me.device; end
			for i = 1:length(choice)
				TouchQueueRelease(me.devices(choice(i)));
			end
			if me.verbose; salutation(me,'close','Closing...'); end
		end

		% ===================================================================
		function flush(me, choice)
		%> @fn flush(me, choice)
		%>
		%> @param choice which touch device to use, default uses me.device
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
		%> @fn eventAvail(me, choice)
		%>
		%> @param choice which touch device to use, default uses me.device
		%> @return nAvail number of available events
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
		%> @param choice which touch device to use, default uses me.device
		%> @return event structure
		% ===================================================================
			event = {};
			if me.isDummy
				[mx, my, b] = GetMouse(me.swin);
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
				event{i} = TouchEventGet(me.devices(choice(i)), me.swin);
			end
		end

		% ===================================================================
		function resetAll(me)
		%> @fn resetAll
		%>
		%> @param
		%> @return
		% ===================================================================
			me.hold			= struct('N',0,'start',0,'now',0,'total',0,...
							'search',0,'init',0,'length',0,'release',0);
			me.x			= [];
			me.y			= [];
			me.win			= [];
			me.isHeld		= false;
			me.wasHeld		= false;
			me.isRelease	= false;
			me.wasNegation	= false;
			me.isSearching	= false;
		end

		% ===================================================================
		function [result, x, y] = checkTouchWindow(me, window, panelType)
		%> @fn checkTouchWindow
		%>
		%> @param window - a touch rect to test
		%> @param panelType 1 = front panel, 2 = back panel (need to reverse X)
		%> @return result - true / false
		% ===================================================================
			if ~exist('window','var'); window = []; end
			if ~exist('panelType','var') || isempty(panelType); panelType = 1; end
			result = false; x = []; y = [];
			event = getEvent(me);
			while ~isempty(event) && iscell(event); event = event{1}; end
			if isempty(event) || ~isfield(event,'MappedX'); return; end
			if panelType == 2; event.MappedX = me.screenVals.width - event.MappedX; end
			xy = me.screen.toDegrees([event.MappedX event.MappedY]);
			result = calculateWindow(me, xy(1), xy(2), window);
			x = xy(1); y = xy(2);
			me.x = x; me.y = y;
		end

		% ===================================================================
		function [result, x, y] = checkTouchWindows(me, windows, panelType)
		%> @fn [result, x, y] = checkTouchWindows(me, windows)
		%>
		%> @param windows a set of touch rects to test
		%> @param panelType 1 = front panel, 2 = back panel (need to reverse X)
		%> @return result - true / false
		% ===================================================================
			if ~exist('windows','var') || isempty(windows); return; end
			if ~exist('panelType','var') || isempty(panelType); panelType = 1; end
			nWindows = size(windows,1);
			result = logical(zeros(nWindows,1)); x = zeros(nWindows,1); y = zeros(nWindows,1);
			event = getEvent(me);
			while ~isempty(event) && iscell(event); event = event{1}; end
			if isempty(event) || ~isfield(event,'MappedX'); return; end
			if panelType == 2; event.MappedX = me.screenVals.width - event.MappedX; end
			xy = me.screen.toDegrees([event.MappedX event.MappedY]);
			for i = 1 : nWindows
				result(i,1) = calculateWindow(me, xy(1), xy(2), windows(i,:));
				x(i,1) = xy(1); y(i,1) = xy(2);
				if result(i,1)==true; me.x=x(i,1);me.y=y(i,1);break; end
			end
		end

		% ===================================================================
		%> @fn isHold
		%>
		%> @param
		%> @return
		% ===================================================================
		function [held, heldtime, release, releasing, searching, failed] = isHold(me)
			held = false; heldtime = false; release = false;
			releasing = false; searching = true; failed = false;

			me.hold.now = GetSecs;
			if me.hold.start == 0
				me.hold.N = 0;
				me.hold.total = 0;
				me.hold.search = 0;
				me.hold.init = 0;
				me.hold.length = 0;
				me.hold.release = 0;
				me.hold.start = me.hold.now;
				me.isHeld = false;
				me.wasHeld = false;
			else
				me.hold.total = me.hold.now - me.hold.start;
			end

			held = checkTouchWindow(me);

			if held == -100
				searching = false;
				failed = true;
				if me.verbose;fprintf('--->>> touchManager -100 NEGATION!\n');end
				return
			end

			if held
				searching = false;
				if me.isHeld == false
					me.hold.N = me.hold.N + 1;
					me.isHeld = true;
					me.hold.init = me.hold.now;
					me.hold.length = 0;
				else
					me.hold.length = me.hold.now - me.hold.init;
				end
				if me.hold.length >= me.window.hold
					me.wasHeld = true;
					heldtime = true;
					me.hold.release = me.hold.length;
					if me.hold.release >= (me.window.hold + me.window.release)
						releasing = false;
					else
						releasing = true;
					end

				end
			else
				me.isHeld = false;
				if me.hold.N > 0 && me.wasHeld
					searching = false; releasing = false;
					me.hold.release = me.hold.now - me.hold.init;
					if me.hold.release <= (me.window.hold + me.window.release)
						release = true;
						me.isRelease = true;
					end
				else
					me.hold.search = me.hold.total;
					if me.hold.search >= me.window.init
						searching = false;
					end
				end
			end
			if false
				fprintf('ISHOLD %.1fx %.1fy: %.2f-tot %.2f-srch %.2f-hld %.2f-rel h:%i t:%i r:%i rl:%i s:%i N:%i\n',...
				me.x,me.y,me.hold.total,me.hold.search,me.hold.length,me.hold.release,held,heldtime,release,releasing,searching,me.hold.N);
			end
		end


		% ===================================================================
		function [out, held, heldtime, release, releasing, searching, failed] = testHold(me, yesString, noString)
		%> @fn testHold
		%>
		%> @param
		%> @return
		% ===================================================================
			[held, heldtime, release, releasing, searching, failed] = isHold(me);
			out = '';
			if failed || (~held && ~searching)
				out = noString;
			elseif held && heldtime
				out = yesString;
			end
		end

		% ===================================================================
		function [out, held, heldtime, release, releasing, searching, failed] = testHoldRelease(me, yesString, noString)
		%> @fn testHoldRelease
		%>
		%> @param
		%> @return
		% ===================================================================
			[held, heldtime, release, releasing, searching, failed] = isHold(me);
			out = '';
			if failed || (held && heldtime && ~releasing)
				out = noString;
			elseif ~held && me.hold.N > 0 && ~me.wasHeld
				out = noString;
			elseif ~held && me.hold.N == 1 && me.wasHeld && release
				out = yesString;
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
			setup(me, sM); 		%===================!!! Run setup first
			im = discStimulus('size', 5);
			setup(im, sM);

			quitKey = KbName('escape');
			doQuit = false;
			createQueue(me);	%===================!!! Create Queue
			start(me); 			%===================!!! Start touch collection
			try
				for i = 1 : 5
					if doQuit; break; end
					tx = randi(20)-10;
					ty = randi(20)-10;
					im.xPositionOut = tx;
					im.yPositionOut = ty;
					me.window.X = tx;
					me.window.Y = ty;
					me.window.radius = im.size;
					update(im);
					fprintf('\n\nTRIAL %i -- X = %i Y = %i R = %.2f\n',i,me.window.X,me.window.Y,me.window.radius);
					rect = toDegrees(sM, im.mvRect, 'rect');
					resetAll(me);
					flush(me); 	%===================!!! flush the queue
					txt = '';
					vbl = flip(sM); ts = vbl;
					result = 'timeout';
					while vbl <= ts + 10
						drawText(sM,txt); drawGrid(sM);
						if ~me.wasHeld; draw(im); end
						vbl = flip(sM);
						[r, hld, hldt, rel, reli, se] = testHoldRelease(me,'yes','no');
						if hld
							txt = sprintf('%s IN x = %.1f y = %.1f - h:%i t:%i r:%i rl:%i s:%i N:%i',r,me.x,me.y,hld,hldt,rel,reli,se,me.hold.N);
						elseif ~isempty(me.x)
							txt = sprintf('%s OUT x = %.1f y = %.1f - h:%i t:%i r:%i rl:%i s:%i N:%i',r,me.x,me.y,hld,hldt,rel,reli,se,me.hold.N);
						else
							txt = sprintf('%s NO touch - h:%i t:%i r:%i rl:%i s:%i N:%i',r,hld,hldt,rel,reli,se,me.hold.N);
						end
						flush(me);
						if strcmp(r,'yes')
							result = 'correct'; break;
						elseif strcmp(r,'no')
							result = 'incorrect'; break;
						end
						[~,~,keys] = optickaCore.getKeys();
						if any(keys(quitKey)); doQuit = true; break; end
					end
					fprintf('RESULT: %s - \n',result);
					disp(me.hold);
					drawTextNow(sM,result); WaitSecs(3);
				end
				stop(me); close(me); %===================!!! stop and close
				me.window = oldWin;
				me.verbose = oldVerbose;
				try reset(im); end
				try close(sM); end
			catch ME
				try reset(im); end
				try close(sM); end
				try close(me); end
				sca
				rethrow(ME);
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
				r = sqrt((x - xWin).^2 + (y - yWin).^2); %fprintf('X: %.1f-%.1f Y: %.1f-%.1f R: %.1f-%.1f\n',x, xWin, me.y, yWin, r, radius);
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
			me.win = window;
			if any(window); result = true;end
			if any(windowneg); resultneg = true; end
			if me.window.doNegation && resultneg == false
				result = -100;
			end
		end
	end
end

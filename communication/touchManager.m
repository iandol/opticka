% ========================================================================
classdef touchManager < optickaCore
%> @class touchManager
%> @brief Manages touch screens (wraps the PTB TouchQueue* functions), and
%> provides touch area management methods
%>
%> TOUCHMANAGER -- call this and setup with screen manager, then run your
%> task. This class can handles touch windows, exclusion zones and more for
%> multiple touch screens.
%>
%> Copyright ©2014-2024 Ian Max Andolina — released: LGPL3, see LICENCE.md
% ========================================================================

	%--------------------PUBLIC PROPERTIES----------%
	properties
		%> which touch device to connect to?
		device				= 1
		%> use the mouse instead of the touch screen for debugging
		isDummy				= false
		%> window is a touch window, X and Y are the screen postion
		%> radius: circular when radius is 1 value, rectangular when radius = [width height])
		%> doNegation: allows to return -100 (like exclusion) if touch is outside window.
		%> when using the testHold etc functions. negationBuffer is an area
		%> around he window to allow some margin of error...
		%> init: a timer that measures time to first touch
		%> hold: a timer that determines how long to hold
		%> release: a timer to determine the time after hold in which to release the window
		window				= struct('X', 0, 'Y', 0, 'radius', 2, 'doNegation', false,...
								'negationBuffer', 2, 'strict', true,...
								'init', 3, 'hold', 0.1, 'release', 1);
		%> Use exclusion zones where no touch allowed: [left,top,right,bottom]
		%> Add rows to generate multiple exclusion zones.
		exclusionZone		= []
		%> drain the events to only get the last one? This ensures lots of
		%> events don't pile up, often you only want the current event,
		%> but potentially causes a longer delay each time getEvent is called...
		drainEvents			= true;
		%> panel type, 1 = front, 2 = back aka reverse X position
		panelType			= 1
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
		hold				= []
		eventID				= []
		eventType			= [];
		eventNew			= false
		eventMove			= false
		eventPressed		= false
		eventRelease		= false
		wasHeld				= false
		wasNegation			= false
		isSearching			= false
		isReleased			= false
		isOpen				= false
		isQueue				= false
		devices				= []
		names				= []
		allInfo				= []
		event				= []
	end

	properties (Access = private)
		lastPressed			= false
		pressed				= false
		ppd					= 36
		screen				= []
		swin				= []
		screenVals			= []
		allowedProperties	= {'isDummy','device','verbose','window','nSlots',...
							'panelType','drainEvents','exclusionZone'}
		holdTemplate		= struct('N',0,'inWindow',false,'touched',false,...
							'start',0,'now',0,'total',0,'search',0,'init',0,'releaseinit',0,...
							'length',0,'release',0)
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
			me.hold = me.holdTemplate;
			try
				if IsLinux
					[~,r] = system('xinput');
					disp('Input Device List:');
					disp(r);
				end
			end
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
				me.comment = sprintf('found ONE Touch Screen: %s',me.names{1});
				fprintf('--->touchManager: %s\n',me.comment);
			elseif length(me.devices)==2
				me.comment = sprintf('found TWO Touch Screens plugged %s %s',me.names{1},me.names{2});
				fprintf('--->touchManager: %s\n',me.comment);
			end
		end

		% ===================================================================
		function createQueue(me)
		%> @fn createQueue(me)
		%>
		%> @param choice which touch device to use, default uses me.device
		%> @return
		% ===================================================================
			if me.isDummy; me.isQueue = true; return; end
			try
				TouchQueueCreate(me.swin, me.devices(me.device), me.nSlots);
			catch
				warning('touchManager: Cannot create touch queue!');
			end
			me.isQueue = true;
			if me.verbose; logOutput(me,'createQueue','Created...'); end
		end

		% ===================================================================
		function start(me)
		%> @fn start(me)
		%>
		%> @return
		% ===================================================================
			if me.isDummy; me.isOpen = true; return; end
			if ~me.isQueue; createQueue(me); end
			TouchQueueStart(me.devices(me.device));
			me.isOpen = true;
			if me.verbose; logOutput(me,'start','Started queue...'); end
		end

		% ===================================================================
		function stop(me)
		%> @fn stop(me)
		%>
		%> @return
		% ===================================================================
			if me.isDummy; me.isOpen = false; return; end
			TouchQueueStop(me.devices(me.device));
			me.isOpen = false; me.isQueue = false;
			if me.verbose; logOutput(me,'stop','Stopped queue...'); end
		end

		% ===================================================================
		function close(me)
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
				TouchQueueRelease(me.devices(me.device));
			end
			if me.verbose; logOutput(me,'close','Closed...'); end
		end

		% ===================================================================
		function flush(me)
		%> @fn flush(me)
		%>
		%> @param
		%> @return
		% ===================================================================
			if me.isDummy; return; end
			TouchEventFlush(me.devices(me.device));
		end

		% ===================================================================
		function navail = eventAvail(me)
		%> @fn eventAvail(me)
		%>
		%> @param
		%> @return nAvail number of available events
		% ===================================================================
			navail = 0;
			if me.isDummy
				[~, ~, b] = GetMouse;
				if any(b); navail = 1; end
			else
				navail = TouchEventAvail(me.devices(me.device));
			end
		end

		% ===================================================================
		function event = getEvent(me)
		%> @fn getEvent
		%>
		%> @param
		%> @return event structure
		% ===================================================================
			event = [];
			if me.isDummy
				[mx, my, b] = GetMouse(me.swin);
				if any(b) && ~me.lastPressed
					type = 2; motion = false; press = true;  me.lastPressed = true;
					me.eventNew = true;
					me.eventPressed = true;
				elseif any(b) && me.lastPressed
					type = 3; motion = true; press = true;  me.lastPressed = true;
					me.eventMove = true;
					me.eventPressed = true;
				elseif me.lastPressed && ~any(b)
					type = 4; motion = false; press = false; me.lastPressed = false;
					me.eventRelease = true;
				else
					type = -1; motion = false; press = 0;  me.lastPressed = false;
					me.eventNew = false; me.eventMove = false; me.eventRelease = false; me.eventPressed = false;
				end
				if type > 0
					event = struct('Type',type,'Time',GetSecs,...
					'X',mx,'Y',my,'ButtonStates',b,...
					'NormX',mx/me.screenVals.width,'NormY',my/me.screenVals.height, ...
					'MappedX',mx,'MappedY',my,...
					'Pressed',press,'Motion',motion,...
					'Keycode',55);
					event.xy = me.screen.toDegrees([event.MappedX event.MappedY],'xy');
					me.event = event;
					me.eventType	= event.Type;
					me.x = event.xy(1); me.y = event.xy(2);
				end
			else
				if me.drainEvents
					while eventAvail(me); event = TouchEventGet(me.devices(me.device), me.swin, 0); end
				else
					event = TouchEventGet(me.devices(me.device), me.swin, 0);
				end
			end
			me.eventNew = false; me.eventMove = false; me.eventRelease = false; me.eventPressed = false;
			if ~isempty(event)
				me.eventID		= event.Keycode;
				me.eventType	= event.Type;
				switch event.Type
					case 2 %NEW
						me.eventNew = true;
						me.eventPressed = true;
					case 3 %MOVE
						me.eventMove = true;
						me.eventPressed = true;
					case 4 %RELEASE
						me.eventRelease = true;
					case 5 %ERROR
						disp('Event lost!');
						me.event = []; event = [];
						return
				end
				event.xy = me.screen.toDegrees([event.MappedX event.MappedY],'xy');
				me.event = event;
				me.x = event.xy(1); me.y = event.xy(2);
			end
		end

		% ===================================================================
		function reset(me)
		%> @fn reset
		%>
		%> @param
		%> @return
		% ===================================================================
			me.lastPressed 	= false;
			me.hold			= me.holdTemplate;
			me.x			= [];
			me.y			= [];
			me.win			= [];
			me.wasHeld		= false;
			me.isReleased	= false;
			me.wasNegation	= false;
			me.isSearching	= false;
			me.eventNew		= false;
			me.eventMove	= false;
			me.eventPressed	= false;
			me.eventRelease	= false;
			me.eventID 		= [];
			me.eventType	= [];
			me.event		= [];
		end

		% ===================================================================
		function [result, win, wasEvent] = checkTouchWindows(me, windows, panelType)
		%> @fn [result, win, wasEvent] = checkTouchWindows(me, windows, panelType)
		%>
		%> @param windows: [optional] touch rects to test (default use window parameters)
		%> @param panelType: [optional] 1 = front panel, 2 = back panel (need to reverse X)
		%> @return result: -100 = negation, true / false otherwise
		% ===================================================================
			if ~exist('windows','var'); windows = []; end
			if ~exist('panelType','var') || isempty(panelType); panelType = me.panelType; end

			nWindows = max([1 size(windows,1)]);
			result = false; win = 1; wasEvent = false; xy = [];

			event = getEvent(me);

			while iscell(event) && ~isempty(event); event = event{1}; end
			if isempty(event); return; end

			wasEvent = true;

			if panelType == 2; event.MappedX = me.screenVals.width - event.MappedX; end

			if ~isempty(event.xy)
				if isempty(windows)
					result = calculateWindow(me, event.xy(1), event.xy(2));
				else
					for i = 1 : nWindows
						result(i,1) = calculateWindow(me, event.xy(1), event.xy(2), windows(i,:));
						if result(i,1); win = i; result = true; break;end
					end
				end
				me.event.result = result;
			end
			if me.verbose
				fprintf('--->>> checkTouchWindows #:%i type:%i new:%i move:%i press:%i release:%i {%.1fX %.1fY} result:%i\n',...
				me.eventID,event.Type,me.eventNew,me.eventMove,me.eventPressed,me.eventRelease,me.x,me.y,result);
			end
		end

		% ===================================================================
		%> @fn isHold
		%>
		%> This is the main function which runs touch timers and calculates
		%> the logic of whether the touch is in a region and for how long.
		%>
		%> @param
		%> @return
		% ===================================================================
		function [held, heldtime, release, releasing, searching, failed, touch] = isHold(me)
			held = false; heldtime = false; release = false;
			releasing = false; searching = true; failed = false; touch = false;

			me.hold.now = GetSecs;
			if me.hold.start == 0
				me.hold.start = me.hold.now;
				me.hold.N = 0;
				me.hold.inWindow = false;
				me.hold.touched = false;
				me.hold.total = 0;
				me.hold.search = 0;
				me.hold.init = 0;
				me.hold.length = 0;
				me.hold.releaseinit = 0;
				me.hold.release = 0;
				me.wasHeld = false;
			else
				me.hold.total = me.hold.now - me.hold.start;
				if ~me.hold.touched
					me.hold.search = me.hold.total;
				end
			end

			[held, ~, wasEvent] = checkTouchWindows(me);
			if ~wasEvent % no touch
				if me.hold.inWindow % but previous event was touch inside window
					me.hold.length = me.hold.now - me.hold.init;
					if me.hold.length >= me.window.hold
						me.wasHeld = true;
						heldtime = true;
						releasing = true;
					end
					me.hold.release = me.hold.now - me.hold.releaseinit;
					if me.hold.release > me.window.release
						releasing = false;
						failed = true;
					end
				elseif ~me.hold.inWindow && me.hold.search > me.window.init
					failed = true;
					searching = false;
				end
				return;
			else
				touch = true;
			end

			if held == -100
				me.wasNegation = true;
				searching = false;
				failed = true;
				if me.verbose; fprintf('--->>> touchManager -100 NEGATION!\n'); end
				return
			end

			st = '';

			if me.eventPressed && held %A
				st = 'A';
				me.hold.touched = true;
				me.hold.inWindow = true;
				searching = false;
				if me.eventNew == true || me.hold.N == 0
					me.hold.init = me.hold.now;
					me.hold.N = me.hold.N + 1;
					me.hold.releaseinit = me.hold.init + me.window.hold;
					me.hold.length = 0;
				else
					me.hold.length = me.hold.now - me.hold.init;
				end
				if me.hold.search <= me.window.init && me.hold.length >= me.window.hold
					me.wasHeld = true;
					heldtime = true;
					releasing = true;
				end
				if me.wasHeld
					me.hold.release = me.hold.now - me.hold.releaseinit;
					if me.hold.release <= me.window.release
						releasing = true;
					else
						releasing = false;
						failed = true;
					end
				end
			elseif me.eventPressed && ~held %B
				st = 'B';
				me.hold.inWindow = false;
				me.hold.touched = true;
				if me.hold.N > 0
					failed = true;
					searching = false;
				else
					searching = true;
				end
			elseif me.eventRelease && held %C
				st = 'C';
				searching = false;
				me.hold.length = me.hold.now - me.hold.init;
				if me.hold.inWindow
					if me.hold.length >= me.window.hold
						me.wasHeld = true;
						heldtime = true;
						releasing = true;
					else
						me.wasHeld = false;
						failed = true;
					end
					me.hold.release = me.hold.now - me.hold.releaseinit;
					if me.hold.release > me.window.release
						releasing = false;
						failed = true;
					else
						release = true;
						releasing = false;
					end
				else
					st = ['!!' st];
				end
				me.hold.inWindow = false;
			elseif me.eventRelease && ~held %D
				st = 'D';
				me.hold.inWindow = false;
				failed = true;
				searching = false;
			end
			me.isSearching = searching;
			me.isReleased = release;
			if me.verbose
				fprintf('%s--->%i n:%i mv:%i p:%i r:%i {%.1fX %.1fY} tt:%.2f st:%.2f ht:%.2f rt:%.2f %i %i h:%i t:%i r:%i rl:%i s:%i f:%i N:%i\n',...
				st,me.eventID,me.eventNew,me.eventMove,me.eventPressed,me.eventRelease,me.x,me.y,...
				me.hold.total,me.hold.search,me.hold.length,me.hold.release,...
				me.hold.inWindow,me.hold.touched,...
				held,heldtime,release,releasing,searching,failed,me.hold.N);
			end
		end


		% ===================================================================
		function [out, held, heldtime, release, releasing, searching, failed, touch] = testHold(me, yesString, noString)
		%> @fn testHold
		%>
		%> @param
		%> @return
		% ===================================================================
			[held, heldtime, release, releasing, searching, failed, touch] = isHold(me);
			out = '';
			if me.wasNegation || failed || (~held && ~searching)
				out = noString;
			elseif heldtime
				out = yesString;
			end
		end

		% ===================================================================
		function [out, held, heldtime, release, releasing, searching, failed, touch] = testHoldRelease(me, yesString, noString)
		%> @fn testHoldRelease
		%>
		%> @param
		%> @return
		% ===================================================================
			[held, heldtime, release, releasing, searching, failed, touch] = isHold(me);
			out = '';
			if me.wasNegation || failed || (~held && ~searching)
				out = noString;
			elseif me.wasHeld && release
				out = yesString;
			end
		end

		% ===================================================================
		function demo(me,useaudio)
		%> @fn demo
		%>
		%> @param
		%> @return
		% ===================================================================
			if ~exist('useaudio','var'); useaudio=false; end
			if isempty(me.screen); me.screen = screenManager(); end
			sM = me.screen;
			windowed=[]; sf=[];
			if max(Screen('Screens'))==0; windowed = [0 0 1600 800]; end
			if ~isempty(windowed); sf = kPsychGUIWindow; end
			sM.windowed = windowed; sM.specialFlags = sf;
			oldWin = me.window;
			oldVerbose = me.verbose;
			me.verbose = true;

			if useaudio;a=audioManager();open(a);beep(a,3000,0.1,0.1);WaitSecs(0.2);beep(a,250,0.3,0.8);end

			if ~sM.isOpen; open(sM); end
			WaitSecs(2);
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
					me.window.radius = im.size/2;
					update(im);
					if useaudio;beep(a,1000,0.1,0.1);end
					fprintf('\n\nTRIAL %i -- X = %i Y = %i R = %.2f\n',i,me.window.X,me.window.Y,me.window.radius);
					rect = toDegrees(sM, im.mvRect, 'rect');
					reset(me);
					flush(me); 	%===================!!! flush the queue
					txt = '';
					vbl = flip(sM); ts = vbl;
					result = 'timeout';
					while vbl <= ts + 20
						[r, hld, hldt, rel, reli, se, fl, tch] = testHoldRelease(me,'yes','no');
						if hld
							txt = sprintf('%s IN x = %.1f y = %.1f - h:%i ht:%i r:%i rl:%i s:%i f:%i touch:%i N:%i',...
							r,me.x,me.y,hld,hldt,rel,reli,se,fl,tch,me.hold.N);
						elseif ~isempty(me.x)
							txt = sprintf('%s OUT x = %.1f y = %.1f - h:%i ht:%i r:%i rl:%i s:%i f:%i touch:%i N:%i',...
							r,me.x,me.y,hld,hldt,rel,reli,se,fl,tch,me.hold.N);
						else
							txt = sprintf('%s NO touch - h:%i ht:%i r:%i rl:%i s:%i f:%i touch:%i N:%i',...
							r,hld,hldt,rel,reli,se,fl,tch,me.hold.N);
						end
						drawBackground(sM);
						drawText(sM,txt); drawGrid(sM);
						if ~me.wasHeld; draw(im); end
						vbl = flip(sM);
						if strcmp(r,'yes')
							if useaudio;beep(a,3000,0.1,0.1);end
							result = 'CORRECT!!!'; break;
						elseif strcmp(r,'no')
							if useaudio;beep(a,250,0.3,0.8);end
							result = 'INCORRECT!!!'; break;
						end
						[keyDown,~,keys] = optickaCore.getKeys([]);
						if keyDown && any(keys(quitKey)); doQuit = true; break; end
					end
					drawTextNow(sM, result);
					tend = vbl - ts;
					fprintf('RESULT: %s in %.2f \n',result,tend);
					disp(me.hold);
					WaitSecs(2);
				end
				stop(me); close(me); %===================!!! stop and close
				me.window = oldWin;
				me.verbose = oldVerbose;
				if useaudio; try reset(a); end; end
				try reset(im); end
				try close(sM); end
			catch ME
				getReport(ME);
				try reset(im); end
				try close(sM); end
				try close(me); end
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
			negradius = radius + me.window.negationBuffer;
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

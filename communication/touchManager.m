% ========================================================================
classdef touchManager < optickaCore
%> @class touchManager @brief Manages touch screens (wraps the PTB
%> TouchQueue* functions), and provides touch area management methods.
%>
%> TOUCHMANAGER -- call this and setup with screen manager, then run your
%> task. This class can handles touch windows (circular or rectangular),
%> exclusion zones and more for multiple touch screens. NOTE: touch
%> interfaces do not keep state, so if you touch but do not move your finger
%> then there are no events, so touchManager ensures that the state is
%> handled for you. The touch queue is also asynchronous to the main PTB
%> task and so must be handled specifically. The default here is to drop all
%> but the latest event (drainEvent = true), when false all events are
%> processed which may take more time. Touchscreens can also cause unwanted
%> events, especially before/after the task runs (a subject can press
%> buttons, enter text etc.), so on Linux we also enable / disable the touch
%> screen when deviceName is passed to try to mitigate this problem.
%>
%> Copyright ©2014-2025 Ian Max Andolina — released: LGPL3, see LICENCE.md
% ========================================================================

	%--------------------PUBLIC PROPERTIES----------%
	properties
		%> which touch device to connect to?
		device double			= 1
		%> touch device name, useful to enable it at the OS level before
		%> PTB searches for the touch device
		deviceName string		= ""
		%> use the mouse instead of the touch screen for debugging
		isDummy	logical			= false
		%> window is a touch window, X and Y are the screen postion
		%> radius: circular when radius is 1 value, rectangular when radius = [width height])
		%> init: timer that tests time to first touch
		%> hold: timer that determines how long to hold
		%> release: timer to determine the time after hold in which window should be released
		%> doNegation: allows to return -100 (like exclusion) if touch is OUTSIDE window.
		%> when using the testHold etc functions. 
		%> negationBuffer: is an area around the window to allow some margin of error...
		window struct
		%> Use exclusion zones where no touch allowed:
		%> [left,top,right,bottom] Add rows to generate multiple exclusion
		%> zones. These are checked before the touch windows are.
		exclusionZone		= []
		%> drain the events to only get the latest? This ensures lots of
		%> events don't pile up, often you only want the current event, but
		%> potentially causes a longer delay each time getEvent is called.
		%> In theory you may miss specific events like NEW touch so ensure
		%> this works with your paradigm.
		drainEvents logical	= true
		%> there can be up to 10 touch events, do we check if the touch ID matches?
		trackID	logical		= true
		%> which id to track as the main one (1 = first event). 
		%> Note this is different from the event keycode, which increments
		%> with each event, this is the order of the touch event
		mainID double		= 1
		%> panel type, 1 = "front", 2 = "back" (reverses X position)
		panelType double	= 1
		%> verbose, log more info to command window
		%> useful for debugging.
		verbose				= false
	end

	properties (SetAccess=private, GetAccess=public)
		% general touch info, latest x and y position
		x					= []
		y					= []
		%> Accumulated X position in degrees since last flush
		xAll				= []
		%> Accumulated Y position in degrees since last flush
		yAll				= []
		%> times the xAll and yAll coordinates were recorded, see queueTime
		%> which is the time of the last flush or a sync event to get relative times
		tAll				= []
		%> time of last flush or syncTime method call, useful for getting relative times
		queueTime			= 0
		% touch event info from getEvent()
		event				= []
		eventID				= []
		eventType			= []
		eventNew			= false
		eventMove			= false
		eventPressed		= false
		eventRelease		= false
		% window info from checkTouchWindows()
		windowTouched		= []
		wasInWindow			= false
		% hold info from isHold()
		hold				= []
		wasHeld				= false
		wasNegation			= false
		isSearching			= false
		isReleased			= false
		isOpen				= false
		isQueue				= false
		% others
		devices				= []
		names				= []
		allInfo				= []
	end

	properties (Hidden = true)
		%> number of slots for touch events
		nSlots double		= 1e5
		%> functions return immediately, useful for mocking
		silentMode logical	= false
	end

	properties (Access = private)
		deferLog			= false
		lastPressed			= false
		currentID			= []
		pressed				= false
		ppd					= 36
		screen				= []
		swin				= []
		screenVals			= []
		windowTemplate		= struct('X', 0, 'Y', 0, 'radius', 2, ...
							'init', 3, 'hold', 0.05, 'release', 1, ...
							'doNegation', false, 'negationBuffer', 2, 'strict', true);
		holdTemplate		= struct('N',0,'inWindow',false,'touched',false,...
							'start',0,'now',0,'total',0,'search',0,'init',0,'releaseinit',0,...
							'length',0,'release',0)
		allowedProperties	= {'isDummy','device','deviceName','verbose','window','nSlots',...
							'panelType','drainEvents','exclusionZone'}
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

			% PTB: find touch interfaces
			try [me.devices,me.names,me.allInfo] = GetTouchDeviceIndices([], 1); end %#ok<*TRYNC>
			
			me.window = me.windowTemplate;
			me.hold = me.holdTemplate;
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
				error('≣≣≣≣⊱touchManager:Need to pass an open screenManager object!');
			end
			try touchManager.enableTouchDevice(me.deviceName, "enable"); end
			try [me.devices,me.names,me.allInfo] = GetTouchDeviceIndices([], 1); end
			if me.isDummy
				me.comment = 'Dummy Mode Active';
				fprintf('≣≣≣≣⊱touchManager: %s\n',me.comment);
			elseif isempty(me.devices)
				me.comment = 'No Touch Screen are available, please check USB!';
				warning('≣≣≣≣⊱touchManager: %s\n',me.comment);
			elseif isscalar(me.devices)
				me.comment = sprintf('found ONE Touch Screen: %s',me.names{1});
				fprintf('≣≣≣≣⊱touchManager: %s\n',me.comment);
			elseif length(me.devices)==2
				me.comment = sprintf('found TWO Touch Screens plugged %s %s',me.names{1},me.names{2});
				fprintf('≣≣≣≣⊱touchManager: %s\n',me.comment);
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
			if isempty(me.devices) || isempty(me.device) || me.device <= 0
				error('≣≣≣≣⊱touchManager: no available devices!!!')
			end
			try
				TouchQueueCreate(me.swin, me.devices(me.device), me.nSlots);
			catch
				warning('≣≣≣≣⊱touchManager: Cannot create touch queue!');
			end
			syncTime(me);
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
			if isempty(me.devices(me.device)); error("≣≣≣≣⊱touchManager: no device available!!!"); end
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
			if me.isDummy; me.isOpen = false; me.isQueue = false; return; end
			TouchQueueStop(me.devices(me.device));
			me.isOpen = false; me.isQueue = false;
			if me.verbose; logOutput(me,'stop','Stopped queue...'); end
		end

		% ===================================================================
		function close(me, choice)
		%> @fn close(me, choice)
		%>
		%> @param choice which touch device to use, default uses me.device
		%> @return
		% ===================================================================
			flush(me);
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
		function n = flush(me)
		%> @fn flush(me)
		%>
		%> @param
		%> @return n number of flushed events
		% ===================================================================
			reset(me);
			n = 0;
			syncTime(me);
			if me.isDummy; return; end
			n = TouchEventFlush(me.devices(me.device));
			if me.verbose; fprintf('≣Flush⊱ Touch queue flushed %i events...\n',n); end
		end

		% ===================================================================
		function syncTime(me, timestamp)
		%> @fn syncTime(me) Set the time of the touch queue to the current
		%> time. We can use this function to set the 0 time, for example
		%> stimulus onset etc. which can be used for evt.Time and tAll data.
		%>
		%> @param timestamp: [optional] time to set the queue time to, default is GetSecs
		% ===================================================================
			if ~exist('timestamp','var');timestamp = GetSecs; end
			me.queueTime = timestamp;
		end

		% ===================================================================
		function navail = eventAvail(me)
		%> @fn eventAvail(me)
		%>
		%> @param
		%> @return navail number of available events
		% ===================================================================
			navail = 0;
			if me.isDummy
				[~, ~, b] = GetMouse;
				if any(b) || me.lastPressed; navail = 1; end
			else
				navail = TouchEventAvail(me.devices(me.device));
			end
		end

		% ===================================================================
		function resetWindow(me,N)
		% function resetWindow(me,N)
		%> @fn resetWindow reset the touch window parameters
		%>
		%> @param
		%> @return
		% ===================================================================
			arguments(Input)
				me
				N = 1
			end

			for ii = 1 : N
				me.window(ii) = me.windowTemplate;
			end
		end

		% ===================================================================
		function updateWindow(me,X,Y,radius,doNegation,negationBuffer,strict,init,hold,release)
		% function updateWindow(me,X,Y,radius,doNegation,negationBuffer,strict,init,hold,release)
		%> @fn updateWindow update the touch window parameters
		%>
		%> @param
		%> @return
		% ===================================================================
			arguments(Input)
				me
				X = []
				Y = []
				radius = []
				doNegation = []
				negationBuffer = []
				strict = []
				init = []
				hold = []
				release = []
			end

			% set defaults for new windows
			maxL = max([length(X) length(Y) length(radius) length(doNegation) length(negationBuffer) length(strict) length(init) length(hold) length(release)]);
			if maxL > length(me.window)
				for ii = length(me.window)+1:maxL
					me.window(ii) = me.windowTemplate;
				end
			end
			
			if ~isempty(X)
				for ii = 1:length(X); if ~isnan(X(ii)); me.window(ii).X = X(ii); end; end
			end
			if ~isempty(Y)
				for ii = 1:length(Y); if ~isnan(Y(ii)); me.window(ii).Y = Y(ii); end; end
			end
			if ~isempty(radius) 
				for ii = 1:length(radius); if ~isnan(radius(ii)); me.window(ii).radius = radius(ii); end; end
			end
			if ~isempty(doNegation)
				for ii = 1:length(doNegation); if ~isnan(doNegation(ii)); me.window(ii).doNegation = doNegation(ii); end; end
			end
			if ~isempty(negationBuffer)
				for ii = 1:length(negationBuffer); if ~isnan(negationBuffer(ii)); me.window(ii).negationBuffer = negationBuffer(ii); end; end
			end
			if ~isempty(strict)
				for ii = 1:length(strict); if ~isnan(strict(ii)); me.window(ii).strict = strict(ii); end; end
			end
			if ~isempty(init)
				for ii = 1:length(init); if ~isnan(init(ii)); me.window(ii).init = init(ii); end; end
			end
			if ~isempty(hold)
				for ii = 1:length(hold); if ~isnan(hold(ii)); me.window(ii).hold = hold(ii); end; end
			end
			if ~isempty(release)
				for ii = 1:length(release); if ~isnan(release(ii)); me.window(ii).release = release(ii); end; end
			end
			if me.verbose
				for ii=1:length(me.window)
					fprintf('≣updateWindow %i⊱ X:%.1f Y:%.1f R:%.1f Neg:%i Buf:%.1f Strict:%i Init:%.1f Hold:%.1f Rel: %.1f\n',...
					ii, me.window(ii).X, me.window(ii).Y,...
					me.window(ii).radius,me.window(ii).doNegation,...
					me.window(ii).negationBuffer,me.window(ii).strict,...
					me.window(ii).init,me.window(ii).hold,me.window(ii).release);
				end
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
			me.xAll			= [];
			me.yAll			= [];
			me.tAll			= [];
			me.windowTouched			= [];
			me.wasInWindow	= false;
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
			me.currentID	= [];
			me.queueTime	= GetSecs;
		end

		% ===================================================================
		function evt = getEvent(me)
		%> @fn getEvent
		%>
		%> @param
		%> @return event structure
		% ===================================================================
			evt = [];
			if me.isDummy % use mouse to simulate touch
				[mx, my, b] = GetMouse(me.swin);
				if any(b) && ~me.lastPressed
					type = 2; motion = false; press = true;  
				elseif any(b) && me.lastPressed
					type = 3; motion = true; press = true;  
				elseif ~any(b) && me.lastPressed
					type = 4; motion = false; press = false; 
				else
					type = -1; motion = false; press = 0;  
				end
				if type > 0
					evt = struct('Type',type,'Time',GetSecs,...
					'X',mx,'Y',my,'ButtonStates',b,...
					'NormX',mx/me.screenVals.width,'NormY',my/me.screenVals.height, ...
					'MappedX',mx,'MappedY',my,...
					'Pressed',press,'Motion',motion,...
					'Keycode',55);
				end
			else
				evt = getEvents(me);
			end
			if ~isempty(evt)
				me.eventNew = false; me.eventMove = false; me.eventRelease = false; me.eventPressed = false;
				for ii = 1:length(evt)
					if me.trackID && ~isempty(me.currentID) && me.currentID ~= evt(ii).Keycode
						continue;
					end
					switch evt(ii).Type
						case 2 %NEW
							me.eventNew = true;
							me.eventPressed = true;
							me.lastPressed = true;
							me.eventMove = false;
						case 3 %MOVE
							me.eventNew = false;
							me.eventMove = true;
							me.eventPressed = true;
						case 4 %RELEASE
							if me.lastPressed || me.isDummy
								me.eventNew = false;
								me.eventMove = false;
								me.eventRelease = true;
								me.lastPressed = false;
							end
							me.currentID = [];
						case 5 %ERROR
							warning('≣≣≣≣⊱touchManager: Event lost!');
							me.event = []; evt = [];
							me.lastPressed = false;
							me.currentID = [];
							return
					end
					if evt(ii).Type == 2 || evt(ii).Type == 3
						evt(ii).xy = me.screen.toDegrees([evt(ii).MappedX evt(ii).MappedY],'xy');
						if ~isempty(evt(ii).xy) && length(evt(ii).xy)==2
							me.xAll = [me.xAll evt(ii).xy(1)];
							me.yAll = [me.yAll evt(ii).xy(2)];
							me.tAll = [me.tAll evt(ii).Time];
						end
					end
				end
				evt = evt(end);
				me.eventID		= evt.Keycode;
				me.eventType	= evt.Type;
				if me.panelType == 2; evt.changeX = true; evt.MappedX = me.screenVals.width - evt.MappedX; end
				evt.xy = me.screen.toDegrees([evt.MappedX evt.MappedY],'xy');
				me.event = evt;
				me.x = evt.xy(1); me.y = evt.xy(2);
			end
		end

		% ===================================================================
		%> @fn isTouch
		%>
		%> Simply checks for touch event irrespective of position
		%>
		%> @param
		%> @return
		% ===================================================================
		function touch = isTouch(me, getEvt)
			arguments
				me
				getEvt {mustBeNumericOrLogical} = true;
			end

			touch = false;

			if getEvt
				evt = getEvent(me);
				me.event = evt;
			elseif isempty(me.event)
				return;
			end

			touch = logical(me.lastPressed);
		end

		% ===================================================================
		function [result, win, wasEvent, wasTouch] = checkTouchWindows(me, windows, getEvt)
		%> @fn [result, win, wasEvent, wasTouch] = checkTouchWindows(me, windows)
		%>
		%> Simply get latest touch event and check if it is in the a defined window
		%>
		%> @param windows: [optional] touch rects to test (default use touchManager.window parameters)
		%> @param getEvent: [optional,default=true] do we get event or use the existing one?
		%> @return result: -100 = negation, true / false otherwise
		%> @return win: index of the window that the touch event is in
		%> @return wasEvent: indicates if an event was processed
		%> @return wasTouch: indicates if a touch event was detected
		% ===================================================================
			arguments(Input)
				me
				windows = []; % Ensure windows is numeric
				getEvt {mustBeNumericOrLogical} = true; % Ensure getEvt is numeric or logical
			end
			arguments(Output)
				result {mustBeNumericOrLogical}
				win {mustBeNumeric}
				wasEvent {mustBeNumericOrLogical} 
				wasTouch {mustBeNumericOrLogical} 
			end

			result = false; win = NaN; wasEvent = false; wasTouch = false;
			if ~isempty(windows)
				nWindows = max([1 size(windows,1)]);
			else
				nWindows = length(me.window);
			end

			if getEvt
				evt = getEvent(me);
			else
				evt = me.event;
			end

			while iscell(evt) && ~isempty(evt); evt = evt{1}; end
			
			if isempty(evt); return; end

			wasEvent = true;
			wasTouch = me.eventPressed;

			if ~isempty(evt.xy)
				if ~isempty(windows) && ~isempty(me.window)
					for ii = 1 : nWindows
						result = calculateWindow(me, evt.xy(1), evt.xy(2), windows(ii,:));
						if result; win = ii; break; end
					end
				else
					for ii = 1 : nWindows
						result = calculateWindow(me, evt.xy(1), evt.xy(2), me.window(ii));
						if result; win = ii; break; end
					end
				end
				me.windowTouched = win;
				me.event.result = result;
				if any(result); me.wasInWindow = true; end
			end
			if me.verbose
				fprintf('≣checkWin-%s⊱%i wasHeld:%i type:%i result:%i new:%i mv:%i prs:%i lastprs: %i rel:%i \n\t%.1fX %.1fY [win:%i %sX %sY]\n',...
				me.name, me.eventID, me.wasHeld, evt.Type, result, ...
				me.eventNew, me.eventMove, me.eventPressed, me.lastPressed, ...
				me.eventRelease,me.x, me.y, win, ...
				sprintf("<%.1f>",me.window.X), ...
				sprintf("<%.1f>",me.window.Y));
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
			me.deferLog = true;
			[held, ~, wasEvent] = checkTouchWindows(me);
			if ~isempty(me.windowTouched) && me.windowTouched > 0
				win = me.windowTouched;
			else
				win = 1;
			end
			me.deferLog = false;
			if ~wasEvent % no touch
				if me.hold.inWindow % but previous event was touch inside window
					me.hold.length = me.hold.now - me.hold.init;
					if me.hold.length >= me.window(win).hold
						me.wasHeld = true;
						heldtime = true;
						releasing = true;
					end
					me.hold.release = me.hold.now - me.hold.releaseinit;
					if me.hold.release > me.window(win).release
						releasing = false;
						failed = true;
					end
				elseif ~me.hold.inWindow && me.hold.search > me.window(win).init
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
				if me.verbose; fprintf('≣isHold⊱ touchManager -100 NEGATION!\n'); end
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
					me.hold.releaseinit = me.hold.init + me.window(win).hold;
					me.hold.length = 0;
				else
					me.hold.length = me.hold.now - me.hold.init;
				end
				if me.hold.search <= me.window(win).init && me.hold.length >= me.window(win).hold
					me.wasHeld = true;
					heldtime = true;
					releasing = true;
				end
				if me.wasHeld
					me.hold.release = me.hold.now - me.hold.releaseinit;
					if me.hold.release <= me.window(win).release
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
					if me.hold.length >= me.window(win).hold
						me.wasHeld = true;
						heldtime = true;
						releasing = true;
					else
						me.wasHeld = false;
						failed = true;
					end
					me.hold.release = me.hold.now - me.hold.releaseinit;
					if me.hold.release > me.window(win).release
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
				fprintf('≣isHold⊱%s⊱%s:evt%i new:%i mv:%i prs:%i rel:%i {%.1fX %.1fY - winx%s winy%s} tt:%.2f st:%.2f ht:%.2f rt:%.2f inWin:%i tchd:%i h:%i ht:%i r:%i rl:%i s:%i fail:%i N:%i\n',...
				me.name,st,me.eventID,me.eventNew,me.eventMove,me.eventPressed,me.eventRelease,...
				me.x,me.y,sprintf("<%.1f>",me.window(:).X),sprintf("<%.1f>",me.window(:).Y),...
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
			if me.verbose && ~isempty(out)
				fprintf('≣testHold⊱ %s held:%i heldtime:%i rel:%i reling:%i ser:%i fail:%i touch:%i x:%.1f [%.1f] y:%.1f [%.1f]\n',...
					out, held, heldtime, release, releasing, searching, failed, touch,...
					me.x, me.y, me.window(1).X, me.window(1).Y)
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
			if me.verbose && ~isempty(out)
				fprintf('≣testHoldRelease⊱ %s held:%i time:%.3f rel:%i rel:%i ser:%i fail:%i touch:%i\n',...
					out, held, heldtime, release, releasing, searching, ...
					failed, touch);
			end
		end

		% ===================================================================
		function demo(me, nTrials, useaudio)
		%> @fn demo
		%>
		%> @param
		%> @return
		% ===================================================================
			arguments(Input)
				me
				nTrials double = 10
				useaudio logical = false
			end
			if isempty(me.screen); me.screen = screenManager(); end
			sM = me.screen;
			if max(Screen('Screens'))==0 && me.verbose
				PsychDebugWindowConfiguration; 
			end
			oldWin = me.window;
			oldVerbose = me.verbose;
			me.verbose = true;

			if useaudio;a=audioManager();open(a);beep(a,3000,0.1,0.1);WaitSecs(0.2);beep(a,250,0.3,0.8);end

			try
				if ~sM.isOpen; open(sM); end
				setup(me, sM); 		%===================!!! Run setup first
				im = discStimulus('size', 6);

				setup(im, sM);
	
				quitKey = KbName('escape');
				doQuit = false;
				createQueue(me);	%===================!!! Create Queue
				start(me); 			%===================!!! Start touch collection

				for i = 1 : nTrials
					if doQuit; break; end
					tx = randi(20)-10;
					ty = randi(20)-10;
					im.xPositionOut = tx;
					im.yPositionOut = ty;
					%X,Y,radius,doNegation,negationBuffer,strict,init,hold,release
					me.updateWindow([tx 0],[ty 0],[im.size/2 2]);
					update(im);
					if useaudio;beep(a,1000,0.1,0.1);end
					fprintf('\n\nTouchManager Demo TRIAL %i -- X = %s Y = %s R = %s\n',i,sprintf("<%.1f>",me.window.X),sprintf("<%.1f>",me.window.Y),sprintf("<%.1f>",me.window.radius));
					t = sprintf('Negation buffer: %s | Init: %s s | Hold > time: %s s | Release < time %s s',...
						sprintf("<%.1f>",me.window.negationBuffer), sprintf("<%.1f>",me.window.init), ...
						sprintf("<%.1f>",me.window.hold), sprintf("<%.1f>",me.window.release));
					reset(me);
					flush(me); 	%===================!!! flush the queue
					vbl = flip(sM); ts = vbl;
					result = 'timeout';
					while vbl <= ts + 20
						[r, hld, hldt, rel, reli, se, fl, tch] = testHoldRelease(me,'yes','no');
						if hld
							txt = sprintf('%s IN x = %.1f y = %.1f - h:%i ht:%i r:%i rl:%i s:%i f:%i touch:%i N:%i\n%s',...
							r,me.x,me.y,hld,hldt,rel,reli,se,fl,tch,me.hold.N,t);
						elseif ~isempty(me.x)
							txt = sprintf('%s OUT x = %.1f y = %.1f - h:%i ht:%i r:%i rl:%i s:%i f:%i touch:%i N:%i\n%s',...
							r,me.x,me.y,hld,hldt,rel,reli,se,fl,tch,me.hold.N,t);
						else
							txt = sprintf('%s NO touch - h:%i ht:%i r:%i rl:%i s:%i f:%i touch:%i N:%i\n%s',...
							r,hld,hldt,rel,reli,se,fl,tch,me.hold.N,t);
						end
						if ~me.wasHeld; draw(im); end
						drawText(sM,txt); drawGrid(sM); drawScreenCenter(sM);
						vbl = flip(sM);
						if strcmp(r,'yes')
							if useaudio;beep(a,3000,0.1,0.1);end
							result = sprintf('CORRECT @ window %i!!!',me.windowTouched); break;
						elseif strcmp(r,'no')
							if useaudio;beep(a,250,0.3,0.8);end
							result = 'INCORRECT!!!'; break;
						end
						[keyDown,~,keys] = optickaCore.getKeys([]);
						if keyDown && any(keys(quitKey)); doQuit = true; break; end
					end
					drawTextNow(sM, result);
					tend = vbl - ts;
					fprintf('≣≣≣≣⊱ TouchManager Demo RESULT: %s in %.2f \n',result,tend);
					disp(me.hold);
					WaitSecs(2);
				end
				stop(me); close(me); %===================!!! stop and close
				me.window = oldWin;
				me.verbose = oldVerbose;
				if useaudio; try reset(a); end; end
				try reset(im); end
				try close(sM); end
				clear Screen
			catch ME
				getReport(ME);
				try reset(im); end
				try close(sM); end
				try close(me); end
				if useaudio; try reset(a); end; end
				try me.window = oldWin; end
				try me.verbose = oldVerbose; end
				clear Screen
				rethrow(ME);
			end
		end

		% ===================================================================
		function testEvents(me)
		%> @fn test, test the touch event values
		%>
		%> @param
		%> @return
		% ===================================================================
			if isempty(me.screen); me.screen = screenManager(); end
			sM = me.screen;
			sM.screen = 0;
			sM.disableSyncTests = true;
			sM.font.TextSize = 22;
			if max(Screen('Screens'))==0 && me.verbose
				PsychDebugWindowConfiguration; 
			end
			
			oldWin = me.window;
			oldVerbose = me.verbose;
			me.verbose = true;

			if ~sM.isOpen; sv = open(sM); end
			setup(me, sM); 		%===================!!! Run setup first

			quitKey = KbName('escape');
			doQuit = false;
			createQueue(me);	%===================!!! Create Queue
			start(me); 			%===================!!! Start touch collection
			try
				while ~doQuit
					reset(me);
					flush(me); 	%===================!!! flush the queue
					me.updateWindow(0,0,3,true,2,true,5,1,1);
					vbl = flip(sM); ts = vbl;
					while vbl <= ts + 30
						[held, heldtime, release, releasing, searching, failed, touch] = isHold(me);
						txt = sprintf('X: %.1f Y: %.1f - h:%i ht:%i r:%i rl:%i s:%i f:%i touch:%i N:%i - evtX:%.1f evtYvbn  ',...
							me.x,me.y,held,heldtime,release,releasing,searching,failed,touch,me.hold.N);
						if ~isempty(me.event) && isstruct(me.event)
							txt = sprintf('%s\n ID: %i type:%i evtX:%.1f evtY:%.1f nrmX: %.2f nrmY: %.2f mapX: %.1f mapY: %.1f press:%i motion:%i',...
								txt, me.event.Keycode, me.event.Type, me.event.X, me.event.Y, me.event.NormX, me.event.NormY,...
								me.event.MappedX,me.event.MappedY,me.event.Pressed,me.event.Motion);
							txt = sprintf('%s\n new: %i pressed: %i lastpressed: %i move: %i release: %i',...
								txt, me.eventNew, me.eventPressed, me.lastPressed, me.eventMove, me.eventRelease);
						end
						drawGreenSpot(sM, 6); drawTextWrapped(sM,txt); drawScreenCenter(sM);
						drawGrid(sM);
						vbl = flip(sM);
						[keyDown,~,keys] = optickaCore.getKeys([]);
						if keyDown && any(keys(quitKey)); doQuit = true; break; end
					end
					disp(me.hold);
					WaitSecs(0.1);
				end
				stop(me); close(me); %===================!!! stop and close
				me.window = oldWin;
				me.verbose = oldVerbose;
				try reset(im); end
				try close(sM); end
				clear Screen
				if ~isempty(me.xAll)
					figure;
					plot(me.xAll, me.yAll);
					xlim([sv.leftInDegrees sv.rightInDegrees]);
					ylim([sv.topInDegrees sv.bottomInDegrees]);
					set(gca,'YDir','reverse');
					xlabel('X Position (deg)');
					xlabel('Y Position (deg)');
				end
			catch ME
				getReport(ME);
				try reset(im); end
				try close(sM); end
				try close(me); end
				clear Screen
				rethrow(ME);
			end
		end

	end

	%=======================================================================
	methods (Static = true) %------------------STATIC METHODS
	%=======================================================================
		
		function enableTouchDevice(deviceName, enable)
			%> On linux we can use xinput to list and enable/disable touch
			%> interfaces, here we try to make the named touch interface
			%> enabled or disabled.
			arguments(Input)
				deviceName string = ""
				enable string = "enable"
			end
			
			if ~IsLinux || matches(deviceName,""); return; end
			
			enable = lower(enable);
			
			if matches(enable,["on","yes","true","enable"])
				cmd = "enable";
			else
				cmd = "disable";
			end

			ret = 0; msg = ''; attempt = false;

			try
				[~,r] = system("xinput list");
				disp('===>>> XInput Initial Device List:');
				disp(r);
				if isempty(deviceName); return; end
				pattern = sprintf('(?<name>%s)\\s+id=(?<id>\\d+)', deviceName);
				r = strsplit(string(r), newline);
				for ii = 1:length(r)
					tokens = regexp(r(ii), pattern, 'names');
					if ~isempty(tokens)
						attempt = true;
						[ret,msg] = system("xinput " + cmd + " " + tokens.id);
						fprintf('===>>> XInput: Run <xinput %s %s> on %s\n', cmd, tokens.id, deviceName);
						WaitSecs('YieldSecs',1);
						[~,r] = system("xinput list");
						disp('===>>>XInput Final Device List:');
						disp(r);
						fprintf('\n\n');
						break
					end
				end
				if attempt == true && ret == 1
					warning('touchManager.enableTouchDevice failed: %s',msg);
				elseif attempt == false
					warning('touchManager.enableTouchDevice device not found: %s',deviceName);
				end
			end
		end

	end

	%=======================================================================
	methods (Access = protected) %------------------PROTECTED METHODS
	%=======================================================================

		% ===================================================================
		function [evt, n] = getEvents(me)
		%> @fn getEvents
		%>
		%> @param
		%> @return
		% ===================================================================	
			n = 0;
			while eventAvail(me) > 0
				n = n + 1;
				evt(n) = TouchEventGet(me.devices(me.device), me.swin, 0);
			end
			if n == 0; evt = []; return; end
			if me.drainEvents; evt = evt(end); end
		end

		% ===================================================================
		function result = calculateWindow(me, x, y, tempWindow)
		%> @fn calculateWindow
		%>
		%> @param
		%> @return
		% ===================================================================
			arguments(Input)
				me
				x = []
				y = []
				tempWindow = []
			end
			arguments(Output)
				result 
			end
			if isempty(x) || isempty(y); return; end
			if exist('tempWindow','var') && isnumeric(tempWindow) && length(tempWindow) == 4
				pos = screenManager.rectToPos(tempWindow);
				radius = pos.radius;
				xWin = pos.X;
				yWin = pos.Y;
			else
				radius = tempWindow.radius;
				xWin = tempWindow.X;
				yWin = tempWindow.Y;
			end
			result = false; match = false; matchneg = false;
			negradius = radius + tempWindow.negationBuffer;
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
			if isscalar(radius)
				r = sqrt((x - xWin).^2 + (y - yWin).^2); %fprintf('X: %.1f-%.1f Y: %.1f-%.1f R: %.1f-%.1f\n',x, xWin, me.y, yWin, r, radius);
				if any(find(r < radius))
					match = true; 
				end
				if any(find(r < negradius))
					matchneg = true;
				end
			else % ---- x y rectangular window test
				if (x >= (xWin - radius(1))) && (x <= (xWin + radius(1))) ...
						&& (y >= (yWin - radius(2))) && (y <= (yWin + radius(2)))
					match = true;
				end
				if (x >= (xWin - negradius(1))) && (x <= (xWin + negradius(1))) ...
						&& (y >= (yWin - negradius(2))) && (y <= (yWin + negradius(2)))
					matchneg = true;
				end
			end
			if (tempWindow.doNegation && matchneg) || (~tempWindow.doNegation && match)
				result = true;
			elseif tempWindow.doNegation && ~matchneg
				result = -100;
			end
		end
	end
end

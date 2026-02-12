% ========================================================================
classdef touchManager < optickaCore
%> @class touchManager @brief Manages touch screens (wraps the PTB
%> TouchQueue* functions), and provides touch area management methods.
%>
%> TOUCHMANAGER -- call this and setup with screen manager, then run your
%> task. This class can handles touch windows (circular or rectangular),
%> exclusion zones and more for multiple touch screens. 
% 
%> NOTE: touch interfaces do NOT keep state, so if you touch but do not move
%> your finger then there are no events, so touchManager ensures that the
%> state is handled for you. The touch queue is also asynchronous to the
%> main PTB task and so must be handled specifically. The default here is to
%> drop all but the latest event (drainEvent = true), when false all events
%> are processed which may take more time. Touchscreens can also cause
%> unwanted OS/UI events, especially before/after the task runs (a subject
%> can press buttons, enter text etc.), so on Linux we also enable / disable
%> the touch screen at the OS level when deviceName is passed to try to
%> mitigate this problem.
%>
%> This class uses the TouchQueue* functions from Psychtoolbox, 
%> see: https://psychtoolbox.org/docs/TouchQueue for more details.
%>
%> Copyright ©2014-2026 Ian Max Andolina — released: LGPL3, see LICENCE.md
% ========================================================================

	%--------------------PUBLIC PROPERTIES----------%
	properties
		%> which touch device to connect to?
		device double			= 1
		%
		%> touch device name, useful to enable it at the OS level before
		%> PTB searches for the touch device
		deviceName string		= ""
		%
		%> use the mouse instead of the touch screen for debugging
		isDummy	logical			= false
		%
		%> window is a touch window - see windowTemplate below for the exact struct
		%
		%> X: X position for the centre of the tocuh window in degrees on screen
		%> Y: Y position for the centre of the tocuh window in degrees on screen
		%> radius: circular when radius is singular, rectangular when radius = [width height])
		%> init: timer that tests time window allowed to first touch
		%> hold: timer that determines how long to hold
		%> release: timer to determine the time after hold in which window should be released
		%> 		If release is NaN, release timing checks are disabled and a
		%> 		successful hold is accepted without requiring a release.
		%> doNegation: return -100 (fail) if deliberate touch is OUTSIDE window when using the testHold etc functions. 
		%> negationBuffer: is an area around the window to allow some margin of error for negation...
		%> strict: enforce strict rules for hold within the window
		window struct
		%
		%> Use exclusion zones where no touch allowed:
		%> [left,top,right,bottom] Add rows to generate multiple exclusion
		%> zones. These are checked before the touch windows are.
		exclusionZone double= []
		%
		%> drain the events to only get the latest? This ensures lots of
		%> events don't pile up if you only want the current event, but
		%> potentially causes lost state from missed events. If enabled you
		%> may miss specific events like a NEW touch so ensure this works
		%> with your paradigm!!!
		drainEvents logical	= false
		%
		%> there can be up to 10 touch events, do we check if the touch ID matches?
		trackID	logical		= true
		%
		%> which id to track as the main one (1 = first event). 
		%> Note this is different from the event keycode, which increments
		%> with each event, this is the order of the touch event
		mainID double		= 1
		%
		%> panel type, 1 = "front", 2 = "back" (reverses X position)
		panelType double	= 1
		%
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
		%> IDs for each timepoint
		IDall				= []
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
		wasNegation			= false
		wasInWindow			= false
		% hold info from isHold()
		hold				= []
		wasHeld				= false
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
		lastPressed			= false
		currentID			= []
		pressed				= false
		ppd					= 36
		screen				= []
		swin				= []
		screenVals			= []
		windowTemplate		= struct('X', 0, 'Y', 0, 'radius', 2, ...
							'init', 3, 'hold', 0.05, 'release', NaN, ...
							'doNegation', false, 'negationBuffer', 2, 'strict', true);
		holdTemplate		= struct('N',0,'inWindow',false,'touched',false, ...
							'negation', false, 'searching', false, 'failed', false, ...
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
			if me.isDummy
				me.comment = 'Dummy Mode Active';
				fprintf('≣≣≣≣⊱touchManager: %s\n',me.comment);
				return
			else
				try touchManager.enableTouchDevice(me.deviceName, "enable"); end
				loop = 1;
				while isempty(me.devices) && loop <=5
					try [me.devices,me.names,me.allInfo] = GetTouchDeviceIndices([], 1); end
					WaitSecs(0.1); loop = loop + 1;
				end
			end
			if isempty(me.devices)
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
			if ~me.isQueue; createQueue(me); end
			if me.isDummy; me.isOpen = true; return; end
			if isempty(me.devices) || isempty(me.devices(me.device)); error("≣≣≣≣⊱touchManager: no device available!!!"); end
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
			if me.isOpen && me.isQueue; flush(me); end
			me.isOpen = false; me.isQueue = false;
			if me.isDummy || isempty(me.devices); return; end
			if ~exist('choice','var') || isempty(choice); choice = me.device; end
			for i = 1:length(choice)
				try TouchQueueRelease(me.devices(choice(i))); end
			end
			if me.verbose; logOutput(me,'close','Closed...'); end
		end

		% ===================================================================
		function n = flush(me)
		%> @fn flush(me) flush any events in the touch queue
		%>
		%> @param
		%> @return n number of flushed events
		% ===================================================================
			if ~me.isOpen && ~me.isQueue; return; end
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
			if ~exist('timestamp','var'); timestamp = GetSecs; end
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
				for ii = 1:length(release); me.window(ii).release = release(ii); end
			end
			if me.verbose
				for ii=1:length(me.window)
					fprintf('≣updateWindow %i⊱ X:%.1f Y:%.1f R:%.1f Neg:%i Buf:%.1f Strict:%i Init:%.1f Hold:%.1f Rel: %.1f\n',...
					ii, me.window(ii).X, me.window(ii).Y,...
					me.window(ii).radius, me.window(ii).doNegation,...
					me.window(ii).negationBuffer, me.window(ii).strict,...
					me.window(ii).init, me.window(ii).hold, me.window(ii).release);
				end
			end
		end

		% ===================================================================
		function reset(me, softReset)
		%> @fn reset
		%>
		%> @param softReset -- soft reset = keep lastPressed and event flags
		%> (reason: because touch screen has no state and subject holding a
		%> touch screen without moving is the same as no touch, a soft reset
		%> keeps the last event state but resets other properties) 
		%> 
		% ===================================================================
			arguments(Input)
				me
				softReset {mustBeNumericOrLogical} = false
			end
			if ~softReset
				me.lastPressed	= false;
				me.eventNew		= false;
				me.eventMove	= false;
				me.eventPressed	= false;
				me.eventRelease	= false;
			end
			me.hold			= me.holdTemplate;
			me.x			= NaN;
			me.y			= NaN;
			me.xAll			= [];
			me.yAll			= [];
			me.tAll			= [];
			me.IDall		= [];
			me.windowTouched= [];
			me.wasInWindow	= false;
			me.wasHeld		= false;
			me.isReleased	= false;
			me.wasNegation	= false;
			me.isSearching	= false;
			me.eventID 		= [];
			me.eventType	= [];
			me.event		= [];
			me.currentID	= [];
			me.queueTime	= GetSecs;
			if me.verbose
				fprintf('≣reset⊱ Touch data reset: softReset = %i | lastPressed = %i\n', softReset, me.lastPressed); 
			end
		end

		% ===================================================================
		function evt = getEvent(me)
		%> @fn getEvent
		%>
		%> @param
		%> @return event structure
		% ===================================================================
			evt = []; evtN = 0;
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
					evtN = 1;
					evt = struct('Type',type,'Time',GetSecs,...
					'X',mx,'Y',my,'ButtonStates',b,...
					'NormX',mx/me.screenVals.width,'NormY',my/me.screenVals.height, ...
					'MappedX',mx,'MappedY',my,...
					'Pressed',press,'Motion',motion,...
					'Keycode',55);
				end
			else
				[evt, evtN] = getAvailableEvents(me);
			end
			if ~isempty(evt)
				me.eventNew = false; me.eventMove = false; me.eventRelease = false; me.eventPressed = false;
				xy = [];
				processedEvt = [];
				processedCount = 0;
				for ii = 1:evtN
					if me.trackID
						if isempty(me.currentID)
							if evt(ii).Type ~= 2
								continue;
							end
						elseif me.currentID ~= evt(ii).Keycode
							continue;
						end
					end
					switch evt(ii).Type
						case 1
							fprintf('≣≣≣≣⊱touchManager: WARNING: Event Type 1!!!\n');
							continue;
						case 2 %NEW
							me.currentID = evt(ii).Keycode;
							me.eventNew = true;
							me.eventMove = false;
							me.eventRelease = false;
							me.eventPressed = true;
							me.lastPressed = true;
						case 3 %MOVE
							me.eventNew = false;
							me.eventMove = true;
							me.eventRelease = false;
							me.eventPressed = true;
							me.lastPressed = true;
						case 4 %RELEASE
							if me.lastPressed || me.isDummy
								me.eventNew = false;
								me.eventMove = false;
								me.eventRelease = true;
								me.eventPressed = false;
								me.lastPressed = false;
							end
							me.currentID = [];
						case 5 %ERROR
							warning('≣≣≣≣⊱touchManager: Event Type 5!!!\n');
							continue;
					end
					if evt(ii).Type > 1 && evt(ii).Type < 5 % NEW / MOVE / RELEASE
						me.IDall = [me.IDall evt(ii).Keycode];
						% transparent display back has a reversed X
						if me.panelType == 2
							evt(ii).changeX = true; 
							evt(ii).MappedX = me.screenVals.width - evt(ii).MappedX; 
						end
						evt(ii).xy = me.screen.toDegrees([evt(ii).MappedX evt(ii).MappedY],'xy');
						xy = evt(ii).xy;
						if ~isempty(xy) && length(xy)==2 && ~any(isnan(xy))
							me.xAll = [me.xAll xy(1)];
							me.yAll = [me.yAll xy(2)];
							me.tAll = [me.tAll evt(ii).Time];
							me.x = xy(1);
							me.y = xy(2);
						end
					end
					processedEvt = evt(ii);
					processedCount = processedCount + 1;
					if me.verbose
						fprintf('≣≣≣⊱Event ID: %i type:%i evtX:%.1f evtY:%.1f nrmX: %.2f nrmY: %.2f mapX: %.1f mapY: %.1f press:%i motion:%i last:%i\n', ...
							evt(ii).Keycode, evt(ii).Type, evt(ii).X, evt(ii).Y, evt(ii).NormX, evt(ii).NormY, ...
							evt(ii).MappedX, evt(ii).MappedY, evt(ii).Pressed, evt(ii).Motion, me.lastPressed);
					end
				end
				if isempty(processedEvt)
					return
				end
				evt = processedEvt;
				if evt.Type == 4; evt.xy = [me.x me.y]; end
				me.eventID		= evt.Keycode;
				me.eventType	= evt.Type;
				
				me.event = evt;
				if me.verbose
					fprintf('≣getEvent⊱ processed %i event(s) %s IDs %s final x: %.1f final y: %.1f\n', ...
						processedCount, sprintf('%i ', evt(:).Type), sprintf('%i ', evt(:).Keycode), me.x, me.y); 
				end
			end
		end

		% ===================================================================
		%> @fn isTouch
		%>
		%> Simply checks for touch event irrespective of position / time etc.
		%>
		%> @param getEvt -- do we force a getEvent() or use the last valid event?
		%> @return touch -- logical for if there is a touch event
		% ===================================================================
		function touch = isTouch(me, getEvt)
			arguments(Input)
				me
				getEvt {mustBeNumericOrLogical} = true
			end

			touch = false;

			if getEvt
				getEvent(me);
			elseif isempty(me.event)
				return;
			end

			touch = logical(me.lastPressed);
		end

		% ===================================================================
		function [result, win, wasEvent] = checkTouchWindows(me, windows, getEvt)
		%> @fn [result, win, wasEvent] = checkTouchWindows(me, windows)
		%>
		%> Simply get latest touch event and check if it is in the a defined window
		%>
		%> @param windows: [optional] touch rects to test (default use touchManager.window parameters)
		%> @param getEvent: [optional,default=true] do we get event or use the existing one?
		%> @return result: true / false OR -100 if negation triggered
		%> @return win: index of the window that the touch event is in
		%> @return wasEvent: indicates if an event was processed
		% ===================================================================
			arguments(Input)
				me
				windows = []; % Ensure windows is numeric
				getEvt logical = true; % Ensure getEvt is numeric or logical
			end
			arguments(Output)
				result {mustBeNumericOrLogical}
				win {mustBeNumeric}
				wasEvent logical
			end

			%% ============================= default return values
			result = false; win = NaN; wasEvent = false; 

			%% ============================= check if we are using a custom window and how many
			if ~isempty(windows)
				nWindows = max([1 size(windows,1)]);
			else
				nWindows = length(me.window);
			end

			%% ============================== get our latest touch event(s)
			if getEvt
				evt = getEvent(me);
			else
				evt = me.event;
			end
			while iscell(evt) && ~isempty(evt); evt = evt{1}; end
			if isempty(evt); return; end

			wasEvent = true;

			if isstruct(evt) && isfield(evt,'xy') && length(evt.xy)==2
				for ii = 1 : nWindows
					% for negation with multiple windows, only the last
					% window should be used
					isLast = ii == nWindows;
					if ~isempty(windows) && ~isempty(me.window)
						result = calculateWindow(me, evt.xy(1), evt.xy(2), windows(ii,:), isLast);
						if result; win = ii; break; end
					else
						result = calculateWindow(me, evt.xy(1), evt.xy(2), me.window(ii), isLast);
						if result; win = ii; break; end
					end
				end
				me.windowTouched = win;
				me.event.result = result;
				if any(result == -100)
					me.wasNegation = true;
					me.hold.negation = true;
				elseif any(result == true)
					me.wasInWindow = true;
				end
			end
			if me.verbose
				eventIdValue = me.eventID;
				if isstring(eventIdValue) || ischar(eventIdValue)
					eventIdValue = str2double(eventIdValue);
				end
				if isempty(eventIdValue) || isnan(eventIdValue)
					eventIdValue = -1;
				end
				resultValue = result;
				if isstring(resultValue) || ischar(resultValue)
					resultValue = str2double(resultValue);
				end
				if isempty(resultValue) || isnan(resultValue)
					resultValue = 0;
				end
				fprintf('≣checkTouchWindows-%s⊱%i wasHeld:%i type:%i result:%i new:%i mv:%i prs:%i lastprs:%i rel:%i \n\tx:%.1f y:%.1fY [win:%i %sX %sY]\n',...
				me.name, eventIdValue, me.wasHeld, evt.Type, resultValue, ...
				me.eventNew, me.eventMove, me.eventPressed, me.lastPressed, ...
				me.eventRelease, me.x, me.y, win, ...
				sprintf("{%.1f}",me.window(:).X), ...
				sprintf("{%.1f}",me.window(:).Y));
			end
		end

		% ===================================================================
		function [held, heldtime, release, releasing, searching, failed, touch, negation] = isHold(me)
		%> @fn isHold
		%>
		%> This is the main function which runs touch timers and calculates
		%> the logic of whether the touch is in a region and for how long. 
		%> Use me.window to set the parameters for the hold, for example:
		%> me.window(1).X = 0; me.window(1).Y = 0; me.window(1).radius = 2;
		%>
		%> @return held logical/double indicating if touch is currently in window (-100 = negation)
		%> @return heldtime logical indicating if hold duration requirement met
		%> @return release logical indicating if release condition satisfied
		%> @return releasing logical indicating if currently in release phase
		%> @return searching logical indicating if still searching for touch initiation
		%> @return failed logical indicating if touch attempt failed
		%> @return touch logical indicating if touch event was detected, whether in window or not
		%> @return negation was a negation touch event detected?
		% ===================================================================
			arguments(Output)
				held {mustBeNumericOrLogical}
				heldtime logical
				release logical
				releasing logical
				searching logical
				failed logical
				touch logical
				negation logical
			end

			held = false; heldtime = false; release = false;
			releasing = false; searching = true; failed = false; 
			touch = false; negation = false;

			%% ======================== update hold times
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
			
			%% ======================== check window 
			[held, ~, wasEvent] = checkTouchWindows(me);
			if ~isempty(me.windowTouched) && me.windowTouched > 0
				win = me.windowTouched;
			else
				win = 1;
			end

			%% ======================== NEGATION CHECK
			if held == -100
				negation = true;
				touch = true; %a negation can only occur using a touch out of the window
				searching = false;
				failed = true;
				if me.verbose; fprintf('≣isHold⊱ touchManager -100 NEGATION!\n'); end
				return
			end

			%% ======================= check release requirement, if release is empty / NaN / Inf then we ignore release codition
			releaseTime = me.window(win).release;
			noReleaseRequirement = isempty(releaseTime) || isnan(releaseTime) || isinf(releaseTime);

			%% ======================== check if we have a touch event or not
			if ~wasEvent 
				% no new touch events (BUT remember this can be when a previous touch state is unchanged)
				if me.hold.inWindow % previous event WAS a touch inside window
					me.hold.length = me.hold.now - me.hold.init;
					if me.hold.length >= me.window(win).hold
						me.wasHeld = true;
						heldtime = true;
						if noReleaseRequirement
							if me.verbose; fprintf('≣isHold⊱ ~wasEvent touchManager no release requirement, hold successful!\n'); end
							
							release = true;
							releasing = false;
							searching = false;
						else
							releasing = true;
						end
					end
					if ~noReleaseRequirement
						me.hold.release = me.hold.now - me.hold.releaseinit;
						if me.hold.release > me.window(win).release
							releasing = false;
							failed = true;
						end
					end
				elseif ~me.hold.inWindow && me.hold.search > me.window(win).init
					failed = true;
					searching = false;
				end
				return;
			else 
				% we had a touch event
				touch = true;
			end

			st = '';

			%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
			%% ======================== MAIN HOLD LOGIC
			if me.eventPressed && held %A
				st = 'press&held';
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
				if (me.hold.search <= me.window(win).init) && (me.hold.length >= me.window(win).hold)
					me.wasHeld = true;
					heldtime = true;
					if noReleaseRequirement
						if me.verbose; fprintf('≣isHold⊱ %s touchManager no release requirement, hold successful!\n',st); end
						release = true;
						releasing = false;
					else
						releasing = true;
					end
				end
				if me.wasHeld
					if noReleaseRequirement
						if me.verbose; fprintf('≣isHold⊱ %s touchManager no release requirement, hold successful!\n',st); end
						release = true;
						releasing = false;
					else
						me.hold.release = me.hold.now - me.hold.releaseinit;
						if me.hold.release <= me.window(win).release
							releasing = true;
						else
							releasing = false;
							failed = true;
						end
					end
				end
			elseif me.eventPressed && ~held %B
				st = 'press&notheld';
				me.hold.inWindow = false;
				me.hold.touched = true;
				if me.hold.N > 0
					failed = true;
					searching = false;
				else
					searching = true;
				end
			elseif me.eventRelease && held %C
				st = 'release&held';
				searching = false;
				me.hold.length = me.hold.now - me.hold.init;
				if me.hold.inWindow
					if me.hold.length >= me.window(win).hold
						me.wasHeld = true;
						heldtime = true;
						if noReleaseRequirement
							if me.verbose; fprintf('≣isHold⊱ %s touchManager no release requirement, hold successful!\n',st); end
							release = true;
							releasing = false;
						else
							releasing = true;
						end
					else
						me.wasHeld = false;
						failed = true;
					end
					if ~noReleaseRequirement
						me.hold.release = me.hold.now - me.hold.releaseinit;
						if me.hold.release > me.window(win).release
							releasing = false;
							failed = true;
						else
							release = true;
							releasing = false;
						end
					end
				else
					st = ['!!' st];
				end
				me.hold.inWindow = false;
			elseif me.eventRelease && ~held %D
				st = 'release&notheld';
				me.hold.inWindow = false;
				failed = true;
				searching = false;
			end
			me.isSearching = searching;
			me.isReleased = release;
			if me.verbose
				fprintf(['≣isHold⊱%s⊱%i⊱%s new:%i mv:%i prs:%i rel:%i [x:%.1f y:%.1f winx:%s winy:%s]\n\t' ...
					'N:%i total:%.2f search:%.2f len:%.2f rel:%.2f inWin:%i tchd:%i h:%i ht:%i r:%i rl:%i s:%i fail:%i\n'],...
				me.name,me.eventID,st,me.eventNew,me.eventMove,me.eventPressed,me.eventRelease,...
				me.x,me.y,sprintf("{%.1f}",me.window(:).X),sprintf("{%.1f}",me.window(:).Y),...
				me.hold.N, me.hold.total, me.hold.search, me.hold.length, me.hold.release,...
				me.hold.inWindow, me.hold.touched,...
				held, heldtime, release, releasing, searching, failed);
			end
		end


		% ===================================================================
		function [out, held, heldtime, release, releasing, searching, failed, touch, negation] = testHold(me, yesString, noString)
		%> @fn testHold
		%>
		%> @param
		%> @return
		% ===================================================================
			[held, heldtime, release, releasing, searching, failed, touch, negation] = isHold(me);
			out = '';
			if negation || failed || (~held && ~release && ~searching)
				out = noString;
			elseif heldtime
				out = yesString;
			end
			if me.verbose && ~isempty(out)
				fprintf('≣testHold⊱"%s" held:%i heldtime:%i rel:%i reling:%i ser:%i fail:%i touch:%i neg: {x:%.1f y:%.1f winx:%s winy:%s}\n',...
					out, held, heldtime, release, releasing, searching, failed, touch, negation, ...
					me.x,me.y,sprintf("<%.1f>",me.window(:).X),sprintf("<%.1f>",me.window(:).Y))
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
				fprintf('≣testHoldRelease⊱"%s" held:%i heldtime:%i rel:%i reling:%i ser:%i fail:%i touch:%i {x:%.1f y:%.1f winx:%s winy:%s}\n',...
					out, held, heldtime, release, releasing, searching, failed, touch,...
					me.x,me.y,sprintf("<%.1f>",me.window(:).X),sprintf("<%.1f>",me.window(:).Y))
			end
		end

		% ===================================================================
		function demo(me, nTrials, useaudio, holdTime, releaseTime)
		%> @fn demo
		%>
		%> @param
		%> @return
		% ===================================================================
			arguments(Input)
				me
				nTrials double = 10
				useaudio logical = false
				holdTime double = 1
				releaseTime double = NaN
			end
			if isempty(me.screen); me.screen = screenManager(); end
			sM = me.screen;
			if max(Screen('Screens'))==0 && me.verbose
				mustClearScreen = true;
				PsychDebugWindowConfiguration; 
			else
				mustClearScreen = false;
			end
			oldWin = me.window;
			oldVerbose = me.verbose;
			me.verbose = true;

			if useaudio;a=audioManager();open(a);beep(a,3000,0.1,0.1);WaitSecs(0.2);beep(a,250,0.3,0.8);end

			try
				if ~sM.isOpen; open(sM); end
				setup(me, sM);		%===================!!! Run setup first
				im = discStimulus('size', 6);
				setup(im, sM);
				quitKey = KbName('escape');
				doQuit = false;

				createQueue(me);	%===================!!! Create Queue
				start(me);			%===================!!! Start touch collection

				for i = 1 : nTrials
					if doQuit; break; end
					tx = randi(20)-10;
					ty = randi(20)-10;
					im.xPositionOut = tx;
					im.yPositionOut = ty;
					update(im);
					%updateWindow(me,X,Y,radius,doNegation,negationBuffer,strict,init,hold,release)
					me.updateWindow(tx, ty, im.size/2, true, 2, true, 5, holdTime, releaseTime);
					if useaudio;beep(a,1000,0.1,0.1);end
					fprintf('\n\nTouchManager Demo TRIAL %i -- X = %s Y = %s R = %s\n',i,sprintf("<%.1f>",me.window.X),sprintf("<%.1f>",me.window.Y),sprintf("<%.1f>",me.window.radius));
					infoTxt = sprintf('Negation buffer: %s | Init: %s s | Hold > time: %s s | Release < time %s s',...
						sprintf("<%.1f>",me.window.negationBuffer), sprintf("<%.1f>",me.window.init), ...
						sprintf("<%.1f>",me.window.hold), sprintf("<%.1f>",me.window.release));
					fprintf("%s\n",infoTxt);
					% wait for no touch on screen
					while isTouch(me); fprintf('Please release screen...\n');WaitSecs(0.2); end
					reset(me); %===================!!! reset the touch data
					flush(me); %===================!!! flush the queue
					vbl = flip(sM); ts = vbl;
					result = 'timeout';
					holdResult = '';
					while isempty(holdResult) && vbl <= ts + 20
						if ~isnan(releaseTime) && ~isinf(releaseTime)
							[holdResult, hld, hldt, rel, reli, se, fl, tch] = testHoldRelease(me,'yes','no');
						else
							[holdResult, hld, hldt, rel, reli, se, fl, tch] = testHold(me,'yes','no');
						end
						if hld
							txt = sprintf('%s IN x = %.1f y = %.1f - h:%i ht:%i r:%i rl:%i s:%i f:%i touch:%i N:%i\n%s',...
							holdResult,me.x,me.y,hld,hldt,rel,reli,se,fl,tch,me.hold.N,infoTxt);
						elseif ~isempty(me.x)
							txt = sprintf('%s OUT x = %.1f y = %.1f - h:%i ht:%i r:%i rl:%i s:%i f:%i touch:%i N:%i\n%s',...
							holdResult,me.x,me.y,hld,hldt,rel,reli,se,fl,tch,me.hold.N,infoTxt);
						else
							txt = sprintf('%s NO touch - h:%i ht:%i r:%i rl:%i s:%i f:%i touch:%i N:%i\n%s',...
							holdResult,hld,hldt,rel,reli,se,fl,tch,me.hold.N,infoTxt);
						end
						if ~me.wasHeld; draw(im); end
						drawText(sM,txt); drawGrid(sM); drawScreenCenter(sM); drawSpot(sM,1.25,[0 1 1 0.5],me.x,me.y);
						vbl = flip(sM);
						if strcmp(holdResult,'yes')
							if useaudio;beep(a,3000,0.1,0.1);end
							result = sprintf('CORRECT @ window %i!!!',me.windowTouched); break;
						elseif strcmp(holdResult,'no')
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
					% wait for no touch on screen
					while isTouch(me); fprintf('Please release screen...\n');WaitSecs(0.2); end
					WaitSecs('YieldSecs',2);
				end
				stop(me); close(me); %===================!!! stop and close
				me.window = oldWin;
				me.verbose = oldVerbose;
				if useaudio; try reset(a); end; end
				try reset(im); end
				try close(sM); end
				if mustClearScreen; clear Screen; end
			catch ME
				getReport(ME);
				try reset(im); end
				try close(sM); end
				try close(me); end
				if useaudio; try reset(a); end; end
				try me.window = oldWin; end
				try me.verbose = oldVerbose; end
				if mustClearScreen; clear Screen; end
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
			sM.screen = max(Screen('Screens'));
			sM.disableSyncTests = true;
			sM.font.TextSize = 24;
			clearScreen = false;
			if max(Screen('Screens'))==0 && me.verbose
				PsychDebugWindowConfiguration;
				clearScreen = true;
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
					%updateWindow(me,X,Y,radius,doNegation,negationBuffer,strict,init,hold,release)
					me.updateWindow(0,0,3,true,2,true,5,1,1);
					reset(me);
					flush(me); 	%===================!!! flush the queue
					vbl = flip(sM); ts = vbl;
					while vbl <= ts + 30
						[held, heldtime, release, releasing, searching, failed, touch] = isHold(me);
						uniqueIDs = unique(me.IDall);
						nUnique = length(uniqueIDs);
						if nUnique > 0
							idsString = sprintf('%i ', uniqueIDs(1:min(nUnique,5)));
						else
							idsString = '';
						end
						txt = sprintf('X: %.1f Y: %.1f - h:%i ht:%i r:%i rl:%i s:%i f:%i touch:%i N:%i ids:%i [%s]- evtX:%.1f evtYvbn  ',...
							me.x,me.y,held,heldtime,release,releasing,searching,failed,touch,me.hold.N,nUnique,idsString);
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
				if clearScreen; clear Screen; end
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
				if clearScreen; clear Screen; end
				rethrow(ME);
			end
		end

		function displayInfo(me)
			disp(me);
			for ii = 1:length(me.devices)
				disp(me.devices(ii))
			end
			for ii = 1:length(me.names)
				disp(me.names(ii));
			end
			for ii = 1:length(me.allInfo)
				if iscell(me.allInfo)
					disp(me.allInfo{ii});
				else
					disp(me.allInfo(ii));
				end
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
		function [evt, n] = getAvailableEvents(me)
		%> @fn getAvailableEvents
		%>
		%> @param
		%> @return evt
		%> @return n
		% ===================================================================
			arguments(Output)
				evt struct
				n double
			end
			n = 0;
			while eventAvail(me) > 0
				n = n + 1;
				evt(n) = TouchEventGet(me.devices(me.device), me.swin, 0);
			end
			if n == 0; evt = []; return; end
			if me.drainEvents
				evt = evt(end);
				fprintf('≣≣≣≣⊱ TouchManager Drained %i events\n',n-1);
			end
			
		end

		% ===================================================================
		function result = calculateWindow(me, x, y, tempWindow, isLast)
		%> @fn calculateWindow
		%>
		%> @param
		%> @return
		% ===================================================================
			arguments(Input)
				me
				x double = []
				y double = []
				% can be a rect or a window parameter struct
				tempWindow = []
				% doNegation can only be properly tested on the last window
				isLast logical = true
			end
			arguments(Output)
				result {mustBeNumericOrLogical}
			end
			if isempty(x) || isempty(y); return; end
			if exist('tempWindow','var') && isnumeric(tempWindow) && length(tempWindow) == 4
				pos = screenManager.rectToPos(tempWindow);
				tempWindow = me.windowTemplate;
				tempWindow.X = pos.X;
				tempWindow.Y = pos.Y;
				tempWindow.radius = pos.radius;
			end
			radius = tempWindow.radius;
			xWin = tempWindow.X;
			yWin = tempWindow.Y;
			result = false; match = false; matchneg = false;
			negradius = radius + tempWindow.negationBuffer;
			ez = me.exclusionZone;
			% ---- test for exclusion zones first
			if ~isempty(ez)
				for i = 1:size(ez,1)
					% [-x +x -y +y]
					if (x >= ez(i,1) && x <= ez(i,3)) && ...
						(y >= ez(i,2) && y <= ez(i,4))
						result = -1000;
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
				if tempWindow.doNegation && any(find(r < negradius))
					matchneg = true;
				end
			else % ---- x y rectangular window test
				if (x >= (xWin - radius(1))) && (x <= (xWin + radius(1))) ...
						&& (y >= (yWin - radius(2))) && (y <= (yWin + radius(2)))
					match = true;
				end
				if tempWindow.doNegation ...
					&& (x >= (xWin - negradius(1))) && (x <= (xWin + negradius(1))) ...
					&& (y >= (yWin - negradius(2))) && (y <= (yWin + negradius(2)))
					matchneg = true;
				end
			end
			if (~tempWindow.doNegation && match) || (tempWindow.doNegation && matchneg)
				result = true;
			elseif isLast && tempWindow.doNegation && ~matchneg
				result = -100;
			end
		end
	end
end

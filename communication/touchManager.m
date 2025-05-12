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
%> Copyright ©2014-2025 Ian Max Andolina — released: LGPL3, see LICENCE.md
% ========================================================================

	%--------------------PUBLIC PROPERTIES----------%
	properties
		%> which touch device to connect to?
		device				= 1
		%> use the mouse instead of the touch screen for debugging
		isDummy				= false
		%> window is a touch window, X and Y are the screen postion
		%> radius: circular when radius is 1 value, rectangular when radius = [width height])
		%> doNegation: allows to return -100 (like exclusion) if touch is OUTSIDE window.
		%> when using the testHold etc functions. negationBuffer is an area
		%> around the window to allow some margin of error...
		%> init: timer that tests time to first touch
		%> hold: timer that determines how long to hold
		%> release: timer to determine the time after hold in which window should be released
		window				= struct('X', 0, 'Y', 0, 'radius', 2, 'doNegation', false,...
								'negationBuffer', 2, 'strict', true,...
								'init', 3, 'hold', 0.05, 'release', 1);
		%> Use exclusion zones where no touch allowed: [left,top,right,bottom]
		%> Add rows to generate multiple exclusion zones.
		exclusionZone		= []
		%> drain the events to only get the latest? This ensures lots of
		%> events don't pile up, often you only want the current event,
		%> but potentially causes a longer delay each time getEvent is called...
		drainEvents			= true;
		%> there can be up to 10 touch events, do we record all of them
		trackID				= false
		%> which id to track as the main one (1 = first event)
		mainID				= 1
		%> panel type, 1 = front, 2 = back (reverses X position)
		panelType			= 1
		%> verbose
		verbose				= false
	end

	properties (Hidden = true)
		%> number of slots for touch events
		nSlots				= 1e5
		%> functions return immediately
		silentMode			= false
	end

	properties (SetAccess=private, GetAccess=public)
		% general touch info
		x					= []
		y					= []
		%> All X position in degrees
		xAll				= []
		%> All Y position in degrees
		yAll				= []
		% most recent touch events
		evts				= []
		% touch event info from getEvent()
		event				= []
		eventID				= []
		eventType			= []
		eventNew			= false
		eventMove			= false
		eventPressed		= false
		eventRelease		= false
		% window info from checkTouchWindows()
		win					= []
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

	properties (Access = private)
		deferLog			= false
		lastPressed			= false
		currentID			= []
		pressed				= false
		ppd					= 36
		screen				= []
		swin				= []
		screenVals			= []
		evtsTemplate		= struct('id', [], 'type', [], 'x', [], 'y', [])
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
			me.evts = me.evtsTemplate;
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
			elseif isscalar(me.devices)
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
			reset(me);
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
				if any(b) || me.lastPressed; navail = 1; end
			else
				navail = TouchEventAvail(me.devices(me.device));
			end
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
				evt = getEvent(me);
			end
			me.eventNew = false; me.eventMove = false; me.eventRelease = false; me.eventPressed = false;
			if ~isempty(evt)
				me.eventID		= evt.Keycode;
				me.eventType	= evt.Type;
				switch evt.Type
					case 2 %NEW
						me.eventNew = true;
						me.eventPressed = true;
						me.lastPressed = true;
					case 3 %MOVE
						me.eventMove = true;
						me.eventPressed = true;
					case 4 %RELEASE
						if me.lastPressed || me.isDummy
							me.eventRelease = true;
							me.lastPressed = false;
						end
					case 5 %ERROR
						warning('touchManager: Event lost!');
						me.event = []; evt = [];
						me.lastPressed = false;
						return
					otherwise
						
				end
				if me.panelType == 2; evt.changeX = true; evt.MappedX = me.screenVals.width - evt.MappedX; end
				evt.xy = me.screen.toDegrees([evt.MappedX evt.MappedY],'xy');
				me.event = evt;
				me.x = evt.xy(1); me.y = evt.xy(2);
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
			me.evts			= me.evtsTemplate;
			me.x			= [];
			me.y			= [];
			me.xAll			= [];
			me.yAll			= [];
			me.win			= [];
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
		end

		% ===================================================================
		function [result, win, wasEvent] = checkTouchWindows(me, windows)
		%> @fn [result, win, wasEvent] = checkTouchWindows(me, windows)
		%>
		%> Simply get latest touch event and check if it is in the defined window
		%>
		%> @param windows: [optional] touch rects to test (default use window parameters)
		%> @return result: -100 = negation, true / false otherwise
		% ===================================================================
			if ~exist('windows','var'); windows = []; end
			
			nWindows = max([1 size(windows,1)]);
			result = false; win = 1; wasEvent = false;

			evt = getEvent(me);

			while iscell(evt) && ~isempty(evt); evt = evt{1}; end
			
			if isempty(evt); return; end

			wasEvent = true;

			if ~isempty(evt.xy)
				if isempty(windows)
					[result, win] = calculateWindow(me, evt.xy(1), evt.xy(2));
				else
					for i = 1 : nWindows
						[result(i,1), win] = calculateWindow(me, evt.xy(1), evt.xy(2), windows(i,:));
						if result(i,1); win = i; result = true; break;end
					end
				end
				me.event.result = result;
				if any(result); me.wasInWindow = true; end
			end
			if me.verbose && ~me.deferLog
				fprintf('≣checkWin%s⊱%i wasHeld:%i type:%i result:%i new:%i mv:%i prs:%i rel:%i {%.1fX %.1fY} win:%i\n',...
				me.name, me.eventID, me.wasHeld, evt.Type, result,me.eventNew,me.eventMove,me.eventPressed,me.eventRelease,...
				me.x,me.y,win);
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
			me.deferLog = false;
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
				if me.verbose; fprintf('≣≣≣≣⊱ touchManager -100 NEGATION!\n'); end
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
				fprintf('≣isHold⊱%s⊱%s:%i new:%i mv:%i prs:%i rel:%i {%.1fX %.1fY} tt:%.2f st:%.2f ht:%.2f rt:%.2f inWin:%i tchd:%i h:%i ht:%i r:%i rl:%i s:%i fail:%i N:%i\n',...
				me.name,st,me.eventID,me.eventNew,me.eventMove,me.eventPressed,me.eventRelease,me.x,me.y,...
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
				fprintf('≣testHoldRelease = %s > held:%i heldtime:%i rel:%i reling:%i ser:%i fail:%i touch:%i\n', out, held, heldtime, release, releasing, searching, failed, touch)
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
				fprintf('≣testHoldRelease = %s > held:%i time:%.3f rel:%i rel:%i ser:%i fail:%i touch:%i\n', out, held, heldtime, release, releasing, searching, failed, touch)
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
			if max(Screen('Screens'))==0 && me.verbose
				PsychDebugWindowConfiguration; 
			end
			oldWin = me.window;
			oldVerbose = me.verbose;
			me.verbose = true;

			if useaudio;a=audioManager();open(a);beep(a,3000,0.1,0.1);WaitSecs(0.2);beep(a,250,0.3,0.8);end

			try
				if ~sM.isOpen; open(sM); end
				WaitSecs(0.5);
				setup(me, sM); 		%===================!!! Run setup first
				im = discStimulus('size', 6);
				setup(im, sM);
	
				quitKey = KbName('escape');
				doQuit = false;
				createQueue(me);	%===================!!! Create Queue
				start(me); 			%===================!!! Start touch collection

				for i = 1 : 6
					if doQuit; break; end
					tx = randi(20)-10;
					ty = randi(20)-10;
					im.xPositionOut = tx;
					im.yPositionOut = ty;
					me.window.X = tx;
					me.window.Y = ty;
					me.window.radius = im.size/2;
					me.window.release = 2;
					update(im);
					if useaudio;beep(a,1000,0.1,0.1);end
					fprintf('\n\nTouchManager Demo TRIAL %i -- X = %i Y = %i R = %.2f\n',i,me.window.X,me.window.Y,me.window.radius);
					t = sprintf('Negation buffer: %.2f | Init: %.2f s | Hold > time: %.2f s | Release < time %.2f s',...
						me.window.negationBuffer, me.window.init, me.window.hold, me.window.release);
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
						drawText(sM,txt); drawGrid(sM);
						vbl = flip(sM);
						if strcmp(r,'yes')
							if useaudio;beep(a,3000,0.1,0.1);end
							result = sprintf('CORRECT!!!'); break;
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
			if max(Screen('Screens'))==0 && me.verbose
				PsychDebugWindowConfiguration; 
			end
			
			oldWin = me.window;
			oldVerbose = me.verbose;
			me.verbose = true;

			if ~sM.isOpen; open(sM); end
			setup(me, sM); 		%===================!!! Run setup first

			quitKey = KbName('escape');
			doQuit = false;
			createQueue(me);	%===================!!! Create Queue
			start(me); 			%===================!!! Start touch collection
			try
				while ~doQuit
					reset(me);
					flush(me); 	%===================!!! flush the queue
					me.window.X = 0;
					me.window.Y = 0;
					me.window.radius = 3;
					me.window.release = 2;
					vbl = flip(sM); ts = vbl;
					while vbl <= ts + 30
						[held, heldtime, release, releasing, searching, failed, touch] = isHold(me);
						txt = sprintf('X: %.1f Y: %.1f - h:%i ht:%i r:%i rl:%i s:%i f:%i touch:%i N:%i - evtX:%.1f evtYvbn  ',...
							me.x,me.y,held,heldtime,release,releasing,searching,failed,touch,me.hold.N);
						if ~isempty(me.event) && isstruct(me.event)
						txt = sprintf('%s\n type:%i evtX:%.1f evtY:%.1f nrmX: %.2f nrmY: %.2f mapX: %.1f mapY: %.1f press:%i motion:%i',...
								txt, me.event.Type, me.event.X, me.event.Y, me.event.NormX, me.event.NormY,...
								me.event.MappedX,me.event.MappedY,me.event.Pressed,me.event.Motion);
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

	end

	%=======================================================================
	methods (Access = protected) %------------------PROTECTED METHODS
	%=======================================================================

		function evt = getEvents(me)

			if me.drainEvents
				while eventAvail(me) 
					evt = TouchEventGet(me.devices(me.device), me.swin, 0); 

				end
			else
				evt = TouchEventGet(me.devices(me.device), me.swin, 0);
			end
	
		end
		% ===================================================================
		function [result, window] = calculateWindow(me, x, y, tempWindow)
		%> @fn calculateWindow
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
			if isscalar(radius)
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

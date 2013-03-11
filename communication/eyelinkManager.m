% ========================================================================
%> @brief eyelinkManager wraps around the eyelink toolbox functions
%> offering a simpler interface
%>
% ========================================================================
classdef eyelinkManager < optickaCore
	
	properties
		%> the PTB screen to work on, passed in during initialise
		screen = []
		%> eyetracker defaults structure
		defaults = struct()
		%> start eyetracker in dummy mode?
		isDummy = false
		%> do we record and retrieve eyetracker EDF file?
		recordData = false;
		%> name of eyetracker EDF file
		saveFile = 'myData.edf'
		%> do we log messages to the command window?
		verbose = false
		%> fixation X position in degrees
		fixationX = 0
		%> fixation Y position in degrees
		fixationY = 0
		%> fixation radius in degrees
		fixationRadius = 1
		%> fixation time in seconds
		fixationTime = 1
		%> only allow 1 entry to fixation window?
		strictFixation = true
		%> time to initiate fixation in seconds
		fixationInitTime = 0.25
		%> tracker update speed (Hz), should be 250 500 1000 2000
		sampleRate = 250
		%> calibration style
		calibrationStyle = 'HV5'
		%> use manual remote calibration
		remoteCalibration = true
		% use callbacks
		enableCallbacks = true
		%> cutom calibration callback (enables better handling of
		%> calibration)
		callback = 'eyelinkCallback'
		%> eyelink defaults modifiers as a struct()
		modify = struct()
		%> stimulus positions to draw on screen
		stimulusPositions = []
	end
	
	properties (SetAccess = private, GetAccess = public)
		%> Gaze X position in degrees
		x = []
		%> Gaze Y position in degrees
		y = []
		%> pupil size
		pupil = []
		% are we connected to eyelink?
		isConnected = false
		% are we recording to an EDF file?
		isRecording = false
		% which eye is the tracker using?
		eyeUsed = -1
		%current sample taken from eyelink
		currentSample = []
		%current event taken from eyelink
		currentEvent = []
		%version of eyelink
		version = ''
		%> Initiate fixation length
		fixInitLength = 0
		%how long have we been fixated?
		fixLength = 0
		%> Initiate fixation time
		fixInitStartTime = 0
		%the first timestamp fixation was true
		fixStartTime = 0
		%> total time searching and holding fixation
		fixInitTotal = 0
		%> total time searching and holding fixation
		fixTotal = 0
	end
	
	properties (SetAccess = private, GetAccess = private)
		fixN = 0
		error = []
		%> previous message sent to eyelink
		previousMessage = ''
		%> allowed properties passed to object upon construction
		allowedProperties = 'fixationX|fixationY|fixationRadius|fixationTime|fixationInitTime|sampleRate|calibrationStyle|enableCallbacks|callback|name|verbose|isDummy|remoteCalibration'
	end
	
	methods
		% ===================================================================
		%> @brief 
		%>
		% ===================================================================
		function obj = eyelinkManager(varargin)
			if nargin>0
				obj.parseArgs(varargin,obj.allowedProperties);
			end
			obj.defaults = EyelinkInitDefaults();
			try % is eyelink interface working
				Eyelink('GetTrackerVersion'); 
			catch %#ok<CTCH>
				obj.isDummy = true; 
			end
			obj.modify.calibrationtargetcolour = [1 1 0];
			obj.modify.calibrationtargetsize = 5;
			obj.modify.calibrationtargetwidth = 3;
			obj.modify.waitformodereadytime = 500;
			obj.modify.displayCalResults = 1;
			obj.modify.targetbeep = 0;
			obj.modify.devicenumber = -1;
		end
		
		% ===================================================================
		%> @brief initialise the eyelink, setting up the proper settings
		%> and opening the EDF file if isRecording = true
		%>
		% ===================================================================
		function initialise(obj,sM)
			if ~exist('sM','var')
				warning('Cannot initialise without a PTB screen')
				return
			end
			
			obj.screen = sM;
			
			if ~isempty(obj.callback) && obj.enableCallbacks
				[~,dummy] = EyelinkInit(obj.isDummy,obj.callback);
			elseif obj.enableCallbacks
				[~,dummy] = EyelinkInit(obj.isDummy,1);
			else
				[~,dummy] = EyelinkInit(obj.isDummy,0);
			end
			obj.isDummy = logical(dummy);
			
			obj.checkConnection();
			
			if obj.screen.isOpen == true
				rect=obj.screen.winRect;
				Eyelink('Command', 'screen_pixel_coords = %ld %ld %ld %ld',rect(1),rect(2),rect(3)-1,rect(4)-1);
				obj.defaults = EyelinkInitDefaults(obj.screen.win);
				if exist(obj.callback,'file')
					obj.defaults.callback = obj.callback;
				end
				obj.defaults.backgroundcolour = obj.screen.backgroundColour;
			end
			
			%structure of eyelink modifiers
			fn = fieldnames(obj.modify);
			for i = 1:length(fn)
				if isfield(obj.defaults,fn{i})
					obj.defaults.(fn{i}) = obj.modify.(fn{i});
				end
			end

			obj.updateDefaults();
			
			[~, obj.version] = Eyelink('GetTrackerVersion');
			obj.salutation(['Initialise Method', 'Running on a ' obj.version]);
			
			% try to open file to record data to
			if obj.isConnected && obj.recordData
				err = Eyelink('Openfile', obj.saveFile);
				if err ~= 0 
					obj.salutation('Initialise Method', 'Cannot setup data file, aborting data recording');
					obj.isRecording = false;
				else
					Eyelink('Command', ['add_file_preamble_text ''Recorded by:' obj.fullName ' tracker''']);
					obj.isRecording = true;
				end
			end
			
			Eyelink('Message', 'DISPLAY_COORDS %ld %ld %ld %ld',rect(1),rect(2),rect(3)-1,rect(4)-1);
			Eyelink('Command', 'link_event_filter = LEFT,RIGHT,FIXATION,SACCADE,BLINK,MESSAGE,BUTTON');
			Eyelink('Command', 'link_sample_data  = LEFT,RIGHT,GAZE,GAZERES,AREA,STATUS');
			Eyelink('Command', 'file_event_filter = LEFT,RIGHT,FIXATION,SACCADE,BLINK,MESSAGE,BUTTON');
			Eyelink('Command', 'file_sample_data  = LEFT,RIGHT,GAZE,HREF,AREA,GAZERES,STATUS');
			
			%Eyelink('Command', 'use_ellipse_fitter = no');
			Eyelink('Command', 'sample_rate = %d',obj.sampleRate);
		end
		
		% ===================================================================
		%> @brief 
		%>
		% ===================================================================
		function updateDefaults(obj)
			EyelinkUpdateDefaults(obj.defaults);
		end
		
		% ===================================================================
		%> @brief 
		%>
		% ===================================================================
		function setup(obj)
			if obj.isConnected
				trackerSetup(obj); % Calibrate the eye tracker
				%driftCorrection(obj);
				checkEye(obj);
			end
		end
		
		% ===================================================================
		%> @brief 
		%>
		% ===================================================================
		function resetFixation(obj)
			obj.fixStartTime = 0;
			obj.fixLength = 0;
			obj.fixInitStartTime = 0;
			obj.fixInitLength = 0;
			obj.fixInitTotal = 0;
			obj.fixN = 0;
		end
				
		% ===================================================================
		%> @brief 
		%>
		% ===================================================================
		function connected = checkConnection(obj)
			obj.isConnected = logical(Eyelink('IsConnected'));
			connected = obj.isConnected;
		end
		
		% ===================================================================
		%> @brief sets up the calibration and validation
		%>
		% ===================================================================
		function trackerSetup(obj)
			if obj.isConnected
				Eyelink('Verbosity',4);
				Eyelink('Command','calibration_type = %s', obj.calibrationStyle);
				Eyelink('Command','normal_click_dcorr = ON');
				Eyelink('Command','randomize_calibration_order = NO');
				Eyelink('Command','randomize_validation_order = NO');
				Eyelink('Command','cal_repeat_first_target = YES');
				Eyelink('Command','val_repeat_first_target = YES');
				Eyelink('Command','validation_online_fixup  = NO');
				if obj.remoteCalibration
					Eyelink('Command', 'generate_default_targets = YES');
					Eyelink('Command','remote_cal_enable = 1');
					Eyelink('Command','key_function 1 ''remote_cal_target 1''');
					Eyelink('Command','key_function 2 ''remote_cal_target 2''');
					Eyelink('Command','key_function 3 ''remote_cal_target 3''');
					Eyelink('Command','key_function 4 ''remote_cal_target 4''');
					Eyelink('Command','key_function 5 ''remote_cal_target 5''');
					Eyelink('Command','key_function 6 ''remote_cal_target 6''');
					Eyelink('Command','key_function 7 ''remote_cal_target 7''');
					Eyelink('Command','key_function 8 ''remote_cal_target 8''');
					Eyelink('Command','key_function 9 ''remote_cal_target 9''');
					Eyelink('Command','key_function 0 ''remote_cal_target 0''');
					Eyelink('Command','key_function q ''remote_cal_complete''');
				else 
					Eyelink('Command', 'generate_default_targets = YES');
					Eyelink('Command','remote_cal_enable = 0');
				end
				EyelinkDoTrackerSetup(obj.defaults);
				[~,out] = Eyelink('CalMessage');
				obj.salutation('SETUP',out);
			end
		end
		
		% ===================================================================
		%> @brief wrapper for StartRecording
		%>
		% ===================================================================
		function startRecording(obj)
			if obj.isConnected
				Eyelink('StartRecording');
				checkEye(obj);
			end
		end
		
		% ===================================================================
		%> @brief wrapper for EyelinkDoDriftCorrection
		%>
		% ===================================================================
		function driftCorrection(obj)
			if obj.isConnected
				EyelinkDoDriftCorrection(obj.defaults);
			end
		end
		
		% ===================================================================
		%> @brief wrpper for CheckRecording
		%>
		% ===================================================================
		function error = checkRecording(obj)
			if obj.isConnected
				error=Eyelink('CheckRecording');
			else
				error = -1;
			end
		end
		
		% ===================================================================
		%> @brief get a sample from the tracker, if dummymode=true then use
		%> the mouse as an eye signal
		%>
		% ===================================================================
		function evt = getSample(obj)
			obj.currentSample = [];
			if obj.isConnected && Eyelink('NewFloatSampleAvailable') > 0
				obj.currentSample = Eyelink('NewestFloatSample');% get the sample in the form of an event structure
				if ~isempty(obj.currentSample)
					obj.x = obj.currentSample.gx(obj.eyeUsed+1); % +1 as we're accessing MATLAB array
					obj.y = obj.currentSample.gy(obj.eyeUsed+1);
					obj.pupil = obj.currentSample.pa(obj.eyeUsed+1);
				end
			elseif obj.isDummy %lets use a mouse to simulate the eye signal
				if obj.screen.isOpen
					[obj.x, obj.y] = GetMouse(obj.screen.win);
				else
					[obj.x, obj.y] = GetMouse([]);
				end
				obj.pupil = 1000;
				obj.currentSample.gx = obj.x;
				obj.currentSample.gy = obj.y;
				obj.currentSample.pa = obj.pupil;
				obj.currentSample.time = GetSecs*1000;
			end
			evt = obj.currentSample;
		end
		
		% ===================================================================
		%> @brief 
		%>
		% ===================================================================
		function evt = getEvent(obj)
		
		end
		
		% ===================================================================
		%> @brief Function interface to update the fixation parameters
		%>
		% ===================================================================
		function updateFixationValues(obj,x,y,inittime,fixtime,radius,strict)
			resetFixation(obj)
			if nargin > 1 && ~isempty(x)
				if isinf(x)
					obj.fixationX = obj.screen.screenXOffset;
				else
					obj.fixationX = x;
				end
			end
			if nargin > 2 && ~isempty(y)
				if isinf(y)
					obj.fixationY = obj.screen.screenYOffset;
				else
					obj.fixationY = y;
				end
			end
			if nargin > 3 && ~isempty(inittime);
				if length(inittime) == 2
					obj.fixationInitTime = randi(inittime*1000)/1000;
				elseif length(inittime)==1
					obj.fixationInitTime = inittime;
				end
			end
			if nargin > 4 && ~isempty(fixtime)
				if length(fixtime) == 2
					obj.fixationTime = randi(fixtime*1000)/1000; 
				elseif length(fixtime) == 1
					obj.fixationTime = fixtime;
				end
			end
			if nargin > 5 && ~isempty(radius); obj.fixationRadius = radius; end
			if nargin > 6 && ~isempty(strict); obj.strictFixation = strict; end
		end
		
		% ===================================================================
		%> @brief isFixated tests for fixation and updates the fixLength time
		%>
		%> @return fixated boolean if we are fixated
		%> @return fixtime boolean if we're fixed for fixation time
		%> @return searching boolean for if we are still searching for fixation
		% ===================================================================
		function [fixated, fixtime, searching] = isFixated(obj)
			fixated = false;
			fixtime = false;
			searching = true;
			if obj.isConnected && ~isempty(obj.currentSample)
				if obj.fixInitTotal == 0
					obj.fixInitTotal = obj.currentSample.time;
				end
				r = sqrt((obj.x - obj.fixationX)^2 + (obj.y - obj.fixationY)^2);
				%fprintf('x: %g-%g y: %g-%g r: %g-%g\n',obj.x, obj.fixationX, obj.y, obj.fixationY,r,obj.fixationRadius);
				if r < (obj.fixationRadius);
					if obj.fixN == 0 
						obj.fixN = 1;
					end
					if obj.fixStartTime == 0
						obj.fixStartTime = obj.currentSample.time;
					end
					obj.fixLength = (obj.currentSample.time - obj.fixStartTime) / 1000;
					if obj.fixLength > obj.fixationTime
						fixtime = true;
					end
					obj.fixInitStartTime = 0;
					searching = false;
					fixated = true;
					obj.fixTotal = (obj.currentSample.time - obj.fixInitTotal) / 1000;
					return
				else
					if obj.fixN == 1 
						obj.fixN = -100;
					end
					if obj.fixInitStartTime == 0
						obj.fixInitStartTime = obj.currentSample.time;
					end
					obj.fixInitLength = (obj.currentSample.time - obj.fixInitStartTime) / 1000;
					if obj.fixInitLength <= obj.fixationInitTime
						searching = true;
					else
						searching = false;
					end
					obj.fixStartTime = 0;
					obj.fixLength = 0;
					obj.fixTotal = (obj.currentSample.time - obj.fixInitTotal) / 1000;
					return
				end
			end
		end
			
		% ===================================================================
		%> @brief testFixation returns input yes or no strings based on
		%> fixation state, useful for using via stateMachine
		%>
		% ===================================================================
		function out = testWithinFixationWindow(obj, yesString, noString)
			if obj.isFixated
				out = yesString;
			else
				out = noString;
			end
		end
		
		% ===================================================================
		%> @brief Checks if we've maintained fixation for correct time, if
		%> true return yesString, if not return noString. This allows an
		%> external code to quickly select a string based on this.
		%>
		% ===================================================================
		function out = testFixationTime(obj, yesString, noString)
			[fix,fixtime] = obj.isFixated();
			if fix && fixtime
				obj.salutation(sprintf('Fixation Time: %g',obj.fixLength),'TESTFIXTIME');
				out = yesString;
			else
				out = noString;
			end
		end
		
		% ===================================================================
		%> @brief Checks if we're looking for fixation a set time
		%>
		% ===================================================================
		function out = testSearchHoldFixation(obj, yesString, noString)
			[fix, fixtime, searching] = obj.isFixated();
			if searching
				if (obj.strictFixation==true && (obj.fixN == 0)) || obj.strictFixation==false
					out = ['searching ' num2str(obj.fixInitLength)];
					return
				else
					out = noString;
					%fprintf('--->Eyelink STRICT SEARCH FAIL: %s [%g %g %g]\n', out, fix, fixtime, searching);
					return
				end
			elseif fix
				if (obj.strictFixation==true && ~(obj.fixN == -100)) || obj.strictFixation==false
					if fixtime
						out = [yesString ' ' num2str(obj.fixLength)];
					else
						out = ['fixing ' num2str(obj.fixLength)];
					end
					return
				else
					out = noString;
					%fprintf('--->Eyelink FIX FAIL: %s [%g %g %g]\n', out, fix, fixtime, searching)
					return
				end
			elseif searching == false
				out = noString;
				%fprintf('--->Eyelink SEARCH FAIL: %s [%g %g %g]\n', out, fix, fixtime, searching)
				return
			else
				out = '';
			end
			
		end
		
		% ===================================================================
		%> @brief checks which eye is available, force left eye if
		%> binocular is enabled
		%>
		% ===================================================================
		function eyeUsed = checkEye(obj)
			if obj.isConnected
				obj.eyeUsed = Eyelink('EyeAvailable'); % get eye that's tracked
				if obj.eyeUsed == obj.defaults.BINOCULAR; % if both eyes are tracked
					obj.eyeUsed = obj.defaults.LEFT_EYE; % use left eye
				end
				eyeUsed = obj.eyeUsed;
			else
				obj.eyeUsed = -1;
				eyeUsed = obj.eyeUsed;
			end
		end
		
		% ===================================================================
		%> @brief draw the current eye position on the PTB display
		%>
		% ===================================================================
		function drawEyePosition(obj)
			if obj.isConnected && obj.screen.isOpen && ~isempty(obj.x) && ~isempty(obj.y)
				x = obj.toPixels(obj.x,'x');
				y = obj.toPixels(obj.y,'y');
				if obj.isFixated
					Screen('DrawDots', obj.screen.win, [x y], 8, [1 0.5 1 1], [], 1);
					if obj.fixLength > obj.fixationTime
						Screen('DrawText', obj.screen.win, 'FIX', x, y, [1 1 1]);
					end	
				else
					Screen('DrawDots', obj.screen.win, [x y], 4, [1 0.5 0 1], [], 1);
				end	
			end
		end
		
		% ===================================================================
		%> @brief displays status message on tracker, only sets it if
		%> message is not the previous message, so loop safe.
		%>
		% ===================================================================
		function statusMessage(obj,message)
			if ~strcmpi(message,obj.previousMessage) && obj.isConnected
				obj.previousMessage = message;
				Eyelink('Command',['record_status_message ''' message '''']);
			end
		end
		
		% ===================================================================
		%> @brief close the eyelink and cleanup, send EDF file if recording
		%> is enabled
		%>
		% ===================================================================
		function close(obj)
			try
				if obj.isRecording == true
					Eyelink('StopRecording');
					Eyelink('CloseFile');
					try
						obj.salutation('Close Method',sprintf('Receiving data file %s', obj.saveFile),true);
						status=Eyelink('ReceiveFile');
						if status > 0
							obj.salutation('Close Method',sprintf('ReceiveFile status %d', status));
						end
						if 2==exist(obj.saveFile, 'file')
							obj.salutation('Close Method',sprintf('Data file ''%s'' can be found in ''%s''', obj.saveFile, pwd),true);
						end
					catch ME
						obj.salutation('Close Method',sprintf('Problem receiving data file ''%s''', obj.saveFile),true);
						disp(ME.message);
					end
				end
				Eyelink('Shutdown');
			catch ME
				obj.salutation('Close Method','Couldn''t stop recording, forcing shutdown...',true)
				Eyelink('Shutdown');
				obj.error = ME;
				obj.salutation(ME.message);
			end
			obj.isConnected = false;
			obj.isDummy = false;
			obj.isRecording = false;
			obj.eyeUsed = -1;
			obj.screen = [];
		end
		
		% ===================================================================
		%> @brief draw the stimuli boxes on the tracker display
		%>
		% ===================================================================
		function trackerDrawStimuli(obj)
			if obj.isConnected
				for i = 1:length(obj.stimulusPositions)
					x = obj.screen.xCenter + (obj.stimulusPositions(i).x * obj.screen.ppd);
					y = obj.screen.yCenter + (obj.stimulusPositions(i).y * obj.screen.ppd);
					size = obj.stimulusPositions(i).size * obj.screen.ppd;
					rect = [0 0 size size];
					rect = round(CenterRectOnPoint(rect, x, y));
					Eyelink('Command', 'draw_box %d %d %d %d 12', rect(1), rect(2), rect(3), rect(4));
				end
				
			end
		end
		
		% ===================================================================
		%> @brief draw the fixation box on the tracker display
		%>
		% ===================================================================
		function trackerDrawFixation(obj)
			if obj.isConnected
				size = (obj.fixationRadius * 2) * obj.screen.ppd;
				mod = round(size/10);
				if mod < 0; mod = 0; end
				rect = [0 0 size-mod size-mod];
				x = obj.screen.xCenter + (obj.fixationX * obj.screen.ppd);
				y = obj.screen.yCenter + (obj.fixationY * obj.screen.ppd);
				rect = round(CenterRectOnPoint(rect, x, y));
				Eyelink('Command','clear_screen 0');
				Eyelink('Command', 'draw_box %d %d %d %d 14', rect(1), rect(2), rect(3), rect(4));
			end
		end
		
		% ===================================================================
		%> @brief check what mode the eyelink is in
		%>
		% ===================================================================
		function mode = currentMode(obj)
			if obj.isConnected
				mode = Eyelink('CurrentMode');
			else
				mode = -1;
			end
		end
		
		% ===================================================================
		%> @brief set into offline / idle mode
		%>
		% ===================================================================
		function setOffline(obj)
			if obj.isConnected 
				Eyelink('Command', 'set_idle_mode');
			end
		end
		
		
		% ===================================================================
		%> @brief automagically turn pixels to degrees
		%>
		% ===================================================================
		function set.x(obj,in)
			obj.x = toDegrees(obj,in,'x');
		end
		
		% ===================================================================
		%> @brief automagically turn pixels to degrees
		%>
		% ===================================================================
		function set.y(obj,in)
			obj.y = toDegrees(obj,in,'y');
		end
		
		% ===================================================================
		%> @brief runs a demo of the eyelink, tests this class
		%>
		% ===================================================================
		function runDemo(obj)
			stopkey=KbName('ESCAPE');
			nextKey=KbName('SPACE');
			try
				s = screenManager();
				s.backgroundColour = [0.5 0.5 0.5 0];
				o = dotsStimulus('size',obj.fixationRadius*2,'speed',2,'mask',false,'density',30);
				%s.windowed = [800 600];
				s.screen = 1;
				open(s); %open out screen
				setup(o,s); %setup our stimulus with open screen
				
				ListenChar(2); 
				initialise(obj,s); %initialise eyelink with our screen
				setup(obj); %setup eyelink
			
				obj.statusMessage('DEMO Running'); %
				setOffline(obj); %Eyelink('Command', 'set_idle_mode');
				trackerDrawFixation(obj)
				
				xx = 0;
				
 				while xx == 0
					yy = 0;
					startRecording(obj);
					WaitSecs(0.1);
					Eyelink('Message', 'SYNCTIME');
					vbl=Screen('Flip',s.win);
					while yy == 0
						err = checkRecording(obj);
						if(err~=0); xx = 1; break; end;

						[~, ~, keyCode] = KbCheck(-1);
						if keyCode(stopkey); xx = 1; break;	end;
						if keyCode(nextKey); yy = 1; break; end

						draw(o);
						drawGrid(s);
						drawScreenCenter(s);

						getSample(obj);

						if ~isempty(obj.currentSample)
							x = obj.toPixels(obj.x,'x'); %#ok<*PROP>
							y = obj.toPixels(obj.y,'y');
							txt = sprintf('Press ESC to finish \n X = %g / %g | Y = %g / %g \n RADIUS = %g | FIXATION = %g', x, obj.x, y, obj.y, obj.fixationRadius, obj.fixLength);
							Screen('DrawText', s.win, txt, 10, 10);
							drawEyePosition(obj);
						end

						Screen('DrawingFinished', s.win); 

						animate(o);

						vbl=Screen('Flip',s.win, vbl+(s.screenVals.ifi * 0.5));
					end
					setOffline(obj); %Eyelink('Command', 'set_idle_mode');
					obj.fixationX = randi([-12 12]);
					obj.fixationY = randi([-12 12]);
					obj.fixationRadius = randi([1 6]);
					o.sizeOut = obj.fixationRadius*2;
					o.xPositionOut = obj.fixationX;
					o.yPositionOut = obj.fixationY;
					statusMessage(obj,sprintf('X Pos = %g | Y Pos = %g | Radius = %g',obj.fixationX,obj.fixationY,obj.fixationRadius));
					trackerDrawFixation(obj)
					update(o);
					WaitSecs(0.1)
					
				end
				ListenChar(0);
				close(s);
				close(obj);
				clear s o
				
			catch ME
				ListenChar(0);
				obj.salutation('runDemo ERROR!!!')
				Eyelink('Shutdown');
				close(s);
				sca;
				close(obj);
				clear s o
				obj.error = ME;
				obj.salutation(ME.message);
				rethrow(ME);
			end
			
		end
		
	end%-------------------------END PUBLIC METHODS--------------------------------%
	
	%=======================================================================
	methods (Access = private) %------------------PRIVATE METHODS
	%=======================================================================
		
		% ===================================================================
		%> @brief
		%>
		% ===================================================================
		function out = toDegrees(obj,in,axis)
			switch axis
				case 'x'
					out = (in - obj.screen.xCenter) / obj.screen.ppd;
				case 'y'
					out = (in - obj.screen.yCenter) / obj.screen.ppd;
				otherwise
					out = 0;
			end
		end
		
		% ===================================================================
		%> @brief
		%>
		% ===================================================================
		function out = toPixels(obj,in,axis)
			switch axis
				case 'x'
					out = (in * obj.screen.ppd) + obj.screen.xCenter;
				case 'y'
					out = (in * obj.screen.ppd) + obj.screen.yCenter;
				otherwise
					out = 0;
			end
		end
		
	end
	
end


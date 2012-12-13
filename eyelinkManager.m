classdef eyelinkManager < optickaCore
	
	properties
		%the PTB screen to work on, passed in during initialise
		screen = []
		% eyetracker defaults structure
		defaults = struct()
		% start eyetracker in dummy mode?
		isDummy = false
		% do we record and retrieve eyetracker EDF file?
		recordData = false;
		% name of eyetracker EDF file
		saveFile = 'myData.edf'
		% do we log messages to the command window?
		verbose = true
		% fixation X position in degrees
		fixationX = 0
		% fixation Y position in degrees
		fixationY = 0
		% fixation radius in degrees
		fixationRadius = 1
		% fixation time in seconds
		fixationTime = 1
		%> calibration style
		calibrationStyle = 'HV5'
		%> use manual remote calibration
		remoteCalibration = true
		% use callbacks, currently not working...
		enableCallbacks = true
		%> calibration callback
		callback = ''
	end
	
	properties (SetAccess = private, GetAccess = public)
		%> Gaze X position in degrees
		x = []
		%> Gaze Y position in degrees
		y = []
		%> pupil size
		pupil = []
		silentMode = false
		isConnected = false
		isRecording = false
		eyeUsed = -1
		currentSample = []
		currentEvent = []
		version = ''
		error = []
		fixStartTime = 0
		fixLength = 0
		%> previous message sent to eyelink
		previousMessage = ''
	end
	
	properties (SetAccess = private, GetAccess = private)
		%> allowed properties passed to object upon construction
		allowedProperties = 'name|verbose|isDummy|enableCallbacks'
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
		end
		
		% ===================================================================
		%> @brief 
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
				Eyelink('Command', 'screen_pixel_coords = %d %d %d %d',rect(1),rect(2),rect(3)-1,rect(4)-1);
				obj.defaults = EyelinkInitDefaults(obj.screen.win);
				if exist(obj.callback,'file')
					obj.defaults.callback = obj.callback;
				end
				obj.defaults.backgroundcolour = obj.screen.backgroundColour;
			end
			
			obj.defaults.calibrationtargetcolour = [1 1 0];
			obj.defaults.calibrationtargetsize= 5;
			obj.defaults.calibrationtargetwidth=5;
			obj.defaults.waitformodereadytime=500;

			obj.updateDefaults();
			
			[~, obj.version] = Eyelink('GetTrackerVersion');
			obj.salutation(['Initialise Method', 'Running on a ' obj.version]);
			Eyelink('Command', 'link_sample_data = LEFT,RIGHT,GAZE,AREA');
			% try to open file to record data to
			if obj.isConnected && obj.recordData
				err = Eyelink('Openfile', obj.saveFile);
				if err ~= 0 
					obj.salutation('Initialise Method', 'Cannot setup data file, aborting data recording');
					obj.isRecording = false;
				else
					Eyelink('command', ['add_file_preamble_text ''Recorded by:' obj.fullName ' tracker''']);
					obj.isRecording = true;
				end
			end
			
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
		%> @brief 
		%>
		% ===================================================================
		function trackerSetup(obj)
			if obj.isConnected
				Eyelink('Command','calibration_type = %s', obj.calibrationStyle);
				Eyelink('Command','normal_click_dcorr = ON');
				Eyelink('Command','randomize_calibration_order = NO');
				Eyelink('Command','randomize_validation_order = NO');
				Eyelink('Command','cal_repeat_first_target = YES');
				Eyelink('Command','val_repeat_first_target = YES');
				Eyelink('Command','validation_online_fixup  = NO');
				if obj.remoteCalibration
					Eyelink('Verbosity',6);
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
					Eyelink('Verbosity',6);
					Eyelink('Command','remote_cal_enable = 0');
				end
				EyelinkDoTrackerSetup(obj.defaults);
				[r,out] = Eyelink('CalMessage');
				obj.salutation('SETUP',out);
			end
		end
		
		% ===================================================================
		%> @brief 
		%>
		% ===================================================================
		function startRecording(obj)
			if obj.isConnected
				Eyelink('StartRecording');
				checkEye(obj);
				Eyelink('Message', 'SYNCTIME');
			end
		end
		
		% ===================================================================
		%> @brief 
		%>
		% ===================================================================
		function driftCorrection(obj)
			if obj.isConnected
				EyelinkDoDriftCorrection(obj.defaults);
			end
		end
		
		% ===================================================================
		%> @brief 
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
		%> @brief isFixated tests for fixation
		%>
		% ===================================================================
		function fixated = isFixated(obj)
			fixated = false;
			obj.fixLength = 0;
			if obj.isConnected && ~isempty(obj.currentSample)
				d = (obj.x - obj.fixationX)^2 + (obj.y - obj.fixationY)^2;
				if d < (obj.fixationRadius);
					if obj.fixStartTime == 0
						obj.fixStartTime = obj.currentSample.time;
					end
					obj.fixLength = (obj.currentSample.time - obj.fixStartTime) / 1000;
					fixated = true;
				else
					obj.fixStartTime = 0;
				end
			end
		end
			
		% ===================================================================
		%> @brief testFixation returns input yes or no strings based on
		%> fixation state, useful for using via stateMachine
		%>
		% ===================================================================
		function out = testFixation(obj, yesString, noString)
			if obj.isFixated
				out = yesString;
			else
				out = noString;
			end
		end
		
		% ===================================================================
		%> @brief 
		%>
		% ===================================================================
		function out = testFixationTime(obj, yesString, noString)
			if obj.isFixated && (obj.fixLength > obj.fixationTime)
				obj.salutation(sprintf('Fixation Time: %g',obj.fixLength),'TEST');
				out = yesString;
			else
				out = noString;
			end
		end
			
		
		% ===================================================================
		%> @brief 
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
		%> @brief 
		%>
		% ===================================================================
		function close(obj)
			try
				if obj.isRecording == true
					Eyelink('StopRecording');
					Eyelink('CloseFile');
					try
						obj.salutation('Close Method',sprintf('Receiving data file %s', obj.saveFile));
						status=Eyelink('ReceiveFile');
						if status > 0
							obj.salutation('Close Method',sprintf('ReceiveFile status %d', status));
						end
						if 2==exist(obj.saveFile, 'file')
							obj.salutation('Close Method',sprintf('Data file ''%s'' can be found in ''%s''', obj.saveFile, pwd));
						end
					catch ME
						obj.salutation('Close Method',sprintf('Problem receiving data file ''%s''', obj.saveFile));
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
		%> @brief 
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
		%> @brief 
		%>
		% ===================================================================
		function drawPosition(obj)
			if obj.isConnected && obj.screen.isOpen && ~isempty(obj.x) && ~isempty(obj.y)
				x = obj.toPixels(obj.x,'x');
				y = obj.toPixels(obj.y,'y');
				if obj.isFixated
					Screen('DrawDots', obj.screen.win, [x y], 4, [1 1 1 1], [], 1);
				else
					Screen('DrawDots', obj.screen.win, [x y], 4, [1 0.5 1 1], [], 1);
				end
				if obj.fixLength > obj.fixationTime
					Screen('DrawText', obj.screen.win, 'FIX', x, y);
				end		
			end
		end
		
		% ===================================================================
		%> @brief 
		%>
		% ===================================================================
		function statusMessage(obj,message)
			if ~strcmpi(message,obj.previousMessage) && obj.isConnected
				obj.previousMessage = message;
				Eyelink('Command',['record_status_message ''' message '''']);
			end
		end
		% ===================================================================
		%> @brief 
		%>
		% ===================================================================
		function runDemo(obj)
			stopkey=KbName('space');
			try
				s = screenManager();
				o = dotsStimulus();
				%s.windowed = [800 600];
				s.screen = 1;
				open(s);
				setup(o,s);
				
				ListenChar(1); 
				initialise(obj,s);
				setup(obj);
			
				startRecording(obj);
				obj.statusMessage('DEMO Running');
				
				WaitSecs(0.1);
				while 1
					err = checkRecording(obj);
					if(err~=0); break; end;
						
					[~, ~, keyCode] = KbCheck;
					if keyCode(stopkey); break;	end;
					
					draw(o);
					drawGrid(s);
					drawFixationPoint(s);
					
					getSample(obj);
					
					if ~isempty(obj.currentSample)
						x = obj.toPixels(obj.x,'x');
						y = obj.toPixels(obj.y,'y');
						txt = sprintf('Press SPACE to finish \n X = %g / %g | Y = %g / %g \n FIXATION = %g', x, obj.x, y, obj.y, obj.fixLength);
						Screen('DrawText', s.win, txt, 10, 10);
						if obj.isFixated
							Screen('DrawDots', s.win, [x y], 8, [1 1 1], [], 2);
						else
							Screen('DrawDots', s.win, [x y], 4, rand(3,1), [], 2)
						end
						if obj.fixLength > obj.fixationTime
							Screen('DrawText', s.win, 'FIX', x, y);
							obj.statusMessage('DEMO running + fixated');
						else
							obj.statusMessage('DEMO running');
						end
					end
					
					Screen('DrawingFinished', s.win); 
					
					animate(o);
					
					Screen('Flip',s.win);
					
				end
				ListenChar(0);
				close(s);
				close(obj);
				
			catch ME
				ListenChar(0);
				obj.salutation('runDemo ERROR!!!')
				Eyelink('Shutdown');
				close(s);
				sca;
				close(obj);
				obj.error = ME;
				obj.salutation(ME.message);
				rethrow(ME);
			end
			
		end
		
		% ===================================================================
		%> @brief 
		%>
		% ===================================================================
		function set.x(obj,in)
			obj.x = toDegrees(obj,in,'x');
		end
		
		% ===================================================================
		%> @brief 
		%>
		% ===================================================================
		function set.y(obj,in)
			obj.y = toDegrees(obj,in,'y');
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


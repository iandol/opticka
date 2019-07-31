% ========================================================================
%> @brief eyelinkManager wraps around the Tobii Pro SDK toolbox functions
%> offering a simpler interface
%>
% ========================================================================
classdef tobiiManager < optickaCore
	
	properties
		%> the PTB screen to work on, passed in during initialise
		screen = []
		%> IP address of host
		IP char = 'tet-tcp://169.254.7.109'
		%> start eyetracker in dummy mode?
		isDummy logical = false
		%> do we log messages to the command window?
		verbose = false
		%> fixation X position(s) in degrees
		fixationX double = 0
		%> fixation Y position(s) in degrees
		fixationY double = 0
		%> fixation radius in degrees
		fixationRadius double = 1
		%> fixation time in seconds
		fixationTime double = 1
		%> only allow 1 entry to fixation window?
		strictFixation logical = true
		%> time to initiate fixation in seconds
		fixationInitTime double = 0.25
		%> exclusion zone no eye movement allowed inside
		exclusionZone = []
		%> tracker update speed (Hz), should be 250 500 1000 2000
		sampleRate double = 1200
		%> calibration style
		calibrationStyle char = 'HV5'
		%> stimulus positions to draw on screen
		stimulusPositions = []
	end
	
	properties (Hidden = true)
		
	end
	
	properties (SetAccess = private, GetAccess = public)
		% are we connected to Tobii?
		isConnected logical = false
		% are we recording to matrix?
		isRecording logical = false
		%> data streamed from the Tobii
		data
		%> all connected eyetrackers
		eyetrackers
		%> calibration data
		calibration = []
		%> Last gaze X position in degrees
		x = []
		%> Last gaze Y position in degrees
		y = []
		%> pupil size
		pupil = []
		%current sample taken from tobii
		currentSample = []
		%current event taken from tobii
		currentEvent = []
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
		%> last time offset betweeen tracker and display computers
		currentOffset = 0
		%> tracker time stamp
		trackerTime = 0
		% which eye is the tracker using?
		eyeUsed = -1
		%version of tobii SDK
		version char = ''
		%> main tobii classes
		tobiiOps
		tobii
		%> display area
		displayArea
		%> track box
		trackBox
	end
	
	properties (SetAccess = private, GetAccess = private)
		%> the PTB screen handle, normally set by screenManager but can force it to use another screen
		win = []
		ppd_ double = 35
		fixN double = 0
		fixSelection = []
		%> previous message sent to eyelink
		previousMessage char = ''
		%> allowed properties passed to object upon construction
		allowedProperties char = 'IP|fixationX|fixationY|fixationRadius|fixationTime|fixationInitTime|sampleRate|calibrationStyle|name|verbose|isDummy'
	end
	
	methods
		% ===================================================================
		%> @brief This is the constructor for this class
		%>
		% ===================================================================
		function obj = tobiiManager(varargin)
			if nargin>0
				obj.parseArgs(varargin,obj.allowedProperties);
			end
			try % is tobii sdk working
				obj.tobiiOps = EyeTrackingOperations();
				obj.version = obj.tobiiOps.get_sdk_version();
				obj.eyetrackers = obj.tobiiOps.find_all_eyetrackers();
				if size(obj.eyetrackers,2) == 1
					obj.IP = obj.eyetrackers(1).Address; 
					obj.name = [obj.eyetrackers(1).Model '[' obj.eyetrackers(1).Name ']'];
				end
			catch ME
				obj.tobii = [];
				obj.tobiiOps = [];
				obj.eyetrackers = [];
				obj.isDummy = true;
				obj.version = '-1';
				getReport(ME);
			end
		end
		
		% ===================================================================
		%> @brief initialise the tobii.
		%>
		% ===================================================================
		function initialise(obj,sM)
			if ~exist('sM','var') || isempty(sM)
				sM = screenManager();
			end
			
			obj.tobii = obj.tobiiOps.get_eyetracker(obj.IP);
			if ~isa(obj.tobii,'EyeTracker')
				error('CANNOT INITIALISE TOBII');
			end
			obj.isConnected	= true;
			obj.stopRecording();
			obj.tobii.get_time_sync_data();

			if sM.isOpen == true
				obj.win = obj.screen.win;
			end
			obj.screen			= sM;
			obj.ppd_			= obj.screen.ppd;
			obj.displayArea		= obj.tobii.get_display_area();
			obj.trackBox		= obj.tobii.get_track_box();
			
			result = obj.tobii.get_time_sync_data();

			if isa(result,'StreamError')
				fprintf('Error: %s\n',char(result.Error));
				fprintf('Source: %s\n',char(result.Source));
				fprintf('SystemTimeStamp: %d\n',result.SystemTimeStamp);
				fprintf('Message: %s\n',result.Message);
			elseif isa(result,'TimeSynchronizationReference')
				fprintf('TOBII Collected %d data points\n',size(result,1));
				latest_time_sync_data = result(end);
				fprintf('SystemRequestTimeStamp: %d\n',latest_time_sync_data.SystemRequestTimeStamp);
				fprintf('DeviceTimeStamp: %d\n',latest_time_sync_data.DeviceTimeStamp);
				fprintf('SystemResponseTimeStamp: %d\n',latest_time_sync_data.SystemResponseTimeStamp);
				obj.trackerTime = double(latest_time_sync_data.DeviceTimeStamp);
				obj.currentOffset = double(latest_time_sync_data.SystemResponseTimeStamp);
			end
			
			obj.salutation('Initialise Method', sprintf('Running on a %s @ %2.5g (time offset: %2.5g)', obj.version, obj.trackerTime,obj.currentOffset));
			obj.stopRecording();
		end
		
		% ===================================================================
		%> @brief
		%>
		% ===================================================================
		function updateDefaults(obj)
			
		end
		
		% ===================================================================
		%> @brief
		%>
		% ===================================================================
		function setup(obj)
			if obj.isConnected
				
			end
		end
		
		% ===================================================================
		%> @brief reset the fixation counters ready for a new trial
		%>
		% ===================================================================
		function resetFixation(obj)
			obj.fixStartTime = 0;
			obj.fixLength = 0;
			obj.fixInitStartTime = 0;
			obj.fixInitLength = 0;
			obj.fixInitTotal = 0;
			obj.fixTotal = 0;
			obj.fixN = 0;
			obj.fixSelection = 0;
		end
		
		% ===================================================================
		%> @brief check the connection with the eyelink
		%>
		% ===================================================================
		function connected = checkConnection(obj)
			connected = false;
			if isa(obj.tobii,'EyeTracker')
				obj.tobii.get_time_sync_data();
				result = obj.tobii.get_time_sync_data();
				if isa(result,'TimeSynchronizationReference')
					obj.isConnected = true;
					connected = obj.isConnected;
				end
			end
		end
		
		% ===================================================================
		%> @brief sets up the calibration and validation
		%>
		% ===================================================================
		function trackerSetup(obj)
			
		end
		
		% ===================================================================
		%> @brief wrapper for StartRecording
		%>
		% ===================================================================
		function startRecording(obj)
			if obj.isConnected
				
			end
		end
		
		% ===================================================================
		%> @brief wrapper for StopRecording
		%>
		% ===================================================================
		function stopRecording(obj)
			if obj.isConnected
				obj.tobii.stop_gaze_data();
				obj.tobii.stop_time_sync_data();
				obj.tobii.stop_eye_image();
			end
		end
		
		% ===================================================================
		%> @brief wrapper for EyelinkDoDriftCorrection
		%>
		% ===================================================================
		function success = driftCorrection(obj)
			success = false;
		end
		
		% ===================================================================
		%> @brief wrapper for CheckRecording
		%>
		% ===================================================================
		function error = checkRecording(obj)
			error = true;
		end
		
		% ===================================================================
		%> @brief get a sample from the tracker, if dummymode=true then use
		%> the mouse as an eye signal
		%>
		% ===================================================================
		function sample = getSample(obj)
			if obj.isConnected && Eyelink('NewFloatSampleAvailable') > 0
				obj.currentSample = Eyelink('NewestFloatSample');% get the sample in the form of an event structure
				if ~isempty(obj.currentSample) && isstruct(obj.currentSample)
					obj.x = obj.currentSample.gx(obj.eyeUsed+1); % +1 as we're accessing MATLAB array
					obj.y = obj.currentSample.gy(obj.eyeUsed+1);
					obj.pupil = obj.currentSample.pa(obj.eyeUsed+1);
					%if obj.verbose;fprintf('>>X: %.2g | Y: %.2g | P: %.2g\n',obj.x,obj.y,obj.pupil);end
				end
			elseif obj.isDummy %lets use a mouse to simulate the eye signal
				if ~isempty(obj.win)
					[obj.x, obj.y] = GetMouse(obj.win);
				else
					[obj.x, obj.y] = GetMouse([]);
				end
				obj.pupil = 800 + randi(20);
				obj.currentSample.gx = obj.x;
				obj.currentSample.gy = obj.y;
				obj.currentSample.pa = obj.pupil;
				obj.currentSample.time = GetSecs * 1000;
				%if obj.verbose;fprintf('>>X: %.2g | Y: %.2g | P: %.2g\n',obj.x,obj.y,obj.pupil);end
			end
			sample = obj.currentSample;
		end
		
		% ===================================================================
		%> @brief TODO
		%>
		% ===================================================================
		function evt = getEvent(obj)
			
		end
		
		% ===================================================================
		%> @brief Function interface to update the fixation parameters
		%>
		% ===================================================================
		function updateFixationValues(obj,x,y,inittime,fixtime,radius,strict)
			%tic
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
			if nargin > 3 && ~isempty(inittime)
				if iscell(inittime) && length(inittime)==4
					obj.fixationInitTime = inittime{1};
					obj.fixationTime = inittime{2};
					obj.fixationRadius = inittime{3};
					obj.strictFixation = inittime{4};
				elseif length(inittime) == 2
					obj.fixationInitTime = randi(inittime.*1000)/1000;
				elseif length(inittime)==1
					obj.fixationInitTime = inittime;
				end
			end
			if nargin > 4 && ~isempty(fixtime)
				if length(fixtime) == 2
					obj.fixationTime = randi(fixtime.*1000)/1000;
				elseif length(fixtime) == 1
					obj.fixationTime = fixtime;
				end
			end
			if nargin > 5 && ~isempty(radius); obj.fixationRadius = radius; end
			if nargin > 6 && ~isempty(strict); obj.strictFixation = strict; end
			if obj.verbose
				fprintf('-+-+-> eyelinkManager:updateFixationValues: X=%g | Y=%g | IT=%s | FT=%s | R=%g\n', ...
					obj.fixationX, obj.fixationY, num2str(obj.fixationInitTime), num2str(obj.fixationTime), ...
					obj.fixationRadius);
			end
		end
		
		% ===================================================================
		%> @brief isFixated tests for fixation and updates the fixLength time
		%>
		%> @return fixated boolean if we are fixated
		%> @return fixtime boolean if we're fixed for fixation time
		%> @return searching boolean for if we are still searching for fixation
		% ===================================================================
		function [fixated, fixtime, searching, window, exclusion] = isFixated(obj)
			fixated = false; fixtime = false; searching = true; window = []; exclusion = false;
			if (obj.isConnected || obj.isDummy) && ~isempty(obj.currentSample)
				if obj.fixInitTotal == 0
					obj.fixInitTotal = obj.currentSample.time;
				end
				if ~isempty(obj.exclusionZone)
					eZ = obj.exclusionZone; x = obj.x; y = obj.y;
					if (x >= eZ(1) && x <= eZ(2)) && (y <= eZ(3) && y >= eZ(4))
						fixated = false; fixtime = false; searching = false; exclusion = true;
						fprintf(' ==> EXCLUSION ZONE ENTERED!\n');
						return
					end
				end
				r = sqrt((obj.x - obj.fixationX).^2 + (obj.y - obj.fixationY).^2); %fprintf('x: %g-%g y: %g-%g r: %g-%g\n',obj.x, obj.fixationX, obj.y, obj.fixationY,r,obj.fixationRadius);
				window = find(r < obj.fixationRadius);
				if any(window)
					if obj.fixN == 0
						obj.fixN = 1;
						obj.fixSelection = window(1);
					end
					if obj.fixSelection == window(1)
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
						%if obj.verbose;fprintf(' | %g:%g LENGTH: %g/%g TOTAL: %g/%g | ',fixated,fixtime, obj.fixLength, obj.fixationTime, obj.fixTotal, obj.fixInitTotal);end
						return
					else
						fixated = false;
						fixtime = false;
						searching = false;
					end
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
		function out = testExclusion(obj)
			out = false;
			if (obj.isConnected || obj.isDummy) && ~isempty(obj.currentSample) && ~isempty(obj.exclusionZone)
				eZ = obj.exclusionZone; x = obj.x; y = obj.y;
				if (x >= eZ(1) && x <= eZ(2)) && (y <= eZ(3) && y >= eZ(4))
					out = true;
					fprintf(' ==> EXCLUSION ZONE ENTERED!\n');
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
			if isFixated(obj)
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
			[fix,fixtime] = isFixated(obj);
			if fix && fixtime
				out = yesString; %obj.salutation(sprintf('Fixation Time: %g',obj.fixLength),'TESTFIXTIME');
			else
				out = noString;
			end
		end
		
		% ===================================================================
		%> @brief Checks if we're looking for fixation a set time. Input is
		%> 2 strings, either one is returned depending on success or
		%> failure, 'searching' may also be returned meaning the fixation
		%> window hasn't been entered yet, and 'fixing' means the fixation
		%> time is not yet met...
		%>
		%> @param yesString if this function succeeds return this string
		%> @param noString if this function fails return this string
		%> @return out the output string which is 'searching' if fixation is
		%>   still being initiated, 'fixing' if the fixation window was entered
		%>   but not for the requisite fixation time, or the yes or no string.
		% ===================================================================
		function [out, window, exclusion] = testSearchHoldFixation(obj, yesString, noString)
			[fix, fixtime, searching, window, exclusion] = obj.isFixated();
			if exclusion
				fprintf('-+-+-> Tobii:testSearchHoldFixation EXCLUSION ZONE ENTERED!\n')
				out = 'EXCLUDED!'; window = [];
				return
			end
			if searching
				if (obj.strictFixation==true && (obj.fixN == 0)) || obj.strictFixation==false
					out = 'searching';
				else
					out = noString;
					if obj.verbose; fprintf('-+-+-> Tobii:testSearchHoldFixation STRICT SEARCH FAIL: %s [%g %g %g]\n', out, fix, fixtime, searching);end
				end
				return
			elseif fix
				if (obj.strictFixation==true && ~(obj.fixN == -100)) || obj.strictFixation==false
					if fixtime
						out = yesString;
						if obj.verbose; fprintf('-+-+-> Tobii:testSearchHoldFixation FIXATION SUCCESSFUL!: %s [%g %g %g]\n', out, fix, fixtime, searching);end
					else
						out = 'fixing';
					end
				else
					out = noString;
					if obj.verbose;fprintf('-+-+-> Tobii:testSearchHoldFixation FIX FAIL: %s [%g %g %g]\n', out, fix, fixtime, searching);end
				end
				return
			elseif searching == false
				out = noString;
				if obj.verbose;fprintf('-+-+-> Tobii:testSearchHoldFixation SEARCH FAIL: %s [%g %g %g]\n', out, fix, fixtime, searching);end
			else
				out = '';
			end
			return
		end
		
		% ===================================================================
		%> @brief Checks if we're still within fix window. Input is
		%> 2 strings, either one is returned depending on success or
		%> failure, 'fixing' means the fixation time is not yet met...
		%>
		%> @param yesString if this function succeeds return this string
		%> @param noString if this function fails return this string
		%> @return out the output string which is 'fixing' if the fixation window was entered
		%>   but not for the requisite fixation time, or the yes or no string.
		% ===================================================================
		function [out, window, exclusion] = testHoldFixation(obj, yesString, noString)
			[fix, fixtime, searching, window, exclusion] = obj.isFixated();
			if exclusion
				fprintf('-+-+-> Tobii:testHoldFixation EXCLUSION ZONE ENTERED!\n')
				out = 'EXCLUDED!'; window = [];
				return
			end
			if fix
				if (obj.strictFixation==true && ~(obj.fixN == -100)) || obj.strictFixation==false
					if fixtime
						out = yesString;
						if obj.verbose; fprintf('-+-+-> Tobii:testHoldFixation FIXATION SUCCESSFUL!: %s [%g %g %g]\n', out, fix, fixtime, searching);end
					else
						out = 'fixing';
					end
				else
					out = noString;
					if obj.verbose;fprintf('-+-+-> Tobii:testHoldFixation FIX FAIL: %s [%g %g %g]\n', out, fix, fixtime, searching);end
				end
				return
			else
				out = noString;
				if obj.verbose; fprintf('-+-+-> Tobii:testHoldFixation FIX FAIL: %s [%g %g %g]\n', out, fix, fixtime, searching);end
				return
			end
		end
		
		% ===================================================================
		%> @brief checks which eye is available, force left eye if
		%> binocular is enabled
		%>
		% ===================================================================
		function eyeUsed = checkEye(obj)
			if obj.isConnected
				
			end
		end
		
		% ===================================================================
		%> @brief draw the current eye position on the PTB display
		%>
		% ===================================================================
		function drawEyePosition(obj)
			if (obj.isDummy || obj.isConnected) && obj.screen.isOpen && ~isempty(obj.x) && ~isempty(obj.y)
				x = obj.toPixels(obj.x,'x');
				y = obj.toPixels(obj.y,'y');
				if obj.isFixated
					Screen('DrawDots', obj.win, [x y], 8, [1 0.5 1 1], [], 1);
					if obj.fixLength > obj.fixationTime
						Screen('DrawText', obj.win, 'FIX', x, y, [1 1 1]);
					end
				else
					Screen('DrawDots', obj.win, [x y], 6, [1 0.5 0 1], [], 1);
				end
			end
		end
		
		% ===================================================================
		%> @brief displays status message on tracker, only sets it if
		%> message is not the previous message, so loop safe.
		%>
		% ===================================================================
		function statusMessage(obj,message)
			if obj.isConnected
				if obj.verbose; fprintf('-+-+->Eyelink status message: %s\n',message);end
			end
		end
		
		% ===================================================================
		%> @brief send message to store in EDF data
		%>
		%>
		% ===================================================================
		function edfMessage(obj, message)
			if obj.isConnected
				if obj.verbose; fprintf('-+-+->EDF Message: %s\n',message);end
			end
		end
		
		% ===================================================================
		%> @brief close the eyelink and cleanup, send EDF file if recording
		%> is enabled
		%>
		% ===================================================================
		function close(obj)
			try
				
			catch ME
				obj.salutation('Close Method','Couldn''t stop recording, forcing shutdown...',true)
				obj.error = ME;
				obj.salutation(ME.message);
			end
			Eyelink('Shutdown');
			obj.isConnected = false;
			obj.isDummy = false;
			obj.isRecording = false;
			obj.eyeUsed = -1;
			obj.screen = [];
		end
		
		% ===================================================================
		%> @brief draw the background colour
		%>
		% ===================================================================
		function trackerClearScreen(obj)
			if obj.isConnected
				
			end
		end
		
		% ===================================================================
		%> @brief draw the stimuli boxes on the tracker display
		%>
		% ===================================================================
		function trackerDrawStimuli(obj, ts, clearScreen)
			if obj.isConnected
				
			end
		end
		
		% ===================================================================
		%> @brief draw the fixation box on the tracker display
		%>
		% ===================================================================
		function trackerDrawFixation(obj)
			if obj.isConnected
				
			end
		end
		
		% ===================================================================
		%> @brief draw the fixation box on the tracker display
		%>
		% ===================================================================
		function trackerDrawExclusion(obj)
			if obj.isConnected && ~isempty(obj.exclusionZone) && length(obj.exclusionZone)==4
				
			end
		end
		
		% ===================================================================
		%> @brief draw the fixation box on the tracker display
		%>
		% ===================================================================
		function trackerDrawText(obj,textIn)
			if obj.isConnected
				
			end
		end
		
		% ===================================================================
		%> @brief check what mode the eyelink is in
		%> ##define IN_UNKNOWN_MODE 0
		%> #define IN_IDLE_MODE 1
		%> #define IN_SETUP_MODE 2
		%> #define IN_RECORD_MODE 4
		%> #define IN_TARGET_MODE 8
		%> #define IN_DRIFTCORR_MODE 16
		%> #define IN_IMAGE_MODE 32
		%> #define IN_USER_MENU 64
		%> #define IN_PLAYBACK_MODE 256
		%> #define LINK_TERMINATED_RESULT -100
		% ===================================================================
		function mode = currentMode(obj)
			if obj.isConnected
				mode = obj.tobii.get_eye_tracking_mode();
			end
		end
		
		% ===================================================================
		%> @brief Sync time message for EDF file
		%>
		% ===================================================================
		function syncTime(obj)
			if obj.isConnected
				
			end
		end
		
		% ===================================================================
		%> @brief Get offset between tracker and display computers
		%>
		% ===================================================================
		function offset = getTimeOffset(obj)
			if obj.isConnected
				offset = Eyelink('TimeOffset');
				obj.currentOffset = offset;
			else
				offset = 0;
			end
		end
		
		% ===================================================================
		%> @brief Get offset between tracker and display computers
		%>
		% ===================================================================
		function time = getTrackerTime(obj)
			if obj.isConnected
				time = Eyelink('TrackerTime');
				obj.trackerTime = time;
			else
				time = 0;
			end
		end
		
		% ===================================================================
		%> @brief set into offline / idle mode
		%>
		% ===================================================================
		function setOffline(obj)
			if obj.isConnected
				
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
			calibkey=KbName('C');
			validkey=KbName('V');
			driftkey=KbName('D');
			obj.recordData = true;
			try
				s = screenManager('debug',true);
				s.backgroundColour = [0.5 0.5 0.5 0];
				o = dotsStimulus('size',obj.fixationRadius*2,'speed',2,'mask',false,'density',30);
				open(s); %open out screen
				setup(o,s); %setup our stimulus with open screen
				
				ListenChar(1);
				initialise(obj,s); %initialise eyelink with our screen
				setup(obj); %setup eyelink
				
				obj.statusMessage('DEMO Running'); %
				setOffline(obj); %Eyelink('Command', 'set_idle_mode');
				trackerClearScreen(obj);
				trackerDrawFixation(obj);
				xx = 0;
				a = 1;
				
				while xx == 0
					yy = 0;
					b = 1;
					edfMessage(obj,'V_RT MESSAGE END_FIX END_RT');
					edfMessage(obj,['TRIALID ' num2str(a)]);
					startRecording(obj);
					WaitSecs(0.1);
					vbl=Screen('Flip',s.win);
					syncTime(obj);
					while yy == 0
						err = checkRecording(obj);
						if(err~=0); xx = 1; break; end
						
						[~, ~, keyCode] = KbCheck(-1);
						if keyCode(stopkey); xx = 1; break;	end
						if keyCode(nextKey); yy = 1; break; end
						if keyCode(calibkey); yy = 1; break; end
						
						if b == 30; edfMessage(obj,'END_FIX');end
						
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
						b=b+1;
					end
					edfMessage(obj,'END_RT');
					stopRecording(obj)
					edfMessage(obj,'TRIAL_RESULT 1')
					if xx ~=1; driftCorrection(obj); end
					obj.fixationX = randi([-5 5]);
					obj.fixationY = randi([-5 5]);
					obj.fixationRadius = randi([1 5]);
					o.sizeOut = obj.fixationRadius*2;
					o.xPositionOut = obj.fixationX;
					o.yPositionOut = obj.fixationY;
					ts.x = obj.fixationX;
					ts.y = obj.fixationY;
					ts.size = o.sizeOut;
					ts.selected = true;
					setOffline(obj); %Eyelink('Command', 'set_idle_mode');
					statusMessage(obj,sprintf('X Pos = %g | Y Pos = %g | Radius = %g',obj.fixationX,obj.fixationY,obj.fixationRadius));
					trackerClearScreen(obj);
					trackerDrawFixation(obj);
					trackerDrawStimuli(obj,ts);
					update(o);
					WaitSecs(0.3)
					a=a+1;
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
			if ~exist('axis','var');axis='';end
			switch axis
				case 'x'
					out = (in - obj.screen.xCenter) / obj.ppd_;
				case 'y'
					out = (in - obj.screen.yCenter) / obj.ppd_;
				otherwise
					if length(in)==2
						out(1) = (in(1) - obj.screen.xCenter) / obj.ppd_;
						out(2) = (in(2) - obj.screen.yCenter) / obj.ppd_;
					else
						out = 0;
					end
			end
		end
		
		% ===================================================================
		%> @brief
		%>
		% ===================================================================
		function out = toPixels(obj,in,axis)
			if ~exist('axis','var');axis='';end
			switch axis
				case 'x'
					out = (in * obj.ppd_) + obj.screen.xCenter;
				case 'y'
					out = (in * obj.ppd_) + obj.screen.yCenter;
				otherwise
					if length(in)==2
						out(1) = (in(1) * obj.ppd_) + obj.screen.xCenter;
						out(2) = (in(2) * obj.ppd_) + obj.screen.yCenter;
					elseif length(in)==4
						out(1:2) = (in(1:2) * obj.ppd_) + obj.screen.xCenter;
						out(3:4) = (in(3:4) * obj.ppd_) + obj.screen.yCenter;
					else
						out = 0;
					end
			end
		end
		
	end
	
end


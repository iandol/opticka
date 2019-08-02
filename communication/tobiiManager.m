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
		verbose = true
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
		%> tracker time stamp
		systemTime = 0
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
		function me = tobiiManager(varargin)
			if nargin>0
				me.parseArgs(varargin,me.allowedProperties);
			end
			try % is tobii sdk working
				initTracker(me);
				me.isDummy = false;
			catch ME
				me.tobii = [];
				me.tobiiOps = [];
				me.eyetrackers = [];
				me.isDummy = true;
				me.version = '-1';
				getReport(ME);
			end
		end
		
		% ===================================================================
		%> @brief initialise the tobii.
		%>
		% ===================================================================
		function initialise(me,sM)
			if ~exist('sM','var') || isempty(sM)
				sM = screenManager();
			end
			initTracker(me);
			me.tobii = me.tobiiOps.get_eyetracker(me.IP);
			if ~isa(me.tobii,'EyeTracker')
				error('CANNOT INITIALISE TOBII');
			end
			me.isConnected	= true;
			me.stopRecording();
			me.data = [];
			me.tobii.get_time_sync_data();

			me.screen		= sM;
			me.ppd_			= me.screen.ppd;
			if sM.isOpen == true
				me.win = me.screen.win;
			end
			me.displayArea	= me.tobii.get_display_area();
			me.trackBox		= me.tobii.get_track_box();
			
			syncTrackerTime(me);
			
			me.salutation('Initialise Method', sprintf('Running on a %s @ %2.5g (time offset: %2.5g)', me.version, me.trackerTime,me.currentOffset));
			me.stopRecording();
		end
		
		% ===================================================================
		%> @brief
		%>
		% ===================================================================
		function updateDefaults(me)
			
		end
		
		% ===================================================================
		%> @brief
		%>
		% ===================================================================
		function setup(me)
			if me.isConnected
				
			end
		end
		
		% ===================================================================
		%> @brief reset the fixation counters ready for a new trial
		%>
		% ===================================================================
		function resetFixation(me)
			me.fixStartTime = 0;
			me.fixLength = 0;
			me.fixInitStartTime = 0;
			me.fixInitLength = 0;
			me.fixInitTotal = 0;
			me.fixTotal = 0;
			me.fixN = 0;
			me.fixSelection = 0;
		end
		
		% ===================================================================
		%> @brief check the connection with the eyelink
		%>
		% ===================================================================
		function connected = checkConnection(me)
			connected = false;
			if isa(me.tobii,'EyeTracker')
				me.tobii.get_time_sync_data();
				result = me.tobii.get_time_sync_data();
				if isa(result,'TimeSynchronizationReference')
					me.isConnected = true;
					connected = me.isConnected;
				end
			end
		end
		
		% ===================================================================
		%> @brief sets up the calibration and validation
		%>
		% ===================================================================
		function trackerSetup(me)
			if me.isConnected && me.screen.isOpen
				resetFixation(me);
				checkHeadPosition(me);
				doCalibration(me);
			end
		end
		
		% ===================================================================
		%> @brief wrapper for StartRecording
		%>
		% ===================================================================
		function startRecording(me,trialInfo)
			if me.isConnected
				me.tobii.get_gaze_data();
				me.isRecording = true;
			end
		end
		
		% ===================================================================
		%> @brief wrapper for StopRecording
		%>
		% ===================================================================
		function stopRecording(me)
			if me.isConnected
				me.tobii.stop_gaze_data();
				me.tobii.stop_time_sync_data();
				me.tobii.stop_eye_image();
				me.isRecording = false;
			end
		end
		
		% ===================================================================
		%> @brief wrapper for EyelinkDoDriftCorrection
		%>
		% ===================================================================
		function success = driftCorrection(me)
			success = false;
		end
		
		% ===================================================================
		%> @brief wrapper for CheckRecording
		%>
		% ===================================================================
		function error = checkRecording(me)
			error = false;
		end
		
		% ===================================================================
		%> @brief get a sample from the tracker, if dummymode=true then use
		%> the mouse as an eye signal
		%>
		% ===================================================================
		function sample = getSample(me)
			me.currentSample = [];
			if me.isConnected && me.isRecording
				cdata = me.tobii.get_gaze_data();
				if ~isempty(cdata) && isa(cdata(1),'GazeData') && cdata(1).LeftEye.GazePoint.Validity.Valid
					thisdata = cdata(end);
					me.currentSample.gx = thisdata.LeftEye.GazePoint.OnDisplayArea(1);
					me.currentSample.gy = thisdata.LeftEye.GazePoint.OnDisplayArea(2);
					me.currentSample.pa = thisdata.LeftEye.Pupil.Diameter;
					me.currentSample.time = double(thisdata.SystemTimeStamp);
					me.x = me.currentSample.gx * me.screen.screenVals.width; 
					me.y = me.currentSample.gy * me.screen.screenVals.height;
					me.pupil = me.currentSample.pa;
					if me.x < 0; me.x = 0; end
					if me.y < 0; me.y = 0; end
					%if me.verbose;fprintf('>>X: %.2g | Y: %.2g | P: %.2g\n',me.x,me.y,me.pupil);end
				end
			elseif me.isDummy %lets use a mouse to simulate the eye signal
				if ~isempty(me.win)
					[me.x, me.y] = GetMouse(me.win);
				else
					[me.x, me.y] = GetMouse([]);
				end
				me.pupil = 800 + randi(20);
				me.currentSample.gx = me.x;
				me.currentSample.gy = me.y;
				me.currentSample.pa = me.pupil;
				me.currentSample.time = GetSecs * 1000;
				%if me.verbose;fprintf('>>X: %.2g | Y: %.2g | P: %.2g\n',me.x,me.y,me.pupil);end
			end
			if me.isConnected && me.isRecording && ~me.isDummy
				me.data = [me.data;cdata];
			end
			sample = me.currentSample;
		end
		
		% ===================================================================
		%> @brief TODO
		%>
		% ===================================================================
		function evt = getEvent(me)
			
		end
		
		% ===================================================================
		%> @brief Function interface to update the fixation parameters
		%>
		% ===================================================================
		function updateFixationValues(me,x,y,inittime,fixtime,radius,strict)
			%tic
			resetFixation(me)
			if nargin > 1 && ~isempty(x)
				if isinf(x)
					me.fixationX = me.screen.screenXOffset;
				else
					me.fixationX = x;
				end
			end
			if nargin > 2 && ~isempty(y)
				if isinf(y)
					me.fixationY = me.screen.screenYOffset;
				else
					me.fixationY = y;
				end
			end
			if nargin > 3 && ~isempty(inittime)
				if iscell(inittime) && length(inittime)==4
					me.fixationInitTime = inittime{1};
					me.fixationTime = inittime{2};
					me.fixationRadius = inittime{3};
					me.strictFixation = inittime{4};
				elseif length(inittime) == 2
					me.fixationInitTime = randi(inittime.*1000)/1000;
				elseif length(inittime)==1
					me.fixationInitTime = inittime;
				end
			end
			if nargin > 4 && ~isempty(fixtime)
				if length(fixtime) == 2
					me.fixationTime = randi(fixtime.*1000)/1000;
				elseif length(fixtime) == 1
					me.fixationTime = fixtime;
				end
			end
			if nargin > 5 && ~isempty(radius); me.fixationRadius = radius; end
			if nargin > 6 && ~isempty(strict); me.strictFixation = strict; end
			if me.verbose
				fprintf('-+-+-> eyelinkManager:updateFixationValues: X=%g | Y=%g | IT=%s | FT=%s | R=%g\n', ...
					me.fixationX, me.fixationY, num2str(me.fixationInitTime), num2str(me.fixationTime), ...
					me.fixationRadius);
			end
		end
		
		% ===================================================================
		%> @brief isFixated tests for fixation and updates the fixLength time
		%>
		%> @return fixated boolean if we are fixated
		%> @return fixtime boolean if we're fixed for fixation time
		%> @return searching boolean for if we are still searching for fixation
		% ===================================================================
		function [fixated, fixtime, searching, window, exclusion] = isFixated(me)
			fixated = false; fixtime = false; searching = true; window = []; exclusion = false;
			if (me.isConnected || me.isDummy) && ~isempty(me.currentSample)
				if me.fixInitTotal == 0
					me.fixInitTotal = me.currentSample.time;
				end
				if ~isempty(me.exclusionZone)
					eZ = me.exclusionZone; x = me.x; y = me.y;
					if (x >= eZ(1) && x <= eZ(2)) && (y <= eZ(3) && y >= eZ(4))
						fixated = false; fixtime = false; searching = false; exclusion = true;
						fprintf(' ==> EXCLUSION ZONE ENTERED!\n');
						return
					end
				end
				r = sqrt((me.x - me.fixationX).^2 + (me.y - me.fixationY).^2); %fprintf('x: %g-%g y: %g-%g r: %g-%g\n',me.x, me.fixationX, me.y, me.fixationY,r,me.fixationRadius);
				window = find(r < me.fixationRadius);
				if any(window)
					if me.fixN == 0
						me.fixN = 1;
						me.fixSelection = window(1);
					end
					if me.fixSelection == window(1)
						if me.fixStartTime == 0
							me.fixStartTime = me.currentSample.time;
						end
						me.fixLength = (me.currentSample.time - me.fixStartTime) / 1000;
						if me.fixLength > me.fixationTime
							fixtime = true;
						end
						me.fixInitStartTime = 0;
						searching = false;
						fixated = true;
						me.fixTotal = (me.currentSample.time - me.fixInitTotal) / 1000;
						%if me.verbose;fprintf(' | %g:%g LENGTH: %g/%g TOTAL: %g/%g | ',fixated,fixtime, me.fixLength, me.fixationTime, me.fixTotal, me.fixInitTotal);end
						return
					else
						fixated = false;
						fixtime = false;
						searching = false;
					end
				else
					if me.fixN == 1
						me.fixN = -100;
					end
					if me.fixInitStartTime == 0
						me.fixInitStartTime = me.currentSample.time;
					end
					me.fixInitLength = (me.currentSample.time - me.fixInitStartTime) / 1000;
					if me.fixInitLength <= me.fixationInitTime
						searching = true;
					else
						searching = false;
					end
					me.fixStartTime = 0;
					me.fixLength = 0;
					me.fixTotal = (me.currentSample.time - me.fixInitTotal) / 1000;
					return
				end
			end
		end
		
		% ===================================================================
		%> @brief testFixation returns input yes or no strings based on
		%> fixation state, useful for using via stateMachine
		%>
		% ===================================================================
		function out = testExclusion(me)
			out = false;
			if (me.isConnected || me.isDummy) && ~isempty(me.currentSample) && ~isempty(me.exclusionZone)
				eZ = me.exclusionZone; x = me.x; y = me.y;
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
		function out = testWithinFixationWindow(me, yesString, noString)
			if isFixated(me)
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
		function out = testFixationTime(me, yesString, noString)
			[fix,fixtime] = isFixated(me);
			if fix && fixtime
				out = yesString; %me.salutation(sprintf('Fixation Time: %g',me.fixLength),'TESTFIXTIME');
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
		function [out, window, exclusion] = testSearchHoldFixation(me, yesString, noString)
			[fix, fixtime, searching, window, exclusion] = me.isFixated();
			if exclusion
				fprintf('-+-+-> Tobii:testSearchHoldFixation EXCLUSION ZONE ENTERED!\n')
				out = 'EXCLUDED!'; window = [];
				return
			end
			if searching
				if (me.strictFixation==true && (me.fixN == 0)) || me.strictFixation==false
					out = 'searching';
				else
					out = noString;
					if me.verbose; fprintf('-+-+-> Tobii:testSearchHoldFixation STRICT SEARCH FAIL: %s [%g %g %g]\n', out, fix, fixtime, searching);end
				end
				return
			elseif fix
				if (me.strictFixation==true && ~(me.fixN == -100)) || me.strictFixation==false
					if fixtime
						out = yesString;
						if me.verbose; fprintf('-+-+-> Tobii:testSearchHoldFixation FIXATION SUCCESSFUL!: %s [%g %g %g]\n', out, fix, fixtime, searching);end
					else
						out = 'fixing';
					end
				else
					out = noString;
					if me.verbose;fprintf('-+-+-> Tobii:testSearchHoldFixation FIX FAIL: %s [%g %g %g]\n', out, fix, fixtime, searching);end
				end
				return
			elseif searching == false
				out = noString;
				if me.verbose;fprintf('-+-+-> Tobii:testSearchHoldFixation SEARCH FAIL: %s [%g %g %g]\n', out, fix, fixtime, searching);end
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
		function [out, window, exclusion] = testHoldFixation(me, yesString, noString)
			[fix, fixtime, searching, window, exclusion] = me.isFixated();
			if exclusion
				fprintf('-+-+-> Tobii:testHoldFixation EXCLUSION ZONE ENTERED!\n')
				out = 'EXCLUDED!'; window = [];
				return
			end
			if fix
				if (me.strictFixation==true && ~(me.fixN == -100)) || me.strictFixation==false
					if fixtime
						out = yesString;
						if me.verbose; fprintf('-+-+-> Tobii:testHoldFixation FIXATION SUCCESSFUL!: %s [%g %g %g]\n', out, fix, fixtime, searching);end
					else
						out = 'fixing';
					end
				else
					out = noString;
					if me.verbose;fprintf('-+-+-> Tobii:testHoldFixation FIX FAIL: %s [%g %g %g]\n', out, fix, fixtime, searching);end
				end
				return
			else
				out = noString;
				if me.verbose; fprintf('-+-+-> Tobii:testHoldFixation FIX FAIL: %s [%g %g %g]\n', out, fix, fixtime, searching);end
				return
			end
		end
		
		% ===================================================================
		%> @brief checks which eye is available, force left eye if
		%> binocular is enabled
		%>
		% ===================================================================
		function eyeUsed = checkEye(me)
			if me.isConnected
				
			end
		end
		
		% ===================================================================
		%> @brief draw the current eye position on the PTB display
		%>
		% ===================================================================
		function drawEyePosition(me)
			if (me.isDummy || me.isConnected) && me.screen.isOpen && ~isempty(me.x) && ~isnan(me.x) && ~isempty(me.y) && ~isnan(me.y)
				if me.isFixated
					Screen('DrawDots', me.win, [me.x me.y], 8, [1 0.5 1 1], [], 1);
					if me.fixLength > me.fixationTime
						Screen('DrawText', me.win, 'FIX', me.x, me.y, [1 1 1]);
					end
				else
					Screen('DrawDots', me.win, [30 30], 6, [1 0.5 0 1], [], 1);
				end
			end
		end
		
		% ===================================================================
		%> @brief displays status message on tracker, only sets it if
		%> message is not the previous message, so loop safe.
		%>
		% ===================================================================
		function statusMessage(me,message)
			if me.isConnected
				if me.verbose; fprintf('-+-+->Tobii status message: %s\n',message);end
			end
		end
		
		% ===================================================================
		%> @brief send message to store in EDF data
		%>
		%>
		% ===================================================================
		function edfMessage(me, message)
			if me.isConnected
				if me.verbose; fprintf('-+-+->EDF Message: %s\n',message);end
			end
		end
		
		% ===================================================================
		%> @brief close the eyelink and cleanup, send EDF file if recording
		%> is enabled
		%>
		% ===================================================================
		function close(me)
			try
				stopRecording(me)
				me.tobii = [];
				me.tobiiOps = [];
			catch ME
				me.salutation('Close Method','Couldn''t stop recording, forcing shutdown...',true)
				me.error = ME;
				me.salutation(ME.message);
			end
			me.isConnected = false;
			me.isDummy = false;
			me.isRecording = false;
			me.eyeUsed = -1;
			me.screen = [];
		end
		
		% ===================================================================
		%> @brief draw the background colour
		%>
		% ===================================================================
		function trackerClearScreen(me)
			if me.isConnected
				
			end
		end
		
		% ===================================================================
		%> @brief draw the stimuli boxes on the tracker display
		%>
		% ===================================================================
		function trackerDrawStimuli(me, ts, clearScreen)
			if me.isConnected
				
			end
		end
		
		% ===================================================================
		%> @brief draw the fixation box on the tracker display
		%>
		% ===================================================================
		function trackerDrawFixation(me)
			if me.isConnected
				
			end
		end
		
		% ===================================================================
		%> @brief draw the fixation box on the tracker display
		%>
		% ===================================================================
		function trackerDrawExclusion(me)
			if me.isConnected && ~isempty(me.exclusionZone) && length(me.exclusionZone)==4
				
			end
		end
		
		% ===================================================================
		%> @brief draw the fixation box on the tracker display
		%>
		% ===================================================================
		function trackerDrawText(me,textIn)
			if me.isConnected
				
			end
		end
		
		% ===================================================================
		%> @brief check what mode the tobii is in
		%> 
		% ===================================================================
		function mode = currentMode(me)
			if me.isConnected
				mode = me.tobii.get_eye_tracking_mode();
			end
		end
		
		
		% ===================================================================
		%> @brief Sync time with tracker
		%>
		% ===================================================================
		function syncTime(me)
			
		end
			
			
		% ===================================================================
		%> @brief Sync time with tracker
		%>
		% ===================================================================
		function syncTrackerTime(me)
			if me.isConnected
				me.tobii.get_time_sync_data();
				result = me.tobii.get_time_sync_data();
				me.tobii.stop_time_sync_data();
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
					me.trackerTime = double(latest_time_sync_data.DeviceTimeStamp);
					me.currentOffset = me.trackerTime - double(latest_time_sync_data.SystemResponseTimeStamp);
				end
			end
		end
		
		% ===================================================================
		%> @brief Get offset between tracker and display computers
		%>
		% ===================================================================
		function offset = getTimeOffset(me)
			if me.isConnected
				offset = 0;
				me.currentOffset = offset;
			else
				offset = 0;
			end
		end
		
		% ===================================================================
		%> @brief Get tracker time
		%>
		% ===================================================================
		function [trackertime, systemtime] = getTrackerTime(me)
			if me.isConnected
				trackertime = 0;
				me.systemTime = me.tobiiOps.get_system_time_stamp();
			else
				trackertime = 0;
				systemtime = 0;
			end
		end
		
		% ===================================================================
		%> @brief set into offline / idle mode
		%>
		% ===================================================================
		function setOffline(me)
			if me.isConnected
				stopRecording(me);
			end
		end
		
		% ===================================================================
		%> @brief automagically turn pixels to degrees
		%>
		% ===================================================================
		function set.x(me,in)
			me.x = toDegrees(me,in,'x');
		end
		
		% ===================================================================
		%> @brief automagically turn pixels to degrees
		%>
		% ===================================================================
		function set.y(me,in)
			me.y = toDegrees(me,in,'y');
		end
		
		% ===================================================================
		%> @brief runs a demo of the eyelink, tests this class
		%>
		% ===================================================================
		function runDemo(me)
			KbName('UnifyKeyNames')
			stopkey=KbName('escape');
			nextKey=KbName('space');
			calibkey=KbName('C');
			validkey=KbName('V');
			driftkey=KbName('D');
			try
				s = screenManager('debug',true,'blend',true);
				s.backgroundColour = [0.5 0.5 0.5 0];
				o = dotsStimulus('size',me.fixationRadius*2,'speed',2,'mask',false,'density',30);
				open(s); %open out screen
				setup(o,s); %setup our stimulus with open screen
				
				ListenChar(1);
				initialise(me,s); %initialise eyelink with our screen
				trackerSetup(me);
				
				me.statusMessage('DEMO Running'); %
				setOffline(me);
				
				xx = 0;
				a = 1;
				while xx == 0
					yy = 0;
					b = 1;
					startRecording(me);
					WaitSecs(0.1);
					vbl=flip(s);
					syncTime(me);
					while yy == 0
						err = checkRecording(me);
						if(err~=0); xx = 1; break; end
						
						[~, ~, keyCode] = KbCheck(-1);
						if keyCode(stopkey); xx = 1; break;	end
						if keyCode(nextKey); yy = 1; break; end
						if keyCode(calibkey); yy = 1; break; end
						
						if b == 30; edfMessage(me,'END_FIX');end
						
						draw(o);
						drawGrid(s);
						drawScreenCenter(s);
						
						getSample(me);
						
						if ~isempty(me.currentSample)
							txt = sprintf('Press ESC to finish \n X = %g / %g | Y = %g / %g \n RADIUS = %g | FIXATION = %g', me.currentSample.gx, me.x, me.currentSample.gy, me.y, me.fixationRadius, me.fixLength);
							Screen('DrawText', s.win, txt, 10, 10);
							drawEyePosition(me);
						end
						
						Screen('DrawingFinished', s.win);
						animate(o);
						vbl=Screen('Flip',s.win, vbl+(s.screenVals.ifi * 0.5));
						b=b+1;
					end
					edfMessage(me,'END_RT');
					stopRecording(me)
					edfMessage(me,'TRIAL_RESULT 1')
					
					me.fixationX = randi([-5 5]);
					me.fixationY = randi([-5 5]);
					me.fixationRadius = randi([1 5]);
					o.sizeOut = me.fixationRadius*2;
					o.xPositionOut = me.fixationX;
					o.yPositionOut = me.fixationY;
					ts.x = me.fixationX;
					ts.y = me.fixationY;
					ts.size = o.sizeOut;
					ts.selected = true;
					setOffline(me); %Eyelink('Command', 'set_idle_mode');
					statusMessage(me,sprintf('X Pos = %g | Y Pos = %g | Radius = %g',me.fixationX,me.fixationY,me.fixationRadius));
					update(o);
					WaitSecs(0.3)
					a=a+1;
				end
				ListenChar(0);
				close(s);
				close(me);
				clear s o
			catch ME
				getReport(ME);
				ListenChar(0);
				Priority(0);
				me.salutation('runDemo ERROR!!!')
				close(s);
				sca;
				close(me);
				clear s o
				me.salutation(ME.message);
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
		function checkHeadPosition(me)
			if ~me.isConnected; return; end
			me.tobii.get_gaze_data();
			while ~KbCheck
				DrawFormattedText(me.screen.win, 'When correctly positioned press any key to start the calibration.', 'center', me.screen.screenVals.height * 0.1, me.screen.screenVals.white);
				distance = [];
				gaze_data = me.tobii.get_gaze_data();
				if ~isempty(gaze_data)
					last_gaze = gaze_data(end);
					validityColor = [0.8 0 0];
					% Check if user has both eyes inside a reasonable tacking area.
					if last_gaze.LeftEye.GazeOrigin.Validity.Valid && last_gaze.RightEye.GazeOrigin.Validity.Valid
						left_validity = all(last_gaze.LeftEye.GazeOrigin.InTrackBoxCoordinateSystem(1:2) < 0.85) ...
							&& all(last_gaze.LeftEye.GazeOrigin.InTrackBoxCoordinateSystem(1:2) > 0.15);
						right_validity = all(last_gaze.RightEye.GazeOrigin.InTrackBoxCoordinateSystem(1:2) < 0.85) ...
							&& all(last_gaze.RightEye.GazeOrigin.InTrackBoxCoordinateSystem(1:2) > 0.15);
						if left_validity && right_validity
							validityColor = [0 0.8 0];
						end
					end
					origin = [me.screen.screenVals.width/4 me.screen.screenVals.height/4];
					size = [me.screen.screenVals.width/2 me.screen.screenVals.height/2];
					
					baseRect = [0 0 size(1) size(2)];
					frame = CenterRectOnPointd(baseRect, me.screen.screenVals.width/2, me.screen.screenVals.height/2);
					
					Screen('FrameRect', me.screen.win, validityColor, frame, 5);
					% Left Eye
					if last_gaze.LeftEye.GazeOrigin.Validity.Valid
						distance = [distance; round(last_gaze.LeftEye.GazeOrigin.InUserCoordinateSystem(3)/10,1)];
						left_eye_pos_x = double(1-last_gaze.LeftEye.GazeOrigin.InTrackBoxCoordinateSystem(1))*size(1) + origin(1);
						left_eye_pos_y = double(last_gaze.LeftEye.GazeOrigin.InTrackBoxCoordinateSystem(2))*size(2) + origin(2);
						Screen('DrawDots', me.screen.win, [left_eye_pos_x left_eye_pos_y], 30, validityColor, [], 2);
					end
					% Right Eye
					if last_gaze.RightEye.GazeOrigin.Validity.Valid
						distance = [distance;round(last_gaze.RightEye.GazeOrigin.InUserCoordinateSystem(3)/10,1)];
						right_eye_pos_x = double(1-last_gaze.RightEye.GazeOrigin.InTrackBoxCoordinateSystem(1))*size(1) + origin(1);
						right_eye_pos_y = double(last_gaze.RightEye.GazeOrigin.InTrackBoxCoordinateSystem(2))*size(2) + origin(2);
						Screen('DrawDots', me.screen.win, [right_eye_pos_x right_eye_pos_y], 30, validityColor, [], 2);
					end
				end
				DrawFormattedText(me.screen.win, sprintf('Current distance to the eye tracker: %.2f cm.',mean(distance)), 'center', me.screen.screenVals.height * 0.85, me.screen.screenVals.white);
				flip(me.screen);
			end
			me.tobii.stop_gaze_data();
		end
		
		% ===================================================================
		%> @brief
		%>
		% ===================================================================
		function doCalibration(me)
			
			spaceKey = KbName('escape');
			RKey = KbName('C');
			
			dotSizePix = 20;
			
			dotColor = [[1 0 0];[1 1 1]]; % Red and white
			
			leftColor = [0.8 0 0]; 
			rightColor = [0 0.8 0]; 
			
			% Calibration points
			lb = 0.15;  % left bound
			xc = 0.5;  % horizontal center
			rb = 0.85;  % right bound
			ub = 0.15;  % upper bound
			yc = 0.5;  % vertical center
			bb = 0.85;  % bottom bound
			
			points_to_calibrate = [[xc,yc];[lb,ub];[rb,ub];[lb,bb];[rb,bb]];
			
			% Create calibration object
			calib = ScreenBasedCalibration(me.tobii);
			calib.leave_calibration_mode();
			calibrating = true;
			
			DrawFormattedText(me.screen.win, 'Get ready to fixate...', 'center', 'center', me.screen.screenVals.white);
			flip(me.screen);
			WaitSecs(0.5);
			spx = [me.screen.screenVals.width me.screen.screenVals.height];
			
			while calibrating
				% Enter calibration mode
				calib.enter_calibration_mode();
				
				for i=1:length(points_to_calibrate)
					
					Screen('DrawDots', me.screen.win, points_to_calibrate(i,:).*spx, dotSizePix, dotColor(1,:), [], 2);
					Screen('DrawDots', me.screen.win, points_to_calibrate(i,:).*spx, dotSizePix*0.3, dotColor(2,:), [], 2);
					
					Screen('Flip', me.screen.win);
					
					% Wait a moment to allow the user to focus on the point
					WaitSecs(1);
					
					if calib.collect_data(points_to_calibrate(i,:)) ~= CalibrationStatus.Success
						% Try again if it didn't go well the first time.
						% Not all eye tracker models will fail at this point, but instead fail on ComputeAndApply.
						calib.collect_data(points_to_calibrate(i,:));
					end
					
					flip(me.screen);
					WaitSecs(0.2);
					
				end
				
				DrawFormattedText(me.screen.win, 'Calculating calibration result....', 'center', 'center', me.screen.screenVals.white);
				
				flip(me.screen);
				
				% Blocking call that returns the calibration result
				calibration_result = calib.compute_and_apply();
				
				calib.leave_calibration_mode();
				
				if calibration_result.Status ~= CalibrationStatus.Success
					break
				end
				
				% Calibration Result
				WaitSecs(0.5);
				flip(me.screen);
				points = calibration_result.CalibrationPoints;
				
				for i=1:length(points)
					Screen('DrawDots', me.screen.win, points(i).PositionOnDisplayArea.*spx, dotSizePix*0.5, dotColor(2,:), [], 2);
					for j=1:length(points(i).RightEye)
						if points(i).LeftEye(j).Validity == CalibrationEyeValidity.ValidAndUsed
							Screen('DrawDots', me.screen.win, points(i).LeftEye(j).PositionOnDisplayArea.*spx, dotSizePix*0.3, leftColor, [], 2);
							Screen('DrawLines', me.screen.win, ([points(i).LeftEye(j).PositionOnDisplayArea; points(i).PositionOnDisplayArea].*spx)', 2, leftColor, [0 0], 2);
						end
						if points(i).RightEye(j).Validity == CalibrationEyeValidity.ValidAndUsed
							Screen('DrawDots', me.screen.win, points(i).RightEye(j).PositionOnDisplayArea.*spx, dotSizePix*0.3, rightColor, [], 2);
							Screen('DrawLines', me.screen.win, ([points(i).RightEye(j).PositionOnDisplayArea; points(i).PositionOnDisplayArea].*spx)', 2, rightColor, [0 0], 2);
						end
					end
					
				end
				
				DrawFormattedText(me.screen.win, 'Press the ''C'' key to recalibrate or ''Escape'' to continue....', 'center', me.screen.screenVals.height * 0.95, me.screen.screenVals.white)
				flip(me.screen);
				
				while true
					[ keyIsDown, seconds, keyCode ] = KbCheck;
					keyCode = find(keyCode, 1);
					if keyIsDown
						if keyCode == spaceKey
							calibrating = false;
							break;
						elseif keyCode == RKey
							break;
						end
						KbReleaseWait;
					end
				end
			end
			
		end
		
		% ===================================================================
		%> @brief
		%>
		% ===================================================================
		function initTracker(me)
			me.tobiiOps = EyeTrackingOperations();
			me.version = me.tobiiOps.get_sdk_version();
			me.eyetrackers = me.tobiiOps.find_all_eyetrackers();
			me.IP = me.eyetrackers(1).Address; 
			me.name = [me.eyetrackers(1).Model '[' me.eyetrackers(1).Name ']'];
		end
		
		% ===================================================================
		%> @brief
		%>
		% ===================================================================
		function out = toDegrees(me,in,axis)
			if ~exist('axis','var');axis='';end
			switch axis
				case 'x'
					out = (in - me.screen.xCenter) / me.ppd_;
				case 'y'
					out = (in - me.screen.yCenter) / me.ppd_;
				otherwise
					if length(in)==2
						out(1) = (in(1) - me.screen.xCenter) / me.ppd_;
						out(2) = (in(2) - me.screen.yCenter) / me.ppd_;
					else
						out = 0;
					end
			end
		end
		
		% ===================================================================
		%> @brief
		%>
		% ===================================================================
		function out = toPixels(me,in,axis)
			if ~exist('axis','var');axis='';end
			switch axis
				case 'x'
					out = (in * me.ppd_) + me.screen.xCenter;
				case 'y'
					out = (in * me.ppd_) + me.screen.yCenter;
				otherwise
					if length(in)==2
						out(1) = (in(1) * me.ppd_) + me.screen.xCenter;
						out(2) = (in(2) * me.ppd_) + me.screen.yCenter;
					elseif length(in)==4
						out(1:2) = (in(1:2) * me.ppd_) + me.screen.xCenter;
						out(3:4) = (in(3:4) * me.ppd_) + me.screen.yCenter;
					else
						out = 0;
					end
			end
		end
		
	end
	
end


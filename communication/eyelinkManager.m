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
		defaults struct = struct()
		%> IP address of host
		IP char = ''
		%> start eyetracker in dummy mode?
		isDummy logical = false
		%> do we record and retrieve eyetracker EDF file?
		recordData logical = false;
		%> name of eyetracker EDF file
		saveFile char = 'myData.edf'
		%> do we log messages to the command window?
		verbose logical = false
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
		sampleRate double = 250
		%> calibration style
		calibrationStyle char = 'HV5'
		%> use manual remote calibration
		remoteCalibration logical = false
		% use callbacks
		enableCallbacks logical = true
		%> cutom calibration callback (enables better handling of
		%> calibration)
		callback char = 'eyelinkCallback'
		%> eyelink defaults modifiers as a struct()
		modify struct = struct()
		%> stimulus positions to draw on screen
		stimulusPositions = []
	end
	
	properties (Hidden = true)
		%> verbosity level
		verbosityLevel double = 4
		%> force drift correction?
		forceDriftCorrect logical = false
	end
	
	properties (SetAccess = private, GetAccess = public)
		%> Gaze X position in degrees
		x = []
		%> Gaze Y position in degrees
		y = []
		%> pupil size
		pupil = []
		% are we connected to eyelink?
		isConnected logical = false
		% are we recording to an EDF file?
		isRecording logical = false
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
		%> last time offset betweeen tracker and display computers
		currentOffset = 0
		%> tracker time stamp
		trackerTime = 0
	end
	
	properties (SetAccess = private, GetAccess = private)
		%> the PTB screen handle, normally set by screenManager but can force it to use another screen
		win = []
		ppd_ double = 35
		tempFile char = 'MYDATA.edf'
		fixN double = 0
		fixSelection = []
		error = []
		%> previous message sent to eyelink
		previousMessage char = ''
		%> allowed properties passed to object upon construction
		allowedProperties char = 'IP|fixationX|fixationY|fixationRadius|fixationTime|fixationInitTime|sampleRate|calibrationStyle|enableCallbacks|callback|name|verbose|isDummy|remoteCalibration'
	end
	
	methods
		% ===================================================================
		%> @brief This is the constructor for this class
		%>
		% ===================================================================
		function obj = eyelinkManager(varargin)
			if nargin>0
				obj.parseArgs(varargin,obj.allowedProperties);
			end
			obj.defaults = EyelinkInitDefaults();
			try % is eyelink interface working
				obj.version = Eyelink('GetTrackerVersion');
			catch %#ok<CTCH>
				obj.version = 0;
			end
			obj.modify.calibrationtargetcolour = [1 1 1];
			obj.modify.calibrationtargetsize = 0.8;
			obj.modify.calibrationtargetwidth = 0.04;
			obj.modify.displayCalResults = 1;
			obj.modify.targetbeep = 0;
			obj.modify.devicenumber = -1;
			obj.modify.waitformodereadytime = 500;
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
			
			Eyelink('Shutdown'); %just make sure link is closed
			obj.screen = sM;
			
			if ~isempty(obj.IP) && ~obj.isDummy
				obj.salutation('Eyelink Initialise',['Trying to set custom IP address: ' obj.IP],true)
				ret = Eyelink('SetAddress', obj.IP);
				if ret ~= 0
					warning('!!!--> Couldn''t set IP address to %s!!!\n',obj.IP);
				end
			end
			
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
				obj.win = obj.screen.win;
				obj.defaults = EyelinkInitDefaults(obj.win);
			elseif ~isempty(obj.win)
				obj.defaults = EyelinkInitDefaults(obj.win);
			else
				obj.defaults = EyelinkInitDefaults();
			end
			
			rect=obj.screen.winRect;
			Eyelink('Command', 'screen_pixel_coords = %ld %ld %ld %ld',rect(1),rect(2),rect(3),rect(4));
			if ~isempty(obj.callback) && exist(obj.callback,'file')
				obj.defaults.callback = obj.callback;
			end
			obj.defaults.backgroundcolour = obj.screen.backgroundColour;
			obj.ppd_ = obj.screen.ppd;
			
			%structure of eyelink modifiers
			fn = fieldnames(obj.modify);
			for i = 1:length(fn)
				if isfield(obj.defaults,fn{i})
					obj.defaults.(fn{i}) = obj.modify.(fn{i});
				end
			end
			
			obj.defaults.verbose = obj.verbose;
			
			obj.updateDefaults();
			
			[~, obj.version] = Eyelink('GetTrackerVersion');
			getTrackerTime(obj);
			obj.salutation('Initialise Method', sprintf('Running on a %s @ %2.5g', obj.version, obj.trackerTime));
			
			% try to open file to record data to
			if obj.isConnected && obj.recordData
				err = Eyelink('Openfile', obj.tempFile);
				if err ~= 0
					warning('eyelinkManager Cannot setup Eyelink data file, aborting data recording');
					obj.isRecording = false;
				else
					Eyelink('Command', ['add_file_preamble_text ''Recorded by:' obj.fullName ' tracker'''],true);
					obj.isRecording = true;
				end
			end
			
			Eyelink('Message', 'DISPLAY_COORDS %ld %ld %ld %ld',rect(1),rect(2),rect(3),rect(4));
			Eyelink('Message', 'FRAMERATE %ld',round(obj.screen.screenVals.fps));
			Eyelink('Message', 'DISPLAY_PPD %ld', round(obj.ppd_));
			Eyelink('Message', 'DISPLAY_DISTANCE %ld', round(obj.screen.distance));
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
				checkEye(obj);
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
			obj.fixN = 0;
			obj.fixSelection = 0;
		end
		
		% ===================================================================
		%> @brief check the connection with the eyelink
		%>
		% ===================================================================
		function connected = checkConnection(obj)
			isc = Eyelink('IsConnected');
			if isc == 1
				obj.isConnected = true;
			elseif isc == -1
				obj.isConnected = false;
				obj.isDummy = true;
			else
				obj.isConnected = false;
			end
			connected = obj.isConnected;
		end
		
		% ===================================================================
		%> @brief sets up the calibration and validation
		%>
		% ===================================================================
		function trackerSetup(obj)
			if ~obj.isConnected; return; end
			Eyelink('Verbosity',obj.verbosityLevel);
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
			fprintf('\n===>>> CALIBRATE EYELINK <<<===\n');
			EyelinkDoTrackerSetup(obj.defaults);
			[result,out] = Eyelink('CalMessage');
			fprintf('\t===>>> RESULT =  %.2g | message: %s\n\n',result,out);
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
		%> @brief wrapper for StopRecording
		%>
		% ===================================================================
		function stopRecording(obj)
			if obj.isConnected
				Eyelink('StopRecording');
			end
		end
		
		
		% ===================================================================
		%> @brief wrapper for EyelinkDoDriftCorrection
		%>
		% ===================================================================
		function success = driftCorrection(obj)
			success = false;
			if obj.forceDriftCorrect
				Eyelink('command', 'driftcorrect_cr_disable = ON');
			end
			if obj.isConnected
				success = EyelinkDoDriftCorrection(obj.defaults, obj.fixationX, obj.fixationY);
				%success = Eyelink('DriftCorrStart', obj.screen.xCenter, obj.screen.yCenter, 1, 1, 1);
				fprintf('Drift Correct at %.2g %.2g RETURN: %.2g\n', obj.fixationX, obj.fixationY, success);
			end
			if success == -1
				obj.salutation('Drift Correct','FAILED',true);
			elseif obj.forceDriftCorrect
				obj.salutation('Drift Correct','TRY TO APPLY',true);
				Eyelink('ApplyDriftCorr');
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
			if obj.verbose; fprintf('-+-+-> eyelinkManager:updateFixationValues: X=%g | Y=%g | IT=%s | FT=%s | R=%g\n', obj.fixationX, obj.fixationY, num2str(obj.fixationInitTime), num2str(obj.fixationTime), obj.fixationRadius); end
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
				fprintf('-+-+-> Eyelink:testSearchHoldFixation EXCLUSION ZONE ENTERED!\n')
				out = 'EXCLUDED!'; window = [];
				return
			end
			if searching
				if (obj.strictFixation==true && (obj.fixN == 0)) || obj.strictFixation==false
					out = 'searching';
				else
					out = noString;
					if obj.verbose; fprintf('-+-+-> Eyelink:testSearchHoldFixation STRICT SEARCH FAIL: %s [%g %g %g]\n', out, fix, fixtime, searching);end
				end
				return
			elseif fix
				if (obj.strictFixation==true && ~(obj.fixN == -100)) || obj.strictFixation==false
					if fixtime
						out = yesString;
						if obj.verbose; fprintf('-+-+-> Eyelink:testSearchHoldFixation FIXATION SUCCESSFUL!: %s [%g %g %g]\n', out, fix, fixtime, searching);end
					else
						out = 'fixing';
					end
				else
					out = noString;
					if obj.verbose;fprintf('-+-+-> Eyelink:testSearchHoldFixation FIX FAIL: %s [%g %g %g]\n', out, fix, fixtime, searching);end
				end
				return
			elseif searching == false
				out = noString;
				if obj.verbose;fprintf('-+-+-> Eyelink:testSearchHoldFixation SEARCH FAIL: %s [%g %g %g]\n', out, fix, fixtime, searching);end
			else
				out = '';
			end
			return
		end
		
		% ===================================================================
		%> @brief checks which eye is available, force left eye if
		%> binocular is enabled
		%>
		% ===================================================================
		function eyeUsed = checkEye(obj)
			if obj.isConnected
				obj.eyeUsed = Eyelink('EyeAvailable'); % get eye that's tracked
				if obj.eyeUsed == obj.defaults.BINOCULAR % if both eyes are tracked
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
			if ~strcmpi(message,obj.previousMessage) && obj.isConnected
				obj.previousMessage = message;
				Eyelink('Command',['record_status_message ''' message '''']);
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
				Eyelink('Message', message );
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
				obj.isConnected = false;
				obj.isDummy = false;
				obj.eyeUsed = -1;
				obj.screen = [];
				if obj.isRecording == true && ~isempty(obj.saveFile)
					Eyelink('StopRecording');
					Eyelink('CloseFile');
					try
						obj.salutation('Close Method',sprintf('Receiving data file %s', obj.tempFile),true);
						status=Eyelink('ReceiveFile');
						if status > 0
							obj.salutation('Close Method',sprintf('ReceiveFile status %d', status));
						end
						if exist(obj.tempFile, 'file')
							obj.salutation('Close Method',sprintf('Data file ''%s'' can be found in ''%s''', obj.tempFile, strrep(pwd,'\','/')),true);
							status = movefile(obj.tempFile, obj.saveFile,'f');
							if status == 1
								obj.salutation('Close Method',sprintf('Data file copied to ''%s''', obj.saveFile),true);
							end
						end
					catch ME
						obj.salutation('Close Method',sprintf('Problem receiving data file ''%s''', obj.tempFile),true);
						disp(ME.message);
					end
				end
				trackerClearScreen(obj);
			catch ME
				obj.salutation('Close Method','Couldn''t stop recording, forcing shutdown...',true)
				trackerClearScreen(obj);
				Eyelink('Shutdown');
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
				Eyelink('Command', 'clear_screen 0');
			end
		end
		
		% ===================================================================
		%> @brief draw the stimuli boxes on the tracker display
		%>
		% ===================================================================
		function trackerDrawStimuli(obj, ts, clearScreen)
			if obj.isConnected
				if exist('ts','var') && isstruct(ts)
					obj.stimulusPositions = ts;
				end
				if ~exist('clearScreen','var')
					clearScreen = false;
				end
				for i = 1:length(obj.stimulusPositions)
					x = obj.stimulusPositions(i).x; %#ok<PROPLC>
					y = obj.stimulusPositions(i).y; %#ok<PROPLC>
					size = obj.stimulusPositions(i).size;
					if isempty(size); size = 1 * obj.ppd_; end
					rect = [0 0 size size];
					rect = round(CenterRectOnPoint(rect, x, y)); %#ok<PROPLC>
					if clearScreen; Eyelink('Command', 'clear_screen 0'); end
					if obj.stimulusPositions(i).selected == true
						Eyelink('Command', 'draw_box %d %d %d %d 10', rect(1), rect(2), rect(3), rect(4));
					else
						Eyelink('Command', 'draw_box %d %d %d %d 11', rect(1), rect(2), rect(3), rect(4));
					end
				end			
			end
		end
		
		% ===================================================================
		%> @brief draw the fixation box on the tracker display
		%>
		% ===================================================================
		function trackerDrawFixation(obj)
			if obj.isConnected
				size = (obj.fixationRadius * 2) * obj.ppd_;
				rect = [0 0 size size];
				x = toPixels(obj, obj.fixationX, 'x');
				y = toPixels(obj, obj.fixationY, 'y');
				rect = round(CenterRectOnPoint(rect, x, y));
				Eyelink('Command', 'draw_filled_box %d %d %d %d 12', rect(1), rect(2), rect(3), rect(4));
			end
		end
		
		% ===================================================================
		%> @brief draw the fixation box on the tracker display
		%>
		% ===================================================================
		function trackerDrawExclusion(obj)
			if obj.isConnected && ~isempty(obj.exclusionZone) && length(obj.exclusionZone)==4
				rect = toPixels(obj, obj.exclusionZone);
				Eyelink('Command', 'draw_box %d %d %d %d 10', rect(1), rect(2), rect(3), rect(4));
			end
		end
		
		% ===================================================================
		%> @brief draw the fixation box on the tracker display
		%>
		% ===================================================================
		function trackerDrawText(obj,textIn)
			if obj.isConnected
				if exist('textIn','var') && ~isempty(textIn)
					xDraw = toPixels(obj, 0, 'x');
					yDraw = toPixels(obj, 0, 'y');
					Eyelink('Command', 'draw_text %i %i %d %s', xDraw, yDraw, 3, textIn);
				end
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
				mode = Eyelink('CurrentMode');
			else
				mode = -100;
			end
		end
		
		% ===================================================================
		%> @brief Sync time message for EDF file
		%>
		% ===================================================================
		function syncTime(obj)
			if obj.isConnected
				Eyelink('Message', 'SYNCTIME');		%zero-plot time for EDFVIEW
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


% ========================================================================
%> @class eyelinkManager
%> @brief eyelinkManager wraps around the eyelink toolbox functions offering a
%> consistent interface and methods for fixation window control
%>
%> Class methods enable the user to test for common behavioural eye tracking
%> tasks with single commands. For example, to initiate a task we normally
%> place a fixation cross on the screen and ask the subject to saccade to
%> the cross and maintain fixation for a particular duration. This is
%> achieved using testSearchHoldFixation('yes','no'), using the properties:
%> fixation.initTime to time how long the subject has to saccade into the
%> window, fixation.time for how long they must maintain fixation,
%> fixation.radius for the radius around fixation.X and fixation.Y position.
%> The method returns the 'yes' string if the rules are matched, and 'no' if
%> they are not, thus enabling experiment code to simply call this method
%> until it returns 'yes''. Other methods include isFixated(),
%> testFixationTime(), testHoldFixation().
%>
%> This class enables several types of behavioural control:
%>
%> 1. Fixation window: one or more areas where the subject must enter with
%>    their eye position within a certain time and must maintain fixation
%>    for a certain time. Windows can be circular or rectangular.
%> 2. Exclusion zones: one or more rectangular areas that cause failure if
%>    entered.
%> 3. Fix initiation zone: an area the eye must stay with for a certain time
%>    before a saccade. For example if a subect fixates, then must saccade a
%>    time X, do not allow the eye to leave this zone before X + t (t by
%>    default is 100ms). This stops potential cheating by the subject.
%>
%> Try using the demo mode to see it in action (read the runDemo() code to
%> understand how to use the class):
%>
%>```matlab
%> >> eT = eyelinkManager('verbose', true);
%> >> eT.runDemo();
%>```
%>
%> Multiple fixation windows can be assigned (either circular or
%> rectangular), and in addition multiple exclusion windows (exclusionZone)
%> can ensure a subject doesn't saccade to particular parts of the screen.
%> fixInit allows you to define a minimum time with which the subject can
%> initiate a saccade away from a position (which stops a subject cheating
%> by moving the eyes too soon).
%>
%> For the eyelink we also allow the use of remote calibration and can call
%> a reward systems during calibration / validation to improve subject
%> performance compared to the eyelink toolbox alone.
%>
%> @todo refactor this and tobiiManager to inherit from a common eyelinkManager
%> 
%> Copyright ©2014-2022 Ian Max Andolina — released: LGPL3, see LICENCE.md
% ========================================================================
classdef eyelinkManager < eyetrackerCore
	
	properties
		%> tracker update speed (Hz), should be 250 500 1000 2000
		sampleRate double			= 1000
		%> calibration style, [H3 HV3 HV5 HV8 HV13]
		calibrationStyle char		= 'HV5'
		%> proportion of screen used in horizontal and vertical co-ordinates
		%> for calibration and validation, e.g. [0.3 0.3]
		calibrationProportion double= []
		%> eyetracker defaults structure
		defaults struct				= struct()
		%> IP address of host
		IP char						= ''
		% use callbacks
		enableCallbacks logical		= true
		%> cutom calibration callback (enables better handling of
		%> calibration, can trigger reward system etc.)
		callback char				= 'eyelinkCustomCallback'
		%> eyelink defaults modifiers as a struct()
		modify struct				= struct('calibrationtargetcolour',[1 1 1],...
									'calibrationtargetsize',2,'calibrationtargetwidth',0.1,...
									'displayCalResults',1,'targetbeep',1,'devicenumber',-1,...
									'waitformodereadytime',500)
	end
	
	properties (Hidden = true)
		%> verbosity level
		verbosityLevel double		= 4
		%> force drift correction?
		forceDriftCorrect logical	= true
		%> drift correct max
		driftMaximum double			= 15
		%> custom calibration target
		customTarget				= []
		%> compatibility with tobii which can use a second screen
		secondScreen				= false
	end
	
	properties (SetAccess = protected, GetAccess = public)
		%> Gaze X position in degrees
		x							= []
		%> Gaze Y position in degrees
		y							= []
		%> pupil size
		pupil						= []
		%> last isFixated true/false result
		isFix						= false
		%> did the fixInit test fail or not?
		isInitFail					= false
		%> are we in a blink?
		isBlink						= false
		%> are we in an exclusion zone?
		isExclusion					= false
		%> total time searching and holding fixation
		fixTotal					= 0
		%> Initiate fixation length
		fixInitLength				= 0
		%how long have we been fixated?
		fixLength					= 0
		%> Initiate fixation time
		fixInitStartTime			= 0
		%the first timestamp fixation was true
		fixStartTime				= 0
		%> which fixation window matched the last fixation?
		fixWindow					= 0
		%> last time offset betweeen tracker and display computers
		currentOffset				= 0
		%> tracker time stamp
		trackerTime					= 0
		%current sample taken from eyelink
		currentSample				= []
		%current event taken from eyelink
		currentEvent				= []
		% are we connected to eyelink?
		isConnected logical			= false
		% are we recording to an EDF file?
		isRecording logical			= false
		% which eye is the tracker using?
		eyeUsed						= -1
		%version of eyelink
		version						= ''
		%> the PTB screen to work on, passed in during initialise
		xAll						= []
		%> Last gaze Y position in degrees reset using resetFixation
		yAll						= []
		%> all pupil size reset using resetFixation
		pupilAll					= []
	end
	
	properties (SetAccess = protected, GetAccess = ?optickaCore)
		% value for missing data
		MISSING_DATA				= -32768
		%> the PTB screen handle, normally set by screenManager but can force it to use another screen
		win							= []
		ppd_ double					= 32
		tempFile char				= 'MYDATA.edf'
		% deals with strict fixation
		fixN double					= 0
		fixSelection				= []
		error						= []
		%> previous message sent to eyelink
		previousMessage char		= ''
	end
	
	methods
		% ===================================================================
		%> @brief This is the constructor for this class
		%>
		% ===================================================================
		function me = eyelinkManager(varargin)
			args = optickaCore.addDefaults(varargin,struct('name','eyelink manager'));
			me=me@eyetrackerCore(args); %we call the superclass constructor first
			me.parseArgs(args, me.allowedProperties);
			
			me.defaults = EyelinkInitDefaults();
			try % is eyelink interface working
				me.version = Eyelink('GetTrackerVersion');
			catch %#ok<CTCH>
				me.version = 0;
			end
		end
		
		% ===================================================================
		%> @brief initialise the eyelink, setting up the proper settings
		%> and opening the EDF file if me.recordData is true
		%>
		% ===================================================================
		function success = initialise(me,sM)
			success = false;
			if ~exist('sM','var')
				warning('Cannot initialise without a PTB screen')
				return
			end
			
			if ~me.isDummy
				try
					Eyelink('Shutdown'); %just make sure link is closed
				catch ME
					getReport(ME)
					warning('Problems with Eyelink initialise, make sure you install Eyelink Developer libraries!');
					me.isDummy = true;
				end
			end
			me.screen = sM;
			
			if ~isempty(me.IP) && ~me.isDummy
				me.salutation('Eyelink Initialise',['Trying to set custom IP address: ' me.IP],true)
				ret = Eyelink('SetAddress', me.IP);
				if ret ~= 0
					warning('!!!--> Couldn''t set IP address to %s!!!\n',me.IP);
				end
			end
			
			if ~isempty(me.callback) && me.enableCallbacks
				[res,dummy] = EyelinkInit(me.isDummy,me.callback);
			elseif me.enableCallbacks
				[res,dummy] = EyelinkInit(me.isDummy,1);
			else
				[res,dummy] = EyelinkInit(me.isDummy,0);
			end
			me.isDummy = logical(dummy);
			me.checkConnection();
			if ~me.isConnected && ~me.isDummy
				me.salutation('Eyelink Initialise','Could not connect, or enter Dummy mode...',true)
				return
			end
			
			if me.screen.isOpen == true 
				me.win = me.screen.win;
				me.defaults = EyelinkInitDefaults(me.win);
			elseif ~isempty(me.win)
				me.defaults = EyelinkInitDefaults(me.win);
			else
				me.defaults = EyelinkInitDefaults();
			end
			
			me.defaults.winRect=me.screen.winRect;
			% this command is sent from EyelinkInitDefaults
 			% Eyelink('Command', 'screen_pixel_coords = %ld %ld %ld %ld',me.screen.winRect(1),me.screen.winRect(2),me.screen.winRect(3)-1,me.screen.winRect(4)-1);
			if ~isempty(me.callback) && exist(me.callback,'file')
				me.defaults.callback = me.callback;
			end
			me.defaults.backgroundcolour = me.screen.backgroundColour;
			me.ppd_ = me.screen.ppd;
			me.defaults.ppd = me.screen.ppd;
			
			%structure of eyelink modifiers
			fn = fieldnames(me.modify);
			for i = 1:length(fn)
				if isfield(me.defaults,fn{i})
					me.defaults.(fn{i}) = me.modify.(fn{i});
				end
			end
			
			me.defaults.verbose = me.verbose;
			
			if ~isempty(me.customTarget)
				me.customTarget.reset();
				me.customTarget.setup(me.screen);
				me.defaults.customTarget = me.customTarget;
			else
				me.defaults.customTarget = [];
			end
			
			updateDefaults(me);
			
			if me.isDummy
				me.version = 'Dummy Eyelink';
			else
				[~, me.version] = Eyelink('GetTrackerVersion');
			end
			getTrackerTime(me);
			getTimeOffset(me);
			me.salutation('Initialise Method', sprintf('Running on a %s @ %2.5g (time offset: %2.5g)', me.version, me.trackerTime,me.currentOffset),true);
			% try to open file to record data to
			if me.isConnected 
				if me.recordData
					err = Eyelink('Openfile', me.tempFile);
					if err ~= 0
						warning('eyelinkManager Cannot setup Eyelink data file, aborting data recording');
						me.isRecording = false;
					else
						Eyelink('Command', ['add_file_preamble_text ''Recorded by:' me.fullName ' tracker'''],true);
						me.isRecording = true;
					end
				end
				Eyelink('Message', 'DISPLAY_COORDS %ld %ld %ld %ld',me.screen.winRect(1),me.screen.winRect(2),me.screen.winRect(3)-1,me.screen.winRect(4)-1);
				Eyelink('Message', 'FRAMERATE %ld',round(me.screen.screenVals.fps));
				Eyelink('Message', 'DISPLAY_PPD %ld', round(me.ppd_));
				Eyelink('Message', 'DISPLAY_DISTANCE %ld', round(me.screen.distance));
				Eyelink('Message', 'DISPLAY_PIXELSPERCM %ld', round(me.screen.pixelsPerCm));
				Eyelink('Command', 'link_event_filter = LEFT,RIGHT,FIXATION,SACCADE,BLINK,MESSAGE,BUTTON');
				Eyelink('Command', 'link_sample_data  = LEFT,RIGHT,GAZE,GAZERES,AREA,STATUS');
				Eyelink('Command', 'file_event_filter = LEFT,RIGHT,FIXATION,SACCADE,BLINK,MESSAGE,BUTTON');
				Eyelink('Command', 'file_sample_data  = LEFT,RIGHT,GAZE,HREF,AREA,GAZERES,STATUS');
				%Eyelink('Command', 'use_ellipse_fitter = no');
				Eyelink('Command', 'sample_rate = %d',me.sampleRate);
			end
		end
		
		% ===================================================================
		%> @brief
		%>
		% ===================================================================
		function updateDefaults(me)
			EyelinkUpdateDefaults(me.defaults);
		end
		
		% ===================================================================
		%> @brief check the connection with the eyelink
		%>
		% ===================================================================
		function connected = checkConnection(me)
			isc = Eyelink('IsConnected');
			if isc == 1
				me.isConnected = true;
			elseif isc == -1
				me.isConnected = false;
				me.isDummy = true;
			else
				me.isConnected = false;
			end
			connected = me.isConnected;
		end
		
		% ===================================================================
		%> @brief sets up the calibration and validation
		%>
		% ===================================================================
		function trackerSetup(me)
			if ~me.isConnected; return; end
			oldrk = RestrictKeysForKbCheck([]); %just in case someone has restricted keys
			fprintf('\n===>>> CALIBRATING EYELINK... <<<===\n');
			Eyelink('Verbosity',me.verbosityLevel);
			if ~isempty(me.calibrationProportion) && length(me.calibrationProportion)==2
				Eyelink('Command','calibration_area_proportion = %s', num2str(me.calibrationProportion));
				Eyelink('Command','validation_area_proportion = %s', num2str(me.calibrationProportion));
				% see https://www.sr-support.com/forum-37-page-2.html
				%Eyelink('Command','calibration_corner_scaling = %s', num2str([me.calibrationProportion(1)-0.1 me.calibrationProportion(2)-0.1])-);
				%Eyelink('Command','validation_corner_scaling = %s', num2str([me.calibrationProportion(1)-0.1 me.calibrationProportion(2)-0.1]));
			end
			Eyelink('Command','horizontal_target_y = %i',me.screen.winRect(4)/2);
			Eyelink('Command','calibration_type = %s', me.calibrationStyle);
			Eyelink('Command','normal_click_dcorr = ON');
			Eyelink('Command', 'driftcorrect_cr_disable = OFF');
			Eyelink('Command', 'drift_correction_rpt_error = 10.0');
			Eyelink('Command', 'online_dcorr_maxangle = 15.0');
			Eyelink('Command','randomize_calibration_order = NO');
			Eyelink('Command','randomize_validation_order = NO');
			Eyelink('Command','cal_repeat_first_target = YES');
			Eyelink('Command','val_repeat_first_target = YES');
			Eyelink('Command','validation_online_fixup  = NO');
			Eyelink('Command','generate_default_targets = YES');
			if me.remoteCalibration
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
				Eyelink('Command','key_function ins ''remote_cal_complete''');
				fprintf('\n===>>> REMOTE CALIBRATION ENABLED: 1-9 show point, space to choose point.\nINS key ON EYELINK == accept calibration!!!\n');
			else
				Eyelink('Command','remote_cal_enable = 0');
			end
			if ~isdeployed; commandwindow; end
			EyelinkDoTrackerSetup(me.defaults);
			if ~isempty(me.screen) && me.screen.isOpen
				Screen('Flip',me.screen.win);
			end
			[result,out] = Eyelink('CalMessage');
			fprintf('-+-+-> CAL RESULT =  %.2f | message: %s\n\n',result,out);
			RestrictKeysForKbCheck(oldrk);
			checkEye(me);
		end
		
		% ===================================================================
		%> @brief wrapper for StartRecording
		%>
		% ===================================================================
		function startRecording(me,~)
			if me.isConnected
				Eyelink('StartRecording');
				checkEye(me);
			end
		end
		
		% ===================================================================
		%> @brief wrapper for StopRecording
		%>
		% ===================================================================
		function stopRecording(me,~)
			if me.isConnected
				Eyelink('StopRecording');
			end
		end
		
		% ===================================================================
		%> @brief set into offline / idle mode
		%>
		% ===================================================================
		function setOffline(me)
			if me.isConnected
				Eyelink('Command', 'set_idle_mode');
			end
		end
		
		% ===================================================================
		%> @brief wrapper for EyelinkDoDriftCorrection
		%>
		% ===================================================================
		function success = driftCorrection(me)
			success = false;
			x=me.toPixels(me.fixation.X,'x'); %#ok<*PROPLC>
			y=me.toPixels(me.fixation.Y,'y');
			if me.isConnected
				resetOffset(me);
				Eyelink('Command', 'driftcorrect_cr_disable = OFF');
				Eyelink('Command', 'drift_correction_rpt_error = 10.0');
				Eyelink('Command', 'online_dcorr_maxangle = 15.0');
				Screen('DrawText',me.screen.win,'Drift Correction...',10,10);
				Screen('gluDisk',me.screen.win,[1 0 1 0.5],x,y,8);
				Screen('Flip',me.screen.win);
				WaitSecs('YieldSecs',0.2);
				success = EyelinkDoDriftCorrection(me.defaults, round(x), round(y), 1, 1);
				[result,out] = Eyelink('CalMessage');
				fprintf('DriftCorrect @ %.2f/%.2f px (%.2f/%.2f deg): result = %i msg = %s\n',...
					x,y, me.fixation.X, me.fixation.Y,result,out);
				if success ~= 0
					me.salutation('Drift Correct','FAILED',true);
				end
				if me.forceDriftCorrect
					res=Eyelink('ApplyDriftCorr');
					[result,out] = Eyelink('CalMessage');
					me.salutation('Drift Correct',sprintf('Results: %f %i %s\n',res,result,out),true);
				end
			end
			WaitSecs('YieldSecs',1);
		end

		
		% ===================================================================
		function error = checkRecording(me)
		%> @fn checkRecording
		%> Wrapper for CheckRecording
		%>
		% ===================================================================
			if me.isConnected
				error=Eyelink('CheckRecording');
			else
				error = -1;
			end
		end
		
		% ===================================================================
		function sample = getSample(me)
		%> @fn getSample
		%> Get a sample from the tracker, if dummymode=true then use
		%> the mouse as an eye signal
		%>
		% ===================================================================
			if me.isConnected && Eyelink('NewFloatSampleAvailable') > 0
				me.currentSample = Eyelink('NewestFloatSample');% get the sample in the form of an event structure
				if ~isempty(me.currentSample) && isstruct(me.currentSample)
					if me.currentSample.gx(me.eyeUsed+1) == me.MISSING_DATA ...
					&& me.currentSample.gy(me.eyeUsed+1) == me.MISSING_DATA ...
					&& me.currentSample.pa(me.eyeUsed+1) == 0 ...
					&& me.ignoreBlinks
						%me.x = toPixels(me,me.fixation.X,'x');
						%me.y = toPixels(me,me.fixation.Y,'y');
						me.pupil = 0;
						me.isBlink = true;
					else
						me.x = me.currentSample.gx(me.eyeUsed+1); % +1 as we're accessing MATLAB array
						me.y = me.currentSample.gy(me.eyeUsed+1);
						me.pupil = me.currentSample.pa(me.eyeUsed+1);
						me.xAll = [me.xAll me.x];
						me.yAll = [me.yAll me.y];
						me.pupilAll = [me.pupilAll me.pupil];
						me.isBlink = false;
					end
					%if me.verbose;fprintf('<GS X: %.2g | Y: %.2g | P: %.2g | isBlink: %i>\n',me.x,me.y,me.pupil,me.isBlink);end
				end
			elseif me.isDummy %lets use a mouse to simulate the eye signal
				if ~isempty(me.win)
					[me.x, me.y] = GetMouse(me.win);
				elseif ~isempty(me.screen) && ~isempty(me.screen.screen)
					[me.x, me.y] = GetMouse(me.screen.screen);
				else
					[me.x, me.y] = GetMouse();
				end
				me.pupil = 800 + randi(20);
				me.currentSample.gx = me.x;
				me.currentSample.gy = me.y;
				me.currentSample.pa = me.pupil;
				me.currentSample.time = GetSecs * 1000;
				me.xAll = [me.xAll me.x];
				me.yAll = [me.yAll me.y];
				me.pupilAll = [me.pupilAll me.pupil];
				%if me.verbose;fprintf('<DM X: %.2f | Y: %.2f | P: %.2f | T: %f>\n',me.x,me.y,me.pupil,me.currentSample.time);end
			end
			sample = me.currentSample;
		end
		
		% ===================================================================
		%> @brief checks which eye is available, force left eye if
		%> binocular is enabled
		%>
		% ===================================================================
		function eyeUsed = checkEye(me)
			if me.isConnected
				me.eyeUsed = Eyelink('EyeAvailable'); % get eye that's tracked
				if me.eyeUsed == me.defaults.BINOCULAR % if both eyes are tracked
					me.eyeUsed = me.defaults.LEFT_EYE; % use left eye
				end
				eyeUsed = me.eyeUsed;
			else
				me.eyeUsed = -1;
				eyeUsed = me.eyeUsed;
			end
		end
		
		% ===================================================================
		%> @brief displays status message on tracker, only sets it if
		%> message is not the previous message, so loop safe.
		%>
		% ===================================================================
		function statusMessage(me,message)
			if ~strcmpi(message,me.previousMessage) && me.isConnected
				me.previousMessage = message;
				Eyelink('Command',['record_status_message ''' message '''']);
				if me.verbose; fprintf('-+-+-> Eyelink status message: %s\n',message);end
			end
		end
		
		% ===================================================================
		%> @brief send message to store in EDF data
		%>
		%>
		% ===================================================================
		function trackerMessage(me, message, varargin)
			if me.isConnected
				Eyelink('Message', message );
				if me.verbose; fprintf('-+-+-> EDF Message: %s\n',message);end
			end
		end
		
		% ===================================================================
		%> @brief close the eyelink and cleanup, send EDF file if recording
		%> is enabled
		%>
		% ===================================================================
		function close(me)
			try
				me.isConnected = false;
				%me.isDummy = false;
				me.eyeUsed = -1;
				me.screen = [];
				trackerClearScreen(me);
				if me.isRecording == true && ~isempty(me.saveFile)
					Eyelink('StopRecording');
					Eyelink('CloseFile');
					try
						me.salutation('Close Method',sprintf('Receiving data file %s', me.tempFile),true);
						status=Eyelink('ReceiveFile');
						if status > 0
							me.salutation('Close Method',sprintf('ReceiveFile status %d', status));
						end
						if exist(me.tempFile, 'file')
							me.salutation('Close Method',sprintf('Data file ''%s'' can be found in ''%s''', me.tempFile, strrep(pwd,'\','/')),true);
							status = movefile(me.tempFile, me.saveFile,'f');
							if status == 1
								me.salutation('Close Method',sprintf('Data file copied to ''%s''', me.saveFile),true);
								trackerDrawText(me,sprintf('Data file copied to ''%s''', me.saveFile));
							end
						end
					catch ME
						me.salutation('Close Method',sprintf('Problem receiving data file ''%s''', me.tempFile),true);
						disp(ME.message);
					end
				end
			catch ME
				me.salutation('Close Method','Couldn''t stop recording, forcing shutdown...',true)
				trackerClearScreen(me);
				Eyelink('Shutdown');
				me.error = ME;
				me.salutation(ME.message);
			end
			Eyelink('Shutdown');
			me.isConnected = false;
			me.isRecording = false;
			me.eyeUsed = -1;
			me.screen = [];
		end
		
		% ===================================================================
		%> @brief draw the background colour
		%>
		% ===================================================================
		function trackerClearScreen(me)
			if ~me.isConnected; return; end
			Eyelink('Command', 'clear_screen 0');
		end

		% ===================================================================
		%> @brief draw general status
		%>
		% ===================================================================
		function trackerDrawStatus(me, comment, ts, dontClear)
			if ~me.isConnected; return; end
			if ~exist('comment','var'); comment=''; end
			if ~exist('ts','var'); ts = []; end
			if ~exist('dontClear','var');dontClear = false; end
			if dontClear==false; trackerClearScreen(me); end
			trackerDrawExclusion(me);
			trackerDrawFixation(me);
			if ~isempty(ts);trackerDrawStimuli(me, ts);end
			if ~isempty(comment);trackerDrawText(me, comment);end
		end
		
		% ===================================================================
		%> @brief draw the stimuli boxes on the tracker display
		%>
		% ===================================================================
		function trackerDrawStimuli(me, ts, dontClear, convertToPixels)
			if ~me.isConnected; return; end
			if exist('ts','var') && isstruct(ts) && ~isempty(fields(ts))
				me.stimulusPositions = ts;
			else
				return
			end
			if ~exist('dontClear','var')
				dontClear = true;
			end
			if ~exist('convertToPixels','var')
				convertToPixels = false;
			end
			if dontClear==false; Eyelink('Command', 'clear_screen 0'); end
			for i = 1:length(me.stimulusPositions)
				x = me.stimulusPositions(i).x; 
				y = me.stimulusPositions(i).y; 
				size = me.stimulusPositions(i).size;
				if isempty(size); size = 1; end
				rect = [0 0 size size];
				rect = CenterRectOnPoint(rect, x, y); 
				if convertToPixels; rect = toPixels(me, rect,'rect'); end
				rect = round(rect);
				if me.stimulusPositions(i).selected == true
					Eyelink('Command', 'draw_box %d %d %d %d 10', rect(1), rect(2), rect(3), rect(4));
				else
					Eyelink('Command', 'draw_box %d %d %d %d 11', rect(1), rect(2), rect(3), rect(4));
				end
			end			
		end
		
		% ===================================================================
		%> @brief draw the fixation box on the tracker display
		%>
		% ===================================================================
		function trackerDrawFixation(me)
			if ~me.isConnected; return; end
			size = me.fixation.radius * 2;
			rect = [0 0 size size];
			for i = 1:length(me.fixation.X)
				nrect = CenterRectOnPoint(rect, me.fixation.X(i), me.fixation.Y(i));
				nrect = round(toPixels(me, nrect, 'rect'));
				Eyelink('Command', 'draw_filled_box %d %d %d %d 10', nrect(1), nrect(2), nrect(3), nrect(4));
			end
		end
		
		% ===================================================================
		%> @brief draw the fixation box on the tracker display
		%>
		% ===================================================================
		function trackerDrawExclusion(me)
			if ~me.isConnected; return; end
			if ~isempty(me.exclusionZone) && size(me.exclusionZone,2)==4
				for i = 1:size(me.exclusionZone,1)
					rect = round(toPixels(me, me.exclusionZone(i,:)));
					% exclusion zone is [-degX +degX -degY +degY], but rect is left,top,right,bottom
					Eyelink('Command', 'draw_box %d %d %d %d 12', rect(1), rect(3), rect(2), rect(4));
				end
			end
		end
		
		% ===================================================================
		%> @brief draw the fixation box on the tracker display
		%>
		% ===================================================================
		function trackerDrawText(me,textIn)
			if ~me.isConnected; return; end
			if exist('textIn','var') && ~isempty(textIn)
				xDraw = toPixels(me, 0, 'x');
				yDraw = toPixels(me, 0, 'y');
				Eyelink('Command', 'draw_text %i %i %d %s', xDraw, yDraw, 3, textIn);
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
		function mode = currentMode(me)
			if me.isConnected
				mode = Eyelink('CurrentMode');
			else
				mode = -100;
			end
		end
		
		% ===================================================================
		%> @brief Sync time message for EDF file
		%>
		% ===================================================================
		function syncTime(me)
			if ~me.isConnected; return; end
			Eyelink('Message', 'SYNCTIME');		%zero-plot time for EDFVIEW
		end
		
		% ===================================================================
		%> @brief Get offset between tracker and display computers
		%>
		% ===================================================================
		function offset = getTimeOffset(me)
			if me.isConnected
				offset = Eyelink('TimeOffset');
				me.currentOffset = offset;
			else
				offset = 0;
			end
		end
		
		% ===================================================================
		%> @brief Get offset between tracker and display computers
		%>
		% ===================================================================
		function time = getTrackerTime(me)
			if me.isConnected
				time = Eyelink('TrackerTime');
				me.trackerTime = time;
			else
				time = 0;
			end
		end
		
		% ===================================================================
		%> @brief automagically turn pixels to degrees
		%>
		% ===================================================================
		function set.x(me,in)
			me.x = toDegrees(me,in,'x'); %#ok<*MCSUP>
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
		function runDemo(me,forcescreen)
			KbName('UnifyKeyNames')
			stopkey				= KbName('Q');
			nextKey				= KbName('SPACE');
			calibkey			= KbName('C');
			driftkey			= KbName('D');
			offsetkey			= KbName('O');
			oldx				= me.fixation.X;
			oldy				= me.fixation.Y;
			oldexc				= me.exclusionZone;
			oldfixinit			= me.fixInit;
			me.recordData		= true; %lets save an EDF file
			%set up a figure to plot eye position
			figure;plot(0,0,'ro');ax=gca;hold on;xlim([-20 20]);ylim([-20 20]);set(ax,'YDir','reverse');
			title('eyelinkManager Demo');xlabel('X eye position (deg)');ylabel('Y eye position (deg)');grid on;grid minor;drawnow;
			% DEMO EXPERIMENT:
			try
				%open screen manager and dots stimulus
				s = screenManager('debug',true,'pixelsPerCm',27,'distance',66);
				if exist('forcescreen','var'); s.screen = forcescreen; end
				s.backgroundColour = [0.5 0.5 0.5 0]; %s.windowed = [0 0 900 900];
				o = dotsStimulus('size',me.fixation.radius(1)*2,'speed',2,'mask',true,'density',50); %test stimulus
				open(s); % open our screen
				setup(o,s); % setup our stimulus with our screen object
				
				initialise(me,s); % initialise eyelink with our screen
				if ~me.isDummy && ~me.isConnected
					reset(o);
					close(s);
					error('Could not connect to Eyelink or use Dummy mode...')
				end
				%ListenChar(-1); % capture the keyboard settings
				setup(me); % setup + calibrate the eyelink
				
				% define our fixation widow and stimulus for first trial
				% x,y,inittime,fixtime,radius,strict
				me.updateFixationValues([0 -10],[0 -10],3,1,1,true);
				o.sizeOut = me.fixation.radius(1)*2;
				o.xPositionOut = me.fixation.X;
				o.yPositionOut = me.fixation.Y;
				ts.x = me.fixation.X; %ts is a simple structure that we can pass to eyelink to draw on its screen
				ts.y = me.fixation.Y;
				ts.size = o.sizeOut;
				ts.selected = true;
				
				% setup an exclusion zone where eye is not allowed
				me.exclusionZone = [8 15 10 15];
				exc = me.toPixels(me.exclusionZone);
				exc = [exc(1) exc(3) exc(2) exc(4)]; %psychrect=[left,top,right,bottom] 
				
				setOffline(me); %Eyelink('Command', 'set_idle_mode');
				trackerClearScreen(me); % clear eyelink screen
				trackerDrawFixation(me); % draw fixation window on tracker
				trackerDrawStimuli(me,ts); % draw stimulus on tracker
				
				Screen('TextSize', s.win, 18);
				HideCursor(s.win);
				Priority(MaxPriority(s.win));
				blockLoop = true;
				a = 1;
				
				while blockLoop
					% some general variables
					trialLoop = true;
					b = 1;
					xst = [];
					yst = [];
					correct = false;
					% !!! these messages define the trail start in the EDF for
					% offline analysis
					edfMessage(me,'V_RT MESSAGE END_FIX END_RT');
					edfMessage(me,['TRIALID ' num2str(a)]);
					% start the eyelink recording data for this trail
					startRecording(me);
					% this draws the text to the tracker info box
					statusMessage(me,sprintf('DEMO Running Trial=%i X Pos = %g | Y Pos = %g | Radius = %g',a,me.fixation.X,me.fixation.Y,me.fixation.radius));
					WaitSecs('YieldSecs',0.25);
					vbl=flip(s);
					syncTime(me);
					while trialLoop
						Screen('FillRect',s.win,[0.7 0.7 0.7 0.5],exc); Screen('DrawText',s.win,'Exclusion Zone',exc(1),exc(2),[0.8 0.8 0.8]);
						drawSpot(s,me.fixation.radius,[0.5 0.6 0.5 0.25],me.fixation.X,me.fixation.Y);
						drawCross(s,0.5,[1 1 0.5],me.fixation.X,me.fixation.Y);
						draw(o);
						drawGrid(s);
						drawScreenCenter(s);
						
						% get the current eye position and save x and y for local
						% plotting
						getSample(me); xst(b)=me.x - me.offset.X; yst(b)=me.y - me.offset.Y;
						
						% if we have an eye position, plot the info on the display
						% screen
						if ~isempty(me.currentSample)
							[~, ~, searching, window, exclusion, fixinit] = isFixated(me);
							x = me.toPixels(me.x - me.offset.X,'x'); %#ok<*PROP>
							y = me.toPixels(me.y - me.offset.Y,'y');
							txt = sprintf('Q = finish, SPACE = next. X = %3.1f / %2.2f | Y = %3.1f / %2.2f | RADIUS = %s | TIME = %.1f | FIX = %.1f | WIN = %i | SEARCH = %i | BLINK = %i | EXCLUSION = %i | FAIL-INIT = %i',...
								x, me.x - me.offset.X, y, me.y - me.offset.Y, sprintf('%1.1f ',me.fixation.radius), ...
								me.fixTotal, me.fixLength, window, searching, me.isBlink, exclusion, fixinit);
							Screen('DrawText', s.win, txt, 10, 10,[1 1 1]);
							drawEyePosition(me);
						end
						
						% tell PTB we've finished drawing
						finishDrawing(s);
						% animate out stimulus
						animate(o);
						% flip the screen
						vbl=Screen('Flip',s.win, vbl + s.screenVals.halfisi);
						
						% check the keyboard
						   [~, ~, keyCode] = KbCheck(-1);
						if keyCode(stopkey); trialLoop = 0; blockLoop = 0; break;	end
						if keyCode(nextKey); trialLoop = 0; correct = true; break; end
						if keyCode(calibkey); trackerSetup(me); break; end
						if keyCode(driftkey); driftCorrection(me); break; end
						if keyCode(offsetkey); driftOffset(me); break; end
						% send a message for the EDF after 60 frames
						if b == 60; edfMessage(me,'END_FIX');end
						b=b+1;
					end
					% tell EDF end of reaction time portion
					edfMessage(me,'END_RT');
					if correct
						edfMessage(me,'TRIAL_RESULT 1');
					else
						edfMessage(me,'TRIAL_RESULT 0');
					end
					% stop recording data
					stopRecording(me);
					setOffline(me); %Eyelink('Command', 'set_idle_mode');
					resetFixation(me);

					% set up the fix init system, whereby the subject must
					% remain a certain time at the origin of the eye
					% position before saccading to next target, use previous fixation location.
					%me.fixInit.X = me.fixation.X;
					%me.fixInit.Y = me.fixation.Y;
					%me.fixInit.time = 0.1;
					%me.fixInit.radius = 3;
					
					% prepare a random position for next trial
					me.updateFixationValues([randi([-5 5]) -10],[randi([-5 5]) -10],[],[],randi([1 5]));
					o.sizeOut = me.fixation.radius*2;
					%me.fixation.radius = [me.fixation.radius me.fixation.radius];
					o.xPositionOut = me.fixation.X(1);
					o.yPositionOut = me.fixation.Y(1);
					update(o);
					% use this struct for the parameters to draw stimulus
					% to screen
					ts.x = me.fixation.X(1);
					ts.y = me.fixation.Y(1);
					ts.size = me.fixation.radius;
					ts.selected = true;
					% clear tracker display
					trackerDrawStimuli(me,ts,true);
					trackerDrawFixation(me);
					% plot eye position for last trial and ITI
					plot(ax,xst,yst);drawnow;
					while GetSecs <= vbl + 1
						% check the keyboard
						[~, ~, keyCode] = KbCheck(-1);
						if keyCode(calibkey); trackerSetup(me); break; end
						if keyCode(driftkey); driftCorrection(me); break; end
						if keyCode(offsetkey); driftOffset(me); break; end
					end
					a=a+1;
				end
				% clear tracker display
				trackerClearScreen(me);
				trackerDrawText(me,'FINISHED eyelinkManager Demo!!!');
				ListenChar(0);Priority(0);ShowCursor;RestrictKeysForKbCheck([])
				close(s);
				close(me);
				clear s o
				if ~me.isDummy
					an = questdlg('Do you want to load the data and plot it?');
					if strcmpi(an,'yes')
						if ~isdeployed; commandwindow; end
						evalin('base',['eA=eyelinkAnalysis(''dir'',''' ...
							me.paths.savedData ''', ''file'',''myData.edf'');eA.parseSimple;eA.plot']);
					end
				end
				me.resetFixation;
				me.resetOffset;
				me.fixation.X = oldx;
				me.fixation.Y = oldy;
				me.exclusionZone = oldexc;
				me.fixInit = oldfixinit;
			catch ME
				me.fixation.X = oldx;
				me.fixation.Y = oldy;
				me.exclusionZone = oldexc;
				me.fixInit = oldfixinit;
				me.resetFixation;
				me.resetOffset;
				ListenChar(0);Priority(0);ShowCursor;RestrictKeysForKbCheck([])
				me.salutation('runDemo ERROR!!!')
				Eyelink('Shutdown');
				try close(s); end
				sca;
				try close(me); end
				clear s o
				me.error = ME;
				me.salutation(ME.message);
				rethrow(ME);
			end
			
		end
		
	end%-------------------------END PUBLIC METHODS--------------------------------%
	
	%=======================================================================
	methods (Hidden = true) %------------------HIDDEN METHODS
	%=======================================================================
	
		% ===================================================================
		%> @brief TODO
		%>
		% ===================================================================
		function evt = getEvent(me)
			
		end

		% ===================================================================
		%> @brief compatibility with tobiiManager
		%>
		% ===================================================================
		function saveData(me,args)
			
		end
		
		% ===================================================================
		%> @brief send message to store in EDF data
		%>
		%>
		% ===================================================================
		function edfMessage(me, message)
			if me.isConnected
				Eyelink('Message', message );
				if me.verbose; fprintf('-+-+->EDF Message: %s\n',message);end
			end
		end

		function trackerFlip(me, varargin)

		end

		function trackerDrawEyePosition(me)

		end

		function trackerDrawEyePositions(me)

		end
		
	
	end
	
	
	%=======================================================================
	methods (Access = private) %------------------PRIVATE METHODS
	%=======================================================================
		
	end
end


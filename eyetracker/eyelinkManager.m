% ========================================================================
classdef eyelinkManager < eyetrackerCore
%> @class eyelinkManager
%> @brief eyelinkManager wraps around the eyelink toolbox functions offering a
%> consistent interface and methods for fixation window control. See
%> eyetrackerCore for the common methods that handle fixation windows etc.
%> 
%> Copyright ©2014-2023 Ian Max Andolina — released: LGPL3, see LICENCE.md
% ========================================================================

	%-----------------CONTROLLED PROPERTIES-------------%
	properties (SetAccess = protected, GetAccess = public)
		%> type of eyetracker
		type				= 'eyelink'
	end
	
	%---------------PUBLIC PROPERTIES---------------%
	properties
		%> properties to setup and modify calibration
		calibration			= struct( ...
							'style','HV9', ...
							'proportion',[0.6 0.6], ...
							'manual',false, ...
							'paceDuration',1000, ...
							'IP','', ...
							'eyeUsed', 0, ...
							'enableCallbacks', true, ...
							'callback', 'eyelinkCustomCallback', ...
							'devicenumber', [], ...
							'targetbeep', 1, ...
							'feedbackbeep', 1, ...
							'calibrationtargetsize', 3, ...
							'calibrationtargetwidth', 1, ...
							'calibrationtargetcolour', [1 1 1])
		%> eyetracker defaults structure
		defaults			= struct()
	end
	
	%---------------HIDDEN PROPERTIES---------------%
	properties (Hidden = true)
		%> verbosity level
		verbosityLevel		= 4
		%> force drift correction?
		forceDriftCorrect	= true
		%> drift correct max
		driftMaximum		= 15
		%> custom calibration target
		customTarget		= []
	end
	
	%---------------SEMI-PROTECTED PROPERTIES----------%
	properties (SetAccess = protected, GetAccess = ?optickaCore)
		% value for missing data
		MISSING_DATA		= -32768
		tempFile			= 'eyeData'
		error				= []
		%> previous message sent to eyelink
		previousMessage		= ''
	end

	%--------------------PROTECTED PROPERTIES----------%
	properties (SetAccess = protected, GetAccess = protected)
		%> allowed properties passed to object upon construction
		allowedProperties	= {'calibration', 'defaults','verbosityLevel'}
	end
	
	%=======================================================================
	methods %------------------PUBLIC METHODS
	%=======================================================================

		% ===================================================================
		function me = eyelinkManager(varargin)
		%> @fn eyelinkManager(varargin)
		%> @brief This is the constructor for this class
		%>
		% ===================================================================
			args = optickaCore.addDefaults(varargin,struct('name','Eyelink','sampleRate',1000));
			me=me@eyetrackerCore(args); %we call the superclass constructor first
			me.parseArgs(args, me.allowedProperties);
			
			try % is eyelink interface working
				me.version = Eyelink('GetTrackerVersion');
			catch %#ok<CTCH>
				me.version = 0;
			end
			me.defaults = EyelinkInitDefaults();
		end
		
		% ===================================================================
		function success = initialise(me, sM)
		%> @fn initialise
		%> @brief initialise the eyelink with the screenManager object, setting
		%> up the calibration options and opening the EDF file if me.recordData
		%> is true.
		%>
		%> @param sM screenManager to link to
		% ===================================================================
			if me.isOff; me.isDummy = true; return; end
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
					uiwait(warndlg('Problems with Eyelink initialise, make sure you install Eyelink Developer libraries!','eyelinkManager','modal'));
					me.isDummy = true;
				end
			end
			me.screen = sM;
			
			if isfield(me.calibration,'IP') && ~isempty(me.calibration.IP) && ~me.isDummy
				me.salutation('Eyelink Initialise',['Trying to set custom IP address: ' me.calibration.IP],true)
				ret = Eyelink('SetAddress', me.calibration.IP);
				if ret ~= 0
					warning('!!!--> Couldn''t set IP address to %s!!!\n',me.calibration.IP);
				end
			end
			
			if me.screen.isOpen
				me.win = me.screen.win;
				me.defaults = EyelinkInitDefaults(me.win);
			else
				me.defaults = EyelinkInitDefaults();
			end
			
			if ~isempty(me.screen.winRect) && length(me.screen.winRect)==4
				me.defaults.winRect=me.screen.winRect;
			end
			
			if ~isempty(me.calibration.callback) && exist(me.calibration.callback,'file')
				me.defaults.callback = me.calibration.callback;
			end

			me.defaults.backgroundcolour = [me.screen.backgroundColour(1:3) 1];
			me.ppd_ = me.screen.ppd;
			me.defaults.ppd = me.screen.ppd;
			
			fn = fieldnames(me.calibration);
			for i = 1:length(fn)
				if isfield(me.defaults,fn{i})
					me.defaults.(fn{i}) = me.calibration.(fn{i});
				end
			end

			if me.defaults.targetbeep==1; me.defaults.feedbackbeep=1; end
			
			me.defaults.verbose = me.verbose;
			me.defaults.debugPrint = me.verbose;
			
			updateDefaults(me);

			if me.calibration.enableCallbacks
				[res,dummy] = EyelinkInit(me.isDummy, me.calibration.callback);
			else
				[res,dummy] = EyelinkInit(me.isDummy,0);
			end

			if ~res
				me.isConnected = false;
				me.isDummy = true;
			else
				me.isDummy = logical(dummy);
				me.checkConnection();
			end
			
			if me.isDummy
				me.version = 'Dummy Eyelink';
			else
				[~, me.version] = Eyelink('GetTrackerVersion');
				try
					[~,majorVersion]=regexp(me.version,'.*?(\d)\.\d*?','Match','Tokens');
					majorVersion = majorVersion{1}{1};
				catch
					majorVersion = 4;
				end
			end
			%getTrackerTime(me);
			%getTimeOffset(me);
			me.salutation('Initialise Method', sprintf('Running on a %s @ %2.5g (time offset: %2.5g)', me.version, me.trackerTime,me.currentOffset),true);
			% try to open file to record data to
			if me.isConnected 
				if me.recordData
					err = Eyelink('Openfile', me.tempFile);
					if err ~= 0
						me.isRecording = false;
						error('eyelinkManager Cannot setup Eyelink data file, aborting data recording'); %#ok<CPROPLC>
					else
						Eyelink('Command', ['add_file_preamble_text ''Recorded by:' me.fullName ' tracker'''],true);
						me.isRecording = true;
					end
				end
				Eyelink('Command', 'screen_pixel_coords = %ld %ld %ld %ld',me.screen.winRect(1),me.screen.winRect(2),me.screen.winRect(3)-1,me.screen.winRect(4)-1);
				Eyelink('Message', 'DISPLAY_COORDS %ld %ld %ld %ld',me.screen.winRect(1),me.screen.winRect(2),me.screen.winRect(3)-1,me.screen.winRect(4)-1);
				Eyelink('Message', 'FRAMERATE %ld',round(me.screen.screenVals.fps));
				Eyelink('Message', 'DISPLAY_PPD %ld', round(me.ppd_));
				Eyelink('Message', 'DISPLAY_DISTANCE %ld', round(me.screen.distance));
				Eyelink('Message', 'DISPLAY_PIXELSPERCM %ld', round(me.screen.pixelsPerCm));
				Eyelink('Command', 'link_event_filter = LEFT,RIGHT,FIXATION,SACCADE,BLINK,BUTTON,FIXUPDATE,INPUT');
				Eyelink('Command', 'file_event_filter = LEFT,RIGHT,FIXATION,SACCADE,BLINK,MESSAGE,BUTTON,INPUT');
				if majorVersion > 3  % Check tracker version and include 'HTARGET' to save head target sticker data for supported eye trackers
					Eyelink('Command', 'file_sample_data  = LEFT,RIGHT,GAZE,HREF,RAW,AREA,HTARGET,GAZERES,BUTTON,STATUS,INPUT');
					Eyelink('Command', 'link_sample_data  = LEFT,RIGHT,GAZE,GAZERES,AREA,HTARGET,STATUS,INPUT');
				else
					Eyelink('Command', 'file_sample_data  = LEFT,RIGHT,GAZE,HREF,RAW,AREA,GAZERES,BUTTON,STATUS,INPUT');
					Eyelink('Command', 'link_sample_data  = LEFT,RIGHT,GAZE,GAZERES,AREA,STATUS,INPUT');
				end
				Eyelink('Command', 'sample_rate = %d',me.sampleRate);
				Eyelink('Command', 'clear_screen 1')
			end
		   end
		
		% ===================================================================
		function updateDefaults(me)
		%> @fn updateDefaults
		%> @brief whenever you change me.defaults you should run this to update
		%> the eyelink toolbox
		%>
		% ===================================================================
			EyelinkUpdateDefaults(me.defaults);
		end
		
		% ===================================================================
		function connected = checkConnection(me)
		%> @fn checkConnection
		%> @brief check the connection with the eyelink is valid
		%>
		% ===================================================================
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
		function trackerSetup(me)
		%> @fn trackerSetup
		%> @brief runs the calibration and validation
		%>
		% ===================================================================
			[rM, aM] = initialiseGlobals(me);
			if me.calibration.enableCallbacks && contains(me.calibration.callback, 'eyelinkCustomCallback')
				try open(aM); end
				%Snd('Open', aM.aHandle, 1);
			end

			if isa(me.screen,'screenManager') && ~me.screen.isOpen; open(me.screen); end

			if ~me.isConnected || me.isOff; return; end
			oldrk = RestrictKeysForKbCheck([]); %just in case someone has restricted keys
			fprintf('\n===>>> CALIBRATING EYELINK... <<<===\n');
			Eyelink('Verbosity',me.verbosityLevel);
			if ~isempty(me.calibration.proportion) && length(me.calibration.proportion)==2
				Eyelink('Command','calibration_area_proportion = %s', num2str(me.calibration.proportion));
				Eyelink('Command','validation_area_proportion = %s', num2str(me.calibration.proportion));
				% see https://www.sr-support.com/forum-37-page-2.html
				%Eyelink('Command','calibration_corner_scaling = %s', num2str([me.calibrationProportion(1)-0.1 me.calibrationProportion(2)-0.1])-);
				%Eyelink('Command','validation_corner_scaling = %s', num2str([me.calibrationProportion(1)-0.1 me.calibrationProportion(2)-0.1]));
			end
			Eyelink('Command','screen_pixel_coords = %ld %ld %ld %ld',me.screen.winRect(1),me.screen.winRect(2),me.screen.winRect(3)-1,me.screen.winRect(4)-1);
			if me.calibration.eyeUsed == me.defaults.LEFT_EYE
				Eyelink('Command','active_eye = LEFT');
			elseif me.calibration.eyeUsed == me.defaults.RIGHT_EYE
				Eyelink('Command','active_eye = RIGHT');
			else
				Eyelink('Command','active_eye = LEFT');
			end
			%Eyelink('Command','horizontal_target_y = %i',round(me.screen.winRect(4)/2));
			Eyelink('Command','calibration_type = %s', me.calibration.style);
			Eyelink('Command','enable_automatic_calibration = YES');
			Eyelink('Command','automatic_calibration_pacing = %s',num2str(round(me.calibration.paceDuration)));
			%Eyelink('Command','normal_click_dcorr = ON');
			%Eyelink('Command','driftcorrect_cr_disable = OFF');
			%Eyelink('Command','drift_correction_rpt_error = 10.0');
			%Eyelink('Command','online_dcorr_maxangle = 15.0');
			%Eyelink('Command','randomize_calibration_order = NO');
			%Eyelink('Command','randomize_validation_order = NO');
			%Eyelink('Command','cal_repeat_first_target = YES');
			%Eyelink('Command','val_repeat_first_target = YES');
			%Eyelink('Command','validation_online_fixup  = NO');
			%Eyelink('Command','generate_default_targets = YES');
			if me.calibration.manual
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
		function startRecording(me,~)
		%> @brief wrapper for StartRecording
		%>
		% ===================================================================
			if me.isConnected
				Eyelink('StartRecording');
				checkEye(me);
			end
		end
		
		% ===================================================================
		function stopRecording(me,~)
		%> @brief wrapper for StopRecording
		%>
		% ===================================================================
			if me.isConnected
				Eyelink('StopRecording');
			end
		end
		
		% ===================================================================
		function setOffline(me)
		%> @brief set into offline / idle mode
		%>
		% ===================================================================
			if me.isConnected
				Eyelink('Command', 'set_idle_mode');
			end
		end
		
		% ===================================================================
		function success = driftCorrection(me)
		%> @brief wrapper for EyelinkDoDriftCorrection
		%>
		% ===================================================================
			oldrk = RestrictKeysForKbCheck([]); %just in case someone has restricted keys
			success = false;
			x=me.toPixels(me.fixation.X(1),'x'); %#ok<*PROPLC>
			y=me.toPixels(me.fixation.Y(1),'y');
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
					x,y, me.fixation.X(1), me.fixation.Y(1),result,out);
				if success ~= 0
					me.salutation('Drift Correct','FAILED',true);
				end
				if me.forceDriftCorrect
					res=Eyelink('ApplyDriftCorr');
					[result,out] = Eyelink('CalMessage');
					me.salutation('Drift Correct',sprintf('Results: %f %i %s\n',res,result,out),true);
				end
			end
			RestrictKeysForKbCheck(oldrk);
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
				sample = Eyelink('NewestFloatSample');% get the sample in the form of an event structure
				if ~isempty(sample) && isstruct(sample)
					sample.time = sample.time / 1e3;
					x = sample.gx(me.eyeUsed+1);
					y = sample.gy(me.eyeUsed+1);
					p = sample.pa(me.eyeUsed+1);
					if x == me.MISSING_DATA || y == me.MISSING_DATA
						me.x = NaN;
						me.y = NaN;
						sample.valid = false;
						me.pupil = NaN;
						me.xAll = [me.xAll me.x];
						me.yAll = [me.yAll me.y];
						me.pupilAll = [me.pupilAll me.pupil];
						me.isBlink = true;
					else
						sample.valid = true;
						xy = toDegrees(me, [x y]);
						me.x = xy(1); me.y = xy(2);
						me.pupil = p;
						me.xAll = [me.xAll me.x];
						me.yAll = [me.yAll me.y];
						me.pupilAll = [me.pupilAll me.pupil];
						me.isBlink = false;
					end
					if me.debug;fprintf('<GS X: %.2g | Y: %.2g | P: %.2g | isBlink: %i>\n',me.x,me.y,me.pupil,me.isBlink);end
				end
			else
				sample = getMouseSample(me);
			end
			me.currentSample = sample;
		end
		
		% ===================================================================
		function eyeUsed = checkEye(me)
		%> @brief checks which eye is available, force left eye if
		%> binocular is enabled
		%>
		% ===================================================================
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
		function statusMessage(me,message)
		%> @brief displays status message on tracker, only sets it if
		%> message is not the previous message, so loop safe.
		%>
		% ===================================================================
			if ~strcmpi(message,me.previousMessage) && me.isConnected
				me.previousMessage = message;
				Eyelink('Command',['record_status_message ''' message '''']);
				if me.verbose; fprintf('-+-+-> Eyelink status message: %s\n',message);end
			end
		end
		
		% ===================================================================
		function trackerMessage(me, message, varargin)
		%> @brief send message to store in EDF data
		%>
		%>
		% ===================================================================
			if me.isConnected
				Eyelink('Message', message );
				if me.verbose; fprintf('-+-+-> EDF Message: %s\n',message);end
			end
		end
		
		% ===================================================================
		function close(me)
		%> @brief close the eyelink and cleanup, send EDF file if recording
		%> is enabled
		%>
		% ===================================================================
			try
				me.isConnected = false;
				%me.isDummy = false;
				me.eyeUsed = -1;
				me.screen = [];
				try trackerClearScreen(me); end
				if me.isRecording == true
					Eyelink('StopRecording');
					Eyelink('CloseFile');
					oldp = pwd;
					try
						if isfield(me.paths,'alfPath') && exist(me.paths.alfPath,'dir')
							cd(me.paths.alfPath);
						else
							cd(me.paths.savedData);
						end
						me.salutation('Close Method',sprintf('Receiving data file %s.edf', me.tempFile),true);
						status=Eyelink('ReceiveFile');
						if status > 0
							me.salutation('Close Method',sprintf('ReceiveFile status %d', status));
						end
						if exist([me.tempFile '.edf'], 'file')
							me.salutation('Close Method',sprintf('Data file ''%s.edf'' can be found in ''%s''', me.tempFile, strrep(pwd,'\','/')),true);
							if ~contains(me.saveFile,'.edf'); me.saveFile = [me.saveFile '.edf']; end
							status = copyfile([me.tempFile '.edf'], me.saveFile, 'f');
							if status == 1
								me.salutation('Close Method',sprintf('Data file copied to ''%s''', me.saveFile),true);
							end
						end
					catch ME
						me.salutation('Close Method',sprintf('Problem receiving data file ''%s''', me.tempFile),true);
						warning('eyelinkManager.close(): EYELINK DATA NOT RECEIVED!')
						disp(ME.message);
					end
					cd(oldp);
				end
			catch ME
				me.salutation('Close Method','Couldn''t stop recording, forcing shutdown...',true)
				try trackerClearScreen(me); end
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
		function trackerClearScreen(me)
		%> @brief draw the background colour
		%>
		% ===================================================================
			if ~me.isConnected || me.isOff; return; end
			Eyelink('Command', 'clear_screen 1');
		end

		% ===================================================================
		function trackerDrawStatus(me, comment, ts, dontClear)
		%> @brief draw general status
		%>
		% ===================================================================
			if ~me.isConnected || me.isOff; return; end
			if ~exist('comment','var'); comment=''; end
			if ~exist('ts','var'); ts = []; end
			if ~exist('dontClear','var'); dontClear = false; end
			if dontClear == false; trackerClearScreen(me); end
			trackerDrawFixation(me);
			if ~isempty(me.exclusionZone);trackerDrawExclusion(me);end
			if ~isempty(ts);trackerDrawStimuli(me, ts);end
			if ~isempty(comment);trackerDrawText(me, comment);end
		end
		
		% ===================================================================
		function trackerDrawStimuli(me, ts, dontClear, convertToPixels)
		%> @brief draw the stimuli boxes on the tracker display
		%>
		% ===================================================================
			if ~me.isConnected || me.isOff; return; end
			if exist('ts','var') && isstruct(ts) && isfield(ts,'x')
				me.stimulusPositions = ts;
			else
				return
			end
			if ~exist('dontClear','var'); dontClear = true; end
			if ~exist('convertToPixels','var'); convertToPixels = true; end
			if dontClear==false; Eyelink('Command', 'clear_screen 0'); end
			for i = 1:length(me.stimulusPositions)
				x = me.stimulusPositions(i).x; 
				y = me.stimulusPositions(i).y; 
				size = me.stimulusPositions(i).size;
				if isempty(size); size = 1; end
				rect = [0 0 size size];
				rect = CenterRectOnPoint(rect, x, y); 
				if convertToPixels; rect = round(toPixels(me, rect,'rect')); end
				if me.stimulusPositions(i).selected == true
					Eyelink('Command', 'draw_box %d %d %d %d 15', rect(1), rect(2), rect(3), rect(4));
				else
					Eyelink('Command', 'draw_box %d %d %d %d 13', rect(1), rect(2), rect(3), rect(4));
				end
			end			
		end
		
		% ===================================================================
		function trackerDrawFixation(me)
		%> @brief draw the fixation box on the tracker display
		%>
		% ===================================================================
			if ~me.isConnected || me.isOff; return; end
			if isscalar(me.fixation.radius)
				rect = [0 0 me.fixation.radius*2 me.fixation.radius*2];
			else
				rect = [0 0 me.fixation.radius(1)*2 me.fixation.radius(2)*2];
			end
			for i = 1:length(me.fixation.X)
				nrect = CenterRectOnPoint(rect, me.fixation.X(i), me.fixation.Y(i));
				nrect = round(toPixels(me, nrect, 'rect'));
				Eyelink('Command', 'draw_filled_box %d %d %d %d 10', nrect(1), nrect(2), nrect(3), nrect(4));
			end
		end
		
		% ===================================================================
		function trackerDrawExclusion(me)
		%> @brief draw the fixation box on the tracker display
		%>
		% ===================================================================
			if ~me.isConnected || me.isOff; return; end
			if ~isempty(me.exclusionZone) && size(me.exclusionZone,2)==4
				for i = 1:size(me.exclusionZone,1)
					rect = round(toPixels(me, me.exclusionZone(i,:)));
					% exclusion zone is [-degX +degX -degY +degY], but rect is left,top,right,bottom
					Eyelink('Command', 'draw_box %d %d %d %d 12', rect(1), rect(3), rect(2), rect(4));
				end
			end
		end
		
		% ===================================================================
		function trackerDrawText(me,textIn)
		%> @brief draw the fixation box on the tracker display
		%>
		% ===================================================================
			if ~me.isConnected || me.isOff; return; end
			if exist('textIn','var') && ~isempty(textIn)
				xDraw = toPixels(me, 0, 'x');
				yDraw = toPixels(me, 0, 'y');
				Eyelink('Command', 'draw_text %i %i %d %s', xDraw, yDraw, 3, textIn);
			end
		end
		
		% ===================================================================
		function mode = currentMode(me)
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
			if me.isConnected
				mode = Eyelink('CurrentMode');
			else
				mode = -100;
			end
		end
		
		% ===================================================================
		function syncTime(me)
		%> @brief Sync time message for EDF file
		%>
		% ===================================================================
			if ~me.isConnected || me.isOff; return; end
			Eyelink('Message', 'SYNCTIME');		%zero-plot time for EDFVIEW
		end
		
		% ===================================================================
		function offset = getTimeOffset(me)
		%> @brief Get offset between tracker and display computers
		%>
		% ===================================================================
			if me.isConnected
				offset = Eyelink('TimeOffset');
				me.currentOffset = offset;
			else
				offset = 0;
			end
		end
		
		% ===================================================================
		function time = getTrackerTime(me)
		%> @brief Get offset between tracker and display computers
		%>
		% ===================================================================
			if me.isConnected
				time = Eyelink('TrackerTime');
				me.trackerTime = time;
			else
				time = 0;
			end
		end
		
		% ===================================================================
		function runDemo(me, forcescreen)
		%> @brief runs a demo of the eyelink, tests this class
		%>
		% ===================================================================
			[rM, aM] = initialiseGlobals(me);
			if ~aM.isSetup;	try setup(aM); aM.beep(2000,0.1,0.1); end; end
			PsychDefaultSetup(2);
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
			figure;plot(0,0,'ro');ax=gca;hold on;xlim([-20 20]);ylim([-20 20]);set(ax,'YDir','reverse');
			title('eyelinkManager Demo');xlabel('X eye position (deg)');ylabel('Y eye position (deg)');grid on;grid minor;drawnow;
			drawnow;
			% DEMO EXPERIMENT:
			try
				%open screen manager and dots stimulus

				if isempty(me.screen) || ~isa(me.screen,'screenManager')
					s = screenManager('debug',true,'pixelsPerCm',36,'distance',57.3);
					s.font.TextSize = 18;
					s.font.TextBackgroundColor = [0.5 0.5 0.5 1];
					if exist('forcescreen','var'); s.screen = forcescreen; end
					s.backgroundColour = [0.5 0.5 0.5 1]; %s.windowed = [0 0 900 900];
				else
					s = me.screen;
				end
				if ~s.isOpen; open(s); end

				o = dotsStimulus('size',me.fixation.radius(1)*2,'speed',2,'mask',true,'density',50); %test stimulus
				setup(o,s); % setup our stimulus with our screen object
				
				% el=EyelinkInitDefaults(s.win);
				% if ~EyelinkInit(me.isDummy,1)
				% 	fprintf('Eyelink Init aborted.\n');
				% 	Eyelink('Shutdown');
				% 	close(s);
				% 	return;
				% end
				% EyelinkDoTrackerSetup(el);
				% EyelinkDoDriftCorrection(el);

				initialise(me,s); % initialise eyelink with our screen
				ListenChar(-1); % capture the keyboard settings
				trackerSetup(me); % setup + calibrate the eyelink
				ListenChar(0);

				% define our fixation widow and stimulus for first trial
				% x,y,inittime,fixtime,radius,strict
				me.updateFixationValues([0 -10],[0 -10],3,1,1,true);
				o.sizeOut = me.fixation.radius(1) * 2;
				o.xPositionOut = me.fixation.X(1);
				o.yPositionOut = me.fixation.Y(1);
				for i = 1:length(me.fixation.X)
					ts(i).x = me.toPixels(me.fixation.X(i),'x');
					ts(i).y = me.toPixels(me.fixation.Y(i),'y');
					ts(i).size = o.sizeOut;
					ts(i).selected = true;
				end
				update(o);
				
				% setup an exclusion zone where eye is not allowed
				me.exclusionZone = [10 12 10 12];
				exc = me.toPixels(me.exclusionZone);
				exc = [exc(1) exc(3) exc(2) exc(4)]; %psychrect=[left,top,right,bottom] 
				
				setOffline(me); %Eyelink('Command', 'set_idle_mode');
				
				Priority(MaxPriority(s.win));
				blockLoop = true;
				a = 1;
				
				while a < 6 && blockLoop
					setOffline(me);
					% some general variables
					b = 1;
					xst = [];
					yst = [];
					trackerDrawStatus(me,'',ts);
					% !!! these messages define the trail start in the EDF for
					% offline analysis
					trackerMessage(me,'V_RT MESSAGE END_FIX END_RT');
					trackerMessage(me,['TRIALID ' num2str(a)]);
					% start the eyelink recording data for this trial
					setOffline(me);startRecording(me);
					% this draws the text to the tracker info box
					statusMessage(me,sprintf('DEMO Running Trial=%i X Pos = %g | Y Pos = %g | Radius = %g',a,me.fixation.X,me.fixation.Y,me.fixation.radius));
					WaitSecs('YieldSecs',1);
					vbl = flip(s); tStart = vbl;
					while vbl < tStart + 5
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
						[keyDown, ~, keyCode] = optickaCore.getKeys();
						if keyDown
							if keyCode(stopkey); blockLoop = false; break;	end
							if keyCode(nextKey); correct = true; end
							if keyCode(calibkey); trackerSetup(me); break; end
							if keyCode(driftkey); driftCorrection(me); break; end
							if keyCode(offsetkey); driftOffset(me); break; end
						end
						% send a message for the EDF after 60 frames
						if b == 60; trackerMessage(me,'END_FIX'); syncTime(me);end
						b=b+1;
					end
					Screen('Flip',s.win);
					% clear tracker display
					trackerClearScreen(me);
					% tell EDF end of reaction time portion
					trackerMessage(me,'END_RT');
					% stop recording data
					WaitSecs(0.1);
					stopRecording(me);
					setOffline(me);
					WaitSecs(0.1);
					trackerMessage(me,'TRIAL_RESULT 1');
					resetFixation(me);

					% set up the fix init system, whereby the subject must
					% remain a certain time at the origin of the eye
					% position before saccading to next target, use previous fixation location.
					%me.fixInit.X = me.fixation.X;
					%me.fixInit.Y = me.fixation.Y;
					%me.fixInit.time = 0.1;
					%me.fixInit.radius = 3;
					
					% prepare a random position for next trial
					me.updateFixationValues([randi([-4 4]) -10],[randi([-4 4]) -10],[],[],randi([1 4]));
					o.sizeOut = me.fixation.radius(1)*2;
					%me.fixation.radius = [me.fixation.radius me.fixation.radius];
					o.xPositionOut = me.fixation.X(1);
					o.yPositionOut = me.fixation.Y(1);
					update(o);
					% use this struct for the parameters to draw stimulus
					% to screen
					for i = 1:length(me.fixation.X)
						ts(i).x = me.toPixels(me.fixation.X(i),'x');
						ts(i).y = me.toPixels(me.fixation.Y(i),'y');
						ts(i).size = o.sizeOut;
						ts(i).selected = true;
					end
					% plot eye position for last trial and ITI
					plot(ax,xst,yst);drawnow;
					while GetSecs <= vbl + 1
						% check the keyboard
						[keyDown, ~, keyCode] = optickaCore.getKeys();
						if keyDown
							if keyCode(calibkey); trackerSetup(me); break; end
							if keyCode(driftkey); driftCorrection(me); break; end
							if keyCode(offsetkey); driftOffset(me); break; end
						 end
						WaitSecs(0.01);
					end
					a=a+1;
				end
				% clear tracker display
				trackerClearScreen(me);
				trackerDrawText(me,'FINISHED eyelinkManager Demo!!!');
				ListenChar(0);Priority(0);ShowCursor;RestrictKeysForKbCheck([]);
				close(s);
				try close(aM); end
				try close(rM); end
				close(me);
				clear s o
				if ~me.isDummy
					an = questdlg('Do you want to load the data and plot it?');
					if strcmpi(an,'yes')
						if ~isdeployed; commandwindow; end
						evalin('base',['eA=eyelinkAnalysis(''dir'',''' ...
							me.paths.savedData ''', ''file'',''' me.saveFile ''');eA.parseSimple;eA.plot']);
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
				ListenChar(0);Priority(0);ShowCursor;RestrictKeysForKbCheck([]);
				me.salutation('runDemo ERROR!!!')
				try Eyelink('Shutdown'); end
				try close(s); end
				try close(aM); end
				try close(rM); end
				try close(me); end
				sca;
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
	
		% === NOOPS
		function trackerDrawEyePosition(~, varargin)
			
		end
		function trackerDrawEyePositions(~, varargin)
			
		end
		function trackerFlip(~, varargin)
			
		end

		% ===================================================================
		function evt = getEvent(me)
		%> @brief TODO
		%>
		% ===================================================================
			
		end

		% ===================================================================
		function saveData(me,args)
		%> @brief compatibility with tobiiManager
		%>
		% ===================================================================
			
		end
		
		% ===================================================================
		function edfMessage(me, message)
		%> @brief send message to store in EDF data, USE trackerMessage
		%>
		%>
		% ===================================================================
			if me.isConnected
				Eyelink('Message', message );
				if me.verbose; fprintf('-+-+->EDF Message: %s\n',message);end
			end
		end

	end
	
	
	%=======================================================================
	methods (Access = private) %------------------PRIVATE METHODS
	%=======================================================================
		
	end
end


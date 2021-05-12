% ========================================================================
%> @brief eyelinkManager wraps around the eyelink toolbox functions
%> offering a simpler interface, with methods for fixation window control
%>
% ========================================================================
classdef eyelinkManager < optickaCore
	
	properties
		%> eyetracker defaults structure
		defaults struct				= struct()
		%> IP address of host
		IP char						= ''
		%> start eyetracker in dummy mode?
		isDummy logical				= false
		%> do we record and retrieve eyetracker EDF file?
		recordData logical			= false;
		%> name of eyetracker EDF file
		saveFile char				= 'myData.edf'
		%> do we log messages to the command window?
		verbose						= false
		%> fixation window:
		%> if X and Y have multiple rows, assume each one is a different fixation window.
		%> if radius is a single value, assume a circular window
		%> if radius has 2 values assume width x height rectangle
		fixation struct				= struct('X',0,'Y',0,'initTime',1,'fixTime',1,...
									'radius',1,'strictFixation',true)
		%> add a manual offset to the eye position, similar to a drift correction
		%> but handled by the eyelinkManager.
		offset struct				= struct('X',0,'Y',0)
		%> When using the test for eye position functions, 
		%> exclusion zones where no eye movement allowed: [-degX +degX -degY +degY]
		%> Add rows to generate succesive exclusion zones.
		exclusionZone				= []
		%> we can optional set an initial window that the subject must stay
		%> inside of before they saccade to the target window. This
		%> restricts guessing and "cheating", by forcing a minimum delay
		%> (default = 100ms) before initiating a saccade. Only used if X is not
		%> empty.
		fixInit	struct				= struct('X',[],'Y',[],'time',0.1,'radius',2)
		%> do we ignore blinks, if true then we do not update X and Y position from
		%> previous eye location, meaning the various methods will maintain position,
		%> e.g. if you are fixated and blink, the within-fixation X and Y position are
		%> retained so that a blink does not "break" fixation. a blink is difined as
		%> a state whre gx and gy are MISSING and pa is 0. Technically we can't 
		%> really tell if a subject is blinking or has removed their head using the 
		%> float data.
		ignoreBlinks logical		= false
		%> tracker update speed (Hz), should be 250 500 1000 2000
		sampleRate double			= 1000
		%> calibration style, [H3 HV3 HV5 HV8 HV13]
		calibrationStyle char		= 'HV5'
		%> remote calibration enables manual control and selection of each fixation
		%> this is useful for a baby or monkey who has not been trained for fixation
		%> use 1-9 to show each dot, space to select fix as valid, and 
		%> INS key ON EYELINK KEYBOARD to accept calibration!
		remoteCalibration logical	= false
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
		%> stimulus positions to draw on screen
		stimulusPositions			= []
	end
	
	properties (Hidden = true)
		%> verbosity level
		verbosityLevel double		= 4
		%> force drift correction?
		forceDriftCorrect logical	= true
		%> custom calibration target
		customTarget				= []
	end
	
	properties (SetAccess = private, GetAccess = public)
		%> the PTB screen to work on, passed in during initialise
		screen						= []
		%> Gaze X position in degrees
		x							= []
		%> Gaze Y position in degrees
		y							= []
		%> pupil size
		pupil						= []
		%> are we in a blink?
		isBlink						= false
		%> are we in an exclusion zone?
		isExclusion					= false
		%> last isFixated true/false result
		isFix						= false
		%> did the fixInit test fail or not?
		isInitFail					= false
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
	end
	
	properties (SetAccess = private, GetAccess = private)
		% value for missing data
		MISSING_DATA				= -32768
		%> the PTB screen handle, normally set by screenManager but can force it to use another screen
		win							= []
		ppd_ double					= 35
		tempFile char				= 'MYDATA.edf'
		% deals with strict fixation
		fixN double					= 0
		fixSelection				= []
		error						= []
		%> previous message sent to eyelink
		previousMessage char		= ''
		%> allowed properties passed to object upon construction
		allowedProperties char		= ['IP|fixation|ignoreBlink|sampleRate|calibrationStyle|' ...
			'enableCallbacks|callback|name|verbose|isDummy|remoteCalibration']
	end
	
	methods
		% ===================================================================
		%> @brief This is the constructor for this class
		%>
		% ===================================================================
		function me = eyelinkManager(varargin)
			if nargin>0
				me.parseArgs(varargin,me.allowedProperties);
			end
			me.defaults = EyelinkInitDefaults();
			try % is eyelink interface working
				me.version = Eyelink('GetTrackerVersion');
			catch %#ok<CTCH>
				me.version = 0;
			end
			me.modify.calibrationtargetcolour = [1 1 1];
			me.modify.calibrationtargetsize = 1;
			me.modify.calibrationtargetwidth = 0.1;
			me.modify.displayCalResults = 1;
			me.modify.targetbeep = 1;
			me.modify.devicenumber = -1;
			me.modify.waitformodereadytime = 500;
		end
		
		% ===================================================================
		%> @brief initialise the eyelink, setting up the proper settings
		%> and opening the EDF file if me.recordData is true
		%>
		% ===================================================================
		function initialise(me,sM)
			if ~exist('sM','var')
				warning('Cannot initialise without a PTB screen')
				return
			end
			
			try
				Eyelink('Shutdown'); %just make sure link is closed
			catch ME
				getReport(ME)
				warning('Problems with Eyelink initialise, make sure you install Eyelink Developer libraries!');
				me.isDummy = true;
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
				[~,dummy] = EyelinkInit(me.isDummy,me.callback);
			elseif me.enableCallbacks
				[~,dummy] = EyelinkInit(me.isDummy,1);
			else
				[~,dummy] = EyelinkInit(me.isDummy,0);
			end
			me.isDummy = logical(dummy);
			
			me.checkConnection();
			
			if me.screen.isOpen == true 
				me.win = me.screen.win;
				me.defaults = EyelinkInitDefaults(me.win);
			elseif ~isempty(me.win)
				me.defaults = EyelinkInitDefaults(me.win);
			else
				me.defaults = EyelinkInitDefaults();
			end
			
			me.defaults.winRect=me.screen.winRect;
			% this command is send from EyelinkInitDefaults
 			Eyelink('Command', 'screen_pixel_coords = %ld %ld %ld %ld',me.screen.winRect(1),me.screen.winRect(2),me.screen.winRect(3)-1,me.screen.winRect(4)-1);
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
			if me.isConnected && me.recordData
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
		
		% ===================================================================
		%> @brief
		%>
		% ===================================================================
		function updateDefaults(me)
			EyelinkUpdateDefaults(me.defaults);
		end
		
		% ===================================================================
		%> @brief
		%>
		% ===================================================================
		function setup(me)
			if me.isConnected
				oldrk = RestrictKeysForKbCheck([]); %just in case someone has restricted keys
				trackerSetup(me); % Calibrate the eye tracker
				checkEye(me);
				RestrictKeysForKbCheck(oldrk);
			end
		end
		
		% ===================================================================
		%> @brief reset the fixation counters ready for a new trial
		%>
		% ===================================================================
		function resetFixation(me)
			me.fixStartTime			= 0;
			me.fixLength			= 0;
			me.fixInitStartTime		= 0;
			me.fixInitLength		= 0;
			me.fixTotal				= 0;
			me.fixN					= 0;
			me.fixSelection			= 0;
			me.isFix				= false;
			me.isBlink				= false;
			me.isExclusion			= false;
			me.isInitFail			= false;
			if me.verbose
				fprintf('-+-+-> eyelinkManager:reset fixation: %i %i %i\n',me.fixLength,me.fixTotal,me.fixN);
			end
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
			fprintf('\n===>>> CALIBRATING EYELINK... <<<===\n');
			Eyelink('Verbosity',me.verbosityLevel);
			Eyelink('Command','calibration_type = %s', me.calibrationStyle);
			Eyelink('Command','normal_click_dcorr = ON');
			Eyelink('Command','randomize_calibration_order = NO');
			Eyelink('Command','randomize_validation_order = NO');
			Eyelink('Command','cal_repeat_first_target = YES');
			Eyelink('Command','val_repeat_first_target = YES');
			Eyelink('Command','validation_online_fixup  = NO');
			if me.remoteCalibration
				Eyelink('Command','generate_default_targets = YES');
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
				Eyelink('Command','generate_default_targets = YES');
				Eyelink('Command','remote_cal_enable = 0');
			end
			EyelinkDoTrackerSetup(me.defaults);
			if ~isempty(me.screen) && me.screen.isOpen
				Screen('Flip',me.screen.win);
			end
			[result,out] = Eyelink('CalMessage');
			fprintf('===>>> RESULT =  %.2g | message: %s\n\n',result,out);
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
		function stopRecording(me)
			if me.isConnected
				Eyelink('StopRecording');
			end
		end
		
		% ===================================================================
		%> @brief wrapper for EyelinkDoDriftCorrection
		%>
		% ===================================================================
		function success = driftCorrection(me,force)
			if ~exist('force','var');force = true;end
			success = false;
			if me.forceDriftCorrect || force
				Eyelink('command', 'driftcorrect_cr_disable = ON');
			else
				Eyelink('command', 'driftcorrect_cr_disable = OFF');
			end
			if me.isConnected
				x=me.toPixels(me.fixation.X,'x'); %#ok<*PROPLC>
				y=me.toPixels(me.fixation.Y,'y');
				fprintf('Drift Correct @ %.2f/%.2f px (%.2f/%.2f deg)\n', x,y, me.fixation.X, me.fixation.Y);
				Screen('DrawText',me.screen.win,'Drift Correction...');
				Screen('gluDisk',me.screen.win,[1 0 0 0.5],x,y,8)
				Screen('Flip',me.screen.win);
				WaitSecs('YieldSecs',0.25);
				success = EyelinkDoDriftCorrect(me.defaults, round(x), round(y), 1, 1);
			end
			if success ~= 0
				me.salutation('Drift Correct','FAILED',true);
			end
			if me.forceDriftCorrect
				me.salutation('Drift Correct','Apply Drift correct',true);
				res=Eyelink('ApplyDriftCorr');
				me.salutation('Drift Correct',sprintf('DC Result: %f\n',res),true);
			end
		end
		
		% ===================================================================
		%> @brief wrpper for CheckRecording
		%>
		% ===================================================================
		function error = checkRecording(me)
			if me.isConnected
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
		function sample = getSample(me)
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
				%if me.verbose;fprintf('<DM X: %.2f | Y: %.2f | P: %.2f | T: %f>\n',me.x,me.y,me.pupil,me.currentSample.time);end
			end
			sample = me.currentSample;
		end
		
		
		% ===================================================================
		%> @brief Sinlge method to update the fixation parameters
		%>
		% ===================================================================
		function updateFixationValues(me,x,y,inittime,fixtime,radius,strict)
			resetFixation(me)
			if nargin > 1 && ~isempty(x)
				if isinf(x)
					me.fixation.X = me.screen.screenXOffset;
				else
					me.fixation.X = x;
				end
			end
			if nargin > 2 && ~isempty(y)
				if isinf(y)
					me.fixation.Y = me.screen.screenYOffset;
				else
					me.fixation.Y = y;
				end
			end
			if nargin > 3 && ~isempty(inittime)
				if iscell(inittime) && length(inittime)==4
					me.fixation.initTime = inittime{1};
					me.fixation.time = inittime{2};
					me.fixation.radius = inittime{3};
					me.fixation.strictFixation = inittime{4};
				elseif length(inittime) == 2
					me.fixation.initTime = randi(inittime.*1000)/1000;
				elseif length(inittime)==1
					me.fixation.initTime = inittime;
				end
			end
			if nargin > 4 && ~isempty(fixtime)
				if length(fixtime) == 2
					me.fixation.time = randi(fixtime.*1000)/1000;
				elseif length(fixtime) == 1
					me.fixation.time = fixtime;
				end
			end
			if nargin > 5 && ~isempty(radius); me.fixation.radius = radius; end
			if nargin > 6 && ~isempty(strict); me.fixation.strictFixation = strict; end
			if me.verbose 
				fprintf('-+-+-> eyelinkManager:updateFixationValues: X=%g | Y=%g | IT=%s | FT=%s | R=%g | Strict=%i\n', ... 
				me.fixation.X, me.fixation.Y, num2str(me.fixation.initTime), num2str(me.fixation.time), ...
				me.fixation.radius,me.fixation.strictFixation); 
			end
		end
		
		% ===================================================================
		%> @brief isFixated tests for fixation and updates the fixLength time
		%>
		%> @return fixated boolean if we are fixated
		%> @return fixtime boolean if we're fixed for fixation time
		%> @return searching boolean for if we are still searching for fixation
		% ===================================================================
		function [fixated, fixtime, searching, window, exclusion, fixinit] = isFixated(me)
			fixated = false; fixtime = false; searching = true; 
			exclusion = false; window = []; fixinit = false;
			
			if isempty(me.currentSample); return; end
			
			if me.isExclusion || me.isInitFail
				exclusion = me.isExclusion; fixinit = me.isInitFail; searching = false;
				return; % we previously matched either rule, now cannot pass fixation until a reset.
			end
			if me.fixInitStartTime == 0
				me.fixInitStartTime = me.currentSample.time;
				me.fixTotal = 0;
				me.fixInitLength = 0;
			end
			
			x = me.x + me.offset.X; y = me.y + me.offset.Y;
			% ---- test for exclusion zones first
			if ~isempty(me.exclusionZone)
				for i = 1:size(me.exclusionZone,1)
					if (x >= me.exclusionZone(i,1) && x <= me.exclusionZone(i,2)) && ...
						(me.y >= me.exclusionZone(i,3) && me.y <= me.exclusionZone(i,4))
						searching = false; exclusion = true; me.isExclusion = true;
						return;
					end
				end
			end
			% ---- test for fix initiation start window
			if ~isempty(me.fixInit.X)
				if (me.currentSample.time - me.fixInitStartTime) < me.fixInit.time
					r = sqrt((x - me.fixInit.X).^2 + (me.y - me.fixInit.Y).^2);
					window = find(r < me.fixInit.radius);
					if ~any(window)
						searching = false; exclusion = true; fixinit = true;
						me.isInitFail = fixinit; me.isFix = false;
						return;
					end
				end
			end
			% now test if we are still searching or in fixation window, if
			% radius is single value, assume circular, otherwise assume
			% rectangular
			if length(me.fixation.radius) == 1 % circular test
				r = sqrt((x - me.fixation.X).^2 + (me.y - me.fixation.Y).^2); %fprintf('x: %g-%g y: %g-%g r: %g-%g\n',x, me.fixation.X, me.y, me.fixation.Y,r,me.fixation.radius);
				window = find(r < me.fixation.radius);
			else % x y rectangular window test
				if (x >= (me.fixation.X - me.fixation.radius(1))) && (x <= (me.fixation.X + me.fixation.radius(1))) ...
						&& (me.y >= (me.fixation.Y - me.fixation.radius(2))) && (me.y <= (me.fixation.Y + me.fixation.radius(2)))
					window = 1;
				end
			end
			me.fixTotal = (me.currentSample.time - me.fixInitStartTime) / 1e3;
			if any(window) % inside fixation window
				if me.fixN == 0
					me.fixN = 1;
					me.fixSelection = window(1);
				end
				if me.fixSelection == window(1)
					if me.fixStartTime == 0
						me.fixStartTime = me.currentSample.time;
					end
					fixated = true; searching = false;
					me.fixLength = (me.currentSample.time - me.fixStartTime) / 1e3;
					if me.fixLength >= me.fixation.time
						fixtime = true;
					end
				else
					fixated = false; fixtime = false; searching = false;
				end
				me.isFix = fixated;
			else % not inside the fixation window
				if me.fixN == 1
					me.fixN = -100;
				end
				me.fixInitLength = (me.currentSample.time - me.fixInitStartTime) / 1e3;
				if me.fixInitLength < me.fixation.initTime
					searching = true;
				else
					searching = false;
				end
				me.isFix = false; me.fixLength = 0; me.fixStartTime = 0;
			end
		end
		
		% ===================================================================
		%> @brief testExclusion 
		%> 
		%>
		% ===================================================================		
		function out = testExclusion(me)
			out = false;
			if (me.isConnected || me.isDummy) && ~isempty(me.currentSample) && ~isempty(me.exclusionZone)
				eZ = me.exclusionZone; x = me.x + me.offset.X; y = me.y + me.offset.Y;
				for i = 1:size(eZ,1)
					if (x >= eZ(i,1) && x <= eZ(i,2)) && (y >= eZ(i,3) && y <= eZ(i,4))
						out = true;
						return
					end
				end
			end
		end
		
		% ===================================================================
		%> @brief testWithinFixationWindow simply tests we are in fixwindow
		%> 
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
		%> @brief Checks for both searching and then maintaining fix. Input is
		%> 2 strings, either one is returned depending on success or
		%> failure, 'searching' may also be returned meaning the fixation
		%> window hasn't been entered yet, and 'fixing' means the fixation
		%> time is not yet met...
		%>
		%> @param yesString if this function succeeds return this string
		%> @param noString if this function fails return this string
		%> @return out the output string which is 'searching' if fixation has
		%>   been initiated, 'fixing' if the fixation window was entered
		%>   but not for the requisite fixation time, 'EXCLUDED!' if an exclusion
		%>   zone was entered or the yesString or noString.
		% ===================================================================
		function [out, window, exclusion] = testSearchHoldFixation(me, yesString, noString)
			[fix, fixtime, searching, window, exclusion, initfail] = me.isFixated();
			if exclusion
				fprintf('-+-+-> Eyelink:testSearchHoldFixation EXCLUSION ZONE ENTERED!\n')
				out = 'EXCLUDED!';
				return
			end
			if initfail
				if me.verbose; fprintf('-+-+-> Eyelink:testSearchHoldFixation FIX INIT TIME FAILED!\n'); end
				out = 'EXCLUDED!';
				return
			end
			if searching
				if (me.fixation.strictFixation==true && (me.fixN == 0)) || me.fixation.strictFixation==false
					out = 'searching';
				else
					out = noString;
					if me.verbose; fprintf('-+-+-> Eyelink:testSearchHoldFixation STRICT SEARCH FAIL: %s [%.2f %.2f %.2f]\n', out, fix, fixtime, searching);end
				end
				return
			elseif fix
				if (me.fixation.strictFixation==true && ~(me.fixN == -100)) || me.fixation.strictFixation==false
					if fixtime
						out = yesString;
						if me.verbose; fprintf('-+-+-> Eyelink:testSearchHoldFixation FIXATION SUCCESSFUL!: %s [%.2f %.2f %.2f]\n', out, fix, fixtime, searching);end
					else
						out = 'fixing';
					end
				else
					out = noString;
					if me.verbose;fprintf('-+-+-> Eyelink:testSearchHoldFixation FIX FAIL: %s [%.2f %.2f %.2f]\n', out, fix, fixtime, searching);end
				end
				return
			elseif searching == false
				out = noString;
				if me.verbose;fprintf('-+-+-> Eyelink:testSearchHoldFixation SEARCH FAIL: %s [%.2f %.2f %.2f]\n', out, fix, fixtime, searching);end
			else
				out = '';
			end
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
				fprintf('-+-+-> Eyelink:testHoldFixation EXCLUSION ZONE ENTERED!\n')
				out = 'EXCLUDED!'; window = [];
				return
			end
			if fix
				if (me.fixation.strictFixation==true && ~(me.fixN == -100)) || me.fixation.strictFixation==false
					if fixtime
						out = yesString;
						if me.verbose; fprintf('-+-+-> Eyelink:testHoldFixation FIXATION SUCCESSFUL!: %s [%g %g %g]\n', out, fix, fixtime, searching);end
					else
						out = 'fixing';
					end
				else
					out = noString;
					if me.verbose;fprintf('-+-+-> Eyelink:testHoldFixation FIX FAIL: %s [%g %g %g]\n', out, fix, fixtime, searching);end
				end
				return
			else
				out = noString;
				if me.verbose; fprintf('-+-+-> Eyelink:testHoldFixation FIX FAIL: %s [%g %g %g]\n', out, fix, fixtime, searching);end
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
		%> @brief draw the current eye position on the PTB display
		%>
		% ===================================================================
		function drawEyePosition(me)
			if (me.isDummy || me.isConnected) && isa(me.screen,'screenManager') && me.screen.isOpen && ~isempty(me.x) && ~isempty(me.y)
				xy = toPixels(me,[me.x+me.offset.X me.y+me.offset.Y]);
				if me.isFix
					if me.fixLength > me.fixation.time && ~me.isBlink
						Screen('DrawDots', me.win, xy, 6, [0 1 0.25 1], [], 3);
					elseif ~me.isBlink
						Screen('DrawDots', me.win, xy, 6, [0.75 0 0.75 1], [], 3);
					else
						Screen('DrawDots', me.win, xy, 6, [0.75 0 0 1], [], 3);
					end
				else
					if ~me.isBlink
						Screen('DrawDots', me.win, xy, 6, [0.75 0.5 0 1], [], 3);
					else
						Screen('DrawDots', me.win, xy, 6, [0.75 0 0 1], [], 3);
					end
				end
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
				if me.verbose; fprintf('-+-+->Eyelink status message: %s\n',message);end
			end
		end
		
		% ===================================================================
		%> @brief send message to store in EDF data
		%>
		%>
		% ===================================================================
		function trackerMessage(me, message)
			if me.isConnected
				Eyelink('Message', message );
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
			if me.isConnected
				Eyelink('Command', 'clear_screen 0');
			end
		end
		
		% ===================================================================
		%> @brief draw the stimuli boxes on the tracker display
		%>
		% ===================================================================
		function trackerDrawStimuli(me, ts, clearScreen)
			if me.isConnected
				if exist('ts','var') && isstruct(ts)
					me.stimulusPositions = ts;
				end
				if ~exist('clearScreen','var')
					clearScreen = false;
				end
				for i = 1:length(me.stimulusPositions)
					x = me.stimulusPositions(i).x; 
					y = me.stimulusPositions(i).y; 
					size = me.stimulusPositions(i).size;
					if isempty(size); size = 1 * me.ppd_; end
					rect = [0 0 size size];
					rect = round(CenterRectOnPoint(rect, x, y)); 
					if clearScreen; Eyelink('Command', 'clear_screen 0'); end
					if me.stimulusPositions(i).selected == true
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
		function trackerDrawFixation(me)
			if me.isConnected
				size = (me.fixation.radius * 2) * me.ppd_;
				rect = [0 0 size size];
				x = toPixels(me, me.fixation.X, 'x');
				y = toPixels(me, me.fixation.Y, 'y');
				rect = round(CenterRectOnPoint(rect, x, y));
				Eyelink('Command', 'draw_filled_box %d %d %d %d 12', rect(1), rect(2), rect(3), rect(4));
			end
		end
		
		% ===================================================================
		%> @brief draw the fixation box on the tracker display
		%>
		% ===================================================================
		function trackerDrawExclusion(me)
			if me.isConnected && ~isempty(me.exclusionZone) && length(me.exclusionZone)==4
				rect = toPixels(me, me.exclusionZone);
				Eyelink('Command', 'draw_box %d %d %d %d 10', rect(1), rect(2), rect(3), rect(4));
			end
		end
		
		% ===================================================================
		%> @brief draw the fixation box on the tracker display
		%>
		% ===================================================================
		function trackerDrawText(me,textIn)
			if me.isConnected
				if exist('textIn','var') && ~isempty(textIn)
					xDraw = toPixels(me, 0, 'x');
					yDraw = toPixels(me, 0, 'y');
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
			if me.isConnected
				Eyelink('Message', 'SYNCTIME');		%zero-plot time for EDFVIEW
			end
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
		%> @brief set into offline / idle mode
		%>
		% ===================================================================
		function setOffline(me)
			if me.isConnected
				Eyelink('Command', 'set_idle_mode');
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
				%ListenChar(-1); % capture the keyboard settings
				setup(me); % setup + calibrate the eyelink
				
				% define our fixation widow and stimulus for first trial
				% x,y,inittime,fixtime,radius,strict
				me.updateFixationValues(0,0,3,1,1,true);
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
						draw(o);
						drawGrid(s);
						drawScreenCenter(s);
						drawCross(s,0.5,[1 1 0],me.fixation.X,me.fixation.Y);
						
						% get the current eye position and save x and y for local
						% plotting
						getSample(me); xst(b)=me.x+me.offset.X; yst(b)=me.y+me.offset.Y;
						
						% if we have an eye position, plot the info on the display
						% screen
						if ~isempty(me.currentSample)
							[~, ~, searching] = isFixated(me);
							x = me.toPixels(me.x,'x'); %#ok<*PROP>
							y = me.toPixels(me.y,'y');
							txt = sprintf('Q = finish, SPACE = next. X = %3.1f / %2.2f | Y = %3.1f / %2.2f | RADIUS = %s | TIME = %.1f | FIX = %.1f | SEARCH = %i | BLINK = %i | EXCLUSION = %i | FAIL-INIT = %i',...
								x, me.x, y, me.y, sprintf('%1.1f ',me.fixation.radius), me.fixTotal, me.fixLength, searching, me.isBlink, me.isExclusion, me.isInitFail);
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
					%me.fixInit.radius = 3;
					% prepare a random position for next trial
					me.updateFixationValues(randi([-5 5]),randi([-5 5]),[],[],randi([1 5]));
					o.sizeOut = me.fixation.radius*2;
					%me.fixation.radius = [me.fixation.radius me.fixation.radius];
					o.xPositionOut = me.fixation.X;
					o.yPositionOut = me.fixation.Y;
					update(o);
					% use this struct for the parameters to draw stimulus
					% to screen
					ts.x = me.fixation.X;
					ts.y = me.fixation.Y;
					ts.size = me.fixation.radius;
					ts.selected = true;
					% clear tracker display
					trackerClearScreen(me);
					trackerDrawStimuli(me,ts);
					trackerDrawFixation(me);
					% plot eye position for last trial and ITI
					plot(ax,xst,yst);drawnow;
					while GetSecs <= vbl + 1
						% check the keyboard
						[~, ~, keyCode] = KbCheck(-1);
						if keyCode(calibkey); trackerSetup(me); break; end
						if keyCode(driftkey); driftCorrection(me); break; end
					end
					a=a+1;
				end
				ListenChar(0);Priority(0);ShowCursor;RestrictKeysForKbCheck([])
				close(s);
				close(me);
				clear s o
				if ~me.isDummy
					an = questdlg('Do you want to load the data and plot it?');
					if strcmpi(an,'yes')
						commandwindow;
						evalin('base',['eA=eyelinkAnalysis(''dir'',''' ...
							me.paths.savedData ''', ''file'',''myData.edf'');eA.parseSimple;eA.plot']);
					end
				end
				me.fixation.X = oldx;
				me.fixation.Y = oldy;
				me.exclusionZone = oldexc;
				me.fixInit = oldfixinit;
			catch ME
				me.fixation.X = oldx;
				me.fixation.Y = oldy;
				me.exclusionZone = oldexc;
				me.fixInit = oldfixinit;
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
		
	
	end
	
	
	%=======================================================================
	methods (Access = private) %------------------PRIVATE METHODS
	%=======================================================================
		
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


% ========================================================================
classdef tobiiManager < eyetrackerCore & eyetrackerSmooth
%> @class tobiiManager
%> @brief Manages the Tobii eyetrackers
%>
%> tobiiManager wraps around the Titta toolbox functions
%> offering a interface consistent with eyelinkManager, offering
%> methods to check and change fixation windows gaze contingent tasks easily.
%>
%> The core methods enable the user to test for common behavioural eye
%> tracking tasks with single commands. For example, to initiate a task we
%> normally place a fixation cross on the screen and ask the subject to
%> saccade to the cross and maintain fixation for a particular duration. This
%> is achieved using testSearchHoldFixation('yes','no'), using the properties:
%> fixation.initTime to time how long the subject has to saccade into the
%> window, fixation.time for how long they must maintain fixation,
%> fixation.radius for the radius around fixation.X and fixation.Y
%> position. The method returns the 'yes' string if the rules are matched, 
%> and 'no' if they are not, thus enabling experiment code to simply define what 
%> happened. Other methods include isFixated(), testFixationTime(),
%> testHoldFixation(). 
%>
%> Multiple fixation windows can be assigned, and in addition exclusion
%> windows can ensure a subject doesn't saccade to particular parts of the
%> screen. fixInit allows you to define a minimum time with which the subject
%> must initiate a saccade away from a position (which stops a subject cheating).
%>
%> @todo handle new eye-openness signals in new SDK https://developer.tobiipro.com/commonconcepts/eyeopenness.html
%>
%> Copyright ©2014-2023 Ian Max Andolina — released: LGPL3, see LICENCE.md
% ========================================================================
	
	properties (SetAccess = protected, GetAccess = public)
		%> type of eyetracker
		type			= 'tobii'
	end

	properties
		%> setup and calibration values
		calibration		= struct(...
						'model', 'Tobii Pro Spectrum',...
						'mode', 'human',...
						'stimulus', 'animated',...
						'calPositions', [],...
						'valPositions', [],...
						'manual', false,...
						'manualMode', 'standard',...
						'autoPace', true,...
						'paceDuration', 0.8,...
						'eyeUsed', 'both',...
						'movie', [], ...
						'filePath', [],...
						'size', 1,... % size of calibration target in degrees
						'reloadCalibration',true,...
						'calFile','tobiiCalibration.mat')
		%> optional eyetracker address
		address			= []
	end
	
	properties (Hidden = true)
		%> Settings structure from Titta
		settings struct	= []
		%> Titta class object
		tobii
		%> 
		sampletime		= []
		%> last calibration data
		calib
	end

	properties (SetAccess = protected, GetAccess = protected)
		%> tracker time stamp
		systemTime		= 0
		calibData
		calStim
		isCollectedData = false
		%> allowed properties passed to object upon construction
		allowedProperties = {'calibration', 'settings', 'address'}
	end
	
	%=======================================================================
	methods %------------------PUBLIC METHODS
	%=======================================================================
	
		% ===================================================================
		function me = tobiiManager(varargin)
		%> @fn tobiiManager
		%>
		%> tobiiManager CONSTRUCTOR
		%>
		%> @param varargin can be passed as a structure or name,arg pairs
		%> @return instance of the class.
		% ===================================================================
			args = optickaCore.addDefaults(varargin,struct('name','Tobii',...
				'sampleRate',300,'useOperatorScreen',true,'eyeUsed','both'));
			me=me@eyetrackerCore(args); %we call the superclass constructor first
			me.parseArgs(args, me.allowedProperties);
			
			try % is tobii working?
				assert(exist('Titta','class')==8,'TOBIIMANAGER:NO-TITTA','Cannot find Titta toolbox, please install instead of Tobii SDK; exiting...');
			end
			if contains(me.calibration.model,{'Tobii 4C','IS4_Large_Peripheral'})
				me.model = 'IS4_Large_Peripheral';
				me.sampleRate = 90; 
				me.calibration.mode = 'Default';
			end
			[p,f,e] = fileparts(me.saveFile);
			if isempty(e); e = '.mat'; end
			if isempty(p)
				initialiseSaveFile(me);
				me.saveFile = [me.paths.savedData filesep f e];
			end
			me.smoothing.sampleRate = me.sampleRate;
		end
		
		% ===================================================================
		%> @brief initialise the tobii.
		%>
		%> @param sM - screenManager object we will use
		%> @param sM2 - a second screenManager used during calibration
		% ===================================================================
		function success = initialise(me,sM,sM2)
			success = false;
			if me.isOff; me.isConnected = false; return; end

			if ~exist('sM','var') || isempty(sM)
				if isempty(me.screen) || ~isa(me.screen,'screenManager')
					me.screen		= screenManager;
				end
			else
					me.screen			= sM;
			end
			me.ppd_					= me.screen.ppd;
			if me.screen.isOpen; me.win	= me.screen.win; end

			if me.screen.screen > 0
				oscreen = me.screen.screen - 1;
			else
				oscreen = 0;
			end
			if exist('sM2','var')
				me.operatorScreen = sM2;
			elseif isempty(me.operatorScreen)
				me.operatorScreen = screenManager('pixelsPerCm',20,...
					'disableSyncTests',true,'backgroundColour',me.screen.backgroundColour,...
					'screen', oscreen, 'specialFlags', kPsychGUIWindow);
				[w,h]			= Screen('WindowSize',me.operatorScreen.screen);
				me.operatorScreen.windowed	= [0 0 round(w/1.2) round(h/1.2)];
			end
			me.secondScreen		= true;
			if ismac; me.operatorScreen.useRetina = true; end

			initialiseSaveFile(me);
			[p,f,e] = fileparts(me.saveFile);
			if isempty(e); e = '.mat'; end
			if isempty(p)
				me.saveFile = [me.paths.savedData filesep me.name '-' me.savePrefix '-' f e];
			else
				me.saveFile = [p filesep me.name '-' me.savePrefix '-' f e];
			end

			me.smoothing.sampleRate = me.sampleRate;
			
			if contains(me.calibration.model,{'Tobii 4C','IS4_Large_Peripheral'})
				me.model = 'IS4_Large_Peripheral';
				me.sampleRate = 90; 
				me.calibration.mode = 'Default';
			end
			
			me.settings								= Titta.getDefaults(me.calibration.model);
			if ~contains(me.calibration.model,{'Tobii 4C','IS4_Large_Peripheral'})
				me.settings.freq					= me.sampleRate;
				me.settings.trackingMode			= me.calibration.mode;
			end
			me.settings.calibrateEye				= me.calibration.eyeUsed;
			me.settings.cal.bgColor					= floor(me.screen.backgroundColour*255);
			me.settings.UI.setup.bgColor			= me.settings.cal.bgColor;
			me.settings.UI.val.bgColor				= me.settings.cal.bgColor;
			me.settings.advcal.bgColor				= me.settings.cal.bgColor;
			me.settings.UI.advcal.bgColor			= me.settings.cal.bgColor;
			me.settings.UI.setup.eyeClr				= 255;
			me.settings.UI.setup.instruct.font		= me.sansFont;
			me.settings.UI.button.setup.text.font	= me.sansFont;
			me.settings.UI.button.val.text.font		= me.sansFont;
			me.settings.UI.cal.errMsg.font			= me.sansFont;
			me.settings.UI.val.avg.text.font		= me.monoFont;
			me.settings.UI.val.hover.text.font		= me.monoFont;
			me.settings.UI.val.menu.text.font		= me.monoFont;
			if strcmpi(me.calibration.stimulus,'movie') || strcmpi(me.calibration.manualMode,'Smart')
				me.calStim							= tittaAdvMovieStimulus(me.screen);
				me.calStim.bgColor					= me.settings.cal.bgColor;
				me.calStim.blinkCount				= 3;
				if ~isempty(me.calibration.filePath); fp = me.calibration.filePath; else; fp = me.calibration.movie; end
				m									= movieStimulus('size', me.calibration.size,'filePath', fp);
				reset(m); setup(m, me.screen);
				me.calStim.setVideoPlayer(m);
				me.settings.cal.drawFunction		= @(a,b,c,d,e,f) me.calStim.doDraw(a,b,c,d,e,f);
				if me.calibration.manual
					me.settings.advcal.drawFunction	= @(a,b,c,d,e,f) me.calStim.doDraw(a,b,c,d,e,f);
				end
			elseif strcmpi(me.calibration.stimulus,'image')
				me.calStim							= tittaAdvImageStimulus(me.screen);
				me.calStim.bgColor					= me.settings.cal.bgColor;
				me.calStim.blinkCount				= 3;
				if ~isempty(me.calibration.filePath); fp = me.calibration.filePath; else; fp = me.calibration.movie; end
				m									= imageStimulus('size', me.calibration.size,'filePath', fp);
				reset(m); setup(m, me.screen);
				me.calStim.setStimulus(m);
				me.settings.cal.drawFunction		= @(a,b,c,d,e,f) me.calStim.doDraw(a,b,c,d,e,f);
				if me.calibration.manual
					me.settings.advcal.drawFunction	= @(a,b,c,d,e,f) me.calStim.doDraw(a,b,c,d,e,f);
				end
			elseif strcmpi(me.calibration.stimulus,'pupilcore')
				me.calStim							= tittaCalStimulus(me.screen);
				me.calStim.bgColor					= me.settings.cal.bgColor;
				me.calStim.moveTime					= 0.75;
				me.calStim.oscillatePeriod			= 0.8;
				me.calStim.blinkCount				= 4;
				me.calStim.fixBackColor				= 0;
				me.calStim.fixFrontColor			= 255;
				me.settings.cal.drawFunction		= @(a,b,c,d,e,f) me.calStim.doDraw(a,b,c,d,e,f);
				if me.calibration.manual
					me.settings.advcal.drawFunction	= @(a,b,c,d,e,f) me.calStim.doDraw(a,b,c,d,e,f);
				end
			else
				me.calStim							= AnimatedCalibrationDisplay();
				me.calStim.bgColor					= me.settings.cal.bgColor;
				me.calStim.fixBackSizeMin			= round(me.calibration.size * me.ppd_);
				me.calStim.fixBackSizeMax			= round((me.calibration.size*1.5) * me.ppd_);
				me.calStim.fixBackSizeMaxOsc		= me.calStim.fixBackSizeMax;
				me.calStim.fixBackSizeBlink			= me.calStim.fixBackSizeMax;
				me.calStim.moveTime					= 0.75;
				me.calStim.oscillatePeriod			= 1;
				me.calStim.blinkCount				= 4;
				me.calStim.fixBackColor				= 0;
				me.calStim.fixFrontColor			= 255;
				me.settings.cal.drawFunction		= @(a,b,c,d,e,f) me.calStim.doDraw(a,b,c,d,e,f);
				if me.calibration.manual
					me.settings.advcal.drawFunction	= @(a,b,c,d,e,f) me.calStim.doDraw(a,b,c,d,e,f);
				end
			end
			if me.calibration.autoPace
				me.settings.cal.autoPace			= 2;
			else
				me.settings.cal.autoPace			= 0;
			end
			me.settings.cal.paceDuration			= me.calibration.paceDuration;
			if me.calibration.autoPace
				me.settings.cal.doRandomPointOrder	= true;
			else
				me.settings.cal.doRandomPointOrder	= false;
			end
			if ~isempty(me.calibration.calPositions)
				me.settings.cal.pointPos			= me.calibration.calPositions;
			else
				me.calibration.calPositions			= me.settings.cal.pointPos;
			end
			if ~isempty(me.calibration.valPositions)
				me.settings.val.pointPos			= me.calibration.valPositions;
			else
				me.calibration.valPositions			= me.settings.val.pointPos;
			end
			if me.verbose; me.settings.debugMode=true; end
			me.settings.cal.pointNotifyFunction	= @tittaCalCallback;
			me.settings.val.pointNotifyFunction	= @tittaCalCallback;
			
			if me.calibration.manual
				me.settings.advcal.cal.pointPos				= me.calibration.calPositions;
				me.settings.advcal.val.pointPos				= me.calibration.valPositions;
				me.settings.advcal.cal.pointNotifyFunction	= @tittaCalCallback;
				me.settings.advcal.val.pointNotifyFunction	= @tittaCalCallback;
			end

			if ~isa(me.tobii, 'Titta') || isempty(me.tobii); initTracker(me); end
			assert(isa(me.tobii,'Titta'),'TOBIIMANAGER:INIT-ERROR','Cannot Initialise...')
			if me.isDummy; me.tobii = me.tobii.setDummyMode(); end
			
			if isempty(me.address) || me.isDummy
				me.tobii.init();
			else
				me.tobii.init(me.address);
			end
			checkConnection(me);
			me.systemTime							= me.tobii.getTimeAsSystemTime;
			me.isConnected = true;
			
			if me.screen.isOpen == true
				me.win								= me.screen.win;
			end
			me.ppd_									= me.screen.ppd;
			
			if ~me.isDummy
				me.version = sprintf('Running on a %s (%s) @ %iHz mode:%s [%s:%s]\nScreen %i %i x %i @ %iHz', ...
					me.tobii.systemInfo.model, ...
					me.tobii.systemInfo.deviceName,...
					me.tobii.systemInfo.frequency,...
					me.tobii.systemInfo.trackingMode,...
					me.tobii.systemInfo.firmwareVersion,...
					me.tobii.systemInfo.runtimeVersion,...
					me.screen.screen,...
					me.screen.winRect(3),...
					me.screen.winRect(4),...
					me.screen.screenVals.fps);
			else
				me.version = sprintf('Running in Dummy Mode\nScreen %i %i x %i @ %iHz',...
					me.screen.screen,...
					me.screen.winRect(3),...
					me.screen.winRect(4),...
					me.screen.screenVals.fps);
			end
			me.salutation('tobiiManager.initialise()', me.version, true);
			success = true;
		end
		
		% ===================================================================
		%> @brief sets up the calibration and validation
		%>
		% ===================================================================
		function cal = trackerSetup(me, incal)
			cal = [];
			if ~me.isConnected 
				warning('Eyetracker not connected [must initialise first], cannot calibrate!'); return
			end

			if ~me.screen.isOpen; open(me.screen); end
			if ~me.operatorScreen.isOpen; open(me.operatorScreen); end

			if me.isDummy
				disp('--->>> Tobii Dummy Mode: calibration skipped');return;
			end

			[p,f,~]=fileparts(me.calibration.calFile);
			e = '.mat';
			if isempty(f); f = 'tobiiCalibration'; end
			if isempty(p) || ~exist('p','dir'); p = me.paths.calibration; end
			me.calibration.calFile = [p filesep f e];

			if ~exist('incal','var'); incal = []; end
			if me.calibration.reloadCalibration && exist(me.calibration.calFile,'file')
				load(me.calibration.calFile);
				if (isfield(cal,'attempt') && ~isempty(cal.attempt)) && (isfield(cal,'wasSkipped') && ~cal.wasSkipped)
					incal = cal; cal = []; 
				end
			elseif exist('incal','var') && isstruct(incal) && ~isempty(incal)
				me.calib = incal;
			else
				incal = [];
			end

			fprintf('\n===>>> CALIBRATING TOBII... <<<===\n');
			wasRecording = me.isRecording;
			if wasRecording; stopRecording(me,true); end
			%updateDefaults(me); % make sure we send any other settings changes
			
			oldr = RestrictKeysForKbCheck([]);
			ListenChar(-1);
			if me.calibration.manual
				if strcmpi(me.calibration.manualMode,'standard')
					ctrl = [];
				else
					[rM, aM] = initialiseGlobals(me, false, true);
					ctrl = tempController(me.tobii, me.calStim);
					ctrl.rewardProvider = rM;
					ctrl.audioProvider = aM;
				end
				if ~isempty(incal) && isstruct(incal)...
					&& (isfield(incal,'type') && contains(incal.type,'advanced'))...
					&& (isfield(cal,'wasSkipped') && ~cal.wasSkipped)
				else
					incal = [];
				end
				cal = me.tobii.calibrateAdvanced([me.screen.win me.operatorScreen.win], incal, ctrl); 
			else
				if ~isempty(incal) && isstruct(incal)...
						&& (isfield(incal,'type') && contains(incal.type,'standard'))...
						&& (isfield(cal,'wasSkipped') && ~cal.wasSkipped)
					cal = me.tobii.calibrate([me.screen.win me.operatorScreen.win], [], incal); 
				else
					cal = me.tobii.calibrate([me.screen.win me.operatorScreen.win]);
				end
			end
			ListenChar(0);
			RestrictKeysForKbCheck(oldr);

			if ~isempty(cal) && isfield(cal,'wasSkipped') && ~cal.wasSkipped
				cal.date = me.dateStamp;
				assignin('base','cal',cal); %put our calibration ready to save manually
				save(me.calibration.calFile,'cal');
				me.calib = cal;
			end

			if strcmpi(me.calibration.stimulus,'movie')
				try me.calStim.setCleanState(); end
			end

			if ~isempty(me.calib) && me.calib.wasSkipped ~= 1 && isfield(me.calib,'selectedCal')
				try
					calMsg = me.tobii.getValidationQualityMessage(me.calib);
					fprintf('\n-+-+-> CAL RESULT = ');
					disp(calMsg);
					if isempty(me.validationData)
						me.validationData{1} = calMsg;
					else
						me.validationData{end+1} = calMsg;
					end
					me.calib.v = calMsg;
				end
			else
 				disp('-+-+!!! The calibration was unsuccesful or skipped !!!+-+-')
			end
			resetAll(me);
			if wasRecording; startRecording(me,true); end
		end
		
		% ===================================================================
		%> @brief wrapper for StartRecording
		%>
		%> @param override - to keep compatibility with the eyelinkManager
		%> API we need to only start and stop recording using a passed
		%> parameter, as the eyelink requires start and stop on every trial
		%> but the tobii does not. So by default without override==true this
		%> will just return.
		% ===================================================================
		function startRecording(me, override)
			if ~exist('override','var') || isempty(override) || override==false; return; end
			if me.isConnected
				success = me.tobii.buffer.start('gaze');
				if success
					me.statusMessage('Starting to record gaze...');
				else
					warning('Can''t START buffer() GAZE recording!!!')
				end
				success = me.tobii.buffer.start('positioning');
				if success
					me.statusMessage('Starting to record Position...');
				else
					warning('Can''t START buffer() Position recording!!!')
				end
				success = me.tobii.buffer.start('externalSignal');
				if success
					me.statusMessage('Starting to record TTLs...');
				else
					warning('Can''t START buffer() TTL recording!!!')
				end
				success = me.tobii.buffer.start('timeSync');
				if success
					me.statusMessage('Starting to record timeSync...');
				else
					warning('Can''t START buffer() timeSync recording!!!')
				end
			end
			me.isRecording = me.tobii.buffer.isRecording('gaze');
		end
		
		% ===================================================================
		%> @brief wrapper for StopRecording
		%>
		%> @param override - to keep compatibility with the eyelinkManager
		%> API we need to only start and stop recording using a passed
		%> parameter, as the eyelink requires start and stop on every trial
		%> but the tobii does not. So by default without override==true this
		%> will just return.
		% ===================================================================
		function stopRecording(me, override)
			if ~exist('override','var') || isempty(override) || override~=true; return; end
			try
				if me.tobii.buffer.hasStream('eyeImage') && me.tobii.buffer.isRecording('eyeImage')
					success = me.tobii.buffer.stop('eyeImage');
					if success
						me.statusMessage('Stopping to record eyeImage...');
					else
						warning('Can''t STOP buffer() eyeImage recording!!!')
					end
				end
				if me.tobii.buffer.isRecording('timeSync')
					success = me.tobii.buffer.stop('timeSync');
					if success
						me.statusMessage('Stopping to record timeSync...');
					else
						warning('Can''t STOP buffer() timeSync recording!!!')
					end
				end
				if me.tobii.buffer.isRecording('externalSignal')
					success = me.tobii.buffer.stop('externalSignal');
					if success
						me.statusMessage('Stopping to record TTLs...');
					else
						warning('Can''t STOP buffer() TTL recording!!!')
					end
				end
				if me.tobii.buffer.isRecording('positioning')
					success = me.tobii.buffer.stop('positioning');
					if success
						me.statusMessage('Stopping to record Position...');
					else
						warning('Can''t STOP buffer() TTL recording!!!')
					end
				end
				success = me.tobii.buffer.stop('gaze');
				if success
					me.statusMessage('Stopping to record Gaze...');
				else
					warning('Can''t STOP buffer() GAZE recording!!!')
				end
				
				me.isRecording = me.tobii.buffer.isRecording('gaze'); 
			end
		end

		% ===================================================================
		function sample = getSample(me)
		%> @fn getSample()
		%> @brief get a sample from the tracker, if dummymode=true then use
		%> the mouse as an eye signal
		%>
		% ===================================================================
			if me.isOff; return; end
			if me.isDummy %lets use a mouse to simulate the eye signal
				sample = getMouseSample(me);
			elseif me.isConnected && me.isRecording
				sample			= me.sampleTemplate;
				xy				= [];
				td				= me.tobii.buffer.peekN('gaze',me.smoothing.nSamples);
				if isempty(td);me.currentSample=sample;return;end
				sample.raw		= td;
				if any(td.left.gazePoint.valid) || any(td.right.gazePoint.valid)
					if isfield(td,'systemTimeStamp') && ~isempty(td.systemTimeStamp)
						sample.time		= double(td.systemTimeStamp(end)) / 1e6; %remember these are in microseconds
					else
						sample.time = [];
					end
					if isfield(td,'deviceTimeStamp') && ~isempty(td.deviceTimeStamp)
						sample.timeD	= double(td.deviceTimeStamp(end)) / 1e6;
					else
						sample.timeD = [];
					end
					sample.timeD2	= GetSecs;
					switch me.smoothing.eyes
						case 'left'
							xy	= td.left.gazePoint.onDisplayArea(:,td.left.gazePoint.valid);
						case 'right'
							xy	= td.right.gazePoint.onDisplayArea(:,td.right.gazePoint.valid);
						otherwise
							if all(td.left.gazePoint.valid & td.right.gazePoint.valid)
								v = td.left.gazePoint.valid & td.right.gazePoint.valid;
								xy = [td.left.gazePoint.onDisplayArea(:,v);...
									td.right.gazePoint.onDisplayArea(:,v)];
							else
								xy = [td.left.gazePoint.onDisplayArea(:,td.left.gazePoint.valid),...
									td.right.gazePoint.onDisplayArea(:,td.right.gazePoint.valid)];
							end
					end
				end
				if ~isempty(xy)
					me.xAllRaw	= [me.xAllRaw xy(1,:)];
					me.yAllRaw	= [me.yAllRaw xy(2,:)];
					sample.valid = true;
					xy			= doSmoothing(me,xy);
					xy			= toPixels(me, xy,'','relative');
					sample.gx	= xy(1);
					sample.gy	= xy(2);
					sample.pa	= nanmean(td.left.pupil.diameter);
					xyd	= me.toDegrees(xy);
					me.x = xyd(1); me.y = xyd(2);
					me.pupil	= sample.pa;
					if me.debug;fprintf('>>X: %2.2f | Y: %2.2f | P: %.2f\n',me.x,me.y,me.pupil);end
				else
					sample.gx	= NaN;
					sample.gy	= NaN;
					sample.pa	= NaN;
					me.x		= NaN;
					me.y		= NaN;
					me.pupil	= NaN;
				end
				me.xAll			= [me.xAll me.x];
				me.yAll			= [me.yAll me.y];
				me.pupilAll		= [me.pupilAll me.pupil];
			else
				sample			= me.sampleTemplate;
				if me.debug;fprintf('-+-+-> tobiiManager.getSample(): are you sure you are recording?\n');end
			end
			me.currentSample	= sample;
		end
		
		% ===================================================================
		%> @brief draw N last eye position on the PTB display
		%>
		% ===================================================================
		function drawEyePositions(me,dataDur)
			if (~me.isDummy || me.isConnected) && me.screen.isOpen
				nDataPoint  = ceil(dataDur/1000*fs);
				eyeData     = me.tobii.buffer.peekN('gaze',nDataPoint);
				pointSz		= 3;
				point       = pointSz.*[0 0 1 1];
				if ~isempty(eyeData.systemTimeStamp)
					age=double(abs(eyeData.systemTimeStamp-eyeData.systemTimeStamp(end)))/1000;
					if qShowLeft
						qValid = eyeData.left.gazePoint.valid;
						lE = bsxfun(@times,eyeData.left.gazePoint.onDisplayArea(:,qValid),me.screen.screenVals.winRect(3:4));
						if ~isempty(lE)
							clrs = interp1([0;dataDur],[1 0 1 1],age(qValid)).';
							lE = CenterRectOnPointd(point,lE(1,:).',lE(2,:).');
							Screen('FillOval', me.win, clrs, lE.', 2*pi*pointSz);
						end
					end
					if qShowRight
						qValid = eyeData.right.gazePoint.valid;
						rE = bsxfun(@times,eyeData.right.gazePoint.onDisplayArea(:,qValid),me.screen.screenVals.winRect(3:4));
						if ~isempty(rE)
							clrs = interp1([0;dataDur],[1 1 0 1],age(qValid)).';
							rE = CenterRectOnPointd(point,rE(1,:).',rE(2,:).');
							Screen('FillOval', me.win, clrs, rE.', 2*pi*pointSz);
						end
					end
				end
			end
		end

		% ===================================================================
		%> @brief Save the data
		%>
		% ===================================================================
		function saveData(me,tofile)
			if ~exist('tofile','var') || isempty(tofile); tofile = true; end
			ts = tic;
			me.data = [];
			if me.isConnected && ~me.isCollectedData
				me.data = me.tobii.collectSessionData();
				me.isCollectedData = true;
			end
			if ~isempty(me.data) && tofile
				tobii = me;
				if exist(me.saveFile,'file')
					initialiseSaveFile(me);
					[p,f,e] = fileparts(me.saveFile);
					me.saveFile = [p filesep me.savePrefix '-' f '.mat'];
				end
				try
					save(me.saveFile,'tobii');
					disp('===========================')
					me.salutation('saveData',sprintf('Save: %s in %.1fms\n',strrep(me.saveFile,'\','/'),toc(ts)*1e3),true);
					disp('===========================')
					clear tobii
				catch ERR
					warning('Save FAILED: %s in %.1fms\n',strrep(me.saveFile,'\','/'),toc(ts)*1e3);
					getReport(ERR);
				end
			elseif isempty(me.data)
				disp('===========================')
				me.salutation('saveData',sprintf('NO data available... (%.1fms)...\n',toc(ts)*1e3),true);
				disp('===========================')
			elseif ~isempty(me.data)
				disp('===========================')
				me.salutation('saveData',sprintf('Data retrieved to object in %.1fms)...\n',toc(ts)*1e3),true);
				disp('===========================')
			end
		end
		
		% ===================================================================
		%> @brief send message to store in tracker data
		%>
		%>
		% ===================================================================
		function trackerMessage(me, message, vbl)
			if me.isConnected
				if exist('vbl','var')
					me.tobii.sendMessage(message, vbl);
				else
					me.tobii.sendMessage(message);
				end
				if me.verbose; fprintf('-+-+->TOBII Message: %s\n',message);end
			end
		end

		% ===================================================================
		%> @brief close the tobii and cleanup
		%> is enabled
		%>
		% ===================================================================
		function close(me)
			try
				try stopRecording(me,true); end
				if me.recordData && ~me.isCollectedData
					saveData(me,false);
				end
				out = me.tobii.deInit();
				me.isConnected = false;
				me.isRecording = false;
				resetFixation(me);
				if me.secondScreen && ~isempty(me.operatorScreen) && isa(me.operatorScreen,'screenManager')
					try me.operatorScreen.close; end
				end
			catch ME
				me.salutation('Close Method','Couldn''t stop recording, forcing shutdown...',true)
				me.tobii.deInit();
				me.isConnected = false;
				me.isRecording = false;
				resetFixation(me);
				if me.secondScreen && ~isempty(me.operatorScreen) && isa(me.operatorScreen,'screenManager')
					me.operatorScreen.close;
				end
				getReport(ME);
			end
		end

		% ===================================================================
		%> @brief
		%>
		% ===================================================================
		function updateDefaults(me)
			if isa(me.tobii, 'Titta')
				me.tobii.setOptions(me.settings);
			end
		end

		% ===================================================================
		%> @brief check the connection with the tobii
		%>
		% ===================================================================
		function connected = checkConnection(me)
			if isa(me.tobii,'Titta')
				me.isConnected = true;
			else
				me.isConnected = false;
			end
			connected = me.isConnected;
		end
		
		% ===================================================================
		%> @brief Sync time with tracker
		%>
		% ===================================================================
		function syncTrackerTime(me)
			if me.isConnected
				me.tobii.getSystemTime;
			end
		end
		
		% ===================================================================
		%> @brief Train to use tracker
		%>
		% ===================================================================
		function runTimingTest(me,sRate,interval)
			ofilename = me.saveFile;
			me.initialiseSaveFile();
			[p,~,e]=fileparts(me.saveFile);
			me.saveFile = [p filesep 'tobiiTimingTest-' me.savePrefix e];
			try
				if isa(me.screen,'screenManager') && ~isempty(me.screen)
					s = me.screen;
				else
					s = screenManager('blend',true,'pixelsPerCm',36,'distance',60);
				end
				s.disableSyncTests = false;
				s.backgroundColour = [0.5 0.5 0.5 0];
				me.sampleRate = sRate;
				sv=open(s); %open our screen
				initialise(me,s); %initialise tobii with our screen
				trackerSetup(me);
				ShowCursor; %titta fails to show cursor so we must do it
				Priority(MaxPriority(s.win));
				startRecording(me);
				WaitSecs('YieldSecs',1);
				drawCross(s);
				vbl = flip(s);
				trackerMessage(me,'STARTVBL',vbl);
				sampleInterval = interval;
				nSamples = 2000;
				ti = zeros(nSamples,1) * NaN;
				tx = zeros(nSamples,1) * NaN;
				tj = zeros(nSamples,1);
				for i = 1 : nSamples
					td = me.tobii.buffer.peekN('gaze',1);
					if ~isempty(td)
						ti(i) = double(td.systemTimeStamp);
						tx(i) = td.left.gazePoint.onDisplayArea(1);
					end
					tj(i) = WaitSecs(sampleInterval);
				end
				vbl=flip(s);
				trackerMessage(me,'ENDVBL',vbl);
				ti = (ti - ti(1)) / 1e3;
				tj = (tj - tj(1)) * 1e3;
				sdi = std(diff(ti));
				sdj = std(diff(tj));
				WaitSecs('YieldSecs',0.5);
				assignin('base','ti',ti);
				assignin('base','tj',tj);
				assignin('base','ti',ti);
				assignin('base','tx',tx);
				figure;
				subplot(2,1,1);
				plot(diff(tj),'LineWidth',1.5);set(gca,'YScale','linear');ylabel('Time Delta (ms)');xlabel(['PTB Timestamp SD=' num2str(sdj) 'ms']);
				ylim([0 max(diff(ti))]);line([0 nSamples],[sampleInterval*1e3 sampleInterval*1e3],'LineStyle','-.','LineWidth',1,'Color','red');
				title(['Sample Interval: ' num2str(sampleInterval*1e3) 'ms | Tobii Sample Rate: ' num2str(sRate) 'hz']);
				legend('Raw Timestamps','Sample Interval')
				subplot(2,1,2);
				plot(diff(ti),'LineWidth',1.5);set(gca,'YScale','linear');ylabel('Time Delta (ms)');xlabel(['Tobii Timestamp SD=' num2str(sdi) 'ms']);
				ylim([0 max(diff(ti))]);line([0 nSamples],[sampleInterval*1e3 sampleInterval*1e3],'LineStyle','-.','LineWidth',1,'Color','red');
				ListenChar(0); Priority(0); ShowCursor;
				stopRecording(me);
				close(s);
				saveData(me,false);
				close(me);
				me.saveFile = ofilename;
				clear s
			catch ME
				ListenChar(0);Priority(0);ShowCursor;
				me.saveFile = ofilename;
				getReport(ME)
				close(s);
				sca;
				close(me);
				clear s
				rethrow(ME)
			end
		end
		
		% ===================================================================
		%> @brief runs a demo of the tobii workflow, testing this class
		%>
		% ===================================================================
		function runDemo(me,forcescreen)
			PsychDefaultSetup(2);
			stopKey				= KbName('q');
			upKey				= KbName('uparrow');
			downKey				= KbName('downarrow');
			leftKey				= KbName('leftarrow');
			rightKey			= KbName('rightarrow');
			calibKey			= KbName('c');
			ofixation			= me.fixation; 
			me.sampletime		= [];
			osmoothing			= me.smoothing;
			ofilename			= me.saveFile;
			oldexc				= me.exclusionZone;
			oldfixinit			= me.fixInit;
			me.initialiseSaveFile();
			[p,~,e]				= fileparts(me.saveFile);
			me.saveFile			= [p filesep 'tobiiRunDemo-' me.savePrefix e];
			useS2				= false;
			try
				if isa(me.screen,'screenManager') && ~isempty(me.screen)
					s = me.screen;
				else
					s = screenManager('blend',true,'pixelsPerCm',36,'distance',60,'disableSyncTests',true);
				end
				
				if exist('forcescreen','var'); s.screen = forcescreen; end
				s.backgroundColour		= [0.5 0.5 0.5 0];
			
				if ~s.isOpen; sv=open(s); else; sv=s.screenVals; end
				initialise(me, s);
				if me.useOperatorScreen; s2 = me.operatorScreen; end
				if ~s2.isOpen; open(s2); useS2 = true; end
				
				trackerSetup(me); ShowCursor;

				drawPhotoDiodeSquare(s,[0 0 0 1]); flip(s); %make sure our photodiode patch is black
				
				% set up the size and position of the stimulus
				o = dotsStimulus('size',me.fixation.radius(1)*2,'speed',2,'mask',true,'density',50); %test stimulus
				if length(me.fixation.radius) == 1
					f = discStimulus('size',me.fixation.radius(1)*2,'colour',[0 0 0],'alpha',0.25);
				else
					f = barStimulus('barWidth',me.fixation.radius(1)*2,'barHeight',me.fixation.radius(2)*2,...
						'colour',[0 0 0],'alpha',0.25);
				end
				setup(o,s); %setup our stimulus with open screen
				setup(f,s); %setup our stimulus with open screen
				o.xPositionOut = me.fixation.X;
				o.yPositionOut = me.fixation.Y;
				f.alpha;
				f.xPositionOut = me.fixation.X;
				f.xPositionOut = me.fixation.X;
				
				% set up an exclusion zone where eye is not allowed
				me.exclusionZone = [8 10 8 10];
				exc = me.toPixels(me.exclusionZone);
				exc = [exc(1) exc(3) exc(2) exc(4)]; %psychrect=[left,top,right,bottom] 

				RestrictKeysForKbCheck([stopKey upKey downKey leftKey rightKey calibKey]);
			
				% warm up
				fprintf('\n===>>> Warming up the GPU, Eyetracker etc... <<<===\n')
				Priority(MaxPriority(s.win));
				%HideCursor(s.win);
				endExp = 0;
				trialn = 1;
				maxTrials = 10;
				psn = cell(maxTrials,1);
				m=1; n=1;
				methods={'median','heuristic1','heuristic2','sg','simple'};
				eyes={'both','left','right'};
				if ispc; Screen('TextFont',s.win,'Consolas'); end
				sgolayfilt(rand(10,1),1,3); %warm it up
				me.heuristicFilter(rand(10,1), 2);
				startRecording(me, true);
				WaitSecs('YieldSecs',1);
				for i = 1 : s.screenVals.fps
					draw(o);draw(f);
					drawBackground(s);
					drawPhotoDiodeSquare(s,[0 0 0 1]);
					Screen('DrawText',s.win,['Warm up frame: ' num2str(i)],65,10);
					finishDrawing(s);
					animate(o);
					getSample(me); isFixated(me); resetFixation(me);
					flip(s);
				end
				drawPhotoDiodeSquare(s,[0 0 0 1]);
				flip(s);
				if useS2;flip(s2);end
				ListenChar(-1); % ListenChar(0);
				update(o); %make sure stimuli are set back to their start state
				update(f);
				WaitSecs('YieldSecs',0.5);
				trackerMessage(me,'!!! Starting Demo...')
				while trialn <= maxTrials && endExp == 0
					trialtick = 1;
					trackerMessage(me,sprintf('Settings for Trial %i, X=%.2f Y=%.2f, SZ=%.2f',trialn,me.fixation.X,me.fixation.Y,o.sizeOut))
					drawPhotoDiodeSquare(s,[0 0 0 1]);
					vbl = flip(s); tstart=vbl+sv.ifi;
					if useS2;flip(s2,[],[],2);end
					trackerMessage(me,'STARTVBL',vbl);
					while vbl < tstart + 6
						Screen('FillRect',s.win,[0.7 0.7 0.7 0.5],exc); Screen('DrawText',s.win,'Exclusion Zone',exc(1),exc(2),[0.8 0.8 0.8]);
						draw(o); draw(f);
						drawGrid(s);
						drawCross(s,0.5,[1 1 0],me.fixation.X,me.fixation.Y);
						drawPhotoDiodeSquare(s,[1 1 1 1]);
						
						getSample(me); isFixated(me);
						
						if ~isempty(me.currentSample)
							txt = sprintf('Q = finish. X: %3.1f / %2.2f | Y: %3.1f / %2.2f | # = %2i %s %s | RADIUS = %s | TIME = %.2f | FIXATION %i = %.2f (buffer: %.2f) | EXC = %i | INIT FAIL = %i',...
								me.currentSample.gx, me.x, me.currentSample.gy, me.y, me.smoothing.nSamples,...
								me.smoothing.method, me.smoothing.eyes, sprintf('%1.1f ',me.fixation.radius), ...
								me.fixTotal,me.fixN,me.fixLength,me.fixBuffer,me.isExclusion,me.isInitFail);
							Screen('DrawText', s.win, txt, 10, 10,[1 1 1]);
							drawEyePosition(me);
							%psn{trialn} = me.tobii.buffer.peekN('positioning',1);
						end
						if useS2
							drawGrid(s2);
							trackerDrawExclusion(me);
							trackerDrawFixation(me);
							trackerDrawEyePosition(me);
						end
						finishDrawing(s);
						animate(o);
						
						vbl(end+1) = Screen('Flip', s.win, vbl(end) + s.screenVals.halfifi);
						if trialtick==1; me.tobii.sendMessage('SYNC = 255', vbl);end
						if useS2; flip(s2,[],[],2); end
						[keyDown, ~, keyCode] = KbCheck(-1);
						if keyDown
							if keyCode(stopKey); endExp = 1; break;
							elseif keyCode(calibKey); me.trackerSetup;
							elseif keyCode(upKey); me.smoothing.nSamples = me.smoothing.nSamples + 1; if me.smoothing.nSamples > 400; me.smoothing.nSamples=400;end
							elseif keyCode(downKey); me.smoothing.nSamples = me.smoothing.nSamples - 1; if me.smoothing.nSamples < 1; me.smoothing.nSamples=1;end
							elseif keyCode(leftKey); m=m+1; if m>5;m=1;end; me.smoothing.method=methods{m};
							elseif keyCode(rightKey); n=n+1; if n>3;n=1;end; me.smoothing.eyes=eyes{n};
							end
						end
						trialtick=trialtick+1;
					end
					if endExp == 0
						drawPhotoDiodeSquare(s,[0 0 0 1]);
						vbl = flip(s);
						if useS2; flip(s2,[],[],2); end
						trackerMessage(me,'END_RT',vbl);
						trackerMessage(me,'TRIAL_RESULT 1');
						trackerMessage(me,sprintf('Ending trial %i @ %i',trialn,int64(round(vbl*1e6))));
						resetFixation(me);
						if length(me.fixation.radius) == 1
							r = randi([1 3]);
							o.sizeOut = me.fixation.radius * 2;
							f.sizeOut = me.fixation.radius * 2;
						else
							r = [randi([1 3]) randi([1 3])];
							o.sizeOut = mean(me.fixation.radius) * 2;
							f.barWidthOut = me.fixation.radius(1) * 2;
							f.barHeightOut = me.fixation.radius(2) * 2;
						end
						updateFixationValues(me,randi([-7 7]),randi([-7 7]));
						o.xPositionOut = me.fixation.X;
						o.yPositionOut = me.fixation.Y;
						f.xPositionOut = me.fixation.X;
						f.yPositionOut = me.fixation.Y;
						update(o);update(f);
						WaitSecs(0.3);
						trialn = trialn + 1;
					else
						drawPhotoDiodeSquare(s,[0 0 0 1]);
						vbl = flip(s);
						if useS2; flip(s2,[],[],2); end
						trackerMessage(me,'END_RT',vbl);
						trackerMessage(me,'TRIAL_RESULT -10 ABORT');
						trackerMessage(me,sprintf('Aborting %i @ %i', trialn, int64(round(vbl*1e6))));
					end
				end
				stopRecording(me,true);
				ListenChar(0); Priority(0); ShowCursor; RestrictKeysForKbCheck([]);
				try close(s); if useS2;close(s2);end; end %#ok<*TRYNC>
				saveData(me);
				assignin('base','psn',psn);
				assignin('base','data',me.data);
				close(me);
				me.fixation = ofixation;
				me.saveFile = ofilename;
				me.smoothing = osmoothing;
				me.exclusionZone = oldexc;
				me.fixInit = oldfixinit;
				clear s s2 o
			catch ME
				try stopRecording(me,true); end
				me.fixation = ofixation;
				me.saveFile = ofilename;
				me.smoothing = osmoothing;
				me.exclusionZone = oldexc;
				me.fixInit = oldfixinit;
				ListenChar(0); Priority(0); ShowCursor; RestrictKeysForKbCheck([]);
				getReport(ME)
				try close(s); end
				try if useS2;close(s2);end; end
				sca;
				try close(me); end
				clear s s2 o
				rethrow(ME);
			end
			
		end
		
		% ===================================================================
		%> @brief
		%>
		% ===================================================================
		function value = checkRecording(me)
			if me.isConnected
				value = me.tobii.buffer.isRecording('gaze');
			else
				value = false;
			end
			me.isRecording = value;
		end
		
	end%-------------------------END PUBLIC METHODS--------------------------------%
	
	%============================================================================
	methods (Hidden = true) %--HIDDEN METHODS (compatibility with eyelinkManager)
		%============================================================================
		
		% ===================================================================
		%> @brief checks which eye is available, force left eye if
		%> binocular is enabled
		%>
		% ===================================================================
		function eyeUsed = checkEye(me)
			if me.isConnected
				eyeUsed = me.eyeUsed;
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
		%> @brief send message to store in tracker data (compatibility)
		%>
		%>
		% ===================================================================
		function edfMessage(me, message)
			trackerMessage(me,message)
		end
		
		% ===================================================================
		%> @brief
		%>
		% ===================================================================
		function setup(me)
			updateDefaults(me)
		end
		
		% ===================================================================
		%> @brief set into offline / idle mode
		%>
		% ===================================================================
		function setOffline(me)
			
		end
		
		% ===================================================================
		%> @brief wrapper for EyelinkDoDriftCorrection
		%>
		% ===================================================================
		function success = driftCorrection(me)
			success = driftOffset(me);
		end
		
		% ===================================================================
		%> @brief check what mode the tobii is in
		%>
		% ========================a===========================================
		function mode = currentMode(me)
			if me.isConnected
				mode = 0;
			end
		end
		
		% ===================================================================
		%> @brief Sync time with tracker
		%>
		% ===================================================================
		function syncTime(me)
			trackerMessage(me,'SYNCTIME');
		end
		
		
		% ===================================================================
		%> @brief Get offset between tracker and display computers
		%>
		% ===================================================================
		function offset = getTimeOffset(me)
			offset = 0;
		end
		
		% ===================================================================
		%> @brief Get tracker time
		%>
		% ===================================================================
		function [trackertime, systemtime] = getTrackerTime(me)
			if me.isConnected
				trackertime = 0;
				systemtime = 0;
			end
		end
		
		% ===================================================================
		%> @brief TODO
		%>
		% ===================================================================
		function evt = getEvent(me)
			
		end
		
	end%-------------------------END HIDDEN METHODS--------------------------------%
	
	%=======================================================================
	methods (Access = private) %------------------PRIVATE METHODS
	%=======================================================================
		
		% ===================================================================
		%> @brief
		%>
		% ===================================================================
		function initTracker(me)
			if isempty(me.settings)
				me.settings = Titta.getDefaults(me.calibration.model);
			end
			me.tobii = Titta(me.settings);
		end
		
	end %------------------END PRIVATE METHODS
end

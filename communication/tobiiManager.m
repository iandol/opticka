% ========================================================================
classdef tobiiManager < eyetrackerCore
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
%> @todo refactor this and eyelinkManager to inherit from a common eyelinkManager
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
		calibration		= struct('model','Tobii Pro Spectrum','mode','human',...
							'stimulus','animated','calPositions',[],'valPositions',[],...
							'manual', false, 'autoPace',true,'paceDuration',0.8,'eyeUsed','both',...
							'movie',[])
		%> options for online smoothing of peeked data {'median','heuristic','savitsky-golay'}
		smoothing		= struct('nSamples',8,'method','median','window',3,...
							'eyes','both')
	end
	
	properties (Hidden = true)
		%> Titta settings structure
		settings struct	= []
		%> Titta class object
		tobii
		%> 
		sampletime		= []
		%>
		calib
	end
	
	properties (SetAccess = protected, GetAccess = public, Dependent = true)
		% calculates the smoothing in ms
		smoothingTime double
	end
	
	properties (SetAccess = protected, GetAccess = protected)
		%> tracker time stamp
		systemTime		= 0
		calibData
		calStim
		%> allowed properties passed to object upon construction
		allowedProperties = {'calibration', 'settings','useOperatorScreen','smoothing'}
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
			args = optickaCore.addDefaults(varargin,struct('name','Tobii','sampleRate',300));
			me=me@eyetrackerCore(args); %we call the superclass constructor first
			me.parseArgs(args, me.allowedProperties);
			
			try % is tobii working?
				assert(exist('Titta','class')==8,'TOBIIMANAGER:NO-TITTA','Cannot find Titta toolbox, please install instead of Tobii SDK; exiting...');
				initTracker(me);
				assert(isa(me.tobii,'Titta'),'TOBIIMANAGER:INIT-ERROR','Cannot Initialise...')
			catch ME
				ME.getReport
				fprintf('!!! Error initialising Tobii: %s\n\t going into Dummy mode...\n',ME.message);
				me.tobii = [];
				me.isDummy = true;
			end
			if contains(me.calibration.model,{'Tobii 4C','IS4_Large_Peripheral'})
				me.model = 'IS4_Large_Peripheral';
				me.sampleRate = 90; 
				me.calibration.mode = 'Default';
			end
			p = fileparts(me.saveFile);
			if isempty(p)
				me.saveFile = [me.paths.savedData filesep me.saveFile];
			end
		end
		
		% ===================================================================
		%> @brief initialise the tobii.
		%>
		%> @param sM - screenManager object we will use
		%> @param sM2 - a second screenManager used during calibration
		% ===================================================================
		function success = initialise(me,sM,sM2)
			if ~exist('sM','var') || isempty(sM)
				if isempty(me.screen) || ~isa(me.screen,'screenManager')
					me.screen		= screenManager();
				end
			else
				me.screen			= sM;
			end
			if me.useOperatorScreen && ~exist('sM2','var')
				sM2 = screenManager('windowed',[0 0 1000 1000],'pixelsPerCm',25,...
					'disableSyncTests',true,'backgroundColour',sM.backgroundColour,...
					'specialFlags', kPsychGUIWindow);
			end
			if ~exist('sM2','var') || ~isa(sM2,'screenManager')
				me.secondScreen		= false;
			else
				me.operatorScreen	= sM2;
				me.secondScreen		= true;
			end
			if contains(me.calibration.model,{'Tobii 4C','IS4_Large_Peripheral'})
				me.calibration.model = 'IS4_Large_Peripheral';
				me.sampleRate = 90; 
				me.calibration.mode = 'Default';
			end
			if ~isa(me.tobii, 'Titta') || isempty(me.tobii); initTracker(me); end
			assert(isa(me.tobii,'Titta'),'TOBIIMANAGER:INIT-ERROR','Cannot Initialise...')
			
			if me.isDummy
				me.tobii			= me.tobii.setDummyMode();
			end
			
			me.settings								= Titta.getDefaults(me.calibration.model);
			if ~contains(me.calibration.model,{'Tobii 4C','IS4_Large_Peripheral'})
				me.settings.freq					= me.sampleRate;
				me.settings.trackingMode			= me.calibration.mode;
			end
			me.settings.calibrateEye				= me.calibration.eyeUsed;
			me.settings.cal.bgColor					= floor(me.screen.backgroundColour*255);
			me.settings.UI.setup.bgColor			= me.settings.cal.bgColor;
			me.settings.UI.setup.showFixPointsToSubject		= false;
			me.settings.UI.setup.showHeadToSubject			= true;   
			me.settings.UI.setup.showInstructionToSubject	= true;
			me.settings.UI.setup.eyeClr						= 255;
			if strcmpi(me.calibration.stimulus,'animated')
				me.calStim							= AnimatedCalibrationDisplay();
				me.calStim.moveTime					= 0.75;
				me.calStim.oscillatePeriod			= 1;
				me.calStim.blinkCount				= 4;
				me.calStim.bgColor					= me.settings.cal.bgColor;
				me.calStim.fixBackColor				= 0;
				me.calStim.fixFrontColor			= 255;
				me.settings.cal.drawFunction		= @(a,b,c,d,e,f) me.calStim.doDraw(a,b,c,d,e,f);
				if me.calibration.manual;me.settings.mancal.drawFunction	= @(a,b,c,d,e,f) me.calStim.doDraw(a,b,c,d,e,f);end
			elseif strcmpi(me.calibration.stimulus,'movie')
				me.calStim							= tittaCalMovieStimulus();
				me.calStim.moveTime					= 0.75;
				me.calStim.oscillatePeriod			= 1;
				me.calStim.blinkCount				= 3;
				if isempty(me.calibration.movie)
					me.calibration.movie			= movieStimulus('size',4);
				end
				reset(me.calibration.movie);
				setup(me.calibration.movie, me.screen);
				me.calStim.initialise(me.calibration.movie);
				me.settings.cal.drawFunction		= @(a,b,c,d,e,f) me.calStim.doDraw(a,b,c,d,e,f);
				if me.manualCalibration;me.settings.mancal.drawFunction	= @(a,b,c,d,e,f) me.calStim.doDraw(a,b,c,d,e,f);end
			end
			me.settings.cal.autoPace				= me.calibration.autoPace;
			me.settings.cal.paceDuration			= me.calibration.paceDuration;
			if me.calibration.autoPace
				me.settings.cal.doRandomPointOrder	= true;
			else
				me.settings.cal.doRandomPointOrder	= false;
			end
			if ~isempty(me.calibration.calPositions)
				me.settings.cal.pointPos			= me.calPositions;
			end
			if ~isempty(me.calibration.valPositions)
				me.settings.val.pointPos			= me.valPositions;
			end
			
			me.settings.cal.pointNotifyFunction	= @tittaCalCallback;
			me.settings.val.pointNotifyFunction	= @tittaCalCallback;
			
			if me.calibration.manual
				me.settings.UI.mancal.bgColor		= floor(me.screen.backgroundColour*255);
				me.settings.mancal.bgColor			= floor(me.screen.backgroundColour*255);
				me.settings.mancal.cal.pointPos		= me.calibration.calPositions;
				me.settings.mancal.val.pointPos		= me.calibration.valPositions;
				me.settings.mancal.cal.paceDuration	= me.calibration.paceDuration;
				me.settings.mancal.val.paceDuration	= me.calibration.paceDuration;
				me.settings.UI.mancal.showHead		= true;
				me.settings.UI.mancal.headScale		= 0.4;
				me.settings.mancal.cal.pointNotifyFunction	= @tittaCalCallback;
				me.settings.mancal.val.pointNotifyFunction	= @tittaCalCallback;
			end
			updateDefaults(me);
			me.tobii.init();
			me.isConnected							= true;
			me.systemTime							= me.tobii.getTimeAsSystemTime;
			me.ppd_									= me.screen.ppd;
			if me.screen.isOpen == true
				me.win								= me.screen.win;
			end
			
			if ~me.isDummy
				me.salutation('Initialise', ...
					sprintf('Running on a %s (%s) @ %iHz mode:%s | Screen %i %i x %i @ %iHz', ...
					me.tobii.systemInfo.model, ...
					me.tobii.systemInfo.deviceName,...
					me.tobii.systemInfo.frequency,...
					me.tobii.systemInfo.trackingMode,...
					me.screen.screen,...
					me.screen.winRect(3),...
					me.screen.winRect(4),...
					me.screen.screenVals.fps),true);
			else
				me.salutation('Initialise', 'Running in Dummy Mode', true);
			end
			success = true;
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
			connected = false;
			if isa(me.tobii,'Titta') && me.tobii.isInitialized
				connected = true;
			end
		end
		
		% ===================================================================
		%> @brief sets up the calibration and validation
		%>
		% ===================================================================
		function cal = trackerSetup(me,incal)
			ListenChar(0); RestrictKeysForKbCheck([]);
			cal = [];
			if ~me.isConnected 
				warning('Eyetracker not connected, cannot calibrate!');
				return
			end

			if ~me.screen.isOpen; open(me.screen); end
			if ~me.operatorScreen.isOpen; open(me.operatorScreen); end

			if me.isDummy
				disp('--->>> Tobii Dummy Mode: calibration skipped')
				return;
			end
			fprintf('\n===>>> CALIBRATING TOBII... <<<===\n');
			if ~exist('incal','var');incal=[];end
			wasRecording = me.isRecording;
			if wasRecording; stopRecording(me);	end
			updateDefaults(me); % make sure we send any other settings changes
			
			ListenChar(-1);
			if me.calibration.manual
				if ~isempty(incal) && isstruct(incal) && isfield(incal,'type') && contains(incal.type,'manual')
					me.calib = me.tobii.calibrateManual([me.screen.win me.operatorScreen.win], incal); 
				else
					me.calib = me.tobii.calibrateManual([me.screen.win me.operatorScreen.win]);
				end
			else
				if ~isempty(incal) && isstruct(incal) && isfield(incal,'type') && contains(incal.type,'standard')
					me.calib = me.tobii.calibrate([me.screen.win me.operatorScreen.win], [], incal); 
				else
					me.calib = me.tobii.calibrate([me.screen.win me.operatorScreen.win]);
				end
			end
			ListenChar(0);

			if strcmpi(me.calibration.stimulus,'movie')
				me.calStim.movie.reset();
				%me.calStim.movie.setup(me.screen);
			end

			if ~isempty(me.calib) && me.calib.wasSkipped ~= 1
				cal = me.calib;
				if isfield(me.calib,'selectedCal')
					try
						calMsg = me.tobii.getValidationQualityMessage(me.calib);
						fprintf('-+-+-> CAL RESULT = ');
						disp(calMsg);
					end
				end
			else
 				disp('-+-+!!! The calibration was unsuccesful or skipped !!!+-+-')
			end
			resetAll(me);
			if wasRecording; startRecording(me); end
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
			if ~exist('override','var') || isempty(override) || override~=true; return; end
			if me.isConnected && ~me.isRecording
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
			me.isRecording = true;
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
			if me.isConnected && me.isRecording
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
			end
			me.isRecording = false;
		end

		% ===================================================================
		%> @brief get a sample from the tracker, if dummymode=true then use
		%> the mouse as an eye signal
		%>
		% ===================================================================
		function sample = getSample(me)
			sample				= me.sampleTemplate;
			if me.isDummy %lets use a mouse to simulate the eye signal
				if ~isempty(me.win)
					[mx, my]	= GetMouse(me.win);
				else
					[mx, my]	= GetMouse([]);
				end
				sample.valid	= true;
				me.pupil		= 5 + randn;
				sample.gx		= mx;
				sample.gy		= my;
				sample.pa		= me.pupil;
				sample.time		= GetSecs;
				xy				= me.toDegrees([sample.gx sample.gy]);
				me.x = xy(1); me.y = xy(2);
				me.xAll			= [me.xAll me.x];
				me.yAll			= [me.yAll me.y];
				me.pupilAll		= [me.pupilAll me.pupil];
				%if me.verbose;fprintf('>>X: %.2f | Y: %.2f | P: %.2f\n',me.x,me.y,me.pupil);end
			elseif me.isConnected && me.isRecording
				xy				= [];
				td				= me.tobii.buffer.peekN('gaze',me.smoothing.nSamples);
				if isempty(td);me.currentSample=sample;return;end
				sample.raw		= td;
				sample.time		= double(td.systemTimeStamp(end)) / 1e6; %remember these are in microseconds
				sample.timeD	= double(td.deviceTimeStamp(end)) / 1e6;
				if any(td.left.gazePoint.valid) || any(td.right.gazePoint.valid)
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
					sample.valid = true;
					xy			= doSmoothing(me,xy);
					xy			= toPixels(me, xy,'','relative');
					sample.gx	= xy(1);
					sample.gy	= xy(2);
					sample.pa	= nanmean(td.left.pupil.diameter);
					xyd	= me.toDegrees(xy);
					me.x = xyd(1); me.y = xyd(2);
					me.pupil	= sample.pa;
					%if me.verbose;fprintf('>>X: %2.2f | Y: %2.2f | P: %.2f\n',me.x,me.y,me.pupil);end
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
				if me.verbose;fprintf('-+-+-> tobiiManager.getSample(): are you sure you are recording?\n');end
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
			if me.isConnected
				me.data = me.tobii.collectSessionData();
			end
			me.initialiseSaveFile();
			if ~isempty(me.data) && tofile
				tobii = me;
				if exist(me.saveFile,'file')
					[p,f,e] = fileparts(me.saveFile);
					me.saveFile = [p filesep f me.savePrefix e];
				end
				save(me.saveFile,'tobii')
				disp('===========================')
				me.salutation('saveData',sprintf('Save: %s in %.1fms\n',strrep(me.saveFile,'\','/'),toc(ts)*1e3),true);
				disp('===========================')
				clear tobii
			elseif isempty(me.data)
				me.salutation('saveData',sprintf('NO data available... (%.1fms)...\n',toc(ts)*1e3),true);
			elseif ~isempty(me.data)
				me.salutation('saveData',sprintf('Data retrieved to object in %.1fms)...\n',toc(ts)*1e3),true);
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
				stopRecording(me);
				out = me.tobii.deInit();
				me.isConnected = false;
				me.isRecording = false;
				resetFixation(me);
				if me.secondScreen && ~isempty(me.operatorScreen) && isa(me.operatorScreen,'screenManager')
					me.operatorScreen.close;
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
			RestrictKeysForKbCheck([stopKey upKey downKey leftKey rightKey calibKey]);
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
				if length(Screen('Screens'))>1 && s.screen - 1 >= 0
					useS2				= true;
					me.useOperatorScreen = true;
					s2					= screenManager;
					s2.pixelsPerCm		= 20;
					s2.screen			= s.screen - 1;
					s2.backgroundColour	= s.backgroundColour;
					[w,h]				= Screen('WindowSize',s2.screen);
					s2.windowed			= [0 0 round(w/2) round(h/2)];
					s2.bitDepth			= '8bit';
					s2.blend			= true;
					s2.disableSyncTests	= true;
					s2.specialFlags		= kPsychGUIWindow;
				end
			
				sv=open(s); %open our screen
				
				if useS2
					initialise(me, s, s2); %initialise tobii with our screen
					s2.open();
				else
					initialise(me, s); %initialise tobii with our screen
				end
				trackerSetup(me);
				ShowCursor; %titta fails to show cursor so we must do it
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
							txt = sprintf('Q = finish. X: %3.1f / %2.2f | Y: %3.1f / %2.2f | # = %2i %s %s | RADIUS = %s | TIME = %.2f | FIXATION = %.2f | EXC = %i | INIT FAIL = %i',...
								me.currentSample.gx, me.x, me.currentSample.gy, me.y, me.smoothing.nSamples,...
								me.smoothing.method, me.smoothing.eyes, sprintf('%1.1f ',me.fixation.radius), ...
								me.fixTotal,me.fixLength,me.isExclusion,me.isInitFail);
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
							elseif keyCode(calibKey); me.doCalibration;
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
						trackerMessage(me,'TRIAL_RESULT 1')
						trackerMessage(me,sprintf('Ending trial %i @ %i',trialn,int64(round(vbl*1e6))))
						resetFixation(me);
						me.fixation.X = randi([-7 7]);
						me.fixation.Y = randi([-7 7]);
						if length(me.fixation.radius) == 1
							me.fixation.radius = randi([1 3]);
							o.sizeOut = me.fixation.radius * 2;
							f.sizeOut = me.fixation.radius * 2;
						else
							me.fixation.radius = [randi([1 3]) randi([1 3])];
							o.sizeOut = mean(me.fixation.radius) * 2;
							f.barWidthOut = me.fixation.radius(1) * 2;
							f.barHeightOut = me.fixation.radius(2) * 2;
						end
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
						trackerMessage(me,'TRIAL_RESULT -10 ABORT')
						trackerMessage(me,sprintf('Aborting %i @ %i', trialn, int64(round(vbl*1e6))))
					end
				end
				stopRecording(me);
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
				stopRecording(me);
				me.fixation = ofixation;
				me.saveFile = ofilename;
				me.smoothing = osmoothing;
				me.exclusionZone = oldexc;
				me.fixInit = oldfixinit;
				ListenChar(0); Priority(0); ShowCursor; RestrictKeysForKbCheck([]);
				getReport(ME)
				close(s);
				if useS2;close(s2);end
				sca;
				close(me);
				clear s s2 o
				rethrow(ME)
			end
			
		end
		
		% ===================================================================
		%> @brief
		%>
		% ===================================================================
		function doCalibration(me)
			if me.isConnected
				me.trackerSetup();
			end
		end
		
		% ===================================================================
		%> @brief smooth data in M x N where M = 2 (x&y trace) or M = 4 is x&y
		%> for both eyes. Output is 2 x 1 x&y averages position
		%>
		% ===================================================================
		function out = doSmoothing(me,in)
			if size(in,2) > me.smoothing.window * 2
				switch me.smoothing.method
					case 'median'
						out = movmedian(in,me.smoothing.window,2);
						out = median(out, 2);
					case {'heuristic','heuristic1'}
						out = me.heuristicFilter(in,1);
						out = median(out, 2);
					case 'heuristic2'
						out = me.heuristicFilter(in,2);
						out = median(out, 2);
					case {'sg','savitzky-golay'}
						out = sgolayfilt(in,1,me.smoothing.window,[],2);
						out = median(out, 2);
					otherwise
						out = median(in, 2);
				end
			elseif size(in, 2) > 1
				out = median(in, 2);
			else
				out = in;
			end
			if size(out,1)==4 % XY for both eyes, combine together.
				out = [mean([out(1) out(3)]); mean([out(2) out(4)])];
			end
			if length(out) ~= 2
				out = [NaN NaN];
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
		
		% ===================================================================
		%> @brief
		%>
		% ===================================================================
		function value = get.smoothingTime(me)
			value = (1000 / me.sampleRate) * me.smoothing.nSamples;
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
		%> @brief Stampe 1993 heuristic filter as used by Eyelink
		%>
		%> @param indata - input data
		%> @param level - 1 = filter level 1, 2 = filter level 1+2
		%> @param steps - we step every # steps along the in data, changes the filter characteristics, 3 is the default (filter 2 is #+1)
		%> @out out - smoothed data
		% ===================================================================
		function out = heuristicFilter(~,indata,level,steps)
			if ~exist('level','var'); level = 1; end %filter level 1 [std] or 2 [extra]
			if ~exist('steps','var'); steps = 3; end %step along the data every n steps
			out=zeros(size(indata));
			for k = 1:2 % x (row1) and y (row2) eye samples
				in = indata(k,:);
				%filter 1 from Stampe 1993, see Fig. 2a
				if level > 0
					for i = 1:steps:length(in)-2
						x = in(i); x1 = in(i+1); x2 = in(i+2); %#ok<*PROPLC>
						if ((x2 > x1) && (x1 < x)) || ((x2 < x1) && (x1 > x))
							if abs(x1-x) < abs(x2-x1) %i is closest
								x1 = x;
							else
								x1 = x2;
							end
						end
						x2 = x1;
						x1 = x;
						in(i)=x; in(i+1) = x1; in(i+2) = x2;
					end
				end
				%filter2 from Stampe 1993, see Fig. 2b
				if level > 1
					for i = 1:steps+1:length(in)-3
						x = in(i); x1 = in(i+1); x2 = in(i+2); x3 = in(i+3);
						if x2 == x1 && (x == x1 || x2 == x3)
							x3 = x2;
							x2 = x1;
							x1 = x;
						else %x2 and x1 are the same, find closest of x2 or x
							if abs(x1 - x3) < abs(x1 - x)
								x2 = x3;
								x1 = x3;
							else
								x2 = x;
								x1 = x;
							end
						end
						in(i)=x; in(i+1) = x1; in(i+2) = x2; in(i+3) = x3;
					end
				end
				out(k,:) = in;
			end
		end
		
		% ===================================================================
		%> @brief
		%>
		% ===================================================================
		function initTracker(me)
			me.settings = Titta.getDefaults(me.calibration.model);
			me.settings.cal.bgColor = 127;
			me.tobii = Titta(me.settings);
		end
		
	end %------------------END PRIVATE METHODS
end

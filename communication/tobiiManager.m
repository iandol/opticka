% ========================================================================
%> @brief tobiiManager wraps around the Titta toolbox functions
%> offering a interface consistent with the previous eyelinkManager, offering
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
% ========================================================================
classdef tobiiManager < optickaCore
	
	properties
		%> fixation window:
		%> if X and Y have multiple rows, assume each one is a different fixation window.
		%> if radius has a single value, assume circular window
		%> if radius has 2 values assume width x height rectangle
		%> initTime is the time the subject has to initiate fixation
		%> time is the time the sbject must maintain fixation within the window
		%> strict = false allows subject to exit and enter window without
		%> failure, useful during training
		fixation struct					= struct('X',0,'Y',0,'initTime',1,'time',1,...
										'radius',1,'strict',true)
		%> When using the test for eye position functions, 
		%> exclusion zones where no eye movement allowed: [-degX +degX -degY +degY]
		%> Add rows to generate succesive exclusion zones.
		exclusionZone					= []
		%> we can optional set an initial window that the subject must stay
		%> inside of before they saccade to the target window. This
		%> restricts guessing and "cheating", by forcing a minimum delay
		%> (default = 100ms) before initiating a saccade. Only used if X is not
		%> empty.
		fixInit	struct					= struct('X',[],'Y',[],'time',0.1,'radius',2)
		%> add a manual offset to the eye position, similar to a drift correction
		%> but handled by the eyelinkManager.
		offset struct					= struct('X',0,'Y',0)
		%> model of eyetracker:
		%> 'Tobi Pro Spectrum' - 'IS4_Large_Peripheral' - 'Tobii TX300'
		model char {mustBeMember(model,{'Tobii Pro Spectrum','Tobii TX300',...
			'Tobii 4C','IS4_Large_Peripheral', 'Tobii Pro Nano'})} = 'Tobii Pro Spectrum'
		%> tracker update speed (Hz)
		%> Spectrum Pro: [60, 120, 150, 300, 600 or 1200]
		%> 4C: 90
		sampleRate double {mustBeMember(sampleRate,[60 90 120 150 300 600 1200])} = 300
		%> use human, macaque, Default or other tracking mode
		trackingMode char {mustBeMember(trackingMode,{'human','macaque','Default', ...
			'Infant', 'Bright light'})} = 'human'
		%> options for online smoothing of peeked data {'median','heuristic','savitsky-golay'}
		smoothing struct				= struct('nSamples',8,'method','median','window',3,...
			'eyes','both')
		%> type of calibration stimulus
		calibrationStimulus char {mustBeMember(calibrationStimulus,{'animated',...
					'movie','normal'})}	= 'animated'
		%> Titta class object
		tobii Titta
		%> Titta settings structure
		settings struct					= []
		%> name of eyetracker data file
		saveFile char					= 'tobiiData.mat'
		%> start eyetracker in dummy mode?
		isDummy logical					= false
		%> do we use manual calibration mode?
		manualCalibration logical		= false
		%> custom calibration positions, e.g. [ .1 .5; .5 .5; .8 .5]
		calPositions					= []
		%> custom validation positions
		valPositions					= []
		%> does calibration pace automatically?
		autoPace logical				= true
		%> pace duration
		paceDuration double				= 0.8
		% which eye is the tracker using?
		eyeUsed char {mustBeMember(eyeUsed,{'both','left','right'})} = 'both'
		%> which movie to use for calibration, empty uses default
		calibrationMovie movieStimulus
	end
	
	properties (Hidden = true)
		%> do we log messages to the command window?
		verbose							= false
		%> stimulus positions to draw on screen
		stimulusPositions				= []
		%> 
		sampletime						= []
		%> operator screen used during calibration
		operatorScreen screenManager
		%> is operator screen being used?
		secondScreen logical			= false
		%> should we close it after calibration
		closeSecondScreen logical		= false
		%> size to draw eye position on screen
		eyeSize double					= 6
	end
	
	properties (SetAccess = private, GetAccess = public, Dependent = true)
		% are we recording to matrix?
		isRecording logical
		% calculates the smoothing in ms
		smoothingTime double
	end
	
	properties (SetAccess = private, GetAccess = public)
		%> Last gaze X position in degrees
		x								= []
		%> Last gaze Y position in degrees
		y								= []
		%> pupil size
		pupil							= []
		%> All gaze X position in degrees reset using resetFixation
		xAll							= []
		%> Last gaze Y position in degrees reset using resetFixation
		yAll							= []
		%> all pupil size reset using resetFixation
		pupilAll						= []
		%current sample taken from tobii
		currentSample struct
		%current event taken from tobii
		currentEvent struct
		%> are we in an exclusion zone?
		isExclusion	logical				= false
		%> last isFixated true/false result
		isFix logical					= false
		%> did the fixInit test fail or not?
		isInitFail logical				= false
		%> Initiate fixation time
		fixInitStartTime				= 0
		%> Initiate fixation length
		fixInitLength					= 0
		%the first timestamp fixation was true
		fixStartTime					= 0
		%how long have we been fixated?
		fixLength						= 0
		%> total time searching and holding fixation
		fixTotal						= 0
		%> last time offset betweeen tracker and display computers
		currentOffset					= 0
		%> tracker time stamp
		trackerTime						= 0
		%> tracker time stamp
		systemTime						= 0
		%> the PTB screen to work with, passed in during initialise
		screen screenManager
		% are we connected to Tobii?
		isConnected logical				= false
		%> data streamed out from the Tobii
		data struct						= struct()
		%> calibration data
		calibration						= []
	end
	
	properties (SetAccess = private, GetAccess = private)
		%> cache this to save time in tight loops
		isRecording_					= false
		calStim
		%> currentSample template
		sampleTemplate struct			= struct('raw',[],'time',NaN,'timeD',NaN,'gx',NaN,'gy',NaN,...
											'pa',NaN,'valid',false)
		%> the PTB screen handle, normally set by screenManager but can force it to use another screen
		win								= []
		ppd_ double						= 36
		% these are used to test strict fixation
		fixN double						= 0
		fixSelection					= []
		%> event N
		eventN							= 1
		%> previous message sent to tobii
		previousMessage char			= ''
		%> allowed properties passed to object upon construction
		allowedProperties char			= ['tobii|screen|isDummy|saveFile|settings|calPositions|'...
					'valPositions|model|trackingMode|fixation|sampleRate|smoothing|calibrationMovie|'...
					'verbose|isDummy|manualCalibration|exclusionZone|fixInit']
	end
	
	methods
		% ===================================================================
		%> @brief This is the constructor for this class
		%>
		% ===================================================================
		function me = tobiiManager(varargin)
			args = optickaCore.addDefaults(varargin,struct('name','tobii manager'));
			me=me@optickaCore(args); %we call the superclass constructor first
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
			if contains(me.model,{'Tobii 4C','IS4_Large_Peripheral'})
				me.sampleRate = 90; 
				me.trackingMode = 'Default';
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
		function initialise(me,sM,sM2)
			if ~exist('sM','var') || isempty(sM)
				if isempty(me.screen) || ~isa(me.screen,'screenManager')
					me.screen		= screenManager();
				end
			else
				if ~isempty(me.screen) && isa(me.screen,'screenManager') && me.screen.isOpen && ~strcmpi(sM.uuid,me.screen.uuid)
					%close(me.screen); 
				end
				me.screen			= sM;
			end
			if ~exist('sM2','var') || ~isa(sM2,'screenManager')
				me.secondScreen		= false;
			else
				me.operatorScreen	= sM2;
				me.secondScreen		= true;
			end
			if contains(me.model,{'Tobii 4C','IS4_Large_Peripheral'})
				me.sampleRate = 90; 
				me.trackingMode = 'Default';
			end
			if ~isa(me.tobii, 'Titta') || isempty(me.tobii); initTracker(me); end
			assert(isa(me.tobii,'Titta'),'TOBIIMANAGER:INIT-ERROR','Cannot Initialise...')
			
			if me.isDummy
				me.tobii			= me.tobii.setDummyMode();
			end
			
			me.settings								= Titta.getDefaults(me.model);
			if ~contains(me.model,{'Tobii 4C','IS4_Large_Peripheral'})
				me.settings.freq					= me.sampleRate;
				me.settings.trackingMode			= me.trackingMode;
			end
			me.settings.calibrateEye				= me.eyeUsed;
			me.settings.cal.bgColor					= floor(me.screen.backgroundColour*255);
			me.settings.UI.setup.bgColor			= me.settings.cal.bgColor;
			me.settings.UI.setup.showFixPointsToSubject		= false;
			me.settings.UI.setup.showHeadToSubject			= true;   
			me.settings.UI.setup.showInstructionToSubject	= true;
			me.settings.UI.setup.eyeClr						= 255;
			if strcmpi(me.calibrationStimulus,'animated')
				me.calStim							= AnimatedCalibrationDisplay();
				me.calStim.moveTime					= 0.75;
				me.calStim.oscillatePeriod			= 1;
				me.calStim.blinkCount				= 4;
				me.calStim.bgColor					= me.settings.cal.bgColor;
				me.calStim.fixBackColor				= 0;
				me.calStim.fixFrontColor			= 255;
				me.settings.cal.drawFunction		= @(a,b,c,d,e,f) me.calStim.doDraw(a,b,c,d,e,f);
				if me.manualCalibration;me.settings.mancal.drawFunction	= @(a,b,c,d,e,f) me.calStim.doDraw(a,b,c,d,e,f);end
			elseif strcmpi(me.calibrationStimulus,'movie')
				me.calStim							= tittaCalMovieStimulus();
				me.calStim.moveTime					= 0.75;
				me.calStim.oscillatePeriod			= 1;
				me.calStim.blinkCount				= 3;
				if isempty(me.screen.audio)
					me.screen.audio					= audioManager();
				end
				if isempty(me.calibrationMovie)
					me.calibrationMovie				= movieStimulus('size',4);
				end
				reset(me.calibrationMovie);
				setup(me.calibrationMovie, me.screen);
				me.calStim.initialise(me.calibrationMovie);
				me.settings.cal.drawFunction		= @(a,b,c,d,e,f) me.calStim.doDraw(a,b,c,d,e,f);
				if me.manualCalibration;me.settings.mancal.drawFunction	= @(a,b,c,d,e,f) me.calStim.doDraw(a,b,c,d,e,f);end
			end
			me.settings.cal.autoPace				= me.autoPace;
			me.settings.cal.paceDuration			= me.paceDuration;
			if me.autoPace
				me.settings.cal.doRandomPointOrder	= true;
			else
				me.settings.cal.doRandomPointOrder	= false;
			end
			if ~isempty(me.calPositions)
				me.settings.cal.pointPos			= me.calPositions;
			end
			if ~isempty(me.valPositions)
				me.settings.val.pointPos			= me.valPositions;
			end
			
			me.settings.cal.pointNotifyFunction	= @tittaCalCallback;
			me.settings.val.pointNotifyFunction	= @tittaCalCallback;
			
			if me.manualCalibration
				me.settings.UI.mancal.bgColor		= floor(me.screen.backgroundColour*255);
				me.settings.mancal.bgColor			= floor(me.screen.backgroundColour*255);
				me.settings.mancal.cal.pointPos		= me.calPositions;
				me.settings.mancal.val.pointPos		= me.valPositions;
				me.settings.mancal.cal.paceDuration	= me.paceDuration;
				me.settings.mancal.val.paceDuration	= me.paceDuration;
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
				me.isRecording_ = false;
				resetFixation(me);
			catch ME
				me.salutation('Close Method','Couldn''t stop recording, forcing shutdown...',true)
				me.tobii.deInit();
				me.isConnected = false;
				me.isRecording_ = false;
				resetFixation(me);
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
		%> @brief reset the fixation counters ready for a new trial
		%>
		% ===================================================================
		function resetFixation(me,removeHistory)
			if ~exist('removeHistory','var');removeHistory=true;end
			me.fixStartTime		= 0;
			me.fixLength		= 0;
			me.fixInitStartTime	= 0;
			me.fixInitLength	= 0;
			me.fixTotal			= 0;
			me.fixN				= 0;
			me.fixSelection		= 0;
			if removeHistory
				resetFixationHistory(me);
			end
			me.isFix			= false;
			me.isExclusion		= false;
			me.isInitFail		= false;
		end
		
		% ===================================================================
		%> @brief reset the fixation counters ready for a new trial
		%>
		% ===================================================================
		function resetFixationTime(me)
			me.fixStartTime		= 0;
			me.fixLength		= 0;
		end
		
		% ===================================================================
		%> @brief reset the fixation history: xAll yAll pupilAll
		%>
		% ===================================================================
		function resetFixationHistory(me)
			me.xAll				= [];
			me.yAll				= [];
			me.pupilAll			= [];
		end
		
		% ===================================================================
		%> @brief reset the fixation offset to 0
		%>
		% ===================================================================
		function resetOffset(me)
			me.offset.X = 0;
			me.offset.Y = 0;
		end
		
		% ===================================================================
		%> @brief reset the fixation offset to 0
		%>
		% ===================================================================
		function resetFixInit(me)
			me.fixInit.X = 0;
			me.fixInit.Y = 0;
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
			cal = [];
			if ~me.isConnected || ~me.screen.isOpen || me.isDummy; return; end
			if ~exist('incal','var');incal=[];end
			wasRecording = me.isRecording;
			if wasRecording; stopRecording(me);	end
			updateDefaults(me); % make sure we send any other settings changes
			ListenChar(-1);
			if ~isempty(me.operatorScreen) && isa(me.operatorScreen,'screenManager')
				if ~me.operatorScreen.isOpen
					me.operatorScreen.open();
				end
				if me.manualCalibration
					if ~isempty(incal) && isstruct(incal) && isfield(incal,'type') && contains(incal.type,'manual')
						me.calibration = me.tobii.calibrateManual([me.screen.win me.operatorScreen.win], incal); 
					else
						me.calibration = me.tobii.calibrateManual([me.screen.win me.operatorScreen.win]);
					end
				else
					if ~isempty(incal) && isstruct(incal) && isfield(incal,'type') && contains(incal.type,'standard')
						me.calibration = me.tobii.calibrate([me.screen.win me.operatorScreen.win], [], incal); 
					else
						me.calibration = me.tobii.calibrate([me.screen.win me.operatorScreen.win]);
					end
				end
			else
				me.calibration = me.tobii.calibrate(me.screen.win,[],incal); %start calibration
			end
			ListenChar(0);
			if strcmpi(me.calibrationStimulus,'movie')
				me.calStim.movie.reset();
				%me.calStim.movie.setup(me.screen);
			end
			if ~isempty(me.calibration) && me.calibration.wasSkipped ~= 1
				cal = me.calibration;
				if isfield(me.calibration,'selectedCal')
					try
						calMsg = me.tobii.getValidationQualityMessage(me.calibration);
						disp(calMsg);
					end
				end
			else
				disp('---!!! The calibration was unsuccesful or skipped !!!---')
			end
			if me.secondScreen && me.closeSecondScreen && me.operatorScreen.isOpen
				close(me.operatorScreen); 
				WaitSecs('YieldSecs',0.2); 
			end
			resetFixation(me);
			if wasRecording; startRecording(me); end
			me.isRecording_ = me.isRecording;
		end
		
		% ===================================================================
		%> @brief wrapper for StartRecording
		%>
		% ===================================================================
		function startRecording(me)
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
			me.isRecording_ = me.isRecording;
		end
		
		% ===================================================================
		%> @brief wrapper for StopRecording
		%>
		% ===================================================================
		function stopRecording(me)
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
			me.isRecording_ = me.isRecording;
		end
		
		% ===================================================================
		%> @brief wrapper for EyelinkDoDriftCorrection
		%>
		% ===================================================================
		function success = driftOffset(me)
			success = false;
			escapeKey			= KbName('ESCAPE');
			stopkey				= KbName('Q');
			nextKey				= KbName('SPACE');
			calibkey			= KbName('C');
			driftkey			= KbName('D');
			if me.isConnected || me.isDummy
				x=me.toPixels(me.fixation.X,'x'); %#ok<*PROPLC>
				y=me.toPixels(me.fixation.Y,'y');
				Screen('Flip',me.screen.win);
				ifi = me.screen.screenVals.ifi;
				breakLoop = false; i = 1; flash = true;
				correct = false;
				xs = [];
				ys = [];
				while ~breakLoop
					getSample(me);
					xs(i) = me.x;
					ys(i) = me.y;
					if mod(i,10) == 0
						flash = ~flash;
					end
					Screen('DrawText',me.screen.win,'Drift Correction...',10,10,[0.4 0.4 0.4]);
					if flash
						Screen('gluDisk',me.screen.win,[1 0 1 0.75],x,y,10);
						Screen('gluDisk',me.screen.win,[1 1 1 1],x,y,4);
					else
						Screen('gluDisk',me.screen.win,[1 1 0 0.75],x,y,10);
						Screen('gluDisk',me.screen.win,[0 0 0 1],x,y,4);
					end
					me.screen.drawCross(0.6,[0 0 0],x,y,0.1,false);
					Screen('Flip',me.screen.win);
					[~, ~, keyCode] = KbCheck(-1);
					if keyCode(stopkey) || keyCode(escapeKey); breakLoop = true; break;	end
					if keyCode(nextKey); correct = true; break; end
					if keyCode(calibkey); trackerSetup(me); break; end
					if keyCode(driftkey); driftCorrection(me); break; end
					i = i + 1;
				end
				if correct && length(xs) > 5 && length(ys) > 5
					success = true;
					me.offset.X = median(xs) - me.fixation.X;
					me.offset.Y = median(ys) - me.fixation.Y;
					t = sprintf('Offset: X = %.2f Y = %.2f\n',me.offset.X,me.offset.Y);
					me.salutation('Drift [SELF]Correct',t,true);
					Screen('DrawText',me.screen.win,t,10,10,[0.4 0.4 0.4]);
					Screen('Flip',me.screen.win);
				else
					me.offset.X = 0;
					me.offset.Y = 0;
					t = sprintf('Offset: X = %.2f Y = %.2f\n',me.offset.X,me.offset.Y);
					me.salutation('REMOVE Drift [SELF]Offset',t,true);
					Screen('DrawText',me.screen.win,'Reset Drift Offset...',10,10,[0.4 0.4 0.4]);
					Screen('Flip',me.screen.win);
				end
				WaitSecs('YieldSecs',1);
			end
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
				sample.time		= GetSecs * 1e6;
				me.x			= me.toDegrees(sample.gx,'x');
				me.y			= me.toDegrees(sample.gy,'y');
				me.xAll			= [me.xAll me.x];
				me.yAll			= [me.yAll me.y];
				me.pupilAll		= [me.pupilAll me.pupil];
				%if me.verbose;fprintf('>>X: %.2f | Y: %.2f | P: %.2f\n',me.x,me.y,me.pupil);end
			elseif me.isConnected && me.isRecording_
				xy				= [];
				td				= me.tobii.buffer.peekN('gaze',me.smoothing.nSamples);
				if isempty(td);me.currentSample=sample;return;end
				sample.raw		= td;
				sample.time		= double(td.systemTimeStamp(end)); %remember these are in microseconds
				sample.timeD	= double(td.deviceTimeStamp(end));
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
					xy			= me.toDegrees(xy);
					me.x		= xy(1);
					me.y		= xy(2);
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
				if me.verbose;fprintf('--->>> tobiiManager getSample(): are you sure you are recording?\n');end
			end
			me.currentSample	= sample;
		end
		
		% ===================================================================
		%> @brief Method to update the fixation parameters
		%>
		% ===================================================================
		function updateFixationValues(me,x,y,inittime,fixtime,radius,strict)
			%tic
			resetFixation(me,false)
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
					me.fixation.strict = inittime{4};
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
			if nargin > 6 && ~isempty(strict); me.fixation.strict = strict; end
			if me.verbose
				fprintf('-+-+-> eyelinkManager:updateFixationValues: X=%g | Y=%g | IT=%s | FT=%s | R=%g\n', ...
					me.fixation.X, me.fixation.Y, num2str(me.fixation.initTime), num2str(me.fixation.time), ...
					me.fixation.radius);
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
			fixated = false; fixtime = false; searching = true; window = []; exclusion = false; fixinit = false; window = 0;
			
			if isempty(me.currentSample) || isnan(me.currentSample.time);return;end
			
			if me.isExclusion || me.isInitFail
				exclusion = me.isExclusion; fixinit = me.isInitFail; searching = false;
				return; % we previously matched either rule, now cannot pass fixation until a reset.
			end
			
			if me.fixInitStartTime == 0
				me.fixInitStartTime = me.currentSample.time;
			end
			% ---- test for exclusion zones first
			if ~isempty(me.exclusionZone)
				for i = 1:size(me.exclusionZone,1)
					if (me.x >= me.exclusionZone(i,1) && me.x <= me.exclusionZone(i,2)) && ...
						(me.y >= me.exclusionZone(i,3) && me.y <= me.exclusionZone(i,4))
						searching = false; exclusion = true; me.isExclusion = true; me.isFix = false;
						return;
					end
				end
			end
			% ---- test for fix initiation start window
			if ~isempty(me.fixInit.X)
				if (me.currentSample.time - me.fixInitStartTime) < (me.fixInit.time * 1e6)
					r = sqrt((me.x - me.fixInit.X).^2 + (me.y - me.fixInit.Y).^2);
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
				r = sqrt((me.x - me.fixation.X).^2 + (me.y - me.fixation.Y).^2); %fprintf('x: %g-%g y: %g-%g r: %g-%g\n',me.x, me.fixation.X, me.y, me.fixation.Y,r,me.fixation.radius);
				window = find(r < me.fixation.radius);
			elseif length(me.fixation.radius) == 2 % x y rectangular window test
				if (me.x >= (me.fixation.X - me.fixation.radius(1))) && (me.x <= (me.fixation.X + me.fixation.radius(1))) ...
						&& (me.y >= (me.fixation.Y - me.fixation.radius(2))) && (me.y <= (me.fixation.Y + me.fixation.radius(2)))
					window = 1;
				end
			end
			% update our logic depending on if we are in or out of fixation window
			me.fixTotal = (me.currentSample.time - me.fixInitStartTime) / 1e6;
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
					me.fixLength = (me.currentSample.time - me.fixStartTime) / 1e6;
					if me.fixLength >= me.fixation.time
						fixtime = true;
					else
						fixtime = false;
					end
				else
					fixated = false; fixtime = false; searching = false;
				end
				me.isFix = fixated;
			else %not inside the fixation window
				if me.fixN == 1
					me.fixN = -100;
				end
				me.fixInitLength = (me.currentSample.time - me.fixInitStartTime) / 1e6;
				if me.fixInitLength <= me.fixation.initTime
					searching = true;
				else
					searching = false;
				end
				me.isFix = false; me.fixLength = 0; me.fixStartTime = 0;
			end
		end
		
		% ===================================================================
		%> @brief testExclusion checks if eye is in exclusion zones
		%>
		% ===================================================================
		function out = testExclusion(me)
			out = false;
			if (me.isConnected || me.isDummy) && ~isempty(me.currentSample) && ~isempty(me.exclusionZone)
				for i = 1:size(me.exclusionZone,1)
					if (me.x >= me.exclusionZone(i,1) && me.x <= me.exclusionZone(i,2)) && ...
							(me.y >= me.exclusionZone(i,3) && me.y <= me.exclusionZone(i,4))
						out = true;
						fprintf('-+-+-> Tobii:EXCLUSION ZONE %i ENTERED!\n',i);
						return
					end
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
				out = yesString; %me.salutation(sprintf('Fixation time: %g',me.fixLength),'TESTFIXTIME');
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
			[fix, fixtime, searching, window, exclusion, initfail] = me.isFixated();
			if exclusion
				fprintf('-+-+-> Tobii:testSearchHoldFixation EXCLUSION ZONE ENTERED!\n')
				out = 'EXCLUDED!'; window = [];
				return
			end
			if initfail
				if me.verbose; fprintf('-+-+-> Tobii:testSearchHoldFixation FIX INIT TIME FAILED!\n'); end
				out = 'EXCLUDED!';
				return
			end
			if searching
				if (me.fixation.strict==true && (me.fixN == 0)) || me.fixation.strict==false
					out = 'searching';
				else
					out = noString;
					if me.verbose; fprintf('-+-+-> Tobii:testSearchHoldFixation STRICT SEARCH FAIL: %s [%g %g %g]\n', out, fix, fixtime, searching);end
				end
				return
			elseif fix
				if (me.fixation.strict==true && ~(me.fixN == -100)) || me.fixation.strict==false
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
		end
		
		% ===================================================================
		%> @brief Checks if we're within fix window. Input is
		%> 2 strings, either one is returned depending on success or
		%> failure, 'fixing' means the fixation time is not yet met...
		%>
		%> @param yesString if this function succeeds return this string
		%> @param noString if this function fails return this string
		%> @return out the output string which is 'fixing' if the fixation window was entered
		%>   but not for the requisite fixation time, or the yes or no string.
		% ===================================================================
		function [out, window, exclusion] = testHoldFixation(me, yesString, noString)
			[fix, fixtime, searching, window, exclusion, initfail] = me.isFixated();
			if exclusion
				fprintf('-+-+-> Tobii:testHoldFixation EXCLUSION ZONE ENTERED!\n')
				out = 'EXCLUDED!'; window = [];
				return
			end
			if initfail
				if me.verbose; fprintf('-+-+-> Tobii:testSearchHoldFixation FIX INIT TIME FAILED!\n'); end
				out = 'EXCLUDED!';
				return
			end
			if fix
				if (me.fixation.strict==true && ~(me.fixN == -100)) || me.fixation.strict==false
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
		%> @brief draw the current eye position on the PTB display
		%>
		% ===================================================================
		function drawEyePosition(me,details)
			if ~exist('details','var'); details = false; end
			if (me.isDummy || me.isConnected) && me.screen.isOpen ...
					&& ~isempty(me.currentSample) && me.currentSample.valid
				xy = [me.currentSample.gx me.currentSample.gy];
				if details
					if me.isFix
						if me.fixLength > me.fixation.time
							Screen('DrawDots', me.win, xy, me.eyeSize, [0 1 0.25 1], [], 0);
						else
							Screen('DrawDots', me.win, xy, me.eyeSize, [0.75 0 0.75 1], [], 0);
						end
					else
						Screen('DrawDots', me.win, xy, me.eyeSize, [0.7 0.5 0 1], [], 0);
					end
				else
					Screen('DrawDots', me.win, xy, me.eyeSize, [0.7 0.5 0 1], [], 0);
				end
			end
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
			KbName('UnifyKeyNames')
			stopkey				= KbName('q');
			upKey				= KbName('uparrow');
			downKey				= KbName('downarrow');
			leftKey				= KbName('leftarrow');
			rightKey			= KbName('rightarrow');
			calibkey			= KbName('c');
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
					s = screenManager('blend',true,'pixelsPerCm',36,'distance',60);
				end
				s.disableSyncTests		= false;
				s.audio					= audioManager();
				s.audio.setup();
				if exist('forcescreen','var'); s.screen = forcescreen; end
				s.backgroundColour		= [0.5 0.5 0.5 0];
				if length(Screen('Screens'))>1 && s.screen - 1 >= 0
					useS2				= true;
					s2.pixelsPerCm		= 45;
					s2					= screenManager;
					s2.screen			= s.screen - 1;
					s2.backgroundColour	= s.backgroundColour;
					[w,h]				= Screen('WindowSize',s2.screen);
					s2.windowed			= [0 0 round(w/2) round(h/2)];
					s2.bitDepth			= '8bit';
					s2.blend			= true;
					s2.disableSyncTests	= true;
				end
			
				sv=open(s); %open our screen
				
				if useS2
					me.closeSecondScreen = false;
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
				f.alpha
				f.xPositionOut = me.fixation.X;
				f.xPositionOut = me.fixation.X;
				
				% set up an exclusion zone where eye is not allowed
				me.exclusionZone = [8 12 9 12];
				exc = me.toPixels(me.exclusionZone);
				exc = [exc(1) exc(3) exc(2) exc(4)]; %psychrect=[left,top,right,bottom] 

				% warm up
				fprintf('\n===>>> Warming up the GPU, Eyetracker etc... <<<===\n')
				Priority(MaxPriority(s.win));
				HideCursor(s.win);
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
				startRecording(me);
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
				ListenChar(-1);
				update(o); %make sure stimuli are set back to their start state
				update(f);
				WaitSecs('YieldSecs',0.5);
				trackerMessage(me,'!!! Starting Demo...')
				while trialn <= maxTrials && endExp == 0
					trialtick = 1;
					trackerMessage(me,sprintf('Settings for Trial %i, X=%.2f Y=%.2f, SZ=%.2f',trialn,me.fixation.X,me.fixation.Y,o.sizeOut))
					drawPhotoDiodeSquare(s,[0 0 0 1]);
					flip(s2,[],[],2);
					vbl = flip(s); tstart=vbl+sv.ifi;
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
							drawEyePosition(me,true);
							%psn{trialn} = me.tobii.buffer.peekN('positioning',1);
						end
						if useS2
							drawGrid(s2);
							trackerDrawExclusion(me);
							trackerDrawFixation(me);
						end
						finishDrawing(s);
						animate(o);
						
						vbl(end+1) = Screen('Flip', s.win, vbl(end) + s.screenVals.halfifi);
						if trialtick==1; me.tobii.sendMessage('SYNC = 255', vbl);end
						if useS2; flip(s2,[],[],2); end
						[keyDown, ~, keyCode] = KbCheck(-1);
						if keyDown
							if keyCode(stopkey); endExp = 1; break;
							elseif keyCode(calibkey); me.doCalibration;
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
						trackerMessage(me,'END_RT',vbl);
						trackerMessage(me,'TRIAL_RESULT -10 ABORT')
						trackerMessage(me,sprintf('Aborting %i @ %i', trialn, int64(round(vbl*1e6))))
					end
				end
				stopRecording(me);
				ListenChar(0); Priority(0); ShowCursor;
				try close(s); close(s2);end %#ok<*TRYNC>
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
				ListenChar(0);Priority(0);ShowCursor;
				getReport(ME)
				close(s);
				sca;
				close(me);
				clear s o
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
		%> @brief draw the background colour
		%>
		% ===================================================================
		function trackerClearScreen(me)
			if ~me.isConnected || ~me.operatorScreen.isOpen; return;end
			drawBackground(me.operatorScreen);
		end
		
		% ===================================================================
		%> @brief draw the stimuli boxes on the tracker display
		%>
		% ===================================================================
		function trackerDrawStimuli(me, ts, clearScreen)
			if ~me.isConnected || ~me.operatorScreen.isOpen; return;end
			if exist('ts','var') && isstruct(ts)
				me.stimulusPositions = ts;
			end
			if ~exist('clearScreen','var');clearScreen = false;end
			for i = 1:length(me.stimulusPositions)
				x = me.stimulusPositions(i).x; 
				y = me.stimulusPositions(i).y; 
				size = me.stimulusPositions(i).size;
				if isempty(size); size = 1 * me.ppd_; end
				if me.stimulusPositions(i).selected == true
					drawBox(me.operatorScreen,[x y],size,[0.5 1 0]);
				else
					drawBox(me.operatorScreen,[x y],size,[0.6 0.6 0]);
				end
			end			
		end
		
		% ===================================================================
		%> @brief draw the fixation box on the tracker display
		%>
		% ===================================================================
		function trackerDrawFixation(me)
			if ~me.isConnected || ~me.operatorScreen.isOpen; return;end
			if length(me.fixation.radius) == 1
				drawSpot(me.operatorScreen,me.fixation.radius,[0.5 0.6 0.5 1],me.fixation.X,me.fixation.Y);
			else
				rect = [me.fixation.X - me.fixation.radius(1), ...
					me.fixation.Y - me.fixation.radius(2), ...
					me.fixation.X + me.fixation.radius(1), ...
					me.fixation.Y + me.fixation.radius(2)];
				drawRect(me.operatorScreen,rect,[0.5 0.6 0.5 1]);
			end
		end
		
		% ===================================================================
		%> @brief draw the fixation box on the tracker display
		%>
		% ===================================================================
		function trackerDrawEyePosition(me)
			if ~me.isConnected || ~me.operatorScreen.isOpen; return;end
			if me.isFix
				if me.fixLength > me.fixation.time
					drawSpot(me.operatorScreen,0.3,[0 1 0.25 0.75],me.x,me.y);
				else
					drawSpot(me.operatorScreen,0.3,[0.75 0.25 0.75 0.75],me.x,me.y);
				end
			else
				drawSpot(me.operatorScreen,0.3,[0.7 0.5 0 0.75],me.x,me.y);
			end
		end
		
		% ===================================================================
		%> @brief draw the sampled eye positions in xAll yAll
		%>
		% ===================================================================
		function trackerDrawEyePositions(me)
			if ~me.isConnected || ~me.operatorScreen.isOpen; return;end
			if ~isempty(me.xAll) && ~isempty(me.yAll) && (length(me.xAll)==length(me.yAll))
				xy = [me.xAll;me.yAll];
				drawDots(me.operatorScreen,xy,8,[0.5 1 0 0.2]);
			end
		end
		
		% ===================================================================
		%> @brief draw the fixation box on the tracker display
		%>
		% ===================================================================
		function trackerDrawExclusion(me)
			if ~me.isConnected || ~me.operatorScreen.isOpen || isempty(me.exclusionZone); return; end
			for i = 1:size(me.exclusionZone,1)
				drawRect(me.operatorScreen, [me.exclusionZone(1), ...
					me.exclusionZone(3), me.exclusionZone(2), ...
					me.exclusionZone(4)],[0.7 0.6 0.6]);
			end
		end
		
		% ===================================================================
		%> @brief draw the fixation box on the tracker display
		%>
		% ===================================================================
		function trackerDrawText(me,textIn)
			if ~me.isConnected || ~me.operatorScreen.isOpen || ~exist('textIn','var'); return; end
			drawText(me.operatorScreen,textIn);
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
		function value = get.isRecording(me)
			if me.isConnected
				value = me.tobii.buffer.isRecording('gaze');
			else
				value = false;
			end
			me.isRecording_ = value;
		end
		
		% ===================================================================
		%> @brief
		%>
		% ===================================================================
		function value = get.smoothingTime(me)
			value = (1000 / me.sampleRate) * me.smoothing.nSamples;
		end
		
		% ===================================================================
		%> @brief
		%>
		% ===================================================================
		function set.model(me,value)
			me.model = value;
			switch me.model
				case {'IS4_Large_Peripheral','Tobii 4C'}
					me.sampleRate = 90; %#ok<*MCSUP>
					me.trackingMode = 'Default';
				case {'Tobii TX300','TX300'}
					me.sampleRate = 300; 
					me.trackingMode = 'Default';
				otherwise
					me.sampleRate = 300; 
					me.trackingMode = 'macaque';
			end
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
			driftOffset(me);
		end
		
		% ===================================================================
		%> @brief wrapper for CheckRecording
		%>
		% ===================================================================
		function error = checkRecording(me)
			error = false;
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
			
		end
		
		
		% ===================================================================
		%> @brief Get offset between tracker and display computers
		%>
		% ===================================================================
		function offset = getTimeOffset(me)
			
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
		%> @brief to pixels from visual degrees / relative
		%>
		% ===================================================================
		function out = toPixels(me,in,axis,inputtype)
			if ~exist('axis','var') || isempty(axis); axis=''; end
			if ~exist('inputtype','var') || isempty(inputtype); inputtype = 'degrees'; end
			out = 0;
			if length(in)>4; return; end
			switch axis
				case 'x'
					switch inputtype
						case 'degrees'
							out = (in * me.ppd_) + me.screen.xCenter;
						case 'relative'
							out = in * me.screen.screenVals.width;
					end
				case 'y'
					switch inputtype
						case 'degrees'
							out = (in * me.ppd_) + me.screen.yCenter;
						case 'relative'
							out = in * me.screen.screenVals.height;
					end
				otherwise
					switch inputtype
						case 'degrees'
							if length(in)==2
								out(1) = (in(1) * me.ppd_) + me.screen.xCenter;
								out(2) = (in(2) * me.ppd_) + me.screen.yCenter;
							elseif length(in)==4
								out(1:2) = (in(1:2) * me.ppd_) + me.screen.xCenter;
								out(3:4) = (in(3:4) * me.ppd_) + me.screen.yCenter;
							end
						case 'relative'
							if length(in)==2
								out(1) = in(1) * me.screen.screenVals.width;
								out(2) = in(2) * me.screen.screenVals.height;
							elseif length(in)==4
								out(1:2) = in(1:2) * me.screen.screenVals.width;
								out(3:4) = in(3:4) * me.screen.screenVals.height;
							end
					end
			end
		end
		
		% ===================================================================
		%> @brief to visual degrees from pixels
		%>
		% ===================================================================
		function out = toDegrees(me,in,axis,inputtype)
			if ~exist('axis','var') || isempty(axis); axis=''; end
			if ~exist('inputtype','var') || isempty(inputtype); inputtype = 'pixels'; end
			out = 0;
			if length(in)>2; return; end
			switch axis
				case 'x'
					in = in(1);
					switch inputtype
						case 'pixels'
							out = (in - me.screen.xCenter) / me.ppd_;
						case 'relative'
							out = (in - 0.5) * (me.screen.screenVals.width /me.ppd_);
					end
				case 'y'
					in = in(1);
					switch inputtype
						case 'pixels'
							out = (in - me.screen.yCenter) / me.ppd_; return
						case 'relative'
							out = (in - 0.5) * (me.screen.screenVals.height /me.ppd_);
					end
				otherwise
					switch inputtype
						case 'pixels'
							out(1) = (in(1) - me.screen.xCenter) / me.ppd_;
							out(2) = (in(2) - me.screen.yCenter) / me.ppd_;
						case 'relative'
							out(1) = (in - 0.5) * (me.screen.screenVals.width /me.ppd_);
							out(2) = (in - 0.5) * (me.screen.screenVals.height /me.ppd_);
					end
			end
		end
		
		% ===================================================================
		%> @brief
		%>
		% ===================================================================
		function initTracker(me)
			me.settings = Titta.getDefaults(me.model);
			me.settings.cal.bgColor = 127;
			me.tobii = Titta(me.settings);
		end
		
	end %------------------END PRIVATE METHODS
end

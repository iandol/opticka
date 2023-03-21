% ========================================================================
classdef runExperiment < optickaCore
%> @class runExperiment
%> @brief The main experiment manager.
%>
%> RUNEXPERIMENT accepts a task « taskSequence », stimuli « metaStimulus » and
%> for behavioural tasks a « stateMachine » state machine file, and runs the
%> stimuli based on the task objects passed. This class uses the fundamental
%> configuration of the screen (calibration, size etc. via « screenManager »),
%> and manages communication to a DAQ systems using digital I/O and
%> communication over a TCP/UDP client⇄server socket (via «dataConnection»).
%>
%> There are 2 main experiment types:
%>  1) MOC (method of constants) tasks -- uses stimuli and task objects
%>     directly to run standard randomised variable tasks. See optickatest.m
%>     for an example. Does not use the «stateMachine».
%>  2) Behavioural tasks that use state machines for control logic. These
%>     tasks still use stimuli and task objects to provide stimuli and
%>     variable lists, but use a state machine to control the task
%>     structure.
%>
%> Stimuli should be «metaStimulus» class, so for example:
%>
%> ```
%> myStim = metaStimulus;
%> myStim{1} = gratingStimulus('mask',true,'sf',1);
%> task = taskSequence; % this creates randomised variable lists
%> task.nVar = struct('name','angle','stimulus',1,'values',[-90 0 90]);
%> myExp = runExperiment('stimuli', myStim,'task', task);
%> runMOC(myExp); % run method of constants type experiment
%> ```
%>
%> will run a minimal experiment showing a 1c/d circularly masked grating.
%>
%> @todo refactor checkKey(): can we use a config for keyboard commands?
%>
%> Copyright ©2014-2022 Ian Max Andolina — released: LGPL3, see LICENCE.md
% ========================================================================	
	properties
		%> subject name
		subjectName char			= 'Simulcra'
		%> researcher name
		researcherName char			= 'Jane Doe'
		%> a metaStimulus class instance holding our stimulus objects
		stimuli metaStimulus
		%> a taskSequence class instance determining our stimulus variables
		task taskSequence
		%> a screenManager class instance managing the PTB Screen
		screen screenManager
		%> filename for a stateMachine state info file
		stateInfoFile char			= ''
		%> user functions file that can be passed to the state machine
		userFunctionsFile			= ''
		%> what strobe device to use
		%> device = display++ | datapixx | labjackt | labjack | arduino
		%> optional port = not needed for most of the interfaces
		%> optional config = plain | plexon style strobe
		%> optional stim OFF strobe value used for MOC tasks
		strobe struct				= struct('device','','port','',...
									'mode','plain','stimOFFValue',255)
		%> what reward device to use
		reward struct				= struct('device','','port','',...
									'board','');
		%> which eyetracker to use
		eyetracker struct			= struct('device','','dummy',true,...
									'esettings',[],'tsettings',[])
		%> use control commands to start / stop recording
		%> device = intan | plexon | none
		%> port = tcp port
		control struct				= struct('device','','port','127.0.0.1:5000')
		%> log all frame times?
		logFrames logical			= true
		%> enable debugging? (poorer temporal fidelity)
		debug logical				= false
		%> flip as fast as possible?
		benchmark logical			= false
		%> verbose logging to command window?
		verbose						= false
	end
	
	properties (Transient = true)
		%> structure for screenManager on initialisation and info from opticka
		screenSettings struct		= struct()
		%> this lets the opticka UI leave commands to runExperiment
		uiCommand char				= ''
		%> return if runExperiment is running (true) or not (false)
		isRunning logical			= false
	end
	
	properties (Hidden = true)
		%> draw simple fixation cross during trial for MOC tasks?
		drawFixation logical		= false
		%> shows the info text and position grid during stimulus presentation
		visualDebug logical			= false
		%> used to select single stimulus in training mode
		stimList					= []
		%> which stimulus is selected?
		thisStim					= []
		%> tS is the runtime settings structure, saved here as a backup
		tS
		%> what mode to run the Display++ digital I/O in? Plexon requires
		%> the use of a strobe trigger line, whereas most other equipment
		%> just uses simple threshold reading
		dPPMode char				= 'plain'
		%> which port is the arduino on?
		arduinoPort char			= ''
		%> show a white square in the top-right corner to trigger a photodiode
		%> attached to screen. This is only displayed when the stimulus is
		%> shown, not during the blank and can therefore be used for timing
		%> validation. For stateMachine tasks you need to pass in the drawing
		%> command for this to take effect.
		photoDiode logical			= false
		%> turn diary on for runTask, saved to the same folder as the data
		diaryMode logical			= false
		%> opticka version, passed on first use by opticka
		optickaVersion char
		%> do we record times for every function run by state machine?
		logStateTimers				= false
		%> do we ask for comments for runMOC
		comments					= true
		%> our old stimulus structure used to be a simple cell, now we use metaStimulus
		stimulus
	end

	properties (Transient = true, Hidden = true)
		%> keep track of several task values during runTask()
		lastXPosition				= 0
		lastYPosition				= 0
		lastXExclusion				= []
		lastYExclusion				= []
		lastSize					= 1
		lastIndex					= 0
	end
	
	properties (SetAccess = private, GetAccess = public)
		%> stateMachine
		stateMachine
		%> eyetracker manager object
		eyeTracker 
		%> generic IO manager
		io
		%> DataPixx control object
		dPixx 
		%> Display++ control object
		dPP 
		%> LabJack control object
		lJack 
		%> Arduino control object
		arduino
		%> user functions object
		userFunctions
		%> data connection
		dC
		%> state machine control cell array
		stateInfo cell				= {}
		%> general computer info retrieved using PTB Screen('computer')
		computer
		%> PTB version information: Screen('version')
		ptb
		%> copy of screen settings from screenManager
		screenVals struct
		%> log of timings for MOC tasks
		runLog
		%> log of timings for state machine tasks
		taskLog
		%> behavioural responses log
		behaviouralRecord
		%> previous info populated during load of a saved object
		previousInfo struct			= struct()
	end
	
	properties (SetAccess = private, GetAccess = private)
		%> general info on current run
		currentInfo
		%> variable info on the current run
		variableInfo
		%> send a strobe on next flip?
		sendStrobe logical			= false
		%> need an eyetracker sample on next flip?
		needSample logical			= false
		%> send an eyetracker SYNCTIME on next flip?
		sendSyncTime logical		= false
		%> do we flip the screen or not?
		doFlip logical				= true
		%> do we flip the eyetracker window? 0=no 1=yes 2=yes+clear
		doTrackerFlip double		= 0;
		%> fInc for managing keyboard sensitivity
		fInc						= 6
		%> is it MOC run (false) or stateMachine runTask (true)?
		isRunTask logical			= true
		%> are we using taskSequeence or not?
		isTask logical				= true
		%> should we stop the task?
		stopTask logical			= false
		%> prestimuli
		stimShown				= false
		%> properties allowed to be modified during construction
		allowedProperties = {'reward','strobe','eyetracker','control',...
			'logFrames','subjectName','researcherName'...
			'stateInfoFile','userFunctionFile','dummyMode','stimuli','task',...
			'screen','visualDebug','debug','verbose','screenSettings','benchmark'}
	end
	
	%=======================================================================
	methods %------------------PUBLIC METHODS
	%=======================================================================
		
		% ===================================================================
		function me = runExperiment(varargin)
		%> @fn runExperiment
		%>
		%> runExperiment CONSTRUCTOR
		%>
		%> @param varargin can be passed as a structure or name,arg pairs
		%> @return instance of the class.
		% ===================================================================
			args = optickaCore.addDefaults(varargin,struct('name','Run Experiment'));
			me=me@optickaCore(args); %superclass constructor
			me.parseArgs(args,me.allowedProperties);
		end
		
		% ===================================================================
		function runMOC(me, tS)
		%> @fn runMOC
		%> 
		%> runMOC uses built-in loop for experiment control and runs a
		%> methods-of-constants (MOC) experiment with the settings passed to
		%> it (stimuli,task and screen). This is different to the runTask
		%> method as it doesn't use a stateMachine for experimental logic,
		%> just a minimal deterministic trial+block loop. 
		%>
		%> @todo currently we can only record eye positions with the
		%> eyelink, add other tracker support
		%>
		%> @param me required class object
		%> @param tS structure with some options to pass
		% ===================================================================
			% we try not to use global variables, however the external eyetracker
			% API does not easily allow us to pass objects and so we use global
			% variables in this specific case...
			global rM %eyetracker calibration needs access to reward manager
					
			refreshScreen(me);
			initialiseSaveFile(me); %generate a savePrefix for this run
			me.name = [me.subjectName '-' me.savePrefix]; %give us a run name
			if isempty(me.screen) || isempty(me.task)
				me.initialise; %we set up screenManager and taskSequence objects
			end
			if me.screen.isPTB == false %NEED PTB!
				errordlg('There is no working PTB available!')
				error('There is no working PTB available!')
			end

			%===============================enable diary logging if requested
			if me.diaryMode
				diary off
				diary([me.paths.savedData filesep me.name '.log']);
			end

			%===============================initialise the rewardManager global object
			if ~isa(rM,'arduinoManager') 
				rM=arduinoManager();
			end
			if rM.isOpen
				rM.close; rM.reset;
			end

			%===============================enable diary logging if requested
			if me.diaryMode
				diary off
				diary([me.paths.savedData filesep me.name '.log']);
			end
			
			%===============================initialise runLog for this run
			me.previousInfo.runLog	= me.runLog;
			me.taskLog				= [];
			me.runLog				= timeLogger();
			tL						= me.runLog;
			tL.name					= me.name;
			if me.logFrames;tL.preAllocate(me.screenVals.fps*60*180);end
			%===============================make a short handle to the screenManager and metaStimulus objects
			me.stimuli.screen		= me.screen;
			s						= me.screen; 
			stims					= me.stimuli;
			if ~exist('tS','var') || isempty(tS)
				tS.controlPlexon		= false;
				tS.askForComments		= true;
			end
			if ~isfield(tS,'controlPlexon'); tS.controlPlexon = false; end
			if ~isfield(tS,'askForComments'); tS.askForComments = true; end

			%===============================initialise task
			task						= me.task;
			initialise(task, true);

			%-----------------------------------------------------------
			try%======This is our main TRY CATCH experiment display loop
			%-----------------------------------------------------------	
				me.lastIndex = 0;
				me.isRunning = true;
				me.isRunTask = false;

				%================================get pre-run comments for this data collection
				if tS.askForComments
					comment = inputdlg({'CHECK Recording system!!! Initial Comment for this Run?'},['Run Comment for ' me.name]);
					if ~isempty(comment)
						comment = comment{1};
						me.comment = [me.name ':' comment];
						bR.comment = me.comment; eT.comment = me.comment; sM.comment = me.comment; io.comment = me.comment; tL.comment = me.comment; tS.comment = me.comment;
					end
				end

				%=============================Premptive save in case of crash or error: SAVES IN /TMP
				rE = me;
				tS.tmpFile = [tempdir filesep me.name '.mat'];
				fprintf('===>>> Save initial state: %s\n',tS.tmpFile);
				save(tS.tmpFile,'rE','tS');
				
				%================================open the PTB screen and setup stimuli
				me.screenVals		= s.open(me.debug,tL);
				stims.verbose		= me.verbose;
				task.fps			= me.screenVals.fps;
				setup(stims, s); %run setup() for each stimulus
				if s.movieSettings.record; prepareMovie(s); end
				
				%================================initialise and set up I/O
				io					= configureIO(me); %#ok<*PROPLC> 
				dC					= dataConnection('protocol','tcp');
				
				%========================================Start amplifier
				% 
				if strcmp(me.control.device,'intan')
					addr = strsplit(me.control.port,':');
					dC.rAddress = addr{1};
					dC.rPort = addr{2};
					try 
						open(dC);
						write(dC,uint8(['set Filename.BaseFilename ' me.name]));
						write(dC,uint8(['set Filename.Path ' 'C:/OptickaFiles']));
						write(dC,uint8('set runmode run'));
					catch
						warning('runTask cannot contact intan!!!')
						me.control.device = '';
					end
				elseif strcmp(me.control.device,'plexon') 
					if strcmp(me.strobe.device,'datapixx') || strcmp(me.strobe.device,'display++')
						startRecording(io);
						WaitSecs(0.5);
						resumeRecording(io);
					elseif strcmp(me.strobe.device,'labjack')
						% Trigger the omniplex (TTL on FIO1) into paused mode
						io.setDIO([2,0,0]);WaitSecs(0.001);io.setDIO([0,0,0]);
						WaitSecs(0.5);
						io.setDIO([3,0,0],[3,0,0])%(Set HIGH FIO0->Pin 24), unpausing the omniplex
					end
				end

			
				%=========================================================
				% lets draw 2 seconds worth of the stimuli we will be using
				% covered by a blank. Primes the GPU and other components with the sorts
				% of stimuli/tasks used and this does appear to minimise
				% some of the frames lost on first presentation for very complex
				% stimuli using 32bit computation buffers...
				fprintf('\n===>>> Warming up the GPU and I/O systems... <<<===\n')
				show(stims);
				for i = 1:s.screenVals.fps*2
					draw(stims);
					drawBackground(s);
					drawText(s,'Warming up the GPU, Eyetracker and I/O systems...');
					s.drawPhotoDiodeSquare([0 0 0 1]);
					finishDrawing(s);
					animate(stims);
					if ~mod(i,10); io.sendStrobe(me.strobe.stimOFFValue); end
					flip(s);
					KbCheck(-1);
				end
				update(stims); %make sure stimuli are set back to their start state
				if ismethod(me,'resetLog'); resetLog(me); end
				io.resetStrobe;flip(s);flip(s);
				tL.screenLog.beforeDisplay = GetSecs();

				%===========================double check the labJackT handle is still valid
				if isa(io,'labJackT') && io.isOpen && ~io.isHandleValid
					io.close;
					io.open;
					disp('We had to reopen the labJackT to ensure a stable connection...')
				end
				
				%=============================profiling starts here if uncommented
				%profile clear; profile on;

				%===========================take over the keyboard + max priority
				KbReleaseWait; %make sure keyboard keys are all released
				if me.debug == false
					%warning('off'); %#ok<*WNOFF>
					ListenChar(-1); %2=capture all keystrokes
				end
				if ~isdeployed
					try commandwindow; end
				end
				Priority(MaxPriority(s.win)); %bump our priority to maximum allowed

				%================================Set state for first trial
				me.updateMOCVars(1,1); %------set the variables for the very first run
				task.isBlank				= true;
				task.tick					= 1;
				task.switched				= 1;
				task.totalRuns				= 1;
				tL.miss(1)					= 0;
				tL.stimTime(1)				= 0;
				tL.vbl(1)					= Screen('Flip', s.win);
				tL.lastvbl					= tL.vbl(1);
				tL.startTime				= tL.lastvbl;
				tL.screenLog.beforeDisplay	= tL.lastvbl;
				
				%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
				%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
				% DISPLAY LOOP
				%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
				%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
				while ~task.taskFinished
					if task.isBlank
						if me.photoDiode;s.drawPhotoDiodeSquare([0 0 0 1]);end
					else
						draw(stims);
						if me.photoDiode;s.drawPhotoDiodeSquare([1 1 1 1]);end
					end
					if s.visualDebug;s.drawGrid;me.infoTextScreen;end
					
					Screen('DrawingFinished', s.win); % Tell PTB that no further drawing commands will follow before Screen('Flip')
					
					%========= check for keyboard if in blank ========%
					if task.isBlank
						if strcmpi(me.uiCommand,'stop');break;end
						[~,~,kc] = KbCheck(-1);
						if strcmpi(KbName(kc),'q')
							%notify(me,'abortRun');
							break; %break the while loop
						end
					end

					%================= UPDATE TASK ===================%
					updateMOCTask(me); %update our task structure
					
					%=======Display++ or DataPixx: I/O send strobe
					% command for this screen flip needs to be sent
					% PRIOR to the flip! Also remember DPP will be
					% delayed by one flip
					if me.sendStrobe && matches(me.strobe.device,'display++')
						sendStrobe(io); me.sendStrobe = false;
					elseif me.sendStrobe && matches(me.strobe.device,'datapixx')
						triggerStrobe(io); me.sendStrobe = false;
					end
					
					%======= FLIP: Show it at correct retrace: ========%
					nextvbl = tL.lastvbl + me.screenVals.halfisi;
					if me.logFrames == true
						[tL.vbl(task.tick),tL.show(task.tick), ...
						tL.flip(task.tick),tL.miss(task.tick)] ...
							= Screen('Flip', s.win, nextvbl);
						tL.lastvbl = tL.vbl(task.tick);
					elseif ~me.benchmark
						[tL.vbl, tL.show, tL.flip, tL.miss] ...
							= Screen('Flip', s.win, nextvbl);
						tL.lastvbl = tL.vbl;
					else
						tL.vbl = Screen('Flip', s.win, 0, 2, 2);
						tL.lastvbl = tL.vbl;
					end

					%======LabJack: I/O needs to send strobe immediately after screen flip -----%
					if me.sendStrobe && matches(me.strobe.device,'labjackt')
						sendStrobe(io); me.sendStrobe = false;
					end
					
					%===================Logging=======================%
					if task.tick == 1 && ~me.benchmark
						tL.startTime=tL.vbl(1); %respecify this with actual stimulus vbl
					end
					if me.logFrames
						if ~task.isBlank
							tL.stimTime(task.tick)=1+task.switched;
						else
							tL.stimTime(task.tick)=0-task.switched;
						end
					end
					if s.movieSettings.record ...
							&& ~task.isBlank ...
							&& (s.movieSettings.loop <= s.movieSettings.nFrames)
						s.addMovieFrame();
					end
					%===================Tick tock!=======================%
					task.tick=task.tick+1; tL.tick = task.tick;
					
				end
				%==================================================================%
				%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
				% Finished display loop
				%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
				%==================================================================%
				
				ListenChar(0);
				s.drawBackground;
				vbl=Screen('Flip', s.win);
				tL.screenLog.afterDisplay=vbl;
				
				%================================Amplifier control
				if strcmp(me.control.device,'intan')
					write(dC,uint8('set runmode stop'));
				elseif strcmp(me.control.device,'plexon') 
					if strcmp(me.strobe.device,'datapixx') || strcmp(me.strobe.device,'display++')
						pauseRecording(io);
						WaitSecs(0.25)
						stopRecording(io);
					elseif strcmp(me.strobe.device,'labjack')
						io.setDIO([0,0,0],[1,0,0]); %this is RSTOP, pausing the omniplex
						io.setDIO([2,0,0]);WaitSecs(0.05);io.setDIO([0,0,0]); %we stop recording mode completely
					end
				end
				
				%-----get our profiling report for our task loop
				%profile off; profile report; profile clear
				
				tL.screenLog.deltaDispay=tL.screenLog.afterDisplay - tL.screenLog.beforeDisplay;
				tL.screenLog.deltaUntilDisplay=tL.startTime - tL.screenLog.beforeDisplay;
				tL.screenLog.deltaToFirstVBL=tL.vbl(1) - tL.screenLog.beforeDisplay;
				if me.benchmark == true
					tL.screenLog.benchmark = task.tick / (tL.screenLog.afterDisplay - tL.startTime);
					fprintf('\n---> BENCHMARK FPS = %g\n', tL.screenLog.benchmark);
				end
				
				s.screenVals.info = Screen('GetWindowInfo', s.win);
				
				try resetScreenGamma(s); end
				
				if matches(me.eyetracker.device,'eyelink')
					try close(me.eyeTracker); end
					me.eyeTracker = [];
				end
				
				try finaliseMovie(s,false); end
				
				try reset(stims); end
				try close(s); end
				try close(io); end

				removeEmptyValues(tL);
				me.tS = tS; %store our tS structure for backup

				if tS.askForComments
					comment = inputdlg('Final Comment for this Run?','Run Comment');
					if ~isempty(comment)
						comment = comment{1};
						me.comment = [me.comment ' | Final Comment: ' comment];
						bR.comment = me.comment;
						eT.comment = me.comment;
						sM.comment = me.comment;
						io.comment = me.comment;
						tL.comment = me.comment;
						tS.comment = me.comment;
					end
				end
				
				%------SAVE the DATA
				sname = [me.paths.savedData filesep me.name '.mat'];
				rE = me;
				save(sname,'rE','tS');
				fprintf('\n\n#####################\n===>>> SAVED DATA to: %s\n#####################\n\n',sname)
				
				tL.calculateMisses;
				if tL.nMissed > 0
					fprintf('\n!!!>>> >>> >>> There were %i MISSED FRAMES <<< <<< <<<!!!\n',tL.nMissed);
				end
				
				if s.movieSettings.record; playMovie(s); end
				
				me.isRunning = false;
				
			catch ME
				me.isRunning = false;
				fprintf('\n\n---!!! ERROR in runExperiment.runMOC()\n');
				try
					pauseRecording(io); %pause plexon
					WaitSecs(0.25)
					stopRecording(io);
					close(io);
				end
				%profile off; profile clear
				warning('on');
				Priority(0);
				ListenChar(0);
				ShowCursor;
				resetScreenGamma(s);
				try close(s); end
				try close(me.eyeTracker); end
				me.eyeTracker = [];
				me.behaviouralRecord = [];
				try close(rM); end
				me.lJack=[];
				me.io = [];
				clear tL s tS bR rM eT io sM
				rethrow(ME);
			end
		end %==============END runMOC
	
		% ===================================================================
		function runTask(me)
		%> @fn runTask
		%>
		%> runTask runs a state machine (behaviourally) driven task. 
		%> 
		%> Uses a StateInfo.m file to control the behavioural paradigm. The
		%> state machine controls the logic of the experiment, and this
		%> method manages the display loop.
		%>
		% ===================================================================
			% we try not to use global variables, however the external
			% eyetracker API does not easily allow us to pass objects and so
			% we use global variables in this specific case...
			global rM %#ok<*GVMIS> %global reward manager we can share with eyetracker 
			global aM %global audio manager we can share with eyetracker

			refreshScreen(me);
			initialiseSaveFile(me); %generate a savePrefix for this run
			me.comment = [me.comment ' ' me.name];
			me.name = [me.subjectName '-' me.savePrefix]; %give us a run name
			if isempty(me.screen) || isempty(me.task)
				me.initialise; %we set up screenManager and taskSequence objects
			end
			if me.screen.isPTB == false %NEED PTB!
				errordlg('There is no working PTB available!')
				error('There is no working PTB available!')
			end

			%------enable diary logging if requested
			if me.diaryMode
				diary off
				diary([me.paths.savedData filesep me.name '.log']);
			end

			%------make sure we reset any state machine functions to not cause
			% problems when they are reassigned below. For example, io interfaces
			% can be reset unless we clear this before we open the io.
			me.stateInfo = {};
			if isa(me.stateMachine,'stateMachine'); me.stateMachine.reset; me.stateMachine = []; end
			
			%------initialise the rewardManager global object
			if ~isa(rM,'arduinoManager') 
				rM=arduinoManager();
			end
			if rM.isOpen
				rM.close; rM.reset;
			end
			
			%------initialise an audioManager for beeps,playing sounds etc.
			if ~exist('aM','var') || isempty(aM) || ~isa(aM,'audioManager')
				aM=audioManager;
			end
			aM.silentMode = false;
			if ~aM.isSetup;	aM.setup; end
			aM.beep(1000,0.1,0.1);
			
			if isempty(regexpi(me.comment, '^Protocol','once'))
				me.comment = '';
			end
			
			fprintf('\n\n\n===>>>>>> Start task: %s <<<<<<===\n\n\n',me.name);
			
			%--------------------------------------------------------------
			% tS is a general structure to hold various parameters will be saved
			% after the run; prefer structure over class to keep it light. These
			% defaults can be overwritten by the StateFile.m
			tS							= struct();
			tS.name						= 'generic';%==name of this protocol
			tS.useTask					= false;	%==use taskSequence (randomised variable task object)
			tS.keyExclusionPattern		= ["fixate","stimulus"]; %==which states skip keyboard check
			tS.checkKeysDuringStimulus	= false;	%==allow keyboard control? Slight drop in performance
			tS.enableTrainingKeys		= false;	%==enable keys useful during task training, but not for data recording
			tS.recordEyePosition		= false;	%==record eye position within PTB, **in addition** to the eyetracker?
			tS.askForComments			= false;	%==little UI requestor asks for comments before/after run
			tS.saveData					= false;	%==save behavioural and eye movement data?
			tS.controlPlexon			= false;	%==send start/stop commands to a plexon?
			tS.showBehaviourPlot		= true;		%==open the behaviourPlot figure? Can cause more memory use
			tS.rewardTime				= 250;		%==TTL time in milliseconds
			tS.rewardPin				= 2;		%==Output pin, 2 by default with Arduino.
			tS.tOut						= 5;		%==if wrong response, how long to time out before next trial
			tS.useMagStim				= false;	%==set up magstim [deprecated]?
			tS.tobiiFlipRate			= 8;		%==how many flip frames constitute 1 tobii flip?
	
			%------initialise time logs for this run
			me.previousInfo.taskLog		= me.taskLog;
			me.runLog					= [];
			me.taskLog					= timeLogger();
			tL							= me.taskLog; %short handle to log
			tL.name						= me.name;
			if me.logFrames;tL.preAllocate(me.screenVals.fps*60*240);end
			
			%-----behavioural record
			me.behaviouralRecord		= behaviouralRecord('name',me.name); %#ok<*CPROP>
			bR							= me.behaviouralRecord; %short handle
		
			%------make a short handle to the screenManager and metaStimulus objects
			me.stimuli.screen			= me.screen;
			s							= me.screen; 
			stims						= me.stimuli;
			
			%------initialise task
			task						= me.task;
			initialise(task, true);
			
			%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
			try %================This is our main TASK setup=====================
			%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
				me.lastIndex			= 0;
				me.isRunning			= true;
				me.isRunTask			= true;
				
				%================================open the eyetracker interface
				if strcmp(me.eyetracker.device, 'tobii')
					me.eyeTracker		= tobiiManager();
					if ~isempty(me.eyetracker.tsettings); me.eyeTracker.addArgs(me.eyetracker.tsettings); end
				else
					me.eyeTracker		= eyelinkManager();
					if ~isempty(me.eyetracker.esettings); me.eyeTracker.addArgs(me.eyetracker.esettings); end
				end
				eT						= me.eyeTracker;
				eT.verbose				= me.verbose;
				eT.saveFile				= [me.paths.savedData filesep me.name '.edf'];
				if isempty(me.eyetracker.device)
					eT.isDummy			= true;
				else
					eT.isDummy			= me.eyetracker.dummy;
				end
				
				if isfield(tS,'rewardTime')
					bR.rewardTime		= tS.rewardTime;
				end
				
				%================================open the PTB screen and setup stimuli
				me.screenVals			= s.open(me.debug,tL);
				me.fInc = round(0.3 / (1 / me.screenVals.ifi)); %roughly <0.3s key press
				stims.verbose			= me.verbose;
				setup(stims, s); %run setup() for each stimulus
				task.fps				= s.screenVals.fps;
				
				%================================initialise and set up I/O
				io					= configureIO(me);
				dC					= me.dC;
				
				%================================initialise the user functions object
				if ~exist(me.userFunctionsFile,'file')
					me.userFunctionsFile = [me.paths.root filesep 'userFunctions.m'];
				end
				[p,f] = fileparts(me.userFunctionsFile);
				if ~matches(f,"userFunctions")
					copyfile(me.userFunctionsFile,[p filesep 'userFunctions.m']);
					run([p filesep 'userFunctions.m']);
				else	
					run(me.userFunctionsFile)
				end
				me.userFunctions = ans; %#ok<NOANS> 
				uF = me.userFunctions;
				uF.rE = me; uF.s = s; uF.task = task; uF.eT = eT;
				uF.stims = stims; uF.io = io; uF.rM = rM;

				%================================initialise the state machine
				sM						= stateMachine('verbose', me.verbose,...
						'realTime', task.realTime, 'timeDelta', s.screenVals.ifi, ...
						'name', me.name);
				me.stateMachine			= sM;
				sM.fnTimers				= me.logStateTimers; %record fn evaluations?
				if isempty(me.stateInfoFile) || ~exist(me.stateInfoFile,'file') || strcmp(me.stateInfoFile, 'DefaultStateInfo.m')
					me.stateInfoFile = [me.paths.root filesep 'DefaultStateInfo.m'];
					me.paths.stateInfoFile = me.stateInfoFile; 
				end
				if ~exist(me.stateInfoFile,'file')
					errordlg('runExperiment.runTask(): Please specify a valid State Machine file!!!')
				else
					me.stateInfoFile = regexprep(me.stateInfoFile,'\s+','\\ ');
					disp(['======>>> Loading State File: ' me.stateInfoFile]);
					clear(me.stateInfoFile);
					if ~isdeployed
						run(me.stateInfoFile);
					else
						runDeployed(me.stateInfoFile);
					end
					me.stateInfo = stateInfoTmp;
					addStates(sM, me.stateInfo);
					me.paths.stateInfoFile = me.stateInfoFile;
				end
				uF.sM = sM;
				
				%================================set up the eyetracker interface
				configureEyetracker(me, eT, s);

				%================================get pre-run comments for this data collection
				if tS.askForComments
					comment = inputdlg({'CHECK Recording system!!! Initial Comment for this Run?'},['Run Comment for ' me.name]);
					if ~isempty(comment)
						comment = comment{1};
						me.comment = [me.name ':' comment];
						bR.comment = me.comment; eT.comment = me.comment; sM.comment = me.comment; io.comment = me.comment; tL.comment = me.comment; tS.comment = me.comment;
					end
				end

				%============================================================WARMUP
				% lets draw ~1 seconds worth of the stimuli we will be using
				% covered by a blank. This primes the GPU, eyetracker, IO
				% and other components with the same stimuli/task code used later...
				fprintf('\n===>>> Warming up the GPU, Eyetracker and I/O systems... <<<===\n')
				tSM = stateMachine();
				tSM.warmUp(); clear tSM;
				show(stims); % allows all child stimuli to be drawn
				getStimulusPositions(stims);
				if ~isempty(me.eyetracker.device); resetAll(eT);trackerClearScreen(eT); end % blank eyelink screen
				for i = 1:s.screenVals.fps*1
					draw(stims); % draw all child stimuli
					drawBackground(s); % draw our blank background
					drawPhotoDiodeSquare(s, [mod(i,2) mod(i,2) mod(i,2) 1]); % set our photodiode square white
					drawText(s,'Warming up the GPU, Eyetracker and I/O systems...');
					finishDrawing(s);
					animate(stims); % run our stimulus animation routines to the next frame
					if ~mod(i,10); sendStrobe(io, 255); end % send a strobed word
					if ~isempty(me.eyetracker.device)
						getSample(eT); % get an eyetracker sample
						if i == 1
							trackerMessage(eT,sprintf('WARMUP_TEST %i',getTaskIndex(me)));
							trackerDrawStatus(eT,'Warming Up System',stims.stimulusPositions); 
						end
					end
					flip(s);
					KbCheck(-1);
					if eT.secondScreen; trackerFlip(eT, 1); end
				end
				update(stims); %make sure all stimuli are set back to their start state
				resetLog(stims);
				if ~isempty(me.eyetracker.device)
					resetAll(eT);
					trackerClearScreen(eT);
					if eT.secondScreen; trackerFlip(eT, 0, true); end 
				end
				resetStrobe(io); flip(s); flip(s); % reset the strobe system

				%=============================Premptive save in case of crash or error: SAVES IN /TMP
				rE = me;
				tS.tmpFile = [tempdir filesep me.name '.mat'];
				fprintf('===>>> Save initial state: %s\n',tS.tmpFile);
				save(tS.tmpFile,'rE','tS');

				%=============================Ensure we open the reward manager
				if matches(me.reward.device,'arduino') && isa(rM,'arduinoManager') && ~rM.isOpen
					fprintf('======>>> Opening Arduino for sending reward TTLs\n')
					open(rM);
				elseif matches(me.reward.device,'labjack') && isa(rM,'labJack')
					fprintf('======>>> Opening LabJack for sending reward TTLs\n')
					open(rM);
				end
				
				%===========================Start amplifier
				% 
				if strcmp(me.control.device,'intan')
					try
						if ~dC.isOpen; open(dC); end
						write(dC,uint8(['set Filename.BaseFilename ' me.name]));
						write(dC,uint8(['set Filename.Path ' me.paths.savedData]));
						write(dC,uint8(['set Note1 ' me.name]));
						write(dC,uint8(['set Note2 ' me.comment]));
						write(dC,uint8('set runmode record'));
						WaitSecs(0.5);
					catch
						warning('runTask cannot contact intan!!!')
						me.control.device = '';
					end
				elseif strcmp(me.control.device,'plexon') 
					if strcmp(me.strobe.device,'datapixx') || strcmp(me.strobe.device,'display++')
						startRecording(io);
						WaitSecs(0.5);
						resumeRecording(io);
					elseif strcmp(me.strobe.device,'labjack')
						% Trigger the omniplex (TTL on FIO1) into paused mode
						io.setDIO([2,0,0]);WaitSecs(0.001);io.setDIO([0,0,0]);
						WaitSecs(0.5);
						io.setDIO([3,0,0],[3,0,0])%(Set HIGH FIO0->Pin 24), unpausing the omniplex
					end
				end

				%===========================Initialise our various counters
				task.tick					= 1;
				task.switched				= 1;
				task.totalRuns				= 1;
				me.isTask					= tS.useTask;
				if me.isTask 
					updateVariables(me, task.totalRuns, true, false); % set to first variable
					update(stims); %update our stimuli ready for display
				else
					updateVariables(me, 1, false, false); % set to first variable
					update(stims); %update our stimuli ready for display
				end
				tS.keyTicks				= 0; %tick counter for reducing sensitivity of keyboard
				tS.keyHold				= 1; %a small loop to stop overeager key presses
				tS.totalTicks			= 1; % a tick counter
				tS.pauseToggle			= 1; %toggle pause/unpause
				tS.eyePos				= []; %locally record eye position
				tS.initialTaskIdx.comment	= 'This is the task index before the task starts, it may be modified by resetRun() during task...';
				tS.initialTaskIdx.index		= task.outIndex;
				tS.initialTaskIdx.vars		= task.outValues;
				
				%===========================double check the labJackT handle is still valid
				if isa(io,'labJackT') && ~io.isHandleValid
					io.close;
					io.open;
					warning('We had to reopen the labJackT to ensure a stable connection...')
				end
				
				%===========================set up our behavioural plot
				if tS.showBehaviourPlot; createPlot(bR, eT); drawnow; end

				%===========================take over the keyboard + max priority
				KbReleaseWait; %make sure keyboard keys are all released
				if me.debug == false
					%warning('off'); %#ok<*WNOFF>
					ListenChar(-1); %2=capture all keystrokes
				end
				if ~isdeployed
					try commandwindow; end
				end
				Priority(MaxPriority(s.win)); %bump our priority to maximum allowed

				%=============================profiling starts here if uncommented
				%profile clear; profile on;
				
				%=============================initialise our log times and vbl's
				me.needSample				= false;
				me.stopTask					= false;
				me.doFlip					= false;
				me.doTrackerFlip			= false;
				me.sendStrobe				= false;
				tL.vbl(1)					= Screen('Flip', s.win);
				tL.lastvbl					= tL.vbl(1);
				tL.miss(1)					= 0;
				tL.stimTime(1)				= 0;
				tL.startTime				= tL.lastvbl;
				tL.screenLog.beforeDisplay	= tL.lastvbl;
				tL.screenLog.trackerStartTime = getTrackerTime(eT);
				tL.screenLog.trackerStartOffset = getTimeOffset(eT);
				
				%==============================IGNITE the stateMachine!
				fprintf('\n===>>> Igniting the State Machine... <<<===\n');
				start(sM);

				%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
				%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
				% Display + task loop
				%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
				%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
				while me.stopTask == false
					
					%------run the stateMachine one step forward
					update(sM);
					if me.doFlip && s.visualDebug; s.drawGrid; me.infoTextScreen; end
					if me.doFlip; s.finishDrawing(); end % potential optimisation, but note stateMachine may run non-drawing tasks in update()
					
					%------check eye position manually. Also potentially log
					% this retrieved value, but REMEMBER eyetracker will save
					% the properly sampled eye data in the EDF; this is
					% just a backup sampled at the GPU FPS wrapped in the
					% PTB loop.
					if me.needSample; getSample(eT); end
					if tS.recordEyePosition && strcmp(me.eyetracker.device,'eyelink')
						saveEyeInfo(me, sM, eT, tS);
					end
					
					%------Check keyboard for commands (remember we can turn
					% this off using either tS.keyExclusionPattern
					% [per-state toggle] or tS.checkKeysDuringStimulus).
					if ~matches(sM.currentName,tS.keyExclusionPattern)
						tS = checkKeys(me,tS);
					end
					
					%-----FLIP: Show it at correct retrace: -----%
					if me.doFlip
						%------Display++ or DataPixx: I/O send strobe
						% command for this screen flip needs to be sent
						% PRIOR to the flip! Also remember DPP will be
						% delayed by one flip
						if me.sendStrobe && strcmp(me.strobe.device,'display++')
							sendStrobe(io); me.sendStrobe = false;
						elseif me.sendStrobe && strcmp(me.strobe.device,'datapixx')
							triggerStrobe(io); me.sendStrobe = false;
						end
						%------Do the actual Screen flip, save times if
						% enabled.
						nextvbl = tL.lastvbl + me.screenVals.halfisi;
						if me.logFrames == true
							[tL.vbl(tS.totalTicks),tL.show(tS.totalTicks),...
							tL.flip(tS.totalTicks),tL.miss(tS.totalTicks)] ...
							= Screen('Flip', s.win, nextvbl);
							tL.lastvbl = tL.vbl(tS.totalTicks);
							thisN = tS.totalTicks;
						elseif ~me.benchmark
							[tL.vbl, tL.show, tL.flip, tL.miss] = Screen('Flip', s.win, nextvbl);
							tL.lastvbl = tL.vbl;
							thisN = 1;
						else
							tL.vbl = Screen('Flip', s.win, 0, 2, 2);
							tL.lastvbl = tL.vbl;
							thisN = 0;
						end

						%----- LabJack: I/O needs to send strobe immediately after screen flip -----%
						if me.sendStrobe && matches(me.strobe.device,'labjackt')
							sendStrobe(io); me.sendStrobe = false;
							%Eyelink('Message', sprintf('MSG:SYNCSTROBE value:%i @ vbl:%20.40g / totalTicks: %i', io.sendValue, tL.lastvbl, tS.totalTicks));
						end

						%----- Send Eyetracker messages -----%
						if me.sendSyncTime % sends SYNCTIME message to eyetracker
							syncTime(eT);
							me.sendSyncTime = false;
						end

						%------Log stim / no stim + missed frame -----%
						if thisN > 0
							logStim(tL,sM.currentName,thisN);
						end

						%-------If we missed a frame record it somewhere -----%
						if me.debug && thisN > 0 && tL.miss(thisN) > 0 && tL.stimTime(thisN) > 0
							addMessage(tL,[],[],'We missed a frame during stimulus'); 
						end
						
						%----- increment our global tick counter -----%
						tS.totalTicks = tS.totalTicks + 1; tL.tick = tS.totalTicks;
					else % me.doFlip == FALSE
						% still wait for IFI time
						WaitSecs(s.screenVals.ifi);
					end  % END me.doFlip

					%----- For second display, do we flip? -----%
					if me.doTrackerFlip == 1 
						trackerFlip(eT)
					elseif me.doTrackerFlip == 2 
						trackerFlip(eT, 1)
					elseif me.doTrackerFlip == 3 
						trackerFlip(eT, 1, true)
					end
					
				%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
				end %======================END OF TASK LOOP=========================
				%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
				
				tL.screenLog.afterDisplay = tL.lastvbl;
				tL.screenLog.trackerEndTime = getTrackerTime(eT);
				tL.screenLog.trackerEndOffset = getTimeOffset(eT);
				me.isRunning = false;
				
				try %#ok<*TRYNC> 
					drawBackground(s);
					trackerClearScreen(eT);
					trackerDrawStatus(eT,['FINISHED TASK:' me.name]);
					trackerFlip(eT,0);
					Screen('Flip', s.win);
					Priority(0);
					ListenChar(0);
					RestrictKeysForKbCheck([]);
					ShowCursor;
					warning('on');
				end

				try updatePlot(bR, me); end %update our behavioural plot for final state
				try show(stims); end %make all stimuli visible again, useful for editing
				try reset(stims); end %reset stims back to initial state
				
				%-----get our profiling report for our task loop
				%profile off; profile viewer;

				%================================Amplifier control
				if strcmp(me.control.device,'intan')
					write(dC,uint8('set runmode stop'));
				elseif strcmp(me.control.device,'plexon') 
					if strcmp(me.strobe.device,'datapixx') || strcmp(me.strobe.device,'display++')
						pauseRecording(io);
						WaitSecs(0.25)
						stopRecording(io);
					elseif strcmp(me.strobe.device,'labjack')
						io.setDIO([0,0,0],[1,0,0]); %this is RSTOP, pausing the omniplex
						io.setDIO([2,0,0]);
						WaitSecs(0.05);
						io.setDIO([0,0,0]); %we stop recording mode completely
					end
				end
				
				try close(s); end %screen
				try close(io); end % I/O system
				try close(eT); end % eyetracker, should save the data for us we've already given it our name and folder
				try close(aM); end % audio manager
				try close(rM); end % reward manager
				try close(dC); end % data connection
				
				WaitSecs(0.25);
				fprintf('\n\n======>>> Total ticks: %g | stateMachine ticks: %g\n', tS.totalTicks, sM.totalTicks);
				fprintf('======>>> Tracker Time: %g | PTB time: %g | Drift Offset: %g\n', ...
					tL.screenLog.trackerEndTime-tL.screenLog.trackerStartTime, ...
					tL.screenLog.afterDisplay-tL.screenLog.beforeDisplay, ...
					tL.screenLog.trackerEndOffset-tL.screenLog.trackerStartOffset);
		
				if isfield(tS,'eO')
					close(tS.eO)
					tS.eO=[];
				end
				
				if tS.askForComments
					comment = inputdlg('Final Comment for this Run?','Run Comment');
					if ~isempty(comment)
						comment = comment{1};
						me.comment = [me.comment ' | Final Comment: ' comment];
						bR.comment = me.comment;
						eT.comment = me.comment;
						sM.comment = me.comment;
						io.comment = me.comment;
						tL.comment = me.comment;
						tS.comment = me.comment;
					end
				end
				
				removeEmptyValues(tL);
				me.tS = tS; %store our tS structure for backup
				
				%------SAVE the DATA
				if tS.saveData
					sname = [me.paths.savedData filesep me.name '.mat'];
					rE = me;
					save(sname,'rE','tS');
					fprintf('\n\n#####################\n===>>> <strong>SAVED DATA to: %s</strong>\n#####################\n\n',sname)
					assignin('base', 'tS', tS); % assign tS in base for manual checking
				end

				%------disable diary logging 
				if me.diaryMode; diary off; end
				
				me.stateInfo = [];
				try
					if isa(me.stateMachine,'stateMachine'); me.stateMachine.reset; end
					if isa(me.stimuli,'metaStimulus'); me.stimuli.reset; end
				end
				
			catch ME
				me.isRunning = false;
				fprintf('\n\n===!!! ERROR in runExperiment.runTask()\n');
				try reset(stims); end
				try close(s); end
				try close(aM); end
				try close(eT); end
				try close(rM); end
				if exist('io','var')
					try pauseRecording(io); end%pause plexon
					WaitSecs(0.25)
					try stopRecording(io); end
					try close(io); end
				end
				%profile off; profile clear
				warning('on') 
				Priority(0);
				ListenChar(0); RestrictKeysForKbCheck([]);
				ShowCursor;
				me.eyeTracker = [];
				me.behaviouralRecord = [];
				me.lJack=[];
				me.io = [];
				rethrow(ME)
			end

		end
		% ===================================================================
		function initialise(me, config)
		%> @fn initialise
		%>
		%> Prepares run for the local machine 
		%>
		%> @param config [nostimuli
		%> | noscreen | notask] allows excluding screen / task initialisation
		% ===================================================================
			if ~exist('config','var')
				config = '';
			end
			if me.debug == true %let screen inherit debug settings
				me.screenSettings.debug = true;
				me.screenSettings.visualDebug = true;
			end
			
			if ~contains(config,'nostimuli') && (isempty(me.stimuli) || ~isa(me.stimuli,'metaStimulus'))
				me.stimuli = metaStimulus();
			end
			
			if ~contains(config,'noscreen') && (isempty(me.screen) || ~isa(me.stimuli,'screenManager'))
				me.screen = screenManager(me.screenSettings);
			end
			
			if ~contains(config,'notask') && (isempty(me.task) || ~isa(me.stimuli,'taskSequence'))
				me.task = taskSequence();
				me.task.initialise();
			end
			
			if contains(me.strobe.device,'display++')
				me.dPP = plusplusManager();
			elseif contains(me.strobe.device,'datapixx')
				me.dPixx = dPixxManager();
			end
			
			if ~isdeployed && isempty(me.stateInfoFile)
				if exist([me.paths.root filesep 'DefaultStateInfo.m'],'file')
					me.stateInfoFile = [me.paths.root filesep 'DefaultStateInfo.m'];
				end
			end

			if ~isdeployed && isempty(me.userFunctionsFile)
				if exist([me.paths.root filesep 'userFunctions.m'],'file')
					me.userFunctionsFile = [me.paths.root filesep 'userFunctions.m'];
				end
			end
				
			try me.computer=Screen('computer'); end
			try me.ptb=Screen('version'); end
		
			if ~isempty(me.screen); me.screenVals = me.screen.screenVals; end

			me.fInc = round(0.3 / (1/me.screenVals.ifi));
			
			me.stopTask = false;
			
			if isa(me.runLog,'timeLogger')
				me.runLog.screenLog.prepTime=me.runLog.timer()-me.runLog.screenLog.construct;
			end
			
		end
		
		% ===================================================================
		function checkTaskEnded(me)
		%> @fn checkTaskEnded
		%> Check if stateMachine has finished, set me.stopTask true
		%>
		% ===================================================================
			if me.stateMachine.isRunning && me.task.taskFinished
				me.stopTask = true;
			end
		end
		
		% ===================================================================
		function error = checkScreenError(me)
		%> @fn checkScreenError
		%> check if screenManager is in a good state
		%>
		% ===================================================================
			testWindowOpen(me.screen);
			if me.isRunning && ~me.screen.isOpen
				me.isRunning = false;
				error = true;
			else
				error = false;
			end
		end
		
		% ===================================================================
		function showTimingLog(me)
		%> @fn showTimingLog 
		%>
		%> Prints out the frame time plots from a run
		%>
		% ===================================================================
			if isa(me.taskLog,'timeLogger') && me.taskLog.vbl(1) ~= 0
				me.taskLog.plot;
			elseif isa(me.runLog,'timeLogger') && me.runLog.vbl(1) ~= 0
				me.runLog.plot;
			else
				warndlg('No log available yet...');
			end
		end
		
		% ===================================================================
		function updateFixationTarget(me, useStimuli, varargin)
		%> @fn updateFixationTarget
		%>
		%> Sometimes you want the fixation to follow the position of a particular
		%> stimulus. We can 'tag' the stimulus using metaStimulus.fixationChoice
		%> and then use this method to get the current position and update the
		%> eyetracker fixation window[s] to match the stimuli we tagged.
		%>
		%> @param useStimuli do we use the current stimuli positions or the last
		%> known positions that are stored in me.stimuli.last[X|Y]Position.
		%> @param varargin the rest of the parameters normally passed to 
		%> eyeTracker.updateFixationValues: inittime,fixtime,radius,strict
		% ===================================================================
			if ~exist('useStimuli','var');	useStimuli = false; end
			if useStimuli 
				[me.lastXPosition,me.lastYPosition] = getFixationPositions(me.stimuli);
				updateFixationValues(me.eyeTracker, me.lastXPosition, me.lastYPosition, varargin);
			else
				updateFixationValues(me.eyeTracker, me.stimuli.lastXPosition, me.stimuli.lastYPosition, varargin);
			end
		end
		
		% ===================================================================
		function updateExclusionZones(me, useStimuli, radius)
		%> @fn updateExclusionZones
		%>
		%> Updates eyetracker with current stimuli tagged for exclusion
		%> using metaStimulus.exclusionChoice
		%>
		%> @param useStimuli use the metaStimulus parameters
		%> @param radius of the exclusion zone
		% ===================================================================
			if ~exist('useStimuli','var');	useStimuli = false; end
			if useStimuli 
				[me.lastXExclusion,me.lastYExclusion] = getExclusionPositions(me.stimuli);
				updateExclusionZones(me.eyeTracker, me.lastXExclusion, me.lastYExclusion, radius);
			else 
				updateExclusionZones(me.eyeTracker, me.stimuli.lastXExclusion, me.stimuli.lastYExclusion, radius);
			end
		end
		
		% ===================================================================
		function updateConditionalFixationTarget(me, stimulus, variable, value, varargin)
		%> @fn updateConditionalFixationTarget
		%>
		%> Checks the variable value of a stimulus (e.g. its angle) and
		%> then sets a fixation target based on that value, so you can use
		%> multiple test stimuli and set the target to one of them in a forced
		%> choice paradigm that matches the variable value
		%>
		%> @param stimulus	which stimulus or stimuli to check
		%> @param variable	which variable to check
		%> @param value		which value to check for
		%> @param varargin	additional parameters to set the fixation window
		% ===================================================================
			selected = [];
			try
				for i = stimulus
					thisValue = me.stimuli{stimulus}.([variable 'Out']); %get our value
					if ischar(value)
						if strcmpi(thisValue,value); selected = [selected i]; end
					elseif isnumeric(value)
						if all(thisValue == value); selected = [selected i]; end
					end
				end
			end
			if ~isempty(selected)
				me.stimuli.fixationChoice = selected;
				[me.lastXPosition,me.lastYPosition] = getFixationPositions(me.stimuli);
				updateFixationValues(me.eyeTracker, me.lastXPosition, me.lastYPosition, varargin);
			end
		end
		
		% ===================================================================
		function keyOverride(me)
		%> @fn keyOverride
		%> @brief when running allow keyboard override, so we can edit/debug
		%>  things within the loop!
		%>
		% ===================================================================
			KbReleaseWait; %make sure keyboard keys are all released
			ListenChar(0); %capture keystrokes
			ShowCursor;
			myVar = 0;
			dbstop in clear
			% we have halted the debugger. You can now inspect the workspace and the
			% various objects. me is the runExperiment instance, you can access
			% me.screen for screenManager, me.task for taskSequence, me.stimuli for
			% metaStimulus, me.stateMachine for stateMachine, and other objects...
			% PRESS F5 to exit this mode and return to the experiment...
			clear myVar
			dbclear in clear
			ListenChar(-1); %capture keystrokes
			HideCursor;
		end
		
		% ===================================================================
		function set.verbose(me,value)
		%> @fn set.verbose
		%>
		%> Let us cascase verbosity to other classes
		% ===================================================================
			value = logical(value);
			me.verbose = value;
			if isa(me.task,'taskSequence') && ~isempty(me.task) %#ok<*MCSUP>
				me.task.verbose = value;
			end
			if isa(me.screen,'screenManager') && ~isempty(me.screen)
				me.screen.verbose = value;
			end
			if isa(me.stateMachine,'stateMachine') && ~isempty(me.stateMachine)
				me.stateMachine.verbose = value;
			end
			if (isa(me.eyeTracker,'eyelinkManager') || isa(me.eyeTracker,'tobiiManager')) && ~isempty(me.eyeTracker)
				me.eyeTracker.verbose = value;
			end
			if isa(me.lJack,'labJack') && ~isempty(me.lJack)
				me.lJack.verbose = value;
			end
			if isa(me.dPixx,'dPixxManager') && ~isempty(me.dPixx)
				me.dPixx.verbose = value;
			end
			if isa(me.dPP,'plusplusManager')  && ~isempty(me.dPP)
				me.dPP.verbose = value;
			end
			if isa(me.stimuli,'metaStimulus') && ~isempty(me.stimuli) && me.stimuli.n > 0
				for i = 1:me.stimuli.n
					me.stimuli{i}.verbose = value;
				end
			end
			if value; me.salutation(sprintf('Cascaded Verbose = %i to all objects...',value),[],true); end
		end
		
		% ===================================================================
		function set.stimuli(me,in)
		%> @fn set.stimuli
		%>
		%> Migrate to use a metaStimulus object to manage stimulus objects
		% ===================================================================
			if isempty(me.stimuli) || ~isa(me.stimuli,'metaStimulus')
				me.stimuli = metaStimulus();
			end
			if isa(in,'metaStimulus')
				me.stimuli = in;
			elseif isa(in,'baseStimulus')
				me.stimuli{1} = in;
			elseif iscell(in)
				me.stimuli.stimuli = in;
			end
		end
		
		% ===================================================================
		function randomiseTrainingList(me)
		%> @fn randomiseTrainingList
		%>
		%> For single stimulus presentation, randomise stimulus choice
		%>
		% ===================================================================
			if ~isempty(me.thisStim)
				me.thisStim = randi(length(me.stimList));
				me.stimuli.choice = me.thisStim;
			end
		end
		
		% ===================================================================
		function setStrobeValue(me, value)
		%> @fn setStrobeValue
		%>
		%> Set strobe value
		%>
		%> @param value the value to set the I/O system
		% ===================================================================
			if value == Inf; value = me.strobe.stimOFFValue; end
			if strcmp(me.strobe.device, 'display++')
				prepareStrobe(me.dPP, value);
			elseif strcmp(me.strobe.device, 'datapixx')
				prepareStrobe(me.dPixx, value);
			elseif strcmp(me.strobe.device, 'labjackt') || strcmp(me.strobe.device, 'labjack')
				prepareStrobe(me.lJack, value);
			end
		end
		
		% ===================================================================
		function doStrobe(me, value)
		%> @fn doStrobe
		%> 
		%> set I/O strobe to trigger on next flip
		%>
		%> @param value true or false
		% ===================================================================
			if isempty(value) || value == true
				me.sendStrobe = true;
			else
				me.sendStrobe = false;
			end
		end
		
		% ===================================================================
		function doSyncTime(me)
		%> @fn doSyncTime
		%>
		%> send SYNCTIME message to eyelink after flip
		%> 
		% ===================================================================
			me.sendSyncTime = true;
		end


		% ===================================================================
		function needEyeSample(me, value)
		%> @fn needEyeSample
		%> @brief set needSample if eyeManager getSample on current flip?
		%>
		%> @param value
		% ===================================================================
			if ~exist('value','var'); value = true; end
			me.needSample = value;
		end

		% ===================================================================
		function needFlip(me, value)
		%> @fn enableFlip
		%>
		%> Enable screen flip
		%> 
		% ===================================================================
			if ~exist('value','var'); value = true; end
			me.doFlip = value;
		end

		% ===================================================================
		function needFlipTracker(me, value)
		%> @fn needFlipTracker
		%>
		%> enables/disable the flip for the tracker display window
		%> @param 0: disable flip, 1 enable + clear, 2 enable + don't clear, 3 force
		% ===================================================================
			if ~exist('value','var'); value = 0; end
			me.doTrackerFlip = value;
		end
		
		% ===================================================================
		function trial = getTaskIndex(me, index)
		%> @fn getTaskIndex
		%>
		%> This method gets the unique value of the current trial from
		%> taskSequence. This is useful for sending to the eyetracker or I/O
		%> devices to label which variable value is being shown.
		%>
		%> @param the index to a particular trial
		%> @return the unique variable number
		% ===================================================================
			if ~exist('index','var') || isempty(index)
				index = me.task.totalRuns;
			end
			if index > 0 && ~isempty(me.task.outIndex) && length(me.task.outIndex) >= index
				trial = me.task.outIndex(index);
			else
				trial = -1;
			end
		end
		
		% ===================================================================
		function logRun(me,tag)
		%> @fn logRun
		%> @brief print run info to command window
		%>
		%> @param tag what name to give this log printout
		% ===================================================================
			if me.isRunning
				if ~exist('tag','var'); tag = '#'; end
				t = sprintf('===>%s:%s',tag,infoText(me));
				fprintf('%s\n',t);
				me.behaviouralRecord.info = t;
				if me.isRunTask
					me.taskLog.addMessage([],[],t);
				else
					me.runLog.addMessage([],[],t);
				end
			end			
		end
		
		% ===================================================================
		function updateTask(me,result)
		%> @fn updateTask 
		%> Updates taskSequence with current info and the result for that trial
		%> running the taskSequence.updateTask function
		%>
		%> @param result an integer result, e.g. 1 = correct or -1 = breakfix
		% ===================================================================
			info = ''; sinfo = '';
			if ~isempty(me.eyetracker.device)
				info = sprintf('window=%i; isBlink=%i; isExclusion=%i; isFix=%i; isInitFail=%i; fixTotal=%g',...
					me.eyeTracker.fixWindow, me.eyeTracker.isBlink, me.eyeTracker.isExclusion, ...
					me.eyeTracker.isFix, me.eyeTracker.isInitFail, me.eyeTracker.fixTotal);
			end
			for i = 1:me.stimuli.n
				sinfo = sprintf('%s stim:%i<tick:%i drawtick:%i>',sinfo,i,me.stimuli{i}.tick,me.stimuli{i}.drawTick);
			end
			info = [info ' ' sinfo '\n' me.variableInfo];
			updateTask(me.task,result,GetSecs,info); %do this before getting index
		end
		
		% ===================================================================
		function updateNextState(me, type)
		%> @fn updateNextState
		%> taskSequence can generate a trial factor, and we can set these to
		%> the name of a state in the stateMachine. This means we can choose
		%> a state based on the trial factor in taskSequence. This sets
		%> stateMacine.tempNextState to override the state table next field.
		%>
		%> @param type - whether to use 'trial' [default] or 'block' factor
		% ===================================================================
			if ~exist('type','var'); type = 'trial'; end
			if me.isTask && me.isRunTask
				switch type
					case {'block'}
						thisName = me.task.outBlock{me.task.totalRuns};
					otherwise
						thisName = me.task.outTrial{me.task.totalRuns};
				end
				if ~isempty(thisName) && me.stateMachine.isStateName(thisName)
					if me.verbose; fprintf('!!!>>> Next STATE selected: %s\n',thisName); end
					me.stateMachine.tempNextState = thisName;
				end
			end 
		end
		
		
		% ===================================================================
		function updateVariables(me, index, override, update)
		%> @fn updateVariables
		%> Updates the stimulus objects with the current variable set from taskSequence()
		%> 
		%> @param index a single value of which the overall trial number is
		%> @param override - forces updating even if it is the same trial
		%> @param update - do we also run taskSequence.updateTask() as well?
		% ===================================================================
			if ~exist('update','var') || isempty(update)
				update = false;
			end
			if update == true
				me.updateTask(true); %do this before getting new index
			end
			if ~exist('index','var') || isempty(index)
				index = me.task.totalRuns;
			end
			if ~exist('override','var') || isempty(override)
				override = true;
			end
			if ~isempty(me.strobe.device)
				if me.isTask
					setStrobeValue(me, me.task.outIndex(index));
				else
					setStrobeValue(me, index);
				end
			end
			if me.isTask && ((index > me.lastIndex) || override == true)
				[thisBlock, thisRun, thisVar] = me.task.findRun(index);
				stimIdx = []; 
				t = sprintf('updateVariables: B:%i R:%i T:%i V:%i>',thisBlock, thisRun, index, thisVar);
				for i=1:me.task.nVars
					valueList = cell(1); oValueList = cell(1); %#ok<NASGU>
					doXY = false;
					stimIdx = me.task.nVar(i).stimulus; %which stimuli
					value=me.task.outVars{thisBlock,i}(thisRun);
					if iscell(value)
						value = value{1};
					end
					[valueList{1,1:size(stimIdx,2)}] = deal(value);
					name=[me.task.nVar(i).name 'Out']; %which parameter
					
					if regexpi(name,'^xyPositionOut','once')
						doXY = true;
						me.lastXPosition = value(1);
						me.lastYPosition = value(2);
					elseif regexpi(name,'^xPositionOut','once')
						me.lastXPosition = value;
					elseif regexpi(name,'^yPositionOut','once')
						me.lastYPosition = value;
					elseif regexpi(name,'^sizeOut','once')
						me.lastSize = value;
					end
					
					offsetix = me.task.nVar(i).offsetstimulus;
					offsetvalue = me.task.nVar(i).offsetvalue;
					if ~isempty(offsetix)
						if ischar(offsetvalue)
							mtch = regexpi(offsetvalue,'^(?<name>[^\(\s\d]*)(\(?)(?<num>\d*)(\)?)','names');
							nme = mtch.name;
							num = str2double(mtch.num);
							if ~isempty(nme)
								switch (lower(nme))
									case {'invert'}
										if isnan(num) || isempty(num)
											val = -value;
										else
											val(num) = -value(num);
										end
									case {'yvar'}
										if doXY && ~isnan(num) && ~isempty(num) && length(value)==2
											if rand < 0.5
												val = [value(1) value(2)-num];
											else
												val = [value(1) value(2)+num];
											end
										end
									case {'xvar'}
										if doXY && ~isnan(num) && ~isempty(num) && length(value)==2
											if rand< 0.5
												val = [value(1)-num value(2)];
											else
												val = [value(1)+num value(2)];
											end
										end
									case {'yoffset'}
										if doXY && ~isnan(num) && ~isempty(num) && length(value)==2
											val = [value(1) value(2)+num];
										end
									case {'xoffset'}
										if doXY && ~isnan(num) && ~isempty(num) && length(value)==2
											val = [value(1)+num value(2)];
										end
									otherwise
										val = -value;
								end
							else
								val = value;
							end
						else
							val = value+offsetvalue;
						end
						stimIdx = [stimIdx offsetix];
						[ovalueList{1,1:size(offsetix,2)}] = deal(val);
						valueList = [valueList{:} ovalueList];
					end
					a = 1;
					for j = stimIdx %loop through our stimuli references for this variable
						t = [t sprintf('S%i:%s=%s ',j,name,num2str(valueList{a}, '%g '))];
						if ~doXY
							me.stimuli{j}.(name)=valueList{a};
						else
							me.stimuli{j}.xPositionOut=valueList{a}(1);
							me.stimuli{j}.yPositionOut=valueList{a}(2);
						end
						a = a + 1;
					end
				end
				me.variableInfo = t;
				me.behaviouralRecord.info = [me.behaviouralRecord.info t];
				me.lastIndex = index;
			end
		end
		
		% ===================================================================
		function deleteRunLog(me)
		%> @fn deleteRunLog
		%> @brief deletes the run logs
		%>
		%> @param
		% ===================================================================
			me.runLog = [];
			me.taskLog = [];
		end
		
		% ===================================================================
		function refreshScreen(me)
		%> @fn refreshScreen
		%> @brief refresh the screen values stored in the object
		%>
		%> @param
		% ===================================================================
			me.screenVals = me.screen.prepareScreen();
			me.fInc = round(0.3 / (1 / me.screenVals.ifi)); %roughly <0.3s key press
		end

		% ===================================================================
		function noop(me) %#ok<MANU> 
		%> @fn noop
		%> no operation, tests method call overhead
		%>
		% ===================================================================
			
		end

	end%-------------------------END PUBLIC METHODS--------------------------------%

	%=======================================================================
	methods (Hidden = true) %------------------HIDDEN METHODS
	%=======================================================================

		% ===================================================================
		function enableFlip(me)
		%> @fn enableFlip, deprecated for needFlip(true/false)
		%>
		%> Enable screen flip
		%> 
		% ===================================================================
			me.doFlip = true;
		end
		
		% ===================================================================
		function disableFlip(me)
		%> @fn disableFlip, deprecated for needFlip(true/false)
		%>
		%> Disable screen flip
		%>
		% ===================================================================
			me.doFlip = false;
		end

				
% 		% ===================================================================
% 		function out = saveobj(me)
% 		%> @brief called on save, removes opticka handle
% 		%>
% 		%> @param
% 		% ===================================================================
%  			me.screenSettings.optickahandle = [];
%  			fprintf('===> Saving runExperiment object...\n')
%  			out = me;
%  		end
	end
	
	%=======================================================================
	methods (Access = private) %------------------PRIVATE METHODS
	%=======================================================================
		
		% ===================================================================
		function configureEyetracker(me, eT, s)
		%> @fn configureEyetracker
		%> Configures (calibration etc.) the eyetracker.
		%> @param eT eyetracker object
		%> @param s screen object
		% ===================================================================
			if ~exist('eT','var');error('You need to pass the eyetracker manager object!');end
			if ~exist('s','var');error('You need to pass the screen manager object!');end
			if strcmp(me.eyetracker.device, 'tobii')
				if eT.useOperatorScreen && length(Screen('Screens')) > 1 && s.screen - 1 >= 0
					ss					= screenManager;
					ss.screen			= 0;
					ss.windowed			= [0 0 800 650];
					ss.specialFlags		= kPsychGUIWindow;
					ss.backgroundColour	= s.backgroundColour;
					ss.bitDepth			= '8bit';
					ss.blend			= true;
					ss.pixelsPerCm		= 30;
					initialise(eT,s,ss);
				else
					initialise(eT,s);
				end
				trackerSetup(eT); 
				ShowCursor();
				if ~eT.isConnected && ~eT.isDummy
					warning('Eyetracker is not connected and not in dummy mode, potential connection issue...')
				end
			elseif strcmp(me.eyetracker.device, 'eyelink') || me.eyetracker.dummy
				if me.eyetracker.dummy == true
					fprintf('\n===>>> Dummy eyelink being initialised...\n')
				else
					fprintf('\n===>>> Handing over to Eyelink for calibration & validation...\n')
				end
				initialise(eT, s);
				trackerSetup(eT);
			end
		end
		% ===================================================================
		function io = configureIO(me)
		%> @fn configureIO
		%> Configures the IO devices.
		%> @param
		% ===================================================================
			global rM
			%-------Set up Digital I/O (dPixx and labjack) for this task run...
			if strcmp(me.strobe.device,'display++')
				if ~isa(me.dPP,'plusplusManager')
					me.dPP = plusplusManager('verbose',me.verbose);
				end
				io = me.dPP;  %#ok<*PROP>
				io.sM = me.screen;
				io.strobeMode = me.dPPMode;
				io.name = me.name;
				io.verbose = me.verbose;
				io.name = 'runinstance';
				open(io);
				fprintf('===> Using Display++ for strobed I/O...\n')
			elseif strcmp(me.strobe.device,'datapixx')
				if ~isa(me.dPixx,'dPixxManager')
					me.dPixx = dPixxManager('verbose',me.verbose);
				end
				io = me.dPixx; io.name = me.name;
				io.silentMode = false;
				io.verbose = me.verbose;
				io.name = 'runinstance';
				open(io);
				fprintf('===> Using dataPixx for strobed I/O...\n')
			elseif strcmp(me.strobe.device,'labjackt')
				if ~isa(me.lJack,'labjackT')
					me.lJack = labJackT('openNow',false,'device',1);
				end
				io = me.lJack; io.name = me.name;
				io.silentMode = false;
				io.verbose = me.verbose;
				io.name = 'runinstance';
				open(io);
				if io.isOpen
					fprintf('===> Using labjackT for strobed I/O...\n')
				else
					warning('===> !!! labJackT could not properly open !!!');
				end
			elseif strcmp(me.strobe.device,'labjack')
				if ~isa(me.lJack,'labjack')
					me.lJack = labJack('openNow',false);
				end
				io = me.lJack; io.name = me.name;
				io.silentMode = false;
				io.verbose = me.verbose;
				io.name = 'runinstance';
				open(io);
				if io.isOpen
					fprintf('===> Using labjack for strobed I/O...\n')
				else
					warning('===> !!! labJackT could not properly open !!!');
				end
			else
				io = ioManager();
				io.silentMode = true;
				io.verbose = false;
				io.name = 'silentruninstance';
				me.strobe.device = '';
				fprintf('\n===>>> No strobe output I/O...\n')
			end

			%--------------------------------------reward
			if matches(me.reward.device,'arduino')
				if ~isa(rM,'arduinoManager')
                    rM = arduinoManager();
				end
				if ~rM.isOpen || rM.silentMode
					rM.reset();
					rM.silentMode = false;
					if ~isempty(me.arduinoPort); rM.port = me.arduinoPort; end
					rM.open();
				end
				me.arduino = rM;
				if rM.isOpen; fprintf('===> Using Arduino for reward TTLs...\n'); end
			else
				if isa(rM,'arduinoManager')
					rM.close();
					rM.silentMode = true;
				else
					rM = ioManager();
				end
				fprintf('===> No reward TTLs will be sent...\n');
			end

			%--------------------------------------control
			if isempty(me.dC)
				me.dC = dataConnection();
			end
			close(me.dC);
			if matches(me.control.device,'intan')
				if ~isempty(me.control.port)
					v = strsplit(me.control.port,':');
				else
					v{1} = '127.0.0.1';
					v{2} = '5000';
				end
				if length(v) == 2
					me.dC.rAddress = v{1};
					me.dC.rPort = v{2};
				end
				try 
					open(me.dC); 
				catch
					warning('Cannot open Intan connection!');
				end
			else
				me.dC = dataConnection();
			end
			
		end
		
		
		% ===================================================================
		function updateMOCVars(me,thisBlock,thisRun)
		%> @fn updateMOCVars
		%> @brief update variables for MOC task
		%> Updates the stimulus objects with the current variable set
		%> @param thisBlock is the current trial
		%> @param thisRun is the current run
		% ===================================================================	
			if thisBlock > me.task.nBlocks
				return %we've reached the end of the experiment, no need to update anything!
			end
			
			%start looping through out variables
			for i=1:me.task.nVars
				ix = []; valueList = []; oValueList = []; %#ok<NASGU>
				ix = me.task.nVar(i).stimulus; %which stimuli
				value=me.task.outVars{thisBlock,i}(thisRun);
				if iscell(value); value = value{1}; end
				valueList = repmat({value},length(ix),1);
				name=[me.task.nVar(i).name 'Out']; %which parameter
				
				offsetix = me.task.nVar(i).offsetstimulus;
				offsetvalue = me.task.nVar(i).offsetvalue;
				if ~isempty(offsetix)
					ix = [ix offsetix];
					offsetvalue = value + offsetvalue;
					valueList = [valueList; repmat({offsetvalue},length(offsetix),1)];
				end
				
				if me.task.blankTick > 2 && me.task.blankTick <= me.stimuli.n + 2
					%me.stimuli{j}.(name)=value;
				else
					a = 1;
					for j = ix %loop through our stimuli references for this variable
						if me.verbose==true;tic;end
						me.stimuli{j}.(name)=valueList{a};
						if thisBlock == 1 && thisRun == 1 %make sure we update if this is the first run, otherwise the variables may not update properly
							update(me.stimuli, j);
						end
						if me.verbose==true
							fprintf('=-> updateMOCVars() block/trial %i/%i: Variable:%i %s = %s | Stimulus %g -> %g ms\n',thisBlock,thisRun,i,name,num2str(valueList{a}),j,toc*1000);
						end
						a = a + 1;
					end
				end
			end
		end
		
		% ===================================================================
		function updateMOCTask(me)
		%> @fn updateMOCTask
		%> @brief updateMOCTask
		%> Updates the stimulus run state; update the stimulus values for the
		%> current trial and increments the switchTime and switchTick timer
		% ===================================================================
			me.task.timeNow = GetSecs;
			me.sendStrobe = false;
			
			%--------------first run-----------------
			if me.task.tick == 1 
				fprintf('START @%s\n\n',infoText(me));
				me.stimShown = false;
				me.task.isBlank = true;
				me.task.startTime = me.task.timeNow;
				me.task.switchTime = me.task.isTime; %first ever time is for the first trial
				me.task.switchTick = ceil(me.task.isTime*me.screenVals.fps);
				setStrobeValue(me,me.task.outIndex(me.task.totalRuns));
			end
			
			%-------------------------------------------------------------------
			if me.task.realTime %we measure real time
				maintain = me.task.timeNow <= (me.task.startTime+me.task.switchTime);
			else %we measure frames, prone to error build-up
				maintain = me.task.tick < me.task.switchTick;
			end
			
			if maintain %no need to switch state
				
				if ~me.task.isBlank %showing stimulus, need to call animate for each stimulus
					
					% because the update happens before the flip, but the drawing of the update happens
					% only in the next loop, we have to send the strobe one loop after we set switched
					% to true
					if me.task.switched == true
						me.sendStrobe = true;
						me.stimShown = true;
					end
					%if me.verbose==true;tt=tic;end
					%stims = me.stimuli;
 					%parfor i = 1:me.stimuli.n %parfor appears faster here for 6 stimuli at least
 					%	stims{i}.animate;
 					%end
					me.stimuli.animate;
					%if me.verbose==true;fprintf('=-> updateMOCTask() Stimuli animation: %g ms\n',toc(tt)*1e3);end
				else %this is a blank stimulus
					me.task.blankTick = me.task.blankTick + 1;
					%this causes the update of the stimuli, which may take more than one refresh, to
					%occur during the second blank flip, thus we don't lose any timing.
					if me.task.blankTick == 2 && me.task.tick > 1
						logRun(me,'IN BLANK');
						me.task.doUpdate = true;
					end
					% because the update happens before the flip, but the drawing of the update happens
					% only in the next loop, we have to send the strobe one loop after we set switched
					% to true
					if me.task.switched == true
						me.sendStrobe = true;
					end
					% now update our stimuli, we do it after the first blank as less
					% critical timingwise
					if me.task.doUpdate && me.stimShown
						if ~mod(me.task.thisRun,me.task.minTrials) %are we rolling over into a new trial?
							mT=me.task.thisBlock+1;
							mR = 1;
						else
							mT=me.task.thisBlock;
							mR = me.task.thisRun + 1;
						end
						me.updateMOCVars(mT,mR);
						me.task.doUpdate = false;
					end
					%this dispatches each stimulus update on a new blank frame to
					%reduce overhead.
					if me.task.blankTick > 2 && me.task.blankTick <= me.stimuli.n + 2
						%if me.verbose==true;tic;end
						update(me.stimuli, me.task.blankTick-2);
						%if me.verbose==true;fprintf('=-> updateMOCTask() Blank-frame %i: stimulus %i update = %g ms\n',me.task.blankTick,me.task.blankTick-2,toc*1000);end
					end
					
				end
				me.task.switched = false;
				
				%-------------------------------------------------------------------
			else %need to switch to next trial or blank
				me.task.switched = true;
				if me.task.isBlank == false %we come from showing a stimulus
					me.task.isBlank = true;
					me.task.blankTick = 0;
					if me.task.thisRun == me.task.minTrials %are we within a trial block or not? we add the required time to our switch timer
						me.task.switchTime=me.task.switchTime+me.task.ibTimeNow;
						me.task.switchTick=me.task.switchTick+(ceil(me.task.ibTimeNow*me.screenVals.fps));
					else
						me.task.switchTime=me.task.switchTime+me.task.isTimeNow;
						me.task.switchTick=me.task.switchTick+(ceil(me.task.isTimeNow*me.screenVals.fps));
					end
					setStrobeValue(me,me.strobe.stimOFFValue);%get the strobe word to signify stimulus OFF ready
				else %we have to show the new run on the next flip
					me.task.switchTime=me.task.switchTime+me.task.trialTime; %update our timer
					me.task.switchTick=me.task.switchTick+(ceil(me.task.trialTime*me.screenVals.fps)); %update our timer
					me.task.isBlank = false;
					updateTask(me.task);
					if me.task.totalRuns <= me.task.nRuns
						setStrobeValue(me,me.task.outIndex(me.task.totalRuns)); %get the strobe word ready
					end
				end
			end
		end
		
		% ===================================================================
		function infoTextScreen(me)
		%> @fn infoTextScreen
		%> @brief infoTextScreen - draws text about frame to screen
		%>
		%> @param
		%> @return
		% ===================================================================
			me.screen.drawTextWrapped(infoText(me));
		end
		
		% ===================================================================
		function t = infoText(me)
		%> @fn infoText
		%> @brief infoText - task information as a string
		%>
		%> @return t info string
		% ===================================================================
			etinfo = ''; name = '';
			if me.isRunTask
				log = me.taskLog;
				name = [me.stateMachine.currentName ':' me.stateMachine.currentUUID];
				if ~isempty(me.eyetracker.device)
					etinfo = sprintf('isFix:%i isExcl:%i isFixInit:%i fixLength: %.2f',...
						me.eyeTracker.isFix,me.eyeTracker.isExclusion,me.eyeTracker.isInitFail,me.eyeTracker.fixLength);
				end
			else
				log = me.runLog;
				name = sprintf('%s Blank:%i',name,me.task.isBlank);
			end
			if isempty(me.task.outValues)
				t = sprintf('%s | Time: %3.3f (%i) | isFix: %i | isExclusion: %i | isFixInit: %i',...
					name,(log.lastvbl-log.startTime), log.tick-1,...
					me.eyeTracker.isFix,me.eyeTracker.isExclusion,me.eyeTracker.isInitFail);
				return
			else
				var = me.task.outIndex(me.task.totalRuns);
			end
			if me.logFrames == true && log.tick > 1
				t=sprintf('%s | B:%i R:%i [%i/%i] | V: %i | Time: %3.3f (%i) %s',...
					name,me.task.thisBlock, me.task.thisRun, me.task.totalRuns,...
					me.task.nRuns, var, ...
					(log.lastvbl-log.startTime), log.tick-1,...
					etinfo);
			else
				t=sprintf('%s | B:%i R:%i [%i/%i] | V: %i | Time: %3.3f (%i) %s',...
					name,me.task.thisBlock,me.task.thisRun,me.task.totalRuns,...
					me.task.nRuns, var, ...
					(log.lastvbl-log.startTime), log.tick,...
					etinfo);
			end
			for i=1:me.task.nVars
				if iscell(me.task.outVars{me.task.thisBlock,i}(me.task.thisRun))
					t=[t sprintf(' > %s: %s',me.task.nVar(i).name,...
						num2str(me.task.outVars{me.task.thisBlock,i}{me.task.thisRun},'%.2f '))];
				else
					t=[t sprintf(' > %s: %3.3f',me.task.nVar(i).name,...
						me.task.outVars{me.task.thisBlock,i}(me.task.thisRun))];
				end
			end
			if ~isempty(me.variableInfo)
				t = [t ' | ' me.variableInfo];
			end
			t = WrapString(t, 100);
		end
		
		% ===================================================================
		function tS = saveEyeInfo(me,sM,eT,tS)
		%> @fn saveEyeInfo
		%> @brief save this trial eye info
		%>
		%> @param
		% ===================================================================
			switch sM.currentName
				case 'fixate'
					prefix = 'F';
				case 'stimulus'
					prefix = 'E';
				case 'correct'
					prefix = 'CC';
				case 'breakfix'
					prefix = 'BF';
				otherwise
					prefix = 'U';
			end
			if ~strcmpi(prefix,'U')
				uuid = [prefix sM.currentUUID];
				if isfield(tS.eyePos, uuid)
					tS.eyePos.(uuid).x(end+1) = eT.x;
					tS.eyePos.(uuid).y(end+1) = eT.y;
				else
					tS.eyePos.(uuid).x = eT.x;
					tS.eyePos.(uuid).y = eT.y;
				end
			end
		end
		
		% ===================================================================
		function tS = checkKeys(me,tS)
		%> @brief manage key commands during task loop
		%>
		%> @param args input structure
		% ===================================================================
			tS.keyTicks = tS.keyTicks + 1;
			%now lets check whether any keyboard commands are pressed...
			[keyIsDown, ~, keyCode] = KbCheck(-1);
			if keyIsDown
				rchar = KbName(keyCode);
				if iscell(rchar);rchar=rchar{1};end
				switch rchar
					case 'q' %quit
						me.stopTask = true;
					case 'p' %pause the display
						if tS.keyTicks > tS.keyHold
							if strcmpi(me.stateMachine.currentState.name, 'pause')
								forceTransition(me.stateMachine, me.stateMachine.currentState.next);
							else
								flip(me.screen,[],[],2);flip(me.screen,[],[],2)
								forceTransition(me.stateMachine, 'pause');
								tS.pauseToggle = tS.pauseToggle + 1;
							end
							FlushEvents();
							tS.keyHold = tS.keyTicks + me.fInc;
						end
					case {'UpArrow','up'}
						if tS.keyTicks > tS.keyHold
							if ~isempty(me.stimuli.controlTable)
								maxl = length(me.stimuli.controlTable);
								if isempty(me.stimuli.tableChoice) && maxl > 0
									me.stimuli.tableChoice = 1;
								end
								if (me.stimuli.tableChoice > 0) && (me.stimuli.tableChoice < maxl)
									me.stimuli.tableChoice = me.stimuli.tableChoice + 1;
								end
								var=me.stimuli.controlTable(me.stimuli.tableChoice).variable;
								delta=me.stimuli.controlTable(me.stimuli.tableChoice).delta;
								fprintf('======>>> Set Control table %g - %s : %g\n',me.stimuli.tableChoice,var,delta)
							end
							tS.keyHold = tS.keyTicks + me.fInc;
						end
					case {'DownArrow','down'}
						if tS.keyTicks > tS.keyHold
							if ~isempty(me.stimuli.controlTable)
								maxl = length(me.stimuli.controlTable);
								if isempty(me.stimuli.tableChoice) && maxl > 0
									me.stimuli.tableChoice = 1;
								end
								if (me.stimuli.tableChoice > 1) && (me.stimuli.tableChoice <= maxl)
									me.stimuli.tableChoice = me.stimuli.tableChoice - 1;
								end
								var=me.stimuli.controlTable(me.stimuli.tableChoice).variable;
								delta=me.stimuli.controlTable(me.stimuli.tableChoice).delta;
								fprintf('======>>> Set Control table %g - %s : %g\n',me.stimuli.tableChoice,var,delta)
							end
							tS.keyHold = tS.keyTicks + me.fInc;
						end
						
					case {'LeftArrow','left'} %previous variable 1 value
						if tS.keyTicks > tS.keyHold
							if ~isempty(me.stimuli.controlTable) && ~isempty(me.stimuli.controlTable.variable)
								choice = me.stimuli.tableChoice;
								if isempty(choice)
									choice = 1;
								end
								var = me.stimuli.controlTable(choice).variable;
								delta = me.stimuli.controlTable(choice).delta;
								stims = me.stimuli.controlTable(choice).stimuli;
								thisstim = me.stimuli.stimulusSets{me.stimuli.setChoice}; %what stimulus is visible?
								stims = intersect(stims,thisstim); %only change the visible stimulus
								limits = me.stimuli.controlTable(choice).limits;
								correctPPD = 'size|dotSize|xPosition|yPosition';
								for i = 1:length(stims)
									if ~isempty(regexpi(var, correctPPD, 'once'))
										oval = me.stimuli{stims(i)}.([var 'Out']) / me.stimuli{stims(i)}.ppd;
									elseif strcmpi(var,'sf')
										oval = me.stimuli{stims(i)}.getsfOut;
									else
										oval = me.stimuli{stims(i)}.([var 'Out']);
									end
									val = oval - delta;
									if min(val) < limits(1)
										val(val < limits(1)) = limits(2);
									elseif max(val) > limits(2)
										val(val > limits(2)) = limits(1);
									end
									if length(val) > length(oval)
										val = val(1:length(oval));
									end
									me.stimuli{stims(i)}.([var 'Out']) = val;
									me.stimuli{stims(i)}.update();
									fprintf('======>>> Stimulus #%i -- %s: %.3f (was %.3f)\n',stims(i),var,val,oval)
								end
							end
							tS.keyHold = tS.keyTicks + me.fInc;
						end
					case {'RightArrow','right'} %next variable 1 value
						if tS.keyTicks > tS.keyHold
							if ~isempty(me.stimuli.controlTable) && ~isempty(me.stimuli.controlTable.variable)
								choice = me.stimuli.tableChoice;
								if isempty(choice)
									choice = 1;
								end
								var = me.stimuli.controlTable(choice).variable;
								delta = me.stimuli.controlTable(choice).delta;
								stims = me.stimuli.controlTable(choice).stimuli;
								thisstim = me.stimuli.stimulusSets{me.stimuli.setChoice}; %what stimulus is visible?
								stims = intersect(stims,thisstim); %only change the visible stimulus
								limits = me.stimuli.controlTable(choice).limits;
								correctPPD = 'size|dotSize|xPosition|yPosition';
								for i = 1:length(stims)
									if ~isempty(regexpi(var, correctPPD, 'once'))
										oval = me.stimuli{stims(i)}.([var 'Out']) / me.stimuli{stims(i)}.ppd;
									elseif strcmpi(var,'sf')
										oval = me.stimuli{stims(i)}.getsfOut;
									else
										oval = me.stimuli{stims(i)}.([var 'Out']);
									end
									val = oval + delta;
									if min(val) < limits(1)
										val(val < limits(1)) = limits(2);
									elseif max(val) > limits(2)
										val(val > limits(2)) = limits(1);
									end
									if length(val) > length(oval)
										val = val(1:length(oval));
									end
									me.stimuli{stims(i)}.([var 'Out']) = val;
									me.stimuli{stims(i)}.update();
									fprintf('======>>> Stimulus #%i -- %s: %.3f (%.3f)\n',stims(i),var,val,oval)
								end
							end
							tS.keyHold = tS.keyTicks + me.fInc;
						end
					case ',<'
						if tS.keyTicks > tS.keyHold
							if me.stimuli.setChoice > 1
								me.stimuli.setChoice = round(me.stimuli.setChoice - 1);
								me.stimuli.showSet();
							end
							fprintf('======>>> Stimulus Set: #%g | Stimuli: %s\n',me.stimuli.setChoice, num2str(me.stimuli.stimulusSets{me.stimuli.setChoice}))
							tS.keyHold = tS.keyTicks + me.fInc;
						end
					case '.>'
						if tS.keyTicks > tS.keyHold
							if me.stimuli.setChoice < length(me.stimuli.stimulusSets)
								me.stimuli.setChoice = me.stimuli.setChoice + 1;
								me.stimuli.showSet();
							end
							fprintf('======>>> Stimulus Set: #%g | Stimuli: %s\n',me.stimuli.setChoice, num2str(me.stimuli.stimulusSets{me.stimuli.setChoice}))
							tS.keyHold = tS.keyTicks + me.fInc;
						end
					case 'r'
						timedTTL(me.arduino);
					case '=+'
						if tS.keyTicks > tS.keyHold
							me.screen.screenXOffset = me.screen.screenXOffset + 1;
							fprintf('======>>> Screen X Center: %g deg / %g pixels\n',me.screen.screenXOffset,me.screen.xCenter);
							tS.keyHold = tS.keyTicks + me.fInc;
						end
					case '-_'
						if tS.keyTicks > tS.keyHold
							me.screen.screenXOffset = me.screen.screenXOffset - 1;
							fprintf('======>>> Screen X Center: %g deg / %g pixels\n',me.screen.screenXOffset,me.screen.xCenter);
							tS.keyHold = tS.keyTicks + me.fInc;
						end
					case '[{'
						if tS.keyTicks > tS.keyHold
							me.screen.screenYOffset = me.screen.screenYOffset - 1;
							fprintf('======>>> Screen Y Center: %g deg / %g pixels\n',me.screen.screenYOffset,me.screen.yCenter);
							tS.keyHold = tS.keyTicks + me.fInc;
						end
					case ']}'
						if tS.keyTicks > tS.keyHold
							me.screen.screenYOffset = me.screen.screenYOffset + 1;
							fpridriftntf('======>>> Screen Y Center: %g deg / %g pixels\n',me.screen.screenYOffset,me.screen.yCenter);
							tS.keyHold = tS.keyTicks + me.fInc;
						end
					case 'k'
						if tS.keyTicks > tS.keyHold
							stateName = 'blank';
							[isState, index] = isStateName(me.stateMachine,stateName);
							if isState
								t = me.stateMachine.getState(stateName);
								if isfield(t,'time')
									tout = t.time - 0.25;
									if min(tout) >= 0.1
										me.stateMachine.editStateByName(stateName,'time',tout);
										fprintf('======>>> Decrease %s time: %g:%g\n',t.name, min(tout),max(tout));
									end
								end
							end
							tS.keyHold = tS.keyTicks + me.fInc;
						end
					case 'l'
						if tS.keyTicks > tS.keyHold
							stateName = 'blank';
							[isState, index] = isStateName(me.stateMachine,stateName);
							if isState
								t = me.stateMachine.getState(stateName);
								if isfield(t,'time')
									tout = t.time + 0.25;
									me.stateMachine.editStateByName(stateName,'time',tout);
									fprintf('======>>> Increase %s time: %g:%g\n',t.name, min(tout),max(tout));
								end
								
							end
							tS.keyHold = tS.keyTicks + me.fInc;
						end
					case 'y'
						if tS.keyTicks > tS.keyHold
							fprintf('======>>> Calibrate ENGAGED!\n');
							tS.pauseToggle = tS.pauseToggle + 1; %we go to pause after this so toggle this
							tS.keyHold = tS.keyTicks + me.fInc;
							forceTransition(me.stateMachine, 'calibrate');
							return
						end
					case 'u'
						if tS.keyTicks > tS.keyHold
							fprintf('======>>> Drift OFFSET ENGAGED!\n');
							tS.pauseToggle = tS.pauseToggle + 1; %we go to pause after this so toggle this
							tS.keyHold = tS.keyTicks + me.fInc;
							forceTransition(me.stateMachine, 'offset');
							return
						end
					case 'i'
						if tS.keyTicks > tS.keyHold
							fprintf('======>>> Drift CORRECT ENGAGED!\n');
							tS.pauseToggle = tS.pauseToggle + 1; %we go to pause after this so toggle this
							tS.keyHold = tS.keyTicks + me.fInc;
							forceTransition(me.stateMachine, 'drift');
							return
						end
					case 'f'
						if tS.keyTicks > tS.keyHold
							fprintf('======>>> Flash ENGAGED!\n');
							tS.pauseToggle = tS.pauseToggle + 1; %we go to pause after this so toggle this
							tS.keyHold = tS.keyTicks + me.fInc;
							forceTransition(me.stateMachine, 'flash');
							return
						end
					case 't'
						if tS.keyTicks > tS.keyHold
							fprintf('======>>> MagStim ENGAGED!\n');
							tS.pauseToggle = tS.pauseToggle + 1; %we go to pause after this so toggle this
							tS.keyHold = tS.keyTicks + me.fInc;
							forceTransition(me.stateMachine, 'magstim');
							return
						end
					case ';:'
						if tS.keyTicks > tS.keyHold
							if me.debug && ~isdeployed
								fprintf('======>>> Override ENGAGED! This is a special DEBUG mode\n');
								tS.pauseToggle = tS.pauseToggle + 1; %we go to pause after this so toggle this
								tS.keyHold = tS.keyTicks + me.fInc;
								forceTransition(me.stateMachine, 'override');
							end
							return
						end
					case 'g'
						if tS.keyTicks > tS.keyHold
							fprintf('======>>> grid ENGAGED!\n');
							tS.pauseToggle = tS.pauseToggle + 1; %we go to pause after this so toggle this
							tS.keyHold = tS.keyTicks + me.fInc;
							forceTransition(me.stateMachine, 'showgrid');
							return
						end
					case 'z'
						if tS.keyTicks > tS.keyHold
							me.eyeTracker.fixation.initTime = me.eyeTracker.fixation.initTime - 0.1;
							if me.eyeTracker.fixation.initTime < 0.01
								me.eyeTracker.fixation.initTime = 0.01;
							end
							tS.firstFixInit = me.eyeTracker.fixation.initTime;
							fprintf('======>>> FIXATION INIT TIME: %g\n',me.eyeTracker.fixation.initTime)
							tS.keyHold = tS.keyTicks + me.fInc;
						end
					case 'x'
						if tS.keyTicks > tS.keyHold
							me.eyeTracker.fixation.initTime = me.eyeTracker.fixation.initTime + 0.1;
							tS.firstFixInit = me.eyeTracker.fixation.initTime;
							fprintf('======>>> FIXATION INIT TIME: %g\n',me.eyeTracker.fixation.initTime)
							tS.keyHold = tS.keyTicks + me.fInc;
						end
					case 'c'
						if tS.keyTicks > tS.keyHold
							me.eyeTracker.fixation.time = me.eyeTracker.fixation.time - 0.1;
							if me.eyeTracker.fixation.time < 0.01
								me.eyeTracker.fixation.time = 0.01;
							end
							tS.firstFixTime = me.eyeTracker.fixation.time;
							fprintf('======>>> FIXATION TIME: %g\n',me.eyeTracker.fixation.time)
							tS.keyHold = tS.keyTicks + me.fInc;
						end
					case 'v'
						if tS.keyTicks > tS.keyHold
							me.eyeTracker.fixation.time = me.eyeTracker.fixation.time + 0.1;
							tS.firstFixTime = me.eyeTracker.fixation.time;
							fprintf('======>>> FIXATION TIME: %g\n',me.eyeTracker.fixation.time)
							tS.keyHold = tS.keyTicks + me.fInc;
						end
					case 'b'
						if tS.keyTicks > tS.keyHold
							me.eyeTracker.fixation.radius = me.eyeTracker.fixation.radius - 0.1;
							if me.eyeTracker.fixation.radius < 0.1
								me.eyeTracker.fixation.radius = 0.1;
							end
							tS.firstFixRadius = me.eyeTracker.fixation.radius;
							fprintf('======>>> FIXATION RADIUS: %g\n',me.eyeTracker.fixation.radius)
							tS.keyHold = tS.keyTicks + me.fInc;
						end
					case 'n'
						if tS.keyTicks > tS.keyHold
							me.eyeTracker.fixation.radius = me.eyeTracker.fixation.radius + 0.1;
							tS.firstFixRadius = me.eyeTracker.fixation.radius;
							fprintf('======>>> FIXATION RADIUS: %g\n',me.eyeTracker.fixation.radius)
							tS.keyHold = tS.keyTicks + me.fInc;
						end
					case 's'
						if tS.keyTicks > tS.keyHold
							fprintf('======>>> Show Cursor!\n');
							ShowCursor('CrossHair',me.screen.win);
							tS.keyHold = tS.keyTicks + me.fInc;
						end
					case 'd'
						if tS.keyTicks > tS.keyHold
							fprintf('======>>> Hide Cursor!\n');
							HideCursor(me.screen.win);
							tS.keyHold = tS.keyTicks + me.fInc;
						end
					case '1!'
						if tS.keyTicks > tS.keyHold
							if isfield(tS,'eO') && tS.eO.isOpen == true
								bothEyesOpen(tS.eO)
								Eyelink('Command','binocular_enabled = NO')
								Eyelink('Command','active_eye = LEFT')
							end
							tS.keyHold = tS.keyTicks + me.fInc;
						end
					case '2@'
						if tS.keyTicks > tS.keyHold
							if isfield(tS,'eO') && tS.eO.isOpen == true
								bothEyesClosed(tS.eO)
								Eyelink('Command','binocular_enabled = NO');
								Eyelink('Command','active_eye = LEFT');
							end
							tS.keyHold = tS.keyTicks + me.fInc;
						end
					case '3#'
						if tS.keyTicks > tS.keyHold
							if isfield(tS,'eO') && tS.eO.isOpen == true
								leftEyeClosed(tS.eO)
								Eyelink('Command','binocular_enabled = NO');
								Eyelink('Command','active_eye = RIGHT');
							end
							tS.keyHold = tS.keyTicks + me.fInc;
						end
					case '4$'
						if tS.keyTicks > tS.keyHold
							if isfield(tS,'eO') && tS.eO.isOpen == true
								rightEyeClosed(tS.eO)
								Eyelink('Command','binocular_enabled = NO');
								Eyelink('Command','active_eye = LEFT');
							end
							tS.keyHold = tS.keyTicks + me.fInc;
						end
					case '0)'
						if tS.keyTicks > tS.keyHold
							if me.debug; me.screen.captureScreen(); end
							tS.keyHold = tS.keyTicks + me.fInc;
						end
				end
			end
		end
		
	end %-------END PRIVATE METHODS
	
	%=======================================================================
	methods (Static = true) %------------------STATIC METHODS
	%=======================================================================
	
		function plotEyeLogs(tS)
			ifi = 0.013;
			tS = tS.eyePos;
			fn = fieldnames(tS);
			h=figure;
			set(gcf,'Color',[1 1 1]);
			figpos(1,[1200 1200]);
			p = panel(h);
			p.pack(2,2);
			a = 1;
			stdex = [];
			stdey = [];
			early = [];
			for i = 1:length(fn)-1
				if ~isempty(regexpi(fn{i},'^E')) && ~isempty(regexpi(fn{i+1},'^CC'))
					x = tS.(fn{i}).x;
					y = tS.(fn{i}).y;
					%if a < Inf%(max(x) < 16 && min(x) > -16) && (max(y) < 16 && min(y) > -16) && mean(abs(x(1:10))) < 1 && mean(abs(y(1:10))) < 1
						c = rand(1,3);
						p(1,1).select();
						p(1,1).hold('on')
						plot(x, y,'k-o','Color',c,'MarkerSize',5,'MarkerEdgeColor',[0 0 0], 'MarkerFaceColor',c);

						p(1,2).select();
						p(1,2).hold('on');
						t = 0:ifi:(ifi*length(x));
						t = t(1:length(x));
						plot(t,abs(x),'k-o','Color',c,'MarkerSize',5,'MarkerEdgeColor',[0 0 0], 'MarkerFaceColor',c);
						plot(t,abs(y),'k-o','Color',c,'MarkerSize',5,'MarkerEdgeColor',[0 0 0], 'MarkerFaceColor',c);
						
						p(2,1).select();
						p(2,1).hold('on');
						plot(mean(x(1:10)), mean(y(1:10)),'ko','Color',c,'MarkerSize',5,'MarkerEdgeColor',[0 0 0], 'MarkerFaceColor',c);
						stdex = [stdex std(x(1:10))];
						stdey = [stdey std(y(1:10))];
						
						p(2,2).select();
						p(2,2).hold('on');
						plot3(mean(x(1:10)), mean(y(1:10)),a,'ko','Color',c,'MarkerSize',5,'MarkerEdgeColor',[0 0 0], 'MarkerFaceColor',c);
						
						if mean(x(14:16)) > 5 || mean(y(14:16)) > 5
							early(a) = 1;
						else
							early(a) = 0;
						end
						
						a = a + 1;
						
					%end
				end
			end
			
			p(1,1).select();
			grid on
			box on
			axis square
			title('X vs. Y Eye Position in Degrees')
			xlabel('X Degrees')
			ylabel('Y Degrees')
			
			p(1,2).select();
			grid on
			box on
			title(sprintf('X and Y Position vs. time | Early = %g / %g', sum(early),length(early)))
			xlabel('Time (s)')
			ylabel('Degrees')
			
			p(2,1).select();
			grid on
			box on
			axis square
			title(sprintf('Average X vs. Y Position for first 150ms STDX: %g | STDY: %g',mean(stdex),mean(stdey)))
			xlabel('X Degrees')
			ylabel('Y Degrees')
			
			p(2,2).select();
			grid on
			box on
			axis square
			title('Average X vs. Y Position for first 150ms Over Time')
			xlabel('X Degrees')
			ylabel('Y Degrees')
			zlabel('Trial')
		end
		
		% ===================================================================
		%> @brief loadobj
		%> To be backwards compatible to older saved protocols, we have to parse 
		%> structures / objects specifically during object load
		%> @param in input object/structure
		% ===================================================================
		function lobj = loadobj(in)
			if isa(in,'runExperiment')
				lobj = in;
				name = '';
				if isprop(lobj,'fullName')
					name = [name 'NEW:' lobj.fullName];
				end
				fprintf('---> runExperiment loadobj: %s (UUID: %s)\n',name,lobj.uuid);
				isObjectLoaded = true;
				setPaths(lobj);
				rebuild();
				return
			else
				lobj = runExperiment;
				name = '';
				if isprop(lobj,'fullName')
					name = [name 'NEW:' lobj.fullName];
				end
				if isfield(in,'name')
					name = [name '<--OLD:' in.name];
				end
				fprintf('---> runExperiment loadobj %s: Loading legacy structure (Old UUID: %s)...\n',name,in.uuid);
				isObjectLoaded = false;
				lobj.initialise('notask noscreen nostimuli');
				rebuild();
			end
			
			% as we change runExperiment class, old files become structures and
			% we need to migrate the settings to the new locations!
			function me = rebuild()
				fprintf('   > ');
				try %#ok<*TRYNC>
					if optickaCore.hasKey(in, 'stimuli') && isa(in.stimuli,'metaStimulus')
						if ~isObjectLoaded
							lobj.stimuli = in.stimuli;
							fprintf('metaStimulus object loaded | ');
						else
							fprintf('metaStimulus object present | ');
						end
					elseif optickaCore.hasKey(in, 'stimuli')
						if iscell(in.stimulus) && isa(in.stimulus{1},'baseStimulus')
							lobj.stimuli = metaStimulus();
							lobj.stimuli.stimuli = in.stimulus;
							fprintf('Legacy Stimuli | ');
						elseif isa(in.stimulus,'metaStimulus')
							me.stimuli = in.stimulus;
							fprintf('Stimuli (old field) = metaStimulus object | ');
						else
							fprintf('NO STIMULI!!! | ');
						end
					end

					if (~isObjectLoaded && isfield(in,'stateInfoFile') && ~isempty(in.stateInfoFile)) || ...
					  (isObjectLoaded && isprop(in,'stateInfoFile') && ~isempty(in.stateInfoFile))
						fprintf(['!!!SIF: ' in.stateInfoFile ' ']);
						lobj.stateInfoFile = in.stateInfoFile;
					elseif isfield(in.paths,'stateInfoFile') && ~isempty(in.paths.stateInfoFile)
						fprintf(['!!!PATH: ' in.paths.stateInfoFile ' ']);
						lobj.stateInfoFile = in.paths.stateInfoFile;
					end
					if ~exist(lobj.stateInfoFile,'file')
						tp = lobj.stateInfoFile;
						tp = regexprep(tp,'(^/\w+/\w+)',lobj.paths.home);
						if exist(tp,'file')
							lobj.stateInfoFile = tp;
						else
							[~,f,e] = fileparts(tp);
							newfile = [pwd filesep f e];
							if exist(newfile, 'file')
								lobj.stateInfoFile = newfile;
							end
						end
					end
					lobj.paths.stateInfoFile = in.stateInfoFile;
					fprintf('stateInfoFile: %s assigned | ', lobj.stateInfoFile);

					if isa(in.task,'taskSequence') 
						lobj.task = in.task;
						fprintf(' | loaded taskSequence');
					elseif isa(in.task,'stimulusSequence') || isstruct(in.task)
						tso = fieldnames(in.task);
						ts = taskSequence();
						if matches('nVar',tso)
							ts.nVar = in.task.nVar;
						end
						if matches('nBlocks',tso)
							ts.nBlocks = in.task.nBlocks;
						end
						if matches('randomSeed',tso)
							ts.randomSeed = in.task.randomSeed;
						end
						if matches('realTime', tso)
							ts.realTime = in.task.realTime;
						end
						if matches('isTime',tso)
							ts.isTime = in.task.isTime;
						end
						if matches('ibTime',tso)
							ts.ibTime = in.task.ibTime;
						end
						if matches('trialTime',tso)
							ts.trialTime = in.task.trialTime;
						end
						if matches('randomise',tso)
							ts.randomise = in.task.randomise;
						end
						if matches('realTime',tso)
							ts.realTime = in.task.realTime;
						end
						lobj.task = ts;
						fprintf(' | reconstructed taskSequence %s from %s',ts.fullName,tso.fullName);
						clear tso ts
					elseif isa(lobj.task,'taskSequence')
						lobj.previousInfo.task = in.task;
						fprintf(' | inherited taskSequence');
					else
						lobj.task = taskSequence();
						fprintf(' | new taskSequence');
					end
					if ~isObjectLoaded && isfield(in,'verbose')
						lobj.verbose = in.verbose;
					end
					if ~isObjectLoaded && isfield(in,'debug')
						lobj.debug = in.debug;
					end
					if ~isObjectLoaded && isfield(in,'useLabJackReward') && in.useLabJackReward
						lobj.reward.device = 'labjack';
					end
					if ~isObjectLoaded && isfield(in,'useArduino') && in.useArduino
						lobj.reward.device = 'arduino';
					end
					if ~isObjectLoaded && isfield(in,'useLabJackStrobe') && in.useLabJackStrobe
						lobj.strobe.device = 'labjack';
					end
					if ~isObjectLoaded && isfield(in,'useDisplayPP') && in.useDisplayPP
						lobj.strobe.device = 'display++';
					end
					if ~isObjectLoaded && isfield(in,'useDataPixx') && in.useDataPixx
						lobj.strobe.device = 'datapixx';
					end
					if ~isObjectLoaded && isfield(in,'useLabJackTStrobe') && in.useLabJackTStrobe
						lobj.strobe.device = 'labjackt';
					end
					if ~isObjectLoaded && isfield(in,'useTobii') && in.useTobii
						lobj.eyetracker.device = 'tobii';
					end
					if ~isObjectLoaded && isfield(in,'useEyelink') && in.useEyelink
						lobj.eyetracker.device = 'eyelink';
					end
				end
				try
					if ~isa(in.screen,'screenManager') %this is an old object, pre screenManager
						lobj.screen = screenManager();
						lobj.screen.distance = in.distance;
						lobj.screen.pixelsPerCm = in.pixelsPerCm;
						lobj.screen.screenXOffset = in.screenXOffset;
						lobj.screen.screenYOffset = in.screenYOffset;
						lobj.screen.antiAlias = in.antiAlias;
						lobj.screen.srcMode = in.srcMode;
						lobj.screen.windowed = in.windowed;
						lobj.screen.dstMode = in.dstMode;
						lobj.screen.blend = in.blend;
						lobj.screen.hideFlash = in.hideFlash;
						lobj.screen.movieSettings = in.movieSettings;
						fprintf(' | regenerated screenManager');
					elseif ~strcmpi(in.screen.uuid,lobj.screen.uuid)
						lobj.screen = in.screen;
						in.screen.verbose = false; %no printout
						%in.screen = []; %force close any old screenManager instance;
						fprintf(' | inherited screenManager');
					else
						fprintf(' | loaded screenManager');
					end
				end
				try
					lobj.previousInfo.runLog = in.runLog;
					lobj.previousInfo.computer = in.computer;
					lobj.previousInfo.ptb = in.ptb;
					lobj.previousInfo.screenVals = in.screenVals;
					lobj.previousInfo.screenSettings = in.screenSettings;
					lobj.previousInfo.all = in;
				end
				try lobj.stateMachine		= in.stateMachine; end
				try lobj.eyeTracker			= in.eyeTracker; end
				try lobj.behaviouralRecord	= in.behaviouralRecord; end
				try lobj.runLog				= in.runLog; end
				try lobj.taskLog			= in.taskLog; end
				try lobj.stateInfo			= in.stateInfo; end
				try lobj.comment			= in.comment; end
				fprintf('\n');
			end
		end
		
	end
	
end

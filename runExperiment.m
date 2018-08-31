% ========================================================================
%> @brief runExperiment is the main Experiment manager; Inherits from optickaCore
%>
%>RUNEXPERIMENT The main class which accepts a task and stimulus object
%>and runs the stimuli based on the task object passed. The class
%>controls the fundamental configuration of the screen (calibration, size
%>etc. via screenManager), and manages communication to the DAQ system using TTL pulses out
%>and communication over a UDP client<->server socket (via dataConnection).
%>
%>  stimuli must be metaStimulus class managing gratingStimulus and friends,
%>  so for example:
%>
%>  gStim = gratingStimulus('mask',1,'sf',1);
%>  myStim = metaStimulus;
%>  myStim{1} = gStim;
%>  myExp = runExperiment('stimuli',myStim);
%>  run(myExp);
%>
%>	will run a minimal experiment showing a 1c/d circularly masked grating
% ========================================================================
classdef runExperiment < optickaCore
	
	properties
		%> a metaStimulus class holding our stimulus objects
		stimuli
		%> the stimulusSequence object(s) for the task
		task
		%> screen manager object
		screen
		%> use Display++ for strobed digital I/O?
		useDisplayPP logical = false
		%> use dataPixx for strobed digital I/O?
		useDataPixx logical = false
		%> use LabJack for strobed digital I/O?
		useLabJackStrobe logical = false
		%> use LabJack for reward TTL?
		useLabJackReward logical = false
		%> use Arduino for reward TTL?
		useArduino logical = false
		%> use Eyelink?
		useEyeLink logical = false
		%> use eye occluder (custom arduino device) for LGN work ?
		useEyeOccluder logical = false
		%> this lets the opticka UI leave commands to runExperiment
		uiCommand char = ''
		%> do we flip or not?
		doFlip logical = true
		%> log all frame times?
		logFrames logical = true
		%> enable debugging? (poorer temporal fidelity)
		debug logical = false
		%> shows the info text and position grid during stimulus presentation
		visualDebug logical = false
		%> draw simple fixation cross during trial?
		drawFixation logical = false
		%> flip as fast as possible?
		benchmark logical = false
		%> verbose logging to command window?
		verbose = false
		%> what value to send on stimulus OFF
		stimOFFValue double = 255
		%> subject name
		subjectName char = 'Simulcra'
		%> researcher name
		researcherName char = 'Joanna Doe'
		%> structure for screenManager on initialisation and info from opticka
		screenSettings = struct()
	end
	
	properties (Hidden = true)
		%> our old stimulus structure used to be a simple cell, now we use metaStimulus
		stimulus
		%> used to select single stimulus in training mode
		stimList = []
		%> which stimulus is selected?
		thisStim = []
		%> file to define the stateMachine state info
		stateInfoFile = ''
		%> tS is the runtime settings structure, saved here as a backup
		tS
		%> 
		lastXPosition = 0
		lastYPosition = 0
		lastSize = 1
		lastIndex = 0
		%> what mode to run the DPP in?
		dPPMode char = 'plexon'
	end
	
	properties (SetAccess = private, GetAccess = public)
		%> send strobe on next flip?
		sendStrobe logical = false
		%> need eyelink sample on next flip?
		needSample logical = false
		%> send eyelink SYNCTIME after next flip?
		sendSyncTime logical = false
		%> stateMachine
		stateMachine
		%> eyelink manager object
		eyeLink 
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
		%> state machine control cell array
		stateInfo cell = {}
		%> general computer info
		computer
		%> PTB info
		ptb
		%> gamma tables and the like from screenManager
		screenVals
		%> log times during display
		runLog
		%> task log
		taskLog
		%> training log
		trainingLog
		%> behavioural log
		behaviouralRecord
		%> info on the current run
		currentInfo
		%> previous info populated during load of a saved object
		previousInfo struct = struct()
		%> save prefix generated from clock time
		savePrefix
		%> check if runExperiment is running or not
		isRunning logical = false
	end
	
	properties (SetAccess = private, GetAccess = private)
		%> is it run (false) or runTask (true)?
		isRunTask logical = true
		%> should we stop the task?
		stopTask logical = false
		%> properties allowed to be modified during construction
		allowedProperties='stimuli|task|screen|visualDebug|useLabJack|useDataPixx|logFrames|debug|verbose|screenSettings|benchmark'
	end
	
	events
		runInfo
		abortRun
		endAllRuns
	end
	
	%=======================================================================
	methods %------------------PUBLIC METHODS
		%=======================================================================
		
		% ===================================================================
		%> @brief Class constructor
		%>
		%> More detailed description of what the constructor does.
		%>
		%> @param args are passed as a structure of properties which is
		%> parsed.
		%> @return instance of the class.
		% ===================================================================
		function obj = runExperiment(varargin)
			if nargin == 0; varargin.name = 'runExperiment'; end
			obj=obj@optickaCore(varargin); %superclass constructor
			if nargin > 0; obj.parseArgs(varargin,obj.allowedProperties); end
		end
		
		% ===================================================================
		%> @brief The main run loop
		%>
		%> run uses built-in loop for experiment control and runs a
		%> methods-of-constants experiment with the settings passed to it (stimuli,task
		%> and screen). This is different to the runTask method as it doesn't
		%> use a stateMachine for experimental logic, just a minimal
		%> trial+block loop.
		%>
		%> @param obj required class object
		% ===================================================================
		function run(obj)
			global rM %eyelink calibration needs access to labjack for reward
					
			if isempty(obj.screen) || isempty(obj.task)
				obj.initialise;
			end
			if isempty(obj.stimuli) || obj.stimuli.n < 1
				error('No stimuli present!!!')
			end
			if obj.screen.isPTB == false
				errordlg('There is no working PTB available!')
				error('There is no working PTB available!')
			end
			
			initialiseSaveFile(obj); %generate a savePrefix for this run
			obj.name = [obj.subjectName '-' obj.savePrefix]; %give us a run name

			%initialise runLog for this run
			obj.previousInfo.runLog = obj.runLog;
			obj.taskLog = timeLogger();
			obj.runLog = timeLogger();
			tL = obj.runLog;

			%-----------------------------------------------------------
			try%======This is our main TRY CATCH experiment display loop
			%-----------------------------------------------------------	
				obj.isRunning = true;
				obj.isRunTask = false;
				%make a handle to the screenManager, so lazy!
				s = obj.screen;
				prepareScreen(s);
				obj.screenVals = s.open(obj.debug,obj.runLog);
				
				%configure IO
				io = configureIO(obj);
				
				%the metastimulus wraps our stimulus cell array
				obj.stimuli.screen = s;
				obj.stimuli.verbose = obj.verbose;
				
				if obj.useDataPixx || obj.useDisplayPP
					startRecording(io);
					WaitSecs(0.5);
				elseif obj.useLabJackStrobe
					%Trigger the omniplex (TTL on FIO1) into paused mode
					io.setDIO([2,0,0]);WaitSecs(0.001);io.setDIO([0,0,0]);
				end

				% set up the eyelink interface
				if obj.useEyeLink
					obj.eyeLink = eyelinkManager();
					eL = obj.eyeLink;
					eL.saveFile = [obj.paths.savedData pathsep obj.savePrefix 'RUN.edf'];
					initialise(eL, s);
					setup(eL);
				end
				
				obj.initialiseTask(); %set up our task structure 
				
				setup(obj.stimuli);
				
				obj.updateVars(1,1); %set the variables for the very first run;
				
				KbReleaseWait; %make sure keyboard keys are all released
				
				%bump our priority to maximum allowed
				Priority(MaxPriority(s.win));
				
				%--------------unpause Plexon-------------------------
				if obj.useDataPixx || obj.useDisplayPP
					resumeRecording(io);
				elseif obj.useLabJackStrobe
					io.setDIO([3,0,0],[3,0,0])%(Set HIGH FIO0->Pin 24), unpausing the omniplex
				end
				
				obj.task.tick = 1;
				obj.task.switched = 1;
				tL.screenLog.beforeDisplay = GetSecs();
				
				if obj.useEyeLink; startRecording(eL); end
				
				% lets draw 1 seconds worth of the stimuli we will be using
				% covered by a blank. this lets us prime the GPU with the sorts
				% of stimuli it will be using and this does appear to minimise
				% some of the frames lost on first presentation for very complex
				% stimuli using 32bit computation buffers...
				obj.salutation('Warming up GPU...')
				show(obj.stimuli);
				for i = 1:s.screenVals.fps
					draw(obj.stimuli);
					drawBackground(s);
					drawScreenCenter(s);
					if s.photoDiode == true;s.drawPhotoDiodeSquare([0 0 0 1]);end
					Screen('DrawingFinished', s.win);
					if obj.useEyeLink; getSample(obj.eyeLink); end
					Screen('Flip', s.win);
				end
				if obj.logFrames == true
					tL.screenLog.stimTime(1) = 1;
				end
				obj.salutation('TASK Starting...')
				tL.vbl(1) = GetSecs;
				tL.startTime = tL.vbl(1);
				
				%==================================================================%
				%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
				% Our main display loop
				%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
				%==================================================================%
				while obj.task.thisBlock <= obj.task.nBlocks
					if obj.task.isBlank == true
						if s.photoDiode == true
							s.drawPhotoDiodeSquare([0 0 0 1]);
						end
						if obj.drawFixation;s.drawCross(0.4,[0.3 0.3 0.3 1]);end
					else
						if ~isempty(s.backgroundColour);s.drawBackground;end
						
						draw(obj.stimuli);
						
						if s.photoDiode;s.drawPhotoDiodeSquare([1 1 1 1]);end
						
						if obj.drawFixation;s.drawCross(0.4,[1 1 1 1]);end
					end
					if s.visualDebug == true
						s.drawGrid;
						obj.infoTextScreen;
					end
					
					Screen('DrawingFinished', s.win); % Tell PTB that no further drawing commands will follow before Screen('Flip')
					
					if obj.task.isBlank == true
						if strcmpi(obj.uiCommand,'stop');break;end
						[~,~,kc] = KbCheck(-1);
						if strcmpi(KbName(kc),'q');notify(obj,'abortRun');break;end
					end
					
					%============== Get eye position==================%
					if obj.useEyeLink; getSample(obj.eyeLink); end
					
					%================= UPDATE TASK ===================%
					updateMOCTask(obj); %update our task structure
					
					%============== Send Strobe =======================%
					if (obj.useDisplayPP || obj.useDataPixx) && obj.sendStrobe
						triggerStrobe(io);
						obj.sendStrobe = false;
					end
					
					%======= FLIP: Show it at correct retrace: ========%
					nextvbl = tL.vbl(end) + obj.screenVals.halfisi;
					if obj.logFrames == true
						[tL.vbl(obj.task.tick),tL.show(obj.task.tick),tL.flip(obj.task.tick),tL.miss(obj.task.tick)] = Screen('Flip', s.win, nextvbl);
					elseif obj.benchmark == true
						tL.vbl = Screen('Flip', s.win, 0, 2, 2);
					else
						tL.vbl = Screen('Flip', s.win, nextvbl);
					end
					
					%===================Logging=======================%
					if obj.task.tick == 1
						if obj.benchmark == false
							tL.startTime=tL.vbl(1); %respecify this with actual stimulus vbl
						end
					end
					if obj.logFrames == true
						if obj.task.isBlank == false
							tL.stimTime(obj.task.tick)=1+obj.task.switched;
						else
							tL.stimTime(obj.task.tick)=0-obj.task.switched;
						end
					end
					if (s.movieSettings.loop <= s.movieSettings.nFrames) && obj.task.isBlank == false
						s.addMovieFrame();
					end
					
					%===================Tick tock!=======================%
					obj.task.tick=obj.task.tick+1; tL.tick = obj.task.tick;
					
				end
				%==================================================================%
				%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
				% Finished display loop
				%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
				%==================================================================%
				
				s.drawBackground;
				vbl=Screen('Flip', s.win);
				tL.screenLog.afterDisplay=vbl;
				if obj.useDataPixx || obj.useDisplayPP
					pauseRecording(io);
				elseif obj.useLabJackStrobe
					io.setDIO([0,0,0],[1,0,0]); %this is RSTOP, pausing the omniplex
				end
				notify(obj,'endAllRuns');
				
				tL.screenLog.deltaDispay=tL.screenLog.afterDisplay - tL.screenLog.beforeDisplay;
				tL.screenLog.deltaUntilDisplay=tL.startTime - tL.screenLog.beforeDisplay;
				tL.screenLog.deltaToFirstVBL=tL.vbl(1) - tL.screenLog.beforeDisplay;
				if obj.benchmark == true
					tL.screenLog.benchmark = obj.task.tick / (tL.screenLog.afterDisplay - tL.startTime);
					fprintf('\n---> BENCHMARK FPS = %g\n', tL.screenLog.benchmark);
				end
				
				s.screenVals.info = Screen('GetWindowInfo', s.win);
				
				s.resetScreenGamma();
				
				if obj.useEyeLink
					close(obj.eyeLink);
					obj.eyeLink = [];
				end
				
				s.finaliseMovie(false);
				
				s.close();
				
				if obj.useDataPixx || obj.useDisplayPP
					stopRecording(io);
					close(io);
				elseif obj.useLabJackStrobe
					obj.lJack.setDIO([2,0,0]);WaitSecs(0.05);obj.lJack.setDIO([0,0,0]); %we stop recording mode completely
					obj.lJack.close;
					obj.lJack=[];
				end
				
				tL.calculateMisses;
				if tL.nMissed > 0
					fprintf('\n!!!>>> >>> >>> There were %i MISSED FRAMES <<< <<< <<<!!!\n',tL.nMissed);
				end
				
				s.playMovie();
				
				obj.isRunning = false;
				
			catch ME
				obj.isRunning = false;
				fprintf('\n\n---!!! ERROR in runExperiment.run()\n');
				getReport(ME)
				if obj.useDataPixx || obj.useDisplayPP
					pauseRecording(io); %pause plexon
					WaitSecs(0.25)
					stopRecording(io);
					close(io);
				end
				%profile off; profile clear
				warning('on') %#ok<WNON>
				Priority(0);
				ListenChar(0);
				ShowCursor;
				resetScreenGamma(s);
				close(s);
				close(obj.eyeLink);
				obj.eyeLink = [];
				obj.behaviouralRecord = [];
				close(rM);
				obj.lJack=[];
				obj.io = [];
				clear tL s tS bR rM eL io sM
				rethrow(ME)	
			end
		end
	
		% ===================================================================
		%> @brief runTask runs a state machine (behaviourally) driven task. Uses a StateInfo.m
		%> file to control the behavioural paradigm. 
		%> @param obj required class object
		% ===================================================================
		function runTask(obj)
			global rM %eyelink calibration needs access for reward
			
			if isempty(regexpi(obj.comment, '^Protocol','once'))
				obj.comment = '';
			end
			
			initialiseSaveFile(obj); %generate a savePrefix for this run
			obj.name = [obj.subjectName '-' obj.savePrefix]; %give us a run name
			if isempty(obj.screen) || isempty(obj.task)
				obj.initialise; %we set up screenManager and stimulusSequence objects
			end
			if obj.screen.isPTB == false %NEED PTB!
				errordlg('There is no working PTB available!')
				error('There is no working PTB available!')
			end
			
			fprintf('\n\n\n===>>> Start task: %s <<<===\n\n\n',obj.name);
			
			%------a general structure to hold various parameters, 
			% will be saved after the run; prefer structure over class 
			% to keep it light. These defaults will be overwritten in StateFile.m
			tS = struct();
			tS.name = 'generic'; %==name of this protocol
			tS.useTask = false; %use stimulusSequence (randomised variable task object)
			tS.checkKeysDuringStimulus = false; %==allow keyboard control? Slight drop in performance
			tS.recordEyePosition = false; %==record eye position within PTB, **in addition** to the EDF?
			tS.askForComments = false; %==little UI requestor asks for comments before/after run
			tS.saveData = false; %==save behavioural and eye movement data?
			tS.dummyEyelink = true; %==use mouse as a dummy eyelink, good for testing away from the lab.
			tS.useMagStim = false;
	
			%------initialise time logs for this run
			obj.previousInfo.taskLog = obj.taskLog;
			obj.runLog = timeLogger();
			obj.taskLog = timeLogger();
			tL = obj.taskLog; %short handle to log
			tL.name = obj.name;
			
			%-----behavioural record
			obj.behaviouralRecord = behaviouralRecord('name',obj.name); %#ok<*CPROP>
			bR = obj.behaviouralRecord; %short handle
		
			%------make a short handle to the screenManager
			s = obj.screen; 
			obj.stimuli.screen = [];
			
			%------initialise task
			t = obj.task;
			initialiseTask(t);
			
			%-----try to open eyeOccluder
			if obj.useEyeOccluder
				if ~isfield(tS,'eO') || ~isa(tS.eO,'eyeOccluder')
					tS.eO = eyeOccluder;
				end
				if tS.eO.isOpen == true
					pause(0.1);
					tS.eO.bothEyesOpen;
				else
					tS.eO = [];
					tS=rmfield(tS,'eO');
				end
			end
			
			%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
			try %================This is our main TASK setup=====================
			%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
				obj.isRunning = true;
				obj.isRunTask = true;
				%-----open the eyelink interface
				if obj.useEyeLink
					obj.eyeLink = eyelinkManager();
					eL = obj.eyeLink;
					eL.verbose = obj.verbose;
					eL.saveFile = [obj.paths.savedData filesep obj.subjectName '-' obj.savePrefix '.edf'];
				end
				
				if isfield(tS,'rewardTime')
					bR.rewardTime = tS.rewardTime;
				end
				
				%------open the PTB screen
				obj.screenVals = s.open(obj.debug,tL);
				obj.stimuli.screen = s; %make sure our stimuli use the same screen
				obj.stimuli.verbose = obj.verbose;
				setup(obj.stimuli); %run setup() for each stimulus
				
				%---------initialise and set up I/O
				io = configureIO(obj);
				
				%-----initialise the state machine
				obj.stateMachine = stateMachine('verbose',obj.verbose,'realTime',true,'timeDelta',1e-4,'name',obj.name); 
				sM = obj.stateMachine;
				if isempty(obj.paths.stateInfoFile) || ~exist(obj.paths.stateInfoFile,'file')
					errordlg('Please specify a valid State Machine file...')
				else
					cd(fileparts(obj.paths.stateInfoFile))
					obj.paths.stateInfoFile = regexprep(obj.paths.stateInfoFile,'\s+','\\ ');
					run(obj.paths.stateInfoFile)
					obj.stateInfo = stateInfoTmp;
					addStates(sM, obj.stateInfo);
				end
				
				%--------get pre-run comments for this data collection
				if tS.askForComments
					comment = inputdlg({'CHECK: ARM PLEXON!!! Initial Comment for this Run?'},['Run Comment for ' obj.name]);
					if ~isempty(comment)
						comment = comment{1};
						obj.comment = [obj.name ':' comment];
						bR.comment = obj.comment; eL.comment = obj.comment; sM.comment = obj.comment; io.comment = obj.comment; tL.comment = obj.comment; tS.comment = obj.comment;
					end
				end
				
				%-----set up the eyelink interface
				if obj.useEyeLink
					fprintf('\n===>>> Handing over to eyelink for calibration & validation...\n')
					initialise(eL, s);
					setup(eL);
				end
				
				%-----set up our behavioural plot
				createPlot(bR, eL);
				drawnow;

				%------------------------------------------------------------
				% lets draw 2 seconds worth of the stimuli we will be using
				% covered by a blank. Primes the GPU and other components with the sorts
				% of stimuli/tasks used and this does appear to minimise
				% some of the frames lost on first presentation for very complex
				% stimuli using 32bit computation buffers...
				fprintf('\n===>>> Warming up the GPU, Eyelink and I/O systems... <<<===\n')
				show(obj.stimuli);
				if obj.useEyeLink; trackerClearScreen(eL); end
				for i = 1:s.screenVals.fps*2
					draw(obj.stimuli);
					drawBackground(s);
					s.drawPhotoDiodeSquare([0 0 0 1]);
					finishDrawing(s);
					animate(obj.stimuli);
					if ~mod(i,10); io.sendStrobe(255); end
					if obj.useEyeLink
						getSample(eL); 
						trackerDrawText(eL,'Warming Up System');
						edfMessage(eL,'Warmup test');
					end
					flip(s);
				end
				update(obj.stimuli); %make sure stimuli are set back to their start state
				io.resetStrobe;flip(s);flip(s);
				
				%-----premptive save in case of crash or error SAVE IN /TMP
				rE = obj;
				htmp = obj.screenSettings.optickahandle; obj.screenSettings.optickahandle = [];
				save([tempdir filesep obj.name '.mat'],'rE','tS');
				obj.screenSettings.optickahandle = htmp;
				
				%-----Start Plexon in paused mode
				if obj.useDisplayPP || obj.useDataPixx
					fprintf('\n===>>> Triggering I/O systems... <<<===\n')
					pauseRecording(io); %make sure this is set low first
					startRecording(io);
					WaitSecs(1);
				end
				
				%-----initialise out various counters
				t.tick = 1;
				t.switched = 1;
				t.totalRuns = 1;
				if tS.useTask == true
					updateVariables(obj, t.totalRuns, true, false); % set to first variable
					update(obj.stimuli); %update our stimuli ready for display
				end
				tS.keyTicks = 0; %tick counter for reducing sensitivity of keyboard
				tS.keyHold = 1; %a small loop to stop overeager key presses
				tS.totalTicks = 1; % a tick counter
				tS.pauseToggle = 1; %toggle pause/unpause
				tS.eyePos = []; %locally record eye position
				
				%-----profiling starts here
				%profile clear; profile on;
				
				%-----take over the keyboard!
				KbReleaseWait; %make sure keyboard keys are all released
				if IsLinux
					Priority(2); %bump our priority to maximum allowed
				else
					Priority(MaxPriority(s.win)); %bump our priority to maximum allowed
				end
				if obj.debug == false
					%warning('off'); %#ok<*WNOFF>
					ListenChar(1); %2=capture all keystrokes
				else
					ListenChar(1); %1=listen
				end
				
				%-----initialise our vbl's
				obj.needSample = false;
				obj.stopTask = false;
				tL.screenLog.beforeDisplay = GetSecs;
				tL.screenLog.trackerStartTime = getTrackerTime(eL);
				tL.screenLog.trackerStartOffset = getTimeOffset(eL);
				tL.vbl(1) = Screen('Flip', s.win);
				tL.startTime = tL.vbl(1);
				
				%-----ignite the stateMachine!
				start(sM); 

				%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
				%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
				% Our task display loop
				%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
				%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
				while obj.stopTask == false
					
					%------run the stateMachine one tick forward
					if obj.needSample; getSample(eL); end
					update(sM);
					
					%------check eye position manually. REMEMBER eyelink will save the real eye data in
					% the EDF this is just a backup wrapped in the PTB loop. 
					%if obj.useEyeLink && tS.recordEyePosition == true
					%	saveEyeInfo(obj, sM, eL, tS);
					%end
					
					%------Check keyboard for commands
					if (~strcmpi(sM.currentName,'fixate') && ~strcmpi(sM.currentName,'stimulus'))
						tS = checkFixationKeys(obj,tS);
					end
					
					%------Tell I/O to send strobe on this screen flip
					if obj.sendStrobe && obj.useDisplayPP
						sendStrobe(io);
					elseif obj.sendStrobe && obj.useDataPixx
						triggerStrobe(io);
					end
					
					%----- FLIP: Show it at correct retrace: -----%
					if obj.doFlip
						nextvbl = tL.vbl(end) + obj.screenVals.halfisi;
						if obj.logFrames == true
							[tL.vbl(tS.totalTicks),tL.show(tS.totalTicks),tL.flip(tS.totalTicks),tL.miss(tS.totalTicks)] = Screen('Flip', s.win, nextvbl);
						elseif obj.benchmark == true
							tL.vbl = Screen('Flip', s.win, 0, 2, 2);
						else
							tL.vbl = Screen('Flip', s.win, nextvbl);
						end
						%----- Send Eyelink messages
						if obj.sendStrobe %if strobe sent with value and VBL time
							%Eyelink('Message', sprintf('MSG:SYNCSTROBE value:%i @ vbl:%20.40g / totalTicks: %i', io.sendValue, tL.vbl(end), tS.totalTicks));
							obj.sendStrobe = false;
						end
						if obj.sendSyncTime % sends SYNCTIME message to eyelink
							syncTime(eL);
							obj.sendSyncTime = false;
						end
						%------Log stim / no stim condition to log
						if strcmpi(sM.currentName,'stimulus')
							tL.stimTime(tS.totalTicks)=1;
						else
							tL.stimTime(tS.totalTicks)=0;
						end
						%----- increment our global tick counter
						tS.totalTicks = tS.totalTicks + 1; tL.tick = tS.totalTicks;
					end
					
				%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
				end %======================END OF TASK LOOP=========================
				%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
				
				tL.screenLog.afterDisplay = GetSecs;
				tL.screenLog.trackerEndTime = getTrackerTime(eL);
				tL.screenLog.trackerEndOffset = getTimeOffset(eL);
				
				show(obj.stimuli); %make all stimuli visible again, useful for editing 
				drawBackground(s);
				trackerClearScreen(eL);
				trackerDrawText(eL,['FINISHED TASK:' obj.name]);
				Screen('Flip', s.win);
				Priority(0);
				ListenChar(0);
				ShowCursor;
				warning('on');
				
				notify(obj,'endAllRuns');
				obj.isRunning = false;
				
				%-----get our profiling report for our task loop
				%profile off; profile report; profile clear
				
				if obj.useDisplayPP || obj.useDataPixx
					pauseRecording(io); %pause plexon
					WaitSecs(0.5);
					stopRecording(io);
					WaitSecs(0.5);
					close(io);
				end
				
				close(s); %screen
				close(eL); % eyelink, should save the EDF for us we've already given it our name and folder
				WaitSecs(0.25);
				close(rM); 
				
				fprintf('\n\n===>>> Total ticks: %g | stateMachine ticks: %g\n', tS.totalTicks, sM.totalTicks);
				fprintf('===>>> Tracker Time: %g | PTB time: %g | Drift Offset: %g\n', ...
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
						obj.comment = [obj.comment ' | Final Comment: ' comment];
						bR.comment = obj.comment;
						eL.comment = obj.comment;
						sM.comment = obj.comment;
						io.comment = obj.comment;
						tL.comment = obj.comment;
						tS.comment = obj.comment;
					end
				end
				
				obj.tS = tS; %copy our tS structure for backup
				
				if tS.saveData
					rE = obj;
					%assignin('base', 'rE', obj);
					assignin('base', 'tS', tS);
					warning('off')
					save([obj.paths.savedData filesep obj.name '.mat'],'rE','bR','tL','tS','sM');
					warning('on')
					fprintf('\n===>>> SAVED DATA to: %s\n',[obj.paths.savedData filesep obj.name '.mat'])
				end
				
				clear rE tL s tS bR rM eL io sM	
				
			catch ME
				obj.isRunning = false;
				fprintf('\n\n===!!! ERROR in runExperiment.runTask()\n');
				getReport(ME)
				if exist('io','var')
					pauseRecording(io); %pause plexon
					WaitSecs(0.25)
					stopRecording(io);
					close(io);
				end
				%profile off; profile clear
				warning('on') %#ok<WNON>
				if obj.useEyeOccluder && isfield(tS,'eO')
					close(tS.eO)
					tS.eO=[];
				end
				Priority(0);
				ListenChar(0);
				ShowCursor;
				close(s);
				close(eL);
				obj.eyeLink = [];
				obj.behaviouralRecord = [];
				close(rM);
				obj.lJack=[];
				obj.io = [];
				clear tL s tS bR rM eL io sM
				rethrow(ME)
			end

		end
		% ===================================================================
		%> @brief prepare the object for the local machine
		%>
		%> @param config allows excluding screen / task initialisation
		%> @return
		% ===================================================================
		function initialise(obj,config)
			if ~exist('config','var')
				config = '';
			end
			if obj.debug == true %let screen inherit debug settings
				obj.screenSettings.debug = true;
				obj.screenSettings.visualDebug = true;
			end
			
			if isempty(regexpi('nostimuli',config)) && (isempty(obj.stimuli) || ~isa(obj.stimuli,'metaStimulus'))
				obj.stimuli = metaStimulus();
			end
			
			if isempty(regexpi('noscreen',config)) && isempty(obj.screen)
				obj.screen = screenManager(obj.screenSettings);
			end
			
			if isempty(regexpi('notask',config)) && isempty(obj.task)
				obj.task = stimulusSequence();
			end
			
			if obj.useDisplayPP == true
				obj.useLabJackStrobe = false;
				obj.dPP = plusplusManager();
			elseif obj.useDataPixx == true
				obj.useLabJackStrobe = false;
				obj.dPixx = dPixxManager();
			end
			
			if ~isfield(obj.paths,'stateInfoFile') || isempty(obj.paths.stateInfoFile)
				if exist([obj.paths.root filesep 'DefaultStateInfo.m'],'file')
					obj.paths.stateInfoFile = [obj.paths.root filesep 'DefaultStateInfo.m'];
				end
			end
			
			obj.screen.movieSettings.record = 0;
			obj.screen.movieSettings.size = [400 400];
			obj.screen.movieSettings.quality = 0;
			obj.screen.movieSettings.nFrames = 100;
			obj.screen.movieSettings.type = 1;
			obj.screen.movieSettings.codec = 'rle ';
				
			if obj.screen.isPTB == true
				obj.computer=Screen('computer');
				obj.ptb=Screen('version');
			end
		
			obj.screenVals = obj.screen.screenVals;
			
			obj.stopTask = false;
			
			if isa(obj.runLog,'timeLogger')
				obj.runLog.screenLog.prepTime=obj.runLog.timer()-obj.runLog.screenLog.construct;
			end
			
		end
		
		% ===================================================================
		%> @brief check if stateMachine has finished, set tS.stopTask true
		%>
		%> @param
		% ===================================================================
		function checkTaskEnded(obj)
			if obj.stateMachine.isRunning && obj.task.taskFinished
				obj.stopTask = true;
			end
		end
		
		% ===================================================================
		%> @brief getrunLog Prints out the frame time plots from a run
		%>
		%> @param
		% ===================================================================
		function getRunLog(obj)
			if isa(obj.taskLog,'timeLogger') && obj.taskLog.vbl(1) ~= 0
				obj.taskLog.printRunLog;
			elseif isa(obj.runLog,'timeLogger') && obj.runLog.vbl(1) ~= 0
				obj.runLog.printRunLog;
			else
				warndlg('No log available yet...');
			end
		end
		
		% ===================================================================
		%> @brief updates eyelink with stimuli position
		%>
		%> @param
		% ===================================================================
		function updateFixationTarget(obj, useTask, varargin)
			if ~exist('useTask','var');	useTask = false; end
			if useTask == false
				updateFixationValues(obj.eyeLink, obj.stimuli.lastXPosition, obj.stimuli.lastYPosition)
			else
				[obj.lastXPosition,obj.lastYPosition] = getFixationPositions(obj.stimuli);
				updateFixationValues(obj.eyeLink, obj.lastXPosition, obj.lastYPosition, varargin);
			end
		end
		
		% ===================================================================
		%> @brief checks the variable value of a stimulus (e.g. its angle) and then sets a fixation target based on
		%> that value, so you can use two test stimuli and set the target to one of them in a
		%> forced choice paradigm.
		%>
		%> @param
		% ===================================================================
		function updateConditionalFixationTarget(obj, stimulus, variable, mapping, varargin)
			stimuluschoice = [];
			try
				value = obj.stimuli{stimulus}.([variable 'Out']); %get our value
				stimuluschoice = mapping(2,mapping(1,:)==value);
			end
			if ~isempty(stimuluschoice)
				obj.stimuli.fixationChoice = stimuluschoice;
				[obj.lastXPosition,obj.lastYPosition] = getFixationPositions(obj.stimuli);
				updateFixationValues(obj.eyeLink, obj.lastXPosition, obj.lastYPosition, varargin);
			end
		end
		
		% ===================================================================
		%> @brief when running allow keyboard override, so we can edit/debug things
		%>
		%> @param
		% ===================================================================
		function keyOverride(obj, tS)
			KbReleaseWait; %make sure keyboard keys are all released
			ListenChar(0); %capture keystrokes
			ShowCursor;
			ii = 0;
			dbstop in clear
			%uiinspect(obj)
			clear ii
			dbclear in clear
			ListenChar(2); %capture keystrokes
			%HideCursor;
		end
		
		% ===================================================================
		%> @brief set.verbose
		%>
		%> Let us cascase verbosity to other classes
		% ===================================================================
		function set.verbose(obj,value)
			value = logical(value);
			obj.verbose = value;
			if isa(obj.task,'stimulusSequence') %#ok<*MCSUP>
				obj.task.verbose = value;
			end
			if isa(obj.screen,'screenManager')
				obj.screen.verbose = value;
			end
			if isa(obj.stateMachine,'stateMachine')
				obj.stateMachine.verbose = value;
			end
			if isa(obj.eyeLink,'eyelinkManager')
				obj.eyeLink.verbose = value;
			end
			if isa(obj.lJack,'labJack')
				obj.lJack.verbose = value;
			end
			if isa(obj.dPixx,'dPixxManager')
				obj.dPixx.verbose = value;
			end
			if isa(obj.dPP,'plusplusManager')
				obj.dPP.verbose = value;
			end
			if isa(obj.stimuli,'metaStimulus') && obj.stimuli.n > 0
				for i = 1:obj.stimuli.n
					obj.stimuli{i}.verbose = value;
				end
			end
			obj.salutation(sprintf('Verbose = %i cascaded...',value));
		end
		
		% ===================================================================
		%> @brief set.stimuli
		%>
		%> Migrate to use a metaStimulus object to manage stimulus objects
		% ===================================================================
		function set.stimuli(obj,in)
			if isempty(obj.stimuli) || ~isa(obj.stimuli,'metaStimulus')
				obj.stimuli = metaStimulus();
			end
			if isa(in,'metaStimulus')
				obj.stimuli = in;
			elseif isa(in,'baseStimulus')
				obj.stimuli{1} = in;
			elseif iscell(in)
				obj.stimuli.stimuli = in;
			end
		end
		
		% ===================================================================
		%> @brief Initialise Save Dir
		%>
		%> For single stimulus presentation, randomise stimulus choice
		% ===================================================================
		function initialiseSaveFile(obj,path)
			if ~exist('path','var')
				path = obj.paths.savedData;
			else
				obj.paths.savedData = path;
			end
			c = fix(clock);
			c = num2str(c(1:5));
			c = regexprep(c,' +','-');
			obj.savePrefix = c;
		end
		
		% ===================================================================
		%> @brief randomiseTrainingList
		%>
		%> For single stimulus presentation, randomise stimulus choice
		% ===================================================================
		function randomiseTrainingList(obj)
			if ~isempty(obj.thisStim)
				obj.thisStim = randi(length(obj.stimList));
				obj.stimuli.choice = obj.thisStim;
			end
		end
		
		% ===================================================================
		%> @brief set strobe value
		%>
		%> 
		% ===================================================================
		function setStrobeValue(obj, value)
			if value == Inf; value = obj.stimOFFValue; end
			if obj.useDisplayPP == true
				prepareStrobe(obj.dPP, value);
			elseif obj.useDataPixx == true
				prepareStrobe(obj.dPixx, value);
			elseif isa(obj.lJack,'labJack') && obj.lJack.isOpen == true
				prepareStrobe(obj.lJack, value)
			end
		end
		
		% ===================================================================
		%> @brief set strobe to trigger on next flip
		%>
		%> 
		% ===================================================================
		function doStrobe(obj, value)
			if value == true
				obj.sendStrobe = true;
			else
				obj.sendStrobe = false;
			end
		end
		
		% ===================================================================
		%> @brief send SYNCTIME message to eyelink after flip
		%>
		%> 
		% ===================================================================
		function doSyncTime(obj)
			obj.sendSyncTime = true;
		end
		
		% ===================================================================
		%> @brief enable screen flip
		%>
		%> 
		% ===================================================================
		function enableFlip(obj)
			obj.doFlip = true;
		end
		
		% ===================================================================
		%> @brief disable screen flip
		%>
		%> 
		% ===================================================================
		function disableFlip(obj)
			obj.doFlip = false;
		end
		
		
		% ===================================================================
		%> @brief update task run index
		%>
		%> 
		% ===================================================================
		function updateTaskIndex(obj)
			updateTask(obj.task);
			if obj.task.totalRuns > obj.task.nRuns
				obj.currentInfo.stopTask = true;
			end
		end
		
		% ===================================================================
		%> @brief get task run index
		%>
		%> 
		% ===================================================================
		function trial = getTaskIndex(obj, index)
			if ~exist('index','var') || isempty(index)
				index = obj.task.totalRuns;
			end
			if index > 0
				trial = obj.task.outIndex(index);
			else
				trial = -1;
			end
		end
		
		% ===================================================================
		%> @brief updateVariables
		%> Updates the stimulus objects with the current variable set
		%> @param index a single value
		% ===================================================================
		function updateVariables(obj,index,override,update)
			if ~exist('update','var') || isempty(update)
				update = false;
			end
			if update == true
				updateTask(obj.task,true,GetSecs); %do this before getting index
			end
			if ~exist('index','var') || isempty(index)
				index = obj.task.totalRuns;
			end
			if ~exist('override','var') || isempty(override)
				override = false;
			end
			if obj.useDataPixx || obj.useDisplayPP
				setStrobeValue(obj, obj.task.outIndex(index));
			end
			if (index > obj.lastIndex) || override == true
				[thisBlock, thisRun] = obj.task.findRun(index);
				t = sprintf('Total#%g|Block#%g|Run#%g = ',index,thisBlock,thisRun);
				for i=1:obj.task.nVars
					ix = []; valueList = cell(1); oValueList = cell(1); %#ok<NASGU>
					doXY = false;
					ix = obj.task.nVar(i).stimulus; %which stimuli
					value=obj.task.outVars{thisBlock,i}(thisRun);
					if iscell(value)
						value = value{1};
					end
					[valueList{1,1:size(ix,2)}] = deal(value);
					name=[obj.task.nVar(i).name 'Out']; %which parameter
					
					if regexpi(name,'^xyPositionOut','once')
						doXY = true;
						obj.lastXPosition = value(1);
						obj.lastYPosition = value(2);
					elseif regexpi(name,'^xPositionOut','once')
						obj.lastXPosition = value;
					elseif regexpi(name,'^yPositionOut','once')
						obj.lastYPosition = value;
					elseif regexpi(name,'^sizeOut','once')
						obj.lastSize = value;
					end
					
					offsetix = obj.task.nVar(i).offsetstimulus;
					offsetvalue = obj.task.nVar(i).offsetvalue;

					if ~isempty(offsetix)
						ix = [ix offsetix];
						[ovalueList{1,1:size(offsetix,2)}] = deal(value+offsetvalue);
						valueList = [valueList{:} ovalueList];
					end

					a = 1;
					for j = ix %loop through our stimuli references for this variable
						t = [t sprintf('S%i: %s = %s ',j,name,num2str(valueList{a}))];
						if ~doXY
							obj.stimuli{j}.(name)=valueList{a};
						else
							obj.stimuli{j}.xPositionOut=valueList{a}(1);
							obj.stimuli{j}.yPositionOut=valueList{a}(2);
						end
						a = a + 1;
					end
				end
				obj.behaviouralRecord.info = t;
				obj.lastIndex = index;
			end
		end
		
		% ===================================================================
		%> @brief do we use eyelinkManager getSample on current flip?
		%>
		%> @param
		% ===================================================================
		function needEyelinkSample(obj,value)
			obj.needSample = value;
		end
		
		% ===================================================================
		%> @brief deletes the run logs
		%>
		%> @param
		% ===================================================================
		function deleteRunLog(obj)
			obj.runLog = [];
			obj.taskLog = [];
		end
		
		% ===================================================================
		%> @brief refresh the screen values stored in the object
		%>
		%> @param
		% ===================================================================
		function refreshScreen(obj)
			obj.screenVals = obj.screen.prepareScreen();
		end
		
		% ===================================================================
		%> @brief print run info to command window
		%>
		%> @param
		% ===================================================================
		function logRun(obj,tag)
			if obj.isRunning
				if ~exist('tag','var'); tag = '#'; end
				t = obj.infoText;
				fprintf('===> %s: %s\n',tag,t);
			end			
		end

		% ===================================================================
		%> @brief no operation, tests method call overhead
		%>
		%> @param
		% ===================================================================
		function noop(obj)
			% used to test any overhead of simply calling an empty method
		end

	end%-------------------------END PUBLIC METHODS--------------------------------%
	
	%=======================================================================
	methods (Access = private) %------------------PRIVATE METHODS
	%=======================================================================
		
		% ===================================================================
		%> @brief configureIO
		%> Configures the IO devices.
		%> @param
		% ===================================================================
		function io = configureIO(obj)
			global rM
			%-------Set up Digital I/O (dPixx and labjack) for this task run...
			if obj.useDisplayPP
				if ~isa(obj.dPP,'plusplusManager')
					obj.dPP = plusplusManager();
				end
				io = obj.dPP;  %#ok<*PROP>
				io.sM = obj.screen;
				io.strobeMode = obj.dPPMode;
				obj.stimOFFValue = 255;
				io.name = obj.name;
				io.verbose = obj.verbose;
				io.name = 'runinstance';
				open(io);
				obj.useLabJackStrobe = false;
				obj.useDataPixx = false;
			elseif obj.useDataPixx
				if ~isa(obj.dPixx,'dPixxManager')
					obj.dPixx = dPixxManager('verbose',obj.verbose);
				end
				io = obj.dPixx; io.name = obj.name;
				io.stimOFFValue = 2^15;
				io.silentMode = false;
				io.verbose = obj.verbose;
				io.name = 'runinstance';
				open(io);
				obj.useLabJackStrobe = false;
				obj.useDisplayPP = false;
			else
				io = ioManager();
				io.silentMode = true;
				io.verbose = false;
				io.name = 'silentruninstance';
				obj.useDataPixx = false;
				obj.useLabJackStrobe = false;
				obj.useDisplayPP = false;
			end
			if obj.useArduino
				obj.arduino = arduinoManager('port',ana.arduinoPort);
				rM = obj.arduino;
			elseif obj.useLabJackReward
				obj.lJack = labJack('name',obj.name,'readResponse', false,'verbose',obj.verbose);
				rM = obj.lJack;
			else
				rM = ioManager();
			end
		end
		
		% ===================================================================
		%> @brief InitialiseTask
		%> Sets up the task structure with dynamic properties
		%> @param
		% ===================================================================
		function initialiseTask(obj)
			if isempty(obj.task) %we have no task setup, so we generate one.
				obj.task=stimulusSequence;
			end
			initialiseTask(obj.task);
		end
		
		% ===================================================================
		%> @brief updateVars
		%> Updates the stimulus objects with the current variable set
		%> @param thisBlock is the current trial
		%> @param thisRun is the current run
		% ===================================================================
		function updateVars(obj,thisBlock,thisRun)
			
			if thisBlock > obj.task.nBlocks
				return %we've reached the end of the experiment, no need to update anything!
			end
			
			%start looping through out variables
			for i=1:obj.task.nVars
				ix = []; valueList = []; oValueList = []; %#ok<NASGU>
				ix = obj.task.nVar(i).stimulus; %which stimuli
				value=obj.task.outVars{thisBlock,i}(thisRun);
				if iscell(value); value = value{1}; end
				valueList = repmat({value},length(ix),1);
				name=[obj.task.nVar(i).name 'Out']; %which parameter
				
				offsetix = obj.task.nVar(i).offsetstimulus;
				offsetvalue = obj.task.nVar(i).offsetvalue;
				if ~isempty(offsetix)
					ix = [ix offsetix];
					offsetvalue = value + offsetvalue;
					valueList = [valueList; offsetvalue];
				end
				
				if obj.task.blankTick > 2 && obj.task.blankTick <= obj.stimuli.n + 2
					%obj.stimuli{j}.(name)=value;
				else
					a = 1;
					for j = ix %loop through our stimuli references for this variable
						if obj.verbose==true;tic;end
						obj.stimuli{j}.(name)=valueList{a};
						if thisBlock == 1 && thisRun == 1 %make sure we update if this is the first run, otherwise the variables may not update properly
							update(obj.stimuli, j);
						end
						if obj.verbose==true
							fprintf('=-> updateVars() block/trial %i/%i: Variable:%i %s = %s | Stimulus %g -> %g ms\n',thisBlock,thisRun,i,name,num2str(valueList{a}),j,toc*1000);
						end
						a = a + 1;
					end
				end
			end
		end
		
		% ===================================================================
		%> @brief updateMOCTask
		%> Updates the stimulus run state; update the stimulus values for the
		%> current trial and increments the switchTime and switchTick timer
		% ===================================================================
		function updateMOCTask(obj)
			obj.task.timeNow = GetSecs;
			obj.sendStrobe = false;
			
			%--------------first run-----------------
			if obj.task.tick==1 
				obj.task.isBlank = false;
				obj.task.startTime = obj.task.timeNow;
				obj.task.switchTime = obj.task.trialTime; %first ever time is for the first trial
				obj.task.switchTick = obj.task.trialTime*ceil(obj.screenVals.fps);
				setStrobeValue(obj,obj.task.outIndex(obj.task.totalRuns));
				obj.sendStrobe = true;
			end
			
			%-------------------------------------------------------------------
			if obj.task.realTime == true %we measure real time
				trigger = obj.task.timeNow <= (obj.task.startTime+obj.task.switchTime);
			else %we measure frames, prone to error build-up
				trigger = obj.task.tick < obj.task.switchTick;
			end
			
			if trigger == true %no need to switch state
				
				if obj.task.isBlank == false %showing stimulus, need to call animate for each stimulus
					% because the update happens before the flip, but the drawing of the update happens
					% only in the next loop, we have to send the strobe one loop after we set switched
					% to true
					if obj.task.switched == true
						obj.sendStrobe = true;
					end
					
					%if obj.verbose==true;tic;end
% 					for i = 1:obj.stimuli.n %parfor appears faster here for 6 stimuli at least
% 						obj.stimuli{i}.animate;
% 					end
					animate(obj.stimuli);
					%if obj.verbose==true;fprintf('=-> updateMOCTask() Stimuli animation: %g ms\n',toc*1000);end
					
				else %this is a blank stimulus
					obj.task.blankTick = obj.task.blankTick + 1;
					%this causes the update of the stimuli, which may take more than one refresh, to
					%occur during the second blank flip, thus we don't lose any timing.
					if obj.task.blankTick == 2
						fprintf('@%s\n\n',infoText(obj));
						obj.task.doUpdate = true;
					end
					% because the update happens before the flip, but the drawing of the update happens
					% only in the next loop, we have to send the strobe one loop after we set switched
					% to true
					if obj.task.switched == true
						obj.sendStrobe = true;
					end
					% now update our stimuli, we do it after the first blank as less
					% critical timingwise
					if obj.task.doUpdate == true
						if ~mod(obj.task.thisRun,obj.task.minBlocks) %are we rolling over into a new trial?
							mT=obj.task.thisBlock+1;
							mR = 1;
						else
							mT=obj.task.thisBlock;
							mR = obj.task.thisRun + 1;
						end
						obj.updateVars(mT,mR);
						obj.task.doUpdate = false;
					end
					%this dispatches each stimulus update on a new blank frame to
					%reduce overhead.
					if obj.task.blankTick > 2 && obj.task.blankTick <= obj.stimuli.n + 2
						%if obj.verbose==true;tic;end
						update(obj.stimuli, obj.task.blankTick-2);
						%if obj.verbose==true;fprintf('=-> updateMOCTask() Blank-frame %i: stimulus %i update = %g ms\n',obj.task.blankTick,obj.task.blankTick-2,toc*1000);end
					end
					
				end
				obj.task.switched = false;
				
				%-------------------------------------------------------------------
			else %need to switch to next trial or blank
				obj.task.switched = true;
				if obj.task.isBlank == false %we come from showing a stimulus
					%obj.logMe('IntoBlank');
					obj.task.isBlank = true;
					obj.task.blankTick = 0;
					
					if obj.task.thisRun == obj.task.minBlocks %are we within a trial block or not? we add the required time to our switch timer
						obj.task.switchTime=obj.task.switchTime+obj.task.ibTimeNow;
						obj.task.switchTick=obj.task.switchTick+(obj.task.ibTimeNow*ceil(obj.screenVals.fps));
						fprintf('IB TIME: %g\n',obj.task.ibTimeNow);
					else
						obj.task.switchTime=obj.task.switchTime+obj.task.isTimeNow;
						obj.task.switchTick=obj.task.switchTick+(obj.task.isTimeNow*ceil(obj.screenVals.fps));
						fprintf('IS TIME: %g\n',obj.task.isTimeNow);
					end
					
					setStrobeValue(obj,obj.stimOFFValue);%get the strobe word to signify stimulus OFF ready
					%obj.logMe('OutaBlank');
					
				else %we have to show the new run on the next flip
					%obj.logMe('IntoTrial');
					obj.task.switchTime=obj.task.switchTime+obj.task.trialTime; %update our timer
					obj.task.switchTick=obj.task.switchTick+(obj.task.trialTime*round(obj.screenVals.fps)); %update our timer
					obj.task.isBlank = false;
					updateTask(obj.task);
					if obj.task.totalRuns <= obj.task.nRuns
						setStrobeValue(obj,obj.task.outIndex(obj.task.totalRuns)); %get the strobe word ready
					end
					%obj.logMe('OutaTrial');
				end
			end
		end
		
		% ===================================================================
		%> @brief infoTextScreen - draws text about frame to screen
		%>
		%> @param
		%> @return
		% ===================================================================
		function infoTextScreen(obj)
			t=infoText();
			Screen('DrawText',obj.screen.win,t,50,1,[1 1 1 1],[0 0 0 1]);
		end
		
		% ===================================================================
		%> @brief infoText - info string
		%>
		%> @param
		%> @return
		% ===================================================================
		function t = infoText(obj)
			if obj.isRunTask; log = obj.taskLog; else; log = obj.runLog; end
			if obj.logFrames == true && log.tick > 1
				t=sprintf('B: %i | R: %i [%i/%i] | isBlank: %i | Time: %3.3f (%i) | V: %i |',...
					obj.task.thisBlock, obj.task.thisRun,obj.task.totalRuns,...
					obj.task.nRuns,obj.task.isBlank, ...
					(log.vbl(end)-log.startTime),...
					log.tick,obj.task.outIndex(obj.task.totalRuns));
			else
				t=sprintf('B: %i | R: %i [%i/%i] | isBlank: %i | Time: %3.3f (%i) | V: %i |',...
					obj.task.thisBlock,obj.task.thisRun,obj.task.totalRuns,...
					obj.task.nRuns,obj.task.isBlank, ...
					(log.vbl(1)-log.startTime),log.tick,...
					obj.task.outIndex(obj.task.totalRuns));
			end
			for i=1:obj.task.nVars
				if iscell(obj.task.outVars{obj.task.thisBlock,i}(obj.task.thisRun))
					t=[t sprintf(' / %s: %s',obj.task.nVar(i).name,...
						num2str(obj.task.outVars{obj.task.thisBlock,i}{obj.task.thisRun}))];
				else
					t=[t sprintf(' / %s: %2.2f',obj.task.nVar(i).name,...
						obj.task.outVars{obj.task.thisBlock,i}(obj.task.thisRun))];
				end
			end
		end
		
		% ===================================================================
		%> @brief Logs the run loop parameters along with a calling tag
		%>
		%> Logs the run loop parameters along with a calling tag
		%> @param tag the calling function
		% ===================================================================
		function logMe(obj,tag)
			if obj.verbose == 1 && obj.debug == 1
				if ~exist('tag','var')
					tag='#';
				end
				fprintf('%s -- B: %i | R: %i [%i/%i] | TT: %i | Tick: %i | Time: %5.8g\n',tag,...
					obj.task.thisBlock,obj.task.thisRun,obj.task.totalRuns,obj.task.nRuns,...
					obj.task.isBlank,obj.task.tick,obj.task.timeNow-obj.task.startTime);
			end
		end
		
		% ===================================================================
		%> @brief save this trial eye info
		%>
		%> @param 
		% ===================================================================
		function tS = saveEyeInfo(obj,sM,eL,tS)
			switch sM.currentName
				case 'stimulus'
					prefix = 'E';
				case 'fixate'
					prefix = 'F';
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
					tS.eyePos.(uuid).x(end+1) = eL.x;
					tS.eyePos.(uuid).y(end+1) = eL.y;
				else
					tS.eyePos.(uuid).x = eL.x;
					tS.eyePos.(uuid).y = eL.y;
				end
			end
		end
		
		% ===================================================================
		%> @brief manage key commands during task loop
		%>
		%> @param args input structure
		% ===================================================================
		function tS = checkFixationKeys(obj,tS)
			%frame increment to stop keys being too sensitive
			fInc = 6;
			tS.keyTicks = tS.keyTicks + 1;
			%now lets check whether any keyboard commands are pressed...
			[keyIsDown, ~, keyCode] = KbCheck(-1);
			if keyIsDown == 1
				rchar = KbName(keyCode);
				if iscell(rchar);rchar=rchar{1};end
				switch rchar
					case 'q' %quit
						obj.stopTask = true;
					case {'UpArrow','up'} %give a reward at any time
						if tS.keyTicks > tS.keyHold
							if ~isempty(obj.stimuli.controlTable)
								maxl = length(obj.stimuli.controlTable);
								if isempty(obj.stimuli.tableChoice) && maxl > 0
									obj.stimuli.tableChoice = 1;
								end
								if (obj.stimuli.tableChoice > 0) && (obj.stimuli.tableChoice < maxl)
									obj.stimuli.tableChoice = obj.stimuli.tableChoice + 1;
								end
								var=obj.stimuli.controlTable(obj.stimuli.tableChoice).variable;
								delta=obj.stimuli.controlTable(obj.stimuli.tableChoice).delta;
								fprintf('===>>> Set Control table %g - %s : %g\n',obj.stimuli.tableChoice,var,delta)
							end
							tS.keyHold = tS.keyTicks + fInc;
						end
					case {'DownArrow','down'}
						if tS.keyTicks > tS.keyHold
							if ~isempty(obj.stimuli.controlTable)
								maxl = length(obj.stimuli.controlTable);
								if isempty(obj.stimuli.tableChoice) && maxl > 0
									obj.stimuli.tableChoice = 1;
								end
								if (obj.stimuli.tableChoice > 1) && (obj.stimuli.tableChoice <= maxl)
									obj.stimuli.tableChoice = obj.stimuli.tableChoice - 1;
								end
								var=obj.stimuli.controlTable(obj.stimuli.tableChoice).variable;
								delta=obj.stimuli.controlTable(obj.stimuli.tableChoice).delta;
								fprintf('===>>> Set Control table %g - %s : %g\n',obj.stimuli.tableChoice,var,delta)
							end
							tS.keyHold = tS.keyTicks + fInc;
						end
					
					case {'LeftArrow','left'} %previous variable 1 value
						if tS.keyTicks > tS.keyHold
							if ~isempty(obj.stimuli.controlTable.variable)
								choice = obj.stimuli.tableChoice;
								if isempty(choice)
									choice = 1;
								end
								var = obj.stimuli.controlTable(choice).variable;
								delta = obj.stimuli.controlTable(choice).delta;
								stims = obj.stimuli.controlTable(choice).stimuli;
								thisstim = obj.stimuli.stimulusSets{obj.stimuli.setChoice}; %what stimulus is visible?
								stims = intersect(stims,thisstim); %only change the visible stimulus
								limits = obj.stimuli.controlTable(choice).limits;
								for i = 1:length(stims)
									if strcmpi(var,'size') || strcmpi(var,'dotSize')
										oval = obj.stimuli{stims(i)}.([var 'Out']) / obj.stimuli{stims(i)}.ppd;
									elseif strcmpi(var,'sf')
										oval = obj.stimuli{stims(i)}.getsfOut;
									else
										oval = obj.stimuli{stims(i)}.([var 'Out']);
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
									obj.stimuli{stims(i)}.([var 'Out']) = val;
									fprintf('===>>> Stimulus#%g--%s: %g (%g)\n',stims(i),var,val,oval)
								end
							end
							tS.keyHold = tS.keyTicks + fInc;
						end
					case {'RightArrow','right'} %next variable 1 value
						if tS.keyTicks > tS.keyHold
							if ~isempty(obj.stimuli.controlTable.variable)
								choice = obj.stimuli.tableChoice;
								if isempty(choice)
									choice = 1;
								end
								var = obj.stimuli.controlTable(choice).variable;
								delta = obj.stimuli.controlTable(choice).delta;
								stims = obj.stimuli.controlTable(choice).stimuli;
								thisstim = obj.stimuli.stimulusSets{obj.stimuli.setChoice}; %what stimulus is visible?
								stims = intersect(stims,thisstim); %only change the visible stimulus
								limits = obj.stimuli.controlTable(choice).limits;
								for i = 1:length(stims)
									if strcmpi(var,'size') || strcmpi(var,'dotSize')
										oval = obj.stimuli{stims(i)}.([var 'Out']) / obj.stimuli{stims(i)}.ppd;
									elseif strcmpi(var,'sf')
										oval = obj.stimuli{stims(i)}.getsfOut;
									else
										oval = obj.stimuli{stims(i)}.([var 'Out']);
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
									obj.stimuli{stims(i)}.([var 'Out']) = val;
									fprintf('===>>> Stimulus#%g--%s: %g (%g)\n',stims(i),var,val,oval)
								end
							end
							tS.keyHold = tS.keyTicks + fInc;
						end
					case ',<'
						if tS.keyTicks > tS.keyHold
							if obj.stimuli.setChoice > 1
								obj.stimuli.setChoice = round(obj.stimuli.setChoice - 1);
								obj.stimuli.showSet();
							end
							fprintf('===>>> Stimulus Set: #%g | Stimuli: %s\n',obj.stimuli.setChoice, num2str(obj.stimuli.stimulusSets{obj.stimuli.setChoice}))
							tS.keyHold = tS.keyTicks + fInc;
						end
					case '.>'
						if tS.keyTicks > tS.keyHold
							if obj.stimuli.setChoice < length(obj.stimuli.stimulusSets)
								obj.stimuli.setChoice = obj.stimuli.setChoice + 1;
								obj.stimuli.showSet();
							end
							fprintf('===>>> Stimulus Set: #%g | Stimuli: %s\n',obj.stimuli.setChoice, num2str(obj.stimuli.stimulusSets{obj.stimuli.setChoice}))
							tS.keyHold = tS.keyTicks + fInc;
						end
					case 'r'
						timedTTL(rM,0,150);
					case '=+'
						if tS.keyTicks > tS.keyHold
							obj.screen.screenXOffset = obj.screen.screenXOffset + 1;
							fprintf('===>>> Screen X Center: %g deg / %g pixels\n',obj.screen.screenXOffset,obj.screen.xCenter);
							tS.keyHold = tS.keyTicks + fInc;
						end
					case '-_'
						if tS.keyTicks > tS.keyHold
							obj.screen.screenXOffset = obj.screen.screenXOffset - 1;
							fprintf('===>>> Screen X Center: %g deg / %g pixels\n',obj.screen.screenXOffset,obj.screen.xCenter);
							tS.keyHold = tS.keyTicks + fInc;
						end
					case '[{'
						if tS.keyTicks > tS.keyHold
							obj.screen.screenYOffset = obj.screen.screenYOffset - 1;
							fprintf('===>>> Screen Y Center: %g deg / %g pixels\n',obj.screen.screenYOffset,obj.screen.yCenter);
							tS.keyHold = tS.keyTicks + fInc;
						end
					case ']}'
						if tS.keyTicks > tS.keyHold
							obj.screen.screenYOffset = obj.screen.screenYOffset + 1;
							fprintf('===>>> Screen Y Center: %g deg / %g pixels\n',obj.screen.screenYOffset,obj.screen.yCenter);
							tS.keyHold = tS.keyTicks + fInc;
						end
					case 'k'
						if tS.keyTicks > tS.keyHold
							stateName = 'blank';
							[isState, index] = isStateName(obj.stateMachine,stateName);
							if isState
								t = obj.stateMachine.getState(stateName);
								if isfield(t,'time')
									tout = t.time - 0.25;
									if min(tout) >= 0.1
										obj.stateMachine.editStateByName(stateName,'time',tout);
										fprintf('===>>> Decrease %s time: %g:%g\n',t.name, min(tout),max(tout));
									end
								end
							end
							tS.keyHold = tS.keyTicks + fInc;
						end
					case 'l'
						if tS.keyTicks > tS.keyHold
							stateName = 'blank';
							[isState, index] = isStateName(obj.stateMachine,stateName);
							if isState
								t = obj.stateMachine.getState(stateName);
								if isfield(t,'time')
									tout = t.time + 0.25;
									obj.stateMachine.editStateByName(stateName,'time',tout);
									fprintf('===>>> Increase %s time: %g:%g\n',t.name, min(tout),max(tout));
								end
								
							end
							tS.keyHold = tS.keyTicks + fInc;
						end
					case 'm'
						if tS.keyTicks > tS.keyHold
							fprintf('===>>> Calibrate ENGAGED!\n');
							tS.pauseToggle = tS.pauseToggle + 1; %we go to pause after this so toggle this
							tS.keyHold = tS.keyTicks + fInc;
							forceTransition(obj.stateMachine, 'calibrate');	
							return
						end						
					case 'f'
						if tS.keyTicks > tS.keyHold
							fprintf('===>>> Flash ENGAGED!\n');
							tS.pauseToggle = tS.pauseToggle + 1; %we go to pause after this so toggle this
							tS.keyHold = tS.keyTicks + fInc;
							forceTransition(obj.stateMachine, 'flash');
							return
						end	
					case 't'
						if tS.keyTicks > tS.keyHold
							fprintf('===>>> MagStim ENGAGED!\n');
							tS.pauseToggle = tS.pauseToggle + 1; %we go to pause after this so toggle this
							tS.keyHold = tS.keyTicks + fInc;
							forceTransition(obj.stateMachine, 'magstim');
							return
						end
					case 'o'
						if tS.keyTicks > tS.keyHold
							fprintf('===>>> Override ENGAGED!\n');
							tS.pauseToggle = tS.pauseToggle + 1; %we go to pause after this so toggle this
							tS.keyHold = tS.keyTicks + fInc;
							forceTransition(obj.stateMachine, 'override');
							return
						end	
					case 'g'
						if tS.keyTicks > tS.keyHold
							fprintf('===>>> grid ENGAGED!\n');
							tS.pauseToggle = tS.pauseToggle + 1; %we go to pause after this so toggle this
							tS.keyHold = tS.keyTicks + fInc;
							forceTransition(obj.stateMachine, 'showgrid');
							return
						end		
					case 'z' 
						if tS.keyTicks > tS.keyHold
							obj.eyeLink.fixationInitTime = obj.eyeLink.fixationInitTime - 0.1;
							if obj.eyeLink.fixationInitTime < 0.01
								obj.eyeLink.fixationInitTime = 0.01;
							end
							tS.firstFixInit = obj.eyeLink.fixationInitTime;
							fprintf('===>>> FIXATION INIT TIME: %g\n',obj.eyeLink.fixationInitTime)
							tS.keyHold = tS.keyTicks + fInc;
						end
					case 'x' 
						if tS.keyTicks > tS.keyHold
							obj.eyeLink.fixationInitTime = obj.eyeLink.fixationInitTime + 0.1;
							tS.firstFixInit = obj.eyeLink.fixationInitTime;
							fprintf('===>>> FIXATION INIT TIME: %g\n',obj.eyeLink.fixationInitTime)
							tS.keyHold = tS.keyTicks + fInc;
						end
					case 'c' 
						if tS.keyTicks > tS.keyHold
							obj.eyeLink.fixationTime = obj.eyeLink.fixationTime - 0.1;
							if obj.eyeLink.fixationTime < 0.01
								obj.eyeLink.fixationTime = 0.01;
							end
							tS.firstFixTime = obj.eyeLink.fixationTime;
							fprintf('===>>> FIXATION TIME: %g\n',obj.eyeLink.fixationTime)
							tS.keyHold = tS.keyTicks + fInc;
						end
					case 'v'
						if tS.keyTicks > tS.keyHold
							obj.eyeLink.fixationTime = obj.eyeLink.fixationTime + 0.1;
							tS.firstFixTime = obj.eyeLink.fixationTime;
							fprintf('===>>> FIXATION TIME: %g\n',obj.eyeLink.fixationTime)
							tS.keyHold = tS.keyTicks + fInc;
						end
					case 'b'
						if tS.keyTicks > tS.keyHold
							obj.eyeLink.fixationRadius = obj.eyeLink.fixationRadius - 0.1;
							if obj.eyeLink.fixationRadius < 0.1
								obj.eyeLink.fixationRadius = 0.1;
							end
							tS.firstFixRadius = obj.eyeLink.fixationRadius;
							fprintf('===>>> FIXATION RADIUS: %g\n',obj.eyeLink.fixationRadius)
							tS.keyHold = tS.keyTicks + fInc;
						end
					case 'n'
						if tS.keyTicks > tS.keyHold
							obj.eyeLink.fixationRadius = obj.eyeLink.fixationRadius + 0.1;
							tS.firstFixRadius = obj.eyeLink.fixationRadius;
							fprintf('===>>> FIXATION RADIUS: %g\n',obj.eyeLink.fixationRadius)
							tS.keyHold = tS.keyTicks + fInc;
						end
					case 'p' %pause the display
						if tS.keyTicks > tS.keyHold
							if strcmpi(obj.stateMachine.currentState.name,'pause')
								forceTransition(obj.stateMachine, obj.stateMachine.currentState.next);
								fprintf('===>>> PAUSE OFF!\n');
							else
								forceTransition(obj.stateMachine, 'pause');
								fprintf('===>>> PAUSE ENGAGED! (press [p] to unpause)\n');
								tS.pauseToggle = tS.pauseToggle + 1;
							end 
							tS.keyHold = tS.keyTicks + fInc;
						end
					case 's'
						if tS.keyTicks > tS.keyHold
							ShowCursor;
							tS.keyHold = tS.keyTicks + fInc;
						end
					case 'd'
						if tS.keyTicks > tS.keyHold
							HideCursor;
							tS.keyHold = tS.keyTicks + fInc;
						end
					case '1!'
						if tS.keyTicks > tS.keyHold
							if isfield(tS,'eO') && tS.eO.isOpen == true
								bothEyesOpen(tS.eO)
								Eyelink('Command','binocular_enabled = NO')
								Eyelink('Command','active_eye = LEFT')
							end
							tS.keyHold = tS.keyTicks + fInc;
						end
					case '2@'
						if tS.keyTicks > tS.keyHold
							if isfield(tS,'eO') && tS.eO.isOpen == true
								bothEyesClosed(tS.eO)
								Eyelink('Command','binocular_enabled = NO');
								Eyelink('Command','active_eye = LEFT');
							end
							tS.keyHold = tS.keyTicks + fInc;
						end
					case '3#'
						if tS.keyTicks > tS.keyHold
							if isfield(tS,'eO') && tS.eO.isOpen == true
								leftEyeClosed(tS.eO)
								Eyelink('Command','binocular_enabled = NO');
								Eyelink('Command','active_eye = RIGHT');
							end
							tS.keyHold = tS.keyTicks + fInc;
						end
					case '4$'
						if tS.keyTicks > tS.keyHold
							if isfield(tS,'eO') && tS.eO.isOpen == true
								rightEyeClosed(tS.eO)
								Eyelink('Command','binocular_enabled = NO');
								Eyelink('Command','active_eye = LEFT');
							end		
							tS.keyHold = tS.keyTicks + fInc;
						end
						
				end
			end
%  q		=		quit
%  UP		=		next control table
%  DOWN	=		previous control table
%  LEFT	=		increase value
%  RIGHT	=		decrease value
%  <,		=		previous stimulus set
%  >.		= 		next stimulus set
%  =+		=		Screen center LEFT
%  -_		=		Screen center RIGHT
%  [{		=		Screen Center UP
%  ]}		=		Screen Center DOWN
%  k		=		Increase Prestimulus Time
%  l		=		Decrease Prestimulus Time
%  r		=		1000ms reward
%  m		=		calibrate
%  f		=		flash screen
%  o		=		override mode (causes debug state)
%  z		=		DEC fix init time
%  x		=		INC fix init time
%  c		=		DEC fix time
%  v		=		INC fix time
%  b		=		DEC fix radius
%  n		=		INC fix radius
%  p		=		PAUSE
%  s		=		Show mouse cursor
%  d		=		Hide mouse cursor
%  1		=		Both eyes open
%  2		=		Both eyes closed
%  3		=		Left eye open
%  4		=		Right eye open
		end
		
	end
	
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
		function lobj=loadobj(in)
			if isa(in,'runExperiment')
				lobj = in;
				name = '';
				if isprop(lobj,'fullName')
					name = [name 'NEW:' lobj.fullName];
				end
				fprintf('---> runExperiment loadobj: %s\n',name);
				isObject = true;
				setPaths(lobj);
				rebuild();
				return
			else
				lobj = runExperiment;
				name = '';
				if isprop(lobj,'fullName')
					name = [name 'NEW:' lobj.fullName];
				end
				if isprop(in,'name')
					name = [name '<--OLD:' in.name];
				end
				fprintf('---> runExperiment loadobj %s: Loading legacy structure...\n',name);
				isObject = false;
				lobj.initialise('notask noscreen nostimuli');
				rebuild();
			end
			
			
			function obj = rebuild()
				fprintf('------> ');
				try %#ok<*TRYNC>
					if (isprop(in,'stimuli') || isfield(in,'stimuli')) && isa(in.stimuli,'metaStimulus')
						if ~isObject
							lobj.stimuli = in.stimuli;
							fprintf('metaStimulus object loaded | ');
						else
							fprintf('metaStimulus object present | ');
						end
					elseif isfield(in,'stimulus') || isprop(in,'stimulus')
						if iscell(in.stimulus) && isa(in.stimulus{1},'baseStimulus')
							lobj.stimuli = metaStimulus();
							lobj.stimuli.stimuli = in.stimulus;
							fprintf('Legacy Stimuli | ');
						elseif isa(in.stimulus,'metaStimulus')
							obj.stimuli = in.stimulus;
							fprintf('Stimuli (old field) = metaStimulus object | ');
						else
							fprintf('NO STIMULI!!! | ');
						end
					end
					if isfield(in.paths,'stateInfoFile') 
						if exist(in.paths.stateInfoFile,'file')
							if ~isObject; lobj.paths.stateInfoFile = in.paths.stateInfoFile;end
							fprintf('stateInfoFile assigned');
						else
							tp = in.paths.stateInfoFile;
							tp = regexprep(tp,'(^/\w+/\w+)',lobj.paths.home);
							if exist(tp,'file')
								lobj.paths.stateInfoFile = tp;
								fprintf('stateInfoFile rebuilt');
							end
						end
					elseif isprop(in,'stateInfoFile') || isfield(in,'stateInfoFile')
						if exist(in.stateInfoFile,'file')
							lobj.paths.stateInfoFile = in.stateInfoFile;
							fprintf('stateInfoFile assigned');
						end
					end
					if isa(in.task,'stimulusSequence') && ~isObject
						lobj.task = in.task;
						%lobj.previousInfo.task = in.task;
						fprintf(' | loaded stimulusSequence');
					elseif isa(lobj.task,'stimulusSequence')
						lobj.previousInfo.task = in.task;
						fprintf(' | inherited stimulusSequence');
					else
						lobj.task = stimulusSequence();
						fprintf(' | new stimulusSequence');
					end
					if ~isObject && isfield(in,'verbose')
						lobj.verbose = in.verbose;
					end
					if ~isObject && isfield(in,'debug')
						lobj.debug = in.debug;
					end
					if ~isObject && isfield(in,'useLabJack')
						lobj.useLabJackReward = in.useLabJack;
					end
				end
				try
					if ~isa(in.screen,'screenManager') %this is an old object, pre screenManager
						lobj.screen = screenManager();
						lobj.screen.distance = in.distance;
						lobj.screen.pixelsPerCm = in.pixelsPerCm;
						lobj.screen.backgroundColour = in.backgroundColour;
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
				end
				fprintf('\n');
			end
		end
		
	end
	
end

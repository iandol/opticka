% ========================================================================
%> @brief runExperiment is the main Experiment manager; Inherits from Handle
%>
%>RUNEXPERIMENT The main class which accepts a task and stimulus object
%>and runs the stimuli based on the task object passed. The class
%>controls the fundamental configuration of the screen (calibration, size
%>etc. via screenManager), and manages communication to the DAQ system using TTL pulses out
%>and communication over a UDP client<->server socket (via dataConnection).
%>
%>  Stimulus must be a stimulus class, i.e. gratingStimulus and friends,
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
		%> use dataPixx for digital I/O
		useDataPixx = false
		%> use LabJack for digital I/O
		useLabJack = false
		%> use eyelink?
		useEyeLink = false
		%> key manager 
		keyManager 
		%> this lets the opticka UI leave commands to runExperiment
		uiCommand = ''
		%> do we flip or not?
		doFlip = true
		%> log all frame times, gets slow for > 1e6 frames
		logFrames = true
		%> enable debugging? (poorer temporal fidelity)
		debug = false
		%> shows the info text and position grid during stimulus presentation
		visualDebug = false
		%> flip as fast as possible?
		benchmark = false
		%> verbose logging?
		verbose = false
		%> strobed word value
		strobeValue = []
		%> send strobe on next flip?
		sendStrobe = false
	end
	
	properties (Hidden = true)
		%> structure for screenManager on initialisation and info from opticka
		screenSettings = struct()
		%> our old stimulus structure used to be a simple cell, now use
		%> stimuli
		stimulus
		%> used to select single stimulus in training mode
		stimList = []
		%> which stimulus is selected?
		thisStim = []
		%> file to define the stateMachine state info
		stateInfoFile = ''
	end
	
	properties (SetAccess = private, GetAccess = public)
		%> state machine control cell array
		stateInfo = {}
		%> general computer info
		computer
		%> PTB info
		ptb
		%> gamma tables and the like
		screenVals
		%> log times during display
		runLog
		%> training log
		taskLog
		%> training log
		trainingLog
		%> behavioural log
		behaviouralRecord
		%> info on the current run
		currentInfo
		%> previous info populated during load of a saved object
		previousInfo = struct()
		%> LabJack object
		lJack
		%> stateMachine
		stateMachine
		%> eyelink manager object
		eyeLink
		%> data pixx control
		dPixx
		%> save prefix generated from clock time
		savePrefix
	end
	
	properties (SetAccess = private, GetAccess = private)
		lastXPosition = 0
		lastYPosition = 0
		lastSize = 1
		lastIndex = 0
		%> properties allowed to be modified during construction
		allowedProperties='stimuli|task|screen|visualDebug|useLabJack|useDataPixx|logFrames|debug|verbose|screenSettings|benchmark'
	end
	
	events
		runInfo
		abortRun
		endRun
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
		%> @param obj required class object
		% ===================================================================
		function run(obj)
			global lJ
			initialiseSaveFile(obj)
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
			
			%initialise runLog for this run
			obj.previousInfo.runLog = obj.runLog;
			obj.runLog = timeLogger();
			tL = obj.runLog;
			
			%make a handle to the screenManager
			s = obj.screen;
			%if s.windowed(1)==0 && obj.debug == false;HideCursor;end
			
			%-------Set up Digital I/O for this run...
			%obj.serialP=sendSerial(struct('name',obj.serialPortName,'openNow',1,'verbosity',obj.verbose));
			%obj.serialP.setDTR(0);
			if obj.useDataPixx
				if isa(obj.dPixx,'dPixxManager')
					open(obj.dPixx)
					io = obj.dPixx;
				else
					obj.dPixx = dPixxManager('name','runinstance');
					open(obj.dPixx)
					io = obj.dPixx;
					obj.useLabJack = false;
				end
				if obj.useEyeLink
					obj.lJack = labJack('name','runinstance','readResponse', false,'verbose',obj.verbose);
				end
			elseif obj.useLabJack 
				obj.lJack = labJack('name','runinstance','readResponse', false,'verbose',obj.verbose);
				io = obj.lJack;
			else
				obj.lJack = labJack('verbose',false,'openNow',0,'name','null','silentMode',1);
				io = obj.lJack;
			end
			lJ = obj.lJack;
			
			%-----------------------------------------------------------
			
			%-----------------------------------------------------------
			try%======This is our main TRY CATCH experiment display loop
			%-----------------------------------------------------------	
				obj.screenVals = s.open(obj.debug,obj.runLog);
				
				%the metastimulus wraps our stimulus cell array
				obj.stimuli.screen = s;
				obj.stimuli.verbose = obj.verbose;
				
				if obj.useDataPixx
					io.sendTTL(7); %we are using dataPixx bit 7 > plexon evt23 to toggle start/stop
				elseif obj.useLabJack
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
				
				obj.initialiseTask; %set up our task structure 
				
				setup(obj.stimuli);
				
				obj.salutation('Initial variable setup predisplay...')
				obj.updateVars(1,1); %set the variables for the very first run;
				
				KbReleaseWait; %make sure keyboard keys are all released
				
				%bump our priority to maximum allowed
				Priority(MaxPriority(s.win));
				
				%--------------this is RSTART (unpauses Plexon)
				if obj.useDataPixx 
					io.rstart();
				elseif obj.useLabJack
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
				vbl = 0;
				for i = 1:s.screenVals.fps
					draw(obj.stimuli);
					s.drawBackground;
					s.drawScreenCenter;
					if s.photoDiode == true;s.drawPhotoDiodeSquare([0 0 0 1]);end
					Screen('DrawingFinished', s.win);
					vbl = Screen('Flip', s.win, vbl+0.001);
				end
				if obj.logFrames == true
					tL.screenLog.stimTime(1) = 1;
				end
				obj.salutation('TASK Starting...')
				tL.vbl(1) = vbl;
				tL.startTime = tL.vbl(1);
				
				%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
				%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
				% Our main display loop
				%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
				%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
				while obj.task.thisBlock <= obj.task.nBlocks
					if obj.task.isBlank == true
						if s.photoDiode == true
							s.drawPhotoDiodeSquare([0 0 0 1]);
						end
					else
						if ~isempty(s.backgroundColour)
							s.drawBackground;
						end
						
						draw(obj.stimuli);
						
						if s.photoDiode == true
							s.drawPhotoDiodeSquare([1 1 1 1]);
						end
					end
					if s.visualDebug == true
						s.drawGrid;
						obj.infoText;
					end
					
					if obj.useEyeLink;drawEyePosition(obj.eyeLink);end
					
					Screen('DrawingFinished', s.win); % Tell PTB that no further drawing commands will follow before Screen('Flip')
					
					[~, ~, buttons]=GetMouse(s.screen);
					if buttons(2)==1;notify(obj,'abortRun');break;end; %break on any mouse click, needs to change
					if strcmpi(obj.uiCommand,'stop');break;end
					%if KbCheck;notify(obj,'abortRun');break;end;
					
					%check eye position
					if obj.useEyeLink; getSample(obj.eyeLink); end
					
					obj.updateTask(); %update our task structure
					
					if obj.useDataPixx && obj.sendStrobe
						io.triggerStrobe(); %send our word; datapixx syncs to next vertical trace
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
					%==================================================%
					if obj.useLabJack && obj.sendStrobe
						obj.lJack.strobeWord; %send our word out to the LabJack
						obj.sendStrobe = false;
					end
					
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
					
					obj.task.tick=obj.task.tick+1;
					
				end
				%=================================================Finished display loop
				
				s.drawBackground;
				vbl=Screen('Flip', s.win);
				tL.screenLog.afterDisplay=vbl;
				if obj.useDataPixx
					io.rstop();
				else
					io.setDIO([0,0,0],[1,0,0]); %this is RSTOP, pausing the omniplex
				end
				notify(obj,'endRun');
				
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
				
				if obj.useDataPixx
					io.sendTTL(7); %we are using dataPixx bit 7 > plexon evt23 to toggle start/stop
					close(io);
				else
					obj.lJack.setDIO([2,0,0]);WaitSecs(0.05);obj.lJack.setDIO([0,0,0]); %we stop recording mode completely
					obj.lJack.close;
					obj.lJack=[];
				end
				
				tL.calculateMisses;
				if tL.nMissed > 0
					fprintf('\n!!!>>> >>> >>> There were %i MISSED FRAMES <<< <<< <<<!!!\n',tL.nMissed);
				end
				
				s.playMovie();
				
			catch ME
				if obj.useEyeLink
					close(obj.eyeLink);
					obj.eyeLink = [];
				end
				if isa(obj.dPixx,'dPixxManager') && obj.dPixx.isOpen
					close(obj.dPixx)
				end
				if ~isempty(obj.lJack) && isa(obj.lJack,'labJack')
					obj.lJack.setDIO([0,0,0]);
					obj.lJack.close;
					obj.lJack=[];
				end
				
				s.resetScreenGamma();
				
				s.finaliseMovie(true);
				
				s.close();

				rethrow(ME)
				
			end
			
			if obj.verbose==1
				tL.printRunLog;
			end
		end
	
		% ===================================================================
		%> @brief runTask runs a state machine driven task
		%>
		%> @param obj required class object
		% ===================================================================
		function runTask(obj)
			global lJ %eyelink calibration needs access to labjack for reward
			if isempty(regexpi(obj.comment, '^Protocol','once'))
				obj.comment = '';
			end
			
			initialiseSaveFile(obj)
			obj.name = obj.savePrefix;
			if isempty(obj.screen) || isempty(obj.task)
				obj.initialise;
			end
			if obj.screen.isPTB == false
				errordlg('There is no working PTB available!')
				error('There is no working PTB available!')
			end
			
			%initialise runLog for this run
			obj.trainingLog = timeLogger;
			tL = obj.trainingLog; %short handle to log
			
			obj.behaviouralRecord = behaviouralRecord('name',['Fix' obj.savePrefix]); %#ok<*CPROP>
			bR = obj.behaviouralRecord;
			
			%a throwaway structure to hold various parameters
			tS = struct();
			tS.useTask = false;
			tS.checkKeysDuringStimulus = true;
			tS.recordEyePosition = false;
			tS.askForComments = false;
			tS.saveData = true;
	
			%make a short handle to the screenManager
			s = obj.screen; 
			obj.stimuli.screen = [];
			
			%initialise task
			t = obj.task;
			initialiseTask(t);
			
			%-------Set up Digital I/O for this run...
			if isa(obj.dPixx,'dPixxManager')
				io = obj.dPixx; io.name = ['Fix' obj.savePrefix];
			else
				obj.dPixx = dPixxManager('verbose',obj.verbose,'name',['Fix' obj.savePrefix]);
				io = obj.dPixx;
			end
			
			if obj.useDataPixx
				io.silentMode = false;
				io.verbose = obj.verbose;
				io.name = 'runinstance';
				open(io);
			else
				io.silentMode = true;
				io.verbose = false;
				io.name = 'silentruninstance';
				open(io);
			end
			obj.lJack = labJack('name',['Fix' obj.savePrefix],'readResponse', false,'verbose',obj.verbose);
			lJ = obj.lJack;
			
			%-----------------------------------------------------------
			try%======This is our main TRY CATCH experiment display loop
			%-----------------------------------------------------------
				%open the PTB screen
				obj.screenVals = s.open(obj.debug,tL);
				
				obj.stimuli.screen = s;
				obj.stimuli.verbose = obj.verbose;
				setup(obj.stimuli); %run setup() for each stimulus
				
				% open the eyelink interface
				obj.useEyeLink = true;
				if obj.useEyeLink
					obj.eyeLink = eyelinkManager();
					eL = obj.eyeLink;
					eL.saveFile = [obj.paths.savedData filesep obj.savePrefix 'FIX.edf'];
				end
				
				obj.stateMachine = stateMachine('verbose',obj.verbose,'realTime',true,'name',['Fix' obj.savePrefix]); 
				sM = obj.stateMachine;
				sM.timeDelta = obj.screenVals.ifi; %tell it the spcreen IFI
				if isempty(obj.paths.stateInfoFile)
					errordlg('Please specify a valid State Machine file...')
				elseif ischar(obj.paths.stateInfoFile)
					cd(fileparts(obj.paths.stateInfoFile))
					obj.paths.stateInfoFile = regexprep(obj.paths.stateInfoFile,'\s+','\\ ');
					run(obj.paths.stateInfoFile)
					obj.stateInfo = stateInfoTmp;
					addStates(sM, obj.stateInfo);
				end
				
				if tS.askForComments
					comment = inputdlg({'CHECK: ARM PLEXON!!! Initial Comment for this Run?'},['Run Comment for ' obj.name]);
					comment = comment{1};
					obj.comment = [obj.name ':' comment];
					bR.comment = obj.comment;
					eL.comment = obj.comment;
					sM.comment = obj.comment;
					io.comment = obj.comment;
					tL.comment = obj.comment;
					tS.comment = obj.comment;
				end
				
				KbReleaseWait; %make sure keyboard keys are all released
				ListenChar(2); %capture keystrokes
				
				% set up the eyelink interface
				if obj.useEyeLink
					initialise(eL, s);
					setup(eL);
				end
				
				createPlot(bR, eL);
				
				if obj.useDataPixx 
					rstop(io); %make sure this is set low first
					sendTTL(io, 7); %we are using dataPixx bit 7 > plexon evt23 to toggle start/stop
					WaitSecs(0.1);
				end
				
				t.tick = 1;
				t.switched = 1;
				t.totalRuns = 1;
				if tS.useTask == true
					updateVariables(obj, t.totalRuns, true, false); % set to first variable
					updateFixationTarget(obj, tS.useTask);
				end
				tS.stopTraining = false; %break while loop
				tS.keyHold = 1; %a small loop to stop overeager key presses
				tS.totalTicks = 1; % a tick counter
				tS.pauseToggle = 1; %toggle pause/unpause
				tS.eyePos = []; %locally record eye position
				
				%profile clear; profile on;
				
				HideCursor;
				warning('off'); %#ok<*WNOFF>
				%check initial eye position
				if obj.useEyeLink; getSample(eL); end
				
				%if obj.useDataPixx; rstart(io); end
				
				tL.screenLog.beforeDisplay = GetSecs;
				Priority(MaxPriority(s.win)); %bump our priority to maximum allowed
				vbl = Screen('Flip', s.win);
				tL.vbl(1) = vbl;
				tL.startTime = vbl;
				
				start(sM); %ignite the stateMachine!
				
				%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
				%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
				% Our main display loop
				%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
				%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
				while tS.stopTraining == false
					
					%------run the stateMachine one tick forward
					update(sM);
					
					%------check eye position
					if obj.useEyeLink; 
						getSample(eL); 
						if tS.recordEyePosition == true
							if strcmpi(sM.currentName,'stimulus')
								uuid = ['E' sM.currentUUID];
								if isfield(tS.eyePos,uuid)
									tS.eyePos.(uuid).x(end+1) = eL.x;
									tS.eyePos.(uuid).y(end+1) = eL.y;
								else
									tS.eyePos.(uuid).x = eL.x;
									tS.eyePos.(uuid).y = eL.y;
								end
							elseif strcmpi(sM.currentName,'fixate')
								uuid = ['F' sM.currentUUID];
								if isfield(tS.eyePos,uuid)
									tS.eyePos.(uuid).x(end+1) = eL.x;
									tS.eyePos.(uuid).y(end+1) = eL.y;
								else
									tS.eyePos.(uuid).x = eL.x;
									tS.eyePos.(uuid).y = eL.y;
								end
							elseif strcmpi(sM.currentName,'correct')
								uuid = ['CC' sM.currentUUID];
								tS.eyePos.(uuid).x = 1;
								tS.eyePos.(uuid).y = 1;
							end
						end
					end
					
					%------Check keyboard for commands
					if ~strcmpi(sM.currentName,'calibrate') || (~strcmpi(sM.currentName,'stimulus') || tS.checkKeysDuringStimulus == true)
						tS = obj.checkFixationKeys(tS);
					end
					
					%------Log stim / no stim condition to log
					if strcmpi(obj.stateMachine.currentName,'stimulus')
						tL.stimTime(tS.totalTicks)=1;
					else
						tL.stimTime(tS.totalTicks)=0;
					end
					
					%------Tell DataPixx to send strobe on next screen flip
					if obj.useDataPixx && obj.sendStrobe						
						triggerStrobe(io); %send our word; datapixx syncs to next vertical trace
						obj.sendStrobe = false;
					end
					
					%======= FLIP: Show it at correct retrace: ========%
					if obj.doFlip
						nextvbl = tL.vbl(end) + obj.screenVals.halfisi;
						if obj.logFrames == true
							[tL.vbl(tS.totalTicks),tL.show(tS.totalTicks),tL.flip(tS.totalTicks),tL.miss(tS.totalTicks)] = Screen('Flip', s.win, nextvbl);
						elseif obj.benchmark == true
							tL.vbl = Screen('Flip', s.win, 0, 2, 2);
						else
							tL.vbl = Screen('Flip', s.win, nextvbl);
						end
					end
					%==================================================%
					
					tS.totalTicks = tS.totalTicks + 1;
					
				end
				drawBackground(s);
				Screen('Flip', s.win);
				Priority(0);
				ListenChar(0);
				obj.salutation(sprintf('Total ticks: %g | stateMachine ticks: %g', tS.totalTicks, sM.totalTicks));
				
				if obj.useDataPixx
					rstop(io); %pause plexon
					WaitSecs(0.1)
					sendTTL(io, 7); % we are using dataPixx bit 7 > plexon evt23 to toggle start/stop
					close(io);
				end
				
				%profile off; profile report; profile clear
				ShowCursor;
				warning('on'); %#ok<WNON>
				
				if tS.askForComments
					comment = inputdlg('Final Comment for this Run?','Run Comment');
					comment = comment{1};
					obj.comment = [obj.comment ' | Final Comment: ' comment];
					bR.comment = obj.comment;
					eL.comment = obj.comment;
					sM.comment = obj.comment;
					io.comment = obj.comment;
					tL.comment = obj.comment;
					tS.comment = obj.comment;
				end
				
				close(s);
				close(eL);
				obj.eyeLink = [];
				close(lJ);
				obj.lJack=[];
				if tS.saveData
					assignin('base', 'bR', bR)
					assignin('base', 'tL', tL)
					assignin('base', 'tS', tS)
					assignin('base', 'sM', sM)
					save([obj.paths.savedData filesep 'TrainLog-' obj.savePrefix '.mat'],'obj','bR','tL','tS','sM')
				end
				clear tL s tS bR lJ eL io sM			
			catch ME
				if obj.useDataPixx
					rstop(io); %pause plexon
					close(io); %close io
				end
				%profile off; profile clear
				warning('on') %#ok<WNON>
				Priority(0);
				ListenChar(0);
				ShowCursor;
				close(s);
				close(obj.eyeLink);
				obj.eyeLink = [];
				obj.behaviouralRecord = [];
				obj.lJack.close;
				obj.lJack=[];
				clear tL s tS bR lJ eL io sM
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
			
			if obj.useDataPixx == true
				obj.useLabJack = false;
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
			
			if isa(obj.runLog,'timeLogger')
				obj.runLog.screenLog.prepTime=obj.runLog.timer()-obj.runLog.screenLog.construct;
			end
			
		end
		
		% ===================================================================
		%> @brief getrunLog Prints out the frame time plots from a run
		%>
		%> @param
		% ===================================================================
		function getRunLog(obj)
			if isa(obj.runLog,'timeLogger')
				obj.runLog.printRunLog;
			elseif isa(obj.trainingLog,'timeLogger')
				obj.trainingLog.printRunLog;
			end
		end
		
		% ===================================================================
		%> @brief updates eyelink with stimuli random position
		%>
		%> @param
		% ===================================================================
		function updateFixationTarget(obj, useTask)
			if ~exist('useTask','var');	useTask = false; end
			if useTask == false
				updateFixationValues(obj.eyeLink, obj.stimuli.lastXPosition, obj.stimuli.lastYPosition)
				obj.eyeLink.stimulusPositions(1).x = obj.stimuli.lastXPosition;
				obj.eyeLink.stimulusPositions(1).y = obj.stimuli.lastYPosition;
				obj.eyeLink.stimulusPositions(1).size = 3;
			else
				updateFixationValues(obj.eyeLink, obj.lastXPosition, obj.lastYPosition)
				obj.eyeLink.stimulusPositions(1).x = obj.lastXPosition;
				obj.eyeLink.stimulusPositions(1).y = obj.lastYPosition;
				obj.eyeLink.stimulusPositions(1).size = obj.lastSize;
				%fprintf('LASTX: %g | LASTY: %g\n',obj.lastXPosition,obj.lastYPosition)
			end
		end
		
		% ===================================================================
		%> @brief updates eyelink with stimuli positions
		%>
		%> @param
		% ===================================================================
		function updateStimFixTarget(obj,useTask)
			if ~exist('useTask','var');	useTask = false; end
			if useTask == false
				obj.eyeLink.stimulusPositions(1).x = obj.stimuli.lastXPosition;
				obj.eyeLink.stimulusPositions(1).y = obj.stimuli.lastYPosition;
				obj.eyeLink.stimulusPositions(1).size = 3;
			else
				obj.eyeLink.stimulusPositions(1).x = obj.lastXPosition;
				obj.eyeLink.stimulusPositions(1).y = obj.lastYPosition;
				obj.eyeLink.stimulusPositions(1).size = obj.lastSize;
			end
		end
		
		% ===================================================================
		%> @brief when running allow keyboard override, so we can edit things
		%>
		%> @param
		% ===================================================================
		function keyOverride(obj)
			KbReleaseWait; %make sure keyboard keys are all released
			ListenChar(0); %capture keystrokes
			ShowCursor;
			ii = 0;
			dbstop in clear
			%uiinspect(obj)
			clear ii
			dbclear in clear
			ListenChar(2); %capture keystrokes
			HideCursor;
		end
		
		% ===================================================================
		%> @brief set.verbose
		%>
		%> Let us cascase verbosity to other classes
		% ===================================================================
		function set.verbose(obj,value)
			obj.salutation('Verbose cascaded');
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
			if obj.useDataPixx == true
				prepareStrobe(obj.dPixx, value);			
			elseif isa(obj.lJack,'labJack') && obj.lJack.isOpen == true
				prepareStrobe(obj.lJack, value)
			end
		end
		
		% ===================================================================
		%> @brief set strobe on next flip
		%>
		%> 
		% ===================================================================
		function doStrobe(obj, value)
			if value == true
				obj.sendStrobe = true;
			end
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
			if obj.task.totalRuns < obj.task.nRuns
				obj.task.totalRuns = obj.task.totalRuns + 1;
			else
				obj.currentInfo.stopTraining = true;
			end
		end
		
		% ===================================================================
		%> @brief get task run index
		%>
		%> 
		% ===================================================================
		function trial = getTaskIndex(obj, index)
			if ~exist('index','var') && isprop(obj.task,'totalRuns')
				index = obj.task.totalRuns;	
				trial = obj.task.outIndex(index);
				return
			end
			trial = -1;
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
				updateTaskIndex(obj); %do this before getting index
			end
			if ~exist('index','var') || isempty(index)
				index = obj.task.totalRuns;
			end
			if ~exist('override','var') || isempty(override)
				override = false;
			end
			if obj.useDataPixx == true
				setStrobeValue(obj, obj.task.outIndex(index));
			end
			if (index > obj.lastIndex) || override == true
				if rem(index, obj.task.minBlocks) == 0
					thisBlock = (index / obj.task.minBlocks);
					thisRun = obj.task.minBlocks;
				else
					thisBlock = floor(index / obj.task.minBlocks) + 1;
					thisRun = mod(index, obj.task.minBlocks);
				end
				t = sprintf('Index#%g|Block#%g|Run#%g = ',index,thisBlock,thisRun);
				for i=1:obj.task.nVars
					ix = []; valueList = []; oValueList = []; %#ok<NASGU>
					ix = obj.task.nVar(i).stimulus; %which stimuli
					value=obj.task.outVars{thisBlock,i}(thisRun);
					valueList(1,1:size(ix,2)) = value;
					name=[obj.task.nVar(i).name 'Out']; %which parameter
					if regexpi(name,'xPositionOut','once')
						obj.lastXPosition = value;
					elseif regexpi(name,'yPositionOut','once')
						obj.lastYPosition = value;
					elseif regexpi(name,'sizeOut','once')
						obj.lastSize = value;
					end
					offsetix = obj.task.nVar(i).offsetstimulus;
					offsetvalue = obj.task.nVar(i).offsetvalue;

					if ~isempty(offsetix)
						ix = [ix offsetix];
						ovalueList(1,1:size(offsetix,2)) = value+offsetvalue;
						valueList = [valueList ovalueList];
					end

					a = 1;
					for j = ix %loop through our stimuli references for this variable
						t = [t sprintf('S%g: %s = %g ',j,name,valueList(a))];
						obj.stimuli{j}.(name)=valueList(a);
						a = a + 1;
					end
				end
				obj.behaviouralRecord.info = t;
				obj.lastIndex = index;
			end
		end
		
		% ===================================================================
		%> @brief getrunLog Prints out the frame time plots from a run
		%>
		%> @param
		% ===================================================================
		function deleteRunLog(obj)
			if isa(obj.runLog,'timeLogger')
				obj.runLog = [];
			end
			if isa(obj.trainingLog,'timeLogger')
				obj.trainingLog = [];
			end
		end
		
		% ===================================================================
		%> @brief getTimeLog Prints out the frame time plots from a run
		%>
		%> @param
		% ===================================================================
		function restoreRunLog(obj,tLog)
			if isstruct(tLog);obj.runLog = tLog;end
		end
		
		% ===================================================================
		%> @brief refresh the screen values stored in the object
		%>
		%> @param
		% ===================================================================
		function refreshScreen(obj)
			obj.screenVals = obj.screen.prepareScreen();
		end
		

	end%-------------------------END PUBLIC METHODS--------------------------------%
	
	%=======================================================================
	methods (Access = private) %------------------PRIVATE METHODS
	%=======================================================================
		
		% ===================================================================
		%> @brief InitialiseTask
		%> Sets up the task structure with dynamic properties
		%> @param
		% ===================================================================
		function initialiseTask(obj)
			if isempty(obj.task) %we have no task setup, so we generate one.
				obj.task=stimulusSequence;
			end
			%find out how many stimuli there are, wrapped in the obj.stimuli
			%structure
			obj.task.initialiseTask();
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
				valueList(1,1:size(ix,2)) = value;
				name=[obj.task.nVar(i).name 'Out']; %which parameter
				offsetix = obj.task.nVar(i).offsetstimulus;
				offsetvalue = obj.task.nVar(i).offsetvalue;
				
				if ~isempty(offsetix)
					ix = [ix offsetix];
					ovalueList(1,1:size(offsetix,2)) = offsetvalue;
					valueList = [valueList ovalueList];
				end
				
				if obj.task.blankTick > 2 && obj.task.blankTick <= obj.stimuli.n + 2
					%obj.stimuli{j}.(name)=value;
				else
					a = 1;
					for j = ix %loop through our stimuli references for this variable
						if obj.verbose==true;tic;end
						obj.stimuli{j}.(name)=valueList(a);
						if thisBlock == 1 && thisRun == 1 %make sure we update if this is the first run, otherwise the variables may not update properly
							update(obj.stimuli, j);
						end
						if obj.verbose==true;fprintf('=-> updateVars() block/trial %i/%i: Variable:%i %s = %g | Stimulus %g -> %g ms\n',thisBlock,thisRun,i,name,valueList(a),j,toc*1000);end
						a = a + 1;
					end
				end
			end
		end
		
		% ===================================================================
		%> @brief updateTask
		%> Updates the stimulus run state; update the stimulus values for the
		%> current trial and increments the switchTime and switchTick timer
		% ===================================================================
		function updateTask(obj)
			obj.task.timeNow = GetSecs;
			obj.sendStrobe = false;
			if obj.task.tick==1 %first frame
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
			
			if trigger == true
				
				if obj.task.isBlank == false %showing stimulus, need to call animate for each stimulus
					% because the update happens before the flip, but the drawing of the update happens
					% only in the next loop, we have to send the strobe one loop after we set switched
					% to true
					if obj.task.switched == true;
						obj.sendStrobe = true;
					end
					
					%if obj.verbose==true;tic;end
% 					for i = 1:obj.stimuli.n %parfor appears faster here for 6 stimuli at least
% 						obj.stimuli{i}.animate;
% 					end
					animate(obj.stimuli);
					%if obj.verbose==true;fprintf('=-> updateTask() Stimuli animation: %g ms\n',toc*1000);end
					
				else %this is a blank stimulus
					obj.task.blankTick = obj.task.blankTick + 1;
					%this causes the update of the stimuli, which may take more than one refresh, to
					%occur during the second blank flip, thus we don't lose any timing.
					if obj.task.blankTick == 2
						obj.task.doUpdate = true;
					end
					% because the update happens before the flip, but the drawing of the update happens
					% only in the next loop, we have to send the strobe one loop after we set switched
					% to true
					if obj.task.switched == true;
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
						%if obj.verbose==true;fprintf('=-> updateTask() Blank-frame %i: stimulus %i update = %g ms\n',obj.task.blankTick,obj.task.blankTick-2,toc*1000);end
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
					
					if ~mod(obj.task.thisRun,obj.task.minBlocks) %are we within a trial block or not? we add the required time to our switch timer
						obj.task.switchTime=obj.task.switchTime+obj.task.ibTime;
						obj.task.switchTick=obj.task.switchTick+(obj.task.ibTime*ceil(obj.screenVals.fps));
					else
						obj.task.switchTime=obj.task.switchTime+obj.task.isTime;
						obj.task.switchTick=obj.task.switchTick+(obj.task.isTime*ceil(obj.screenVals.fps));
					end
					
					setStrobeValue(obj,32767);%get the strobe word to signify stimulus OFF ready
					%obj.logMe('OutaBlank');
					
				else %we have to show the new run on the next flip

					%obj.logMe('IntoTrial');
					if obj.task.thisBlock <= obj.task.nBlocks
						obj.task.switchTime=obj.task.switchTime+obj.task.trialTime; %update our timer
						obj.task.switchTick=obj.task.switchTick+(obj.task.trialTime*round(obj.screenVals.fps)); %update our timer
						obj.task.isBlank = false;
						obj.task.totalRuns = obj.task.totalRuns + 1;
						if ~mod(obj.task.thisRun,obj.task.minBlocks) %are we rolling over into a new trial?
							obj.task.thisBlock=obj.task.thisBlock+1;
							obj.task.thisRun = 1;
						else
							obj.task.thisRun = obj.task.thisRun + 1;
						end
						if obj.task.totalRuns <= length(obj.task.outIndex)
							setStrobeValue(obj,obj.task.outIndex(obj.task.totalRuns)); %get the strobe word ready
						else
							
						end
					else
						obj.task.thisBlock = obj.task.nBlocks + 1;
					end
					%obj.logMe('OutaTrial');
				end
			end
		end
		
		% ===================================================================
		%> @brief infoText - draws text about frame to screen
		%>
		%> @param
		%> @return
		% ===================================================================
		function infoText(obj)
			if obj.logFrames == true && obj.task.tick > 1
				t=sprintf('T: %i | R: %i [%i/%i] | isBlank: %i | Time: %3.3f (%i)',obj.task.thisBlock,...
					obj.task.thisRun,obj.task.totalRuns,obj.task.nRuns,obj.task.isBlank, ...
					(obj.runLog.vbl(obj.task.tick-1)-obj.runLog.startTime),obj.task.tick);
			else
				t=sprintf('T: %i | R: %i [%i/%i] | isBlank: %i | Time: %3.3f (%i)',obj.task.thisBlock,...
					obj.task.thisRun,obj.task.totalRuns,obj.task.nRuns,obj.task.isBlank, ...
					(obj.runLog.vbl-obj.runLog.startTime),obj.task.tick);
			end
			for i=1:obj.task.nVars
				t=[t sprintf(' -- %s = %2.2f',obj.task.nVar(i).name,obj.task.outVars{obj.task.thisBlock,i}(obj.task.thisRun))];
			end
			Screen('DrawText',obj.screen.win,t,50,1,[1 1 1 1],[0 0 0 1]);
		end
		
		% ===================================================================
		%> @brief infoText - draws text about frame to screen
		%>
		%> @param
		%> @return
		% ===================================================================
		function t = infoTextUI(obj)
			t=sprintf('T: %i | R: %i [%i/%i] | isBlank: %i | Time: %3.3f (%i)',obj.task.thisBlock,...
				obj.task.thisRun,obj.task.totalRuns,obj.task.nRuns,obj.task.isBlank, ...
				(obj.runLog.vbl(obj.task.tick)-obj.task.startTime),obj.task.tick);
			for i=1:obj.task.nVars
				t=[t sprintf(' -- %s = %2.2f',obj.task.nVar(i).name,obj.task.outVars{obj.task.thisBlock,i}(obj.task.thisRun))];
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
				fprintf('%s -- B: %i | T: %i [%i] | TT: %i | Tick: %i | Time: %5.8g\n',tag,obj.task.thisBlock,obj.task.thisRun,obj.task.totalRuns,obj.task.isBlank,obj.task.tick,obj.task.timeNow-obj.task.startTime);
			end
		end
		
		% ===================================================================
		%> @brief manage keypresses during fixation loop
		%>
		%> @param args input structure
		% ===================================================================
		function tS = checkFixationKeys(obj,tS)
			%frame increment to stop keys being too sensitive
			fInc = 6;
			%now lets check whether any keyboard commands are pressed...
			[keyIsDown, ~, keyCode] = KbCheck(-1);
			if keyIsDown == 1
				rchar = KbName(keyCode);
				if iscell(rchar);rchar=rchar{1};end
				switch rchar
					case 'q' %quit
						tS.stopTraining = true;
					case {'UpArrow','up'} %give a reward at any time
						if tS.totalTicks > tS.keyHold
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
							tS.keyHold = tS.totalTicks + fInc;
						end
					case {'DownArrow','down'}
						if tS.totalTicks > tS.keyHold
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
							tS.keyHold = tS.totalTicks + fInc;
						end
					
					case {'LeftArrow','left'} %previous variable 1 value
						if tS.totalTicks > tS.keyHold
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
									if strcmpi(var,'size')
										oval = obj.stimuli{stims(i)}.([var 'Out']) / obj.stimuli{stims(i)}.ppd;
									elseif strcmpi(var,'sf')
										oval = obj.stimuli{stims(i)}.getsfOut;
									else
										oval = obj.stimuli{stims(i)}.([var 'Out']);
									end
									val = oval - delta;
									if min(val) < limits(1)
										val(val < limits(1)) = limits(2);
									end
									if length(val) > length(oval)
										val = val(1:length(oval));
									end
									obj.stimuli{stims(i)}.([var 'Out']) = val;
									fprintf('===>>> Stimulus#%g--%s: %g (%g)\n',stims(i),var,val,oval)
								end
							end
							tS.keyHold = tS.totalTicks + fInc;
						end
					case {'RightArrow','right'} %next variable 1 value
						if tS.totalTicks > tS.keyHold
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
									if strcmpi(var,'size')
										oval = obj.stimuli{stims(i)}.([var 'Out']) / obj.stimuli{stims(i)}.ppd;
									elseif strcmpi(var,'sf')
										oval = obj.stimuli{stims(i)}.getsfOut;
									else
										oval = obj.stimuli{stims(i)}.([var 'Out']);
									end
									val = oval + delta;
									if max(val) > limits(2)
										val(val > limits(2)) = limits(1);
									end
									if length(val) > length(oval)
										val = val(1:length(oval));
									end
									obj.stimuli{stims(i)}.([var 'Out']) = val;
									fprintf('===>>> Stimulus#%g--%s: %g (%g)\n',stims(i),var,val,oval)
								end
							end
							tS.keyHold = tS.totalTicks + fInc;
						end
					case ',<'
						if tS.totalTicks > tS.keyHold
							if obj.stimuli.setChoice > 1
								obj.stimuli.setChoice = round(obj.stimuli.setChoice - 1);
								obj.stimuli.showSet();
							end
							fprintf('===>>> Stimulus Set: #%g | Stimuli: %s\n',obj.stimuli.setChoice, num2str(obj.stimuli.stimulusSets{obj.stimuli.setChoice}))
							tS.keyHold = tS.totalTicks + fInc;
						end
					case '.>'
						if tS.totalTicks > tS.keyHold
							if obj.stimuli.setChoice < length(obj.stimuli.stimulusSets)
								obj.stimuli.setChoice = obj.stimuli.setChoice + 1;
								obj.stimuli.showSet();
							end
							fprintf('===>>> Stimulus Set: #%g | Stimuli: %s\n',obj.stimuli.setChoice, num2str(obj.stimuli.stimulusSets{obj.stimuli.setChoice}))
							tS.keyHold = tS.totalTicks + fInc;
						end
					case 'r'
						timedTTL(obj.lJack,0,1000);
					case '=+'
						if tS.totalTicks > tS.keyHold
							obj.screen.screenXOffset = obj.screen.screenXOffset + 1;
							fprintf('===>>> Screen X Center: %g deg / %g pixels\n',obj.screen.screenXOffset,obj.screen.xCenter);
							tS.keyHold = tS.totalTicks + fInc;
						end
					case '-_'
						if tS.totalTicks > tS.keyHold
							obj.screen.screenXOffset = obj.screen.screenXOffset - 1;
							fprintf('===>>> Screen X Center: %g deg / %g pixels\n',obj.screen.screenXOffset,obj.screen.xCenter);
							tS.keyHold = tS.totalTicks + fInc;
						end
					case '[{'
						if tS.totalTicks > tS.keyHold
							obj.screen.screenYOffset = obj.screen.screenYOffset - 1;
							fprintf('===>>> Screen Y Center: %g deg / %g pixels\n',obj.screen.screenYOffset,obj.screen.yCenter);
							tS.keyHold = tS.totalTicks + fInc;
						end
					case ']}'
						if tS.totalTicks > tS.keyHold
							obj.screen.screenYOffset = obj.screen.screenYOffset + 1;
							fprintf('===>>> Screen Y Center: %g deg / %g pixels\n',obj.screen.screenYOffset,obj.screen.yCenter);
							tS.keyHold = tS.totalTicks + fInc;
						end
					case 'k'
						if tS.totalTicks > tS.keyHold
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
							tS.keyHold = tS.totalTicks + fInc;
						end
					case 'l'
						if tS.totalTicks > tS.keyHold
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
							tS.keyHold = tS.totalTicks + fInc;
						end
					case 'm'
						if tS.totalTicks > tS.keyHold
							fprintf('===>>> Calibrate ENGAGED!\n');
							tS.pauseToggle = tS.pauseToggle + 1; %we go to pause after this so toggle this
							tS.keyHold = tS.totalTicks + fInc;
							forceTransition(obj.stateMachine, 'calibrate');	
							return
						end						
					case 'f'
						if tS.totalTicks > tS.keyHold
							fprintf('===>>> Flash ENGAGED!\n');
							tS.pauseToggle = tS.pauseToggle + 1; %we go to pause after this so toggle this
							tS.keyHold = tS.totalTicks + fInc;
							forceTransition(obj.stateMachine, 'flash');
							return
						end						
					case 'o'
						if tS.totalTicks > tS.keyHold
							fprintf('===>>> Override ENGAGED!\n');
							tS.pauseToggle = tS.pauseToggle + 1; %we go to pause after this so toggle this
							tS.keyHold = tS.totalTicks + fInc;
							forceTransition(obj.stateMachine, 'override');
							return
						end	
					case 'g'
						if tS.totalTicks > tS.keyHold
							fprintf('===>>> grid ENGAGED!\n');
							tS.pauseToggle = tS.pauseToggle + 1; %we go to pause after this so toggle this
							tS.keyHold = tS.totalTicks + fInc;
							forceTransition(obj.stateMachine, 'showgrid');
							return
						end		
					case 'z' 
						if tS.totalTicks > tS.keyHold
							obj.eyeLink.fixationInitTime = obj.eyeLink.fixationInitTime - 0.1;
							if obj.eyeLink.fixationInitTime < 0.01
								obj.eyeLink.fixationInitTime = 0.01;
							end
							fprintf('===>>> FIXATION INIT TIME: %g\n',obj.eyeLink.fixationInitTime)
							tS.keyHold = tS.totalTicks + fInc;
						end
					case 'x' 
						if tS.totalTicks > tS.keyHold
							obj.eyeLink.fixationInitTime = obj.eyeLink.fixationInitTime + 0.1;
							fprintf('===>>> FIXATION INIT TIME: %g\n',obj.eyeLink.fixationInitTime)
							tS.keyHold = tS.totalTicks + fInc;
						end
					case 'c' 
						if tS.totalTicks > tS.keyHold
							obj.eyeLink.fixationTime = obj.eyeLink.fixationTime - 0.1;
							if obj.eyeLink.fixationTime < 0.01
								obj.eyeLink.fixationTime = 0.01;
							end
							fprintf('===>>> FIXATION TIME: %g\n',obj.eyeLink.fixationTime)
							tS.keyHold = tS.totalTicks + fInc;
						end
					case 'v'
						if tS.totalTicks > tS.keyHold
							obj.eyeLink.fixationTime = obj.eyeLink.fixationTime + 0.1;
							fprintf('===>>> FIXATION TIME: %g\n',obj.eyeLink.fixationTime)
							tS.keyHold = tS.totalTicks + fInc;
						end
					case 'b'
						if tS.totalTicks > tS.keyHold
							obj.eyeLink.fixationRadius = obj.eyeLink.fixationRadius - 0.1;
							if obj.eyeLink.fixationRadius < 0.1
								obj.eyeLink.fixationRadius = 0.1;
							end
							fprintf('===>>> FIXATION RADIUS: %g\n',obj.eyeLink.fixationRadius)
							tS.keyHold = tS.totalTicks + fInc;
						end
					case 'n'
						if tS.totalTicks > tS.keyHold
							obj.eyeLink.fixationRadius = obj.eyeLink.fixationRadius + 0.1;
							fprintf('===>>> FIXATION RADIUS: %g\n',obj.eyeLink.fixationRadius)
							tS.keyHold = tS.totalTicks + fInc;
						end
					case 'p' %pause the display
						if tS.totalTicks > tS.keyHold
							if rem(tS.pauseToggle,2)==0
								forceTransition(obj.stateMachine, 'pause');
								fprintf('===>>> PAUSE ENGAGED!\n');
								tS.pauseToggle = tS.pauseToggle + 1;
							else
								if isStateName(obj.stateMachine,'fixate')
									forceTransition(obj.stateMachine, 'fixate');
									fprintf('===>>> PAUSE OFF!\n');
								elseif isStateName(obj.stateMachine,'blank')
									forceTransition(obj.stateMachine, 'blank');
									fprintf('===>>> PAUSE OFF!\n');
								else
									forceTransition(obj.stateMachine, 'prestimulus');
									fprintf('===>>> PAUSE OFF!\n');
								end
								tS.pauseToggle = tS.pauseToggle + 1;
							end
							tS.keyHold = tS.totalTicks + fInc;
						end
					case 's'
						if tS.totalTicks > tS.keyHold
							ShowCursor;
							tS.keyHold = tS.totalTicks + fInc;
						end
					case 'd'
						if tS.totalTicks > tS.keyHold
							HideCursor;
							tS.keyHold = tS.totalTicks + fInc;
						end
					case '1!'
						
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
		end
		
	end
	
	%=======================================================================
	methods (Static = true) %------------------STATIC METHODS
	%=======================================================================
	
		function plotEyeLogs(tS)
			ifi = 0.013;
			tS = tS.eyePos;
			fn = fieldnames(tS);
			figure;
			a = 1;
			stdex = [];
			stdey = [];
			early = [];
			for i = 1:length(fn)-1
				if regexpi(fn{i+1},'^CC')
					x = tS.(fn{i}).x;
					y = tS.(fn{i}).y;
					if (max(x) < 16 && min(x) > -16) && (max(y) < 16 && min(y) > -16) && mean(abs(x(1:10))) < 1 && mean(abs(y(1:10))) < 1
						c = rand(1,3);
						subplot(2,2,1)
						hold on
						plot(x, y,'k-o','Color',c,'MarkerSize',5,'MarkerEdgeColor',[0 0 0], 'MarkerFaceColor',c);
						hold off

						subplot(2,2,2)
						t = 0:ifi:(ifi*length(x));
						t = t(1:length(x));
						hold on
						plot(t,abs(x),'k-o','Color',c,'MarkerSize',5,'MarkerEdgeColor',[0 0 0], 'MarkerFaceColor',c);
						plot(t,abs(y),'k-o','Color',c,'MarkerSize',5,'MarkerEdgeColor',[0 0 0], 'MarkerFaceColor',c);
						hold off
						
						subplot(2,2,3)
						hold on
						plot(mean(x(1:10)), mean(y(1:10)),'ko','Color',c,'MarkerSize',5,'MarkerEdgeColor',[0 0 0], 'MarkerFaceColor',c);
						stdex = [stdex std(x(1:10))];
						stdey = [stdey std(y(1:10))];
						hold off
						
						subplot(2,2,4)
						hold on
						plot3(mean(x(1:10)), mean(y(1:10)),a,'ko','Color',c,'MarkerSize',5,'MarkerEdgeColor',[0 0 0], 'MarkerFaceColor',c);
						hold off
						
						if mean(x(14:16)) > 5 || mean(y(14:16)) > 5
							early(a) = 1;
						else
							early(a) = 0;
						end
						
						a = a + 1;
						
					end
				end
			end
			
			subplot(2,2,1)
			grid on
			box on
			axis square
			title('X vs. Y Eye Position in Degrees')
			xlabel('X Degrees')
			ylabel('Y Degrees')
			
			subplot(2,2,2)
			grid on
			box on
			title(sprintf('X and Y Position vs. time | Early = %g / %g', sum(early),length(early)))
			xlabel('Time (s)')
			ylabel('Degrees')
			
			subplot(2,2,3)
			grid on
			box on
			axis square
			title(sprintf('Average X vs. Y Position for first 150ms STDX: %g | STDY: %g',mean(stdex),mean(stdey)))
			xlabel('X Degrees')
			ylabel('Y Degrees')
			
			subplot(2,2,4)
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
				if isprop(in,'fullName')
					name = [name ' <-- OLD:' in.fullName];
				end
				fprintf('---> runExperiment loadobj: %s\n',name);
				isObject = true;
				lobj = rebuild(lobj, in, isObject);
				return
			else
				lobj = runExperiment;
				name = '';
				if isprop(lobj,'fullName')
					name = [name 'NEW:' lobj.fullName];
				end
				fprintf('---> runExperiment loadobj %s: Loading legacy structure...\n',name);
				isObject = false;
				lobj.initialise('notask noscreen nostimuli');
				lobj = rebuild(lobj, in, isObject);
			end
			
			
			function obj = rebuild(obj,in,inObject)
				fprintf('------> ');
				try %#ok<*TRYNC>
					if (isprop(in,'stimuli') || isfield(in,'stimuli')) && isa(in.stimuli,'metaStimulus')
						if ~strcmpi(in.stimuli.uuid,lobj.stimuli.uuid)
							lobj.stimuli = in.stimuli;
							fprintf('Stimuli = metaStimulus object loaded | ');
						else
							fprintf('Stimuli = metaStimulus object present | ');
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
							lobj.paths.stateInfoFile = in.paths.stateInfoFile;
							fprintf('stateInfoFile assigned');
						end
					elseif isprop(in,'stateInfoFile') || isfield(in,'stateInfoFile')
						if exist(in.stateInfoFile,'file')
							lobj.paths.stateInfoFile = in.stateInfoFile;
							fprintf('stateInfoFile assigned');
						end
					end
					if isa(in.task,'stimulusSequence') && ~strcmpi(in.task.uuid,lobj.task.uuid)
						lobj.task = in.task;
						lobj.previousInfo.task = in.task;
						fprintf(' | loaded stimulusSequence');
					elseif isa(lobj.task,'stimulusSequence')
						lobj.previousInfo.task = in.task;
						fprintf(' | inherited stimulusSequence');
					else
						lobj.task = stimulusSequence();
						fprintf(' | new stimulusSequence');
					end
					if inObject == true || isfield('in','verbose')
						lobj.verbose = in.verbose;
					end
					if inObject == true || isfield('in','debug')
						lobj.debug = in.debug;
					end
					if inObject == true || isfield('in','useLabJack')
						lobj.useLabJack = in.useLabJack;
					end
					if inObject == true || isfield('in','runLog')
						lobj.previousInfo.runLog = in.runLog;
					end
				end
				try
					if ~isa(in.screen,'screenManager') %this is an old object, pre screenManager
						lobj.screen = screenManager();
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
					else
						lobj.screen = in.screen;
						in.screen.verbose = false; %no printout
						in.screen = []; %force close any old screenManager instance;
						fprintf(' | inherited screenManager');
					end
				end
				try
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
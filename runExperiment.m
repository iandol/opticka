% ========================================================================
%> @brief runExperiment is the main Experiment manager; Inherits from Handle
%>
%>RUNEXPERIMENT The main class which accepts a task and stimulus object
%>and runs the stimuli based on the task object passed. The class
%>controls the fundamental configuration of the screen (calibration, size
%>etc. via screenManager), and manages communication to the DAQ system using TTL pulses out
%>and communication over a UDP client<->server socket (via dataConnection).
%>  Stimulus must be a stimulus class, i.e. gratingStimulus and friends,
%>  so for example:
%>
%>  myStim{1}=gratingStimulus('mask',1,'sf',1);
%>  myExp=runExperiment('stimulus',myStim);
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
		%> file to define the stateMachine state info
		stateInfoFile = ''
		%> use LabJack for digital output?
		useLabJack = false
		%> this lets the opticka UI leave commands to runExperiment
		uiCommand = ''
		%> log all frame times, gets slow for > 1e6 frames
		logFrames = true
		%> structure to pass to screenManager on initialisation
		screenSettings = struct()
		%> change the parameters for poorer temporal fidelity for debugging
		debug = false
		%> shows the info text and position grid during stimulus presentation
		visualDebug = true
		%> flip as fast as possible?
		benchmark = false
		%> verbose logging?
		verbose = true
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
		trainingLog
		%> info on the current run
		currentInfo
		%> previous info populated during load of a saved object
		previousInfo = struct()
		%> LabJack object
		lJack
		%> stateMachine
		stateMachine
	end
	
	properties (Hidden = true)
		%> used to select single stimulus in training
		stimList = []
		thisStim = []
	end
	
	properties (SetAccess = private, GetAccess = private)
		%> properties allowed to be modified during construction
		allowedProperties='stimuli|task|screen|visualDebug|useLabJack|logFrames|debug|verbose|screenSettings|benchmark'
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
			if nargin == 0; varargin.name = 'metaStimulus'; end
			obj=obj@optickaCore(varargin); %superclass constructor
			obj.paths.whereami = fileparts(which(mfilename));
			if nargin > 0; obj.parseArgs(varargin,obj.allowedProperties); end
		end
		
		% ===================================================================
		%> @brief The main run loop
		%>
		%> @param obj required class object
		% ===================================================================
		function run(obj)
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
			
			%-------Set up serial line and LabJack for this run...
			%obj.serialP=sendSerial(struct('name',obj.serialPortName,'openNow',1,'verbosity',obj.verbose));
			%obj.serialP.setDTR(0);
			if obj.useLabJack == true
				obj.lJack = labJack('verbose',obj.verbose,'openNow',1,'name','runinstance');
			else
				obj.lJack = labJack('verbose',false,'openNow',0,'name','null','silentMode',1);
			end
			
			%-----------------------------------------------------------
			
			%-----------------------------------------------------------
			try%======This is our main TRY CATCH experiment display loop
			%-----------------------------------------------------------	
				obj.screenVals = s.open(obj.debug,obj.runLog);
				
				%the metastimulus wraps our stimulus cell array
				obj.stimuli.screen = s;
				obj.stimuli.verbose = obj.verbose;
				
				%Trigger the omniplex (TTL on FIO1) into paused mode
				obj.lJack.setDIO([2,0,0]);WaitSecs(0.001);obj.lJack.setDIO([0,0,0]);
				
				obj.initialiseTask; %set up our task structure 
				
				setup(obj.stimuli);
				
				obj.salutation('Initial variable setup predisplay...')
				obj.updateVars(1,1); %set the variables for the very first run;
				
				KbReleaseWait; %make sure keyboard keys are all released
				
				%bump our priority to maximum allowed
				Priority(MaxPriority(s.win));
				%--------------this is RSTART (Set HIGH FIO0->Pin 24), unpausing the omniplex
				if obj.useLabJack == true
					obj.lJack.setDIO([1,0,0],[1,0,0])
				end
				
				obj.task.tick = 1;
				obj.task.switched = 1;
				tL.screenLog.beforeDisplay = GetSecs();
				
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
					s.drawFixationPoint;
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
						if s.fixationPoint == true
							s.drawFixationPoint;
						end
					end
					if s.visualDebug == true
						s.drawGrid;
						obj.infoText;
					end
					
					Screen('DrawingFinished', s.win); % Tell PTB that no further drawing commands will follow before Screen('Flip')
					
					[~, ~, buttons]=GetMouse(s.screen);
					if buttons(2)==1;notify(obj,'abortRun');break;end; %break on any mouse click, needs to change
					if strcmp(obj.uiCommand,'stop');break;end
					%if KbCheck;notify(obj,'abortRun');break;end;
					
					obj.updateTask(); %update our task structure
					
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
					if obj.task.strobeThisFrame == true
						obj.lJack.strobeWord; %send our word out to the LabJack
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
				obj.lJack.setDIO([0,0,0],[1,0,0]); %this is RSTOP, pausing the omniplex
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
				
				s.finaliseMovie(false);
				
				s.close();
				
				obj.lJack.setDIO([2,0,0]);WaitSecs(0.05);obj.lJack.setDIO([0,0,0]); %we stop recording mode completely
				obj.lJack.close;
				obj.lJack=[];
				
				tL.calculateMisses;
				if tL.nMissed > 0
					fprintf('\n!!!>>> >>> >>> There were %i MISSED FRAMES <<< <<< <<<!!!\n',tL.nMissed);
				end
				
				s.playMovie();
				
			catch ME
				
				obj.lJack.setDIO([0,0,0]);
				
				s.resetScreenGamma();
				
				s.finaliseMovie(true);
				
				s.close();
				
				%obj.serialP.close;
				obj.lJack.close;
				obj.lJack=[];
				rethrow(ME)
				
			end
			
			if obj.verbose==1
				tL.printRunLog;
			end
		end
		
		% ===================================================================
		%> @brief runTrainingSession runs a simple keyboard driven training
		%> session
		%>
		%> @param obj required class object
		% ===================================================================
		function runTrainingSession(obj)
			if isempty(obj.screen) || isempty(obj.task)
				obj.initialise;
			end
			if obj.screen.isPTB == false
				errordlg('There is no working PTB available!')
				error('There is no working PTB available!')
			end
			
			topsDataLog.flushAllData();
			%initialise runLog for this run
			obj.trainingLog = timeLogger;
			tL = obj.trainingLog; %short handle to log
			
			%a throwaway structure to hold various parameters
			tS = struct();
	
			%make a short handle to the screenManager
			s = obj.screen;
			
			% open our labJack if present
			obj.lJack = labJack('name','training','verbose',obj.verbose);
			
			%-----------------------------------------------------------
			try%======This is our main TRY CATCH experiment display loop
			%-----------------------------------------------------------
				%open the PTB screen
				obj.screenVals = s.open(obj.debug,tL);
				
				obj.stimuli.screen = s;
				obj.stimuli.verbose = obj.verbose;
				setup(obj.stimuli); %run setup() for each stimulus
				
				obj.stateMachine = stateMachine('verbose',true); %#ok<*CPROP>
				obj.stateMachine.timeDelta = obj.screenVals.ifi; %tell it the screen IFI
				if isempty(obj.stateInfoFile)
					
					blankFcn = {{@drawBackground, obj.screen};{@drawFixationPoint, obj.screen}};
					stimFcn = {@draw, obj.stimuli};
					stimEntry = {@update, obj.stimuli};
					correctFcn = {{@draw, obj.stimuli}; {@drawGreenSpot, obj.screen}};
					incorrectFcn = {{@drawBackground, obj.screen}; {@drawRedSpot, obj.screen}};
					
					obj.stateInfo = { ...
						'name'			'next'			'time'  'entryFcn'	'withinFcn'		'exitFcn'; ...
						'prestimulus'	'stimulus'		2		[]			blankFcn		[]; ...
						'stimulus'		'incorrect'		3		stimEntry	stimFcn			[]; ...
						'incorrect'		'prestimulus'	0.75	[]			incorrectFcn	[]; ...
						'correct'		'prestimulus'	1.5		stimEntry	correctFcn		[]; ...
						'pause'			'prestimulus'	inf		[]			[]				[]; ...
					};
				
					clear blankFcn stimFcn stimEntry correctFcn incorrectFcn
				
				elseif ischar(obj.stateInfoFile)
					cd(fileparts(obj.stateInfoFile))
					run(obj.stateInfoFile)
					obj.stateInfo = stateInfoTmp;
				end
				addStates(obj.stateMachine, obj.stateInfo);
				
				KbReleaseWait; %make sure keyboard keys are all released
				ListenChar(1); %capture keystrokes
				Priority(MaxPriority(s.win)); %bump our priority to maximum allowed
				
				tS.index = 1;
				tS.maxindex = length(obj.task.nVar(1).values);
				if obj.task.nVars > 1
					tS.index2 = 1;
					tS.maxindex2 = length(obj.task.nVar(2).values);
				end
				if ~isempty(obj.task.nVar(1))
					name = [obj.task.nVar(1).name 'Out'];
					value = obj.task.nVar(1).values(tS.index);
					obj.stimuli{1}.(name) = value;
					update(obj.stimuli{1});
				end
				
				tS.stopTraining = false;
				tS.keyHold = 1; %a small loop to stop overeager key presses
				tS.totalTicks = 1; % a tick counter
				tS.pauseToggle = 1;
				
				tL.screenLog.beforeDisplay = GetSecs;
				
				vbl = Screen('Flip', s.win);
				tL.vbl(1) = vbl;
				tL.startTime = vbl;
				
				start(obj.stateMachine); %ignite the stateMachine!
				
				%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
				%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
				% Our main display loop
				%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
				%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
				while tS.stopTraining == false
					
					% run the stateMachine one tick forward
					update(obj.stateMachine);
					
					% do we draw visual debug info too?
					if s.visualDebug == true
						s.drawGrid;
					end
					
					% Tell PTB that no further drawing commands will follow before Screen('Flip')
					Screen('DrawingFinished', s.win); 
					
					%check keyboard for commands
					tS = obj.checkTrainingKeys(tS);
					
					%if the statemachine is in stimulus state, then animate
					%the stimuli
					if strcmpi(obj.stateMachine.currentName,'stimulus')
						animate(obj.stimuli);
					end
					
					%throw away any other keystrokes
					FlushEvents('keyDown');
					
					%lazy flip, timing is not critical here
					Screen('Flip', s.win);
					tS.totalTicks = tS.totalTicks + 1;
					
				end
				obj.salutation(sprintf('Total ticks: %g -- stateMachine ticks: %g',tS.totalTicks,obj.stateMachine.totalTicks));
				Priority(0);
				ListenChar(0)
				ShowCursor;
				s.close();
				topsDataLog.gui();
				obj.lJack.close;
				obj.lJack=[];
				clear tL s tS
				
			catch ME
				Priority(0);
				ListenChar(0)
				ShowCursor;
				s.close();
				obj.lJack.close;
				obj.lJack=[];
				clear tL s tS
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
			
			obj.runLog = timeLogger();
			
			if isempty(regexpi('noscreen',config)) && isempty(obj.screen)
				obj.screen = screenManager(obj.screenSettings);
			end
			
			if isempty(regexpi('notask',config)) && isempty(obj.task)
				obj.task = stimulusSequence();
			end
			
			obj.screen.movieSettings.record = 0;
			obj.screen.movieSettings.size = [400 400];
			obj.screen.movieSettings.quality = 0;
			obj.screen.movieSettings.nFrames = 100;
			obj.screen.movieSettings.type = 1;
			obj.screen.movieSettings.codec = 'rle ';
			
% 			obj.lJack = labJack(struct('name','labJack','openNow',1,'verbosity',1));
% 			obj.lJack.prepareStrobe(0,[0,255,255],1);
% 			obj.lJack.close;
% 			obj.lJack=[];
			
% 			%small fix to stop nested cells causing problems
% 			if iscell(obj.stimuli) && length(obj.stimuli) > 1
% 				while iscell(obj.stimuli) && length(obj.stimuli) == 1
% 					obj.stimuli = obj.stimuli{1};
% 				end
% 			end
			
			if obj.screen.isPTB == true
				obj.computer=Screen('computer');
				obj.ptb=Screen('version');
			end
			
% 			a=zeros(20,1);
% 			for i=1:20
% 				a(i)=GetSecs;
% 			end
% 			obj.runLog.screen.deltaGetSecs=mean(diff(a))*1000; %what overhead does GetSecs have in milliseconds?
% 			WaitSecs(0.01); %preload function
			
			obj.screenVals = obj.screen.screenVals;
			
			obj.runLog.screenLog.prepTime=obj.runLog.timer()-obj.runLog.screenLog.construct;
			
		end
		
		
		% ===================================================================
		%> @brief getrunLog Prints out the frame time plots from a run
		%>
		%> @param
		% ===================================================================
		function getRunLog(obj)
			obj.runLog.printRunLog;
		end
		
		% ===================================================================
		%> @brief getrunLog Prints out the frame time plots from a run
		%>
		%> @param
		% ===================================================================
		function deleteRunLog(obj)
			obj.runLog = [];
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
		
		% ===================================================================
		%> @brief set.verbose
		%>
		%> Let us cascase verbosity to other classes
		% ===================================================================
		function set.verbose(obj,value)
			obj.verbose = value;
			if isa(obj.task,'stimulusSequence') %#ok<*MCSUP>
				obj.task.verbose = value;
			end
			if isa(obj.screen,'screenManager')
				obj.screen.verbose = value;
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
	end
	%-------------------------END PUBLIC METHODS--------------------------------%
	
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
				ix = []; valueList = []; oValueList = [];
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
			obj.task.strobeThisFrame = false;
			if obj.task.tick==1 %first frame
				obj.task.isBlank = false;
				obj.task.startTime = obj.task.timeNow;
				obj.task.switchTime = obj.task.trialTime; %first ever time is for the first trial
				obj.task.switchTick = obj.task.trialTime*ceil(obj.screenVals.fps);
				obj.lJack.prepareStrobe(obj.task.outIndex(obj.task.totalRuns));
				obj.task.strobeThisFrame = true;
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
						obj.task.strobeThisFrame = true;
					end
					
					if obj.verbose==true;tic;end
% 					for i = 1:obj.stimuli.n %parfor appears faster here for 6 stimuli at least
% 						obj.stimuli{i}.animate;
% 					end
					animate(obj.stimuli);
					if obj.verbose==true;fprintf('=-> updateTask() Stimuli animation: %g ms\n',toc*1000);end
					
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
						obj.task.strobeThisFrame = true;
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
						if obj.verbose==true;tic;end
						update(obj.stimuli, obj.task.blankTick-2);
						if obj.verbose==true;fprintf('=-> updateTask() Blank-frame %i: stimulus %i update = %g ms\n',obj.task.blankTick,obj.task.blankTick-2,toc*1000);end
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
					
					obj.lJack.prepareStrobe(2047); %get the strobe word to signify stimulus OFF ready
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
							obj.lJack.prepareStrobe(obj.task.outIndex(obj.task.totalRuns)); %get the strobe word ready
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
		%> @brief manage keypresses during training loop
		%>
		%> @param args input structure
		% ===================================================================
		function tS = checkTrainingKeys(obj,tS)
			%now lets check whether any keyboard commands are pressed...
			[keyIsDown, ~, keyCode] = KbCheck(-1);
			if keyIsDown == 1
				rchar = KbName(keyCode);
				if iscell(rchar);rchar=rchar{1};end
				switch rchar
					case 'q' %quit
						tS.stopTraining = true;
					case {'LeftArrow','left'} %previous variable 1 value
						if strcmpi(obj.stateMachine.currentName,'stimulus') && tS.totalTicks > tS.keyHold
							if tS.index > 1 && tS.maxindex >= tS.index
								tS.index = tS.index - 1;
								name = [obj.task.nVar(1).name 'Out'];
								value = obj.task.nVar(1).values(tS.index);
								obj.stimuli{1}.(name) = value;
								update(obj.stimuli{1});
								tS.keyHold = tS.totalTicks + 5;
							end
						end
					case {'RightArrow','right'} %next variable 1 value
						if strcmpi(obj.stateMachine.currentName,'stimulus') && tS.totalTicks > tS.keyHold
							if tS.index < tS.maxindex 
								tS.index = tS.index + 1;
								name = [obj.task.nVar(1).name 'Out'];
								value = obj.task.nVar(1).values(tS.index);
								obj.stimuli{1}.(name) = value;
								update(obj.stimuli{1});
								tS.keyHold = tS.totalTicks + 5;
							else
								tS.index = tS.maxindex;
							end
						end
					case ',<'
						if strcmpi(obj.stateMachine.currentName,'stimulus') && tS.totalTicks > tS.keyHold
							if obj.task.nVars > 1 && tS.index2 > 1 && tS.maxindex2 >= tS.index2
								tS.index2 = tS.index2 - 1;
								name = [obj.task.nVar(2).name 'Out'];
								value = obj.task.nVar(2).values(tS.index2);
								obj.stimuli{1}.(name) = value;
								update(obj.stimuli{1});
								tS.keyHold = tS.totalTicks + 5;
							end
						end
					case '.>'
						if strcmpi(obj.stateMachine.currentName,'stimulus') && tS.totalTicks > tS.keyHold
							if obj.task.nVars > 1 && tS.index2 < tS.maxindex2
								tS.index2 = tS.index2 + 1;
								name = [obj.task.nVar(2).name 'Out'];
								value = obj.task.nVar(2).values(tS.index2);

								obj.stimuli{1}.(name) = value;
								update(obj.stimuli{1});
								tS.keyHold = tS.totalTicks + 5;
							else
								tS.index = tS.maxindex;
							end
						end
					case '=+'
						if tS.totalTicks > tS.keyHold
							if ~isempty(obj.stimList)
								if obj.thisStim < max(obj.stimList)
									obj.thisStim = obj.thisStim + 1;
									obj.stimuli.choice = obj.thisStim;
								end
							end
							tS.keyHold = tS.totalTicks + 5;
						end
					case '-_'
						if tS.totalTicks > tS.keyHold
							if ~isempty(obj.stimList)
								if obj.thisStim > 1
									obj.thisStim = obj.thisStim - 1;
									obj.stimuli.choice = obj.thisStim;
								end
							end
							tS.keyHold = tS.totalTicks + 5;
						end
					case 'r'
						if tS.totalTicks > tS.keyHold
							newColour = rand(1,3);
							obj.stimuli{1}.colourOut = newColour;
							update(obj.stimuli{1});
							tS.keyHold = tS.totalTicks + 5;
						end
					case {'UpArrow','up'} %give a reward at any time
						obj.lJack.timedTTL(0,100);
					case {'DownArrow','down'}
						obj.lJack.timedTTL(0,500);
					case 'z' % mark trial as correct
						if strcmpi(obj.stateMachine.currentName,'stimulus')
							forceTransition(obj.stateMachine, 'correct1');
						end
					case 'x' % mark trial as incorrect
						if strcmpi(obj.stateMachine.currentName,'stimulus')
							forceTransition(obj.stateMachine, 'correct2');
						end
					case 'c'
						if strcmpi(obj.stateMachine.currentName,'stimulus')
							forceTransition(obj.stateMachine, 'incorrect');
						end
					case 'p' %pause the display
						if tS.totalTicks > tS.keyHold
							if rem(tS.pauseToggle,2)==1
								forceTransition(obj.stateMachine, 'pause');
								tS.pauseToggle = tS.pauseToggle + 1;
							else
								forceTransition(obj.stateMachine, 'prestimulus');
								tS.pauseToggle = tS.pauseToggle + 1;
							end
							tS.keyHold = tS.totalTicks + 5;
						end
					case '1!'
						tS.stopTraining = true;
				end
			end
		end
		
		
	end
	
	%=======================================================================
	methods (Static = true) %------------------STATIC METHODS
	%=======================================================================
		% ===================================================================
		%> @brief loadobj
		%> To be backwards compatible to older saved protocols, we have to parse 
		%> structures / objects specifically during object load
		%> @param in input object/structure
		% ===================================================================
		function lobj=loadobj(in)
			lobj = runExperiment;
			if isa(in,'runExperiment')
				fprintf('---> runExperiment: Loading object...\n');
				isObject = true;
			else
				fprintf('---> runExperiment: Loading legacy structure...\n');
				isObject = false;
			end
			lobj.initialise('notask');
			lobj = rebuild(lobj, in, isObject);
			function obj = rebuild(obj,in,inObject)
				try %#ok<*TRYNC>
					if inObject == true || isfield(in,'stimulus')
						if iscell(in.stimulus)
							lobj.stimuli = metaStimulus();
							lobj.stimuli.stimuli = in.stimulus;
						elseif isa(in.stimulus,'metaStimulus')
							obj.stimuli = in.stimulus;
						elseif isa(in.stimulus,'baseStimulus')
							lobj.stimuli{1} = in.stimulus;
						else
							fprintf('\t---> runExperiment LOAD: no stimuli found...\n');
						end
					else 
						lobj.stimuli = metaStimulus();
						fprintf('\t---> runExperiment LOAD: legacy stimuli not found...\n');
					end
					if isa(in.task,'stimulusSequence')
						lobj.task = in.task;
						lobj.previousInfo.task = in.task;
					else
						lobj.previousInfo.task = in.task;
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
					else
						in.screen.verbose = false; %no printout
						in.screen = []; %force close any old screenManager instance;
					end
				end
				try
					lobj.previousInfo.computer = in.computer;
					lobj.previousInfo.ptb = in.ptb;
					lobj.previousInfo.screenVals = in.screenVals;
					lobj.previousInfo.screenSettings = in.screenSettings;
				end
			end
		end
		
	end
	
end
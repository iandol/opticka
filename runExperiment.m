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
classdef (Sealed) runExperiment < handle
	
	properties
		%> a cell group of stimulus objects, TODO: use a stimulusManager class to
		%> hold these
		stimulus
		%> the stimulusSequence object(s) for the task
		task
		%> screen manager object
		screen
		%> use LabJack for digital output?
		useLabJack = false
		%> this lets the UI leave commands to runExperiment
		uiCommand = ''
		%> log all frame times, gets slow for > 1e6 frames
		logFrames = true
		%> structure to pass to screenManager on initialisation
		screenSettings = struct()
		%>show command window logging and a time log after stimlus presentation
		verbose = false
		%> change the parameters for poorer temporal fidelity for debugging
		debug = false
		%> shows the info text and position grid during stimulus presentation
		visualDebug = true
		%> flip as fast as possible?
		benchmark = false
	end
	
	properties (SetAccess = private, GetAccess = public)
		%> general computer info
		computer
		%> PTB info
		ptb
		%> gamma tables and the like
		screenVals
		%> log times during display
		timeLog
		%> training log
		trainingLog
		%> for heterogenous stimuli, we need a way to index into the stimulus so
		%> we don't waste time doing this on each iteration
		sList
		%> info on the current run
		currentInfo
		%> previous info populated during load of a saved object
		previousInfo = struct()
		%> LabJack object
		lJack
		%> stateMachine
		sm
	end
	
	properties (SetAccess = private, GetAccess = private)
		%> properties allowed to be modified during construction
		allowedProperties='^(stimulus|task|screen|visualDebug|useLabJack|logFrames|debug|verbose|screenSettings|benchmark)$'
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
			if obj.screen.isPTB == false
				errordlg('There is no working PTB available!')
				error('There is no working PTB available!')
			end
			
			%initialise timeLog for this run
			obj.timeLog = timeLogger;
			tL = obj.timeLog;
			
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
				obj.screenVals = s.open(obj.debug,obj.timeLog);
				
				%Trigger the omniplex (TTL on FIO1) into paused mode
				obj.lJack.setDIO([2,0,0]);WaitSecs(0.001);obj.lJack.setDIO([0,0,0]);
				
				obj.initialiseTask; %set up our task structure 
				
				for j=1:obj.sList.n %parfor doesn't seem to help here...
					obj.stimulus{j}.setup(s); %call setup and pass it the screen object
				end
				
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
				tL.screen.beforeDisplay = GetSecs;
				
				% lets draw 1 seconds worth of the stimuli we will be using
				% covered by a blank. this lets us prime the GPU with the sorts
				% of stimuli it will be using and this does appear to minimise
				% some of the frames lost on first presentation for very complex
				% stimuli using 32bit computation buffers...
				obj.salutation('Warming up GPU...')
				vbl = 0;
				for i = 1:s.screenVals.fps
					for j=1:obj.sList.n
						obj.stimulus{j}.draw();
					end
					s.drawBackground;
					s.drawFixationPoint;
					if s.photoDiode == true;s.drawPhotoDiodeSquare([0 0 0 1]);end
					Screen('DrawingFinished', s.win);
					vbl = Screen('Flip', s.win, vbl+0.001);
				end
				if obj.logFrames == true
					tL.screen.stimTime(1) = 1;
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
						for j=1:obj.sList.n
							obj.stimulus{j}.draw();
						end
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
				tL.screen.afterDisplay=vbl;
				obj.lJack.setDIO([0,0,0],[1,0,0]); %this is RSTOP, pausing the omniplex
				notify(obj,'endRun');
				
				tL.screen.deltaDispay=tL.screen.afterDisplay - tL.screen.beforeDisplay;
				tL.screen.deltaUntilDisplay=tL.startTime - tL.screen.beforeDisplay;
				tL.screen.deltaToFirstVBL=tL.vbl(1) - tL.screen.beforeDisplay;
				if obj.benchmark == true
					tL.screen.benchmark = obj.task.tick / (tL.screen.afterDisplay - tL.startTime);
					fprintf('\n---> BENCHMARK FPS = %g\n', tL.screen.benchmark);
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
				tL.printLog;
			end
		end
		
		% ===================================================================
		%> @brief The main run loop
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
			
			t.tick = 1;
			t.display = 1;
			
			%initialise timeLog for this run
			obj.trainingLog = timeLogger;
			tL = obj.trainingLog;
			
			obj.sm = stateMachine();
			
			%make a handle to the screenManager
			s = obj.screen;
			%if s.windowed(1)==0 && obj.debug == false;HideCursor;end
			
			obj.lJack = labJack('name','training','verbose',obj.verbose);
			
			%-----------------------------------------------------------
			try%======This is our main TRY CATCH experiment display loop
			%-----------------------------------------------------------	
				obj.screenVals = s.open(obj.debug,obj.timeLog);
				
				obj.initialiseTask; %set up our task structure 
				
				for j=1:obj.sList.n %parfor doesn't seem to help here...
					obj.stimulus{j}.setup(s); %call setup and pass it the screen object
				end
				
				obj.salutation('Initial variable setup predisplay...')
				
				KbReleaseWait; %make sure keyboard keys are all released
				
				ListenChar(2);
				
				%bump our priority to maximum allowed
				Priority(MaxPriority(s.win));
				
				tL.screen.beforeDisplay = GetSecs;
				
				obj.salutation('TASK Starting...')
				
				index = 1;
				maxindex = length(obj.task.nVar(1).values);
				if ~isempty(obj.task.nVar(1))
					name = [obj.task.nVar(1).name 'Out'];
					value = obj.task.nVar(1).values(index);
					obj.stimulus{1}.(name) = value;
					obj.stimulus{1}.update;
				end
				
				vbl = Screen('Flip', s.win);
				tL.vbl(1) = vbl;
				tL.startTime = vbl;
				
				stopTraining = false;
				
				%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
				%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
				% Our main display loop
				%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
				%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
				while stopTraining == false
	
					if ~isempty(s.backgroundColour)
						s.drawBackground;
					end
					for j=1:obj.sList.n
						obj.stimulus{j}.draw();
					end
					if s.visualDebug == true
						s.drawGrid;
						obj.infoText;
					end
					
					Screen('DrawingFinished', s.win); % Tell PTB that no further drawing commands will follow before Screen('Flip')
					
					for j=1:obj.sList.n
						obj.stimulus{j}.animate();
					end
					
					[keyIsDown, ~, keyCode] = KbCheck;
					if keyIsDown == 1
						rchar = KbName(keyCode);
						if iscell(rchar);rchar=rchar{1};end
						switch rchar
							case 'q' %quit
								stopTraining = true;
							case {'LeftArrow','left'}
								if index > 1 && maxindex >= index
									index = index - 1;
									value = obj.task.nVar(1).values(index);
									obj.stimulus{1}.(name) = value;
									obj.stimulus{1}.update;
								end
							case {'RightArrow','right'}
								if index < maxindex 
									index = index + 1;
									value = obj.task.nVar(1).values(index);
									obj.stimulus{1}.(name) = value;
									obj.stimulus{1}.update;
								else
									index = maxindex;
								end
								
							case {'UpArrow','up'}
								stopTraining = true;
							case {'DownArrow','down'}
								stopTraining = true;
							case ',<'
								stopTraining = true;
							case '.>'
								stopTraining = true;
							case '1!'
								stopTraining = true;
						end
					end
					
					FlushEvents('keyDown');
					
					Screen('Flip', s.win);
					
				end
				
				Priority(0);
				ListenChar(0)
				ShowCursor;
				s.close();
				obj.lJack.close;
				obj.lJack=[];
				
			catch ME
				
				s.close();
				obj.lJack.close;
				obj.lJack=[];
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
			
			obj.timeLog = timeLogger;
			
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
			
			%small fix to stop nested cells causing problems
			if iscell(obj.stimulus) && length(obj.stimulus) > 1
				while iscell(obj.stimulus) && length(obj.stimulus) == 1
					obj.stimulus = obj.stimulus{1};
				end
			end
			
			if obj.screen.isPTB == true
				obj.computer=Screen('computer');
				obj.ptb=Screen('version');
			end
			
			obj.updatesList;
			
% 			a=zeros(20,1);
% 			for i=1:20
% 				a(i)=GetSecs;
% 			end
% 			obj.timeLog.screen.deltaGetSecs=mean(diff(a))*1000; %what overhead does GetSecs have in milliseconds?
% 			WaitSecs(0.01); %preload function
			
			obj.screenVals = obj.screen.screenVals;
			
			obj.timeLog.screen.prepTime=obj.timeLog.timeFunction()-obj.timeLog.screen.construct;
			
		end
		
		
		% ===================================================================
		%> @brief getTimeLog Prints out the frame time plots from a run
		%>
		%> @param
		% ===================================================================
		function getTimeLog(obj)
			obj.timeLog.printLog;
		end
		
		% ===================================================================
		%> @brief getTimeLog Prints out the frame time plots from a run
		%>
		%> @param
		% ===================================================================
		function deleteTimeLog(obj)
			%obj.timeLog = [];
		end
		
		% ===================================================================
		%> @brief getTimeLog Prints out the frame time plots from a run
		%>
		%> @param
		% ===================================================================
		function restoreTimeLog(obj,tLog)
			if isstruct(tLog);obj.timeLog = tLog;end
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
		%> @brief updatesList
		%> Updates the list of stimuli current in the object
		%> @param
		% ===================================================================
		function updatesList(obj)
			if isempty(obj.stimulus) || isstruct(obj.stimulus{1}) %stimuli should be class not structure, reset
				obj.stimulus = [];
			end
			obj.sList.n = 0;
			obj.sList.list = [];
			obj.sList.index = [];
			obj.sList.gN = 0;
			obj.sList.bN = 0;
			obj.sList.dN = 0;
			obj.sList.sN = 0;
			obj.sList.uN = 0;
			if ~isempty(obj.stimulus)
				sn=length(obj.stimulus);
				obj.sList.n=sn;
				for i=1:sn
					obj.sList.index = [obj.sList.index i];
					switch obj.stimulus{i}.family
						case 'grating'
							obj.sList.list = [obj.sList.list 'g'];
							obj.sList.gN = obj.sList.gN + 1;
						case 'bar'
							obj.sList.list = [obj.sList.list 'b'];
							obj.sList.bN = obj.sList.bN + 1;
						case 'dots'
							obj.sList.list = [obj.sList.list 'd'];
							obj.sList.dN = obj.sList.dN + 1;
						case 'spot'
							obj.sList.list = [obj.sList.list 's'];
							obj.sList.sN = obj.sList.sN + 1;
						otherwise
							obj.sList.list = [obj.sList.list 'u'];
							obj.sList.uN = obj.sList.uN + 1;
					end
				end
			end
		end
		
		% ===================================================================
		%> @brief set.verbose
		%>
		%> Let us cascase verbosity to other classes
		% ===================================================================
		function set.verbose(obj,value)
			obj.verbose = value;
			if isa(obj.task,'stimulusSequence')
				obj.task.verbose = value;
			end
			if isa(obj.screen,'screenManager')
				obj.screen.verbose = value;
			end
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
			%find out how many stimuli there are, wrapped in the obj.stimulus
			%structure
			obj.updatesList();
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
				
				if obj.task.blankTick > 2 && obj.task.blankTick <= obj.sList.n + 2
					%obj.stimulus{j}.(name)=value;
				else
					a = 1;
					for j = ix %loop through our stimuli references for this variable
						if obj.verbose==true;tic;end
						obj.stimulus{j}.(name)=valueList(a);
						if thisBlock == 1 && thisRun == 1 %make sure we update if this is the first run, otherwise the variables may not update properly
							obj.stimulus{j}.update;
						end
						if obj.verbose==true;fprintf('->updateVars() block/trial %i/%i: Variable:%i %s = %g | Stimulus %g -> %g ms\n',thisBlock,thisRun,i,name,valueList(a),j,toc*1000);end
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
					
					%if obj.verbose==true;tic;end
					for i = 1:obj.sList.n %parfor appears faster here for 6 stimuli at least
						obj.stimulus{i}.animate;
					end
					%if obj.verbose==true;fprintf('\nStimuli animation: %g ms',toc*1000);end
					
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
					if obj.task.blankTick > 2 && obj.task.blankTick <= obj.sList.n + 2
						if obj.verbose==true;tic;end
						obj.stimulus{obj.task.blankTick-2}.update;
						if obj.verbose==true;fprintf('->updateTask() Blank-frame %i: stimulus %i update = %g ms\n',obj.task.blankTick,obj.task.blankTick-2,toc*1000);end
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
					(obj.timeLog.vbl(obj.task.tick-1)-obj.timeLog.startTime),obj.task.tick);
			else
				t=sprintf('T: %i | R: %i [%i/%i] | isBlank: %i | Time: %3.3f (%i)',obj.task.thisBlock,...
					obj.task.thisRun,obj.task.totalRuns,obj.task.nRuns,obj.task.isBlank, ...
					(obj.timeLog.vbl-obj.timeLog.startTime),obj.task.tick);
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
				(obj.timeLog.vbl(obj.task.tick)-obj.task.startTime),obj.task.tick);
			for i=1:obj.task.nVars
				t=[t sprintf(' -- %s = %2.2f',obj.task.nVar(i).name,obj.task.outVars{obj.task.thisBlock,i}(obj.task.thisRun))];
			end
		end
		
		% ===================================================================
		%> @brief Prints messages dependent on verbosity
		%>
		%> Prints messages dependent on verbosity
		%> @param in the calling function
		%> @param message the message that needs printing to command window
		% ===================================================================
		function salutation(obj,in,message)
			if obj.verbose==true
				if ~exist('in','var')
					in = 'undefined';
				end
				if exist('message','var')
					fprintf(['---> runExperiment: ' message ' | ' in '\n']);
				else
					fprintf(['---> runExperiment: ' in '\n']);
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
				fprintf('%s -- B: %i | T: %i [%i] | TT: %i | Tick: %i | Time: %5.8g\n',tag,obj.task.thisBlock,obj.task.thisRun,obj.task.totalRuns,obj.task.isBlank,obj.task.tick,obj.task.timeNow-obj.task.startTime);
			end
		end
		
		% ===================================================================
		%> @brief Sets properties from a structure, ignores invalid properties
		%>
		%> @param args input structure
		% ===================================================================
		function parseArgs(obj, args, allowedProperties)
			while iscell(args) && length(args) == 1
				args = args{1};
			end
			if iscell(args)
				if mod(length(args),2) == 1 % odd
					args = args(1:end-1); %remove last arg
				end
				odd = logical(mod(1:length(args),2));
				even = logical(abs(odd-1));
				args = cell2struct(args(even),args(odd),2);
			end
			fnames = fieldnames(args); %find our argument names
			for i=1:length(fnames);
				if regexp(fnames{i}, allowedProperties) %only set if allowed property
					obj.salutation(fnames{i},'Configuring setting');
					obj.(fnames{i})=args.(fnames{i}); %we set up the properies from the arguments as a structure
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
				fprintf('---> Loading runExperiment object...\n');
				isObject = true;
			else
				fprintf('---> Loading runExperiment structure...\n');
				isObject = false;
			end
			lobj.initialise('notask');
			lobj = rebuild(lobj, in, isObject);
			function obj = rebuild(obj,in,inObject)
				try %#ok<*TRYNC>
					if inObject == true || isfield(in,'stimulus')
						obj.stimulus = in.stimulus;
					else 
						obj.stimulus = cell(1);
					end
					if isa(in.task,'stimulusSequence')
						obj.task = in.task;
						obj.previousInfo.task = in.task;
					else
						obj.previousInfo.task = in.task;
					end
					if inObject == true || isfield('in','verbose')
						obj.verbose = in.verbose;
					end
					if inObject == true || isfield('in','debug')
						obj.debug = in.debug;
					end
					if inObject == true || isfield('in','useLabJack')
						obj.useLabJack = in.useLabJack;
					end
					if inObject == true || isfield('in','timeLog')
						in.previousInfo.timeLog = in.timeLog;
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
					obj.previousInfo.computer = in.computer;
					obj.previousInfo.ptb = in.ptb;
					obj.previousInfo.screenVals = in.screenVals;
					obj.previousInfo.gammaTable = in.gammaTable;
					obj.previousInfo.screenSettings = in.screenSettings;
				end
			end
		end
		
	end
	
end
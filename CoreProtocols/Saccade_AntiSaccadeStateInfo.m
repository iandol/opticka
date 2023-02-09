% SACCADE / ANTISACCADE state file, this gets loaded via runExperiment
% class, runTask() method. This task uses 3 stimuli: (1) pro-saccade target
% (2) anti-saccade target and (3) fixation cross. The task sequence is set
% up to randomise the X position of (1) ±10° on each trial, and (2) has a
% modifier set as the inverse (if (1) is -10° on a trial then (2) becomes
% +10°). For the pro-saccade task, show (1) and hide (2), fixation window
% set on (1) and an exclusion zone set around (2). In the anti-saccade task
% we show (2) and set the opacity of (1) during training to encourage the
% subject to saccade away from (2) towards (1); the fixation and exclusion
% windows keep the same logic as for the pro-saccade condition.
%
% State files control the logic of a behavioural task, switching between states
% and executing functions on ENTER, WITHIN and on EXIT of states. In addition
% there are TRANSITION function which can test things like eye position to
% conditionally jump to another state. This state control file will usually be
% run in the scope of the calling runExperiment.runTask() method and other
% objects will be available at run time (with easy to use names listed below).
% The following class objects are already loaded by runTask() and available to
% use; each object has methods (functions) useful for running the task:
%
% me		= runExperiment class object
% s			= screenManager class object
% aM		= audioManager class object
% stims		= our list of stimuli (metaStimulus class)
% sM		= State Machine (stateMachine class)
% task		= task sequence (taskSequence class)
% eT		= eyetracker manager
% io		= digital I/O to recording system
% rM		= Reward Manager (LabJack or Arduino TTL trigger to reward system/Magstim)
% bR		= behavioural record plot (on-screen GUI during a task run)
% tS		= structure to hold general variables, will be saved as part of the data
% uF		= user functions - add your own functions to this class

%==================================================================
%--------------------TASK SPECIFIC CONFIG--------------------------
tS.name						= 'saccade-antisaccade'; %==name of this protocol
% update the trial number for incorrect saccades: if true then we call
% updateTask for both correct and incorrect trials, otherwise we only call
% updateTask() for correct responses. 'false' is useful during training.
tS.includeErrors			= false; 
% is this run a 'saccade' or 'anti-saccade' task run?
tS.type						= 'saccade';
if strcmp(tS.type,'saccade')
	% a flag to conditionally set visualisation on the eye tracker interface
	stims{1}.showOnTracker	= true;
	stims{2}.showOnTracker	= false;
	tS.targetAlpha1			= 0.25;
	tS.targetAlpha2			= 0.75;
else
	% a flag to conditionally set visualisation on the eye tracker interface
	stims{1}.showOnTracker	= false;
	stims{2}.showOnTracker	= true;
	% this can be used during training to keep saccade target visible (i.e. in
	% the anti-saccade task the subject must saccade away from the
	% anti-saccade target towards to place where the pro-saccade target is, so
	% starting training keeping the pro-saccade target visible helps the
	% subject understand the task
	tS.targetAlpha1			= 0.15;
	tS.targetAlpha2			= 0.05;
	tS.antitargetAlpha1		= 0.5;
	tS.antitargetAlpha2		= 0.75;
end
disp(['\n===>>> Task ' tS.name ' Type:' tS.type ' <<<===\n'])

%==================================================================
%----------------------General Settings----------------------------
tS.useTask					= true;		%==use taskSequence (randomises stimulus variables)
tS.rewardTime				= 250;		%==TTL time in milliseconds
tS.rewardPin				= 2;		%==Output pin, 2 by default with Arduino.
tS.checkKeysDuringStimulus  = false;	%==allow keyboard control within stimulus state? Slight drop in performance…
tS.recordEyePosition		= false;	%==record local copy of eye position, **in addition** to the eyetracker?
tS.askForComments			= false;	%==UI requestor asks for comments before/after run
tS.saveData					= true;		%==save behavioural and eye movement data?
tS.showBehaviourPlot		= false;	%==open the behaviourPlot figure? Can cause more memory use
tS.nStims					= stims.n;	%==number of stimuli, taken from metaStimulus object
tS.tOut						= 5;		%==if wrong response, how long to time out before next trial
tS.CORRECT					= 1;		%==the code to send eyetracker for correct trials
tS.BREAKFIX					= -1;		%==the code to send eyetracker for break fix trials
tS.INCORRECT				= -5;		%==the code to send eyetracker for incorrect trials

%==================================================================
%----------------Debug logging to command window------------------
% uncomment each line to get specific verbose logging from each of these
% components; you can also set verbose in the opticka GUI to enable all of
% these…
%sM.verbose					= true;		%==print out stateMachine info for debugging
%stims.verbose				= true;		%==print out metaStimulus info for debugging
%io.verbose					= true;		%==print out io commands for debugging
%eT.verbose					= true;		%==print out eyelink commands for debugging
%rM.verbose					= true;		%==print out reward commands for debugging
%task.verbose				= true;		%==print out task info for debugging

%==================================================================
%---------------------------Eyetracker setup-----------------------
% NOTE: the opticka GUI can set eyetracker options too, if you set options
% here they will OVERRIDE the GUI ones; if they are commented then the GUI
% options are used. me.elsettings and me.tobiisettings contain the GUI
% settings you can test if they are empty or not and set them based on
% that...
eT.name				= tS.name;
if me.eyetracker.dummy;	eT.isDummy = true; end %===use dummy or real eyetracker? 
if tS.saveData;		eT.recordData = true; end %===save Eyetracker data?					
if matches(me.eyetracker.device, 'eyelink')
	warning('Note: this protocol file is optimised for the Tobii eyetracker...')
	if isempty(me.eyetracker.esettings)		%==check if GUI settings are empty
		eT.sampleRate				= 250;		%==sampling rate
		eT.calibrationStyle			= 'HV5';	%==calibration style
		eT.calibrationProportion	= [0.4 0.4]; %==the proportion of the screen occupied by the calibration stimuli
		%-----------------------
		% remote calibration enables manual control and selection of each
		% fixation this is useful for a baby or monkey who has not been trained
		% for fixation use 1-9 to show each dot, space to select fix as valid,
		% INS key ON EYELINK KEYBOARD to accept calibration!
		eT.remoteCalibration				= false; 
		%-----------------------
		eT.modify.calibrationtargetcolour	= [1 1 1]; %==calibration target colour
		eT.modify.calibrationtargetsize		= 2;		%==size of calibration target as percentage of screen
		eT.modify.calibrationtargetwidth	= 0.15;	%==width of calibration target's border as percentage of screen
		eT.modify.waitformodereadytime		= 500;
		eT.modify.devicenumber				= -1;		%==-1 = use any attachedkeyboard
		eT.modify.targetbeep				= 1;		%==beep during calibration
	end
elseif matches(me.eyetracker.device, 'tobii')
	if isempty(me.eyetracker.tsettings)	%==check if GUI settings are empty
		eT.model					= 'Tobii Pro Spectrum';
		eT.sampleRate				= 300;
		eT.trackingMode				= 'human';
		eT.calibrationStimulus		= 'animated';
		eT.autoPace					= true;
		%-----------------------
		% remote calibration enables manual control and selection of each
		% fixation this is useful for a baby or monkey who has not been trained
		% for fixation
		eT.manualCalibration		= false;
		%-----------------------
		eT.calPositions				= [ .2 .5; .5 .5; .8 .5];
		eT.valPositions				= [ .5 .5 ];
	end
end
%==================================================================
%-----------------INITIAL Eyetracker Settings----------------------
% These settings define the initial fixation window and set up for the
% eyetracker. They may be modified during the task (i.e. moving the
% fixation window towards a target, enabling an exclusion window to stop
% the subject entering a specific set of display areas etc.)
%
% IMPORTANT: you need to make sure that the global state time is larger
% than the fixation timers specified here. Each state has a global timer,
% so if the state timer is 5 seconds but your fixation timer is 6 seconds,
% then the state will finish before the fixation time was completed!

% initial fixation X position in degrees (0° is screen centre)
tS.fixX						= 0;	
% initial fixation Y position in degrees
tS.fixY						= 0;
% time to search and enter fixation window
tS.firstFixInit				= 3;
% time to maintain fixation within window, can be single value or a range
% to randomise between
tS.firstFixTime				= 0.5;
% circular fixation window radius in degrees
tS.firstFixRadius			= 1;
% do we forbid eye to enter-exit-reenter fixation window?
tS.strict					= true;
% do we add an exclusion zone where subject cannot saccade to...
tS.exclusionZone			= [];
% time to fix on the stimulus
tS.stimulusFixTime			= 0.25;
% time to show both fix and stim
tS.fixstimTime				= 1.5;
% in this task the subject must saccade to the pro-saccade target location.
% These settings define the rules to "accept" the target fixation as
% correct
tS.targetFixInit			= 3; % time to find the target
tS.targetFixTime			= 1; % to to maintain fixation on target 
tS.targetRadius				= 4; %radius to fix within.
% this task will establish an exclusion zone against the anti-saccade
% target for the pro and anti-saccade task. We can change the size of the
% exclusion zone, here set to 5° around the X and Y position of the
% anti-saccade target.
tS.exclusionRadius			= 5; 
% historical log of X and Y position, and exclusion zone
me.lastXPosition			= tS.fixX;
me.lastYPosition			= tS.fixY;
me.lastXExclusion			= [];
me.lastYExclusion			= [];
%Initialise the eyeTracker object with X, Y, FixInitTime, FixTime, Radius, StrictFix
eT.updateFixationValues(tS.fixX, tS.fixY, tS.firstFixInit, tS.firstFixTime, tS.firstFixRadius, tS.strict);
%Ensure we don't start with any exclusion zones set up
eT.resetExclusionZones();

%==================================================================
%----WHICH states assigned as correct or break for online plot?----
%----You need to use regex patterns for the match (doc regexp)-----
bR.correctStateName				= "correct";
bR.breakStateName				= ["breakfix","incorrect"];

%==================================================================
%--------------randomise stimulus variables every trial?-----------
% if you want to have some randomisation of stimuls variables without using
% taskSequence task (i.e. general training tasks), you can uncomment this
% and runExperiment can use this structure to change e.g. X or Y position,
% size, angle see metaStimulus for more details. Remember this will not be
% "Saved" for later use, if you want to do controlled methods of constants
% experiments use taskSequence to define proper randomised and balanced
% variable sets and triggers to send to recording equipment etc...
%
% stims.choice					= [];
% n								= 1;
% in(n).name					= 'xyPosition';
% in(n).values					= [6 6; 6 -6; -6 6; -6 -6; -6 0; 6 0];
% in(n).stimuli					= 1;
% in(n).offset					= [];
% stims.stimulusTable			= in;
stims.choice					= [];
stims.stimulusTable				= [];

%==================================================================
%-------------allows using arrow keys to control variables?-------------
% another option is to enable manual control of a table of variables
% this is useful to probe RF properties or other features while still
% allowing for fixation or other behavioural control.
% Use arrow keys <- -> to control value and up/down to control variable
stims.controlTable			= [];
stims.tableChoice			= 1;

%==================================================================
% this allows us to enable subsets from our stimulus list
% 1 = saccade target | 2 = anti-saccade target | 3 = fixation cross
stims.stimulusSets			= {3, [1 3], [1 2 3], [1 2]};
stims.setChoice				= 1;
hide(stims);

%==================================================================
% N x 2 cell array of regexpi strings, list to skip the current -> next
% state's exit functions; for example skipExitStates =
% {'fixate','incorrect|breakfix'}; means that if the currentstate is
% 'fixate' and the next state is either incorrect OR breakfix, then skip
% the FIXATE exit state. Add multiple rows for skipping multiple state's
% exit states.
sM.skipExitStates			= {'fixate','incorrect|breakfix'};

%==================================================================
% which stimulus in the list is used for a fixation target? For this
% protocol it means the subject must saccade this stimulus (the saccade
% target is #1 in the list) to get the reward. Also which stimulus to set an
% exclusion zone around (where a saccade into this area causes an immediate
% break fixation).
stims.fixationChoice		= 1;
stims.exclusionChoice		= 2;

%===================================================================
%===================================================================
%===================================================================
%------------------State Machine Task Functions---------------------
% Each cell {array} holds a set of anonymous function handles which are
% executed by the state machine to control the experiment. The state
% machine can run sets at entry ['entryFn'], during ['withinFn'], to
% trigger a transition jump to another state ['transitionFn'], and at exit
% ['exitFn'. Remember these {sets} need to access the objects that are
% available within the runExperiment context (see top of file). You can
% also add global variables/objects then use these. The values entered here
% are set on load, if you want up-to-date values then you need to use
% methods/function wrappers to retrieve/set them.
%===================================================================
%===================================================================
%===================================================================

%====================================================PAUSE
%--------------------pause entry
pauseEntry = { 
	@()hide(stims);
	@()drawBackground(s); %blank the subject display
	@()drawTextNow(s,'PAUSED, press [p] to resume...');
	@()disp('PAUSED, press [p] to resume...');
	@()statusMessage(eT,me.name);
	@()trackerClearScreen(eT); % blank the eyetracker screen
	@()trackerDrawText(eT,'PAUSED, press [P] to resume...');
	@()trackerFlip(eT);
	@()trackerMessage(eT,'TRIAL_RESULT -100'); %store message in EDF
	@()stopRecording(eT, true); %stop recording eye position data
	@()needFlip(me, false); % no need to flip the PTB screen
	@()needEyeSample(me,false); % no need to check eye position
};

%--------------------pause exit
pauseExit = {
	@()startRecording(eT, true); %start recording eye position data again
}; 

%====================================================PRE-FIXATION
pfEntry = { 
	@()needFlip(me, true); 
	@()trackerClearScreen(eT); % blank the eyetracker screen
	@()trackerFlip(eT);
};

pfWithin = {
	@()drawBackground(s);
};

pfExit = {
	@()startRecording(eT);
	@()needEyeSample(me,true); % make sure we start measuring eye position
	@()updateFixationValues(eT,tS.fixX,tS.fixY,tS.firstFixInit,tS.firstFixTime,tS.firstFixRadius,tS.strict); %reset fixation window
	@()resetFixationHistory(eT); % reset the recent eye position history
	@()resetExclusionZones(eT); % reset the exclusion zones on eyetracker
	@()getStimulusPositions(stims,true); %make a struct the eT can use for drawing stim positions
};

%====================================================FIXATION
%--------------------fixate entry
fixEntry = { 
	@()trackerMessage(eT,sprintf('TRIALID %i',getTaskIndex(me))); %Eyelink start trial marker
	@()trackerMessage(eT,['UUID ' UUID(sM)]); %add in the uuid of the current state for good measure
	% draw general state to the eyetracker display (eyelink or tobii)
	@()trackerDrawStatus(eT,'Fixating...', stims.stimulusPositions);
	% show stimulus 3 = fixation cross
	@()show(stims, 3);
	@()logRun(me,'INITFIX'); %fprintf current trial info to command window
};

%--------------------fix within
fixWithin = {
	@()draw(stims); %draw stimulus
	@()trackerDrawEyePosition(eT); % for tobii
	@()trackerFlip(eT, 1); % for tobii
};

%--------------------test we are fixated for a certain length of time
initFix = { 
	% this command performs the logic to search and then maintain fixation
	% inside the fixation window. The eyetracker parameters are defined above.
	% If the subject does initiate and then maintain fixation, then 'fixstim'
	% is returned and the state machine will jump to that state,
	% otherwise 'incorrect' is returned and the state machine will jump there. 
	% If neither condition matches, then the state table below
	% defines that after 5 seconds we will switch to the incorrect state.
	@()testSearchHoldFixation(eT,'fixstim','incorrect')
};

%--------------------exit fixation phase
if strcmpi(tS.type,'saccade')
	fixExit = { 
		@()show(stims, [1 3]); 
		@()edit(stims,1,'alphaOut',tS.targetAlpha1);
	};
else
	fixExit = { 
		@()show(stims, [1 2 3]); 
		@()edit(stims,1,'alphaOut',tS.targetAlpha1);
		@()edit(stims,2,'alphaOut',tS.antitargetAlpha1)
	};
end

%====================================================FIX + TARGET STIMULUS
fsEntry = {
	@()updateFixationValues(eT,[],[],[],0.5); %reset the fixation timer for 0.5 secs
	@()logRun(me,'FIX+STIM'); %fprintf current trial info to command window
};

fsWithin = {
	@()draw(stims); %draw stimulus
	@()trackerDrawEyePosition(eT);
	@()trackerFlip(eT, 1);
};

% test we are fixated for a certain length of time, testHoldFixation assumes
% we are already fixated which we are coming from the fixate state...
fsFix = { 
	@()testHoldFixation(eT,'stimulus','incorrect')
};

% exit fixation phase
fsExit = { 
	% use our saccade target stimulus for next fix X and Y, see
	% stims.fixationChoice above
	@()updateFixationTarget(me, tS.useTask, tS.targetFixInit, tS.targetFixTime, tS.targetRadius, tS.strict);
	% use our antisaccade target to define the exclusion zone, see
	% stims.exclusionChoice above
	@()updateExclusionZones(me, tS.useTask, tS.exclusionRadius);
	@()trackerMessage(eT,'END_FIX');
	@()hide(stims, 3);
};
if strcmpi(tS.type,'saccade')
	fsExit = [ fsExit; { @()edit(stims,1,'alphaOut',tS.targetAlpha2) } ];
else
	fsExit = [ fsExit; { @()edit(stims,1,'alphaOut',tS.targetAlpha2); @()edit(stims,2,'alphaOut',tS.antitargetAlpha2) } ];
end

%====================================================TARGET STIMULUS ALONE
% what to run when we enter the stim presentation state
stimEntry = { 
	@()doStrobe(me,true);
	@()logRun(me,'STIMULUS'); %fprintf current trial info to command window
};

% what to run when we are showing stimuli
stimWithin =  { 
	@()draw(stims);
	@()animate(stims); % animate stimuli for subsequent draw
	@()trackerDrawEyePosition(eT);
	@()trackerFlip(eT, 1);
};

% test we are finding the new target (stimulus 1, the saccade target)
targetFix = {
	@()testSearchHoldFixation(eT,'correct','breakfix'); % tests finding and maintaining fixation
};

%as we exit stim presentation state
stimExit = { 
	@()setStrobeValue(me,255); 
	@()doStrobe(me,true);
};

%====================================================DECISION

%if the subject is correct (small reward)
correctEntry = { 
	@()timedTTL(rM, tS.rewardPin, tS.rewardTime); % send a reward TTL
	@()beep(aM,2000); % correct beep
	@()trackerMessage(eT,'END_RT');
	@()trackerMessage(eT,['TRIAL_RESULT ' str2double(tS.CORRECT)]);
	@()trackerDrawStatus(eT,'Correct! :-)', stims.stimulusPositions);
	@()stopRecording(eT); % stop recording in eyelink [tobii ignores this]
	@()setOffline(eT); % set eyelink offline [tobii ignores this]
	@()needEyeSample(me,false); % no need to collect eye data until we start the next trial
	@()hide(stims);
	@()logRun(me,'CORRECT'); %fprintf current trial info
};

%correct stimulus
correctWithin = { 
	@()drawBackground(s); % draw background alone
};

%when we exit the correct state
correctExit = {
	@()updatePlot(bR, me); %update our behavioural plot, must come before updateTask() / updateVariables()
	@()updateTask(me,tS.CORRECT); %make sure our taskSequence is moved to the next trial
	@()updateVariables(me); %randomise our stimuli, and set strobe value too
	@()update(stims); %update the stimuli ready for display
	@()resetExclusionZones(eT); %reset the exclusion zones
	@()checkTaskEnded(me); %check if task is finished
};

%incorrect entry
incEntry = { 
	@()beep(aM,200,0.5,1);
	@()trackerMessage(eT,'END_RT');
	@()trackerMessage(eT,['TRIAL_RESULT ' str2double(tS.INCORRECT)]);
	@()trackerDrawStatus(eT,'Incorrect! :-(', stims.stimulusPositions);
	@()stopRecording(eT); % stop recording in eyelink [tobii ignores this]
	@()setOffline(eT); % set eyelink offline [tobii ignores this]
	@()hide(stims);
	@()needEyeSample(me,false);
	@()logRun(me,'INCORRECT'); %fprintf current trial info
}; 

%our incorrect stimulus
incWithin = {
	@()drawBackground(s);
};

%incorrect / break exit
incExit = {
	@()updateVariables(me); %randomise our stimuli, don't run updateTask(task), and set strobe value too
	@()update(stims); %update our stimuli ready for display
	@()resetExclusionZones(eT); %reset the exclusion zones
	@()checkTaskEnded(me); %check if task is finished
};
if tS.includeErrors
	incExit = [ {@()updatePlot(bR, me);@()updateTask(me,tS.BREAKFIX)}; incExit ]; % make sure our taskSequence is moved to the next trial
else
	incExit = [ {@()updatePlot(bR, me);@()resetRun(task)}; incExit ]; % we randomise the run within this block to make it harder to guess next trial
end

%break entry
breakEntry = {
	@()beep(aM, 400, 0.5, 1);
	@()trackerMessage(eT,'END_RT');
	@()trackerMessage(eT,['TRIAL_RESULT ' str2double(tS.BREAKFIX)]);
	@()trackerDrawStatus(eT,'Fail to Saccade to Target! :-(', stims.stimulusPositions);
	@()needEyeSample(me,false);
	@()hide(stims);
	@()logRun(me,'BREAKFIX'); %fprintf current trial info
};

exclEntry = {
	@()beep(aM, 400, 0.5, 1);
	@()trackerMessage(eT,'END_RT');
	@()trackerMessage(eT,['TRIAL_RESULT ' str2double(tS.BREAKFIX)]);
	@()trackerDrawStatus(eT,'Exclusion Zone entered! :-(', stims.stimulusPositions);
	@()needEyeSample(me,false);
	@()hide(stims);
	@()logRun(me,'EXCLUSION'); %fprintf current trial info
};

%calibration function
calibrateFn = { 
	@()rstop(io);
	@()drawBackground(s); %blank the display
	@()stopRecording(eT); % stop recording in eyelink [tobii ignores this]
	@()setOffline(eT); % set eyelink offline [tobii ignores this]
	@()trackerSetup(eT);  %enter tracker calibrate/validate setup mode
};

%--------------------drift correction function
driftFn = {
	@()drawBackground(s); %blank the display
	@()stopRecording(eT); % stop recording in eyelink [tobii ignores this]
	@()setOffline(eT); % set eyelink offline [tobii ignores this]
	@()driftCorrection(eT) % enter drift correct
};

%debug override
overrideFn = { @()keyOverride(me) }; %a special mode which enters a matlab debug state so we can manually edit object values

%screenflash
flashFn = { @()flashScreen(s, 0.2) }; % fullscreen flash mode for visual background activity detection

%show 1deg size grid
gridFn = {@()drawGrid(s)};

%==============================================================================
%-----------------------------State Machine Table------------------------------
% specify the cell array that is read by the stateMachine.
% REMEMBER that transitionFcn can override the time value, so for example
% stimulus shows 2 seconds time, but the transitionFcn can jump to other
% states (correct or breakfix) sooner than this, so this is an upper limit!
% initial state should be a pause, and keep calibrate, drift, override, 
% flash, showgrid as these generic states are controlled by the keyboard.
%
stateInfoTmp = {
'name'		'next'		'time'  'entryFcn'		'withinFcn'		'transitionFcn'	'exitFcn';
%---------------------------------------------------------------------------------------------
'pause'		'prefix'	inf		pauseEntry		{}				{}				pauseExit;
'prefix'	'fixate'	0.5		pfEntry			pfWithin		{}				pfExit;
'fixate'	'incorrect'	5		fixEntry		fixWithin		initFix			fixExit;
'fixstim'	'incorrect' 5		fsEntry			fsWithin		fsFix			fsExit
'stimulus'	'incorrect'	5		stimEntry		stimWithin		targetFix		stimExit;
'correct'	'prefix'	0.25	correctEntry	correctWithin	{}				correctExit;
'incorrect'	'timeout'	0.25	incEntry		incWithin		{}				incExit;
'breakfix'	'timeout'	0.25	breakEntry		incWithin		{}				incExit;
'exclusion'	'timeout'	0.25	exclEntry		incWithin		{}				incExit;
'timeout'	'prefix'	tS.tOut	{}				{}				{}				{};
'calibrate'	'pause'		0.5		calibrateFn		{}				{}				{};
'drift'		'pause'		0.5		driftFn			{}				{}				{};
'override'	'pause'		0.5		overrideFn		{}				{}				{};
'flash'		'pause'		0.5		flashFn			{}				{}				{};
'showgrid'	'pause'		10		{}				gridFn			{}				{};
};
%
%-----------------------------State Machine Table------------------------------
%==============================================================================

disp('================>> Building state info file <<================')
disp(stateInfoTmp)
disp('=================>> Loaded state info file <<=================')

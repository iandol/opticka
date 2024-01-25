% FIXATION ONLY state configuration file, this gets loaded by opticka via
% runExperiment class
% 
% This task only contains a fixation cross, by default it uses
% stims.stimulusTable (see below) to randomise the position of the timulus
% on each trial. This randomisation is dynamic, and not saved in any data
% stream; use this technique for training not for data collection. You can
% also control some variable like size manually.
%
% The following class objects (easily named handle copies) are already
% loaded and available to use. Each class has methods useful for running the
% task: 
%
% me		= runExperiment object ('self' in OOP terminology)
% s			= screenManager object
% aM		= audioManager object
% stims		= our list of stimuli (metaStimulus class)
% sM		= State Machine (stateMachine class)
% task		= task sequence (taskSequence class)
% eT		= eyetracker manager
% io		= digital I/O to recording system
% rM		= Reward Manager (LabJack or Arduino TTL trigger to reward system/Magstim)
% bR		= behavioural record plot (on-screen GUI during a task run)
% tS		= structure to hold general variables, will be saved as part of the data

%==================================================================
%------------General Settings-----------------
tS.useTask					= false;		%==use taskSequence (randomised variable task object)
tS.rewardTime				= 250;		%==TTL time in milliseconds
tS.rewardPin				= 2;		%==Output pin, 2 by default with Arduino.
tS.keyExclusionPattern		= ["stimulus"]; %==which states to skip keyboard checking
tS.recordEyePosition		= false;	%==record eye position within PTB, **in addition** to the EDF?
tS.askForComments			= false;	%==little UI requestor asks for comments before/after run
tS.saveData					= false;		%==save behavioural and eye movement data?
tS.showBehaviourPlot		= true;		%==open the behaviourPlot figure? Can cause more memory use…
tS.name						= 'fixation-only task'; %==name of this protocol
tS.nStims					= stims.n;	%==number of stimuli
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
%-----------------INITIAL Eyetracker Settings----------------------
tS.fixX						= 0;		% X position in degrees
tS.fixY						= 0;		% X position in degrees
tS.firstFixInit				= 3;		% time to search and enter fixation window
tS.firstFixTime				= [0.4 0.8];% time to maintain fixation within window
tS.firstFixRadius			= 2;		% radius in degrees
tS.strict					= false;	% do we forbid [true] eye to enter-exit-reenter fixation window?

%=========================================================================
%-------------------------------Eyetracker setup--------------------------
% NOTE: the opticka GUI can set eyetracker options too; me.eyetracker.esettings
% and me.eyetracker.tsettings contain the GUI settings. We test if they are
% empty or not and set general values based on that...
eT.name				= tS.name;
if me.eyetracker.dummy == true;	eT.isDummy = true; end %===use dummy or real eyetracker? 
if tS.saveData;		eT.recordData = true; end %===save ET data?
%Initialise the eyeTracker object with X, Y, FixInitTime, FixTime, Radius, StrictFix
updateFixationValues(eT, tS.fixX, tS.fixY, tS.firstFixInit, tS.firstFixTime, tS.firstFixRadius, tS.strict);

%==================================================================
%----WHICH states assigned as correct or break for online plot?----
%----You need to use regex patterns for the match (doc regexp)-----
bR.correctStateName				= "correct";
bR.breakStateName				= ["breakfix","incorrect"];

%==================================================================
%--------------randomise stimulus variables every trial?-----------
% if you want to have some randomisation of stimuls variables without
% using taskSequence task, you can uncomment this and runExperiment can
% use this structure to change e.g. X or Y position, size, angle
% see metaStimulus for more details. Remember this will not be "Saved" for
% later use, if you want to do controlled methods of constants experiments
% use taskSequence to define proper randomised and balanced variable
% sets and triggers to send to recording equipment etc...
%
d							= 6;
stims.choice				= [];
n							= 1;
in(n).name					= 'xyPosition';
in(n).values				= [d d; d -d; -d d; -d -d; -d 0; d 0];
in(n).stimuli				= 1;
in(n).offset				= [];
stims.stimulusTable			= in;

%==================================================================
%-------------allows using arrow keys to control variables?--------
% another option is to enable manual control of a table of variables
% this is useful to probe RF properties or other features while still
% allowing for fixation or other behavioural control.
% Use arrow keys <- -> to control value and up/down to control variable
stims.tableChoice 				= 1;
n								= 1;
stims.controlTable(n).variable	= 'size';
stims.controlTable(n).delta		= 0.2;
stims.controlTable(n).stimuli	= 1;
stims.controlTable(n).limits	= [0.2 10];
n								= 2;
stims.controlTable(n).variable	= 'xPosition';
stims.controlTable(n).delta		= 0.5;
stims.controlTable(n).stimuli	= 1;
stims.controlTable(n).limits	= [-10 10];
n								= 3;
stims.controlTable(n).variable	= 'yPosition';
stims.controlTable(n).delta		= 0.5;
stims.controlTable(n).stimuli	= 1;
stims.controlTable(n).limits	= [-10 10];

%==================================================================
%this allows us to enable subsets from our stimulus list
% 1 = grating | 2 = fixation cross
stims.stimulusSets			= { 1 };
stims.setChoice				= 1;
hide(stims);

%==================================================================
%which stimulus in the list is used for a fixation target? For this protocol it means
%the subject must fixate this stimulus (the saccade target is #1 in the list) to get the
%reward. Also which stimulus to set an exclusion zone around (where a
%saccade into this area causes an immediate break fixation).
stims.fixationChoice = 1;

%===================================================================
%-----------------State Machine State Functions---------------------
% each cell {array} holds a set of anonymous function handles which are executed by the
% state machine to control the experiment. The state machine can run sets
% at entry, during, to trigger a transition, and at exit. Remember these
% {sets} need to access the objects that are available within the
% runExperiment context (see top of file). You can also add global
% variables/objects then use these. The values entered here are set on
% load, if you want up-to-date values then you need to use methods/function
% wrappers to retrieve/set them.

%--------------------enter pause state
pauseEntryFcn = {
	@()hide(stims);
	@()drawBackground(s); %blank the subject display
	@()drawTextNow(s,'PAUSED, press [p] to resume...');
	@()disp('PAUSED, press [p] to resume...');
	@()trackerDrawStatus(eT,'PAUSED, press [p] to resume', stims.stimulusPositions);
	@()trackerMessage(eT,'TRIAL_RESULT -100'); %store message in EDF
	@()setOffline(eT); % set eyelink offline [tobii ignores this]
	@()stopRecording(eT, true); %stop recording eye position data, true=both eyelink & tobii
	@()needFlip(me, false, 0); % no need to flip the PTB screen
	@()needEyeSample(me, false); % no need to check eye position
	};

%--------------------pause exit
pauseExitFcn = {
	@()fprintf('\n===>>>EXIT PAUSE STATE\n')
	%start recording eye position data again, note true is required here as
	%the eyelink is started and stopped on each trial, but the tobii runs
	%continuously, so @()startRecording(eT) only affects eyelink but
	%@()startRecording(eT, true) affects both eyelink and tobii...
	@()startRecording(eT, true); 
}; 

%========================================================
%========================================================BLANK
%========================================================
%prestim entry
blEntryFcn = {
	@()needFlip(me, true, 1); % start PTB screen flips
	@()needEyeSample(me, true); % make sure we start measuring eye position
	@()startRecording(eT);
	@()update(stims);
	@()updateFixationTarget(me, true, tS.firstFixInit, tS.firstFixTime, tS.firstFixRadius);
	@()resetAll(eT);
	@()trackerDrawStatus(eT,'Fixation Only Trial');
	@()logRun(me,'PRESTIM'); %fprintf current trial info
};

%prestimulus blank
blFcn = { 
	@()trackerDrawFixation(eT);
	@()trackerDrawEyePosition(eT); % draw the fixation position on the eyetracker
};

%exiting prestimulus state
blExitFcn = {
	@()show(stims);
};

%what to run when we enter the stim presentation state
stimEntryFcn = {
	@()logRun(me,'STIM'); 
};

%what to run when we are showing stimuli
stimFcn = {
	@()draw(stims);
	@()animate(stims); % animate stimuli for subsequent draw
	@()trackerDrawEyePosition(eT); % this shows the eye position on tobii
};

%test we are maintaining fixation
maintainFixFcn = {
	@()testSearchHoldFixation(eT,'correct','breakfix');
};

%as we exit stim presentation state
stimExitFcn = {
	
};

%if the subject is correct (small reward)
correctEntryFcn = {
	@()giveReward(rM); % send a reward TTL
	@()beep(aM, tS.correctSound); % correct beep
	@()trackerDrawStatus(eT,'CORRECT! :-)', stims.stimulusPositions);
	@()needFlipTracker(me, 0); %for operator screen stop flip
	@()stopRecording(eT); % stop recording in eyelink [tobii ignores this]
	@()setOffline(eT); % set eyelink offline [tobii ignores this]
	@()needEyeSample(me,false);
	@()hide(stims);
	@()logRun(me,'CORRECT'); %fprintf current trial info
};

%correct stimulus
correctFcn = { 
	
};

%break entry
breakEntryFcn = {
	@()beep(aM,tS.errorSound);
	@()trackerDrawStatus(eT,'BREAK! :-(', stims.stimulusPositions);
	@()needFlipTracker(me, 0); %for tobii stop flip
	@()logRun(me,'BREAK'); %fprintf current trial info
};

%incorrect entry
inEntryFcn = {
	@()beep(aM,tS.errorSound);
	@()trackerDrawStatus(eT,'INCORRECT! :-(', stims.stimulusPositions, 0);
	@()needFlipTracker(me, 0); %for tobii stop flip
	@()logRun(me,'INCORRECT'); %fprintf current trial info
};

%our incorrect stimulus
breakFcn = {
	@()drawBackground(s);
	@()trackerDrawStatus(eT,'BREAKFIX! :-(', stims.stimulusPositions, 0);
	
};

%when we exit the breakfix/incorrect state
ExitFcn = {
	@()updatePlot(bR, me); %update our behavioural plot
	@()needEyeSample(me,false); 
	@()needFlip(me, false, 0);
	@()randomise(stims); %uses stimulusTable to give new values to variables (not saved in data, used for training)
	@()getStimulusPositions(stims); % make a struct the eT can use for drawing stim positions
	@()plot(bR, 1); % actually do our behaviour record drawing
	@()checkTaskEnded(me); % check the trial / block # and if met stop the task
};

%========================================================
%========================================================EYETRACKER
%========================================================
%--------------------calibration function
calibrateFcn = {
	@()drawBackground(s); %blank the display
	@()stopRecording(eT); % stop recording in eyelink [tobii ignores this]
	@()setOffline(eT); % set eyelink offline [tobii ignores this]
	@()trackerSetup(eT);  %enter tracker calibrate/validate setup mode
};

%--------------------drift correction function
driftFcn = {
	@()drawBackground(s); %blank the display
	@()stopRecording(eT); % stop recording in eyelink [tobii ignores this]
	@()setOffline(eT); % set eyelink offline [tobii ignores this]
	@()driftCorrection(eT) % enter drift correct (only eyelink)
};
offsetFcn = {
	@()drawBackground(s); %blank the display
	@()stopRecording(eT); % stop recording in eyelink [tobii ignores this]
	@()setOffline(eT); % set eyelink offline [tobii ignores this]
	@()driftOffset(eT) % enter drift offset (works on tobii & eyelink)
};

%========================================================
%========================================================GENERAL
%========================================================
%--------------------DEBUGGER override
overrideFcn = { @()keyOverride(me) }; %a special mode which enters a matlab debug state so we can manually edit object values

%--------------------screenflash
flashFcn = { @()flashScreen(s, 0.2) }; % fullscreen flash mode for visual background activity detection

%--------------------show 1deg size grid
gridFcn = { @()drawGrid(s) };

%==============================================================================
%----------------------State Machine Table-------------------------
% specify our cell array that is read by the stateMachine
stateInfoTmp = {
'name'		'next'			'time'	'entryFcn'		'withinFcn'		'transitionFcn'	'exitFcn';
%---------------------------------------------------------------------------------------------
'pause'		'blank'			inf		pauseEntryFcn	{}				{}				pauseExitFcn;
%---------------------------------------------------------------------------------------------
'blank'		'stimulus'		0.5		blEntryFcn		blFcn			{}				blExitFcn;
'stimulus'	'incorrect'		5		stimEntryFcn	stimFcn			maintainFixFcn	stimExitFcn;
'incorrect'	'timeout'		0.25	inEntryFcn		breakFcn		{}				ExitFcn;
'breakfix'	'timeout'		0.25	breakEntryFcn	breakFcn		{}				ExitFcn;
'correct'	'blank'			0.25	correctEntryFcn	correctFcn		{}				ExitFcn;
'timeout'	'blank'			tS.tOut	{}				{}				{}				{};
%---------------------------------------------------------------------------------------------
'calibrate'	'pause'			0.5		calibrateFcn	{}				{}				{};
'drift'		'pause'			0.5		driftFcn		{}				{}				{};
'offset'	'pause'			0.5		offsetFcn		{}				{}				{};
%---------------------------------------------------------------------------------------------
'flash'		'pause'			0.5		{}				flashFcn		{}				{};
'override'	'pause'			0.5		{}				overrideFcn		{}				{};
'showgrid'	'pause'			1		{}				gridFcn			{}				{};
};
%----------------------State Machine Table-------------------------
%==============================================================================
disp('================>> Building state info file <<================')
disp(stateInfoTmp)
disp('=================>> Loaded state info file <<=================')
clearvars -regexp '.+Fcn$' % clear the cell array Fcns in the current workspace


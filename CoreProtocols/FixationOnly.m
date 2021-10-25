%FIXATION ONLY state configuration file, this gets loaded by opticka via runExperiment class
% The following class objects (easily named handle copies) are already 
% loaded and available to use. Each class has methods useful for running the task: 
%
% me		= runExperiment object
% s			= screenManager
% aM		= audioManager
% sM		= State Machine
% task		= task sequence (taskSequence class)
% eT		= eyetracker manager
% io		= digital I/O to recording system
% rM		= Reward Manager (LabJack or Arduino TTL trigger to reward system/Magstim)
% bR		= behavioural record plot (on screen GUI during task run)
% stims		= our list of stimuli
% tS		= general structure to hold general variables, will be saved as part of the data

%==================================================================
%------------General Settings-----------------
tS.useTask					= true;		%==use taskSequence (randomised variable task object)
tS.rewardTime				= 250;		%==TTL time in milliseconds
tS.rewardPin				= 2;		%==Output pin, 2 by default with Arduino.
tS.checkKeysDuringStimulus	= true;		%==allow keyboard control during all states? Slight drop in performance
tS.recordEyePosition		= false;	%==record eye position within PTB, **in addition** to the EDF?
tS.askForComments			= false;	%==little UI requestor asks for comments before/after run
tS.saveData					= true;		%==save behavioural and eye movement data?
tS.name						= 'fixation'; %==name of this protocol
tS.nStims					= stims.n;	%==number of stimuli
tS.tOut						= 5;		%==if wrong response, how long to time out before next trial
tS.CORRECT					= 1;		%==the code to send eyetracker for correct trials
tS.BREAKFIX					= -1;		%==the code to send eyetracker for break fix trials
tS.INCORRECT				= -5;		%==the code to send eyetracker for incorrect trials

%==================================================================
%------------Debug logging to command window-----------------
%io.verbose					= true;	%==print out io commands for debugging
%eT.verbose					= true;	%==print out eyelink commands for debugging
%rM.verbose					= true;	%==print out reward commands for debugging

%==================================================================
%-----------------INITIAL Eyetracker Settings----------------------
tS.fixX						= 0;		% X position in degrees
tS.fixY						= 0;		% X position in degrees
tS.firstFixInit				= 3;		% time to search and enter fixation window
tS.firstFixTime				= 0.5;		% time to maintain fixation within windo
tS.firstFixRadius			= 2;		% radius in degrees
tS.strict					= true;		% do we forbid eye to enter-exit-reenter fixation window?
tS.exclusionZone			= [];		% do we add an exclusion zone where subject cannot saccade to...
tS.stimulusFixTime			= 2;		% time to fix on the stimulus
me.lastXPosition			= tS.fixX;
me.lastYPosition			= tS.fixY;

%==================================================================
%---------------------------Eyetracker setup-----------------------
if me.useEyeLink
	eT.name 					= tS.name;
	eT.sampleRate 				= 250;		% sampling rate
	eT.calibrationStyle 		= 'HV5';	% calibration style
	eT.calibrationProportion	= [0.4 0.4]; %the proportion of the screen occupied by the calibration stimuli
	if tS.saveData == true;		eT.recordData = true; end %===save EDF file?
	if me.dummyMode;			eT.isDummy = true; end %===use dummy or real eyetracker? 
	%-----------------------
	% remote calibration enables manual control and selection of each fixation
	% this is useful for a baby or monkey who has not been trained for fixation
	% use 1-9 to show each dot, space to select fix as valid, INS key ON EYELINK KEYBOARD to
	% accept calibration!
	eT.remoteCalibration		= false; 
	%-----------------------
	eT.modify.calibrationtargetcolour = [1 1 1]; % calibration target colour
	eT.modify.calibrationtargetsize = 2;		% size of calibration target as percentage of screen
	eT.modify.calibrationtargetwidth = 0.15;	% width of calibration target's border as percentage of screen
	eT.modify.waitformodereadytime	= 500;
	eT.modify.devicenumber 			= -1;		% -1 = use any attachedkeyboard
	eT.modify.targetbeep 			= 1;		% beep during calibration
elseif me.useTobii
	eT.name 					= tS.name;
	eT.model					= 'Tobii Pro Spectrum';
	eT.trackingMode				= 'human';
	eT.calPositions				= [ .2 .5; .5 .5; .8 .5];
	eT.valPositions				= [ .5 .5 ];
	if me.dummyMode;			eT.isDummy = true; end %===use dummy or real eyetracker? 
end

%Initialise the eyeTracker object with X, Y, FixInitTime, FixTime, Radius, StrictFix
eT.updateFixationValues(tS.fixX, tS.fixY, tS.firstFixInit, tS.firstFixTime, tS.firstFixRadius, tS.strict);
%make sure we don't start with any exclusion zones set up
eT.resetExclusionZones();

%==================================================================
%----WHICH states assigned as correct or break for online plot?----
%----You need to use regex patterns for the match (doc regexp)-----
bR.correctStateName				= '^correct';
bR.breakStateName				= '^(breakfix|incorrect)';

%==================================================================
%-------------------randomise stimulus variables every trial?-----------
% if you want to have some randomisation of stimuls variables without
% using taskSequence task, you can uncomment this and runExperiment can
% use this structure to change e.g. X or Y position, size, angle
% see metaStimulus for more details. Remember this will not be "Saved" for
% later use, if you want to do controlled methods of constants experiments
% use taskSequence to define proper randomised and balanced variable
% sets and triggers to send to recording equipment etc...
%
stims.choice				= [];
n							= 1;
in(n).name					= 'xyPosition';
in(n).values					= [6 6; 6 -6; -6 6; -6 -6; -6 0; 6 0];
in(n).stimuli					= 1;
in(n).offset					= [];
stims.stimulusTable			= in;

%==================================================================
%-------------allows using arrow keys to control variables?-------------
% another option is to enable manual control of a table of variables
% this is useful to probe RF properties or other features while still
% allowing for fixation or other behavioural control.
% Use arrow keys <- -> to control value and up/down to control variable
stims.tableChoice 				= 1;
n								= 1;
stims.controlTable(n).variable	= 'size';
stims.controlTable(n).delta		= 0.5;
stims.controlTable(n).stimuli	= 1;
stims.controlTable(n).limits	= [0.25 20];

%==================================================================
%this allows us to enable subsets from our stimulus list
% 1 = grating | 2 = fixation cross
stims.stimulusSets			= {[1]};
stims.setChoice				= 1;
hide(stims);

%==================================================================
%which stimulus in the list is used for a fixation target? For this protocol it means
%the subject must fixate this stimulus (the saccade target is #1 in the list) to get the
%reward. Also which stimulus to set an exclusion zone around (where a
%saccade into this area causes an immediate break fixation).
me.stimuli.fixationChoice = 1;
me.stimuli.exclusionChoice = [];

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
	@()trackerClearScreen(eT); % blank the eyelink screen
	@()trackerDrawText(eT,'PAUSED, press [P] to resume...');
	@()trackerMessage(eT,'TRIAL_RESULT -100'); %store message in EDF
	@()setOffline(eT); % make sure we set offline, only works on eyelink, ignored by tobii
	@()stopRecording(eT, true); %stop recording eye position data
	@()disableFlip(me); % no need to flip the PTB screen
	@()needEyeSample(me,false); % no need to check eye position
};

%prestim entry
psEntryFcn = { 
	@()setOffline(eT);
	@()trackerDrawFixation(eT);
	@()resetFixation(eT);
	@()startRecording(eT)
};

%prestimulus blank
prestimulusFcn = { @()drawBackground(s) };

%exiting prestimulus state
psExitFcn = { 
	@()update(me.stimuli);
	@()statusMessage(eT,'Showing Fixation Spot...');
};

%what to run when we enter the stim presentation state
stimEntryFcn = {};

%what to run when we are showing stimuli
stimFcn = {
	@()draw(me.stimuli); 
	%@()drawEyePosition(eT);
	@()animate(me.stimuli); % animate stimuli for subsequent draw
};

%test we are maintaining fixation
maintainFixFcn = {
	@()testSearchHoldFixation(eT,'correct','breakfix');
};

%as we exit stim presentation state
stimExitFcn = {};

%if the subject is correct (small reward)
correctEntryFcn = { 
	@()timedTTL(rM, tS.rewardPin, tS.rewardTime); % send a reward TTL
	@()statusMessage(eT,'Correct! :-)');
	@()logRun(me,'CORRECT'); %fprintf current trial info
};

%correct stimulus
correctFcn = { @()drawBackground(s); };


%break entry
breakEntryFcn = { 
	@()statusMessage(eT,'Broke Fixation :-(');
	@()logRun(me,'BREAK'); %fprintf current trial info
};

%incorrect entry
inEntryFcn = {
	@()statusMessage(eT,'Incorrect :-(');
	@()logRun(me,'INCORRECT'); %fprintf current trial info
};

%our incorrect stimulus
breakFcn =  {
	@()drawBackground(s);
};

%when we exit the breakfix/incorrect state
ExitFcn = {
	@()updatePlot(bR, eT, sM);
	@()drawnow;
};

%--------------------calibration function
calibrateFcn = { 
	@()drawBackground(s); %blank the display
	@()stopRecording(eT); % stop eyelink recording data
	@()setOffline(eT); % set eyelink offline
	@()trackerSetup(eT) % enter tracker calibrate/validate setup mode
};

%--------------------drift offset function
offsetFcn = { 
	@()drawBackground(s); %blank the display
	@()stopRecording(eT); % stop eyelink recording data
	@()setOffline(eT); % set eyelink offline
	@()driftOffset(eT) % enter tracker offset
};

%--------------------drift correction function
driftFcn = { 
	@()drawBackground(s); %blank the display
	@()stopRecording(eT); % stop eyelink recording data
	@()setOffline(eT); % set eyelink offline
	@()driftCorrection(eT) % enter drift correct
};

%--------------------screenflash
flashFcn = { 
	@()drawBackground(s);
	@()flashScreen(s, 0.2); % fullscreen flash mode for visual background activity detection
};

%----------------------allow override
overrideFcn = { 
	@()keyOverride(me); 
};

%----------------------show 1deg size grid
gridFcn = { 
	@()drawGrid(s); 
	@()drawScreenCenter(s);
};

%----------------------State Machine Table-------------------------
% this table defines the states and relationships and function sets
%==================================================================
disp('================>> Building state info file <<================')
%specify our cell array that is read by the stateMachine
stateInfoTmp = {
'name'		'next'			'time'	'entryFcn'		'withinFcn'		'transitionFcn'	'exitFcn';
'pause'		'blank'			[inf] 	pauseEntryFcn	[]				[]				[];
'blank'		'stimulus'		[1 ]	psEntryFcn		prestimulusFcn	[]				psExitFcn;
'stimulus'	'incorrect'		4		stimEntryFcn	stimFcn			maintainFixFcn	stimExitFcn;
'incorrect'	'blank'			1		inEntryFcn		breakFcn		[]				ExitFcn;
'breakfix'	'blank'			2		breakEntryFcn	breakFcn		[]				ExitFcn;
'correct'	'blank'			1		correctEntryFcn	correctFcn		[]				correctExitFcn;
'calibrate' 'pause'			0.5		calibrateFcn	[]				[]				[];
'drift'		'pause'			0.5		driftFcn		[]				[]				[];
'flash'		'pause'			0.5		[]				flashFcn		[]				[];
'override'	'pause'			0.5		[]				overrideFcn		[]				[];
'showgrid'	'pause'			1		[]				gridFcn			[]				[];
};

disp(stateInfoTmp)
disp('================>> Loaded state info file <<================')
clear maintainFixFcn prestimulusFcn singleStimulus pauseEntryFcn ...
	prestimulusFcn stimFcn stimEntryFcn stimExitfcn correctEntry ...
	correctWithin correctExitFcn breakFcn maintainFixFcn psExitFcn ...
	incorrectFcn calibrateFcn offsetFcn driftFcn gridFcn overrideFcn flashFcn breakFcn

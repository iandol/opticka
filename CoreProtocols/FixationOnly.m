%FIXATION ONLY state configuration file, this gets loaded by opticka via runExperiment class
% The following class objects (easily named handle copies) are already 
% loaded and available to use: 
%
% me = runExperiment object
% io = digital I/O to recording system
% s = screenManager
% aM = audioManager
% sM = State Machine
% eT = eyetracker manager
% t  = task sequence (taskSequence class)
% rM = Reward Manager (LabJack or Arduino TTL trigger to reward system/Magstim)
% bR = behavioural record plot (on screen GUI during task run)
% me.stimuli = our list of stimuli
% tS = general struct to hold variables for this run, will be saved as part of the data

%==================================================================
%------------General Settings-----------------
tS.useTask					= true; %==use taskSequence (randomised variable task object)
tS.rewardTime				= 250; %==TTL time in milliseconds
tS.rewardPin				= 11; %==Output pin, 2 by default with Arduino.
tS.checkKeysDuringStimulus  = true; %==allow keyboard control? Slight drop in performance
tS.recordEyePosition		= false; %==record eye position within PTB, **in addition** to the EDF?
tS.askForComments			= false; %==little UI requestor asks for comments before/after run
tS.saveData					= true; %==save behavioural and eye movement data?
tS.name						= 'area-summation'; %==name of this protocol
tS.tOut						= 5; %if wrong response, how long to time out before next trial

%==================================================================
%------------Debug logging to command window-----------------
io.verbose					= false; %print out io commands for debugging
eT.verbose					= false; %print out eyelink commands for debugging
rM.verbose					= false; %print out reward commands for debugging

%==================================================================
%--------------------Eyetracker Settings---------------------------
tS.fixX						= 0; % X position in degrees
tS.fixY						= 0; % X position in degrees
tS.firstFixInit				= 3; % time to search and enter fixation window
tS.firstFixTime				= 0.5; % time to maintain fixation within windo
tS.firstFixRadius			= 2; % radius in degrees
tS.strict					= true; % do we forbid eye to enter-exit-reenter fixation window?
tS.exclusionZone			= []; % do we add an exclusion zone where subject cannot saccade to...
tS.stimulusFixTime			= 1.5; % time to fix on the stimulus
me.lastXPosition			= tS.fixX;
me.lastYPosition			= tS.fixY;

%==================================================================
%---------------------------Eyetracker setup-----------------------
if me.useEyeLink
	eT.name 					= tS.name;
	eT.sampleRate 				= 250; % sampling rate
	eT.calibrationStyle 		= 'HV3'; % calibration style
	eT.calibrationProportion	= [0.4 0.4]; %the proportion of the screen occupied by the calibration stimuli
	if tS.saveData == true;		eT.recordData = true; end %===save EDF file?
	if me.dummyMode;			eT.isDummy = true; end %===use dummy or real eyetracker? 
	%-----------------------
	% remote calibration enables manual control and selection of each fixation
	% this is useful for a baby or monkey who has not been trained for fixation
	% use 1-9 to show each dot, space to select fix as valid, INS key ON EYELINK KEYBOARD to
	% accept calibration!
	eT.remoteCalibration		= true; 
	%-----------------------
	eT.modify.calibrationtargetcolour = [1 1 1]; % calibration target colour
	eT.modify.calibrationtargetsize = 2; % size of calibration target as percentage of screen
	eT.modify.calibrationtargetwidth = 0.15; % width of calibration target's border as percentage of screen
	eT.modify.waitformodereadytime	= 500;
	eT.modify.devicenumber 			= -1; % -1 = use any attachedkeyboard
	eT.modify.targetbeep 			= 1; % beep during calibration
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
%----which states assigned as correct or break for online plot?----
bR.correctStateName				= 'correct';
bR.breakStateName				= 'breakfix';

%==================================================================
%-------------------randomise stimulus variables every trial?-----------
% if you want to have some randomisation of stimuls variables without
% using stimulusSequence task, you can uncomment this and runExperiment can
% use this structure to change e.g. X or Y position, size, angle
% see metaStimulus for more details. Remember this will not be "Saved" for
% later use, if you want to do controlled methods of constants experiments
% use stimulusSequence to define proper randomised and balanced variable
% sets and triggers to send to recording equipment etc...
%
me.stimuli.choice				= [];
n								= 1;
in(n).name					= 'xyPosition';
in(n).values					= [6 6; 6 -6; -6 6; -6 -6; -6 0; 6 0];
in(n).stimuli					= 1;
in(n).offset					= [];
me.stimuli.stimulusTable		= in;

%==================================================================
%-------------allows using arrow keys to control variables?-------------
% another option is to enable manual control of a table of variables
% this is useful to probe RF properties or other features while still
% allowing for fixation or other behavioural control.
% Use arrow keys <- -> to control value and up/down to control variable
me.stimuli.tableChoice = 1;
n=1;
me.stimuli.controlTable(n).variable = 'size';
me.stimuli.controlTable(n).delta = 0.5;
me.stimuli.controlTable(n).stimuli = 1;
me.stimuli.controlTable(n).limits = [0.25 20];

%==================================================================
%this allows us to enable subsets from our stimulus list
% 1 = grating | 2 = fixation cross
me.stimuli.stimulusSets = {[1],[1]};
me.stimuli.setChoice = 1;
showSet(me.stimuli);

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

%pause entry
pauseEntryFcn = {
	@()hide(me.stimuli);
	@()drawBackground(s); %blank the subject display
	@()drawTextNow(s,'Paused, press [p] to resume...');
	@()disp('Paused, press [p] to resume...');
	@()trackerClearScreen(eT); % blank the eyelink screen
	@()trackerDrawText(eT,'PAUSED, press [P] to resume...');
	@()trackerMessage(eT,'TRIAL_RESULT -100'); %store message in EDF
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
prestimulusFcn = @()drawBackground(s);

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
	@()finishDrawing(s);
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
	@()timedTTL(rM,2,tS.rewardTime); 
	@()updatePlot(bR, eT, sM);
	@()statusMessage(eT,'Correct! :-)');
};

%correct stimulus
correctFcn = { @()drawBackground(s); @()drawGreenSpot(s,1) };

%when we exit the correct state
correctExitFcn = {};

%break entry
breakEntryFcn = { @()updatePlot(bR, eT, sM);
	@()statusMessage(eT,'Broke Fixation :-(') };

%break entry
incorrectFcn = { @()updatePlot(bR, eT, sM);
	@()statusMessage(eT,'Incorrect :-(') };

%our incorrect stimulus
breakFcn =  { @()drawBackground(s)}; % @()drawGreenSpot(s,1) };

%calibration function
calibrateFcn = {@()trackerSetup(eT);};

%--------------------drift correction function
driftFcn = { 
	@()drawBackground(s); %blank the display
	@()stopRecording(eT); % stop eyelink recording data
	@()setOffline(eT); % set eyelink offline
	@()driftCorrection(eT) % enter drift correct
};

%flash function
flashFcn = {@()flashScreen(s,0.25);};

% allow override
overrideFcn = {@()keyOverride(obj);};

%show 1deg size grid
gridFcn = { @()drawGrid(s); @()drawScreenCenter(s) };

%----------------------State Machine Table-------------------------
disp('================>> Building state info file <<================')
%specify our cell array that is read by the stateMachine
stateInfoTmp = {
'name'		'next'			'time'	'entryFcn'		'withinFcn'		'transitionFcn'	'exitFcn';
'pause'		'blank'			[inf] 	pauseEntryFcn	[]				[]				[];
'blank'		'stimulus'		[2 6]	psEntryFcn		prestimulusFcn	[]				psExitFcn;
'stimulus'	'incorrect'		4		stimEntryFcn	stimFcn			maintainFixFcn	stimExitFcn;
'incorrect'	'blank'			1		incorrectFcn	breakFcn		[]				[];
'breakfix'	'blank'			2		breakEntryFcn	breakFcn		[]				[];
'correct'	'blank'			1		correctEntryFcn	correctFcn		[]				correctExitFcn;
'calibrate' 'pause'			0.5		calibrateFcn	[]				[]				[];
'drift'		'pause'			0.5		driftFcn		[]				[]				[];
'flash'		'pause'			0.5		[]				flashFcn		[]				[];
'override'	'pause'			0.5		[]				overrideFcn		[]				[];
'showgrid'	'pause'			1		[]				gridFcn			[]				[];
};

disp(stateInfoTmp)
disp('================>> Building state info file <<================')
clear maintainFixFcn prestimulusFcn singleStimulus
	prestimulusFcn stimFcn stimEntryFcn stimExitfcn correctEntry correctWithin correctExit
	incorrectFcn calibrateFcn gridFcn overrideFcn flashFcn breakFcn
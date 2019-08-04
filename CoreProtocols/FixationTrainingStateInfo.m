%FIXATION TRAINING state configuration file
%
%This presents a large fixation spot in a loop to train for fixation.
%Adjust eyetracker setting values over training to refine behaviour
%The following class objects (easily named handle copies) are already loaded and available to
%use: 
% me = runExperiment object
% io = digital I/O to recording system
% s = screenManager
% sM = State Machine
% eL = eyelink manager
% rM = reward manager (trigger to reward system)
% bR = behavioural record plot
% me.stimuli = our list of stimuli
% tS = general simple struct to hold variables for this run

%------------General Settings-----------------
tS.useTask = false; %==use stimulusSequence (randomised variable task object)
tS.rewardTime = 500; %==TTL time in milliseconds
tS.rewardPin = 2; %==Output pin, 2 by default with Arduino.
tS.checkKeysDuringStimulus = false; %==allow keyboard control? Slight drop in performance
tS.recordEyePosition = false; %==record eye position within PTB, **in addition** to the EDF?
tS.askForComments = false; %==little UI requestor asks for comments before/after run
tS.saveData = false; %==save behavioural and eye movement data?
tS.dummyEyelink = true; %==use mouse as a dummy eyelink, good for testing away from the lab.
tS.useMagStim = false; %enable the magstim manager
tS.name = 'fixation-training'; %==name of this protocol
me.useDataPixx = false; %make sure we don't trigger the plexon
me.useArduino = true; %use arduino for reward

%------------Eyetracker Settings-----------------
tS.fixX = 0;
tS.fixY = 0;
tS.firstFixInit = 1.5;
tS.firstFixTime = [0.5 0.8];
tS.firstFixRadius = 10;
me.lastXPosition = tS.fixX;
me.lastYPosition = tS.fixY;
tS.strict = false; %do we forbid eye to enter-exit-reenter fixation window?

%------------------------Eyelink setup--------------------------
eL.name = tS.name;
if tS.saveData == true; eL.recordData = true; end %===save EDF file?
if tS.dummyEyelink; eL.isDummy = true; end %===use dummy or real eyelink? 
eL.sampleRate = 250;
eL.remoteCalibration = true; %manual calibration
eL.calibrationStyle = 'HV5'; % calibration style
eL.modify.calibrationtargetcolour = [1 1 0];
eL.modify.calibrationtargetsize = 4;
eL.modify.calibrationtargetwidth = 0.01;
eL.modify.waitformodereadytime = 500;
eL.modify.devicenumber = -1; % -1==use any keyboard

%Initialise the eyeLink object with X, Y, FixInitTime, FixTime, Radius, StrictFix
eL.updateFixationValues(tS.fixX, tS.fixY, tS.firstFixInit, tS.firstFixTime, tS.firstFixRadius, tS.strict);

%randomise stimulus variables every trial?
% me.stimuli.choice = [];
% n = 1;
% in(n).name = 'xyPosition';
% in(n).values = [0 0];
% in(n).stimuli = 1;
% in(n).offset = [];
% me.stimuli.stimulusTable = in;
me.stimuli.choice = [];
me.stimuli.stimulusTable = [];

%allows using arrow keys to control this table
me.stimuli.tableChoice = 1;
n=1;
me.stimuli.controlTable(n).variable = 'size';
me.stimuli.controlTable(n).delta = 1;
me.stimuli.controlTable(n).stimuli = 1;
me.stimuli.controlTable(n).limits = [0.25 20];

%this allows us to enable subsets from our stimulus list
me.stimuli.stimulusSets = {1};
me.stimuli.setChoice = 1;
showSet(me.stimuli);

%----------------------State Machine States-------------------------

%pause entry
pauseEntryFcn = { 
	@()trackerDrawText(eL,'PAUSED, press [P] to resume...'); ...
	@()setOffline(eL);
	@()stopRecording(eL); ...
	@()edfMessage(eL,'TRIAL_RESULT -10'); ...
	@()fprintf('\n===>>>ENTER PAUSE STATE\n'); ...
	@()disableFlip(me); ...
};

%prestim entry
psEntryFcn = { 
	@()setOffline(eL); ...
	@()trackerDrawFixation(eL); ...
	@()resetFixation(eL); ...
	@()startRecording(eL);
};

%prestimulus blank
prestimulusFcn = {  };

%exiting prestimulus state
psExitFcn = {
	@()update(me.stimuli); ...
	@()show(me.stimuli); ...
	@()logRun(me,'SHOW FIX'); ... %fprintf current trial info
	@()statusMessage(eL,'Showing Fixation Spot...'); ...
};

%what to run when we enter the stim presentation state
stimEntryFcn = {};

%what to run when we are showing stimuli
stimFcn = { 
	@()draw(me.stimuli); ... 
	@()drawEyePosition(eL); ...
	@()finishDrawing(s); ...
};

%test we are maintaining fixation
maintainFixFcn = { 
	@()testSearchHoldFixation(eL,'correct','breakfix'); 
};

%as we exit stim presentation state
stimExitFcn = {};

%if the subject is correct (small reward)
correctEntryFcn = { 
	@()timedTTL(rM, tS.rewardPin, tS.rewardTime); ... 
	@()statusMessage(eL,'Correct! :-)');
	@()logRun(me,'CORRECT'); ... %fprintf current trial info
};

%correct stimulus
correctFcn = { 
	@()drawBackground(s); 
	@()drawGreenSpot(s,1) 
};

%when we exit the correct state
correctExitFcn = { @()updatePlot(bR, eL, sM) };

%break entry
breakEntryFcn = { 
	@()statusMessage(eL,'Broke Fixation :-(') 
	@()logRun(me,'BREAKFIX'); ... %fprintf current trial info
};

%break entry
incEntryFcn = { 
	@()statusMessage(eL,'Incorrect :-('); ...
	@()logRun(me,'INCORRECT'); ... %fprintf current trial info
};

%our incorrect stimulus
breakFcn =  { @()drawBackground(s); }; % @()drawGreenSpot(s,1) };

breakExitFcn = { @()updatePlot(bR, eL, sM); };

%calibration function
calibrateFcn = { @()trackerSetup(eL); };

%flash function
flashFcn = { @()flashScreen(s,0.25); };

% allow override
overrideFcn = { @()keyOverride(me); };

%show 1deg size grid
gridFcn = { @()drawGrid(s); @()drawScreenCenter(s) };

% N x 2 cell array of regexpi strings, list to skip the current -> next state's exit functions; for example
% skipExitStates = {'fixate','incorrect|breakfix'}; means that if the currentstate is
% 'fixate' and the next state is either incorrect OR breakfix, then skip the FIXATE exit
% state. Add multiple rows for skipping multiple state's exit states.
sM.skipExitStates = {'fixate','incorrect|breakfix'};

%----------------------State Machine Table-------------------------
disp('================>> Building state info file <<================')
%specify our cell array that is read by the stateMachine
stateInfoTmp = { ...
'name'      'next'		'time' 'entryFcn'		'withinFcn'		'transitionFcn'	'exitFcn'; ...
'pause'		'blank'		inf	pauseEntryFcn	[]					[]					[]; ...
'blank'		'stimulus'	[2 6]	psEntryFcn		prestimulusFcn	[]					psExitFcn; ...
'stimulus'  'incorrect'	4		stimEntryFcn	stimFcn			maintainFixFcn	stimExitFcn; ...
'incorrect'	'blank'		3		incEntryFcn		breakFcn			[]					breakExitFcn; ...
'breakfix'	'blank'		3		breakEntryFcn	breakFcn			[]					breakExitFcn; ...
'correct'	'blank'		1		correctEntryFcn	correctFcn	[]					correctExitFcn; ...
'calibrate' 'pause'		0.5	calibrateFcn	[]					[]					[]; ...
'flash'		'pause'		0.5	[]					flashFcn			[]					[]; ...
'override'	'pause'		0.5	[]					overrideFcn		[]					[]; ...
'showgrid'	'pause'		1		[]					gridFcn			[]					[]; ...
};

disp(stateInfoTmp)
disp('================>> Building state info file <<================')
clear maintainFixFcn prestimulusFcn singleStimulus pauseEntryFcn ...
	prestimulusFcn stimFcn stimEntryFcn stimExitfcn correctEntry ...
	correctWithin correctExitFcn breakFcn maintainFixFcn psExitFcn ...
	incorrectFcn calibrateFcn gridFcn overrideFcn flashFcn breakFcn
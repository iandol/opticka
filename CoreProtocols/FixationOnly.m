%Fixation Only state configuration file
%------------General Settings-----------------
tS.useTask = false;
tS.rewardTime = 500; %TTL time in milliseconds
tS.useTask = false;
tS.checkKeysDuringStimulus = true;
tS.recordEyePosition = false;
tS.askForComments = false;
tS.saveData = false; %we don't want to save any data
me.useDataPixx = false; %make sure we don't trigger the plexon

eL.isDummy = false; %use dummy or real eyelink?
eL.sampleRate = 250;
eL.remoteCalibration = true; %manual calibration
eL.calibrationStyle = 'HV5'; % calibration style
eL.recordData = false; % don't save EDF fileo
eL.modify.calibrationtargetcolour = [1 1 0];
eL.modify.calibrationtargetsize = 1;
eL.modify.calibrationtargetwidth = 0.1;
eL.modify.waitformodereadytime = 500;
eL.modify.devicenumber = -1; % -1==use any keyboard

eL.fixation.X = 0;
eL.fixation.Y = 0;
eL.fixation.radius = 7;
eL.fixation.initTime = 1.5;
eL.fixation.time = 0.5;
eL.fixation.strict = false;

%randomise stimulus variables every trial?
me.stimuli.choice = [];
n = 1;
in(n).name = 'xyPosition';
in(n).values = [0 0;];
in(n).stimuli = [1];
in(n).offset = [];
me.stimuli.stimulusTable = in;

%allows using arrow keys to control this table
me.stimuli.tableChoice = 1;
n=1;
me.stimuli.controlTable(n).variable = 'size';
me.stimuli.controlTable(n).delta = 1;
me.stimuli.controlTable(n).stimuli = 1;
me.stimuli.controlTable(n).limits = [0.25 20];

%this allows us to enable subsets from our stimulus list
me.stimuli.stimulusSets = {[1],[1]};
me.stimuli.setChoice = 1;
showSet(me.stimuli);

%----------------------State Machine States-------------------------
% me = runExperiment object
% io = digital I/O to recording system
% s  = PTB screenManager
% sM = State Machine
% eL = eyetracker manager
% t  = task sequence (stimulusSequence class)
% rM = Reward Manager (LabJack or Arduino TTL trigger to Crist reward system/Magstim)
% bR = behavioural record plot (on screen GUI during task run)
% me.stimuli = our list of stimuli
% tS = general struct to hold variables for this run

%pause entry
pauseEntryFcn = @()setOffline(eL);

%prestim entry
psEntryFcn = { @()setOffline(eL); ...
	@()trackerDrawFixation(eL); ...
	@()resetFixation(eL); ...
	@()startRecording(eL)
	};

%prestimulus blank
prestimulusFcn = @()drawBackground(s);

%exiting prestimulus state
psExitFcn = { 
	@()update(me.stimuli); ...
	@()statusMessage(eL,'Showing Fixation Spot...'); ...
};

%what to run when we enter the stim presentation state
stimEntryFcn = {};

%what to run when we are showing stimuli
stimFcn = { @()draw(me.stimuli); ... 
	%@()drawEyePosition(eL); ...
	@()finishDrawing(s); ...
	@()animate(me.stimuli); ... % animate stimuli for subsequent draw
	};

%test we are maintaining fixation
maintainFixFcn = {@()testSearchHoldFixation(eL,'correct','breakfix');};

%as we exit stim presentation state
stimExitFcn = {};

%if the subject is correct (small reward)
correctEntryFcn = { 
	@()timedTTL(rM,2,tS.rewardTime); ... 
	@()updatePlot(bR, eL, sM); ...
	@()statusMessage(eL,'Correct! :-)');
};

%correct stimulus
correctFcn = { @()drawBackground(s); @()drawGreenSpot(s,1) };

%when we exit the correct state
correctExitFcn = {};

%break entry
breakEntryFcn = { @()updatePlot(bR, eL, sM); ...
	@()statusMessage(eL,'Broke Fixation :-(') };

%break entry
incorrectFcn = { @()updatePlot(bR, eL, sM); ...
	@()statusMessage(eL,'Incorrect :-(') };

%our incorrect stimulus
breakFcn =  { @()drawBackground(s)}; % @()drawGreenSpot(s,1) };

%calibration function
calibrateFcn = {@()trackerSetup(eL);};

%flash function
flashFcn = {@()flashScreen(s,0.25);};

% allow override
overrideFcn = {@()keyOverride(obj);};

%show 1deg size grid
gridFcn = { @()drawGrid(s); @()drawScreenCenter(s) };

%----------------------State Machine Table-------------------------
disp('================>> Building state info file <<================')
%specify our cell array that is read by the stateMachine
stateInfoTmp = { ...
'name'      'next'			'time'  'entryFcn'		'withinFcn'		'transitionFcn'	'exitFcn'; ...
'pause'		'blank'			[inf] 	pauseEntryFcn	[]				[]				[]; ...
'blank'		'stimulus'		[2 6]	psEntryFcn		prestimulusFcn	[]				psExitFcn; ...
'stimulus'  'incorrect'		4		stimEntryFcn	stimFcn			maintainFixFcn	stimExitFcn; ...
'incorrect'	'blank'			1		incorrectFcn	breakFcn		[]				[]; ...
'breakfix'	'blank'			2		breakEntryFcn	breakFcn		[]				[]; ...
'correct'	'blank'			1		correctEntryFcn	correctFcn		[]				correctExitFcn; ...
'calibrate' 'pause'			0.5		calibrateFcn	[]				[]				[]; ...
'flash'		'pause'			0.5		[]				flashFcn		[]				[]; ...
'override'	'pause'			0.5		[]				overrideFcn		[]				[]; ...
'showgrid'	'pause'			1		[]				gridFcn			[]				[]; ...
};

disp(stateInfoTmp)
disp('================>> Building state info file <<================')
clear maintainFixFcn prestimulusFcn singleStimulus ...
	prestimulusFcn stimFcn stimEntryFcn stimExitfcn correctEntry correctWithin correctExit ...
	incorrectFcn calibrateFcn gridFcn overrideFcn flashFcn breakFcn
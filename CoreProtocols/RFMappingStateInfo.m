%=====RF Mapping state configuration file=====
%------------General Settings-----------------
tS.rewardTime = 200; %TTL time in milliseconds
tS.useTask = false;
tS.checkKeysDuringStimulus = true;
tS.recordEyePosition = false;
tS.askForComments = false;
tS.saveData = false;

obj.useDataPixx = false; %make sure we don't trigger the plexon

%------------Eyelink Settings----------------
fixX = 0;
fixY = 0;
firstFixInit = 0.75;
firstFixTime = 2.5;
firstFixRadius = 1.5;
if tS.saveData == true; eL.recordData = true; end% save EDF file?
eL.isDummy = false; %use dummy or real eyelink?
eL.sampleRate = 250;
eL.remoteCalibration = true; %manual calibration
eL.calibrationStyle = 'HV9'; % calibration style
eL.modify.calibrationtargetcolour = [1 1 0];
eL.modify.calibrationtargetsize = 1;
eL.modify.calibrationtargetwidth = 0.01;
eL.modify.waitformodereadytime = 500;
eL.modify.devicenumber = -1; % -1==use any keyboard
% X, Y, FixInitTime, FixTime, Radius, StrictFix
eL.updateFixationValues(fixX, fixY, firstFixInit, firstFixTime, firstFixRadius, true);

%-------randomise stimulus variables every trial?
obj.stimuli.choice = [];
n = 1;
in(n).name = 'xyPosition';
in(n).values = [6 6; 6 -6; -6 6; -6 -6; -6 0; 6 0];
in(n).stimuli = [2 3 4 5 6 7 8 9];
in(n).offset = [];
obj.stimuli.stimulusTable = in;

%--------allows using arrow keys to control this table during presentation
obj.stimuli.tableChoice = 1;
n=1;
obj.stimuli.controlTable(n).variable = 'angle';
obj.stimuli.controlTable(n).delta = 15;
obj.stimuli.controlTable(n).stimuli = [6 7 8 9 10];
obj.stimuli.controlTable(n).limits = [0 360];
n=n+1;
obj.stimuli.controlTable(n).variable = 'size';
obj.stimuli.controlTable(n).delta = 0.5;
obj.stimuli.controlTable(n).stimuli = [2 3 4 5 6 7 8 9 10];
obj.stimuli.controlTable(n).limits = [0.5 20];
n=n+1;
obj.stimuli.controlTable(n).variable = 'flashTime';
obj.stimuli.controlTable(n).delta = 0.1;
obj.stimuli.controlTable(n).stimuli = [1 2 3 4 5 6];
obj.stimuli.controlTable(n).limits = [0.1 1];
n=n+1;
obj.stimuli.controlTable(n).variable = 'barLength';
obj.stimuli.controlTable(n).delta = 0.5;
obj.stimuli.controlTable(n).stimuli = [9];
obj.stimuli.controlTable(n).limits = [0.5 20];
n=n+1;
obj.stimuli.controlTable(n).variable = 'barWidth';
obj.stimuli.controlTable(n).delta = 0.5;
obj.stimuli.controlTable(n).stimuli = [9];
obj.stimuli.controlTable(n).limits = [0.2 10];
n=n+1;
obj.stimuli.controlTable(n).variable = 'tf';
obj.stimuli.controlTable(n).delta = 0.1;
obj.stimuli.controlTable(n).stimuli = [7 8];
obj.stimuli.controlTable(n).limits = [0 6];
n=n+1;
obj.stimuli.controlTable(n).variable = 'sf';
obj.stimuli.controlTable(n).delta = 0.1;
obj.stimuli.controlTable(n).stimuli = [7 8];
obj.stimuli.controlTable(n).limits = [0.1 6];

%------this allows us to enable subsets from our stimulus list
obj.stimuli.stimulusSets = {[11], [2 11], [3 11], [4 11], [5 11], [6 11], [7 11], [8 11], [9 11], [10 11]};
obj.stimuli.setChoice = 1;
showSet(obj.stimuli);

%-------------------State Machine Control Functions------------------
% these are our functions that will execute as the stateMachine runs,
% in the scope of the runExperiemnt object.
% io = datapixx (digital I/O to plexon)
% s = screenManager
% sM = State Machine
% eL = eyelink manager
% lJ = LabJack (reward trigger to Crist reward system)
% bR = behavioural record plot
%--------------------------------------------------------------------
%pause entry
pauseEntryFcn = @()setOffline(eL);

%prestim entry
psEntryFcn = { @()setOffline(eL); ...
	@()trackerDrawFixation(eL); ...
	@()resetFixation(eL); ...
	@()randomise(obj.stimuli) };

%prestimulus blank
prestimulusFcn = @()drawBackground(s);

%exiting prestimulus state
psExitFcn = { @()update(obj.stimuli); ...
	@()statusMessage(eL,'Showing Fixation Spot...'); ...
	@()startRecording(eL) };

%what to run when we enter the stim presentation state
stimEntryFcn = [];

%what to run when we are showing stimuli
stimFcn = { @()draw(obj.stimuli); ...	@()drawEyePosition(eL); ...
	@()finishDrawing(s); ...
	@()animate(obj.stimuli); ... % animate stimuli for subsequent draw
	};

%test we are maintaining fixation
maintainFixFcn = @()testSearchHoldFixation(eL,'correct','breakfix');

%as we exit stim presentation state
stimExitFcn = [];

%if the subject is correct (small reward)
correctEntryFcn = { @()timedTTL(lJ,0,tS.rewardTime); ... 
	@()updatePlot(bR, eL, sM); ...
	@()statusMessage(eL,'Correct! :-)')};

%correct stimulus
correctFcn = { @()drawBackground(s); @()drawGreenSpot(s,1) };

%when we exit the correct state
correctExitFcn = [];

%break entry
breakEntryFcn = { @()updatePlot(bR, eL, sM); ...
	@()statusMessage(eL,'Broke Fixation :-(') };

%break entry
incorrectFcn = { @()updatePlot(bR, eL, sM); ...
	@()statusMessage(eL,'Incorrect :-(') };

%our incorrect stimulus
breakFcn =  @()drawBackground(s);

%calibration function
calibrateFcn = @()trackerSetup(eL);

%flash function
flashFcn = @()flashScreen(s,0.2);

% allow override
overrideFcn = @()keyOverride(obj);

%show 1deg size grid
gridFcn = { @()drawGrid(s); @()drawScreenCenter(s) };

%----------------------State Machine Table-------------------------
disp('================>> Building state info file <<================')
%specify our cell array that is read by the stateMachine
stateInfoTmp = { ...
'name'      'next'			'time'  'entryFcn'		'withinFcn'		'transitionFcn'	'exitFcn'; ...
'pause'		'blank'			[inf] 	pauseEntryFcn	[]				[]				[]; ...
'blank'		'stimulus'		0.5		psEntryFcn		prestimulusFcn	[]				psExitFcn; ...
'stimulus'  'incorrect'		3		stimEntryFcn	stimFcn			maintainFixFcn	stimExitFcn; ...
'incorrect'	'blank'			1		incorrectFcn	breakFcn		[]				[]; ...
'breakfix'	'blank'			1		breakEntryFcn	breakFcn		[]				[]; ...
'correct'	'blank'			0.5		correctEntryFcn	correctFcn		[]				correctExitFcn; ...
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
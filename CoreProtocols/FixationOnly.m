%RF Mapping state configuration file
%------------General Settings-----------------
rewardTime = 900; %TTL time in milliseconds
useTask = false;

eL.isDummy = false; %use dummy or real eyelink?
eL.sampleRate = 250;
eL.remoteCalibration = true; %manual calibration
eL.calibrationStyle = 'HV9'; % calibration style
eL.recordData = false; % don't save EDF fileo
eL.modify.calibrationtargetcolour = [1 1 0];
eL.modify.calibrationtargetsize = 1;
eL.modify.calibrationtargetwidth = 0.01;
eL.modify.waitformodereadytime = 500;
eL.modify.devicenumber = -1; % -1==use any keyboard
eL.fixationX = 0;
eL.fixationY = 0;
eL.fixationRadius = 2;
eL.fixationInitTime = 2.0;
eL.fixationTime = 3.0;
eL.strictFixation = true;

%randomise stimulus variables every trial?
obj.stimuli.choice = [];
n = 1;
in(n).name = 'xyPosition';
in(n).values = [0 0;];
in(n).stimuli = [1];
in(n).offset = [];
obj.stimuli.stimulusTable = in;

%allows using arrow keys to control this table
obj.stimuli.tableChoice = 1;
n=1;
obj.stimuli.controlTable(n).variable = 'angle';
obj.stimuli.controlTable(n).delta = 15;
obj.stimuli.controlTable(n).stimuli = [6 7 8];
obj.stimuli.controlTable(n).limits = [0 360];

%this allows us to enable subsets from our stimulus list
obj.stimuli.stimulusSets = {[1],[1]};
obj.stimuli.setChoice = 1;
showSet(obj.stimuli);

%----------------------State Machine States-------------------------
% io = datapixx (digital I/O to plexon)
% s = screenManager
% sM = State Machine
% eL = eyelink manager
% lJ = LabJack (reward trigger to Crist reward system)
% bR = behavioural record plot
% these are our functions that will execute as the stateMachine runs,
% in the scope of the runExperiemnt object.

%pause entry
pauseEntryFcn = @()setOffline(eL);

%prestim entry
psEntryFcn = { @()setOffline(eL); ...
	@()trackerDrawFixation(eL); ...
	@()resetFixation(eL); ...
	};

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
correctEntryFcn = { @()timedTTL(lJ,0,rewardTime); ... 
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
breakFcn =  { @()drawBackground(s)}; % @()drawGreenSpot(s,1) };

%calibration function
calibrateFcn = @()trackerSetup(eL);

%flash function
flashFcn = @()flashScreen(s,0.25);

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
'stimulus'  'incorrect'		4		stimEntryFcn	stimFcn			maintainFixFcn	stimExitFcn; ...
'incorrect'	'blank'			1		incorrectFcn	breakFcn		[]				[]; ...
'breakfix'	'blank'			4		breakEntryFcn	breakFcn		[]				[]; ...
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
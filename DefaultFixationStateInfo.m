%DEFAULT Fixation Training state configuration file 

%------------General Settings-----------------
rewardTime = 200; %TTL time in milliseconds

el.isDummy = true; %use dummy or real eyelink?
el.sampleRate = 250;
el.remoteCalibration = true; %manual calibration
el.calibrationStyle = 'HV9'; % calibration style
el.recordData = false; % don't save EDF file
el.modify.calibrationtargetcolour = [1 1 0];
el.modify.calibrationtargetsize = 1;
el.modify.calibrationtargetwidth = 0.01;
el.modify.waitformodereadytime = 500;
el.modify.devicenumber = -1; % -1 = use any keyboard
el.fixationX = 0;
el.fixationY = 0;
el.fixationRadius = 1.5;
el.fixationInitTime = 1.0;
el.fixationTime = 1.0;
el.strictFixation = true;

%randomise variables during run?
obj.stimuli.choice = [];
in(1).name = 'xyPosition';
in(1).values = [8 8; 8 -8; -8 8; -8 -8];
in(1).stimuli = [1 2];
in(2).name = 'angle';
in(2).values = [0 22.5 45 67.5 90];
in(2).stimuli = [1 2];
%in(2).name = 'contrast';
%in(2).values = [0.2 0.8];
%in(2).stimuli = [2];
obj.stimuli.stimulusTable = in;

%allows using arrow keys to control this table
obj.stimuli.controlTable(1).variable = 'angle';
obj.stimuli.controlTable(1).delta = 15;
obj.stimuli.controlTable(1).stimuli = [1 2];
obj.stimuli.controlTable(1).limits = [0 360];
obj.stimuli.controlTable(2).variable = 'size';
obj.stimuli.controlTable(2).delta = 1;
obj.stimuli.controlTable(2).stimuli = [1 2];
obj.stimuli.controlTable(2).limits = [1 60];
obj.stimuli.controlTable(3).variable = 'barLength';
obj.stimuli.controlTable(3).delta = 0.5;
obj.stimuli.controlTable(3).stimuli = [2];
obj.stimuli.controlTable(3).limits = [1 30];
obj.stimuli.tableChoice = 1;

%this allows us to enable subsets from our stimulus list
obj.stimuli.stimulusSets = {[1 2 3],[3],[1 3]};
obj.stimuli.setChoice = 1;
showSet(obj.stimuli);

%----------------------State Machine States-------------------------
% io = datapixx (digital I/O to plexon)
% s = screenManager
% sm = State Machine
% el = eyelink manager
% lj = LabJack (reward trigger to Crist reward system)
% bR = behavioural record plot
% these are our functions that will execute as the stateMachine runs,
% in the scope of the runExperiemnt object.

%pause entry
pauseEntryFcn = @()setOffline(el);

%prestim entry
psEntryFcn = { @()setOffline(el); ...
	@()trackerDrawFixation(el); ...
	@()resetFixation(el); ...
	@()randomise(obj.stimuli) };

%prestimulus blank
prestimulusFcn = @()drawBackground(s);

psExitFcn = { @()update(obj.stimuli); ...
	@()startRecording(el); ...
	@()statusMessage(el,'Showing Fixation Spot...'); ...
	@()startRecording(el) };

%what to run when we enter the stim presentation state
stimEntryFcn = [];

%what to run when we are showing stimuli
stimFcn = @()draw(obj.stimuli); %obj.stimuli is the stimuli loaded into opticka

%test we are maintaining fixation
maintainFixFcn = @()testSearchHoldFixation(el,'correct','breakfix');

%as we exit stim presentation state
stimExitFcn = [];

%if the subject is correct (small reward)
correctEntryFcn = { @()timedTTL(lj,0,rewardTime); ... 
	@()updatePlot(bR, el, sm); ...
	@()statusMessage(el,'Correct! :-)')};

%correct stimulus
correctFcn = { @()drawBackground(s); @()drawGreenSpot(s,1) };

%when we exit the correct state
correctExitFcn = [];

%break entry
breakEntryFcn = { @()updatePlot(bR, el, sm); ...
	@()statusMessage(el,'Broke Fixation :-(') };

%our incorrect stimulus
breakFcn =  @()drawBackground(s);

%calibration function
calibrateFcn = @()trackerSetup(el);

overrideFcn = @()keyOverride(obj);

flashFcn = @()flashScreen(s, 0.25);

disp('================>> Loading state info file <<================')
%specify our cell array that is read by the stateMachine
stateInfoTmp = { ...
'name'      'next'			'time'  'entryFcn'		'withinFcn'		'transitionFcn'	'exitFcn'; ...
'pause'		'prestimulus'	inf		pauseEntryFcn	[]				[]				[]; ...
'prestimulus' 'stimulus'	[0.5 1]	psEntryFcn		prestimulusFcn	[]				psExitFcn; ...
'stimulus'  'breakfix'		4		stimEntryFcn	stimFcn			maintainFixFcn	stimExitFcn; ...
'breakfix'	'prestimulus'	0.5		breakEntryFcn	breakFcn		[]				[]; ...
'correct'	'prestimulus'	0.5		correctEntryFcn	correctFcn		[]				correctExitFcn; ...
'calibrate' 'prestimulus'	0.5		calibrateFcn	[]				[]				[]; ...
'override'	'prestimulus'	0.5		overrideFcn		[]				[]				[]; ...
'flash'		'prestimulus'	0.5		flashFcn		[]				[]				[]; ...
};

disp(stateInfoTmp)
disp('================>> Loaded state info file  <<================')
clear maintainFixFcn prestimulusFcn singleStimulus ...
	prestimulusFcn stimFcn stimEntryFcn stimExitfcn correctEntry correctWithin correctExit ...
	incorrectFcn calibrateFcn
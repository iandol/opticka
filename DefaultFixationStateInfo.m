%Fixation Training state configuration file 

rewardTime = 300; %TTL time in milliseconds

obj.eyeLink.remoteCalibration = true; %manual calibration
obj.eyeLink.calibrationStyle = 'HV9'; % 5 point calibration
obj.eyeLink.recordData = false; % don't save EDF file
obj.eyeLink.modify.calibrationtargetcolour = [1 1 0];
obj.eyeLink.modify.calibrationtargetsize = 3;
obj.eyeLink.modify.calibrationtargetwidth = 3;
obj.eyeLink.modify.waitformodereadytime = 500;
obj.eyeLink.modify.devicenumber = -1; % -1 = use any keyboard

obj.eyeLink.fixationX = 0;
obj.eyeLink.fixationY = 0;
obj.eyeLink.fixationRadius = 1.5;
obj.eyeLink.fixationInitTime = 1.0;
obj.eyeLink.fixationTime = 1.0;
obj.eyeLink.strictFixation = true;

obj.stimuli.choice = [];
in(1).name = 'xyPosition';
in(1).values = [8 8; 8 -8; -8 8; -8 -8];
in(1).stimuli = [1];
%in(2).name = 'angle';
%in(2).values = [0 22.5 45 67.5 90];
%in(2).stimuli = [2];
%in(2).name = 'contrast';
%in(2).values = [0.2 0.8];
%in(2).stimuli = [2];
obj.stimuli.stimulusTable = in;

obj.stimuli.controlTable(1).variable = 'angle';
obj.stimuli.controlTable(1).delta = '15';
obj.stimuli.controlTable(1).stimuli = [1 2];
obj.stimuli.controlTable(1).limits = [0 360];
obj.stimuli.controlTable(2).variable = 'size';
obj.stimuli.controlTable(2).delta = '2';
obj.stimuli.controlTable(2).stimuli = [1 2];
obj.stimuli.controlTable(2).limits = [1 20];

obj.stimuli.stimulusSets = {[1 2],[2],[1 2 3]};
obj.stimuli.setChoice = 1;

%these are our functions that will execute as the stateMachine runs,
%this be in the scope of the runExperiemnt object.

%pause entry
pauseEntryFcn = @()setOffline(obj.eyeLink);

%prestim entry
psEntryFcn = { @()setOffline(obj.eyeLink); ...
	@()trackerDrawFixation(obj.eyeLink); ...
	@()resetFixation(obj.eyeLink) };

%prestimulus blank
prestimulusFcn = @()drawBackground(obj.screen);

psExitFcn = { @()update(obj.stimuli); ...
	@()startRecording(obj.eyeLink); ...
	@()statusMessage(obj.eyeLink,'Showing Fixation Spot...') };

%what to run when we enter the stim presentation state
stimEntryFcn = [];

%what to run when we are showing stimuli
stimFcn = @()draw(obj.stimuli); %obj.stimuli is the stimuli loaded into opticka

%test we are maintaining fixation
maintainFixFcn = @()testSearchHoldFixation(obj.eyeLink,'correct','breakfix');

%as we exit stim presentation state
stimExitFcn = [];

%if the subject is correct (small reward)
correctEntryFcn = { @()timedTTL(obj.lJack,0,rewardTime); ... 
	@()updatePlot(obj.behaviouralRecord,obj.eyeLink,obj.stateMachine); ...
	@()statusMessage(obj.eyeLink,'Correct! :-)')};

%correct stimulus
correctFcn = { @()drawBackground(obj.screen); @()drawGreenSpot(obj.screen,1) };

%when we exit the correct state
correctExitFcn = [];

%break entry
breakEntryFcn = { @()updatePlot(obj.behaviouralRecord,obj.eyeLink,obj.stateMachine); ...
	@()statusMessage(obj.eyeLink,'Broke Fixation :-(') };

%our incorrect stimulus
breakFcn =  @()drawBackground(obj.screen);

%calibration function
calibrateFcn = @()trackerSetup(obj.eyeLink);

disp('================>> Loading state info file <<================')
%specify our cell array that is read by the stateMachine
stateInfoTmp = { ...
'name'      'next'			'time'  'entryFcn'		'withinFcn'		'transitionFcn'	'exitFcn'; ...
'pause'		'prestimulus'	inf		pauseEntryFcn	[]				[]				[]; ...
'prestimulus' 'stimulus'	4		psEntryFcn		prestimulusFcn	[]				psExitFcn; ...
'stimulus'  'breakfix'		3		stimEntryFcn	stimFcn			maintainFixFcn	stimExitFcn; ...
'breakfix'	'prestimulus'	0.5		breakEntryFcn	breakFcn		[]				[]; ...
'correct'	'prestimulus'	0.5		correctEntryFcn	correctFcn		[]				correctExitFcn; ...
'calibrate' 'prestimulus'	0.5		calibrateFcn	[]				[]				[]; ...
};

disp(stateInfoTmp)
disp('================>> Loaded state info file  <<================')
clear maintainFixFcn prestimulusFcn singleStimulus ...
	prestimulusFcn stimFcn stimEntryFcn stimExitfcn correctEntry correctWithin correctExit ...
	incorrectFcn calibrateFcn
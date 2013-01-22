%Fixation Training state configuration file 
%This controls a stateMachine instance, switching between these states and 
%executing functions. This will be run in the scope of the calling
%runFixationSession function and thus obj.screen and friends will be
%available at run time.

% do we want to present a single stimulus at a time?
singleStimulus = true;
if singleStimulus == true
	obj.stimList = 1:obj.stimuli.n;
	obj.thisStim = 1;
else
	obj.stimList = [];
	obj.thisStim = [];
end
obj.stimuli.choice = obj.thisStim;

rewardTime = 400;

obj.eyeLink.remoteCalibration = true;
obj.eyeLink.calibrationStyle = 'HV5';
obj.eyeLink.recordData = false;
obj.eyeLink.modify.calibrationtargetcolour = [1 1 0];
obj.eyeLink.modify.calibrationtargetsize = 3;
obj.eyeLink.modify.calibrationtargetwidth = 3;
obj.eyeLink.modify.waitformodereadytime = 500;
obj.eyeLink.modify.devicenumber = -1;

obj.eyeLink.fixationX = 0;
obj.eyeLink.fixationX = 0;
obj.eyeLink.fixationTime = 0.6;
obj.eyeLink.fixationRadius = 1.5;
obj.eyeLink.fixationInitTime = 1;

%===these are our functions that will execute as the stateMachine runs

%prestim entry
psEntryFcn = { @()resetFixation(obj.eyeLink); @()setOffline(obj.eyeLink); ...
	@()trackerDrawFixation(obj.eyeLink) };

%prestimulus blank
prestimulusFcn = @()drawBackground(obj.screen);

psExitFcn = { @()update(obj.stimuli); @()startRecording(obj.eyeLink); @()statusMessage(obj.eyeLink,'Showing Stimulus...') };

%what to run when we enter the stim presentation state
stimEntryFcn = [];

%what to run when we are showing stimuli
stimFcn = @()draw(obj.stimuli); %obj.stimuli is the stimuli loaded into opticka

%test we are maintaining fixation
maintainFixFcn = @()testSearchHoldFixation(obj.eyeLink,'correct','breakfix');

%as we exit stim presentation state
stimExitFcn = [];

%if the subject is correct (small reward)
correctEntryFcn = { @()draw(obj.stimuli); @()timedTTL(obj.lJack,0,rewardTime); ... 
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
'pause'		'prestimulus'	inf		[]				[]				[]				[]; ...
'prestimulus' 'stimulus'	1		psEntryFcn		prestimulusFcn	[]				psExitFcn; ...
'stimulus'  'breakfix'		3		stimEntryFcn	stimFcn			maintainFixFcn	stimExitFcn; ...
'breakfix'	'prestimulus'	1.5		breakEntryFcn	breakFcn		[]				[]; ...
'correct'	'prestimulus'	1.5		correctEntryFcn	correctFcn		[]				correctExitFcn; ...
'calibrate' 'prestimulus'	0.5		calibrateFcn	[]				[]				[]; ...
};

disp(stateInfoTmp)
disp('================>> Loaded state info file  <<================')
clear maintainFixFcn prestimulusFcn singleStimulus ...
	prestimulusFcn stimFcn stimEntryFcn stimExitfcn correctEntry correctWithin correctExit ...
	incorrectFcn calibrateFcn
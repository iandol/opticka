%Default state configuration file for runExperiment.runTrainingSession. 
%This controls a stateMachine instance, switching between these states and 
%executing functions. This will be run in the scope of the calling
%runTrainingSession function and thus obj.screen and friends will be
%available at run time.
disp('================>> Loading state info file <<================')

%--------------present a single stimulus at a time?-------------------
singleStimulus = false;
if singleStimulus == true
	obj.stimList = 1:obj.stimuli.n;
	obj.thisStim = 1;
else
	obj.stimList = [];
	obj.thisStim = [];
end
obj.stimuli.choice = obj.thisStim;

%------------------------Eyelink setup--------------------------
obj.useEyeLink = true;
rewardTime = 200; %TTL time in milliseconds

obj.eyeLink.sampleRate = 250;
obj.eyeLink.remoteCalibration = true; %manual calibration
obj.eyeLink.calibrationStyle = 'HV9'; % 5 point calibration
obj.eyeLink.recordData = false; % don't save EDF file
obj.eyeLink.modify.calibrationtargetcolour = [1 1 0];
obj.eyeLink.modify.calibrationtargetsize = 5;
obj.eyeLink.modify.calibrationtargetwidth = 0.1;
obj.eyeLink.modify.waitformodereadytime = 500;
obj.eyeLink.modify.devicenumber = -1; % -1==use any keyboard

obj.eyeLink.fixationX = 0;
obj.eyeLink.fixationY = 0;
obj.eyeLink.fixationRadius = 1.25;
obj.eyeLink.fixationInitTime = 0.6;
obj.eyeLink.fixationTime = 2.0;
obj.eyeLink.strictFixation = true;

%----------------------State Machine States-------------------------
%these are our functions that will execute as the stateMachine runs

%reset the fixation time values
preEntryFcn = {@()setOffline(obj.eyeLink); ...
	@()trackerDrawFixation(obj.eyeLink); ...
	@()resetFixation(obj.eyeLink); ...
	@()update(obj.stimuli); 
	@()setStrobeValue(obj, 300); };

%prestimulus blank
preFcn = []; 

%exit prestimulus
preExit = { @()update(obj.stimuli); ...
	@()statusMessage(obj.eyeLink,'Showing Fixation Spot...'); ...
	@()startRecording(obj.eyeLink) };

%setup our fixate function before stimulus presentation
fixEntryFcn = @()updateFixationValues(obj.eyeLink, 0.6, 0.2, 1.25, true);

% draw fixate stimulus
fixFcn = @()drawRedSpot(obj.screen,1);

fixExitFcn = @()updateFixationValues(obj.eyeLink, 0.6, 2, 1.25, true);

%test we are fixated for a certain length of time
initFixFcn = @()testSearchHoldFixation(obj.eyeLink,'stimulus','');

%what to run when we are showing stimuli; obj.stimuli is the stimuli loaded into opticka
stimFcn = { @()draw(obj.stimuli); @()drawRedSpot(obj.screen,1); @()drawEyePosition(obj.eyeLink) }; 

%what to run when we enter the stim presentation state
stimEntryFcn = @()doStrobe(obj,true);

%as we exit stim presentation state
stimExitFcn = { @()setStrobeValue(obj,inf); @()doStrobe(obj,true) };

%test we are maintaining fixation
maintainFixFcn = @()testWithinFixationWindow(obj.eyeLink,'yes','breakfix');

%if the subject is correct 
correctEntry = { @()timedTTL(obj.lJack,0,rewardTime); ...
	@()updatePlot(obj.behaviouralRecord,obj.eyeLink,obj.stateMachine); ...
	@()statusMessage(obj.eyeLink,'Correct! :-)') };

%correct stimulus
correctWithin = { @()drawGreenSpot(obj.screen,1) };

%when we exit the correct state
correctExit = { @()randomiseTrainingList(obj); };

%break entry
breakEntryFcn = { @()updatePlot(obj.behaviouralRecord,obj.eyeLink,obj.stateMachine); ...
	@()statusMessage(obj.eyeLink,'Broke Fixation :-(') };

%our incorrect stimulus
incorrectFcn = [];

%calibration function
calibrateFcn = @()trackerSetup(obj.eyeLink);

%specify our cell array that is read by the stateMachine
stateInfoTmp = { ...
'name'      'next'			'time'  'entryFcn'		'withinFcn'		'transitionFcn'	'exitFcn'; ...
'pause'		'blank'			inf		[]				[]				[]				[]; ...
'blank'		'fixate'		0.5		preEntryFcn		preFcn			[]				preExit; ...
'fixate'	'breakfix'		1		fixEntryFcn		fixFcn			initFixFcn		[]; ...
'stimulus'  'correct'		2		stimEntryFcn	stimFcn			maintainFixFcn	stimExitFcn; ...
'breakfix'	'blank'			1		breakEntryFcn	incorrectFcn	[]				[]; ...
'correct'	'blank'			0.5		correctEntry	correctWithin	[]				correctExit; ...
'calibrate' 'pause'			0.5		calibrateFcn	[]				[]				[]; ...
};

disp(stateInfoTmp)
disp('================>> Loaded state info file  <<================')
clear initFixFcn maintainFixFcn prestimulusFcn singleStimulus ...
	preblankFcn stimFcn stimEntry correct1Fcn correct2Fcn ...
	incorrectFcn
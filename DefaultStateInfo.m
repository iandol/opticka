%Default state configuration file for runExperiment.runTrainingSession. 
%This controls a stateMachine instance, switching between these states and 
%executing functions. This will be run in the scope of the calling
%runTrainingSession function and thus obj.screen and friends will be
%available at run time.

%------------------------Eyelink setup--------------------------
obj.useEyeLink = true;
rewardTime = 100; %TTL time in milliseconds

eL.sampleRate = 250;
eL.remoteCalibration = true; %manual calibration
eL.calibrationStyle = 'HV9'; % 5 point calibration
eL.recordData = false; % don't save EDF file
eL.modify.calibrationtargetcolour = [1 1 0];
eL.modify.calibrationtargetsize = 1;
eL.modify.calibrationtargetwidth = 0.01;
eL.modify.waitformodereadytime = 500;
eL.modify.devicenumber = -1; % -1 == use any keyboard

eL.fixationX = 0;
eL.fixationY = 0;
eL.fixationRadius = 1;
eL.fixationInitTime = 0.6;
eL.fixationTime = 2.0;
eL.strictFixation = true;

%----------------------State Machine States-------------------------
%these are our functions that will execute as the stateMachine runs
% io = datapixx (digital I/O to plexon)
% s = screenManager
% sm = State Machine
% lj = LabJack (reward trigger to Crist reward system)

%pause entry
pauseEntryFcn =  { @()disableFlip(obj); @()setOffline(eL); @()rstop(io) }; %lets pause the plexon!

%pause exit
pauseExitFcn = @()rstart(io); %lets unpause the plexon!

%reset the fixation time values
blankEntryFcn = { @()disableFlip(obj); ...
	@()setOffline(eL); ...
	@()trackerDrawFixation(eL); ...
	@()resetFixation(eL); ...
	@()update(obj.stimuli); 
	@()setStrobeValue(obj, 300); };

%prestimulus blank
blankFcn = []; 

%exit prestimulus
blankExitFcn = { @()update(obj.stimuli); ...
	@()statusMessage(el,'Showing Fixation Spot...'); ...
	@()startRecording(el) };

%setup our fixate function before stimulus presentation
fixEntryFcn = { @()enableFlip(obj); @()updateFixationValues(eL, 0, 0, 0.7, 0.3, 1.25, false) };

% draw fixate stimulus
fixFcn = @()drawRedSpot(s, 0.5); %1 = size of red spot

fixExitFcn = @()updateFixationValues(eL, 0, 0, 0.6, 2, 1.25, true);

%test we are fixated for a certain length of time
initFixFcn = @()testSearchHoldFixation(eL,'stimulus','');

%what to run when we enter the stim presentation state
stimEntryFcn = @()doStrobe(obj,true);

%what to run when we are showing stimuli; obj.stimuli is the stimuli loaded into opticka
stimFcn = { @()draw(obj.stimuli); }; 

%as we exit stim presentation state
stimExitFcn = { @()setStrobeValue(obj,inf); @()doStrobe(obj,true) };

%test we are maintaining fixation
maintainFixFcn = @()testWithinFixationWindow(eL,'yes','breakfix');

%if the subject is correct 
correctEntry = { @()timedTTL(lj,0,rewardTime); ...
	@()updatePlot(bR, eL, sM); ...
	@()statusMessage(eL,'Correct! :-)') };

%correct stimulus
correctWithin = { @()drawGreenSpot(s,1) };

%when we exit the correct state
correctExit = { @()randomiseTrainingList(obj); };

%break entry
breakEntryFcn = { @()sendTTL(io,6); @()disableFlip(obj); ...
	@()updatePlot(bR, eL, sM); ...
	@()statusMessage(eL,'Broke Fixation :-(') };

%our incorrect stimulus
breakFcn = [];

%calibration function
calibrateFcn = { @()setOffline(eL); @()rstop(io); @()trackerSetup(eL) };

%specify our cell array that is read by the stateMachine
stateInfoTmp = { ...
'name'      'next'			'time'  'entryFcn'		'withinFcn'		'transitionFcn'	'exitFcn'; ...
'pause'		'blank'			inf		pauseEntryFcn	[]				[]				[]; ...
'blank'		'fixate'		0.5		blankEntryFcn	blankFcn		[]				blankExitFcn; ...
'fixate'	'breakfix'		1		fixEntryFcn		fixFcn			initFixFcn		fixExitFcn; ...
'stimulus'  'correct'		2		stimEntryFcn	stimFcn			maintainFixFcn	stimExitFcn; ...
'breakfix'	'blank'			1		breakEntryFcn	breakFcn		[]				[]; ...
'correct'	'blank'			0.5		correctEntry	correctWithin	[]				correctExit; ...
'calibrate' 'pause'			0.5		calibrateFcn	[]				[]				[]; ...
};

disp(stateInfoTmp)
disp('================>> Loaded state info file  <<================')
clear initFixFcn maintainFixFcn prestimulusFcn singleStimulus ...
	preblankFcn stimFcn stimEntry correct1Fcn correct2Fcn ...
	incorrectFcn
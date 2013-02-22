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
rewardTime = 100; %TTL time in milliseconds

obj.eyeLink.sampleRate = 250;
obj.eyeLink.remoteCalibration = true; %manual calibration
obj.eyeLink.calibrationStyle = 'HV9'; % 5 point calibration
obj.eyeLink.recordData = false; % don't save EDF file
obj.eyeLink.modify.calibrationtargetcolour = [1 1 0];
obj.eyeLink.modify.calibrationtargetsize = 1;
obj.eyeLink.modify.calibrationtargetwidth = 0.01;
obj.eyeLink.modify.waitformodereadytime = 500;
obj.eyeLink.modify.devicenumber = -1; % -1 == use any keyboard

obj.eyeLink.fixationX = 0;
obj.eyeLink.fixationY = 0;
obj.eyeLink.fixationRadius = 1;
obj.eyeLink.fixationInitTime = 0.6;
obj.eyeLink.fixationTime = 2.0;
obj.eyeLink.strictFixation = true;

%----------------------State Machine States-------------------------
%these are our functions that will execute as the stateMachine runs
% io = datapixx (digital I/O to plexon)
% s = screenManager
% sm = State Machine
% lj = LabJack (reward trigger to Crist reward system)

%pause entry
pauseEntryFcn =  { @()disableFlip(obj); @()setOffline(el); @()rstop(io) }; %lets pause the plexon!

%pause exit
pauseExitFcn = @()rstart(io); %lets unpause the plexon!

%reset the fixation time values
blankEntryFcn = { @()disableFlip(obj); ...
	@()setOffline(el); ...
	@()trackerDrawFixation(el); ...
	@()resetFixation(el); ...
	@()update(obj.stimuli); 
	@()setStrobeValue(obj, 300); };

%prestimulus blank
blankFcn = []; 

%exit prestimulus
blankExitFcn = { @()update(obj.stimuli); ...
	@()statusMessage(el,'Showing Fixation Spot...'); ...
	@()startRecording(el) };

%setup our fixate function before stimulus presentation
fixEntryFcn = { @()enableFlip(obj); @()updateFixationValues(el, 0, 0, 0.7, 0.3, 1.25, false) };

% draw fixate stimulus
fixFcn = @()drawRedSpot(s, 0.5); %1 = size of red spot

fixExitFcn = @()updateFixationValues(el, 0, 0, 0.6, 2, 1.25, true);

%test we are fixated for a certain length of time
initFixFcn = @()testSearchHoldFixation(el,'stimulus','');

%what to run when we enter the stim presentation state
stimEntryFcn = @()doStrobe(obj,true);

%what to run when we are showing stimuli; obj.stimuli is the stimuli loaded into opticka
stimFcn = { @()draw(obj.stimuli); }; 

%as we exit stim presentation state
stimExitFcn = { @()setStrobeValue(obj,inf); @()doStrobe(obj,true) };

%test we are maintaining fixation
maintainFixFcn = @()testWithinFixationWindow(el,'yes','breakfix');

%if the subject is correct 
correctEntry = { @()timedTTL(lj,0,rewardTime); ...
	@()updatePlot(obj.behaviouralRecord,obj.eyeLink,obj.stateMachine); ...
	@()statusMessage(el,'Correct! :-)') };

%correct stimulus
correctWithin = { @()drawGreenSpot(s,1) };

%when we exit the correct state
correctExit = { @()randomiseTrainingList(obj); };

%break entry
breakEntryFcn = { @()sendTTL(io,6); @()disableFlip(obj); ...
	@()updatePlot(obj.behaviouralRecord,obj.eyeLink,obj.stateMachine); ...
	@()statusMessage(el,'Broke Fixation :-(') };

%our incorrect stimulus
breakFcn = [];

%calibration function
calibrateFcn = { @()setOffline(el); @()rstop(io); @()trackerSetup(el) };

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
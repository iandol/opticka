%FIGURE GROUND state configuration file, this gets loaded by opticka via
%runExperiment class. The following class objects are already loaded and available to
%use: 
% io = datapixx (digital I/O to plexon)
% s = screenManager
% sM = State Machine
% eL = eyelink manager
% lJ = LabJack (reward trigger to Crist reward system)
% bR = behavioural record plot
% obj.stimuli = our list of stimuli
% tS = general simple struct to hold variables for this run

%------------General Settings-----------------
tS.rewardTime = 150; %TTL time in milliseconds
tS.useTask = true; %use stimulusSequence (randomised variable task object)
tS.checkKeysDuringStimulus = true; %==allow keyboard control? Slight drop in performance
tS.recordEyePosition = true; %==record eye position within PTB, **in addition** to the EDF?
tS.askForComments = true; %==little UI requestor asks for comments before/after run
tS.saveData = true; %==save behavioural and eye movement data?
obj.useDataPixx = true; %==drive plexon to collect data?
obj.useLabJack = true; %==used for rewards and to control magstim
tS.dummyEyelink = false; %==use mouse as a dummy eyelink, good for testing away from the lab.
tS.useMagStim = true; %enable the magstim manager
tS.name = 'figure-ground'; %==name of this protocol

%-----enable the magstimManager which uses FOI2 of the LabJack
if tS.useMagStim
	mS = magstimManager('lJ',lJ,'defaultTTL',2);
	mS.stimulateTime	= 240;
	mS.frequency		= 0.7;
	mS.rewardTime		= 25;
	open(mS);
end
				
%------------Eyetracker Settings-----------------
tS.luminancePedestal = [0.5 0.5 0.5]; %used during training, it sets the clip behind the figure to a different luminance which makes the figure more salient and thus easier to train to.
tS.fixX = 0;
tS.fixY = 0;
tS.firstFixInit = 0.6;
tS.firstFixTime = [0.5];
tS.firstFixRadius = 2;
obj.lastXPosition = tS.fixX;
obj.lastYPosition = tS.fixY;
tS.strict = true;

tS.targetFixInit = 3;
tS.targetFixTime = [0.2 0.5];
tS.targetRadius = 4;

%------------------------Eyelink setup--------------------------
eL.isDummy = tS.dummyEyelink; %use dummy or real eyelink?
eL.name = tS.name;
if tS.saveData == true; eL.recordData = true; end% save EDF file?
eL.sampleRate = 250;
eL.remoteCalibration = true; % manual calibration?
eL.calibrationStyle = 'HV5'; % calibration style
eL.modify.calibrationtargetcolour = [1 1 1];
eL.modify.calibrationtargetsize = 0.5;
eL.modify.calibrationtargetwidth = 0.1;
eL.modify.waitformodereadytime = 500;
eL.modify.devicenumber = -1; % -1 = use any keyboard

%Initialise the eyeLink object with X, Y, FixInitTime, FixTime, Radius, StrictFix
eL.updateFixationValues(tS.fixX, tS.fixY, tS.firstFixInit, tS.firstFixTime, tS.firstFixRadius, tS.strict);

%randomise stimulus variables every trial? useful during initial training but not for
%data collection.
obj.stimuli.choice = [];
obj.stimuli.stimulusTable = [];

% allows using arrow keys to control this table during the main loop
% ideal for mapping receptive fields so we can twiddle parameters, normally not used
% for normal tasks
obj.stimuli.controlTable = [];
obj.stimuli.tableChoice = 1;

% this allows us to enable subsets from our stimulus list. So each set is a
% particular display like fixation spot only, background. During the trial you can
% use the showSet method of obj.stimuli to change to a particular stimulus set.
% numbers are the stimuli in the opticka UI
obj.stimuli.stimulusSets = {[1,4],[1 2 3 4]};
obj.stimuli.setChoice = 1;
showSet(obj.stimuli);

%which stimulus in the list is used for a fixation target? For this protocol it means
%the subject must fixate this stimulus (the figure is #3 in the list) to get the
%reward.
obj.stimuli.fixationChoice = 3;

%----------------------State Machine States-------------------------
% these are our functions that will execute as the stateMachine runs,
% in the scope of the runExperiemnt object.

%pause entry
pauseEntryFcn = { @()rstop(io); ... %rstop is pause the plexon
	@()setOffline(eL); ... %set eyelink offline
	@()stopRecording(eL); ... %stop eye position recording
	@()edfMessage(eL,'TRIAL_RESULT -10'); ... %store message in EDF
	@()drawBackground(s); ... %blank the display
	@()disableFlip(obj); ... %stop screen updates
	}; 

%pause exit
pauseExitFcn = { @()rstart(io) };%lets unpause the plexon!

prefixEntryFcn = { @()enableFlip(obj); }; %enable stimulus flipping
prefixFcn = { @()draw(obj.stimuli) }; % draw our setimulus set.

%fixate entry
fixEntryFcn = { @()statusMessage(eL,'Initiate Fixation...'); ... %status text on the eyelink
	@()enableFlip(obj); 
	@()resetFixation(eL); ... %reset the fixation counters ready for a new trial
	@()setOffline(eL); ... %make sure offline before start recording
	@()edit(obj.stimuli,4,'colourOut',[1 1 0]); ... %edit fixation spot to be yellow
	@()show(obj.stimuli); ... %enable our stimulus set
	@()edfMessage(eL,'V_RT MESSAGE END_FIX END_RT'); ... %this 3 lines set the trial info for the eyelink
	@()edfMessage(eL,['TRIALID ' num2str(getTaskIndex(obj))]); ... %obj.getTaskIndex gives us which trial we're at
	@()edfMessage(eL,['UUID ' UUID(sM)]); ... %add in the uuid of the current state for good measure
	@()startRecording(eL); ... %fire up eyelink
	@()sendTTL(io,3); ... %send TTL on line 3 (pin 19)
	@()syncTime(eL); ... %EDF sync message
	@()draw(obj.stimuli); ... %draw stimulus
	};

%fix within
fixFcn = { @()draw(obj.stimuli) }; %draw stimulus

%test we are fixated for a certain length of time
initFixFcn = @()testSearchHoldFixation(eL,'stimulus','incorrect');

%exit fixation phase
fixExitFcn = { @()animate(obj.stimuli); ... % animate stimuli for subsequent draw
	@()updateFixationTarget(obj, tS.useTask, tS.targetFixInit, tS.targetFixTime, tS.targetRadius, tS.strict); ... %use our stimuli values for next fix X and Y
	@()updateFixationValues(eL, [], [], tS.targetFixInit, tS.targetFixTime, tS.targetRadius, tS.strict); ... %set target fix window
	@()statusMessage(eL,'Show Stimulus...'); ...
	@()edit(obj.stimuli,4,'colourOut',[0.65 0.65 0.45]); ... %dim fix spot
	@()edit(obj.stimuli,2,'modulateColourOut',tS.luminancePedestal); ... %luminance pedestal
	@()edfMessage(eL,'END_FIX'); ...
	};

%what to run when we enter the stim presentation state
stimEntryFcn = @()doStrobe(obj,true);

%what to run when we are showing stimuli
stimFcn =  { @()draw(obj.stimuli); ...	@()drawEyePosition(eL); ...
	@()finishDrawing(s); ...
	@()animate(obj.stimuli); ... % animate stimuli for subsequent draw
	};

%test we are maintaining fixation
maintainFixFcn = @()testSearchHoldFixation(eL,'correct','breakfix');

%as we exit stim presentation state
stimExitFcn = { @()setStrobeValue(obj,inf); @()doStrobe(obj,true) };

%if the subject is correct (small reward)
correctEntryFcn = { @()timedTTL(lJ,0,tS.rewardTime); ... % labjack sends a TTL to Crist reward system
	@()sendTTL(io,4); ... %send correct TTL to dataPixx->Plexon
	@()edfMessage(eL,'END_RT'); ...
	@()statusMessage(eL,'Correct! :-)'); ...
	@()drawTimedSpot(s, 0.5, [0 1 0 1]); ...
	@()hide(obj.stimuli{4}); ...
	@()stopRecording(eL); ...
	@()edfMessage(eL,'TRIAL_RESULT 1'); ...
	};

%correct stimulus
correctFcn = { @()draw(obj.stimuli); 
	@()drawTimedSpot(s, 0.5, [0 1 0 1]); ...
	};

%when we exit the correct state
correctExitFcn = { @()edit(obj.stimuli,2,'modulateColourOut',[0.5 0.5 0.5]); ... %luminance pedestal
	@()setOffline(eL); ... %set eyelink offline
	@()updateVariables(obj,[],[],true); ... %randomise our stimuli, set strobe value too
	@()update(obj.stimuli); ... %update our stimuli ready for display
	@()getStimulusPositions(obj.stimuli); ... %make a struct the eL can use for drawing stim positions
	@()updateFixationValues(eL, tS.fixX, tS.fixY, tS.firstFixInit, tS.firstFixTime, tS.firstFixRadius, tS.strict); ...
	@()trackerClearScreen(eL); ... 
	@()trackerDrawFixation(eL); ... %draw fixation window on eyelink computer
	@()trackerDrawStimuli(eL,obj.stimuli.stimulusPositions); ... %draw location of stimulus on eyelink
	@()drawTimedSpot(s, 0.5, [0 1 0 1], 0.2, true); ... %reset the timer on the green spot
	@()updatePlot(bR, eL, sM); ... %update our behavioural plot
	};

%incorrect entry
incEntryFcn = { @()statusMessage(eL,'Incorrect :-('); ... %status message on eyelink
	@()sendTTL(io,6); ...
	@()edfMessage(eL,'END_RT'); ...
	@()stopRecording(eL); ...
	@()edfMessage(eL,'TRIAL_RESULT 0'); ...
	@()hide(obj.stimuli{4}); ...
	}; 

%our incorrect stimulus
incFcn = @()draw(obj.stimuli);

%incorrect / break exit
incExitFcn = { @()edit(obj.stimuli,2,'modulateColourOut',[0.5 0.5 0.5]); ... %luminance pedestal
	@()setOffline(eL); ... %set eyelink offline
	@()updateVariables(obj,[],[],false); ...
	@()update(obj.stimuli); ... %update our stimuli ready for display
	@()getStimulusPositions(obj.stimuli); ... %make a struct the eL can use for drawing stim positions
	@()updateFixationValues(eL, tS.fixX, tS.fixY, tS.firstFixInit, tS.firstFixTime, tS.firstFixRadius, true); ...
	@()trackerClearScreen(eL); ...
	@()trackerDrawFixation(eL); ... %draw fixation window on eyelink computer
	@()trackerDrawStimuli(eL,obj.stimuli.stimulusPositions); ... %draw location of stimulus on eyelink
	@()updatePlot(bR, eL, sM); ... %update our behavioural plot;
	};

%break entry
breakEntryFcn = { @()statusMessage(eL,'Broke Fixation :-('); ...%status message on eyelink
	@()sendTTL(io,5);
	@()edfMessage(eL,'END_RT'); ...
	@()stopRecording(eL); ...
	@()edfMessage(eL,'TRIAL_RESULT -1'); ...
	@()hide(obj.stimuli{4}); ...
	};

%calibration function
calibrateFcn = { @()drawBackground(s); ... %blank the display
	@()setOffline(eL); @()rstop(io); @()trackerSetup(eL) }; %enter tracker calibrate/validate setup mode

%debug override
overrideFcn = @()keyOverride(obj); %a special mode which enters a matlab debug state so we can manually edit object values

%screenflash
flashFcn = { @()drawBackground(s); ...
	@()flashScreen(s, 0.2); % fullscreen flash mode for visual background activity detection
};

%screenflash
magstimFcn = { @()drawBackground(s); ...
	@()stimulate(mS); % run the magstim
	};

%show 1deg size grid
gridFcn = @()drawGrid(s);

sM.skipExitStates = {'fixate','incorrect|breakfix'};

%----------------------State Machine Table-------------------------
disp('================>> Building state info file <<================')
%specify our cell array that is read by the stateMachine
stateInfoTmp = { ...
'name'      'next'		'time'  'entryFcn'		'withinFcn'		'transitionFcn'	'exitFcn'; ...
'pause'		'prefix'		inf		pauseEntryFcn	[]				[]				pauseExitFcn; ...
'prefix'		'fixate'		1.15		prefixEntryFcn	prefixFcn	[]				[]; ...
'fixate'		'incorrect'	2			fixEntryFcn		fixFcn		initFixFcn	fixExitFcn; ...
'stimulus'  'incorrect'	1.5		stimEntryFcn	stimFcn		maintainFixFcn	stimExitFcn; ...
'incorrect'	'prefix'		1.25		incEntryFcn		incFcn		[]				incExitFcn; ...
'breakfix'	'prefix'		1.25		breakEntryFcn	incFcn		[]				incExitFcn; ...
'correct'	'prefix'		0.25		correctEntryFcn correctFcn	[]				correctExitFcn; ...
'calibrate' 'pause'		0.5		calibrateFcn	[]				[]				[]; ...
'override'	'pause'		0.5		overrideFcn		[]				[]				[]; ...
'flash'		'pause'		0.5		flashFcn			[]				[]				[]; ...
'magstim'	'prefix'		0.5		[]					magstimFcn	[]				[]; ...
'showgrid'	'pause'		10			[]					gridFcn		[]				[]; ...
};

disp(stateInfoTmp)
disp('================>> Loaded state info file  <<================')
clear pauseEntryFcn fixEntryFcn fixFcn initFixFcn fixExitFcn stimFcn maintainFixFcn incEntryFcn ...
	incFcn incExitFcn breakEntryFcn breakFcn correctEntryFcn correctFcn correctExitFcn ...
	calibrateFcn overrideFcn flashFcn gridFcn

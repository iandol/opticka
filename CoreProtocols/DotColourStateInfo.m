%DOT COLOUR state configuration file, this gets loaded by opticka via runExperiment class
% The following class objects are loaded and available to
% use: 
%
% me = runExperiment object
% io = digital I/O to recording system
% s = screenManager
% aM = audioManager
% sM = State Machine
% eT = eyetracker manager
% t  = task sequence (taskSequence class)
% rM = Reward Manager (LabJack or Arduino TTL trigger to reward system/Magstim)
% bR = behavioural record plot (on screen GUI during task run)
% me.stimuli = our list of stimuli
% tS = general struct to hold variables for this run, will be saved after experiment run
%
%------------General Settings-----------------
%------------General Settings-----------------
tS.useTask              = false; %==use taskSequence (randomised variable task object)
tS.rewardTime           = 300; %==TTL time in milliseconds
tS.rewardPin            = 2; %==Output pin, 2 by default with Arduino.
tS.checkKeysDuringStimulus = true; %==allow keyboard control? Slight drop in performance
tS.recordEyePosition	= false; %==record eye position within PTB, **in addition** to the EDF?
tS.askForComments		= false; %==little UI requestor asks for comments before/after run
tS.saveData				= false; %we don't want to save any data
tS.useMagStim			= false; %enable the magstim manager
tS.name					= 'Dot Colour'; %==name of this protocol

%-----enable the magstimManager which uses FOI2 of the LabJack
if tS.useMagStim
	mS = magstimManager('lJ',lJ,'defaultTTL',2);
	mS.stimulateTime	= 240;
	mS.frequency		= 0.7;
	mS.rewardTime		= 25;
	open(mS);
end

%------------Eyetracker Settings-----------------
tS.fixX = 0;
tS.fixY = 0;
me.lastXPosition = tS.fixX;
me.lastYPosition = tS.fixY;
tS.firstFixInit = 0.7;
tS.firstFixTime = 0.5;
tS.firstFixRadius = 1;
tS.stimulusFixTime = 0.75;
tS.strict = true;

%------------------------Eyelink setup--------------------------
eT.name = tS.name;
if tS.saveData == true; eT.recordData = true; end% save EDF file?
if tS.dummyEyelink; eT.isDummy = true; end%*** use dummy or real eyelink? ***
eT.sampleRate = 250;
eT.remoteCalibration = true; % manual calibration?
eT.calibrationStyle = 'HV5'; % calibration style
eT.modify.calibrationtargetcolour = [1 1 0];
eT.modify.calibrationtargetsize = 0.5;
eT.modify.calibrationtargetwidth = 0.01;
eT.modify.waitformodereadytime = 500;
eT.modify.devicenumber = -1; % -1 = use any keyboard

% X, Y, FixInitTime, FixTime, Radius, StrictFix
eT.updateFixationValues(tS.fixX, tS.fixY, tS.firstFixInit, tS.firstFixTime, tS.firstFixRadius, true);

%randomise stimulus variables every trial?
me.stimuli.choice = [];
me.stimuli.stimulusTable = [];

% allows using arrow keys to control this table during the main loop
% ideal for mapping receptive fields so we can twiddle parameters
me.stimuli.controlTable = [];
me.stimuli.tableChoice = 1;

% this allows us to enable subsets from our stimulus list
% numbers are the stimuli in the opticka UI
me.stimuli.stimulusSets = {[1,2]};
me.stimuli.setChoice = 1;
showSet(me.stimuli);

%----------------------State Machine States-------------------------
% these are our functions that will execute as the stateMachine runs,
% in the scope of the runExperiemnt object.

%pause entry
pauseEntryFcn = { @()hide(me.stimuli); ...
	@()drawBackground(s); ... %blank the display
	@()rstop(io); ...
	@()setOffline(eT); ... %set eyelink offline
	@()stopRecording(eT); ...
	@()edfMessage(eT,'TRIAL_RESULT -10'); ...
	@()fprintf('\n===>>>ENTER PAUSE STATE\n');
	@()disableFlip(me); ...
	};

%pause exit
pauseExitFcn = @()rstart(io);%lets unpause the plexon!...

prefixEntryFcn = { @()enableFlip(me); };
prefixFcn = []; %@()draw(me.stimuli);

%fixate entry
fixEntryFcn = { @()statusMessage(eT,'Initiate Fixation...'); ... %status text on the eyelink
	@()sendTTL(io,3); ...
	@()updateFixationValues(eT,tS.fixX,tS.fixY,[],tS.firstFixTime); %reset 
	@()setOffline(eT); ... %make sure offline before start recording
	@()show(me.stimuli{2}); ...
	@()edfMessage(eT,'V_RT MESSAGE END_FIX END_RT'); ...
	@()edfMessage(eT,['TRIALID ' num2str(getTaskIndex(me))]); ...
	@()startRecording(eT); ... %fire up eyelink
	@()syncTime(eT); ... %EDF sync message
	@()draw(me.stimuli); ... %draw stimulus
	};

%fix within
fixFcn = {@()draw(me.stimuli); ... %draw stimulus
	};

%test we are fixated for a certain length of time
initFixFcn = @()testSearchHoldFixation(eT,'stimulus','incorrect');

%exit fixation phase
fixExitFcn = { @()statusMessage(eT,'Show Stimulus...'); ...
	@()updateFixationValues(eT,[],[],[],tS.stimulusFixTime); %reset a maintained fixation of 1 second
	@()show(me.stimuli); ...
	@()edfMessage(eT,'END_FIX'); ...
	}; 

%what to run when we enter the stim presentation state
stimEntryFcn = @()doStrobe(me,true);

%what to run when we are showing stimuli
stimFcn =  { @()draw(me.stimuli); ...
	@()finishDrawing(s); ...
	@()animate(me.stimuli); ... % animate stimuli for subsequent draw
	};

%test we are maintaining fixation
maintainFixFcn = @()testSearchHoldFixation(eT,'correct','breakfix');

%as we exit stim presentation state
stimExitFcn = { @()setStrobeValue(me,inf); @()doStrobe(me,true) };

%if the subject is correct (small reward)
correctEntryFcn = { @()timedTTL(lJ,0,tS.rewardTime); ... % labjack sends a TTL to Crist reward system
	@()sendTTL(io,4); ...
	@()statusMessage(eT,'Correct! :-)'); ...
	@()edfMessage(eT,'END_RT'); ...
	@()stopRecording(eT); ...
	@()edfMessage(eT,'TRIAL_RESULT 1'); ...
	@()hide(me.stimuli); ...
	@()drawTimedSpot(s, 0.5, [0 1 0 1]); ...
	};

%correct stimulus
correctFcn = { @()drawTimedSpot(s, 0.5, [0 1 0 1]); ...
	};

%when we exit the correct state
correctExitFcn = {
	@()setOffline(eT); ... %set eyelink offline
	@()updateVariables(me,[],[],true); ... %randomise our stimuli, set strobe value too
	@()update(me.stimuli); ... %update our stimuli ready for display
	@()updatePlot(bR, eT, sM); ... %update our behavioural plot
	@()getStimulusPositions(me.stimuli); ... %make a struct the eT can use for drawing stim positions
	@()trackerClearScreen(eT); ... 
	@()trackerDrawFixation(eT); ... %draw fixation window on eyelink computer
	@()trackerDrawStimuli(eT,me.stimuli.stimulusPositions); ... %draw location of stimulus on eyelink
	@()drawTimedSpot(s, 0.5, [0 1 0 1], 0.2, true); ... %reset the timer on the green spot
	};
%incorrect entry
incEntryFcn = { @()statusMessage(eT,'Incorrect :-('); ... %status message on eyelink
	@()sendTTL(io,6); ...
	@()edfMessage(eT,'END_RT'); ...
	@()stopRecording(eT); ...
	@()edfMessage(eT,'TRIAL_RESULT 0'); ...
	@()hide(me.stimuli); ...
	}; 

%our incorrect stimulus
incFcn = [];

%incorrect / break exit
incExitFcn = { 
	@()setOffline(eT); ... %set eyelink offline
	@()updateVariables(me,[],[],false); ...
	@()update(me.stimuli); ... %update our stimuli ready for display
	@()updatePlot(bR, eT, sM); ... %update our behavioural plot;
	@()trackerClearScreen(eT); ... 
	@()trackerDrawFixation(eT); ... %draw fixation window on eyelink computer
	@()trackerDrawStimuli(eT); ... %draw location of stimulus on eyelink
	};

%break entry
breakEntryFcn = { @()statusMessage(eT,'Broke Fixation :-('); ...%status message on eyelink
	@()sendTTL(io,5);
	@()edfMessage(eT,'END_RT'); ...
	@()stopRecording(eT); ...
	@()edfMessage(eT,'TRIAL_RESULT -1'); ...
	@()hide(me.stimuli); ...
	};

%calibration function
calibrateFcn = { @()setOffline(eT); @()rstop(io); @()trackerSetup(eT) }; %enter tracker calibrate/validate setup mode

%debug override
overrideFcn = @()keyOverride(me); %a special mode which enters a matlab debug state so we can manually edit object values

%screenflash
flashFcn = { @()drawBackground(s); ...
	@()flashScreen(s, 0.2); % fullscreen flash mode for visual background activity detection
};

%magstim
magstimFcn = { @()drawBackground(s); ...
	@()stimulate(mS); % run the magstim
};

%show 1deg size grid
gridFcn = @()drawGrid(s);

%----------------------State Machine Table-------------------------
disp('================>> Building state info file <<================')
%specify our cell array that is read by the stateMachine
stateInfoTmp = { ...
'name'      'next'		'time'  'entryFcn'		'withinFcn'		'transitionFcn'	'exitFcn'; ...
'pause'		'fixate'	inf		pauseEntryFcn	[]				[]				pauseExitFcn; ...
'prefix'	'fixate'	0.75	prefixEntryFcn				prefixFcn		[]				[]; ...
'fixate'	'incorrect'	1	 	fixEntryFcn		fixFcn			initFixFcn		fixExitFcn; ...
'stimulus'  'incorrect'	2		stimEntryFcn	stimFcn			maintainFixFcn	stimExitFcn; ...
'incorrect'	'prefix'	1.25	incEntryFcn		incFcn			[]				incExitFcn; ...
'breakfix'	'prefix'	1.25	breakEntryFcn	incFcn			[]				incExitFcn; ...
'correct'	'prefix'	0.25	correctEntryFcn	correctFcn		[]				correctExitFcn; ...
'calibrate' 'pause'		0.5		calibrateFcn	[]				[]				[]; ...
'override'	'pause'		0.5		overrideFcn		[]				[]				[]; ...
'flash'		'pause'		0.5		flashFcn		[]				[]				[]; ...
'magstim'	'prefix'		0.5		[]					magstimFcn	[]				[]; ...
'showgrid'	'pause'		10		[]				gridFcn			[]				[]; ...
};

disp(stateInfoTmp)
disp('================>> Loaded state info file  <<================')
clear pauseEntryFcn fixEntryFcn fixFcn initFixFcn fixExitFcn stimFcn maintainFixFcn incEntryFcn ...
	incFcn incExitFcn breakEntryFcn breakFcn correctEntryFcn correctFcn correctExitFcn ...
	calibrateFcn overrideFcn flashFcn gridFcn
%DOT COLOUR state configuration file, this gets loaded by opticka via runExperiment class
% io = datapixx (digital I/O to plexon)
% s = screenManager
% sM = State Machine
% eT = eyelink manager
% lJ = LabJack (reward trigger to Crist reward system)
% bR = behavioural record plot
% obj.stimuli = our list of stimuli
% tS = general simple struct to hold variables for this run
%
%------------General Settings-----------------
tS.rewardTime = 160; %TTL time in milliseconds
tS.useTask = true;
tS.checkKeysDuringStimulus = false;
tS.recordEyePosition = true;
tS.askForComments = true;
tS.saveData = true; %*** save behavioural and eye movement data? ***
obj.useDataPixx = true; %*** drive plexon to collect data? ***
tS.name = 'sf-tf';

fixX = 0;
fixY = 0;
obj.lastXPosition = fixX;
obj.lastYPosition = fixY;
firstFixInit = 0.7;
firstFixTime = 0.5;
firstFixRadius = 1;
stimulusFixTime = 0.75;

eT.isDummy = false; %*** use dummy or real eyelink? ***
eT.name = tS.name;
if tS.saveData == true; eT.recordData = true; end% save EDF file?
eT.sampleRate = 250;
eT.remoteCalibration = true; % manual calibration?
eT.calibrationStyle = 'HV5'; % calibration style
eT.modify.calibrationtargetcolour = [1 1 0];
eT.modify.calibrationtargetsize = 0.5;
eT.modify.calibrationtargetwidth = 0.01;
eT.modify.waitformodereadytime = 500;
eT.modify.devicenumber = -1; % -1 = use any keyboard

% X, Y, FixInitTime, FixTime, Radius, StrictFix
eT.updateFixationValues(fixX, fixY, firstFixInit, firstFixTime, firstFixRadius, true);

%randomise stimulus variables every trial?
obj.stimuli.choice = [];
obj.stimuli.stimulusTable = [];

% allows using arrow keys to control this table during the main loop
% ideal for mapping receptive fields so we can twiddle parameters
obj.stimuli.controlTable = [];
obj.stimuli.tableChoice = 1;

% this allows us to enable subsets from our stimulus list
% numbers are the stimuli in the opticka UI
obj.stimuli.stimulusSets = {[1,2]};
obj.stimuli.setChoice = 1;
showSet(obj.stimuli);

%----------------------State Machine States-------------------------
% these are our functions that will execute as the stateMachine runs,
% in the scope of the runExperiemnt object.

%pause entry
pauseEntryFcn = { @()hide(obj.stimuli); ...
	@()rstop(io); ...
	@()setOffline(eT); ... %set eyelink offline
	@()stopRecording(eT); ...
	@()edfMessage(eT,'TRIAL_RESULT -10'); ...
	};

%pause exit
pauseExitFcn = @()rstart(io);%lets unpause the plexon!...

prefixFcn = []; %@()draw(obj.stimuli);

%fixate entry
fixEntryFcn = { @()statusMessage(eT,'Initiate Fixation...'); ... %status text on the eyelink
	@()sendTTL(io,3); ...
	@()updateFixationValues(eT,fixX,fixY,[],firstFixTime); %reset 
	@()setOffline(eT); ... %make sure offline before start recording
	@()show(obj.stimuli{2}); ...
	@()edfMessage(eT,'V_RT MESSAGE END_FIX END_RT'); ...
	@()edfMessage(eT,['TRIALID ' num2str(getTaskIndex(obj))]); ...
	@()startRecording(eT); ... %fire up eyelink
	@()syncTime(eT); ... %EDF sync message
	@()draw(obj.stimuli); ... %draw stimulus
	};

%fix within
fixFcn = {@()draw(obj.stimuli); ... %draw stimulus
	};

%test we are fixated for a certain length of time
initFixFcn = @()testSearchHoldFixation(eT,'stimulus','incorrect');

%exit fixation phase
fixExitFcn = { @()statusMessage(eT,'Show Stimulus...'); ...
	@()updateFixationValues(eT,[],[],[],stimulusFixTime); %reset a maintained fixation of 1 second
	@()show(obj.stimuli); ...
	@()edfMessage(eT,'END_FIX'); ...
	}; 

%what to run when we enter the stim presentation state
stimEntryFcn = @()doStrobe(obj,true);

%what to run when we are showing stimuli
stimFcn =  { @()draw(obj.stimuli); ...
	@()finishDrawing(s); ...
	@()animate(obj.stimuli); ... % animate stimuli for subsequent draw
	};

%test we are maintaining fixation
maintainFixFcn = @()testSearchHoldFixation(eT,'correct','breakfix');

%as we exit stim presentation state
stimExitFcn = { @()setStrobeValue(obj,inf); @()doStrobe(obj,true) };

%if the subject is correct (small reward)
correctEntryFcn = { @()timedTTL(lJ,0,tS.rewardTime); ... % labjack sends a TTL to Crist reward system
	@()sendTTL(io,4); ...
	@()statusMessage(eT,'Correct! :-)'); ...
	@()edfMessage(eT,'END_RT'); ...
	@()stopRecording(eT); ...
	@()edfMessage(eT,'TRIAL_RESULT 1'); ...
	@()hide(obj.stimuli); ...
	@()drawTimedSpot(s, 0.5, [0 1 0 1]); ...
	};

%correct stimulus
correctFcn = { @()drawTimedSpot(s, 0.5, [0 1 0 1]); ...
	};

%when we exit the correct state
correctExitFcn = {
	@()setOffline(eT); ... %set eyelink offline
	@()updateVariables(obj,[],[],true); ... %randomise our stimuli, set strobe value too
	@()update(obj.stimuli); ... %update our stimuli ready for display
	@()updatePlot(bR, eT, sM); ... %update our behavioural plot
	@()trackerClearScreen(eT); ... 
	@()trackerDrawFixation(eT); ... %draw fixation window on eyelink computer
	@()trackerDrawStimuli(eT); ... %draw location of stimulus on eyelink
	@()drawTimedSpot(s, 0.5, [0 1 0 1], 0.2, true); ... %reset the timer on the green spot
	};
%incorrect entry
incEntryFcn = { @()statusMessage(eT,'Incorrect :-('); ... %status message on eyelink
	@()sendTTL(io,6); ...
	@()edfMessage(eT,'END_RT'); ...
	@()stopRecording(eT); ...
	@()edfMessage(eT,'TRIAL_RESULT 0'); ...
	@()hide(obj.stimuli); ...
	};

%our incorrect stimulus
incFcn = [];

%incorrect / break exit
incExitFcn = { 
	@()setOffline(eT); ... %set eyelink offline
	@()updateVariables(obj,[],[],false); ...
	@()update(obj.stimuli); ... %update our stimuli ready for display
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
	@()hide(obj.stimuli); ...
	};

%calibration function
calibrateFcn = { @()setOffline(eT); @()rstop(io); @()trackerSetup(eT) }; %enter tracker calibrate/validate setup mode

%debug override
overrideFcn = @()keyOverride(obj); %a special mode which enters a matlab debug state so we can manually edit object values

%screenflash
flashFcn = @()flashScreen(s, 0.2); % fullscreen flash mode for visual background activity detection

%show 1deg size grid
gridFcn = @()drawGrid(s);

%----------------------State Machine Table-------------------------
disp('================>> Building state info file <<================')
%specify our cell array that is read by the stateMachine
stateInfoTmp = { ...
'name'      'next'		'time'  'entryFcn'		'withinFcn'		'transitionFcn'	'exitFcn'; ...
'pause'		'fixate'	inf		pauseEntryFcn	[]				[]				pauseExitFcn; ...
'prefix'	'fixate'	0.75	[]				prefixFcn		[]				[]; ...
'fixate'	'incorrect'	1	 	fixEntryFcn		fixFcn			initFixFcn		fixExitFcn; ...
'stimulus'  'incorrect'	2		stimEntryFcn	stimFcn			maintainFixFcn	stimExitFcn; ...
'incorrect'	'prefix'	1.25	incEntryFcn		incFcn			[]				incExitFcn; ...
'breakfix'	'prefix'	1.25	breakEntryFcn	incFcn			[]				incExitFcn; ...
'correct'	'prefix'	0.25	correctEntryFcn	correctFcn		[]				correctExitFcn; ...
'calibrate' 'pause'		0.5		calibrateFcn	[]				[]				[]; ...
'override'	'pause'		0.5		overrideFcn		[]				[]				[]; ...
'flash'		'pause'		0.5		flashFcn		[]				[]				[]; ...
'showgrid'	'pause'		10		[]				gridFcn			[]				[]; ...
};

disp(stateInfoTmp)
disp('================>> Loaded state info file  <<================')
clear pauseEntryFcn fixEntryFcn fixFcn initFixFcn fixExitFcn stimFcn maintainFixFcn incEntryFcn ...
	incFcn incExitFcn breakEntryFcn breakFcn correctEntryFcn correctFcn correctExitFcn ...
	calibrateFcn overrideFcn flashFcn gridFcn
% 2 FIGURE GROUND state configuration file, this gets loaded by opticka via runExperiment class
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
tS.recordEyePosition = false;
tS.askForComments = false;
tS.saveData = true; %*** save behavioural and eye movement data? ***
tS.dummyEyelink = false; 
tS.name = 'two-figure-ground';
luminancePedestal = [0.5 0.5 0.5];

%------------Eyetracker Settings-----------------
tS.fixX = 0;
tS.fixY = 0;
tS.firstFixInit = 1;
tS.firstFixTime = [0.5 0.8];
tS.firstFixRadius = 3.5;
obj.lastXPosition = tS.fixX;
obj.lastYPosition = tS.fixY;
tS.strict = true; %do we forbid eye to enter-exit-reenter fixation window?

tS.targetFixInit = 2;
tS.targetFixTime = 0.4;
tS.targetRadius = 4;

%------------------------Eyelink setup--------------------------
eT.isDummy = tS.dummyEyelink; %use dummy or real eyelink?
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

%Initialise the eyeLink object with X, Y, FixInitTime, FixTime, Radius, StrictFix
eT.updateFixationValues(tS.fixX, tS.fixY, tS.firstFixInit, tS.firstFixTime, tS.firstFixRadius, tS.strict);

%randomise stimulus variables every trial?
obj.stimuli.choice = [];
obj.stimuli.stimulusTable = [];

% allows using arrow keys to control this table during the main loop
% ideal for mapping receptive fields so we can twiddle parameters
obj.stimuli.controlTable = [];
obj.stimuli.tableChoice = 1;

% this allows us to enable subsets from our stimulus list
% numbers are the stimuli in the opticka UI
obj.stimuli.stimulusSets = {[1 2 3 4 5 6],[6]};
obj.stimuli.setChoice = 1;
showSet(obj.stimuli);

%which stimulus in the list is used for a fixation target?
obj.stimuli.fixationChoice = [3 5];

%----------------------State Machine States-------------------------
% these are our functions that will execute as the stateMachine runs,
% in the scope of the runExperiemnt object.

%pause entry
pauseEntryFcn = { @()hide(obj.stimuli); ...
	@()drawBackground(s); ... %blank the display
	@()drawTextNow(s,'PAUSED, press [p] to resume...'); ...
	@()pauseRecording(io); ...
	@()trackerClearScreen(eT); ... 
	@()trackerDrawText(eT,'PAUSED, press [P] to resume...'); ...
	@()setOffline(eT); ... %set eyelink offline
	@()stopRecording(eT); ...
	@()needEyeSample(obj,false); ...
	@()edfMessage(eT,'TRIAL_RESULT -10'); ...
	@()fprintf('\n===>>>ENTER PAUSE STATE\n'); ...
	@()disableFlip(obj); ...
	};

%pause exit
pauseExitFcn = { @()enableFlip(obj); @()resumeRecording(io); };

%prefixate entry
prefixEntryFcn = { @()enableFlip(obj); ...
	@()updateFixationValues(eT,tS.fixX,tS.fixY,tS.firstFixInit,tS.firstFixTime); %reset 
	@()getStimulusPositions(obj.stimuli); ... %make a struct the eT can use for drawing stim positions
	@()trackerClearScreen(eT); ...
	@()trackerDrawFixation(eT); ... %draw fixation window on eyelink computer
	@()trackerDrawStimuli(eT,obj.stimuli.stimulusPositions); ... %draw location of stimulus on eyelink
	};

prefixFcn = @()draw(obj.stimuli);

%prefixate exit
prefixExitFcn = { @()statusMessage(eT,'Initiate Fixation...'); ... %status text on the eyelink
	@()resetFixation(eT); ... %reset the fixation counters ready for a new trial
	@()setOffline(eT); ... %make sure offline before start recording
	@()needEyeSample(obj,true); ...
	@()edfMessage(eT,'V_RT MESSAGE END_FIX END_RT'); ...
	@()edfMessage(eT,sprintf('TRIALID %i',getTaskIndex(obj))); ...
	@()edfMessage(eT,['UUID ' UUID(sM)]); ...
	@()startRecording(eT); ... %fire up eyelink
	};

%fixate entry
fixEntryFcn = { @()edit(obj.stimuli,6,'colourOut',[1 1 0]); ...
	@()show(obj.stimuli); ...
	@()startFixation(io); ...
	@()doSyncTime(me); ... %EDF sync message
	};

%fix within
fixFcn = { @()draw(obj.stimuli) }; %draw stimulus

%test we are fixated for a certain length of time
initFixFcn = @()testSearchHoldFixation(eT,'stimulus','incorrect');

%exit fixation phase
fixExitFcn = { @()updateFixationTarget(obj, tS.useTask, tS.targetFixInit, tS.targetFixTime, tS.targetRadius, tS.strict); ... %use our stimuli values for next fix X and Y
	@()updateFixationValues(eT, [], [], tS.targetFixInit, tS.targetFixTime, tS.targetRadius, tS.strict); ... %set target fix window
	@()statusMessage(eT,'Show Stimulus...'); ...
	@()edit(obj.stimuli,6,'colourOut',[0.65 0.65 0.45]); ... %dim fix spot
	@()edfMessage(eT,'END_FIX'); ...
	}; 

%what to run when we enter the stim presentation state
stimEntryFcn = { @()doStrobe(obj,true); };

%what to run when we are showing stimuli
stimFcn =  { @()draw(obj.stimuli); ...	@()drawEyePosition(eT); ...
	@()finishDrawing(s); ...
	@()animate(obj.stimuli); ... % animate stimuli for subsequent draw
	};

%test we are maintaining fixation
maintainFixFcn = @()testSearchHoldFixation(eT,'correct','breakfix');

%as we exit stim presentation state
stimExitFcn = { @()setStrobeValue(obj,inf); @()doStrobe(obj,true) };

%if the subject is correct (small reward)
correctEntryFcn = { @()timedTTL(rM,0,tS.rewardTime); ...  % labjack sends a TTL to Crist reward system
	@()correct(io); ...
	@()needEyeSample(obj,false); ...
	@()edfMessage(eT,'END_RT'); ...
	@()statusMessage(eT,'Correct! :-)'); ...
	@()drawTimedSpot(s, 0.5, [0 1 0 1]); ...
	@()hide(obj.stimuli{6}); ...
	@()stopRecording(eT); ...
	@()edfMessage(eT,'TRIAL_RESULT 1'); ...
	};

%correct stimulus
correctFcn = { @()draw(obj.stimuli); 
	@()drawTimedSpot(s, 0.5, [0 1 0 1]); ...
	};

%when we exit the correct state
correctExitFcn = {
	@()setOffline(eT); ... %set eyelink offline
	@()updateVariables(obj,[],[],true); ... %randomise our stimuli, set strobe value too
	@()update(obj.stimuli); ... %update our stimuli ready for display
	@()drawTimedSpot(s, 0.5, [0 1 0 1], 0.2, true); ... %reset the timer on the green spot
	@()updatePlot(bR, me); ... %update our behavioural plot
	};

%incorrect entry
incEntryFcn = { @()statusMessage(eT,'Incorrect :-('); ... %status message on eyelink
	@()incorrect(io); ...
	@()edfMessage(eT,'END_RT'); ...
	@()stopRecording(eT); ...
	@()edfMessage(eT,'TRIAL_RESULT 0'); ...
	@()hide(obj.stimuli{6}); ...
	}; 

%our incorrect stimulus
incFcn = @()draw(obj.stimuli);

%incorrect / break exit
incExitFcn = { 
	@()setOffline(eT); ... %set eyelink offline
	@()updateVariables(obj,[],[],false); ...
	@()update(obj.stimuli); ... %update our stimuli ready for display
	@()updatePlot(bR, me); ... %update our behavioural plot, must come before updateTask() / updateVariables()
	};

%break entry
breakEntryFcn = { @()statusMessage(eT,'Broke Fixation :-('); ...%status message on eyelink
	@()breakFixation(io); ...
	@()edfMessage(eT,'END_RT'); ...
	@()stopRecording(eT); ...
	@()edfMessage(eT,'TRIAL_RESULT -1'); ...
	@()hide(obj.stimuli{6}); ...
	};

%calibration function
calibrateFcn = { @()setOffline(eT); @()rstop(io); @()trackerSetup(eT) }; %enter tracker calibrate/validate setup mode

%debug override
overrideFcn = @()keyOverride(obj); %a special mode which enters a matlab debug state so we can manually edit object values

%screenflash
flashFcn = @()flashScreen(s, 0.2); % fullscreen flash mode for visual background activity detection

%show 1deg size grid
gridFcn = @()drawGrid(s);

sM.skipExitStates = {'fixate','incorrect|breakfix'};

%----------------------State Machine Table-------------------------
disp('================>> Building state info file <<================')
%specify our cell array that is read by the stateMachine
stateInfoTmp = { ...
'name'      'next'		'time'  'entryFcn'		'withinFcn'		'transitionFcn'	'exitFcn'; ...
'pause'		'prefix'	inf		pauseEntryFcn	[]				[]				pauseExitFcn; ...
'prefix'	'fixate'	1.75	prefixEntryFcn	prefixFcn		[]				prefixExitFcn; ...
'fixate'	'incorrect'	1.4	 	fixEntryFcn		fixFcn			initFixFcn		fixExitFcn; ...
'stimulus'  'incorrect'	1.5		stimEntryFcn	stimFcn			maintainFixFcn	stimExitFcn; ...
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

%FIGURE GROUND state configuration file, this gets loaded by opticka via
%runExperiment class. The following class objects are already loaded and available to
%use: 
% io = datapixx (digiptal I/O to plexon)
% s = screenManager
% sM = State Machine
% eL = eyelink manager
% rM = Reward Manager (LabJack or Arduino TTL trigger to Crist reward system/Magstim)
% bR = behavioural record plot
% obj.stimuli = our list of stimuli
% tS = general simple struct to hold variables for this run

%------------General Settings-----------------
tS.rewardTime = 150; %TTL time in milliseconds
tS.useTask = true; %use stimulusSequence (randomised variable task object)
tS.checkKeysDuringStimulus = false; %==allow keyboard control? Slight drop in performance
tS.recordEyePosition = false; %==record eye position within PTB, **in addition** to the EDF?
tS.askForComments = false; %==little UI requestor asks for comments before/after run
tS.saveData = true; %==save behavioural and eye movement data?
tS.dummyEyelink = false; %==use mouse as a dummy eyelink, good for testing away from the lab.
tS.useMagStim = false; %enable the magstim manager
tS.name = 'figure-ground'; %==name of this protocol
%io.verbose = true; %==show the triggers sent in the command window
%eL.verbose=true;
tS.luminancePedestal = [0.5 0.5 0.5]; %used during training, it sets the clip behind the figure to a different luminance which makes the figure more salient and thus easier to train to.

%-----enable the magstimManager which uses FOI2 of the LabJack
if tS.useMagStim
	mS = magstimManager('lJ',rM,'defaultTTL',2);
	mS.stimulateTime	= 240;
	mS.frequency		= 0.7;
	mS.rewardTime		= 25;
	open(mS);
end
				
%------------Eyetracker Settings-----------------
tS.fixX = 0;
tS.fixY = 0;
tS.firstFixInit = 1;
tS.firstFixTime = 0.6;
tS.firstFixRadius = 3.5;
obj.lastXPosition = tS.fixX;
obj.lastYPosition = tS.fixY;
tS.strict = true; %do we allow (strict==false) multiple entry/exits of fix window within the time limit

tS.targetFixInit = 1;
tS.targetFixTime = 0.6;
tS.targetRadius = 5;

%------------------------Eyelink setup--------------------------
eL.name = tS.name;
if tS.saveData == true; eL.recordData = true; end %===save EDF file?
if tS.dummyEyelink; eL.isDummy = true; end %===use dummy or real eyelink? 
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
obj.stimuli.stimulusSets = {[1 2 3 4],[1,4]};
obj.stimuli.setChoice = 1;
showSet(obj.stimuli);

%which stimulus in the list is used for a fixation target? For this protocol it means
%the subject must fixate this stimulus (the figure is #3 in the list) to get the
%reward.
obj.stimuli.fixationChoice = 3;

%----------------------State Machine States-------------------------
% these are our functions that will execute as the stateMachine runs,
% in the scope of the runExperiemnt object.
% each statemachine "function" is a cell array of anonymous functions that enables
% each state to perform a set of actions on entry, during and on exit of that state.

%pause entry
pauseEntryFcn = {@()hide(obj.stimuli); ...
	@()drawBackground(s); ... %blank the display
	@()pauseRecording(io); ...
	@()drawTextNow(s,'Paused, press [p] to resume...'); ...
	@()disp('Paused, press [p] to resume...'); ...
	@()trackerClearScreen(eL); ... 
	@()trackerDrawText(eL,'PAUSED, press [P] to resume...'); ...
	@()edfMessage(eL,'TRIAL_RESULT -100'); ... %store message in EDF
	@()stopRecording(eL); ... %stop eye position recording
	@()disableFlip(obj); ... %stop screen updates
	@()needEyelinkSample(obj,false); ...
}; 

%pause exit
pauseExitFcn = { @()enableFlip(obj); ...
	@()resumeRecording(io); ...
};

%prefixate entry
prefixEntryFcn = { @()setOffline(eL); ... %make sure offline before start recording
	@()resetFixation(eL); ... %reset the fixation counters ready for a new trial
	@()updateFixationValues(eL,tS.fixX,tS.fixY,tS.firstFixInit,tS.firstFixTime); %reset 
	@()show(obj.stimuli); ...
	@()getStimulusPositions(obj.stimuli); ... %make a struct the eL can use for drawing stim positions
	@()trackerClearScreen(eL); ...
	@()trackerDrawFixation(eL); ... %draw fixation window on eyelink computer
	@()trackerDrawStimuli(eL,obj.stimuli.stimulusPositions); ... %draw location of stimulus on eyelink
	@()statusMessage(eL,'Prefixation...'); ...
	@()edit(obj.stimuli,4,'colourOut',[0.6 0.6 0.5]); ... %dim fix spotq
};

%prefixate
prefixFcn = { @()draw(obj.stimuli); };

%prefixate exit
prefixExitFcn = { @()statusMessage(eL,'Initiate Fixation...'); ... %status text on the eyelink
	@()edfMessage(eL,'V_RT MESSAGE END_FIX END_RT'); ...
	@()edfMessage(eL,sprintf('TRIALID %i',getTaskIndex(obj))); ...
	@()edfMessage(eL,['UUID ' UUID(sM)]); ... %add in the uuid of the current state for good measure
	@()startRecording(eL); ... %start eyelink recording eye data
	@()needEyelinkSample(obj,true); ...
};

%fixate entry
fixEntryFcn = { @()edit(obj.stimuli,4,'colourOut',[1 1 0]); ... %edit fixation spot to be yellow
	@()startFixation(io); ...
};

%fix within
fixFcn = { @()draw(obj.stimuli); };

%test we are fixated for a certain length of time
initFixFcn = { @()testSearchHoldFixation(eL,'stimulus','incorrect'); };

%exit fixation phase
fixExitFcn = { @()updateFixationTarget(obj, tS.useTask, tS.targetFixInit, tS.targetFixTime, tS.targetRadius, tS.strict); ... %use our stimuli values for next fix X and Y
	%@()statusMessage(eL,'Show Stimulus...'); ...
	@()edit(obj.stimuli,4,'colourOut',[0.6 0.6 0.5]); ... %dim fix spot
	%@()edit(obj.stimuli,2,'modulateColourOut',tS.luminancePedestal); ... %luminance pedestal
	%@()trackerDrawFixation(eL); ... 
	%@()edfMessage(eL,'END_FIX'); ...
};

%what to run when we enter the stim presentation state
stimEntryFcn = { @()doStrobe(obj,true); }; %@()doSyncTime(obj); 

%what to run when we are showing stimuli
stimFcn =  { @()draw(obj.stimuli); ...
	%@()finishDrawing(s); ...
	%@()animate(obj.stimuli); ... % animate stimuli for subsequent draw
};

%test we are finding target
testFixFcn = { @()testSearchHoldFixation(eL,'correct','breakfix'); };

%as we exit stim presentation state
stimExitFcn = { @()sendStrobe(io,255); };

%if the subject is correct (small reward)
correctEntryFcn = { @()edfMessage(eL,'END_RT'); ...
	@()timedTTL(rM,0,tS.rewardTime); ... % labjack sends a TTL to Crist reward system
	@()statusMessage(eL,'Correct! :-)'); ...
	@()hide(obj.stimuli{4}); ...
	%@()drawTimedSpot(s, 0.5, [0 1 0 1]); ...
	@()edfMessage(eL,'TRIAL_RESULT 1'); ...
	@()edfMessage(eL,'TRIAL OK'); ...
	@()stopRecording(eL); ...
};

%correct stimulus
correctFcn = { @()draw(obj.stimuli); 
	@()drawTimedSpot(s, 0.5, [0 1 0 1]); ...
};

%when we exit the correct state
correctExitFcn = { @()correct(io); ...
	%@()edit(obj.stimuli,2,'modulateColourOut',[0.5 0.5 0.5]); ... %luminance pedestal
	@()updateVariables(obj,[],[],true); ... %randomise our stimuli, set strobe value too
	@()update(obj.stimuli); ... %update our stimuli ready for display
	@()drawTimedSpot(s, 0.5, [0 1 0 1], 0.2, true); ... %reset the timer on the green spot
	@()updatePlot(bR, eL, sM); ... %update our behavioural plot
};

%incorrect entry
incEntryFcn = { @()statusMessage(eL,'Incorrect :-('); ... %status message on eyelink
	@()hide(obj.stimuli{4}); ... %hide fixation spot
	@()edfMessage(eL,'END_RT'); ... %send END_RT to eyelink
	@()edfMessage(eL,'TRIAL_RESULT 0'); ... %trial incorrect message
	@()stopRecording(eL); ... %stop eyelink recording data
}; 

%our incorrect stimulus
incFcn = { @()draw(obj.stimuli); };

%incorrect / break exit
incExitFcn = { @()incorrect(io); ...
	%@()edit(obj.stimuli,2,'modulateColourOut',[0.5 0.5 0.5]); ... %luminance pedestal
	@()resetRun(t);... %we randomise the run within this block to make it harder to guess next trial
	@()updateVariables(obj,[],true,false); ... %update the variables
	@()update(obj.stimuli); ... %update our stimuli ready for display
	@()updatePlot(bR, eL, sM); ... %update our behavioural plot;
};

%break entry
breakEntryFcn = { @()statusMessage(eL,'Broke Fixation :-('); ...%status message on eyelink
	@()hide(obj.stimuli{4}); ...
	@()edfMessage(eL,'END_RT'); ...
	@()edfMessage(eL,'TRIAL_RESULT -1'); ...
	@()stopRecording(eL); ...
};

%incorrect / break exit
breakExitFcn = { @()breakFixation(io); ...
	%@()edit(obj.stimuli,2,'modulateColourOut',[0.5 0.5 0.5]); ... %luminance pedestal
	@()setOffline(eL); ... %set eyelink offline
	@()resetRun(t);... %we randomise the run within this block to make it harder to guess next trial
	@()updateVariables(obj,[],true,false); ... %update the variables
	@()update(obj.stimuli); ... %update our stimuli ready for display
	@()updatePlot(bR, eL, sM); ... %update our behavioural plot;
};

%calibration function
calibrateFcn = { @()drawBackground(s); ... %blank the display
	@()setOffline(eL); @()rstop(io); @()trackerSetup(eL) }; %enter tracker calibrate/validate setup mode

%debug override
overrideFcn = { @()keyOverride(obj); }; %a special mode which enters a matlab debug state so we can manually edit object values

%screenflash
flashFcn = { @()drawBackground(s); ...
	@()flashScreen(s, 0.2); % fullscreen flash mode for visual background activity detection
};

%screenflash
magstimFcn = { @()drawBackground(s); ...
	@()stimulate(mS); % run the magstim
};

%show 1deg size grid
gridFcn = { @()drawGrid(s); };

%----------------------State Machine Table-------------------------
disp('================>> Building state info file <<================')
%specify our cell array that is read by the stateMachine
stateInfoTmp = { ...
'name'      'next'		'time'  'entryFcn'		'withinFcn'		'transitionFcn'	'exitFcn'; ...
'pause'		'prefix'	inf		pauseEntryFcn	{}				{}				pauseExitFcn; ...
'prefix'	'fixate'	2		prefixEntryFcn	prefixFcn		{}				prefixExitFcn; ...
'fixate'	'incorrect'	2		fixEntryFcn		fixFcn			initFixFcn		fixExitFcn; ...
'stimulus'  'incorrect'	2		stimEntryFcn	stimFcn			testFixFcn		stimExitFcn; ...
'incorrect'	'prefix'	1.25	incEntryFcn		incFcn			{}				incExitFcn; ...
'breakfix'	'prefix'	1.25	breakEntryFcn	incFcn			{}				breakExitFcn; ...
'correct'	'prefix'	0.5		correctEntryFcn correctFcn		{}				correctExitFcn; ...
'calibrate' 'pause'		0.5		calibrateFcn	{}				{}				{}; ...
'override'	'pause'		0.5		overrideFcn		{}				{}				{}; ...
'flash'		'pause'		0.5		flashFcn		{}				{}				{}; ...
'magstim'	'prefix'	0.5		{}				magstimFcn		{}				{}; ...
'showgrid'	'pause'		10		{}				gridFcn			{}				{}; ...
};
%----------------------State Machine Table-------------------------

% N x 2 cell array of regexp strings, list to skip the current -> next state's exit functions; for example
% skipExitStates = {'fixate','incorrect|breakfix'}; means that if the currentstate is
% 'fixate' and the next state is either incorrect OR breakfix, then skip the FIXATE exit
% state. Add multiple rows for skipping multiple state's exit states.
sM.skipExitStates = {'fixate','incorrect|breakfix'};

disp(stateInfoTmp)
disp('================>> Loaded state info file  <<================')
clear pauseEntryFcn fixEntryFcn fixFcn initFixFcn fixExitFcn stimFcn maintainFixFcn incEntryFcn ...
	incFcn incExitFcn breakEntryFcn breakFcn correctEntryFcn correctFcn correctExitFcn ...
	calibrateFcn overrideFcn flashFcn gridFcn

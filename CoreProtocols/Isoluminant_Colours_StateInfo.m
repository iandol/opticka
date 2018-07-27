%Isoluminant Colour task
%The following class objects (easily named handle copies) are already loaded and available to
%use: 
% io = digital I/O to recording system
% s = screen manager
% sM = State Machine
% eL = eyelink manager
% rM = reward manager (trigger to reward system)
% bR = behavioural record plot
% obj.stimuli = our list of stimuli
% tS = general simple struct to hold variables for this run

%------------General Settings-----------------
tS.rewardTime = 150; %TTL time in milliseconds
tS.useTask = true; %use stimulusSequence (randomised variable task object)
tS.checkKeysDuringStimulus = false; %==allow keyboard control? Slight drop in performance
tS.recordEyePosition = false; %==record eye position within PTB, **in addition** to the EDF?
tS.askForComments = true; %==little UI requestor asks for comments before/after run
tS.saveData = true; %==save behavioural and eye movement data?
obj.useDataPixx = false; %==use datapixx to send strobe words?
obj.useDisplayPP = true; %==use display++ to send strobe words?
obj.useLabJackReward = false; %==used for rewards and to control magstim
tS.dummyEyelink = false; %==use mouse as a dummy eyelink, good for testing away from the lab.
tS.useMagStim = false; %enable the magstim manager
tS.name = 'default'; %==name of this protocol

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
tS.firstFixInit = 1;
tS.firstFixTime = [0.5 0.8];
tS.firstFixRadius = 3.5;
tS.stimulusFixTime = 1;
obj.lastXPosition = tS.fixX;
obj.lastYPosition = tS.fixY;
tS.strict = true; %do we forbid eye to enter-exit-reenter fixation window?

%------------------------Eyelink setup--------------------------
eL.name = tS.name;
if tS.saveData == true; eL.recordData = true; end %===save EDF file?
if tS.dummyEyelink; eL.isDummy = true; end %===use dummy or real eyelink? 
eL.sampleRate = 250;
eL.remoteCalibration = true; %===manual calibration
eL.calibrationStyle = 'HV5'; %===5 point calibration
eL.modify.calibrationtargetcolour = [1 1 0];
eL.modify.calibrationtargetsize = 0.5;
eL.modify.calibrationtargetwidth = 0.01;
eL.modify.waitformodereadytime = 500;
eL.modify.devicenumber = -1; % -1 == use any keyboard

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

% this allows us to enable subsets from our stimulus list
% numbers are the stimuli in the opticka UI
obj.stimuli.stimulusSets = {[1,2]}; %EDIT THIS TO SAY WHICH STMULI TO SHOW
obj.stimuli.setChoice = 1;
showSet(obj.stimuli);

%----------------------State Machine States-------------------------
% these are our functions that will execute as the stateMachine runs,
% in the scope of the runExperiemnt object.

%pause entry
pauseEntryFcn = { @()hide(obj.stimuli); ...
	@()drawBackground(s); ... %blank the display
	@()pauseRecording(io); ...
	@()setOffline(eL); ... %set eyelink offline
	@()stopRecording(eL); ...
	@()edfMessage(eL,'TRIAL_RESULT -10'); ...
	@()fprintf('\n===>>>ENTER PAUSE STATE\n');
	@()disableFlip(obj); ...
	};

%pause exit
pauseExitFcn = { @()enableFlip(obj); @()resumeRecording(io); };

prefixEntryFcn = {
	@()trackerClearScreen(eL); ... 
	@()trackerDrawFixation(eL); ... %draw fixation window on eyelink computer
	@()trackerDrawStimuli(eL,obj.stimuli.stimulusPositions); ... %draw location of stimulus on eyelink
	};

%fixate entry
prefixExitFcn = { @()statusMessage(eL,'Initiate Fixation...'); ... %status text on the eyelink
	@()resetFixation(eL); ... %reset the fixation counters ready for a new trial
	@()updateFixationValues(eL,tS.fixX,tS.fixY,[],tS.firstFixTime); %reset 
	@()setOffline(eL); ... %make sure offline before start recording
	@()show(obj.stimuli{2}); ...
	@()edfMessage(eL,'V_RT MESSAGE END_FIX END_RT'); ...
	@()edfMessage(eL,['TRIALID ' num2str(getTaskIndex(obj))]); ...
	@()startRecording(eL); ... %fire up eyelink
	};


%fixate entry
fixEntryFcn = { @()startFixation(io); ...
	@()syncTime(eL); ... %EDF sync message
	@()draw(obj.stimuli); ... %draw stimulus
	};

%fix within
fixFcn = { @()draw(obj.stimuli); @()drawPhotoDiode(s,[0 0 0]) };

%test we are fixated for a certain length of time
initFixFcn = @()testSearchHoldFixation(eL,'stimulus','incorrect');

%exit fixation phase
fixExitFcn = {@()prepareStrobe(io,getTaskIndex(obj)); ...
	@()updateFixationValues(eL,[],[],[],tS.stimulusFixTime); %reset a maintained fixation of 1 second
	@()showSet(obj.stimuli); ...
	@()statusMessage(eL,'Show Stimulus...'); ...
	@()edfMessage(eL,'END_FIX'); ...
	}; 

%what to run when we enter the stim presentation state
stimEntryFcn = @()sendStrobe(io);

%what to run when we are showing stimuli
stimFcn =  { @()draw(obj.stimuli); ...
	@()drawPhotoDiode(s,[1 1 1]); ...
	@()finishDrawing(s); ...
	@()animate(obj.stimuli); ... % animate stimuli for subsequent draw
	};

%test we are maintaining fixation
maintainFixFcn = @()testSearchHoldFixation(eL,'correct','breakfix');

%as we exit stim presentation state
stimExitFcn = @()sendStrobe(io,255);

%if the subject is correct (small reward)
correctEntryFcn = { %@()timedTTL(rM,0,tS.rewardTime); ... % labjack sends a TTL to Crist reward system
	%@()correct(io); ...
	@()edfMessage(eL,'END_RT'); ...
	@()edfMessage(eL,'TRIAL_RESULT 1'); ...
	@()trackerDrawText(eL,'CORRECT!'); ...
	@()drawSpot(s, 0.3, [1 1 0 1]); ...
	};

%correct stimulus
correctFcn = @()drawSpot(s, 0.3, [1 1 0 1]);

%when we exit the correct state
correctExitFcn = { @()stopRecording(eL); ...
	@()setOffline(eL); ... %set eyelink offline
	@()updateVariables(obj,[],[],true); ... %randomise our stimuli, set strobe value too
	@()update(obj.stimuli); ... %update our stimuli ready for display
	@()getStimulusPositions(obj.stimuli); ... %make a struct the eL can use for drawing stim positions
	%@()updatePlot(bR, eL, sM); ... %update our behavioural plot
	};

%incorrect entry
incEntryFcn = { @()statusMessage(eL,'Incorrect :-('); ... %status message on eyelink
	%@()incorrect(io); ...
	@()edfMessage(eL,'END_RT'); ...
	@()edfMessage(eL,'TRIAL_RESULT 0'); ...
	@()trackerDrawText(eL,'INCORRECT!'); ...
	@()hide(obj.stimuli); ...
	}; 

%our incorrect stimulus
incFcn = [];

%incorrect / break exit
incExitFcn = { @()stopRecording(eL); ...
	@()setOffline(eL); ... %set eyelink offline
	@()resetRun(t);... %we randomise the run within this block to make it harder to guess next trial
	@()updateVariables(obj,[],[],false); ...
	@()update(obj.stimuli); ... %update our stimuli ready for display
	@()updatePlot(bR, eL, sM); ... %update our behavioural plot;
	};

%break entry
breakEntryFcn = { @()statusMessage(eL,'Broke Fixation :-('); ...%status message on eyelink
	@()breakFixation(io);
	@()edfMessage(eL,'END_RT'); ...
	@()stopRecording(eL); ...
	@()edfMessage(eL,'TRIAL_RESULT -1'); ...
	@()trackerDrawText(eL,'BREAK FIX!'); ...
	@()hide(obj.stimuli); ...
	};

%calibration function
calibrateFcn = { @()drawBackground(s); ... %blank the display
	@()setOffline(eL); @()pauseRecording(io); @()trackerSetup(eL) }; %enter tracker calibrate/validate setup mode

%debug override
overrideFcn = { @()pauseRecording(io); @()setOffline(eL); @()keyOverride(obj); }; %a special mode which enters a matlab debug state so we can manually edit object values

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

%==================================================================
%----------------------State Machine Table-------------------------
disp('================>> Building state info file <<================')
%specify our cell array that is read by the stateMachine
stateInfoTmp = { ...
'name'      'next'		'time'  'entryFcn'		'withinFcn'		'transitionFcn'	'exitFcn'; ...
'pause'		'prefix'	inf		pauseEntryFcn	[]				[]				pauseExitFcn; ...
'prefix'	'fixate'	2		prefixEntryFcn	[]				[]				prefixExitFcn; ...
'fixate'	'incorrect'	2	 	fixEntryFcn		fixFcn			initFixFcn		fixExitFcn; ...
'stimulus'  'incorrect'	2		stimEntryFcn	stimFcn			maintainFixFcn	stimExitFcn; ...
'incorrect'	'prefix'	1		incEntryFcn		incFcn			[]				incExitFcn; ...
'breakfix'	'prefix'	1		breakEntryFcn	incFcn			[]				incExitFcn; ...
'correct'	'prefix'	1		correctEntryFcn	correctFcn		[]				correctExitFcn; ...
'calibrate' 'pause'		0.5		calibrateFcn	[]				[]				[]; ...
'override'	'pause'		0.5		overrideFcn		[]				[]				[]; ...
'flash'		'pause'		0.5		flashFcn		[]				[]				[]; ...
'magstim'	'prefix'	0.5		[]				magstimFcn		[]				[]; ...
'showgrid'	'pause'		10		[]				gridFcn			[]				[]; ...
};
%----------------------State Machine Table-------------------------
%==================================================================

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
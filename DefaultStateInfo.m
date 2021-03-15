%Default state configuration file for runExperiment.runTrainingSession (full
%behavioural task design).
%This controls a stateMachine instance, switching between these states and 
%executing functions. This state control file will be run in the scope of the calling
%runExperiment.runTask method and other objects will be
%available at run time (with easy to use names listed below).
%The following class objects are already loaded and available to
%use: 
% me = runExperiment object
% io = digital I/O to recording system
% s  = PTB screenManager
% aM = audioManager
% sM = State Machine
% eL = eyetracker manager
% t  = task sequence (stimulusSequence class)
% rM = Reward Manager (LabJack or Arduino TTL trigger to Crist reward system/Magstim)
% bR = behavioural record plot (on screen GUI during task run)
% me.stimuli = our list of stimuli
% tS = general struct to hold variables for this run

%------------General Settings-----------------
tS.useTask				= true; %==use stimulusSequence (randomised variable task object)
tS.rewardTime			= 150; %==TTL time in milliseconds
tS.checkKeysDuringStimulus = false; %==allow keyboard control? Slight drop in performance
tS.recordEyePosition	= false; %==record eye position within PTB, **in addition** to the EDF?
tS.askForComments		= false; %==little UI requestor asks for comments before/after run
tS.saveData				= false; %==save behavioural and eye movement data?
tS.dummyEyelink			= true; %==use mouse as a dummy eyelink, good for testing away from the lab.
tS.useMagStim			= false; %enable the magstim manager
tS.name					= 'default'; %==name of this protocol

%-----enable the magstimManager which uses FOI2 of the LabJack
if tS.useMagStim
	mS = magstimManager('lJ',lJ,'defaultTTL',2);
	mS.stimulateTime	= 240;
	mS.frequency		= 0.7;
	mS.rewardTime		= 25;
	open(mS);
end

%------------Eyetracker Settings-----------------
tS.fixX					= 0;
tS.fixY					= 0;
tS.firstFixInit			= 1;
tS.firstFixTime			= [0.5 0.8];
tS.firstFixRadius		= 2;
tS.stimulusFixTime		= 1.25;
me.lastXPosition		= tS.fixX;
me.lastYPosition		= tS.fixY;
tS.strict				= true; %do we forbid eye to enter-exit-reenter fixation window?

%------------------------Eyelink setup--------------------------
eL.name					= tS.name;
if tS.saveData == true; eL.recordData = true; end %===save EDF file?
if tS.dummyEyelink; eL.isDummy = true; end %===use dummy or real eyelink? 
eL.sampleRate			= 250;
eL.strictFixation		= tS.strict;
%===========================
% remote calibration enables manual control and selection of each fixation
% this is useful for a baby or monkey who has not been trained for fixation
% use 1-9 to show each dot, space to select fix as valid, INS key ON EYELINK KEYBOARD to
% accept calibration!
eL.remoteCalibration	= false; 
%===========================
eL.calibrationStyle		= 'HV5'; %===5 point calibration
eL.modify.calibrationtargetcolour = [1 1 0];
eL.modify.calibrationtargetsize = 1;
eL.modify.calibrationtargetwidth = 0.1;
eL.modify.waitformodereadytime = 500;
eL.modify.devicenumber	= -1; % -1 == use any keyboard

%Initialise the eyeLink object with X, Y, FixInitTime, FixTime, Radius, StrictFix
eL.updateFixationValues(tS.fixX, tS.fixY, tS.firstFixInit, tS.firstFixTime, tS.firstFixRadius, tS.strict);

%randomise stimulus variables every trial? useful during initial training but not for
%data collection.
me.stimuli.choice		= [];
me.stimuli.stimulusTable = [];

% allows using arrow keys to control this table during the main loop
% ideal for mapping receptive fields so we can twiddle parameters, normally not used
% for normal tasks
me.stimuli.controlTable = [];
me.stimuli.tableChoice	= 1;

% this allows us to enable subsets from our stimulus list
% numbers are the stimuli in the opticka UI
me.stimuli.stimulusSets = {[1,2],2}; 
me.stimuli.setChoice	= 1; %EDIT THIS TO SAY WHICH STIMULI TO SHOW BY DEFAULT
showSet(me.stimuli);

%----------------------State Machine States-------------------------
% these are our functions that will execute as the stateMachine runs,
% in the scope of the runExperiemnt object.

%pause entry
pauseEntryFcn = { 
	@()hide(me.stimuli); ...
	@()drawBackground(s); ... %blank the display
	@()drawTextNow(s,'Paused, press [p] to resume...'); ...
	@()pauseRecording(io); ...
	@()trackerClearScreen(eL); ... 
	@()trackerDrawText(eL,'PAUSED, press [P] to resume...'); ...
	@()setOffline(eL); ... %set eyelink offline
	@()stopRecording(eL); ...
	@()edfMessage(eL,'TRIAL_RESULT -10'); ...
	@()disp('Paused, press [p] to resume...'); ...
	@()disableFlip(me); ...
	@()needEyeSample(me,false); ...
};

	%pause exit
pauseExitFcn = { 
	@()enableFlip(me); ...
	@()resumeRecording(io); ...
};

%prefixate entry
prefixEntryFcn = {
	@()hide(me.stimuli); ...
	@()getStimulusPositions(me.stimuli); ... %make a struct the eL can use for drawing stim positions
	@()trackerClearScreen(eL); ...
	@()trackerDrawFixation(eL); ... %draw fixation window on eyelink computer
	@()trackerDrawStimuli(eL,me.stimuli.stimulusPositions); ... %draw location of stimulus on eyelink
};

%prefixate exit
prefixExitFcn = {
	@()statusMessage(eL,'Initiate Fixation...'); ... %status text on the eyelink
	@()resetFixation(eL); ... %reset the fixation counters ready for a new trial
	@()updateFixationValues(eL,tS.fixX,tS.fixY,[],tS.firstFixTime); %reset 
	@()show(me.stimuli{2}); ...
	@()edfMessage(eL,'V_RT MESSAGE END_FIX END_RT'); ...
	@()edfMessage(eL,['TRIALID ' num2str(getTaskIndex(me))]); ...
	@()startRecording(eL); ... %fire up eyelink
};

%fixate entry
fixEntryFcn = { 
	@()startFixation(io); ...
	@()prepareStrobe(io,getTaskIndex(me)); ...
};

%fix within
fixFcn = { 
	@()draw(me.stimuli); ...
	@()drawPhotoDiode(s,[0 0 0]); ...
};

%test we are fixated for a certain length of time
initFixFcn = {
	@()testSearchHoldFixation(eL,'stimulus','incorrect'); ...
};

%exit fixation phase
fixExitFcn = {
	@()updateFixationValues(eL,[],[],0,tS.stimulusFixTime); %reset a maintained fixation of 1 second
	@()show(me.stimuli); ...
	@()statusMessage(eL,'Show Stimulus...'); ...
	@()edfMessage(eL,'END_FIX'); ...
}; 

%what to run when we enter the stim presentation state
stimEntryFcn = {
	@()syncTime(eL); ... %EDF sync message
	@()sendStrobe(io); ...
};

%what to run when we are showing stimuli
stimFcn =  { 
	@()draw(me.stimuli); ...
	@()drawPhotoDiode(s,[1 1 1]); ...
	@()finishDrawing(s); ...
	@()animate(me.stimuli); ... % animate stimuli for subsequent draw
};

%test we are maintaining fixation
maintainFixFcn = { 
	@()testSearchHoldFixation(eL,'correct','breakfix'); ...
};

%as we exit stim presentation state
stimExitFcn = { 
	@()sendStrobe(io,255); ...
};

%if the subject is correct (small reward)
correctEntryFcn =  { 
	@()hide(me.stimuli); ...
	@()trackerDrawText(eL,'CORRECT :-)'); ... 
};

%correct stimulus
correctFcn = { };

%when we exit the correct state
correctExitFcn = {
	@()correct(io); ...
	@()edfMessage(eL,'END_RT'); ...
	@()edfMessage(eL,'TRIAL_RESULT 1'); ...
	@()stopRecording(eL); ...
	@()setOffline(eL); ... %set eyelink offline
	@()updateVariables(me,[],[],true); ... %randomise our stimuli, set strobe value too
	@()update(me.stimuli); ... %update our stimuli ready for display
	@()updatePlot(bR, eL, sM); ... %update our behavioural plot
	@()checkTaskEnded(me); ... %check if task is finished
};

%incorrect entry
incEntryFcn ={
	@()hide(me.stimuli); ...
	@()trackerDrawText(eL,'INCORRECT!'); ...
};

%incorrect / break exit
incExitFcn = { 
	@()incorrect(io); ...
	@()edfMessage(eL,'END_RT'); ...
	@()edfMessage(eL,'TRIAL_RESULT 0'); ...
	@()stopRecording(eL); ...
	@()setOffline(eL); ... %set eyelink offline
	@()resetRun(t);... %we randomise the run within this block to make it harder to guess next trial
	@()updateVariables(me,[],true,false); ... %need to set override=true to visualise the randomised run
	@()update(me.stimuli); ... %update our stimuli ready for display
	@()updatePlot(bR, eL, sM); ... %update our behavioural plot;
	@()checkTaskEnded(me); ... %check if task is finished
};

%break entry
breakEntryFcn = { 
	@()trackerDrawText(eL,'BREAK FIXATION!'); ...
	@()hide(me.stimuli); ...
};

%incorrect / break exit
breakExitFcn = { 
	@()breakFixation(io); ...
	@()edfMessage(eL,'END_RT'); ...
	@()edfMessage(eL,'TRIAL_RESULT -1'); ...
	@()stopRecording(eL); ...
	@()setOffline(eL); ... %set eyelink offline
	@()resetRun(t);... %we randomise the run within this block to make it harder to guess next trial
	@()updateVariables(me,[],true,false); ...  %need to set override=true to visualise the randomised run
	@()update(me.stimuli); ... %update our stimuli ready for display
	@()updatePlot(bR, eL, sM); ... %update our behavioural plot
	@()checkTaskEnded(me); ... %check if task is finished
};

%calibration function
calibrateFcn = { 
	@()drawBackground(s); ... %blank the display
	@()setOffline(eL); ...
	@()pauseRecording(io); ...
	@()trackerSetup(eL); ...
}; %enter tracker calibrate/validate setup mode

%debug override
overrideFcn = { 
	@()pauseRecording(io); ...
	@()setOffline(eL); ...
	@()keyOverride(me); ...
}; %a special mode which enters a matlab debug state so we can manually edit object values

%screenflash
flashFcn = { 
	@()drawBackground(s); ...
	@()flashScreen(s, 0.2); ...% fullscreen flash mode for visual background activity detection
};

%magstim
magstimFcn = { 
	@()drawBackground(s); ...
	@()stimulate(mS); % run the magstim
};

%show 1deg size grid
gridFcn = { 
	@()drawGrid(s); 
};

% N x 2 cell array of regexpi strings, list to skip the current -> next state's exit functions; for example
% skipExitStates = {'fixate','incorrect|breakfix'}; means that if the currentstate is
% 'fixate' and the next state is either incorrect OR breakfix, then skip the FIXATE exit
% state. Add multiple rows for skipping multiple state's exit states.
sM.skipExitStates = {'fixate','incorrect|breakfix'};

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
'incorrect'	'prefix'	1		incEntryFcn		[]				[]				incExitFcn; ...
'breakfix'	'prefix'	1		breakEntryFcn	[]				[]				breakExitFcn; ...
'correct'	'prefix'	1		correctEntryFcn	correctFcn		[]				correctExitFcn; ...
'calibrate' 'pause'		0.5		calibrateFcn	[]				[]				[]; ...
'override'	'pause'		0.5		overrideFcn		[]				[]				[]; ...
'flash'		'pause'		0.5		flashFcn		[]				[]				[]; ...
'magstim'	'prefix'	0.5		[]				magstimFcn		[]				[]; ...
'showgrid'	'pause'		10		[]				gridFcn			[]				[]; ...
};
%----------------------State Machine Table-------------------------
%==================================================================

disp(stateInfoTmp)
disp('================>> Loaded state info file  <<================')
clear pauseEntryFcn fixEntryFcn fixFcn initFixFcn fixExitFcn stimFcn maintainFixFcn incEntryFcn ...
	incFcn incExitFcn breakEntryFcn breakFcn correctEntryFcn correctFcn correctExitFcn ...
	calibrateFcn overrideFcn flashFcn gridFcn

%Isoluminant Colour task
%The following class objects (easily named handle copies) are already loaded and available to
%use: 
% me = runExperiment object
% io = digital I/O to recording system
% s = screen manager
% sM = State Machine
% eT = eyelink manager
% rM = Reward Manager (LabJack or Arduino TTL trigger to Crist reward system/Magstim)
% bR = behavioural record plot
% stims = our list of stimuli
% tS = general simple struct to hold variables for this run

%------------General Settings-----------------
tS.rewardTime = 150; %==TTL time in milliseconds
tS.useTask = true; %==use taskSequence (randomised variable task object)
tS.checkKeysDuringStimulus = false; %==allow keyboard control? Slight drop in performance
tS.recordEyePosition = false; %==record eye position within PTB, **in addition** to the EDF?
tS.askForComments = true; %==little UI requestor asks for comments before/after run
tS.saveData = true; %==save behavioural and eye movement data?
tS.dummyEyelink = false; %==use mouse as a dummy eyelink, good for testing away from the lab.
tS.useMagStim = false; %enable the magstim manager
tS.name = 'isolum-color'; %==name of this protocol
io.verbose = true; %==show the triggers sent in the command window

%------------Eyetracker Settings-----------------
tS.fixX = 0;
tS.fixY = 0;
tS.firstFixInit = 1;
tS.firstFixTime = 1;
tS.firstFixRadius = 3.25;
tS.stimulusFixTime = 1;
me.lastXPosition = tS.fixX;
me.lastYPosition = tS.fixY;
tS.strict = true; %do we forbid eye to enter-exit-reenter fixation window?

%------------------------Eyelink setup--------------------------
eT.name = tS.name;
if tS.saveData == true; eT.recordData = true; end %===save EDF file?
if tS.dummyEyelink; eT.isDummy = true; end %===use dummy or real eyelink? 
eT.sampleRate = 250;
eT.remoteCalibration = true; %===manual calibration
eT.calibrationStyle = 'HV5'; %===5 point calibration
eT.modify.calibrationtargetcolour = [1 1 0];
eT.modify.calibrationtargetsize = 0.5;
eT.modify.calibrationtargetwidth = 0.01;
eT.modify.waitformodereadytime = 500;
eT.modify.devicenumber = -1; % -1 == use any keyboard

%Initialise the eyeLink object with X, Y, FixInitTime, FixTime, Radius, StrictFix
eT.updateFixationValues(tS.fixX, tS.fixY, tS.firstFixInit, tS.firstFixTime, tS.firstFixRadius, tS.strict);

%randomise stimulus variables every trial? useful during initial training but not for
%data collection.
stims.choice = {};
stims.stimulusTable = {};

% allows using arrow keys to control this table during the main loop
% ideal for mapping receptive fields so we can twiddle parameters, normally not used
% for normal tasks
stims.controlTable = {};
stims.tableChoice = 1;

% this allows us to enable subsets from our stimulus list. So each set is a
% particular display like fixation spot only, background. During the trial you can
% use the showSet method of stims to change to a particular stimulus set.
% numbers are the stimuli in the opticka UI
stims.stimulusSets = {[1,2],2};
stims.setChoice = 1;
showSet(stims);

%----------------------State Machine States-------------------------
% these are our functions that will execute as the stateMachine runs,
% in the scope of the runExperiemnt object.
% each statemachine "function" is a cell array of anonymous functions that enables
% each state to perform a set of actions on entry, during and on exit of that state.

%--------------------pause entry
pauseEntryFcn = {
	@()hide(stims);
	@()drawBackground(s); %blank the display
	@()drawTextNow(s,'Paused, press [p] to resume...');
	%@()pauseRecording(io);
	@()trackerClearScreen(eT); 
	@()trackerDrawText(eT,'PAUSED, press [P] to resume...');
	@()setOffline(eT); %set eyelink offline
	@()stopRecording(eT,true);
	@()needEyeSample(me,false);
	@()edfMessage(eT,'TRIAL_RESULT -10');
	@()fprintf('\n===>>>ENTER PAUSE STATE\n');
	@()disableFlip(me);
};

%--------------------pause exit
pauseExitFcn = { 
	@()enableFlip(me);
	@()startRecording(eT, true); %start recording eye position data again
	%@()resumeRecording(io);
};

%--------------------prefixate entry
prefixEntryFcn = {
	@()setOffline(eT); %make sure offline before start recording
	@()resetFixation(eT); %reset the fixation counters ready for a new trial
	@()updateFixationValues(eT,tS.fixX,tS.fixY,tS.firstFixInit,tS.firstFixTime,tS.firstFixRadius); %reset 
	@()getStimulusPositions(stims); %make a struct the eT can use for drawing stim positions
	@()trackerClearScreen(eT);
	@()trackerDrawFixation(eT); %draw fixation window on eyelink computer
	@()trackerDrawStimuli(eT,stims.stimulusPositions); %draw location of stimulus on eyelink
	@()hide(stims);
	@()logRun(me,'PREFIX'); %fprintf current trial info
};

%--------------------prefixate exit
prefixExitFcn = { 
	@()edfMessage(eT,'V_RT MESSAGE END_FIX END_RT');
	@()edfMessage(eT,sprintf('TRIALID %i',getTaskIndex(me)));
	@()startRecording(eT); %fire up eyelink
	@()statusMessage(eT,'Initiate Fixation...'); %status text on the eyelink
	@()needEyeSample(me,true);
	@()show(stims{2});
};

%--------------------fixate entry
fixEntryFcn = { 
	%@()startFixation(io);
};

%--------------------fix within
fixFcn = { 
	@()draw(stims);
	@()drawPhotoDiode(s,[0 0 0]) 
};

%--------------------test we are fixated for a certain length of time
initFixFcn = { 
	@()testSearchHoldFixation(eT,'stimulus','incorrect'); 
};

%--------------------exit fixation phase
fixExitFcn = {
	@()updateFixationValues(eT,[],[],0,tS.stimulusFixTime); %reset a maintained fixation of 1 second
	@()show(stims);
	@()statusMessage(eT,'Show Stimulus...');
	@()edfMessage(eT,'END_FIX');
}; 

%--------------------what to run when we enter the stim presentation state
stimEntryFcn = { 
    @()prepareStrobe(io, 100);
	@()doStrobe(me,true);
	@()doSyncTime(me);
};  

%--------------------what to run when we are showing stimuli
stimFcn =  { 
	@()draw(stims);
	@()drawPhotoDiode(s,[1 1 1]);
};

%--------------------test we are finding target
maintainFixFcn = { 
	@()testSearchHoldFixation(eT,'correct','breakfix');
};

%--------------------as we exit stim presentation state
stimExitFcn = { 
	%@()sendStrobe(io,255);
};

%--------------------if the subject is correct (small reward)
correctEntryFcn = { 
	@()edfMessage(eT,'END_RT');
	@()trackerDrawText(eT,'CORRECT :-)');
	@()hide(stims{1});
};

%--------------------correct stimulus
correctFcn = { 
	@()draw(stims);
	@()drawPhotoDiode(s,[0 0 0]);
	@()finishDrawing(s);
};

%--------------------when we exit the correct state
correctExitFcn = { 
	%@()correct(io);
	@()needEyeSample(me,false);
	@()edfMessage(eT,'TRIAL_RESULT 1');
	%@()timedTTL(rM,0,tS.rewardTime); % labjack sends a TTL to Crist reward system
	@()stopRecording(eT);
	@()setOffline(eT); %set eyelink offline
	@()updateVariables(me,[],[],true); %randomise our stimuli, set strobe value too
	@()update(stims); %update our stimuli ready for display
	@()updatePlot(bR, eT, sM); %update our behavioural plot
	@()checkTaskEnded(me); %check if task is finished
};

%--------------------incorrect entry
incEntryFcn = { 
	@()edfMessage(eT,'END_RT');
	@()trackerDrawText(eT,'INCORRECT!');
};

%--------------------incorrect / break exit
incExitFcn = { 
	%@()incorrect(io);
	@()needEyeSample(me,false);
	@()edfMessage(eT,'END_RT');
	@()edfMessage(eT,'TRIAL_RESULT 0');
	@()stopRecording(eT);
	@()setOffline(eT); %set eyelink offline
	@()resetRun(task);... %we randomise the run within this block to make it harder to guess next trial
	@()updateVariables(me,[],true,false); %need to set override=true to visualise the randomised run
	@()update(stims); %update our stimuli ready for display
	@()updatePlot(bR, eT, sM); %update our behavioural plot;
	@()checkTaskEnded(me); %check if task is finished
};

%--------------------break entry
breakEntryFcn = { 
	@()edfMessage(eT,'END_RT');
	@()trackerDrawText(eT,'BREAK FIXATION!');
	@()hide(stims);
};

%--------------------incorrect / break exit
breakExitFcn = { 
	%@()breakFixation(io);
	@()needEyeSample(me,false);
	@()edfMessage(eT,'TRIAL_RESULT -1');
	@()stopRecording(eT);
	@()setOffline(eT); %set eyelink offline
	@()resetRun(task); %we randomise the run within this block to make it harder to guess next trial
	@()updateVariables(me,[],true,false);  %need to set override=true to visualise the randomised run
	@()update(stims); %update our stimuli ready for display
	@()updatePlot(bR, eT, sM); %update our behavioural plot
	@()checkTaskEnded(me); %check if task is finished
};

%--------------------enter tracker calibrate/validate setup mode
calibrateFcn = { 
	@()drawBackground(s); %blank the display
	@()setOffline(eT);
	%@()pauseRecording(io);
	@()trackerSetup(eT);
}; 

%--------------------debug override special mode which enters a matlab debug state so we can manually edit object values
overrideFcn = { 
	%@()pauseRecording(io);
	@()setOffline(eT);
	@()keyOverride(me);
};

%--------------------screenflash
flashFcn = {
	@()drawBackground(s);
	@()flashScreen(s, 0.2);% fullscreen flash mode for visual background activity detection
};

%--------------------magstim
magstimFcn = { 
	@()drawBackground(s);
	@()stimulate(mS);% run the magstim
};

%--------------------show 1deg size grid
gridFcn = { 
	@()drawGrid(s); 
};

% N x 2 cell array of regexpi strings, list to skip the current -> next state's exit functions; for example
% skipExitStates = {'fixate',{'incorrect','breakfix'}}; means that if the currentstate is
% 'fixate' and the next state is either incorrect OR breakfix, then skip the FIXATE exit
% state. Add multiple rows for skipping multiple state's exit states.
sM.skipExitStates = {'fixate',{'incorrect','breakfix'}};

%==================================================================
%----------------------State Machine Table-------------------------
disp('================>> Building state info file <<================')
%specify our cell array that is read by the stateMachine
stateInfoTmp = {
'name'      'next'		'time'  'entryFcn'		'withinFcn'		'transitionFcn'	'exitFcn';
'pause'		'prefix'	inf		pauseEntryFcn	{}				{}				pauseExitFcn;
'prefix'	'fixate'	2		prefixEntryFcn	{}				{}				prefixExitFcn;
'fixate'	'incorrect'	2	 	fixEntryFcn		fixFcn			initFixFcn		fixExitFcn;
'stimulus'  'incorrect'	2		stimEntryFcn	stimFcn			maintainFixFcn	stimExitFcn;
'correct'	'prefix'	1		correctEntryFcn	correctFcn		{}				correctExitFcn;
'incorrect'	'prefix'	1		incEntryFcn		{}				{}				incExitFcn;
'breakfix'	'prefix'	1		breakEntryFcn	{}				{}				breakExitFcn;
'calibrate' 'pause'		0.5		calibrateFcn	{}				{}				{};
'override'	'pause'		0.5		overrideFcn		{}				{}				{};
'flash'		'pause'		0.5		flashFcn		{}				{}				{};
'magstim'	'prefix'	0.5		{}				magstimFcn		{}				{};
'showgrid'	'pause'		10		{}				gridFcn			{}				{};
};
%----------------------State Machine Table-------------------------
%==================================================================

disp(stateInfoTmp)
disp('================>> Loaded state info file  <<================')
clear pauseEntryFcn fixEntryFcn fixFcn initFixFcn fixExitFcn stimFcn maintainFixFcn incEntryFcn ...
	incFcn incExitFcn breakEntryFcn breakFcn correctEntryFcn correctFcn correctExitFcn ...
	calibrateFcn overrideFcn flashFcn gridFcn

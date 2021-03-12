%FIXATION TRAINING state configuration file
%
%This presents a large fixation spot in a loop to train for fixation.
%Adjust eyetracker setting values over training to refine behaviour
%The following class objects (easily named handle copies) are already loaded and available to
%use: 
% me = runExperiment object
% io = digital I/O to recording system
% s = screenManager
% aM = audioManager
% sM = State Machine
% eL = eyelink manager
% rM = reward manager (trigger to reward system)
% bR = behavioural record plot
% me.stimuli = our list of stimuli
% tS = general simple struct to hold variables for this run

%------------General Settings-----------------
tS.useTask					= false; %==use stimulusSequence (randomised variable task object)
tS.rewardTime				= 100; %==TTL time in milliseconds
tS.rewardPin				= 2; %==Output pin, 2 by default with Arduino.
tS.checkKeysDuringStimulus  = false; %==allow keyboard control? Slight drop in performance
tS.recordEyePosition		= false; %==record eye position within PTB, **in addition** to the EDF?
tS.askForComments			= false; %==little UI requestor asks for comments before/after run
tS.saveData					= false; %==save behavioural and eye movement data?
tS.dummyEyelink				= false; %==use mouse as a dummy eyelink, good for testing away from the lab.
tS.useMagStim				= false; %enable the magstim manager
tS.name						= 'fixation-training'; %==name of this protocol
me.useEyeLink				= true;

%------------Eyetracker Settings-----------------
tS.fixX						= 0;
tS.fixY						= 0;
tS.firstFixInit				= 1;
tS.firstFixTime				= 2;
tS.firstFixRadius			= 3;
me.lastXPosition			= tS.fixX;
me.lastYPosition			= tS.fixY;
tS.strict					= true; %do we forbid eye to enter-exit-reenter fixation window?

%------------------------Eyelink setup--------------------------
eL.name 					= tS.name;
if tS.saveData == true; eL.recordData = true; end %===save EDF file?
if tS.dummyEyelink; eL.isDummy = true; end %===use dummy or real eyelink? 
eL.sampleRate 				= 250;
%===========================
% remote calibration enables manual control and selection of each fixation
% this is useful for a baby or monkey who has not been trained for fixation
% use 1-9 to show each dot, space to select fix as valid, INS key ON EYELINK KEYBOARD to
% accept calibration!
eL.remoteCalibration			= false; 
%===========================
eL.calibrationStyle 			= 'HV5'; % calibration style
eL.modify.calibrationtargetcolour = [1 0 0];
eL.modify.calibrationtargetsize = 1; % size of calibration target as percentage of screen
eL.modify.calibrationtargetwidth = 0.1; % width of calibration target's border as percentage of screen
eL.modify.waitformodereadytime = 500;
eL.modify.devicenumber 			= -1; % -1==use any keyboard
eL.modify.targetbeep 			= 1;
eL.verbose 						= true;

%Initialise the eyeLink object with X, Y, FixInitTime, FixTime, Radius, StrictFix
eL.updateFixationValues(tS.fixX, tS.fixY, tS.firstFixInit, tS.firstFixTime, tS.firstFixRadius, tS.strict);

%randomise stimulus variables every trial?
% me.stimuli.choice = [];
% n = 1;
% in(n).name = 'xyPosition';
% in(n).values = [0 0];
% in(n).stimuli = 1;
% in(n).offset = [];
% me.stimuli.stimulusTable = in;
me.stimuli.choice 				= [];
me.stimuli.stimulusTable 		= [];

%allows using arrow keys to control this table
me.stimuli.tableChoice 			= 1;
n=1;
me.stimuli.controlTable(n).variable = 'size';
me.stimuli.controlTable(n).delta = 1;
me.stimuli.controlTable(n).stimuli = 1;
me.stimuli.controlTable(n).limits = [0.25 20];

%this allows us to enable subsets from our stimulus list
me.stimuli.stimulusSets 		= {[1,2],[2]};
me.stimuli.setChoice 			= 1;
showSet(me.stimuli);

%which stimulus in the list is used for a fixation target? 
me.stimuli.fixationChoice 		= 1;

%----------------------State Machine States-------------------------

%pause entry
pauseEntryFcn = { 
	@()hide(me.stimuli); ...
	@()drawBackground(s); ... %blank the display
	@()pauseRecording(io); ...
	@()drawTextNow(s,'Paused, press [p] to resume...'); ...
	@()disp('Paused, press [p] to resume...'); ...
	@()trackerClearScreen(eL); ... 
	@()trackerDrawText(eL,'PAUSED, press [P] to resume...'); ...
	@()edfMessage(eL,'TRIAL_RESULT -100'); ... %store message in EDF
	@()setOffline(eL);
	@()stopRecording(eL); ...
	@()edfMessage(eL,'TRIAL_RESULT -10'); ...
	@()fprintf('\n===>>>ENTER PAUSE STATE\n'); ...
	@()disableFlip(me); ...
	@()needEyeSample(me,false); ...
};

%--------------------pause exit
pauseExitFcn = { 
	@()enableFlip(me); ...
	@()needEyeSample(me,true); ...
	@()resumeRecording(io); ...
};

%prestim entry
psEntryFcn = {
	@()setOffline(eL); ...
	@()resetFixation(eL); ... %reset the fixation counters ready for a new trial
	@()startRecording(eL);
	@()trackerClearScreen(eL); ...
	@()statusMessage(eL,'Prefixation...'); ... %status text on the eyelink
	@()logRun(me,'PREFIX'); ... %fprintf current trial info
};

%prestimulus blank
prestimulusFcn = { @()drawBackground(s); @()drawText(s,'Prefix'); };

%exiting prestimulus state
psExitFcn = {
	@()edfMessage(eL,'V_RT MESSAGE END_FIX END_RT'); ...
	@()edfMessage(eL,sprintf('TRIALID %i',getTaskIndex(me))); ...
	@()edfMessage(eL,['UUID ' UUID(sM)]); ... %add in the uuid of the current state for good measure
	@()edfMessage(eL,'MSG:Hello there! '); ... 
	@()startRecording(eL); ... %start eyelink recording eye data
	@()statusMessage(eL,'Get Fixation...'); ... %status text on the eyelink
	@()trackerDrawFixation(eL); ... 
	@()needEyeSample(me,true); ...
	@()changeSet(me.stimuli,1); ...

};

%what to run when we enter the stim presentation state
stimEntryFcn = { @()startFixation(io); };

%what to run when we are showing stimuli
stimFcn = { 
	@()draw(me.stimuli); ... 
	@()drawText(s,'Stim'); ...
	@()drawEyePosition(eL); ...
	@()finishDrawing(s); ...
	@()animate(me.stimuli); ... % animate stimuli for subsequent draw
};

%test we are maintaining fixation
maintainFixFcn = { 
	@()testSearchHoldFixation(eL,'correct','breakfix'); 
};

%as we exit stim presentation state
stimExitFcn = { 
	@()edfMessage(eL,'END_FIX');
	@()edfMessage(eL,'END_RT'); 
};

%if the subject is correct (small reward)
correctEntryFcn = {
	@()logRun(me,'CORRECT'); ... %fprintf current trial info
	@()hide(me.stimuli); ...
	@()timedTTL(rM, tS.rewardPin, tS.rewardTime); ... 
	@()beep(aM,2000); ...
	@()edfMessage(eL,'TRIAL_RESULT 1'); ...
	@()statusMessage(eL,'Correct! :-)'); ...
	@()stopRecording(eL); ...
	@()setOffline(eL); ... %set eyelink offline
};

%correct stimulus
correctFcn = { 
	@()drawBackground(s); ...
	@()drawText(s,'Correct'); ...
};

%when we exit the correct state
correctExitFcn = { 
	@()needEyeSample(me,false); ...
	@()updatePlot(bR, eL, sM); ...
	@()resetFixation(eL); ...
	@()update(me.stimuli); ... 
};

%break entry
breakEntryFcn = { 
	@()logRun(me,'BREAKFIX'); ... %fprintf current trial info
	@()hide(me.stimuli); ...
	@()beep(aM,350,0.5,1); ...
	@()trackerClearScreen(eL); ...
	@()trackerDrawText(eL,'Broke fix! :-(');
	@()edfMessage(eL,'TRIAL_RESULT 0'); ... %trial incorrect message
	@()stopRecording(eL); ... %stop eyelink recording data
	@()setOffline(eL); ... %set eyelink offline
};

%break entry
incEntryFcn = { 
	@()logRun(me,'INCORRECT'); ... %fprintf current trial info
	@()hide(me.stimuli); ...
	@()beep(aM,350,0.5,1); ...
	@()trackerClearScreen(eL); ...
	@()trackerDrawText(eL,'Incorrect! :-(');
	@()edfMessage(eL,'TRIAL_RESULT 0'); ... %trial incorrect message
	@()stopRecording(eL); ... %stop eyelink recording data
	@()setOffline(eL); ... %set eyelink offline
};

%our incorrect stimulus
breakFcn =  { @()drawBackground(s); @()drawText(s,'Wrong'); };

breakExitFcn = { 
	@()incorrect(io); ...
	@()needEyeSample(me,false); ...
	@()update(me.stimuli); ... %update our stimuli ready for display
	@()resetFixation(eL); ...
};

%--------------------calibration function
calibrateFcn = { 
	@()drawBackground(s); ... %blank the display
	@()setOffline(eL); @()rstop(io); @()trackerSetup(eL) 
}; %enter tracker calibrate/validate setup mode

%--------------------screenflash
flashFcn = { 
	@()drawBackground(s); ...
	@()flashScreen(s, 0.2); % fullscreen flash mode for visual background activity detection
};

% allow override
overrideFcn = { @()keyOverride(me); };

%show 1deg size grid
gridFcn = { @()drawGrid(s); @()drawScreenCenter(s) };

% N x 2 cell array of regexpi strings, list to skip the current -> next state's exit functions; for example
% skipExitStates = {'fixate','incorrect|breakfix'}; means that if the currentstate is
% 'fixate' and the next state is either incorrect OR breakfix, then skip the FIXATE exit
% state. Add multiple rows for skipping multiple state's exit states.
sM.skipExitStates = {'fixate','incorrect|breakfix'};

%----------------------State Machine Table-------------------------
disp('================>> Building state info file <<================')
%specify our cell array that is read by the stateMachine
stateInfoTmp = { ...
'name'      'next'		'time' 'entryFcn'		'withinFcn'		'transitionFcn'	'exitFcn'; ...
'pause'		'blank'		inf		pauseEntryFcn	[]					[]					pauseExitFcn; ...
'blank'		'stimulus'	1		psEntryFcn		prestimulusFcn		[]					psExitFcn; ...
'stimulus'  'incorrect'	3		stimEntryFcn	stimFcn				maintainFixFcn		stimExitFcn; ...
'incorrect'	'blank'		1		incEntryFcn		breakFcn			[]					breakExitFcn; ...
'breakfix'	'blank'		1		breakEntryFcn	breakFcn			[]					breakExitFcn; ...
'correct'	'blank'		0.5		correctEntryFcn	correctFcn			[]					correctExitFcn; ...
'calibrate' 'pause'		0.5		calibrateFcn	[]					[]					[]; ...
'flash'		'pause'		0.5		[]				flashFcn			[]					[]; ...
'override'	'pause'		0.5		[]				overrideFcn			[]					[]; ...
'showgrid'	'pause'		1		[]				gridFcn				[]					[]; ...
};

disp(stateInfoTmp)
disp('================>> Building state info file <<================')
clear maintainFixFcn prestimulusFcn singleStimulus pauseEntryFcn ...
	prestimulusFcn stimFcn stimEntryFcn stimExitfcn correctEntry ...
	correctWithin correctExitFcn breakFcn maintainFixFcn psExitFcn ...
	incorrectFcn calibrateFcn gridFcn overrideFcn flashFcn breakFcn
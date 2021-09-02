%RFLOCALISER state configuration file, this gets loaded by opticka via
% runExperiment class. 
%
% This protocol uses mouse and keyboard control of many different classes
% of stimuli. You can change which stimulus and what variables are during
% the task, while the subject maintains fixation. 
%
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

%------------General Settings-----------------
tS.useTask              = false; %==use taskSequence (randomised variable task object)
tS.rewardTime           = 300; %==TTL time in milliseconds
tS.rewardPin            = 2; %==Output pin, 2 by default with Arduino.
tS.checkKeysDuringStimulus = true; %==allow keyboard control? Slight drop in performance
tS.recordEyePosition	= false; %==record eye position within PTB, **in addition** to the EDF?
tS.askForComments		= false; %==little UI requestor asks for comments before/after run
tS.saveData				= false; %we don't want to save any data
tS.useMagStim			= false; %enable the magstim manager
tS.name					= 'RF Localiser'; %==name of this protocol

%------------Eyetracker Settings-----------------
tS.fixX						= 0; % X position in degrees
tS.fixY						= 0; % X position in degrees
tS.firstFixInit				= 1; % time to search and enter fixation window
tS.firstFixTime				= 3; % time to maintain fixation within windo
tS.firstFixRadius			= 2; % radius in degrees
tS.strict					= true; %do we forbid eye to enter-exit-reenter fixation window?
me.lastXPosition			= tS.fixX;
me.lastYPosition			= tS.fixY;

%------------------------Eyelink setup--------------------------
me.useEyeLink					= true; % make sure we are using eyetracker, override UI setting
eT.name							= tS.name;
if tS.saveData == true;			eT.recordData = true; end %===save EDF file?
if me.dummyMode;				eT.isDummy = true; end %===use dummy or real eyetracker, from UI...
%===========================
% remote calibration enables manual control and selection of each fixation
% this is useful for a baby or monkey who has not been trained for fixation
% use 1-9 to show each dot, space to select fix as valid, INS key ON EYELINK KEYBOARD to
% accept calibration!
eT.remoteCalibration			= false; 
%===========================
eT.sampleRate					= 250; % sampling rate
eT.calibrationStyle 			= 'HV5'; % calibration style
eT.modify.calibrationtargetcolour = [1 1 1];
eT.modify.calibrationtargetsize = 1; % size of calibration target as percentage of screen
eT.modify.calibrationtargetwidth = 0.1; % width of calibration target's border as percentage of screen
eT.modify.waitformodereadytime	= 500;
eT.modify.devicenumber 			= -1; % -1==use any keyboard
eT.modify.targetbeep 			= 1;
eT.verbose 						= false;
%oldverbosity					= Eyelink('Verbosity',10);

%Initialise the eyeLink object with X, Y, FixInitTime, FixTime, Radius, StrictFix
eT.updateFixationValues(tS.fixX, tS.fixY, tS.firstFixInit, tS.firstFixTime, tS.firstFixRadius, tS.strict);

%-------------------randomise stimulus variables every trial?-----------
% if you want to have some randomisation of stimuls variables without
% using taskSequence task, you can uncomment this and runExperiment can
% use this structure to change e.g. X or Y position, size, angle
% see metaStimulus for more details. Remember this will not be "Saved" for
% later use, if you want to do controlled methods of constants experiments
% use taskSequence to define proper randomised and balanced variable
% sets and triggers to send to recording equipment etc...
%
% me.stimuli.choice				= [];
% n								= 1;
% in(n).name					= 'xyPosition';
% in(n).values					= [6 6; 6 -6; -6 6; -6 -6; -6 0; 6 0];
% in(n).stimuli					= 1;
% in(n).offset					= [];
% me.stimuli.stimulusTable		= in;
me.stimuli.choice 				= [];
me.stimuli.stimulusTable 		= [];

%--------allows using arrow keys to control this table during presentation
me.stimuli.tableChoice = 1;
n=1;
me.stimuli.controlTable(n).variable = 'angle';
me.stimuli.controlTable(n).delta = 15;
me.stimuli.controlTable(n).stimuli = [7 8 9 10];
me.stimuli.controlTable(n).limits = [0 360];
n=n+1;
me.stimuli.controlTable(n).variable = 'size';
me.stimuli.controlTable(n).delta = 0.25;
me.stimuli.controlTable(n).stimuli = [2 3 4 5 6 7 8 10];
me.stimuli.controlTable(n).limits = [0.25 20];
n=n+1;
me.stimuli.controlTable(n).variable = 'flashTime';
me.stimuli.controlTable(n).delta = 0.1;
me.stimuli.controlTable(n).stimuli = [1 2 3 4 5 6];
me.stimuli.controlTable(n).limits = [0.1 1];
n=n+1;
me.stimuli.controlTable(n).variable = 'barHeight';
me.stimuli.controlTable(n).delta = 1;
me.stimuli.controlTable(n).stimuli = [8 9];
me.stimuli.controlTable(n).limits = [0.5 15];
n=n+1;
me.stimuli.controlTable(n).variable = 'barWidth';
me.stimuli.controlTable(n).delta = 0.25;
me.stimuli.controlTable(n).stimuli = [8 9];
me.stimuli.controlTable(n).limits = [0.25 8.25];
n=n+1;
me.stimuli.controlTable(n).variable = 'tf';
me.stimuli.controlTable(n).delta = 0.1;
me.stimuli.controlTable(n).stimuli = [7];
me.stimuli.controlTable(n).limits = [0 12];
n=n+1;
me.stimuli.controlTable(n).variable = 'sf';
me.stimuli.controlTable(n).delta = 0.1;
me.stimuli.controlTable(n).stimuli = [7 8];
me.stimuli.controlTable(n).limits = [0.1 10];
n=n+1;
me.stimuli.controlTable(n).variable = 'speed';
me.stimuli.controlTable(n).delta = 0.5;
me.stimuli.controlTable(n).stimuli = [10];
me.stimuli.controlTable(n).limits = [0.5 8.5];
n=n+1;
me.stimuli.controlTable(n).variable = 'density';
me.stimuli.controlTable(n).delta = 5;
me.stimuli.controlTable(n).stimuli = [10];
me.stimuli.controlTable(n).limits = [1 151];
n=n+1;
me.stimuli.controlTable(n).variable = 'dotSize';
me.stimuli.controlTable(n).delta = 0.01;
me.stimuli.controlTable(n).stimuli = [10];
me.stimuli.controlTable(n).limits = [0.04 0.51];

%------this allows us to enable subsets from our stimulus list
me.stimuli.stimulusSets = {[11], [1 11], [2 11], [3 11], [4 11], [5 11],...
	[6 11], [7 11], [8 11], [9 11], [10 11]};
me.stimuli.setChoice = 3;
showSet(me.stimuli);

%----------------------State Machine States-------------------------
% each cell {array} holds a set of anonymous function handles which are executed by the
% state machine to control the experiment. The state machine can run sets
% at entry, during, to trigger a transition, and at exit. Remember these
% {sets} need to access the objects that are available within the
% runExperiment context (see top of file). You can also add global
% variables/objects then use these. The values entered here are set on
% load, if you want up-to-date values then you need to use methods/function
% wrappers to retrieve/set them.

%--------------------enter pause state
pauseEntryFcn = {
	@()drawBackground(s); %blank the subject display
	@()flip(s); % flip the PTB screen
	@()drawTextNow(s,'Paused, press [p] to resume...');
	@()disp('Paused, press [p] to resume...');
	@()trackerClearScreen(eT); % blank the eyelink screen
	@()trackerDrawText(eT,'PAUSED, press [P] to resume...');
	@()edfMessage(eT,'TRIAL_RESULT -100'); %store message in EDF
	@()setOffline(eT); % make sure we set offline
	@()stopRecording(eT); %stop recording eye position data
	@()disableFlip(me); % no need to flip the PTB screen
	@()needEyeSample(me,false); % no need to check eye position
};

%--------------------within pause state
pauseFcn = { 
	@()WaitSecs('YieldSecs',0.01);
};

%--------------------exit pause state
pauseExitFcn = { 
	@()fprintf('\n===>>>EXIT PAUSE STATE\n')
	@()enableFlip(me); % start PTB screen flips
};

%---------------------prestim entry
psEntryFcn = {
	@()resetFixation(eT,true); %reset the fixation counters ready for a new trial
	@()startRecording(eT); % start eyelink recording for this trial
	@()edfMessage(eT,'V_RT MESSAGE END_FIX END_RT'); % Eyelink commands
	@()edfMessage(eT,sprintf('TRIALID %i',1)); %Eyelink start trial marker
	@()edfMessage(eT,['UUID ' UUID(sM)]); %add in the uuid of the current state for good measure
	@()statusMessage(eT,'Pre-fixation...'); %status text on the eyelink
	@()trackerClearScreen(eT); % blank the eyelink screen
	@()trackerDrawFixation(eT); % draw the fixation window
	@()needEyeSample(me,true); % make sure we start measuring eye position
	@()showSet(me.stimuli); % make sure we prepare to show the stimulus set
	@()logRun(me,'PREFIX'); %fprintf current trial info to command window
};

%prestimulus blank
prestimulusFcn = { 
	@()drawBackground(s); 
	@()drawText(s,'Prefix'); % gives a text lable of what state we are in
};

%---------------------exiting prestimulus state
psExitFcn = { 
	@()statusMessage(eT,'Stimulus...'); % show eyetracker status message
};

%---------------------stimulus entry state
stimEntryFcn = { 
	@()doStrobe(me,true);
	@()logRun(me,'STIMULUS'); % log start to command window
};

%---------------------stimulus within state
stimFcn = { 
	@()draw(me.stimuli); % draw the stimuli
	@()drawText(s,'Stim'); % draw test to show what state we are in
	@()animate(me.stimuli); % animate stimuli for subsequent draw
};

%test we are maintaining fixation
maintainFixFcn = {
	@()testSearchHoldFixation(eT,'correct','breakfix');
};

%as we exit stim presentation state
stimExitFcn = {
	@()setStrobeValue(me,255);
	@()doStrobe(me,true);
	@()mousePosition(s,true);
};

%if the subject is correct (small reward)
correctEntryFcn = {
	@()timedTTL(rM,tS.rewardPin,tS.rewardTime); % labjack sends a TTL to Crist reward system
	@()beep(aM,2000); % correct beep
	@()statusMessage(eT,'Correct! :-)'); 
	@()stopRecording(eT); 
	@()setOffline(eT); %set eyelink offline
	@()trackerClearScreen(eT);
	@()needEyeSample(me,false); % no need to collect eye data until we start the next trial
};

%correct stimulus
correctFcn = { 
	@()drawBackground(s);
};

correctExitFcn = { 
	@()sendStrobe(io,251); % strobe 250 to signal a correct
};

%break entry
breakEntryFcn = { 
	@()beep(aM,400,0.5,1);
	@()sendStrobe(io,249); % strobe 250 to signal a break
	@()trackerClearScreen(eT);
	@()statusMessage(eT,'Broke Fixation :-('); 
	@()stopRecording(eT); 
	@()needEyeSample(me,false); % no need to collect eye data until we start the next trial
};

%incorrect entry
incorrEntryFcn = { 
	@()beep(aM,400,0.5,1);
	@()sendStrobe(io,250); % strobe 252 to signal a incorrect
	@()trackerClearScreen(eT); 
	@()statusMessage(eT,'Incorrect :-('); 
	@()stopRecording(eT); 
	@()needEyeSample(me,false); % no need to collect eye data until we start the next trial
};

%our incorrect stimulus
breakFcn =  {
	@()drawBackground(s);
};

%when we exit the incorrect/breakfix state
ExitFcn = { 
	@()updateVariables(me,1);
	@()updatePlot(bR, eT, sM);
	@()drawnow;
};

%--------------------calibration function
calibrateFcn = { 
	@()drawBackground(s); %blank the display
	@()stopRecording(eT); % stop eyelink recording data
	@()setOffline(eT); % set eyelink offline
	@()trackerSetup(eT) % enter tracker calibrate/validate setup mode
};

%--------------------drift correction function
driftFcn = {
	@()drawBackground(s); %blank the display
	@()stopRecording(eT); % stop eyelink recording data
	@()setOffline(eT); % set eyelink offline
	@()driftCorrection(eT) % enter drift correct
};

%--------------------screenflash
flashFcn = { 
	@()drawBackground(s);
	@()flashScreen(s, 0.2); % fullscreen flash mode for visual background activity detection
};

%----------------------allow override
overrideFcn = { @()keyOverride(me); };

%----------------------show 1deg size grid
gridFcn = { 
	@()drawGrid(s); 
	@()drawScreenCenter(s);
};

% N x 2 cell array of regexpi strings, list to skip the current -> next state's exit functions; for example
% skipExitStates = {'fixate','incorrect|breakfix'}; means that if the currentstate is
% 'fixate' and the next state is either incorrect OR breakfix, then skip the FIXATE exit
% state. Add multiple rows for skipping multiple state's exit states.
sM.skipExitStates = {'fixate','incorrect|breakfix'};


%==================================================================
%----------------------State Machine Table-------------------------
% this table defines the states and relationships and function sets
%==================================================================
disp('================>> Building state info file <<================')
stateInfoTmp = {
'name'      'next'			'time'  'entryFcn'		'withinFcn'		'transitionFcn'	'exitFcn'; 
'pause'		'blank'			inf 	pauseEntryFcn	pauseFcn		[]				pauseExitFcn; 
'blank'		'stimulus'		0.5		psEntryFcn		prestimulusFcn	[]				psExitFcn;
'stimulus'  'incorrect'		5		stimEntryFcn	stimFcn			maintainFixFcn	stimExitFcn;
'incorrect'	'blank'			1		incorrEntryFcn	breakFcn		[]				ExitFcn;
'breakfix'	'blank'			1		breakEntryFcn	breakFcn		[]				ExitFcn;
'correct'	'blank'			0.5		correctEntryFcn	correctFcn		[]				correctExitFcn;
'calibrate' 'pause'			0.5		calibrateFcn	[]				[]				[]; 
'drift'		'pause'			0.5		driftFcn		[]				[]				[];
'flash'		'pause'			0.5		[]				flashFcn		[]				[]; 
'override'	'pause'			0.5		[]				overrideFcn		[]				[]; 
'showgrid'	'pause'			1		[]				gridFcn			[]				[]; 
};
%----------------------State Machine Table-------------------------
%==================================================================

disp(stateInfoTmp)
disp('================>> Loaded state info file <<================')
clear maintainFixFcn prestimulusFcn singleStimulus ...
	prestimulusFcn stimFcn stimEntryFcn stimExitfcn correctEntry correctWithin correctExit ...
	incorrectFcn calibrateFcn gridFcn overrideFcn flashFcn breakFcn

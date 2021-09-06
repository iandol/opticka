%RFLOCALISER state configuration file, this gets loaded by opticka via
% runExperiment class. 
%
% This protocol uses mouse and keyboard control of many different classes
% of stimuli. You can change which stimulus and what variables are during
% the task, while the subject maintains fixation. 
%
% The following class objects (easily named handle copies) are already 
% loaded and available to use. Each class has methods useful for running the task: 
%
% me		= runExperiment object
% s			= screenManager
% aM		= audioManager
% sM		= State Machine
% task		= task sequence (taskSequence class)
% eT		= eyetracker manager
% io		= digital I/O to recording system
% rM		= Reward Manager (LabJack or Arduino TTL trigger to reward system/Magstim)
% bR		= behavioural record plot (on screen GUI during task run)
% stims		= our list of stimuli
% tS		= general structure to hold general variables, will be saved as part of the data

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
tS.nStims				= stims.n;	%==number of stimuli
tS.tOut					= 5;	%==if wrong response, how long to time out before next trial
tS.CORRECT				= 1;	%==the code to send eyetracker for correct trials
tS.BREAKFIX				= -1;	%==the code to send eyetracker for break fix trials
tS.INCORRECT			= -5;	%==the code to send eyetracker for incorrect trials

%==================================================================
%------------Debug logging to command window-----------------
%io.verbose					= true;	%==print out io commands for debugging
%eT.verbose					= true;	%==print out eyelink commands for debugging
%rM.verbose					= true;	%==print out reward commands for debugging

%==================================================================
%-----------------INITIAL Eyetracker Settings----------------------
tS.fixX						= 0;		% X position in degrees
tS.fixY						= 0;		% X position in degrees
tS.firstFixInit				= 3;		% time to search and enter fixation window
tS.firstFixTime				= 3;		% time to maintain fixation within windo
tS.firstFixRadius			= 6;		% radius in degrees
tS.strict					= true;		% do we forbid eye to enter-exit-reenter fixation window?
tS.exclusionZone			= [];		% do we add an exclusion zone where subject cannot saccade to...
tS.stimulusFixTime			= 3;		% time to fix on the stimulus
me.lastXPosition			= tS.fixX;
me.lastYPosition			= tS.fixY;

%==================================================================
%---------------------------Eyetracker setup-----------------------
if me.useEyeLink
	eT.name 					= tS.name;
	eT.sampleRate 				= 250;		% sampling rate
	eT.calibrationStyle 		= 'HV5';	% calibration style
	eT.calibrationProportion	= [0.4 0.4]; %the proportion of the screen occupied by the calibration stimuli
	if tS.saveData == true;		eT.recordData = true; end %===save EDF file?
	if me.dummyMode;			eT.isDummy = true; end %===use dummy or real eyetracker? 
	%-----------------------
	% remote calibration enables manual control and selection of each fixation
	% this is useful for a baby or monkey who has not been trained for fixation
	% use 1-9 to show each dot, space to select fix as valid, INS key ON EYELINK KEYBOARD to
	% accept calibration!
	eT.remoteCalibration		= false; 
	%-----------------------
	eT.modify.calibrationtargetcolour = [1 1 1]; % calibration target colour
	eT.modify.calibrationtargetsize = 2;		% size of calibration target as percentage of screen
	eT.modify.calibrationtargetwidth = 0.15;	% width of calibration target's border as percentage of screen
	eT.modify.waitformodereadytime	= 500;
	eT.modify.devicenumber 			= -1;		% -1 = use any attachedkeyboard
	eT.modify.targetbeep 			= 1;		% beep during calibration
elseif me.useTobii
	eT.name 					= tS.name;
	eT.model					= 'Tobii Pro Spectrum';
	eT.trackingMode				= 'human';
	eT.calPositions				= [ .2 .5; .5 .5; .8 .5 ];
	eT.valPositions				= [ .5 .5 ];
	if me.dummyMode;			eT.isDummy = true; end %===use dummy or real eyetracker? 
end

%Initialise the eyeTracker object with X, Y, FixInitTime, FixTime, Radius, StrictFix
eT.updateFixationValues(tS.fixX, tS.fixY, tS.firstFixInit, tS.firstFixTime, tS.firstFixRadius, tS.strict);
%make sure we don't start with any exclusion zones set up
eT.resetExclusionZones();

%==================================================================
%----which states assigned as correct or break for online plot?----
bR.correctStateName				= 'correct';
bR.breakStateName				= 'breakfix';

%==================================================================
%-------------------randomise stimulus variables every trial?-----------
% if you want to have some randomisation of stimuls variables without
% using taskSequence task, you can uncomment this and runExperiment can
% use this structure to change e.g. X or Y position, size, angle
% see metaStimulus for more details. Remember this will not be "Saved" for
% later use, if you want to do controlled methods of constants experiments
% use taskSequence to define proper randomised and balanced variable
% sets and triggers to send to recording equipment etc...
%
% stims.choice				= [];
% n							= 1;
% in(n).name				= 'xyPosition';
% in(n).values				= [6 6; 6 -6; -6 6; -6 -6; -6 0; 6 0];
% in(n).stimuli				= 1;
% in(n).offset				= [];
% stims.stimulusTable		= in;
stims.choice 				= [];
stims.stimulusTable 		= [];

%--------allows using arrow keys to control this table during presentation
stims.tableChoice = 1;
n=1;
stims.controlTable(n).variable = 'angle';
stims.controlTable(n).delta = 15;
stims.controlTable(n).stimuli = [7 8 9 10];
stims.controlTable(n).limits = [0 360];
n=n+1;
stims.controlTable(n).variable = 'size';
stims.controlTable(n).delta = 0.25;
stims.controlTable(n).stimuli = [2 3 4 5 6 7 8 10];
stims.controlTable(n).limits = [0.25 20];
n=n+1;
stims.controlTable(n).variable = 'flashTime';
stims.controlTable(n).delta = 0.1;
stims.controlTable(n).stimuli = [1 2 3 4 5 6];
stims.controlTable(n).limits = [0.1 1];
n=n+1;
stims.controlTable(n).variable = 'barHeight';
stims.controlTable(n).delta = 1;
stims.controlTable(n).stimuli = [8 9];
stims.controlTable(n).limits = [0.5 15];
n=n+1;
stims.controlTable(n).variable = 'barWidth';
stims.controlTable(n).delta = 0.25;
stims.controlTable(n).stimuli = [8 9];
stims.controlTable(n).limits = [0.25 8.25];
n=n+1;
stims.controlTable(n).variable = 'tf';
stims.controlTable(n).delta = 0.1;
stims.controlTable(n).stimuli = [7];
stims.controlTable(n).limits = [0 12];
n=n+1;
stims.controlTable(n).variable = 'sf';
stims.controlTable(n).delta = 0.1;
stims.controlTable(n).stimuli = [7 8];
stims.controlTable(n).limits = [0.1 10];
n=n+1;
stims.controlTable(n).variable = 'speed';
stims.controlTable(n).delta = 0.5;
stims.controlTable(n).stimuli = [10];
stims.controlTable(n).limits = [0.5 8.5];
n=n+1;
stims.controlTable(n).variable = 'density';
stims.controlTable(n).delta = 5;
stims.controlTable(n).stimuli = [10];
stims.controlTable(n).limits = [1 151];
n=n+1;
stims.controlTable(n).variable = 'dotSize';
stims.controlTable(n).delta = 0.01;
stims.controlTable(n).stimuli = [10];
stims.controlTable(n).limits = [0.04 0.51];

%------this allows us to enable subsets from our stimulus list
stims.stimulusSets = {[11], [1 11], [2 11], [3 11], [4 11], [5 11],...
	[6 11], [7 11], [8 11], [9 11], [10 11]};
stims.setChoice = 3;
showSet(stims);

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
	@()drawTextNow(s,'PAUSED, press [p] to resume...');
	@()disp('PAUSED, press [p] to resume...');
	@()trackerClearScreen(eT); % blank the eyelink screen
	@()trackerDrawText(eT,'PAUSED, press [P] to resume...');
	@()trackerMessage(eT,'TRIAL_RESULT -100'); %store message in EDF
	@()setOffline(eT); % make sure we set offline, only works on eyelink, ignored by tobii
	@()stopRecording(eT, true); %stop recording eye position data
	@()disableFlip(me); % no need to flip the PTB screen
	@()needEyeSample(me,false); % no need to check eye position
};


%--------------------exit pause state
pauseExitFcn = { 
	@()showSet(stims,3);
	@()fprintf('\n===>>>EXIT PAUSE STATE\n')
	@()enableFlip(me); % start PTB screen flips
};

prefixEntryFcn = {
	@()enableFlip(me);
	@()startRecording(eT); %start recording eye position data again
};

prefixFcn = {
	@()drawBackground(s);
	@()drawMousePosition(s,true);
	@()drawText(s,'PREFIX');
};

prefixExitFcn = {
	@()resetFixationHistory(eT); % reset the recent eye position history
	@()resetExclusionZones(eT); % reset the exclusion zones on eyetracker
	@()updateFixationValues(eT,tS.fixX,tS.fixY,[],tS.firstFixTime); %reset fixation window
	@()trackerMessage(eT,'V_RT MESSAGE END_FIX END_RT'); % Eyelink commands
	@()trackerMessage(eT,sprintf('TRIALID %i',getTaskIndex(me))); %Eyelink start trial marker
	@()trackerMessage(eT,['UUID ' UUID(sM)]); %add in the uuid of the current state for good measure
	@()trackerClearScreen(eT); % blank the eyelink screen
	@()trackerDrawFixation(eT); % draw the fixation window
	@()trackerDrawStimuli(eT,stims.stimulusPositions); %draw location of stimulus on eyelink
	@()statusMessage(eT,'Initiate Fixation...'); %status text on the eyelink
	@()needEyeSample(me,true); % make sure we start measuring eye position
};

%fixate entry
fixEntryFcn = {
	
};

%fix within
fixFcn = {
	@()draw(stims{11}); %draw stimulus
	@()drawMousePosition(s,true);
	@()drawText(s,'FIX');
};

%test we are fixated for a certain length of time
inFixFcn = {
	@()testSearchHoldFixation(eT,'stimulus','incorrect')
};

%exit fixation phase
fixExitFcn = {
	@()statusMessage(eT,'Show Stimulus...');
	@()updateFixationValues(eT,[],[],[],tS.stimulusFixTime); %reset fixation time for stimulus = tS.stimulusFixTime
	@()trackerMessage(eT,'END_FIX');
}; 

%---------------------stimulus entry state
stimEntryFcn = { 
	@()doStrobe(me,true);
	@()logRun(me,'STIMULUS'); % log start to command window
};

%---------------------stimulus within state
stimFcn = { 
	@()draw(stims); % draw the stimuli
	@()drawText(s,'STIM');
	@()drawMousePosition(s);
	@()animate(stims); % animate stimuli for subsequent draw
};

%test we are maintaining fixation
maintainFixFcn = {
	@()testHoldFixation(eT,'correct','breakfix');
};

%as we exit stim presentation state
stimExitFcn = {
	@()setStrobeValue(me,255);
	@()doStrobe(me,true);
	@()mousePosition(s,true);
};

%if the subject is correct (small reward)
correctEntryFcn = {
	@()timedTTL(rM, tS.rewardPin, tS.rewardTime); % send a reward TTL
	@()beep(aM,2000,0.1,0.1); % correct beep
	@()trackerMessage(eT,'END_RT');
	@()trackerMessage(eT,sprintf('TRIAL_RESULT %i',tS.CORRECT));
	@()trackerClearScreen(eT);
	@()trackerDrawText(eT,'Correct! :-)');
	@()stopRecording(eT);
	@()setOffline(eT); %set eyelink offline
	@()needEyeSample(me,false); % no need to collect eye data until we start the next trial
};

%correct stimulus
correctFcn = { 
	@()drawBackground(s);
	@()drawMousePosition(s,true);
	@()drawText(s,'CORRECT');
};

correctExitFcn = { 
	@()updatePlot(bR, eT, sM);
	@()drawnow;
};

%break entry
breakEntryFcn = { 
	@()beep(aM,400,0.5,1);
	@()trackerMessage(eT,'END_RT');
	@()trackerMessage(eT,sprintf('TRIAL_RESULT %i',tS.BREAKFIX));
	@()trackerClearScreen(eT);
	@()trackerDrawText(eT,'BREAK! :-(');
	@()stopRecording(eT);
	@()setOffline(eT); %set eyelink offline
	@()needEyeSample(me,false);
};

%incorrect entry
incorrEntryFcn = { 
	@()beep(aM,400,0.5,1);
	@()trackerMessage(eT,'END_RT');
	@()trackerMessage(eT,sprintf('TRIAL_RESULT %i',tS.INCORRECT));
	@()trackerClearScreen(eT);
	@()trackerDrawText(eT,'Incorrect! :-(');
	@()stopRecording(eT);
	@()setOffline(eT); %set eyelink offline
	@()needEyeSample(me,false);
};

%our incorrect stimulus
breakFcn =  {
	@()drawBackground(s);
	@()drawMousePosition(s,true);
	@()drawText(s,'WRONG');
};

%when we exit the incorrect/breakfix state
ExitFcn = { 
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
'name'      'next'		'time'  'entryFcn'		'withinFcn'		'transitionFcn'	'exitFcn'; 
'pause'		'prefix'	inf		pauseEntryFcn	[]				[]				pauseExitFcn;
'prefix'	'fixate'	0.5		prefixEntryFcn	prefixFcn		[]				prefixExitFcn;
'fixate'	'incorrect'	5		fixEntryFcn		fixFcn			inFixFcn		fixExitFcn;
'stimulus'	'incorrect'	5		stimEntryFcn	stimFcn			maintainFixFcn	stimExitFcn;
'incorrect'	'prefix'	1		incorrEntryFcn	breakFcn		[]				ExitFcn;
'breakfix'	'prefix'	1		breakEntryFcn	breakFcn		[]				ExitFcn;
'correct'	'prefix'	0.5		correctEntryFcn	correctFcn		[]				correctExitFcn;
'calibrate' 'pause'		0.5		calibrateFcn	[]				[]				[]; 
'drift'		'pause'		0.5		driftFcn		[]				[]				[];
'flash'		'pause'		0.5		[]				flashFcn		[]				[]; 
'override'	'pause'		0.5		[]				overrideFcn		[]				[]; 
'showgrid'	'pause'		1		[]				gridFcn			[]				[]; 
};
%----------------------State Machine Table-------------------------
%==================================================================

disp(stateInfoTmp)
disp('================>> Loaded state info file <<================')
clear maintainFixFcn prestimulusFcn singleStimulus ...
	prestimulusFcn stimFcn stimEntryFcn stimExitfcn correctEntry correctWithin correctExit ...
	incorrectFcn calibrateFcn gridFcn overrideFcn flashFcn breakFcn

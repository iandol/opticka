%FIXATION TRAINING state configuration file
%
% This presents a fixation spot with a flashing disk in a loop to train for fixation.
% Adjust eyetracker setting values over training to refine behaviour
% The following class objects (easily named handle copies) are already 
% loaded and available to use: 
%
% me = runExperiment object
% io = digital I/O to recording system
% s = screenManager
% aM = audioManager
% sM = State Machine
% eL = eyetracker manager
% t  = task sequence (stimulusSequence class)
% rM = Reward Manager (LabJack or Arduino TTL trigger to reward system/Magstim)
% bR = behavioural record plot (on screen GUI during task run)
% me.stimuli = our list of stimuli
% tS = general struct to hold variables for this run, will be saved

%==================================================================
%------------General Settings-----------------
tS.useTask					= false; %==use stimulusSequence (randomised variable task object)
tS.rewardTime				= 100; %==TTL time in milliseconds
tS.rewardPin				= 2; %==Output pin, 2 by default with Arduino.
tS.checkKeysDuringStimulus  = false; %==allow keyboard control? Slight drop in performance
tS.recordEyePosition		= false; %==record eye position within PTB, **in addition** to the EDF?
tS.askForComments			= false; %==little UI requestor asks for comments before/after run
tS.saveData					= false; %==save behavioural and eye movement data?
tS.useMagStim				= false; %enable the magstim manager
tS.name						= 'fixation-training'; %==name of this protocol

%==================================================================
%------------Eyetracker Settings-----------------
tS.fixX						= 0; % X position in degrees
tS.fixY						= 0; % X position in degrees
tS.firstFixInit				= 2; % time to search and enter fixation window
tS.firstFixTime				= 2; % time to maintain fixation within windo
tS.firstFixRadius			= 2; % radius in degrees
tS.strict					= true; %do we forbid eye to enter-exit-reenter fixation window?
tS.exclusionZone			= []; %do we add an exclusion zone where subject cannot saccade to...
me.lastXPosition			= tS.fixX;
me.lastYPosition			= tS.fixY;

%==================================================================
%------------------------Eyelink setup--------------------------
me.useEyeLink				= true; % make sure we are using eyetracker
eL.name 					= tS.name;
if tS.saveData == true;		eL.recordData = true; end %===save EDF file?
if me.dummyMode;			eL.isDummy = true; end %===use dummy or real eyetracker? 
eL.sampleRate 				= 250; % sampling rate
%===========================
% remote calibration enables manual control and selection of each fixation
% this is useful for a baby or monkey who has not been trained for fixation
% use 1-9 to show each dot, space to select fix as valid, INS key ON EYELINK KEYBOARD to
% accept calibration!
eL.remoteCalibration			= false; 
%===========================
eL.calibrationStyle 			= 'HV5'; % calibration style
eL.modify.calibrationtargetcolour = [1 1 1];
eL.modify.calibrationtargetsize = 1; % size of calibration target as percentage of screen
eL.modify.calibrationtargetwidth = 0.1; % width of calibration target's border as percentage of screen
eL.modify.waitformodereadytime	= 500;
eL.modify.devicenumber 			= -1; % -1==use any keyboard
eL.modify.targetbeep 			= 1;
eL.verbose 						= false;
%oldverbosity					= Eyelink('Verbosity',10);

%Initialise the eyeLink object with X, Y, FixInitTime, FixTime, Radius, StrictFix
eL.updateFixationValues(tS.fixX, tS.fixY, tS.firstFixInit, tS.firstFixTime, tS.firstFixRadius, tS.strict);

%==================================================================
%-------------------randomise stimulus variables every trial?-----------
% if you want to have some randomisation of stimuls variables without
% using stimulusSequence task, you can uncomment this and runExperiment can
% use this structure to change e.g. X or Y position, size, angle
% see metaStimulus for more details. Remember this will not be "Saved" for
% later use, if you want to do controlled methods of constants experiments
% use stimulusSequence to define proper randomised and balanced variable
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

%==================================================================
%-------------allows using arrow keys to control variables?-------------
% another option is to enable manual control of a table of variables
% this is useful to probe RF properties or other features while still
% allowing for fixation or other behavioural control.
me.stimuli.tableChoice				= 1;
n									= 1;
me.stimuli.controlTable(n).variable = 'size';
me.stimuli.controlTable(n).delta	= 0.5;
me.stimuli.controlTable(n).stimuli	= [1];
me.stimuli.controlTable(n).limits	= [0.5 20];
n									= n + 1;
me.stimuli.controlTable(n).variable = 'size';
me.stimuli.controlTable(n).delta	= 0.5;
me.stimuli.controlTable(n).stimuli	= [2];
me.stimuli.controlTable(n).limits	= [0.5 20];

%this allows us to enable subsets from our stimulus list
me.stimuli.stimulusSets				= {[1,2],[2]};
me.stimuli.setChoice				= 1;
showSet(me.stimuli);

%which stimulus in the list from the GUI is used for a fixation target? 
me.stimuli.fixationChoice			= 2;

%===================================================================
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
	@()trackerClearScreen(eL); % blank the eyelink screen
	@()trackerDrawText(eL,'PAUSED, press [P] to resume...');
	@()edfMessage(eL,'TRIAL_RESULT -100'); %store message in EDF
	@()setOffline(eL); % make sure we set offline
	@()stopRecording(eL); %stop recording eye position data
	@()disableFlip(me); % no need to flip the PTB screen
	@()needEyeSample(me,false); % no need to check eye position
};

%--------------------exit pause state
pauseExitFcn = { 
	@()fprintf('\n===>>>EXIT PAUSE STATE\n')
	@()enableFlip(me); % start PTB screen flips
};

%---------------------prestim entry
psEntryFcn = {
	@()trackerClearScreen(eL); % blank the eyelink screen
	@()resetFixation(eL); %reset the fixation counters ready for a new trial
	@()startRecording(eL); % start eyelink recording for this trial
	@()edfMessage(eL,'V_RT MESSAGE END_FIX END_RT'); % Eyelink commands
	@()edfMessage(eL,sprintf('TRIALID %i',getTaskIndex(me))); %Eyelink start trial marker
	@()edfMessage(eL,['UUID ' UUID(sM)]); %add in the uuid of the current state for good measure
	@()statusMessage(eL,'Pre-fixation...'); %status text on the eyelink
	@()trackerDrawFixation(eL); % draw the fixation window
	@()needEyeSample(me,true); % make sure we start measuring eye position
	@()showSet(me.stimuli); % make sure we prepare to show the stimulus set
	@()logRun(me,'PREFIX'); %fprintf current trial info to command window
};

%---------------------prestimulus blank
prestimulusFcn = { 
	@()drawBackground(s); % only draw a background colour to the PTB screen
	@()drawText(s,'Prefix'); % gives a text lable of what state we are in
};

%---------------------exiting prestimulus state
psExitFcn = { 
	@()statusMessage(eL,'Stimulus...'); % show eyetracker status message
};

%---------------------stimulus entry state
stimEntryFcn = { 
	@()logRun(me,'SHOW Fixation Spot'); % log start to command window
};

%---------------------stimulus within state
stimFcn = { 
	@()draw(me.stimuli); % draw the stimuli
	@()drawText(s,'Stim'); % draw test to show what state we are in
	@()drawEyePosition(eL); % draw the eye position to PTB screen
	@()finishDrawing(s); % tell PTB we have finished drawing
	@()animate(me.stimuli); % animate stimuli for subsequent draw
};

%-----------------------test we are maintaining fixation
maintainFixFcn = { 
	% this command performs the logic to search and then maintain fixation inside the
	% fixation window. The parameters are defined above. If the subject does initiate
	% and then maintain fixation, then 'correct' is returned and the state machine
	% will move to the correct state, otherwise 'breakfix' is returned and the state
	% machine will move to the breakfix state.
	@()testSearchHoldFixation(eL,'correct','breakfix'); 
};

%-----------------------as we exit stim presentation state
stimExitFcn = { 
	@()edfMessage(eL,'END_FIX'); % tell EDF we finish fix
	@()edfMessage(eL,'END_RT'); % tell EDF we finish reaction time
};

%-----------------------if the subject is correct (small reward)
correctEntryFcn = {
	@()timedTTL(rM, tS.rewardPin, tS.rewardTime); % send a reward TTL
	@()beep(aM,2000); % correct beep
	@()edfMessage(eL,'TRIAL_RESULT 1'); % tell EDF trial was a correct
	@()statusMessage(eL,'Correct! :-)'); %show it on the eyelink screen
	@()trackerDrawText(eL,'Correct! :-)');
	@()stopRecording(eL); % stop recording for this trial
	@()setOffline(eL); %set eyelink offline
	@()needEyeSample(me,false); % no need to collect eye data until we start the next trial
	@()logRun(me,'CORRECT'); %fprintf current trial info
};

%-----------------------correct stimulus
correctFcn = { 
	@()drawBackground(s); % draw background colour
	@()drawText(s,'Correct'); % draw text
};

%----------------------when we exit the correct state
correctExitFcn = { 
	@()update(me.stimuli); % prepare stimuli for the next trial
	@()updatePlot(bR, eL, sM); % update the behavioural report plot
	@()drawnow; % ensure we update the figure
};

%----------------------break entry
breakEntryFcn = { 
	@()beep(aM,400,0.5,1);
	@()trackerClearScreen(eL);
	@()trackerDrawText(eL,'Broke fix! :-(');
	@()edfMessage(eL,'TRIAL_RESULT 0'); %trial incorrect message
	@()stopRecording(eL); %stop eyelink recording data
	@()setOffline(eL); %set eyelink offline
	@()needEyeSample(me,false);
	@()logRun(me,'BREAKFIX'); %fprintf current trial info
};

%----------------------break entry
incEntryFcn = { 
	@()beep(aM,400,0.5,1);
	@()trackerClearScreen(eL);
	@()trackerDrawText(eL,'Incorrect! :-(');
	@()edfMessage(eL,'TRIAL_RESULT 0'); %trial incorrect message
	@()stopRecording(eL); % stop eyelink recording data
	@()setOffline(eL); % set eyelink offline
	@()needEyeSample(me,false);
	@()logRun(me,'INCORRECT'); %fprintf current trial info
};

%----------------------our incorrect stimulus
breakFcn =  { @()drawBackground(s); @()drawText(s,'Wrong'); };

breakExitFcn = { 
	@()update(me.stimuli); %update our stimuli ready for display
	@()updatePlot(bR, eL, sM);
	@()drawnow;
};

%--------------------calibration function
calibrateFcn = { 
	@()drawBackground(s); %blank the display
	@()stopRecording(eL); % stop eyelink recording data
	@()setOffline(eL); % set eyelink offline
	@()trackerSetup(eL) % enter tracker calibrate/validate setup mode
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
'name'      'next'		'time' 'entryFcn'		'withinFcn'		'transitionFcn'	'exitFcn';
'pause'		'blank'		inf		pauseEntryFcn	[]				[]					pauseExitFcn;
'blank'		'stimulus'	0.5		psEntryFcn		prestimulusFcn	[]					psExitFcn;
'stimulus'  'incorrect'	5		stimEntryFcn	stimFcn			maintainFixFcn		stimExitFcn;
'incorrect'	'blank'		2		incEntryFcn		breakFcn		[]					breakExitFcn;
'breakfix'	'blank'		2		breakEntryFcn	breakFcn		[]					breakExitFcn;
'correct'	'blank'		0.5		correctEntryFcn	correctFcn		[]					correctExitFcn;
'calibrate' 'pause'		0.5		calibrateFcn	[]				[]					[];
'flash'		'pause'		0.5		[]				flashFcn		[]					[];
'override'	'pause'		0.5		[]				overrideFcn		[]					[];
'showgrid'	'pause'		1		[]				gridFcn			[]					[];
};
%----------------------State Machine Table-------------------------
%==================================================================

disp(stateInfoTmp)
disp('================>> Loaded state info file <<================')
clear maintainFixFcn prestimulusFcn singleStimulus pauseEntryFcn ...
	prestimulusFcn stimFcn stimEntryFcn stimExitfcn correctEntry ...
	correctWithin correctExitFcn breakFcn maintainFixFcn psExitFcn ...
	incorrectFcn calibrateFcn gridFcn overrideFcn flashFcn breakFcn
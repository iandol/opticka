% RFLOCALISER state configuration file. This protocol allows you to elicit
% visual responses from a wide range of stimulus classes while a subject
% maintains fixation.
%
% This protocol uses mouse and keyboard control of 10 different classes of
% stimuli (see opticka Stimulus List. You can change which stimulus and
% what variables are during the task, while the subject maintains fixation.
% See Help > Keyboard Map for the keys; basically < and > change stimuli, ←
% and → arrow keys change the variable, and ↑ and ↓ change the variable
% value (see stims.controlTable below for the actual values). You can also
% change the fixation time etc.
%
% The following class objects (easily named handle copies) are already
% loaded and available to use. Each class has methods useful for running
% the task:
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
tS.useTask              = false;	%==use taskSequence (randomised stimulus variable task object)
tS.rewardTime           = 100;		%==TTL time in milliseconds
tS.rewardPin            = 2;		%==Output pin, 2 by default with Arduino.
tS.checkKeysDuringStimulus = true;	%==allow keyboard control? Slight drop in performance
tS.recordEyePosition	= false;	%==record eye position within PTB, **in addition** to the EDF?
tS.askForComments		= false;	%==little UI requestor asks for comments before/after run
tS.saveData				= false;	%==we don't want to save any data
tS.name					= 'RF Localiser'; %==name of this protocol
tS.nStims				= stims.n;	%==number of stimuli
tS.tOut					= 5;		%==if breakfix response, how long to timeout before next trial
tS.CORRECT				= 1;		%==the code to send eyetracker for correct trials
tS.BREAKFIX				= -1;		%==the code to send eyetracker for break fix trials
tS.INCORRECT			= -5;		%==the code to send eyetracker for incorrect trials

%==================================================================
%----------------Debug logging to command window------------------
% uncomment each line to get specific verbose logging from each of these
% components; you can also set verbose in the opticka GUI to enable all of
% these…
%sM.verbose					= true;		%==print out stateMachine info for debugging
%stims.verbose				= true;		%==print out metaStimulus info for debugging
%io.verbose					= true;		%==print out io commands for debugging
%eT.verbose					= true;		%==print out eyelink commands for debugging
%rM.verbose					= true;		%==print out reward commands for debugging
%task.verbose				= true;		%==print out task info for debugging

%==================================================================
%-----------------INITIAL Eyetracker Settings----------------------
tS.fixX						= 0;		% X position in degrees
tS.fixY						= 0;		% X position in degrees
tS.firstFixInit				= 3;		% time to search and enter fixation window
tS.firstFixTime				= 0.5;		% time to maintain fixation within windo
tS.firstFixRadius			= 6;		% radius in degrees
tS.strict					= true;		% do we forbid eye to enter-exit-reenter fixation window?
tS.exclusionZone			= [];		% do we add an exclusion zone where subject cannot saccade to...
tS.stimulusFixTime			= 2.5;		% time to fix on the stimulus
me.lastXPosition			= tS.fixX;
me.lastYPosition			= tS.fixY;

%==================================================================
%---------------------------Eyetracker setup-----------------------
% NOTE: the opticka GUI can set eyetracker options too, if you set options
% here they will OVERRIDE the GUI ones; if they are commented then the GUI
% options are used. me.elsettings and me.tobiisettings contain the GUI
% settings you can test if they are empty or not and set them based on
% that...
eT.name 					= tS.name;
if tS.saveData == true;		eT.recordData = true; end %===save ET data?					
if me.useEyeLink
	eT.name 						= tS.name;
	if me.dummyMode;				eT.isDummy = true; end %===use dummy or real eyetracker? 
	if tS.saveData == true;			eT.recordData = true; end %===save EDF file?
	if isempty(me.elsettings)		%==check if GUI settings are empty
		eT.sampleRate				= 250;		%==sampling rate
		eT.calibrationStyle			= 'HV5';	%==calibration style
		eT.calibrationProportion	= [0.4 0.4]; %==the proportion of the screen occupied by the calibration stimuli
		%-----------------------
		% remote calibration enables manual control and selection of each
		% fixation this is useful for a baby or monkey who has not been trained
		% for fixation use 1-9 to show each dot, space to select fix as valid,
		% INS key ON EYELINK KEYBOARD to accept calibration!
		eT.remoteCalibration		= false; 
		%-----------------------
		eT.modify.calibrationtargetcolour = [1 1 1]; %==calibration target colour
		eT.modify.calibrationtargetsize = 2;		%==size of calibration target as percentage of screen
		eT.modify.calibrationtargetwidth = 0.15;	%==width of calibration target's border as percentage of screen
		eT.modify.waitformodereadytime	= 500;
		eT.modify.devicenumber 			= -1;		%==-1 = use any attachedkeyboard
		eT.modify.targetbeep 			= 1;		%==beep during calibration
	end
elseif me.useTobii
	eT.name 						= tS.name;
	if me.dummyMode;				eT.isDummy = true; end %===use dummy or real eyetracker? 
	if isempty(me.tobiisettings) 	%==check if GUI settings are empty
		eT.model					= 'Tobii Pro Spectrum';
		eT.sampleRate				= 300;
		eT.trackingMode				= 'human';
		eT.calibrationStimulus		= 'animated';
		eT.autoPace					= true;
		%-----------------------
		% remote calibration enables manual control and selection of each
		% fixation this is useful for a baby or monkey who has not been trained
		% for fixation
		eT.manualCalibration		= false;
		%-----------------------
		eT.calPositions				= [ .2 .5; .5 .5; .8 .5];
		eT.valPositions				= [ .5 .5 ];
	end
end

%Initialise the eyeTracker object with X, Y, FixInitTime, FixTime, Radius, StrictFix
eT.updateFixationValues(tS.fixX, tS.fixY, tS.firstFixInit, tS.firstFixTime, tS.firstFixRadius, tS.strict);
%make sure we don't start with any exclusion zones set up
eT.resetExclusionZones();

%==================================================================
%----which states assigned as correct or break for online plot?----
bR.correctStateName				= '^correct';
bR.breakStateName				= '^(breakfix|incorrect)';

%==================================================================
%-------------------randomise stimulus variables every trial?-----------
% if you want to have some randomisation of stimuls variables without using
% a taskSequence task, you can uncomment this and runExperiment can use
% this structure to change e.g. X or Y position, size, angle see
% metaStimulus for more details. Remember this will not be "Saved" for
% later use, if you want to do controlled experiments use taskSequence to
% define proper randomised and balanced variable sets and triggers to send
% to recording equipment etc...
%
% n							= 1;
% in(n).name				= 'xyPosition';
% in(n).values				= [6 6; 6 -6; -6 6; -6 -6; -6 0; 6 0];
% in(n).stimuli				= 1;
% in(n).offset				= [];
% stims.stimulusTable		= in;
stims.choice 				= [];
stims.stimulusTable 		= [];

%==================================================================
%-------------allows using arrow keys to control variables?-------------
% another option is to enable manual control of a table of variables
% this is useful to probe RF properties or other features while still
% allowing for fixation or other behavioural control.
% Use arrow keys <- -> to control value and ↑ ↓ to control variable.
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
stims.controlTable(n).limits = [0.25 25];
n=n+1;
stims.controlTable(n).variable = 'flashTime';
stims.controlTable(n).delta = 0.1;
stims.controlTable(n).stimuli = [1 2 3 4 5 6];
stims.controlTable(n).limits = [0.05 1.05];
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
stims.controlTable(n).delta = 1;
stims.controlTable(n).stimuli = [10];
stims.controlTable(n).limits = [0.5 50.5];
n=n+1;
stims.controlTable(n).variable = 'density';
stims.controlTable(n).delta = 5;
stims.controlTable(n).stimuli = [10];
stims.controlTable(n).limits = [1 151];
n=n+1;
stims.controlTable(n).variable = 'dotSize';
stims.controlTable(n).delta = 0.02;
stims.controlTable(n).stimuli = [10];
stims.controlTable(n).limits = [0.02 0.5];

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

%====================enter pause state
pauseEntryFcn = {
	@()drawBackground(s); %blank the subject display
	@()drawTextNow(s,'PAUSED, press [p] to resume...');
	@()disp('PAUSED, press [p] to resume...');
	@()trackerClearScreen(eT); % blank the eyelink screen
	@()trackerDrawText(eT,'PAUSED, press [P] to resume...');
	@()trackerMessage(eT,'TRIAL_RESULT -100'); %store message in EDF
	@()setOffline(eT); % set eyelink offline [tobii ignores this]
	@()stopRecording(eT, true); %stop recording eye position data
	@()needFlip(me, false); % no need to flip the PTB screen
	@()needEyeSample(me,false); % no need to check eye position
};

%--------------------exit pause state
pauseExitFcn = { 
	@()showSet(stims,3);
	@()fprintf('\n===>>>EXIT PAUSE STATE\n')
	@()needFlip(me, true); % start PTB screen flips
};

%====================prefix entry state
prefixEntryFcn = {
	@()needFlip(me, true);
	@()startRecording(eT); %start recording eye position data again
};

%--------------------prefix within state
prefixFcn = {
	@()drawBackground(s);
	@()drawMousePosition(s,true);
	@()drawText(s,'PREFIX');
};

%--------------------prefix exit state
prefixExitFcn = {
	@()resetFixationHistory(eT); % reset the recent eye position history
	@()resetExclusionZones(eT); % reset any exclusion zones on eyetracker
	@()updateFixationValues(eT,tS.fixX,tS.fixY,[],tS.firstFixTime); %reset fixation window
	@()trackerMessage(eT,'V_RT MESSAGE END_FIX END_RT'); % Eyelink commands
	@()trackerMessage(eT,sprintf('TRIALID %i',getTaskIndex(me))); %Eyelink start trial marker
	@()trackerMessage(eT,['UUID ' UUID(sM)]); %add in the uuid of the current state for good measure
	@()trackerClearScreen(eT); % blank the eyelink screen
	@()trackerDrawFixation(eT); % draw the fixation window
	@()statusMessage(eT,'Initiate Fixation...'); %status text on the eyelink
	@()needEyeSample(me,true); % make sure we start measuring eye position
};

%====================fixate entry
fixEntryFcn = {
	
};

%--------------------fix within
fixFcn = {
	@()draw(stims{11}); %draw stimulus
	@()drawMousePosition(s,true);
};

%--------------------test we are fixated for a certain length of time
inFixFcn = {
	@()testSearchHoldFixation(eT,'stimulus','incorrect')
};

%--------------------exit fixation phase
fixExitFcn = {
	@()statusMessage(eT,'Show Stimulus...');
	@()updateFixationValues(eT,[],[],[],tS.stimulusFixTime); %reset fixation time for stimulus = tS.stimulusFixTime
	@()trackerMessage(eT,'END_FIX');
}; 

%====================stimulus entry state
stimEntryFcn = { 
	@()doStrobe(me,true);
};

%---------------------stimulus within state
stimFcn = { 
	@()draw(stims); % draw the stimuli
	@()drawMousePosition(s);
	@()animate(stims); % animate stimuli for subsequent draw
};

%--------------------test we are maintaining fixation
maintainFixFcn = {
	@()testHoldFixation(eT,'correct','breakfix');
};

%--------------------as we exit stim presentation state
stimExitFcn = {
	@()setStrobeValue(me,255);
	@()doStrobe(me,true);
	@()mousePosition(s,true); %this just prints the current mouse position to the command window
};

%====================if the subject is correct (small reward)
correctEntryFcn = {
	@()timedTTL(rM, tS.rewardPin, tS.rewardTime); % send a reward TTL
	@()beep(aM,2000,0.1,0.1); % correct beep
	@()trackerMessage(eT,'END_RT');
	@()trackerMessage(eT,sprintf('TRIAL_RESULT %i',tS.CORRECT));
	@()trackerClearScreen(eT);
	@()trackerDrawText(eT,'Correct! :-)');
	@()stopRecording(eT);
	@()setOffline(eT); % set eyelink offline [tobii ignores this]
	@()needEyeSample(me,false); % no need to collect eye data until we start the next trial
	@()logRun(me,'CORRECT'); % log start to command window
};

%--------------------correct stimulus
correctFcn = { 
	@()drawBackground(s);
	@()drawMousePosition(s,true);
};

correctExitFcn = { 
	@()updatePlot(bR, me);
	@()update(stims);
	@()drawnow;
};

%====================break entry
breakEntryFcn = { 
	@()beep(aM,400,0.5,1);
	@()trackerMessage(eT,'END_RT');
	@()trackerMessage(eT,sprintf('TRIAL_RESULT %i',tS.BREAKFIX));
	@()trackerClearScreen(eT);
	@()trackerDrawText(eT,'BREAK! :-(');
	@()stopRecording(eT);
	@()setOffline(eT); % set eyelink offline [tobii ignores this]
	@()needEyeSample(me,false);
	@()logRun(me,'BREAK'); % log start to command window
};

%--------------------incorrect entry
incorrEntryFcn = { 
	@()beep(aM,400,0.5,1);
	@()trackerMessage(eT,'END_RT');
	@()trackerMessage(eT,sprintf('TRIAL_RESULT %i',tS.INCORRECT));
	@()trackerClearScreen(eT);
	@()trackerDrawText(eT,'Incorrect! :-(');
	@()stopRecording(eT);
	@()setOffline(eT); % set eyelink offline [tobii ignores this]
	@()needEyeSample(me,false);
	@()logRun(me,'INCORRECT'); % log start to command window
};

%--------------------our incorrect stimulus
breakFcn =  {
	@()drawBackground(s);
	@()drawMousePosition(s,true);
};

%--------------------when we exit the incorrect/breakfix state
ExitFcn = {
	@()updatePlot(bR, me);
	@()update(stims);
	@()drawnow;
};

%====================calibration function
calibrateFcn = { 
	@()drawBackground(s); %blank the display
	@()stopRecording(eT); % stop recording in eyelink [tobii ignores this]
	@()setOffline(eT); % set eyelink offline [tobii ignores this]
	@()trackerSetup(eT) % enter tracker calibrate/validate setup mode
};

%====================drift correction function
driftFcn = {
	@()drawBackground(s); %blank the display
	@()stopRecording(eT); % stop recording in eyelink [tobii ignores this]
	@()setOffline(eT); % set eyelink offline [tobii ignores this]
	@()driftCorrection(eT) % enter drift correct
};

%====================screenflash
flashFcn = { 
	@()drawBackground(s);
	@()flashScreen(s, 0.2); % fullscreen flash mode for visual background activity detection
};

%====================allow override
overrideFcn = { 
	@()keyOverride(me); 
};

%====================show 1deg size grid
gridFcn = { 
	@()drawGrid(s); 
	@()drawScreenCenter(s);
};

% N x 2 cell array of regexpi strings, list to skip the current -> next state's exit functions; for example
% skipExitStates = {'fixate','incorrect|breakfix'}; means that if the currentstate is
% 'fixate' and the next state is either incorrect OR breakfix, then skip the FIXATE exit
% state. Add multiple rows for skipping multiple state's exit states.
sM.skipExitStates = {'fixate','incorrect|breakfix'};


%==============================================================================
%----------------------State Machine Table-------------------------
% specify our cell array that is read by the stateMachine
stateInfoTmp = {
'name'      'next'		'time'  'entryFcn'		'withinFcn'		'transitionFcn'	'exitFcn'; 
'pause'		'prefix'	inf		pauseEntryFcn	{}				{}				pauseExitFcn;
'prefix'	'fixate'	0.5		prefixEntryFcn	prefixFcn		{}				prefixExitFcn;
'fixate'	'incorrect'	5		fixEntryFcn		fixFcn			inFixFcn		fixExitFcn;
'stimulus'	'incorrect'	5		stimEntryFcn	stimFcn			maintainFixFcn	stimExitFcn;
'incorrect'	'timeout'	0.5		incorrEntryFcn	breakFcn		{}				ExitFcn;
'breakfix'	'timeout'	0.5		breakEntryFcn	breakFcn		{}				ExitFcn;
'correct'	'prefix'	0.5		correctEntryFcn	correctFcn		{}				correctExitFcn;
'timeout'	'prefix'	tS.tOut	{}				breakFcn		{}				{};
'calibrate'	'pause'		0.5		calibrateFcn	{}				{}				{}; 
'drift'		'pause'		0.5		driftFcn		{}				{}				{};
'flash'		'pause'		0.5		{}				flashFcn		{}				{}; 
'override'	'pause'		0.5		{}				overrideFcn		{}				{}; 
'showgrid'	'pause'		1		{}				gridFcn			{}				{}; 
};
%----------------------State Machine Table-------------------------
%==============================================================================
disp('================>> Building state info file <<================')
disp(stateInfoTmp)
disp('=================>> Loaded state info file <<=================')
clearvars -regexp '.+Fcn$' % clear the cell array Fcns in the current workspace

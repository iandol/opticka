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
rM.reward.time			= 250;		%==TTL time in milliseconds
rM.reward.pin			= 2;		%==Output pin, 2 by default with Arduino.
tS.keyExclusionPattern	= [];		%==which states to skip keyboard checking
tS.enableTrainingKeys	= true;		%==enable keys useful during task training, but not for data recording
tS.recordEyePosition	= false;	%==record local copy of eye position, **in addition** to the eyetracker?
tS.askForComments		= false;	%==UI requestor asks for comments before/after run
tS.saveData				= false;	%==save behavioural and eye movement data?
tS.showBehaviourPlot	= true;		%==open the behaviourPlot figure? Can cause more memory use…
tS.name					= 'RF Localiser'; %==name of this protocol
tS.nStims				= stims.n;	%==number of stimuli
tS.tOut					= 5;		%==if breakfix response, how long to timeout before next trial
tS.CORRECT				= 1;		%==the code to send eyetracker for correct trials
tS.BREAKFIX				= -1;		%==the code to send eyetracker for break fix trials
tS.INCORRECT			= -5;		%==the code to send eyetracker for incorrect trials
tS.correctSound			= [2000, 0.1, 0.1]; %==freq,length,volume
tS.errorSound			= [300, 1, 1];		%==freq,length,volume

%==================================================================
%----------------Debug logging to command window------------------
% uncomment each line to get specific verbose logging from each of these
% components; you can also set verbose in the opticka GUI to enable all of
% these…
%sM.verbose					= true;		%==print out stateMachine info for debugging
stims.verbose				= true;		%==print out metaStimulus info for debugging
%io.verbose					= true;		%==print out io commands for debugging
%eT.verbose					= true;		%==print out eyelink commands for debugging
%rM.verbose					= true;		%==print out reward commands for debugging
%task.verbose				= true;		%==print out task info for debugging

%==================================================================
%-----------------INITIAL Eyetracker Settings----------------------
tS.fixX						= 0;		% X position in degrees
tS.fixY						= 0;		% X position in degrees
tS.firstFixInit				= 3;		% time to search and enter fixation window
tS.firstFixTime				= 0.2;		% time to maintain fixation within windo
tS.firstFixRadius			= 10;		% radius in degrees
tS.strict					= true;		% do we forbid eye to enter-exit-reenter fixation window?
tS.exclusionZone			= [];		% do we add an exclusion zone where subject cannot saccade to...
tS.stimulusFixTime			= 3;		% time to fix while showing stimulus
updateFixationValues(eT, tS.fixX, tS.fixY, tS.firstFixInit, tS.firstFixTime, tS.firstFixRadius, tS.strict);

%==================================================================
%----which states assigned as correct or break for online plot?----
bR.correctStateName				= "correct";
bR.breakStateName				= ["breakfix","incorrect"];

%=========================================================================
%--------------Randomise stimulus variables every trial?-----------
% If you want to have some randomisation of stimuls variables WITHOUT using
% taskSequence task. Remember this will not be "Saved" for later use, if you
% want to do controlled experiments use taskSequence to define proper randomised
% and balanced variable sets and triggers to send to recording equipment etc...
% Good for training tasks, or stimulus variability irrelevant to the task.
% n								= 1;
% in(n).name					= 'xyPosition';
% in(n).values					= [6 6; 6 -6; -6 6; -6 -6; -6 0; 6 0];
% in(n).stimuli					= 1;
% in(n).offset					= [];
% stims.stimulusTable			= in;
stims.choice					= [];
stims.stimulusTable				= [];

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
stims.controlTable(n).stimuli = [1 7 8 9 10];
stims.controlTable(n).limits = [0 360];
n=n+1;
stims.controlTable(n).variable = 'size';
stims.controlTable(n).delta = 0.25;
stims.controlTable(n).stimuli = [1 2 3 4 5 6 7 8 10];
stims.controlTable(n).limits = [0.25 50];
n=n+1;
stims.controlTable(n).variable = 'flashTime';
stims.controlTable(n).delta = 0.1;
stims.controlTable(n).stimuli = [2 3 4 5 6];
stims.controlTable(n).limits = [0.05 1.05];
n=n+1;
stims.controlTable(n).variable = 'barHeight';
stims.controlTable(n).delta = 1;
stims.controlTable(n).stimuli = [1 8 9];
stims.controlTable(n).limits = [0.5 50];
n=n+1;
stims.controlTable(n).variable = 'barWidth';
stims.controlTable(n).delta = 0.25;
stims.controlTable(n).stimuli = [1 8 9];
stims.controlTable(n).limits = [0.25 50];
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
stims.stimulusSets = {11, [1 11], [2 11], [3 11], [4 11], [5 11],...
	[6 11], [7 11], [8 11], [9 11], [10 11]};
stims.setChoice = 3;

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
	@()hide(stims); % hide all stimuli
	@()drawBackground(s); %blank the subject display
	@()drawTextNow(s,'PAUSED, press [p] to resume...');
	@()disp('PAUSED, press [p] to resume...');
	@()trackerClearScreen(eT); % blank the eyelink screen
	@()trackerDrawStatus(eT,'PAUSED, press [p] to resume');
	@()trackerMessage(eT,'TRIAL_RESULT -100'); %store message in EDF
	@()resetAll(eT); % reset all fixation markers to initial state
	@()setOffline(eT); % set eyelink offline [tobii ignores this]
	@()stopRecording(eT, true); %stop recording eye position data
	@()needFlip(me, false); % no need to flip the PTB screen
	@()needEyeSample(me, false); % no need to check eye position
};

%--------------------exit pause state
pauseExitFcn = { 
	@()startRecording(eT, true);
	@()showSet(stims, 3);
	@()fprintf('\n===>>>EXIT PAUSE STATE\n')
	@()needFlip(me, true); % start PTB screen flips
};

%====================prefix entry state
prefixEntryFcn = {
	@()needFlip(me, true, 1); % enable the screen and trackerscreen flip
	@()needEyeSample(me, true); % make sure we start measuring eye position
	@()startRecording(eT); %start recording eye position data again
};

%--------------------prefix within state
prefixFcn = {
	@()drawBackground(s);
};

%--------------------prefix exit state
prefixExitFcn = {
	@()updateFixationValues(eT,[],[],[],tS.firstFixTime); %reset fixation time for stimulus = tS.stimulusFixTime
	@()trackerMessage(eT,'V_RT MESSAGE END_FIX END_RT'); % Eyelink commands
	@()trackerMessage(eT,sprintf('TRIALID %i',getTaskIndex(me))); %Eyelink start trial marker
	@()trackerMessage(eT,['UUID ' UUID(sM)]); %add in the uuid of the current state for good measure
	@()trackerDrawStatus(eT,'Init Fix...', stims.stimulusPositions);
};

%====================fixate entry
fixEntryFcn = {
	
};

%--------------------fix within
fixFcn = {
	@()draw(stims{11}); %draw stimulus
	@()animate(stims{11}); % animate stimuli for subsequent draw
	@()drawMousePosition(s);
};

%--------------------test we are fixated for a certain length of time
inFixFcn = {
	@()testSearchHoldFixation(eT,'stimulus','breakfix')
};

%--------------------exit fixation phase
fixExitFcn = {
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
	@()animate(stims); % animate stimuli for subsequent draw
	@()drawMousePosition(s);
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
	@()trackerMessage(eT,'END_RT');
	@()trackerMessage(eT,sprintf('TRIAL_RESULT %i',tS.CORRECT));
	@()trackerDrawStatus(eT, 'CORRECT! :-)');
	@()stopRecording(eT);
	@()setOffline(eT); % set eyelink offline [tobii ignores this]
	@()needEyeSample(me,false); % no need to collect eye data until we start the next trial
	@()logRun(me,'CORRECT'); % log start to command window
};

%--------------------correct stimulus
correctFcn = { 
	@()drawBackground(s);
	@()mousePosition(s,true); %this just prints the current mouse position to the command window
};

correctExitFcn = { 
	@()giveReward(rM); % send a reward TTL
	@()beep(aM, tS.correctSound); % correct beep
	@()updatePlot(bR, me);
	@()update(stims);
	@()needFlipTracker(me, 0); %for operator screen stop flip
	@()plot(bR, 1); % actually do our behaviour record drawing
};

%====================break entry
breakEntryFcn = { 
	@()beep(aM,tS.errorSound);
	@()trackerMessage(eT,'END_RT');
	@()trackerMessage(eT,sprintf('TRIAL_RESULT %i',tS.BREAKFIX));
	@()trackerDrawStatus(eT,'BREAK_FIX! :-(', [], 0);
	@()stopRecording(eT);
	@()setOffline(eT); % set eyelink offline [tobii ignores this]
	@()needEyeSample(me,false);
	@()logRun(me,'BREAK'); % log start to command window
};

%--------------------incorrect entry
incorrEntryFcn = { 
	@()beep(aM,tS.errorSound);
	@()trackerMessage(eT,'END_RT');
	@()trackerMessage(eT,sprintf('TRIAL_RESULT %i',tS.INCORRECT));
	@()trackerDrawStatus(eT,'INCORRECT! :-(', stims.stimulusPositions, 0);
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

%--------------------our incorrect stimulus
tOutFcn =  {
	@()drawBackground(s);
	@()drawText(s,'Timeout');
	@()drawMousePosition(s,true);
};

%--------------------when we exit the incorrect/breakfix state
ExitFcn = {
	@()updatePlot(bR, me);
	@()update(stims);
	@()plot(bR, 1); % actually do our behaviour record drawing
};

%========================================================
%========================================================EYETRACKER
%========================================================
%--------------------calibration function
calibrateFcn = {
	@()drawBackground(s); %blank the display
	@()stopRecording(eT); % stop recording in eyelink [tobii ignores this]
	@()setOffline(eT); % set eyelink offline [tobii ignores this]
	@()trackerSetup(eT);  %enter tracker calibrate/validate setup mode
};

%--------------------drift correction function
driftFcn = {
	@()drawBackground(s); %blank the display
	@()stopRecording(eT); % stop recording in eyelink [tobii ignores this]
	@()setOffline(eT); % set eyelink offline [tobii ignores this]
	@()driftCorrection(eT) % enter drift correct (only eyelink)
};
offsetFcn = {
	@()drawBackground(s); %blank the display
	@()stopRecording(eT); % stop recording in eyelink [tobii ignores this]
	@()setOffline(eT); % set eyelink offline [tobii ignores this]
	@()driftOffset(eT) % enter drift offset (works on tobii & eyelink)
};

%========================================================
%========================================================GENERAL
%========================================================
%--------------------DEBUGGER override
overrideFcn = { @()keyOverride(me) }; %a special mode which enters a matlab debug state so we can manually edit object values

%--------------------screenflash
flashFcn = { @()flashScreen(s, 0.2) }; % fullscreen flash mode for visual background activity detection

%--------------------show 1deg size grid
gridFcn = { @()drawGrid(s) };

% N x 2 cell array of regexpi strings, list to skip the current -> next state's exit functions; for example
% skipExitStates = {'fixate','incorrect|breakfix'}; means that if the currentstate is
% 'fixate' and the next state is either incorrect OR breakfix, then skip the FIXATE exit
% state. Add multiple rows for skipping multiple state's exit states.
sM.skipExitStates = {'fixate','incorrect|breakfix'};


%==========================================================================
%==========================================================================
%==========================================================================
%--------------------------State Machine Table-----------------------------
% specify our cell array that is read by the stateMachine
stateInfoTmp = {
'name'		'next'		'time'	'entryFcn'		'withinFcn'		'transitionFcn'	'exitFcn';
%---------------------------------------------------------------------------------------------
'pause'		'prefix'	inf		pauseEntryFcn	{}				{}				pauseExitFcn;
%---------------------------------------------------------------------------------------------
'prefix'	'fixate'	0.5		prefixEntryFcn	prefixFcn		{}				prefixExitFcn;
'fixate'	'incorrect'	5		fixEntryFcn		fixFcn			inFixFcn		fixExitFcn;
'stimulus'	'incorrect'	5		stimEntryFcn	stimFcn			maintainFixFcn	stimExitFcn;
'incorrect'	'timeout'	0.1		incorrEntryFcn	breakFcn		{}				ExitFcn;
'breakfix'	'timeout'	0.1		breakEntryFcn	breakFcn		{}				ExitFcn;
'correct'	'prefix'	0.1		correctEntryFcn	correctFcn		{}				correctExitFcn;
'timeout'	'prefix'	tS.tOut	{}				tOutFcn			{}				{};
%---------------------------------------------------------------------------------------------
'calibrate'	'pause'		0.5		calibrateFcn	{}				{}				{}; 
'drift'		'pause'		0.5		driftFcn		{}				{}				{};
'offset'	'pause'		0.5		offsetFcn		{}				{}				{};
%---------------------------------------------------------------------------------------------
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

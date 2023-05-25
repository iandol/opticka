% FIXATION TRAINING state configuration file
%
% This presents a fixation spot with a flashing disk in a loop to train for
% fixation. There is a distractor that moves around and subject must ignore
% it. Adjust eyetracker setting values over training to refine behaviour
%
%
% The following class objects are already loaded by runTask() and available to
% use; each object has methods (functions) useful for running the task:
%
% me		= runExperiment object ('self' in OOP terminology) 
% s			= screenManager object
% aM		= audioManager object
% stims		= our list of stimuli (metaStimulus class)
% sM		= State Machine (stateMachine class)
% task		= task sequence (taskSequence class)
% eT		= eyetracker manager
% io		= digital I/O to recording system
% rM		= Reward Manager (LabJack or Arduino TTL trigger to reward system/Magstim)
% bR		= behavioural record plot (on-screen GUI during a task run)
% uF		= user defined functions
% tS		= structure to hold general variables, will be saved as part of the data

%==================================================================
%------------------------General Settings--------------------------
tS.useTask					= true;		%==use taskSequence (randomises stimulus variables)
tS.rewardTime				= 250;		%==TTL time in milliseconds
tS.rewardPin				= 2;		%==Output pin, 2 by default with Arduino.
tS.keyExclusionPattern		= [];		%==which states to skip keyboard checking
tS.recordEyePosition		= false;	%==record local copy of eye position, **in addition** to the eyetracker?
tS.askForComments			= false;	%==UI requestor asks for comments before/after run
tS.saveData					= true;		%==save behavioural and eye movement data?
tS.name						= 'fixation+distractor'; %==name of this protocol
tS.nStims					= stims.n;	%==number of stimuli, taken from metaStimulus object
tS.tOut						= 5;		%==if wrong response, how long to time out before next trial
tS.CORRECT 					= 1;		%==the code to send eyetracker for correct trials
tS.BREAKFIX 				= -1;		%==the code to send eyetracker for break fix trials
tS.INCORRECT 				= -5;		%==the code to send eyetracker for incorrect trials
tS.correctSound				= [2000, 0.1, 0.1]; %==freq,length,volume
tS.errorSound				= [300, 1, 1];		%==freq,length,volume

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
% These settings define the initial fixation window and set up for the
% eyetracker. They may be modified during the task (i.e. moving the
% fixation window towards a target, enabling an exclusion window to stop
% the subject entering a specific set of display areas etc.)
%
tS.fixX						= 0; % X position in degrees
tS.fixY						= 0; % X position in degrees
tS.firstFixInit				= 4; % time to search and enter fixation window
tS.firstFixTime				= [0.3 0.5]; % time to maintain fixation within windo
tS.firstFixRadius			= 2; % radius in degrees
tS.strict					= true; %do we forbid eye to enter-exit-reenter fixation window?
tS.exclusionZone			= []; %do we add an exclusion zone where subject cannot saccade to...
me.lastXPosition			= tS.fixX;
me.lastYPosition			= tS.fixY;

%==================================================================
%==================================================================
%---------------------------Eyetracker setup-----------------------
% NOTE: the opticka GUI can set eyetracker options too, if you set options here
% they will OVERRIDE the GUI ones; if they are commented then the GUI options
% are used. runExperiment.elsettings and runExperiment.tobiisettings
% contain the GUI settings; we test if they are empty or not and set
% defaults based on that...
eT.name 					= tS.name;
if tS.saveData == true;	eT.recordData = true; end %===save ET data?					
%Initialise the eyeTracker object with X, Y, FixInitTime, FixTime, Radius, StrictFix
eT.updateFixationValues(tS.fixX, tS.fixY, tS.firstFixInit, tS.firstFixTime, tS.firstFixRadius, tS.strict);
eT.resetAll();

%==================================================================
%----WHICH states assigned as correct or break for online plot?----
%----You need to use regex patterns for the match (doc regexp)-----
bR.correctStateName				= "correct";
bR.breakStateName				= ["breakfix","incorrect"];

%==================================================================
%--------------randomise stimulus variables every trial?-----------
% if you want to have some randomisation of stimuls variables without using
% taskSequence task (i.e. general training tasks), you can uncomment this
% and runExperiment can use this structure to change e.g. X or Y position,
% size, angle see metaStimulus for more details. Remember this will not be
% "Saved" for later use, if you want to do controlled methods of constants
% experiments use taskSequence to define proper randomised and balanced
% variable sets and triggers to send to recording equipment etc...
%
% stims.choice					= [];
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
% Use arrow keys <- -> to control value and up/down to control variable
stims.tableChoice				= 1;
n								= 1;
stims.controlTable(n).variable	= 'size';
stims.controlTable(n).delta		= 0.5;
stims.controlTable(n).stimuli	= [1];
stims.controlTable(n).limits	= [0.5 15];
n								= n + 1;
stims.controlTable(n).variable	= 'contrast';
stims.controlTable(n).delta		= 0.05;
stims.controlTable(n).stimuli	= [1];
stims.controlTable(n).limits	= [0 1];

%==================================================================
%this allows us to enable subsets from our stimulus list
stims.stimulusSets				= {[1,2,3],3};
stims.setChoice					= 1;
hide(stims);

%==================================================================
%which stimulus in the list is used for a fixation target? For this protocol it means
%the subject must fixate this stimulus (the saccade target is #1 in the list) to get the
%reward. Also which stimulus to set an exclusion zone around (where a
%saccade into this area causes an immediate break fixation).
stims.fixationChoice		= 3;
stims.exclusionChoice		= [];

%==================================================================
% N x 2 cell array of regexpi strings, list to skip the current -> next
% state's exit functions; for example skipExitStates =
% {'fixate','incorrect|breakfix'}; means that if the currentstate is
% 'fixate' and the next state is either incorrect OR breakfix, then skip
% running the fixate exit state functions. Add multiple rows for skipping
% multiple exit states. Sometimes the exit functions prepare for some new
% state, and those functions are not relevant if another state comes after.
% In the example, the idea is fixate should go to stimulus, so run
% preparatory functions in exitFcn, but if the subject didn't properly
% fixate, then when going to incorrect we don't need to prepare the
% stimulus.
sM.skipExitStates = {'fixate','incorrect|breakfix'};


%===================================================================
%===================================================================
%===================================================================
%-----------------State Machine Task Functions---------------------
% Each cell {array} holds a set of anonymous function handles which are
% executed by the state machine to control the experiment. The state
% machine can run sets at entry ['entryFcn'], during ['withinFcn'], to
% trigger a transition jump to another state ['transitionFcn'], and at exit
% ['exitFcn'. Remember these {sets} need to access the objects that are
% available within the runExperiment context (see top of file). You can
% also add global variables/objects then use these. The values entered here
% are set on load, if you want up-to-date values then you need to use
% methods/function wrappers to retrieve/set them.

%--------------------enter pause state
pauseEntryFcn = {
	@()hide(stims);
	@()drawBackground(s); %blank the subject display
	@()drawTextNow(s,'PAUSED, press [p] to resume...');
	@()disp('PAUSED, press [p] to resume...');
	@()trackerDrawStatus(eT,'PAUSED, press [P] to resume...');
	@()trackerMessage(eT,'TRIAL_RESULT -100'); %store message in EDF
	@()setOffline(eT); % set eyelink offline [tobii ignores this]
	@()stopRecording(eT, true); %stop recording eye position data
	@()needFlip(me, false, 0); % no need to flip the PTB screen
	@()needEyeSample(me,false); % no need to check eye position
};

%--------------------exit pause state
pauseExitFcn = {
	@()fprintf('\n===>>>EXIT PAUSE STATE\n')
	@()needFlip(me, true, 1); % start PTB screen flips
	@()startRecording(eT, true); % start eyetracker recording for this trial
};

%---------------------prestim entry
psEntryFcn = {
	@()needFlip(me, true, 1); % start PTB screen flips, and tracker screen flip
	@()needEyeSample(me, true); % make sure we start measuring eye position
	@()startRecording(eT); % start eyelink recording for this trial (ignored by tobii/irec as they always records)
	@()resetAll(eT); %reset all fixation counters and history ready for a new trial
	@()getStimulusPositions(stims,true); %make a struct the eT can use for drawing stim positions
	@()trackerMessage(eT,'V_RT MESSAGE END_FIX END_RT'); % Eyelink-specific commands, ignored by other eyetrackers
	@()trackerMessage(eT,sprintf('TRIALID %i',getTaskIndex(me))); %Eyetracker start trial marker
	@()trackerMessage(eT,['UUID ' UUID(sM)]); %add in the uuid of the current state for good measure
	@()trackerClearScreen(eT); %draw status to eyetracker display
	@()logRun(me,'PREFIX'); % log current trial info to command window AND timeLogger
};

%---------------------prestimulus blank
prestimulusFcn = {
	@()trackerDrawFixation(eT);
	@()trackerDrawEyePosition(eT); % draw the fixation point
};

%---------------------exiting prestimulus state
psExitFcn = {
	@()show(stims); % make sure we prepare to show the stimulus set
};

%---------------------stimulus entry state
stimEntryFcn = { };

%---------------------stimulus within state
stimFcn = {
	@()draw(stims); % draw the stimuli
	@()animate(stims); % animate stimuli for subsequent draw
	@()trackerDrawEyePosition(eT); % draw the fixation point
};

%-----------------------test we are maintaining fixation
maintainFixFcn = {
	% this command performs the logic to search and then maintain fixation inside the
	% fixation window. The parameters are defined above. If the subject does initiate
	% and then maintain fixation, then 'correct' is returned and the state machine
	% will move to the correct state, otherwise 'breakfix' is returned and the state
	% machine will move to the breakfix state.
	@()testSearchHoldFixation(eT,'correct','breakfix'); 
};

%-----------------------as we exit stim presentation state
stimExitFcn = {
	@()trackerMessage(eT,'END_FIX'); % tell EDF we finish fix
	@()trackerMessage(eT,'END_RT'); % tell EDF we finish reaction time
};

%-----------------------if the subject is correct (small reward)
correctEntryFcn = {
	@()giveReward(rM); % send a reward TTL
	@()beep(aM, tS.correctSound); % correct beep
	@()trackerMessage(eT,['TRIAL_RESULT ' num2str(tS.CORRECT)]); % tell EDF trial was a correct
	@()trackerDrawStatus(eT,'CORRECT! :-)');
	@()needFlipTracker(me, 0); %for operator screen stop flip
	@()stopRecording(eT); % stop recording in eyelink [tobii ignores this]
	@()setOffline(eT); % set eyelink offline [tobii ignores this]
	@()needEyeSample(me,false); % no need to collect eye data until we start the next trial
	@()logRun(me,'CORRECT'); %fprintf current trial info
};

%-----------------------correct stimulus
correctFcn = {
	
};

%----------------------when we exit the correct state
correctExitFcn = {
	@()updatePlot(bR, me); % update the behavioural report plot
	@()updateVariables(me,[],[],true); ... %update the task variables
	@()update(stims); ... %update our stimuli ready for display
	@()checkTaskEnded(me);
	@()plot(bR, 1); % actually do our behaviour record drawing
};

%----------------------break entry
breakEntryFcn = {
	@()beep(aM,tS.errorSound);
	@()trackerMessage(eT,['TRIAL_RESULT ' num2str(tS.BREAKFIX)]); %trial incorrect message
	@()trackerDrawStatus(eT,'BROKE FIX! :-(');
	@()needFlipTracker(me, 0); %for operator screen stop flip
	@()stopRecording(eT); % stop recording in eyelink [tobii ignores this]
	@()setOffline(eT); % set eyelink offline [tobii ignores this]
	@()needEyeSample(me,false);
	@()hide(stims);
	@()logRun(me,'BREAKFIX'); %fprintf current trial info
};

%----------------------inc entry
incEntryFcn = { 
	@()beep(aM,tS.errorSound);
	@()trackerMessage(eT,['TRIAL_RESULT ' num2str(tS.INCORRECT)]); %trial incorrect message
	@()trackerDrawStatus(eT,'INCORRECT! :-(', stims.stimulusPositions);
	@()needFlipTracker(me, 0); %for operator screen stop flip
	@()stopRecording(eT); % stop recording in eyelink [tobii ignores this]
	@()setOffline(eT); % set eyelink offline [tobii ignores this]
	@()needEyeSample(me,false);
	@()hide(stims);
	@()logRun(me,'INCORRECT'); %fprintf current trial info

};

%----------------------our incorrect stimulus
breakFcn =  {
	
};

%----------------------break exit
breakExitFcn = { 
	@()updatePlot(bR, me);
	@()updateVariables(me,[],[],false); ... %update the task variables
	@()update(stims); %update our stimuli ready for display
	@()checkTaskEnded(me);
	@()plot(bR, 1); % actually do our behaviour record drawing
};

%--------------------calibration function
calibrateFcn = { 
	@()drawBackground(s); %blank the display
	@()stopRecording(eT); % stop recording in eyelink [tobii ignores this]
	@()setOffline(eT); % set eyelink offline [tobii ignores this]
	@()trackerSetup(eT) % enter tracker calibrate/validate setup mode
};

%--------------------drift offset function
offsetFcn = { 
	@()drawBackground(s); %blank the display
	@()stopRecording(eT); % stop recording in eyelink [tobii ignores this]
	@()setOffline(eT); % set eyelink offline [tobii ignores this]
	@()driftOffset(eT) % enter tracker offset
};

%--------------------drift correction function
driftFcn = { 
	@()drawBackground(s); %blank the display
	@()stopRecording(eT); % stop recording in eyelink [tobii ignores this]
	@()setOffline(eT); % set eyelink offline [tobii ignores this]
	@()driftCorrection(eT) % enter drift correct (only eyelink)
};

%--------------------screenflash
flashFcn = { 
	@()drawBackground(s);
	@()flashScreen(s, 0.2); % fullscreen flash mode for visual background activity detection
};

%----------------------allow override
overrideFcn = { 
	@()keyOverride(me); 
};

%----------------------show 1deg size grid
gridFcn = { 
	@()drawGrid(s); 
	@()drawScreenCenter(s);
};

%==================================================================
%----------------------State Machine Table-------------------------
% this table defines the states and relationships and function sets
% name = state name
% next = the next state to switch to
% time = the time in seconds to run this state
% entryFcn = {array} of functions to run when entering the state
% withinFcn = {array} of functions to run during state
% transitionFcn = function to test a condition (i.e. fixation) during the state to switch to another state.
% exitFcn = {array} of functions to run when leaving a state.
%==================================================================
stateInfoTmp = {
'name'		'next'		'time' 'entryFcn'		'withinFcn'		'transitionFcn'		'exitFcn';
%---------------------------------------------------------------------------------------------
'pause'		'blank'		inf		pauseEntryFcn	[]				[]					pauseExitFcn;
%---------------------------------------------------------------------------------------------
'blank'		'stimulus'	0.5		psEntryFcn		prestimulusFcn	[]					psExitFcn;
'stimulus'	'incorrect'	10		stimEntryFcn	stimFcn			maintainFixFcn		stimExitFcn;
'incorrect'	'timeout'	2		incEntryFcn		breakFcn		[]					breakExitFcn;
'breakfix'	'timeout'	2		breakEntryFcn	breakFcn		[]					breakExitFcn;
'correct'	'blank'		0.5		correctEntryFcn	correctFcn		[]					correctExitFcn;
'timeout'	'blank'		tS.tOut	{}				{}				{}					{};
%---------------------------------------------------------------------------------------------
'calibrate' 'pause'		0.5		calibrateFcn	[]				[]					[];
'offset'	'pause'		0.5		offsetFcn		[]				[]					[];
'drift'		'pause'		0.5		driftFcn		[]				[]					[];
%---------------------------------------------------------------------------------------------
'flash'		'pause'		0.5		[]				flashFcn		[]					[];
'override'	'pause'		0.5		[]				overrideFcn		[]					[];
'showgrid'	'pause'		1		[]				gridFcn			[]					[];
};
%----------------------State Machine Table-------------------------
%==================================================================

disp('================>> Building state info file <<================')
disp(stateInfoTmp)
disp('=================>> Loaded state info file <<=================')

clearvars -regexp '.+Fcn'
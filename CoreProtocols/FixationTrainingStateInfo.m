% FIXATION TRAINING 
%
% Protocol presents a pulsing fixation cross with a stimulus in a loop to train
% for fixation. stims should contain 2 stimuli: stims{1} is a attention grabber,
% stims{2} is the fixation cross. Adjust stimulus sizes and eyetracker setting
% values over training to refine behaviour. You can use the ↑ ↓ keys to set the
% variable (size, xPosition, yPosition) and ← → to change the value of the
% variable. You can also use keys to change fixation window size, and time to
% fixate during the session.
%
% The following class objects are already loaded and available to use:
% 
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
%----------------------General Settings----------------------------
tS.useTask					= true;		%==use taskSequence (randomises stimulus variables)
tS.rewardTime				= 250;		%==TTL time in milliseconds
tS.rewardPin				= 2;		%==Output pin, 2 by default with Arduino.
tS.keyExclusionPattern		= [];		%==which states to skip keyboard checking
tS.recordEyePosition		= false;	%==record local copy of eye position, **in addition** to the eyetracker?
tS.askForComments			= false;	%==UI requestor asks for comments before/after run
tS.saveData					= true;		%==save behavioural and eye movement data?
tS.showBehaviourPlot		= true;		%==open the behaviourPlot figure? Can cause more memory use
tS.name						= 'Fixation training'; %==name of this protocol
tS.nStims					= stims.n;	%==number of stimuli, taken from metaStimulus object
tS.tOut						= 5;		%==if wrong response, how long to time out before next trial
tS.CORRECT					= 1;		%==the code to send eyetracker for correct trials
tS.BREAKFIX					= -1;		%==the code to send eyetracker for break fix trials
tS.INCORRECT				= -5;		%==the code to send eyetracker for incorrect trials
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
% initial fixation X position in degrees (0° is screen centre)
tS.fixX						= 0;	
% initial fixation Y position in degrees
tS.fixY						= 0;
% time to search and enter fixation window
tS.firstFixInit				= 3;
% time to maintain fixation within window, can be single value or a range
% to randomise between
tS.firstFixTime				= 0.25;
% circular fixation window radius in degrees
tS.firstFixRadius			= 5;
% do we forbid eye to enter-exit-reenter fixation window? Set false to make it
% easier during training, nd set to true for final data collection.
tS.strict					= false;
% Initialise eyetracker with X, Y, FixInitTime, FixTime, Radius, StrictFix values
updateFixationValues(eT, tS.fixX, tS.fixY, tS.firstFixInit, tS.firstFixTime, tS.firstFixRadius, tS.strict);

%==================================================================
%----WHICH states assigned as correct or break for online plot?----
%----You need to use regex patterns for the match (doc regexp)-----
bR.correctStateName				= "correct";
bR.breakStateName				= ["breakfix","incorrect"];

%==================================================================
%-------------allows using arrow keys to control variables?-------------
% another option is to enable manual control of a table of variables
% this is useful to probe RF properties or other features while still
% allowing for fixation or other behavioural control. This is also useful for
% training.
stims.tableChoice				= 1;
n								= 1;
stims.controlTable(n).variable	= 'size';
stims.controlTable(n).delta		= 0.5;
stims.controlTable(n).stimuli	= [1 2];
stims.controlTable(n).limits	= [0.5 10];
n								= n + 1;
stims.controlTable(n).variable	= 'xPosition';
stims.controlTable(n).delta		= 3;
stims.controlTable(n).stimuli	= [1 2];
stims.controlTable(n).limits	= [-16 16];
n								= n + 1;
stims.controlTable(n).variable	= 'yPosition';
stims.controlTable(n).delta		= 3;
stims.controlTable(n).stimuli	= [1 2];
stims.controlTable(n).limits	= [-16 16];

%==================================================================
%this allows us to enable subsets from our stimulus list
stims.stimulusSets			= {[1,2]};
stims.setChoice				= 1;
hide(stims);

%==================================================================
% which stimulus in the list is used for a fixation target? For this
% protocol it means the subject must fixate this stimulus (the saccade
% target is #1 in the list) to get the reward. Also which stimulus to set
% an exclusion zone around (where a saccade into this area causes an
% immediate break fixation).
stims.fixationChoice = 2;
stims.exclusionChoice = [];

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

%====================================================PAUSE
%--------------------enter pause state
pauseEntryFn = {
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
pauseExitFn = {
	@()fprintf('\n===>>>EXIT PAUSE STATE\n')
	@()startRecording(eT, true); % start eyetracker recording for this trial
};

%---------------------prestim entry
psEntryFn = {
	@()needFlip(me, true, 1); % start PTB screen flips, and tracker screen flip
	@()needEyeSample(me, true); % make sure we start measuring eye position
	@()startRecording(eT); % start eyelink recording for this trial (ignored by tobii/irec as they always records)
	@()getStimulusPositions(stims,true); %make a struct the eT can use for drawing stim positions
	@()updateFixationTarget(me, true);
	@()resetAll(eT); %reset all fixation counters and history ready for a new trial
	@()trackerMessage(eT,'V_RT MESSAGE END_FIX END_RT'); % Eyelink-specific commands, ignored by other eyetrackers
	@()trackerMessage(eT,sprintf('TRIALID %i',getTaskIndex(me))); %Eyetracker start trial marker
	@()trackerMessage(eT,['UUID ' UUID(sM)]); %add in the uuid of the current state for good measure
	@()trackerDrawStatus(eT,'Pre-stimulus...', stims.stimulusPositions);
	@()logRun(me,'PREFIX'); % log current trial info to command window AND timeLogger
};

%---------------------prestimulus blank
prestimulusFn = {
	@()trackerDrawFixation(eT);
	@()trackerDrawEyePosition(eT); % draw the fixation point
};

%---------------------exiting prestimulus state
psExitFn = {
	@()show(stims); % make sure we prepare to show the stimulus set
};

%---------------------stimulus entry state
stimEntryFn = {
	
};

%---------------------stimulus within state
stimFn = {
	@()draw(stims); % draw the stimuli
	@()animate(stims); % animate stimuli for subsequent draw
	@()trackerDrawEyePosition(eT); % draw the fixation point
};

%-----------------------test we are maintaining fixation
maintainFixFn = {
	% this command performs the logic to search and then maintain fixation
	% inside the fixation window. The eyetracker parameters are defined above.
	% If the subject does initiate and then maintain fixation, then 'correct'
	% is returned and the state machine will move to the correct state,
	% otherwise 'breakfix' is returned and the state machine will move to the
	% breakfix state. If neither condition matches, then the state table below
	% defines that after 5 seconds we will switch to the incorrect state.
	@()testSearchHoldFixation(eT,'correct','breakfix'); 
};

%-----------------------as we exit stim presentation state
stimExitFn = {
	@()trackerMessage(eT,'END_FIX'); % tell eyetracker we finish fix
	@()trackerMessage(eT,'END_RT'); % tell eyetracker we finish reaction time
};

%-----------------------if the subject is correct (small reward)
correctEntryFn = {
	@()timedTTL(rM, tS.rewardPin, tS.rewardTime); % send a reward TTL
	@()trackerMessage(eT,['TRIAL_RESULT ' num2str(tS.CORRECT)]); % tell EDF trial was a correct
	@()trackerDrawStatus(eT,'CORRECT! :-)');
	@()needFlipTracker(me, 0); %for operator screen stop flip
	@()stopRecording(eT); % stop recording in eyelink [tobii ignores this]
	@()setOffline(eT); % set eyelink offline [tobii ignores this]
	@()needEyeSample(me,false); % no need to collect eye data until we start the next trial
	@()beep(aM,2000,0.1,0.1); % correct beep
	@()logRun(me,'CORRECT'); %fprintf current trial info
};

%-----------------------correct stimulus
correctFn = {
	
};

%----------------------when we exit the correct state
correctExitFn = {
	@()updatePlot(bR, me); % update the behavioural report plot
	@()updateVariables(me,[],[],true); ... %update the task variables
	@()update(stims); ... %update our stimuli ready for display
	@()checkTaskEnded(me);
	@()plot(bR, 1); % actually do our behaviour record drawing
};

%----------------------break entry
breakEntryFn = {
	@()trackerMessage(eT,['TRIAL_RESULT ' num2str(tS.BREAKFIX)]); %trial incorrect message
	@()trackerDrawStatus(eT,'BROKE FIX! :-(');
	@()needFlipTracker(me, 0); %for operator screen stop flip
	@()stopRecording(eT); % stop recording in eyelink [tobii ignores this]
	@()setOffline(eT); % set eyelink offline [tobii ignores this]
	@()needEyeSample(me,false);
	@()hide(stims);
	@()beep(aM,400,0.5,1);
	@()logRun(me,'BREAKFIX'); %fprintf current trial info
};

%----------------------inc entry
incEntryFn = { 
	@()trackerMessage(eT,['TRIAL_RESULT ' num2str(tS.INCORRECT)]); %trial incorrect message
	@()trackerDrawStatus(eT,'INCORRECT! :-(', stims.stimulusPositions);
	@()needFlipTracker(me, 0); %for operator screen stop flip
	@()stopRecording(eT); % stop recording in eyelink [tobii ignores this]
	@()setOffline(eT); % set eyelink offline [tobii ignores this]
	@()needEyeSample(me,false);
	@()hide(stims);
	@()beep(aM,400,0.5,1);
	@()logRun(me,'INCORRECT'); %fprintf current trial info
};

%----------------------our incorrect stimulus
breakFn =  {
	
};

%----------------------break exit
breakExitFn = { 
	@()updatePlot(bR, me);
	@()updateVariables(me,[],[],false); ... %update the task variables
	@()update(stims); %update our stimuli ready for display
	@()checkTaskEnded(me);
	@()plot(bR, 1); % actually do our behaviour record drawing
};

%--------------------calibration function
calibrateFn = { 
	@()drawBackground(s); %blank the display
	@()stopRecording(eT); % stop recording in eyelink [tobii ignores this]
	@()setOffline(eT); % set eyelink offline [tobii ignores this]
	@()trackerSetup(eT) % enter tracker calibrate/validate setup mode
};

%--------------------drift offset function
offsetFn = { 
	@()drawBackground(s); %blank the display
	@()stopRecording(eT); % stop recording in eyelink [tobii ignores this]
	@()setOffline(eT); % set eyelink offline [tobii ignores this]
	@()driftOffset(eT) % enter tracker offset
};

%--------------------drift correction function
driftFn = { 
	@()drawBackground(s); %blank the display
	@()stopRecording(eT); % stop recording in eyelink [tobii ignores this]
	@()setOffline(eT); % set eyelink offline [tobii ignores this]
	@()driftCorrection(eT) % enter drift correct (only eyelink)
};

%--------------------screenflash
flashFn = { 
	@()drawBackground(s);
	@()flashScreen(s, 0.2); % fullscreen flash mode for visual background activity detection
};

%----------------------allow override
overrideFn = { 
	@()keyOverride(me); 
};

%----------------------show 1deg size grid
gridFn = { 
	@()drawGrid(s); 
	@()drawScreenCenter(s);
};

%==================================================================
%----------------------State Machine Table-------------------------
% this table defines the states and relationships and function sets
%==================================================================
stateInfoTmp = {
'name'		'next'		'time' 'entryFcn'		'withinFcn'		'transitionFcn'	'exitFcn';
%---------------------------------------------------------------------------------------------
'pause'		'blank'		inf		pauseEntryFn	{}				{}				pauseExitFn;
%---------------------------------------------------------------------------------------------
'blank'		'stimulus'	0.5		psEntryFn		prestimulusFn	{}				psExitFn;
'stimulus'	'incorrect'	5		stimEntryFn		stimFn			maintainFixFn	stimExitFn;
'incorrect'	'timeout'	2		incEntryFn		breakFn			{}				breakExitFn;
'breakfix'	'timeout'	2		breakEntryFn	breakFn			{}				breakExitFn;
'correct'	'blank'		0.5		correctEntryFn	correctFn		{}				correctExitFn;
'timeout'	'blank'		tS.tOut	{}				{}				{}				{};
%---------------------------------------------------------------------------------------------
'calibrate' 'pause'		0.5		calibrateFn		{}				{}				{};
'offset'	'pause'		0.5		offsetFn		{}				{}				{};
'drift'		'pause'		0.5		driftFn			{}				{}					{};
%---------------------------------------------------------------------------------------------
'flash'		'pause'		0.5		{}				flashFn			{}				{};
'override'	'pause'		0.5		{}				overrideFn		{}				{};
'showgrid'	'pause'		1		{}				gridFn			{}				{};
};
%----------------------State Machine Table-------------------------
%==================================================================
disp('================>> Building state info file <<================')
disp(stateInfoTmp)
disp('=================>> Loaded state info file <<=================')

clearvars -regexp '.+Fn'


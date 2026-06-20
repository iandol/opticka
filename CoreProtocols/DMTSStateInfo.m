% DELAYED MATCH TO SAMPLE (DMS): The subject fixates a central cross,
% then a sample image appears. After a delay period (maintaining
% fixation only), a choice array of images appears at peripheral locations.
% The subject must saccade to the image matching the sample to receive
% a reward. Distractors are guarded by exclusion zones.
%
% Stimuli (configured from Opticka GUI):
%   stims{1} = fixation cross
%   stims{2} = sample image (shown during sample phase)
%   stims{3} = target (peripheral, image matched to sample via taskSequence)
%   stims{4} = distractor 1
%   stims{5} = distractor 2
%   stims{6} = distractor 3
%   stims{7} = distractor 4
%
% The following class objects are already loaded and available to use:
%
% me		= runExperiment object ('self' in OOP terminology)
% s			= screenManager object
% aM		= audioManager object
% stims		= our list of stimuli (metaStimulus class)
% sM		= State Machine (stateMachine class)
% task		= task sequence (taskSequence class)
% eT		= eyetracker manager
% io		= digital I/O to recording system
% rM		= Reward Manager
% bR		= behavioural record plot (on-screen GUI during a task run)
% uF		= user defined functions, see userFunctions.m
% tS		= structure to hold general variables, saved as part of the data file
% tL		= timeLogger object to hold timing variables, saved as part of the data file

%==================================================================
%----------------------General Settings----------------------------
tS.name						= 'Delayed Match to Sample'; %==name of this protocol
tS.useTask					= true;		%==use taskSequence (randomises stimulus variables)
tS.rewardTime				= 300;		%==TTL time in milliseconds
tS.rewardPin				= 2;		%==Output pin, 2 by default with Arduino.
tS.keyExclusionPattern		= ["fixation","sample","delay","choice"]; %==skip keyboard check
tS.enableTrainingKeys		= false;	%==enable keys useful during task training?
tS.recordEyePosition		= false;	%==record local copy of eye position?
tS.saveData					= true;		%==save behavioural and eye movement data?
tS.showBehaviourPlot		= true;		%==open the behaviourPlot figure?
tS.nStims					= stims.n;	%==number of stimuli, from metaStimulus object
tS.timeOut					= 2;		%==if wrong response, time out before next trial
tS.CORRECT					= 1;		%==code to send eyetracker for correct trials
tS.BREAKFIX					= -1;		%==code to send eyetracker for break fix trials
tS.INCORRECT				= -5;		%==code to send eyetracker for incorrect trials
tS.correctSound				= [2000, 0.1, 0.1]; %==freq,length,volume
tS.errorSound				= [300, 1, 1];		%==freq,length,volume

%==================================================================
%-----------------DMS timing parameters----------------------------
% These control the key phases of the delayed-match-to-sample task.
tS.sampleTime				= 0.5;			%==duration sample image is shown (seconds)
tS.delayTime				= [1.0 2.0];	%==blank delay period (seconds)
tS.choiceTime				= 10.0;			%==max time to make choice saccade (seconds)
addMessage(tL, 0, [], [], sprintf('sampleTime: %0.2f, delayTime: %s, choiceTime: %0.2f', tS.sampleTime, num2str(tS.delayTime), tS.choiceTime),...
 [], 'Experimental-note'); % HED message to store timing parameters in timeLogger

%==================================================================
%-----------------Debug logging to command window------------------
% uncomment each line to get specific verbose logging
%sM.verbose					= true;		%==print out stateMachine info for debugging
%stims.verbose				= true;		%==print out metaStimulus info for debugging
%io.verbose					= true;		%==print out io commands for debugging
eT.verbose					= true;		%==print out eyelink commands for debugging
%rM.verbose					= true;		%==print out reward commands for debugging
%task.verbose				= true;		%==print out task info for debugging

%==================================================================
%-----------------INITIAL Eyetracker Settings----------------------
% These settings define the initial fixation window and set up for the
% eyetracker. They may be modified during the task.
%
% IMPORTANT: ensure the global state time is larger than any fixation
% timers specified here. If the state timer is 5 seconds but your
% fixation timer is 6 seconds, the state will finish before the
% fixation time was completed!
%------------------------------------------------------------------
% initial fixation X position in degrees (0 = screen centre)
tS.fixX						= 0;
% initial fixation Y position in degrees
tS.fixY						= 0;
% time to search and enter fixation window (initiate fixation)
tS.firstFixInit				= 5;
% time to maintain initial fixation within window, can be single value
% or a range to randomise between
tS.firstFixTime				= 0.25;
% circular fixation window radius in degrees
tS.firstFixRadius			= 2;
% do we forbid eye to enter-exit-reenter fixation window?
tS.strict					= true;
% time to maintain fixation during sample presentation
tS.sampleFixTime			= tS.sampleTime;
% time to maintain fixation during delay period
tS.delayFixTime				= NaN; % this is computed per trial based on the randomised delay time, see delayEntryFn
% time to search and enter target fixation window during choice
tS.targetFixInit			= tS.choiceTime - 0.25;
% time to maintain fixation on the chosen target
tS.targetFixTime			= 0.25;
% radius of the target fixation window in degrees
tS.targetRadius				= 5;
% radius of exclusion zones around distractor stimuli (empty = no exclusion)
tS.exclusionRadius			= 5;

% Initialise eyetracker with X, Y, FixInitTime, FixTime, Radius, StrictFix
updateFixationValues(eT, tS.fixX, tS.fixY, tS.firstFixInit, ...
	tS.firstFixTime, tS.firstFixRadius, tS.strict);

%==================================================================
%-----------------BEHAVIOURAL PLOT CONFIGURATION-------------------
%--WHICH states assigned correct / break for the online plot?--
bR.correctStateName				= "correct";
bR.breakStateName				= ["breakfix","incorrect"];

%==================================================================
%-------------------STATE MACHINE CONFIGURATION--------------------
% N x 2 cell array of regexpi strings, list to skip the current -> next
% state's exit functions; e.g. skipExitStates =
% {'fixate','incorrect|breakfix'}; means if currentstate is 'fixate'
% and next is incorrect OR breakfix, skip the FIXATE exit state.
sM.skipExitStates				= {'fixation','incorrect|breakfix'};

%==================================================================
%------------------SACCADE TARGET CONFIGURATION--------------------
% which stimulus in the list is used for the saccade target?
% Set to 3 = the peripheral target image that matches the sample.
stims.fixationChoice			= 2;
% which stimuli define exclusion zones [distractors]?
stims.exclusionChoice			= [3 4 5 6];
stims.stimulusSets			= { 7, [1 7], [2 3 4 5 6] };

%===================================================================
%===================================================================
%===================================================================
%-----------------State Machine Task Functions---------------------
%===================================================================
%===================================================================
%===================================================================

%====================================================PAUSE
%--------------------enter pause state
% This is the state we enter at the start of the task, and whenever we want
% to pause the task. The screen is blank, eye tracking is stopped, and a
% message is displayed to the subject and operator. The task will only
% resume when the operator presses the 'p' key, which triggers a transition
% back to the 'prefix' state.
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
	@()needEyeSample(me, false); % no need to check eye position
};

%--------------------exit pause state
pauseExitFn = {
	@()startRecording(eT, true); % start eyetracker recording
};

%====================================================prefix
%--------------------prefix entry 
% This is the state we enter at the start of each trial. We set up the
% parameters for the trial, send a message to the eyetracker with the trial
% info, and prepare the fixation target for the subject to look at. We also
% start the PTB screen flip
pfEntryFn = {
	@()needFlip(me, true, 4); % start PTB screen flips, tracker screen flip
	@()needEyeSample(me, true); % start measuring eye position
	@()hide(stims); % hide all stimuli
	@()getStimulusPositions(stims,true); %build struct eT can use for drawing
	@()resetAll(eT); %reset all fixation counters and history for a new trial
	@()updateFixationValues(eT,tS.fixX,tS.fixY,tS.firstFixInit, ...
		tS.firstFixTime,tS.firstFixRadius,tS.strict); %reset fixation window
	@()trackerTrialStart(eT, getTaskIndex(me));
	@()trackerMessage(eT,['UUID ' UUID(sM)]); %add uuid of current state
};

%--------------------prefix within
pfWithinFn = {
	@()trackerDrawFixation(eT);
	@()trackerDrawEyePosition(eT);
};

%--------------------exit prefix
pfExitFn = {
	@()logRun(me,'PREFIX');
	@()trackerDrawStatus(eT,'Starting trial...', stims.stimulusPositions);
};

%====================================================FIXATION
%--------------------fixation entry 
% In this state we show the fixation cross and test for fixation. If the
% subject maintains fixation for the required time, we transition to the
% sample phase. If they break fixation for too long, we transition to the
% breakfix state. Note that we use a custom function testSearchHoldFixation
% that allows the subject to search for fixation (i.e. enter and exit the
% fixation window) for a certain amount of time before we break the trial.
fixEntryFn = {
	@()showSet(stims, 1); % show fixation cross (stims{1})
	@()trackerMessage(eT,'MSG:Start Fixation');
};

%--------------------fixation within
fixWithinFn = {
	@()draw(stims);
	@()animate(stims);
	@()trackerDrawEyePosition(eT);
};

%--------------------test we are fixated; jump to sample or breakfix
initFixFn = {
	@()testSearchHoldFixation(eT,'sample','breakfix')
};

%--------------------exit fixation phase
fixExitFn = {};

%====================================================SAMPLE
%--------------------sample entry
sampleEntryFn = {
	@()showSet(stims, 2); % show fixation cross + sample image only
	@()updateFixationValues(eT,[],[],[],tS.sampleFixTime); %reset fix timer
	@()trackerMessage(eT,'MSG:Sample ON');
	@()logRun(me,'MSG:Sample ON');
};

%--------------------sample within
sampleWithinFn = {
	@()draw(stims);
	@()animate(stims);
	@()trackerDrawFixation(eT);
	@()trackerDrawEyePosition(eT);
};

%--------------------test we maintain fixation during sample
sampleFixFn = {
	@()testHoldFixation(eT,'delay','breakfix')
};

%--------------------exit sample
sampleExitFn = {
	@()showSet(stims, 1); % hide sample image, keep fixation cross
	@()trackerMessage(eT,'MSG:Sample OFF');
};

%====================================================DELAY
%--------------------delay entry
delayEntryFn = {
	@()updateFixationValues(eT,[],[],[],tS.delayFixTime); %reset fix timer
	@()trackerMessage(eT,'MSG:Delay ON');
	@()logRun(me,'MSG:Delay ON');
};

%--------------------delay within
delayWithinFn = {
	@()draw(stims); % only fixation cross visible
	@()trackerDrawEyePosition(eT);
};

%--------------------test we maintain fixation during delay
delayFixFn = {
	@()testHoldFixation(eT,'choice','breakfix')
};

%--------------------exit delay
delayExitFn = {
	@()showSet(stims, 3); % hide fixation cross and sample for choice phase
};

%====================================================CHOICE
%--------------------choice entry
choiceEntryFn = {
	% update fixation target to the target stimulus position
	@()updateFixationTarget(me, true, tS.targetFixInit, ...
		tS.targetFixTime, tS.targetRadius, tS.strict);
	% create exclusion zones around distractor stimuli
	@()updateExclusionZones(me, true, tS.exclusionRadius);
	% show the choice array (target + distractors, stimuli 3..7)
	% send a sync time message
	@()doSyncTime(me);
	% send strobe with stimulus value
	@()doStrobe(me,true);
	@()trackerMessage(eT,'MSG:Choice ON');
	@()logRun(me,'MSG:Choice ON');
};

%--------------------choice within
choiceWithinFn = {
	@()draw(stims);
	@()animate(stims);
	@()trackerDrawEyePosition(eT);
	@()trackerDrawStimuli(eT, stims.stimulusPositions);
};

%--------------------test subject finds target or enters exclusion zone
choiceFixFn = {
	@()testSearchHoldFixation(eT,'correct','incorrect')
};

%--------------------exit choice
choiceExitFn = {
	@()setStrobeValue(me, me.strobe.stimOFFValue);
	@()doStrobe(me,true);
	@()trackerMessage(eT,'MSG:Choice OFF');
	@()logRun(me,'MSG:Choice OFF');
};

%====================================================CORRECT
%--------------------correct entry
correctEntryFn = {
	@()trackerTrialEnd(eT, tS.CORRECT); % send end-trial cleanup
	@()trackerDrawStatus(eT,'CORRECT! :-)', stims.stimulusPositions, 0);
	@()needFlipTracker(me, 0); %for operator screen stop flip
	@()needEyeSample(me,false); % stop eye sampling until next trial
	@()giveReward(rM); % send a reward
	@()beep(aM, tS.correctSound); % correct beep
	@()logRun(me,'CORRECT'); %fprintf current trial info
};

%--------------------correct within
correctWithinFn = {};

%--------------------correct exit
correctExitFn = {
	@()updatePlot(bR, me); % update behavioural report plot
	@()updateTask(me,tS.CORRECT); % move taskSequence to next trial
	@()updateVariables(me,[],[],true); % randomise stimuli, set strobe
	@()updateStimuliImages(uF); % update sample / distractor stimulus images for next trial
	@()updateLocations(uF); % update distractor locations for next trial
	@()updateDelayTime(uF); % update delay time for next trial based on randomised trial condition
	@()update(stims); % update stimuli ready for display
	@()resetAll(eT); % reset the exclusion zones and fixation state
	@()plot(bR, 1); % actually do behaviour record drawing
	@()checkTaskEnded(me); % check if task is finished
};

%====================================================INCORRECT
%--------------------incorrect entry
incEntryFn = {
	@()trackerTrialEnd(eT, tS.INCORRECT); % send end-trial cleanup
	@()trackerDrawStatus(eT,'INCORRECT! :-(', stims.stimulusPositions, 0);
	@()needFlipTracker(me, 0); %for operator screen stop flip
	@()needEyeSample(me,false);
	@()hide(stims);
	@()beep(aM, tS.errorSound);
	@()logRun(me,'MSG:Incorrect'); %fprintf current trial info
};

%--------------------incorrect within
incWithinFn = {};

%--------------------incorrect exit
incExitFn = {
	@()updatePlot(bR, me);
	@()updateVariables(me,[],[],false); % randomise stimuli, set strobe
	@()updateStimuliImages(uF); % update sample / distractor stimulus images for next trial
	@()updateLocations(uF); % update distractor location for next trial
	@()updateDelayTime(uF); % update delay time for next trial based on randomised trial condition
	@()update(stims); % update stimuli ready for display
	@()resetAll(eT); % reset exclusion zones
	@()plot(bR, 1);
	@()checkTaskEnded(me);
};

%====================================================BREAKFIX
%--------------------breakfix entry
breakEntryFn = {
	@()trackerTrialEnd(eT, tS.BREAKFIX); % send end-trial cleanup
	@()trackerDrawStatus(eT,'BROKE FIX! :-(', stims.stimulusPositions, 0);
	@()needFlipTracker(me, 0); %for operator screen stop flip
	@()needEyeSample(me,false);
	@()hide(stims);
	@()beep(aM, tS.errorSound);
	@()logRun(me,'MSG:Breakfix'); %fprintf current trial info
};

%--------------------breakfix within
breakWithinFn = {};

%--------------------breakfix exit
breakExitFn = {
	@()updatePlot(bR, me);
	@()updateVariables(me,[],[],false); % randomise stimuli, set strobe
	@()updateStimuliImages(uF); % update sample / distractor stimulus images for next trial	
	@()updateLocations(uF); % update distractor locations for next trial
	@()updateDelayTime(uF); % update delay time for next trial based on randomised trial condition
	@()update(stims); % update stimuli ready for display
	@()resetAll(eT); % reset exclusion zones
	@()plot(bR, 1);
	@()checkTaskEnded(me);
};

%========================================================
%========================================================EYETRACKER
%========================================================
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

%========================================================
%========================================================GENERAL
%========================================================
%--------------------screenflash
flashFn = {
	@()drawBackground(s);
	@()flashScreen(s, 0.2); % fullscreen flash for visual activity detection
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
'name'		'next'		'time'			'entryFcn'		'withinFcn'		'transitionFcn'	'exitFcn'	'HED';
%---------------------------------------------------------------------------------------------
'pause'		'prefix'	inf				pauseEntryFn	{}				{}				pauseExitFn	'Experiment-control, Pause';
%---------------------------------------------------------------------------------------------
'prefix'	'fixation'	0.5				pfEntryFn		pfWithinFn		{}				pfExitFn	'Experiment-control';
'fixation'	'breakfix'	10				fixEntryFn		fixWithinFn		initFixFn		fixExitFn	'Experiment-structure, Agent-action, Move-eyes';
'sample'	'breakfix'	tS.sampleTime	sampleEntryFn	sampleWithinFn	sampleFixFn		sampleExitFn 'Sensory-event,Experimental-stimulus';
'delay'		'breakfix'	tS.delayTime	delayEntryFn	delayWithinFn	delayFixFn		delayExitFn	'Experiment-control, Delay';
'choice'	'incorrect'	tS.choiceTime	choiceEntryFn	choiceWithinFn	choiceFixFn		choiceExitFn 'Experiment-structure, Sensory-event, Experimental-stimulus, Agent-action, Move-eyes';
'correct'	'prefix'	0.1				correctEntryFn	correctWithinFn	{}				correctExitFn 'Experiment-control, Correct-action';
'incorrect'	'timeout'	0.1				incEntryFn		incWithinFn		{}				incExitFn	'Experiment-control, Incorrect-action';
'breakfix'	'timeout'	0.1				breakEntryFn	breakWithinFn	{}				breakExitFn	'Experiment-control, Inappropriate-action';
'timeout'	'prefix'	tS.timeOut		{}				{}				{}				{}			'Experiment-control, Delay';
%---------------------------------------------------------------------------------------------
'calibrate'	'pause'		0.5				calibrateFn		{}				{}				{}			'Experiment-control';
'offset'	'pause'		0.5				offsetFn		{}				{}				{}			'Experiment-control';
'drift'		'pause'		0.5				driftFn			{}				{}				{}			'Experiment-control';
%---------------------------------------------------------------------------------------------
'flash'		'pause'		0.5				{}				flashFn			{}				{}			'Experiment-control';
'override'	'pause'		0.5				{}				overrideFn		{}				{}			'Experiment-control';
'showgrid'	'pause'		1				{}				gridFn			{}				{}			'Experiment-control';
};
%----------------------State Machine Table-------------------------
%==================================================================
disp('================>> Building Delayed Match to Sample state info <<================')
disp(stateInfoTmp)
disp('=================>> Loaded state info file <<=================')

clearvars -regexp '.+Fn'

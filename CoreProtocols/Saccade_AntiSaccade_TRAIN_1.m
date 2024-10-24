% SACCADE / ANTISACCADE TRAINING 1.
% This task uses 3 stimuli: (1) pro-saccade target
% (2) anti-saccade target and (3) fixation cross. The task sequence is set
% up to randomise the X position of (1) ±10° on each trial, and (2) has a
% modifier set as the inverse (if (1) is -10° on a trial then (2) becomes
% +10°). For the pro-saccade task, show (1) and hide (2), fixation window
% set on (1) and an exclusion zone set around (2). In the anti-saccade task
% we show (2) and set the opacity of (1) during training to encourage the
% subject to saccade away from (2) towards (1); the fixation and exclusion
% windows keep the same logic as for the pro-saccade condition.
%
% NOTE: this pro/anti-saccade task does not impose a delay. Delays are
% common to help analysis of recorded neurons, however, teaching
% subjects to delay their [pro|anti]saccade interferes with the main
% effect!
%
%> This state control file will usually be run in the scope of the calling
%> runExperiment.runTask() method and other objects will be available at run time
%> (with easy to use names listed below). The following class objects are already
%> loaded by runTask() and available to use; each object has methods (functions)
%> useful for running the task:
%
%> me		= runExperiment object ('self' in OOP terminology) 
%> tS		= structure to hold general variables, will be saved as part of the data
%> s		= PTB screen manager object (screenManager class)
%> sM		= state machine (stateMachine class) parses and runs this file
%> task		= task independent variable manager (taskSequence class)
%> stims	= all visual stimuli (metaStimulus class)
%> aM		= audioManager object
%> eT		= eyetracker manager (eyelink / tobii / irec / pupilcore classes)
%> tM		= touchscreen manager
%> io		= digital I/O for recording system
%> rM		= Reward Manager (LabJack or Arduino TTL trigger to reward system/Magstim)
%> bR		= behavioural record plot (on-screen GUI during a task run)
%> uF		= user functions - add your own functions to this class

%==================================================================
%--------------------TASK SPECIFIC CONFIG--------------------------
% is this run a 'saccade' or 'anti-saccade' task run?
% we use manuN to show a selection menu to get values from the user.
title = {'[Anti]Saccade','Choose which type of task to perform.|You can also set the alpha of the |pro and anti saccade targets|which helps the subject during training.'};
tS.options = {'r|¤Pro-Saccade|Anti-Saccade','Choose Protocol Type:';...
	't|0.75','Prosaccade Target Initial Alpha:';...
	't|0.75','Prosaccade Target Main Alpha:';...
	't|0.1','Antisaccade Target Initial Alpha:';...
	't|0.2','Antisaccade Target Main Alpha:'};
if exist('isRunning','var') && isRunning == true % we are actually running a task, ask user
	tS.ua = menuN(title,tS.options);
else % just loading the state file, pass defaults
	tS.ua{1}=1;tS.ua{2}=0.75;yS.us{3}=0.75;tS.ua{4}=0.1;tS.ua{5}=0.2;
end
if tS.ua{1} == 1
	tS.type						= 'saccade';
else
	tS.type						= 'anti-saccade';
end
% update the trial number for incorrect saccades: if true then we call
% updateTask for both correct and incorrect trials, otherwise we only call
% updateTask() for correct responses.
tS.includeErrors			= false; 
tS.name						= 'saccade-antisaccade'; %==name of this protocol

% note there are TWO alpha values, this is used by
% tS.fixAndStimTime below to control an initial visualisation 
% of the targets during fixation mostly used during training
% to guide the subject.
if strcmp(tS.type,'saccade')
	% a flag to conditionally set visualisation on the eye tracker interface
	stims{1}.showOnTracker	= true;
	stims{2}.showOnTracker	= false;
	tS.targetAlpha1			= tS.ua{2};
	tS.targetAlpha2			= tS.ua{3};
	tS.antitargetAlpha1		= 0;
	tS.antitargetAlpha2		= 0;
else
	% a flag to conditionally set visualisation on the eye tracker interface
	stims{1}.showOnTracker	= false;
	stims{2}.showOnTracker	= true;
	% for use with tS.fixAndStimTime:
	% alpha can be used during training to keep saccade target visible (i.e. in
	% the anti-saccade task the subject must saccade away from the
	% anti-saccade target towards to place where the pro-saccade target is, so
	% starting training keeping the pro-saccade target visible helps the
	% subject understand the task. Change the relative alpha values over
	% training until ONLY the anti target is visible before collecting
	% data.
	tS.targetAlpha1			= tS.ua{2};
	tS.targetAlpha2			= tS.ua{3};
	tS.antitargetAlpha1		= tS.ua{4};
	tS.antitargetAlpha2		= tS.ua{5};
end
disp(['\n===>>> Task ' tS.name ' Type:' tS.type ' <<<===\n'])

%==================================================================
%----------------------General Settings----------------------------
tS.saveData					= true;		%==save behavioural and eye movement data?
tS.showBehaviourPlot		= true;		%==open the behaviourPlot figure? Can cause more memory use…
tS.useTask					= true;		%==use taskSequence (randomises stimulus variables)
tS.keyExclusionPattern		= ["fixstim","stimulus"]; %==which states to skip keyboard checking
tS.enableTrainingKeys		= false;	%==enable keys useful during task training, but not for data recording
tS.recordEyePosition		= false;	%==record local copy of eye position, **in addition** to the eyetracker?
tS.includeErrors			= false;	%==do we update the trial number even for incorrect saccade/fixate, if true then we call updateTask for both correct and incorrect, otherwise we only call updateTask() for correct responses
tS.nStims					= stims.n;	%==number of stimuli, taken from metaStimulus object
tS.timeOut					= 2;		%==if wrong response, how long to time out before next trial
tS.CORRECT					= 1;		%==the code to send eyetracker for correct trials
tS.BREAKFIX					= -1;		%==the code to send eyetracker for break fix trials
tS.INCORRECT				= -5;		%==the code to send eyetracker for incorrect trials
tS.correctSound				= [2000, 0.1, 0.1]; %==freq,length,volume
tS.errorSound				= [300, 1, 1];		%==freq,length,volume
% reward system values, set by GUI, but could be overridden here
%rM.reward.time				= 250;		%==TTL time in milliseconds
%rM.reward.pin				= 2;		%==Output pin, 2 by default with Arduino.

%==================================================================
%-----------------DEBUG LOGGING to command window------------------
% uncomment each line to get specific verbose logging from each of these
% components; you can also set verbose in the opticka GUI to enable all of
% these…
%sM.verbose					= true;	%==print out stateMachine info for debugging
%stims.verbose				= true;	%==print out metaStimulus info for debugging
%io.verbose					= true;	%==print out io commands for debugging
%eT.verbose					= true;	%==print out eyelink commands for debugging
%rM.verbose					= true;	%==print out reward commands for debugging
%task.verbose				= true;	%==print out task info for debugging

%==================================================================
%-----------------INITIAL Eyetracker Settings----------------------
% These settings define the initial fixation window and set up for the
% eyetracker. They may be modified during the task (i.e. moving the
% fixation window towards a target, enabling an exclusion window to stop
% the subject entering a specific set of display areas etc.)
%
% IMPORTANT: you need to make sure that the global state time is larger
% than the fixation timers specified here. Each state has a global timer,
% so if the state timer is 5 seconds but your fixation timer is 6 seconds,
% then the state will finish before the fixation time was completed!

% initial fixation X position in degrees (0° is screen centre)
tS.fixX						= 0;
% initial fixation Y position in degrees
tS.fixY						= 0;
% time to search and enter fixation window
tS.firstFixInit				= 15;
% time to maintain initial fixation within window, can be single value or a
% range to randomise between
tS.firstFixTime				= [0.5 0.9];
% circular fixation window radius in degrees
tS.firstFixRadius			= 4;
% do we forbid eye to enter-exit-reenter fixation window?
tS.strict					= false;
% time to show BOTH fixation cross and [anti]saccade target
% this allows the first alpha values to be useful
tS.fixAndStimTime			= 0.1;
% in this task the subject must saccade to the pro-saccade target location.
% These settings define the rules to "accept" the target fixation as
% correct
tS.targetFixInit			= 5; % time to find the target
tS.targetFixTime			= 0.1; % to to maintain fixation on target 
tS.targetRadius				= 8; %circular radius width x height to fix within.
% this task will establish an exclusion zone over the anti-saccade
% target for the pro and anti-saccade task. We can change the size of the
% exclusion zone, here set to 7 x 25° centered on the X and Y position of the
% anti-saccade target.
tS.exclusionRadius			= [3 25]; %width x height of eye exclusion window.
% Initialise the eyeTracker object with X, Y, FixInitTime, FixTime, Radius, StrictFix
updateFixationValues(eT, tS.fixX, tS.fixY, tS.firstFixInit, tS.firstFixTime, tS.firstFixRadius, tS.strict);

%==================================================================
%-----------------BEAVIOURAL PLOT CONFIGURATION--------------------
%--WHICH states assigned correct / incorrect for the online plot?--
bR.correctStateName			= "correct";
bR.breakStateName			= ["breakfix","incorrect"];

%======================================================================
% N x 2 cell array of regexpi strings, list to skip the current -> next
% state's exit functions; for example skipExitStates =
% {'fixate','incorrect|breakfix'}; means that if the currentstate is
% 'fixate' and the next state is either incorrect OR breakfix, then skip
% the FIXATE exit state. Add multiple rows for skipping multiple state's
% exit states.
sM.skipExitStates			= {'fixate','incorrect|breakfix'};

%==================================================================
% which stimulus in the list is used for a fixation target? For this
% protocol it means the subject must saccade this stimulus (the saccade
% target is #1 in the list) to get the reward. Also which stimulus to set an
% exclusion zone around (where a saccade into this area causes an immediate
% break fixation).
stims.fixationChoice		= 1;
stims.exclusionChoice		= 2;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%------------------------------------------------------------------------%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%=========================================================================
%------------------State Machine Task Functions---------------------
% Each cell {array} holds a set of anonymous function handles which are
% executed by the state machine to control the experiment. The state
% machine can run sets at entry ['entryFcn'], during ['withinFcn'], to
% trigger a transition jump to another state ['transitionFcn'], and at exit
% ['exitFcn'. Remember these {sets} need to access the objects that are
% available within the runExperiment context (see top of file). You can
% also add global variables/objects then use these. The values entered here
% are set on load, if you want up-to-date values then you need to use
% methods/function wrappers to retrieve/set them.
%=========================================================================


%========================================================
%========================================================PAUSE
%========================================================

%--------------------pause entry
pauseEntryFn = { 
	@()hide(stims);
	@()drawBackground(s); %blank the subject display
	@()drawTextNow(s,'PAUSED, press [p] to resume...');
	@()disp('PAUSED, press [p] to resume...');
	@()trackerDrawStatus(eT,'PAUSED, press [p] to resume', stims.stimulusPositions);
	@()trackerMessage(eT,'TRIAL_RESULT -100'); %store message in EDF
	@()resetAll(eT); % reset all fixation markers to initial state
	@()setOffline(eT); % set eyelink offline [tobii ignores this]
	@()stopRecording(eT, true); %stop recording eye position data, true=both eyelink & tobii
	@()needFlip(me, false, 0); % no need to flip the PTB screen
	@()needEyeSample(me,false); % no need to check eye position
};

%--------------------pause exit
pauseExitFn = {
	%start recording eye position data again, note true is required here as
	%the eyelink is started and stopped on each trial, but the tobii runs
	%continuously, so @()startRecording(eT) only affects eyelink but
	%@()startRecording(eT, true) affects both eyelink and tobii...
	@()startRecording(eT, true); 
};

%====================================================PRE-FIXATION
pfEntryFn = {
	@()needFlip(me, true, 1); % start PTB screen flips, and tracker screen flip
	@()needEyeSample(me, true); % make sure we start measuring eye position
	@()getStimulusPositions(stims,true); %make a struct the eT can use for drawing stim positions
	@()updateFixationValues(eT,tS.fixX,tS.fixY,tS.firstFixInit,tS.firstFixTime,tS.firstFixRadius,tS.strict); %reset fixation window
	@()trackerTrialStart(eT, getTaskIndex(me));
	@()trackerMessage(eT,['UUID ' UUID(sM)]); %add in the uuid of the current state for good measure
	@()logRun(me,'PREFIX'); % log current trial info to command window AND timeLogger
};

pfWithinFn = {
	
};

pfExitFn = {
	
};

%====================================================FIXATION
%--------------------fixate entry
fixEntryFn = { 
	% show stimulus 3 = fixation cross
	@()show(stims, 3);
	@()trackerDrawStatus(eT,'START TRIAL', stims.stimulusPositions, 0, false);
};

%--------------------fix within
fixWithinFn = {
	@()draw(stims); %draw stimulus
	@()trackerDrawEyePosition(eT);
};

%--------------------test we are fixated for a certain length of time
initFixFn = { 
	% this command performs the logic to search and then maintain fixation
	% inside the fixation window. The eyetracker parameters are defined above.
	% If the subject does initiate and then maintain fixation, then 'fixstim'
	% is returned and the state machine will jump to that state,
	% otherwise 'incorrect' is returned and the state machine will jump there. 
	% If neither condition matches, then the state table below
	% defines that after 5 seconds we will switch to the incorrect state.
	@()testSearchHoldFixation(eT,'fixstim','breakfix')
};

%--------------------exit fixation phase
if strcmpi(tS.type,'saccade')
	fixExitFn = { 
		@()show(stims, [1 3]); 
		@()edit(stims,1,'alphaOut',tS.targetAlpha1);
	};
else
	fixExitFn = { 
		@()show(stims, [1 2 3]); 
		@()edit(stims,1,'alphaOut',tS.targetAlpha1);
		@()edit(stims,2,'alphaOut',tS.antitargetAlpha1)
	};
end

%====================================================FIX + TARGET STIMULUS
fsEntryFn = {
	@()updateFixationValues(eT,[],[],[],tS.fixAndStimTime); %reset the fixation timer 
	@()logRun(me,'FIX+STIM'); %fprintf current trial info to command window
};

fsWithinFn = {
	@()draw(stims); %draw stimulus
	@()trackerDrawEyePosition(eT);
};

% test we are fixated for a certain length of time, testHoldFixation assumes
% we are already fixated which we are coming from the fixate state...
fsFixFn = { 
	@()testHoldFixation(eT,'stimulus','incorrect')
};

% exit fixation phase
fsExitFn = { 
	% use our saccade target stimulus for next fix X and Y, see
	% stims.fixationChoice above
	@()updateFixationTarget(me, tS.useTask, tS.targetFixInit, tS.targetFixTime, tS.targetRadius, tS.strict);
	% use our antisaccade target to define the exclusion zone, see
	% stims.exclusionChoice above
	@()updateExclusionZones(me, tS.useTask, tS.exclusionRadius);
	@()trackerMessage(eT,'END_FIX');
	@()hide(stims, 3);
};
if strcmpi(tS.type,'saccade')
	fsExitFn = [ fsExitFn; { @()edit(stims,1,'alphaOut',tS.targetAlpha2) } ];
else
	fsExitFn = [ fsExitFn; { @()edit(stims,1,'alphaOut',tS.targetAlpha2); @()edit(stims,2,'alphaOut',tS.antitargetAlpha2) } ];
end

%====================================================TARGET STIMULUS ALONE
% what to run when we enter the stim presentation state
stimEntryFn = { 
	@()doStrobe(me,true);
};

% what to run when we are showing stimuli
stimWithinFn = { 
	@()draw(stims);
	@()animate(stims); % animate stimuli for subsequent draw
	@()trackerDrawEyePosition(eT);
};

% test we are finding the new target (stimulus 1, the saccade target)
targetFixFn = {
	@()testSearchHoldFixation(eT,'correct','incorrect'); % tests finding and maintaining fixation
};

%as we exit stim presentation state
stimExitFn = { 
	@()setStrobeValue(me,255); 
	@()doStrobe(me,true);
};

%====================================================DECISION

%if the subject is correct (small reward)
correctEntryFn = {
	@()trackerTrialEnd(eT, tS.CORRECT); % send the end trial messages and other cleanup
	@()needEyeSample(me,false); % no need to collect eye data until we start the next trial
	@()hide(stims); % hide all stims
};

%correct stimulus
correctWithinFn = { 
	
};

%when we exit the correct state
correctExitFn = {
	@()giveReward(rM); % send a reward
	@()beep(aM, tS.correctSound); % correct beep
	@()logRun(me,'CORRECT'); % print current trial info
	@()trackerDrawStatus(eT, 'CORRECT! :-)', stims.stimulusPositions, 0, false);
	@()updatePlot(bR, me); %update our behavioural plot, must come before updateTask() / updateVariables()
	@()updateTask(me,tS.CORRECT); %make sure our taskSequence is moved to the next trial
	@()updateVariables(me); %randomise our stimuli, and set strobe value too
	@()update(stims); %update the stimuli ready for display
	@()plot(bR, 1); % actually do our behaviour record drawing
};

%========================================================INCORRECT
%--------------------incorrect entry
incEntryFn = {
	@()trackerTrialEnd(eT, tS.INCORRECT); % send the end trial messages and other cleanup
	@()needEyeSample(me,false);
	@()hide(stims);
};

%break entry
breakEntryFn = {
	@()trackerTrialEnd(eT, tS.BREAKFIX); % send the end trial messages and other cleanup
	@()needEyeSample(me,false);
	@()hide(stims);
};
exclEntryFn = breakEntryFn;

%our incorrect stimulus
incWithinFn = {
	
};

%--------------------generic exit
exitFn = {
	% tS.includeErrors will prepend some code here...
	@()needFlipTracker(me, 0); %for operator screen stop flip
	@()updateVariables(me); % randomise our stimuli, set strobe value too
	@()update(stims); % update our stimuli ready for display
	@()resetAll(eT); % resets the fixation state timers
	@()plot(bR, 1); % actually do our drawing
};

%--------------------change functions based on tS settings
% we use tS options to change the function lists run by the state machine.
% We can prepend or append new functions to the cell arrays.
%
% logRun = add current info to behaviural record
% updatePlot = updates the behavioural record
% updateTask = updates task object
% resetRun = randomise current trial within the block (makes it harder for
%            subject to guess based on previous failed trial.
% checkTaskEnded = see if taskSequence has finished
if tS.includeErrors % we want to update our task even if there were errors
	incExitFn = [ {
		@()beep(aM, tS.errorSound);
		@()logRun(me,'INCORRECT');
		@()trackerDrawStatus(eT,'INCORRECT! :-(', stims.stimulusPositions, 0, false);
		@()updatePlot(bR, me); 
		@()updateTask(me,tS.INCORRECT)}; 
		exitFn ]; 
	breakExitFn = [ {
		@()beep(aM, tS.errorSound);
		@()logRun(me,'BREAK_FIX'); 
		@()trackerDrawStatus(eT,'BREAK_FIX! :-(', stims.stimulusPositions, 0, false);
		@()updatePlot(bR, me); 
		@()updateTask(me,tS.BREAKFIX)}; 
		exitFn ]; 
	exclExitFn= [ {
		@()beep(aM, tS.errorSound);
		@()logRun(me,'EXCLUSION'); 
		@()trackerDrawStatus(eT,'EXCLUSION! :-(', stims.stimulusPositions, 0, false);
		@()updatePlot(bR, me); 
		@()updateTask(me,tS.BREAKFIX)}; 
		exitFn ];
else
	incExitFn = [ {
		@()beep(aM, tS.errorSound);
		@()logRun(me,'INCORRECT'); 
		@()trackerDrawStatus(eT,'INCORRECT! :-(', stims.stimulusPositions, 0, false);
		@()updatePlot(bR, me); 
		@()resetRun(task)}; 
		exitFn ]; 
	breakExitFn = [ {
		@()beep(aM, tS.errorSound);
		@()logRun(me,'BREAK_FIX'); 
		@()trackerDrawStatus(eT,'BREAK_FIX! :-(', stims.stimulusPositions, 0, false);
		@()updatePlot(bR, me); 
		@()resetRun(task)}; 
		exitFn ];
	exclExitFn= [ {
		@()beep(aM, tS.errorSound);
		@()logRun(me,'EXCLUSION'); 
		@()trackerDrawStatus(eT,'EXCLUSION! :-(', stims.stimulusPositions, 0, false);
		@()updatePlot(bR, me); 
		@()resetRun(task)}; 
		exitFn ];
end

%========================================================
%========================================================EYETRACKER
%========================================================
%--------------------calibration function
calibrateFn = {
	@()drawBackground(s); %blank the display
	@()stopRecording(eT); % stop recording in eyelink [tobii ignores this]
	@()setOffline(eT); % set eyelink offline [tobii ignores this]
	@()trackerSetup(eT);  %enter tracker calibrate/validate setup mode
};

%--------------------drift correction function
driftFn = {
	@()drawBackground(s); %blank the display
	@()stopRecording(eT); % stop recording in eyelink [tobii ignores this]
	@()setOffline(eT); % set eyelink offline [tobii ignores this]
	@()driftCorrection(eT) % enter drift correct (only eyelink)
};
offsetFn = {
	@()drawBackground(s); %blank the display
	@()stopRecording(eT); % stop recording in eyelink [tobii ignores this]
	@()setOffline(eT); % set eyelink offline [tobii ignores this]
	@()driftOffset(eT) % enter drift offset (works on tobii & eyelink)
};

%========================================================
%========================================================GENERAL
%========================================================
%--------------------DEBUGGER override
overrideFn = { @()keyOverride(me) }; %a special mode which enters a matlab debug state so we can manually edit object values

%--------------------screenflash
flashFn = { @()flashScreen(s, 0.2) }; % fullscreen flash mode for visual background activity detection

%--------------------show 1deg size grid
gridFn = { @()drawGrid(s) };

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%------------------------------------------------------------------------%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%==========================================================================
%==========================================================================
%==========================================================================
%--------------------------State Machine Table-----------------------------
% specify our cell array that is read by the stateMachine
stateInfoTmp = {
'name'		'next'		'time'		'entryFcn'		'withinFcn'		'transitionFcn'	'exitFcn';
%=============================================================================================
'pause'		'prefix'	inf			pauseEntryFn	{}				{}				pauseExitFn;
%---------------------------------------------------------------------------------------------
'prefix'	'fixate'	1			pfEntryFn		pfWithinFn		{}				pfExitFn;
'fixate'	'breakfix'	10			fixEntryFn		fixWithinFn		initFixFn		fixExitFn;
'fixstim'	'breakfix'	10			fsEntryFn		fsWithinFn		fsFixFn			fsExitFn
'stimulus'	'incorrect'	10			stimEntryFn		stimWithinFn	targetFixFn		stimExitFn;
'correct'	'prefix'	0.1			correctEntryFn	correctWithinFn	{}				correctExitFn;
'breakfix'	'timeout'	0.1			breakEntryFn	incWithinFn		{}				incExitFn;
'incorrect'	'timeout'	0.1			incEntryFn		incWithinFn		{}				breakExitFn;
'exclusion'	'timeout'	0.1			exclEntryFn		incWithinFn		{}				exclExitFn;
'timeout'	'prefix'	tS.timeOut	{}				{}				{}				{};
%---------------------------------------------------------------------------------------------
'calibrate'	'pause'		0.5			calibrateFn		{}				{}				{};
'drift'		'pause'		0.5			driftFn			{}				{}				{};
'offset'	'pause'		0.5			offsetFn		{}				{}				{};
%---------------------------------------------------------------------------------------------
'override'	'pause'		0.5			overrideFn		{}				{}				{};
'flash'		'pause'		0.5			flashFn			{}				{}				{};
'showgrid'	'pause'		10			{}				gridFn			{}				{};
};
%
%-----------------------------State Machine Table------------------------------
%==============================================================================

disp('================>> Building state info file <<================')
disp(stateInfoTmp)
disp('=================>> Loaded state info file <<=================')
clearvars -regexp '.+Fn'
% PRO-SACCADE and ANTI-SACCADE Task
%
% This task supports both pro and anti saccades and uses 3 stimuli: 
% (1) pro-saccade target
% (2) anti-saccade target and 
% (3) fixation cross. 
% 
% The task sequence is set up to randomise the X & Y position (xpPosition independent variable of (1) ±10° on
% each trial, and (2) has a modifier set as the inverse (if (1) is -10° on
% a trial then (2) becomes +10°) - the anti-saccade target is always
% opposite the saccade target. For the pro-saccade task, show (1) and hide
% (2), fixation window set on (1) and [optionally] exclusion zone set around (2). In
% the anti-saccade task we show (2) and can vary the opacity of (1) during
% training to encourage the subject to saccade away from (2) towards (1);
% the fixation and optional exclusion windows keep the same logic as for the
% pro-saccade condition.
%
% The exclusion zone is used to punish subject who saccade in the wrong
% direction. This is important suring training, but during data collection
% you may want to measure corrective saccades, in which case you would
% disable the exclusion zone.
%
% NOTE: this pro/anti-saccade task does not impose a response delay. Delays
% are common to help analysis of recorded neurons, however, teaching
% subjects to delay their [pro|anti]saccade interferes with the cognitive
% process we wish to measure!!!
%
% BUT this task does support delay of display of the [pro|anti]saccade
% target as this has a clear impact on error rates and reaction times, with
% 200ms showing max effect; you can control this by adding a delayTime
% parameter of 0.2s to the pro-saccade and anti-saccade target stimuli. See
% Fischer B & Weber H (1997) “Effects of stimulus conditions on the
% performance of antisaccades in man.” Experimental Brain Research 116(2),
% 191-200 [doi.org/10.1007/pl00005749](https://doi.org/10.1007/pl00005749)


%==================================================================
%--------------------TASK SPECIFIC CONFIG--------------------------
% name
tS.name					= 'prosaccade-antisaccade'; %==name of this protocol

% we use manuN to show a selection menu to get values from the user.
title = {'[Pro|Anti]Saccade','Choose which type of task to perform.|You can also set the alpha of the |pro and anti saccade targets|which helps the subject during training.'};
tS.options = {'r|¤Pro-Saccade|Anti-Saccade','Choose Protocol Type:';...
	'r|Use Exclusion Zone|¤Disable Exclusion Zone','Exclusion zone: if saccade is wrong direction, triggers incorrect';...
	't|0', 'Stimulus Visual Onset Gap (secs):'; ...
	't|0.1',' Prosaccade Target Initial Alpha [0-1]:';...
	't|0.75',' Prosaccade Target Main Alpha [0-1]:';...
	't|0.1','Antisaccade Target Initial Alpha [0-1]:';...
	't|0.75','Antisaccade Target Main Alpha [0-1]:'};
if exist('isRunning','var') && isRunning == true % we are actually running a task, ask user
	tS.ua = menuN(title,tS.options);
else % just loading the state file, pass defaults
	tS.ua{1}=1;tS.ua{2}=1;tS.ua{3}=0;tS.ua{4}=0.1;yS.us{5}=0.75;tS.ua{6}=0.1;tS.ua{7}=0.1;
end
% task type
if tS.ua{1} == 1
	tS.type				= 'saccade';
else
	tS.type				= 'anti-saccade';
end
% use an exclude zone around the opposite target?
if tS.ua{2} == 1
	tS.exclude			= true;
else
	tS.exclude			= false;
end
% add a gap between when fixation disappears and target appears, see
% Fischer & Weber 1997
if tS.ua{3} > 0
	stims{1}.delayTime = tS.ua{3};
	stims{2}.delayTime = tS.ua{3};
end

% update the trial number for incorrect saccades: if true then we call
% updateTask for both correct and incorrect trials, otherwise we only call
% updateTask() for correct responses. 
tS.includeErrors		= false; 

% note there are TWO alpha values, this is used by
% tS.fixAndStimTime below to control initial visualisation 
% of the targets during fixation mostly used during training
% to guide the subject.
if strcmp(tS.type,'saccade')
	% a flag to conditionally set visualisation on the eye tracker interface
	stims{1}.showOnTracker	= true;
	stims{2}.showOnTracker	= false;
	tS.targetAlpha1			= tS.ua{4};
	tS.targetAlpha2			= tS.ua{5};
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
	tS.targetAlpha1			= tS.ua{4};
	tS.targetAlpha2			= tS.ua{5};
	tS.antitargetAlpha1		= tS.ua{6};
	tS.antitargetAlpha2		= tS.ua{7};
end
disp(['\n===>>> Task ' tS.name ' Type:' tS.type ' <<<===\n'])

%==================================================================
%----------------------General Settings----------------------------
tS.useTask					= true;		%==use taskSequence (randomises stimulus variables)
tS.saveData					= true;		%==save behavioural and eye movement data?
tS.showBehaviourPlot		= true;		%==open the behaviourPlot figure? Can cause more memory use…
tS.keyExclusionPattern		= ["fixstim","stimulus"];		%==which states to skip keyboard checking
tS.recordEyePosition		= false;	%==record local copy of eye position, **in addition** to the eyetracker?
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
%uF.verbose					= true;		%==print out user function logg for debugging

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
tS.firstFixInit				= 3;
% time to maintain initial fixation within window, can be single value or a
% range to randomise between
tS.firstFixTime				= [0.8 1.2];
% circular fixation window radius in degrees
tS.firstFixRadius			= 1.25;
% do we forbid eye to enter-exit-reenter fixation window?
tS.strict					= true;
% time to show BOTH fixation cross and [anti]saccade target
% this allows the first alpha values to be useful
tS.fixAndStimTime			= 0;
% in this task the subject must saccade to the pro-saccade target location.
% These settings define the rules to "accept" the target fixation as
% correct
tS.targetFixInit			= 0.5; % time to find the target
tS.targetFixTime			= 0.5; % to to maintain fixation on target 
tS.targetRadius				= 8; %radius width x height to fix within.
% this task will establish an exclusion zone around the non-target
% target for the pro and anti-saccade task. We can change the size of the
% exclusion zone, here set to 5° around the X and Y position of the
% anti-saccade target.
if tS.exclude
	tS.exclusionRadius		= 5; %radius width x height to fix within.
else
	tS.exclusionRadius		= []; %empty thus exclusion zone removed
end
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
% Each cell {array} holds a set of function handles that are executed by
% the state machine to control the experiment. The state machine can run
% sets at entry ['entryFcn'], during ['withinFcn'], to trigger a transition
% jump to another state ['transitionFcn'], and at exit ['exitFcn'. Remember
% these {sets} access the objects that are available within the
% runExperiment context. You can add custom functions and properties using
% userFunctions.m file. You can also add global variables/objects then use
% these. Any values entered here are set at load; if you want up-to-date
% values at trial time then you need to use methods/function wrappers to
% retrieve/set them.
%=========================================================================

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%==================================================================PAUSE
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%--------------------pause entry
pauseEntryFn = {
	@()hide(stims);
	@()drawBackground(s); %blank the subject display
	@()drawTextNow(s,'PAUSED, press [p] to resume...');
	@()disp('PAUSED, press [p] to resume...');
	@()trackerDrawStatus(eT,'PAUSED, press [p] to resume', [], 0, false);
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
	@()startRecording(eT, true); %start recording eye position data again
};

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%==============================================================PRE-FIXATION
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%====================================================PRE-FIXATION
pfEntryFn = {
	@()needFlip(me, true, 1); % start PTB screen flips, and tracker screen flip
	@()needEyeSample(me, true); % make sure we start measuring eye position
	@()getStimulusPositions(stims,true); %make a struct the eT can use for drawing stim positions
	@()hide(stims);
	@()resetAll(eT); % reset all fixation markers to initial state
	@()updateFixationValues(eT,tS.fixX,tS.fixY,tS.firstFixInit,tS.firstFixTime,tS.firstFixRadius,tS.strict); %reset fixation window
	@()trackerTrialStart(eT, getTaskIndex(me));
	@()trackerMessage(eT,['UUID ' UUID(sM)]); %add in the uuid of the current state for good measure
	% you can add any other messages, such as stimulus values as needed,
	% e.g. @()trackerMessage(eT,['MSG:ANGLE' num2str(stims{1}.angleOut)]) etc.
};

pfWithinFn = {
	@()trackerDrawFixation(eT);
	@()trackerDrawEyePosition(eT);
};

pfExitFn = {
	@()logRun(me,'INITFIX');
	@()trackerDrawStatus(eT,'Start trial...', stims.stimulusPositions, 0, 1);
};

%====================================================FIXATION
%--------------------fixate entry
fixEntryFn = { 
	% show stimulus 3 = fixation cross
	@()show(stims, 3);
	@()trackerMessage(eT,'MSG:Start Fix');
};

%--------------------fix within
fixWithinFn = {
	@()draw(stims); %draw stimulus
	@()animate(stims); % animate stimuli for subsequent draw
	@()trackerDrawEyePosition(eT); % for tobii
};

%--------------------test we are fixated for a certain length of time
initFixFn = {
	% this command performs the logic to search and then maintain fixation
	% inside the fixation window. The eyetracker parameters are defined above.
	% If the subject does initiate and then maintain fixation, then 'fixstim'
	% is returned and the state machine will jump to that state,
	% otherwise 'incorrect' is returned and the state machine will jump there. 
	% If neither condition matches, then the state table below
	% defines that after X seconds we will switch to the incorrect state automatically.
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
	% send an eyeTracker sync message (reset relative time to 0 after next flip)
	@()doSyncTime(me);
	% send stimulus value strobe (value alreadyset by updateVariables(me) function)
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
	@()setStrobeValue(me, me.strobe.stimOFFValue);
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
	@()trackerDrawStatus(eT, 'CORRECT! :-)', stims.stimulusPositions, 1, false);
	@()logRun(me,'CORRECT'); % print current trial info
	@()updatePlot(bR, me); %update our behavioural plot, must come before updateTask() / updateVariables()
	@()updateTask(me,tS.CORRECT); %make sure our taskSequence is moved to the next trial
	@()updateVariables(me); %randomise our stimuli, and set strobe value too
	@()update(stims); %update the stimuli ready for display
	@()resetAll(eT); %reset the exclusion zones
	@()plot(bR, 1); % actually do our behaviour record drawing
	@()checkTaskEnded(me); %check if task is finished
	@()needFlip(me, false, 0);
};

%========================================================INCORRECT
%--------------------incorrect entry
incEntryFn = {
	@()trackerTrialEnd(eT, tS.INCORRECT); % send the end trial messages and other cleanup
	@()needEyeSample(me,false);
	@()hide(stims);
};

%our incorrect stimulus
incWithinFn = {

};

exitFn = {
	% tS.includeErrors will prepend some code here...
	@()beep(aM, tS.errorSound);
	@()updateVariables(me); % randomise our stimuli, set strobe value too
	@()update(stims); % update our stimuli ready for display
	@()resetAll(eT); % resets the fixation state timers
	@()plot(bR, 1); % actually do our drawing
	@()checkTaskEnded(me); %check if task is finished
	@()needFlip(me, false, 0);
};

if tS.includeErrors % do we allow incorrect trials to move to the next trial
	incExitFn = [ {
		@()trackerDrawStatus(eT,'INCORRECT! :-(', stims.stimulusPositions, 1, false);
		@()logRun(me,'INCORRECT');
		@()updatePlot(bR, me);
		@()updateTask(me,tS.BREAKFIX)}; 
		exitFn ]; % make sure our taskSequence is moved to the next trial
else
	incExitFn = [ {
		@()trackerDrawStatus(eT,'INCORRECT! :-(', stims.stimulusPositions, 1, false);
		@()logRun(me,'INCORRECT');
		@()updatePlot(bR, me);
		@()resetRun(task)}; 
		exitFn ]; % we randomise the run within this block to make it harder to guess next trial
end

%========================================================BREAK
%break entry
breakEntryFn = {
	@()trackerTrialEnd(eT, tS.BREAKFIX); % send the end trial messages and other cleanup
	@()needEyeSample(me,false);
	@()hide(stims);
};

exclEntryFn = breakEntryFn;

if tS.includeErrors
	breakExitFn = [ {
		@()trackerDrawStatus(eT,'BREAKFIX! :-(', stims.stimulusPositions, 1, false);
		@()logRun(me,'BREAKFIX');
		@()updatePlot(bR, me);
		@()updateTask(me,tS.BREAKFIX)};
		exitFn ]; % make sure our taskSequence is moved to the next trial
else
	breakExitFn = [ {
		@()trackerDrawStatus(eT,'BREAKFIX! :-(', stims.stimulusPositions, 1, false);
		@()logRun(me,'BREAKFIX');
		@()updatePlot(bR, me);
		@()resetRun(task)};
		exitFn ]; % we randomise the run within this block to make it harder to guess next trial
end

exclExitFcn = [{@()fprintf('EXCLUSION!\n')}; breakExitFn];

toEntryFn = { @()fprintf('\nTIME OUT!\n'); };

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
'name'		'next'		'time'	'entryFcn'		'withinFcn'		'transitionFcn'	'exitFcn';
%---------------------------------------------------------------------------------------------
'pause'		'prefix'	inf		pauseEntryFn	{}				{}				pauseExitFn;
%---------------------------------------------------------------------------------------------
'prefix'	'fixate'	0.5		pfEntryFn		pfWithinFn		{}				pfExitFn;
'fixate'	'breakfix'	10		fixEntryFn		fixWithinFn		initFixFn		fixExitFn;
'fixstim'	'breakfix'	10		fsEntryFn		fsWithinFn		fsFixFn			fsExitFn
'stimulus'	'incorrect'	10		stimEntryFn		stimWithinFn	targetFixFn		stimExitFn;
'correct'	'prefix'	0.1		correctEntryFn	correctWithinFn	{}				correctExitFn;
'breakfix'	'timeout'	0.1		breakEntryFn	incWithinFn		{}				incExitFn;
'incorrect'	'timeout'	0.1		incEntryFn		incWithinFn		{}				breakExitFn;
'exclusion'	'timeout'	0.1		exclEntryFn		incWithinFn		{}				breakExitFn;
'timeout'	'prefix'	tS.tOut	toEntryFn				{}				{}				{};
%---------------------------------------------------------------------------------------------
'calibrate'	'pause'		0.5		calibrateFn		{}				{}				{};
'drift'		'pause'		0.5		driftFn			{}				{}					{};
'offset'	'pause'		0.5		offsetFn		{}				{}					{};
%---------------------------------------------------------------------------------------------
'override'	'pause'		0.5		overrideFn		{}				{}				{};
'flash'		'pause'		0.5		flashFn			{}				{}				{};
'showgrid'	'pause'		10		{}				gridFn			{}				{};
};
%
%-----------------------------State Machine Table------------------------------
%==============================================================================

disp('================>> Building state info file <<================')
disp(stateInfoTmp)
disp('=================>> Loaded state info file <<=================')
clearvars -regexp '.+Fn'

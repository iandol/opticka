% PRO-SACCADE and ANTI-SACCADE Task (TOUCH SCREEN VERSION)
%
% This task supports both pro and anti saccades and uses 3 stimuli:
% (1) pro-saccade target
% (2) anti-saccade target and
% (3) fixation cross.
%
% TOUCH VERSION: this protocol replaces the eyetracker (eT) with the
% touchManager (tM). Touch windows are used instead of gaze windows:
%   - tM.updateWindow sets the circular touch window position and size
%   - testHold(tM,...) is used as the transitionFcn equivalent of
%     testSearchHoldFixation / testHoldFixation
%   - doNegation=true on the target window acts as the exclusion zone:
%     touching far from the saccade target (e.g. near the anti-saccade
%     target) returns -100 and is treated as incorrect.
%
% The fixstim state (brief hold while both fixation cross and target are
% shown) is removed — fixation transitions directly to the stimulus state.
%
% The task sequence is set up to randomise the X & Y position of (1) ±10°
% on each trial, and (2) has a modifier set as the inverse (if (1) is -10°
% then (2) becomes +10°). For the pro-saccade task, show (1) and hide (2),
% touch window set on (1) with optional negation zone around (2). In the
% anti-saccade task we show (2) and the touch window targets the location
% of (1); negation fires if the subject touches near (2) instead.
%
% NOTE: this protocol does NOT impose a response delay. See Fischer B &
% Weber H (1997) Exp Brain Res 116(2):191-200 for background on gap effects.


%==================================================================
%--------------------TASK SPECIFIC CONFIG--------------------------
% name
tS.name					= 'prosaccade-antisaccade-touch'; %==name of this protocol

% we use menuN to show a selection menu to get values from the user.
title = {'[Pro|Anti]Saccade (Touch)','Choose which type of task to perform.|You can also set the alpha of the |pro and anti saccade targets|which helps the subject during training.'};
tS.options = {'r|¤Pro-Saccade|Anti-Saccade','Choose Protocol Type:';...
	'r|Use Negation Zone|¤Disable Negation Zone','Negation zone: if touch is wrong direction, triggers incorrect';...
	't|0', 'Stimulus Visual Onset Gap (secs):'; ...
	't|0.1',' Prosaccade Target Initial Alpha [0-1]:';...
	't|0.75',' Prosaccade Target Main Alpha [0-1]:';...
	't|0.1','Antisaccade Target Initial Alpha [0-1]:';...
	't|0.75','Antisaccade Target Main Alpha [0-1]:'};
if exist('isRunning','var') && isRunning == true % we are actually running a task, ask user
	tS.ua = menuN(title,tS.options);
else % just loading the state file, pass defaults
	tS.ua{1}=1;tS.ua{2}=1;tS.ua{3}=0;tS.ua{4}=0.1;tS.ua{5}=0.75;tS.ua{6}=0.1;tS.ua{7}=0.75;
end

% task type
if tS.ua{1} == 1
	tS.type				= 'saccade';
else
	tS.type				= 'anti-saccade';
end

% use a negation zone around the opposite target?
if tS.ua{2} == 1
	tS.useNegation		= true;
else
	tS.useNegation		= false;
end

% add a gap between when fixation disappears and target appears, see
% Fischer & Weber 1997
if tS.ua{3} > 0
	stims{1}.delayTime = tS.ua{3};
	stims{2}.delayTime = tS.ua{3};
end

% update the trial number for incorrect responses: if true then we call
% updateTask for both correct and incorrect trials, otherwise we only call
% updateTask() for correct responses.
tS.includeErrors		= false;

% note there are TWO alpha values used to control initial visualisation
% of the targets during fixation, mostly used during training to guide
% the subject.
if strcmp(tS.type,'saccade')
	% a flag to conditionally set visualisation
	stims{1}.showOnTracker	= true;
	stims{2}.showOnTracker	= false;
	tS.targetAlpha1			= tS.ua{4};
	tS.targetAlpha2			= tS.ua{5};
	tS.antitargetAlpha1		= 0;
	tS.antitargetAlpha2		= 0;
else
	% for use during training: keep the pro-saccade target visible so the
	% subject understands where they must touch. Reduce alpha over
	% training until ONLY the anti-saccade target is visible.
	stims{1}.showOnTracker	= false;
	stims{2}.showOnTracker	= true;
	tS.targetAlpha1			= tS.ua{4};
	tS.targetAlpha2			= tS.ua{5};
	tS.antitargetAlpha1		= tS.ua{6};
	tS.antitargetAlpha2		= tS.ua{7};
end
disp(['\n===>>> Task ' tS.name ' Type:' tS.type ' <<<===\n'])

%==================================================================
%----------------------General Settings----------------------------
tS.useTask					= true;		%==use taskSequence (randomises stimulus variables)
tS.saveData					= true;		%==save behavioural data?
tS.showBehaviourPlot		= true;		%==open the behaviourPlot figure?
tS.keyExclusionPattern		= ["fixate","stimulus"];	%==which states to skip keyboard checking
tS.nStims					= stims.n;	%==number of stimuli, taken from metaStimulus object
tS.tOut						= 5;		%==if wrong response, how long to time out before next trial
tS.CORRECT					= 1;		%==the code to send for correct trials
tS.BREAKFIX					= -1;		%==the code to send for break fix trials
tS.INCORRECT				= -5;		%==the code to send for incorrect trials
tS.correctSound				= [2000, 0.1, 0.1]; %==freq,length,volume
tS.errorSound				= [300, 1, 1];		%==freq,length,volume

%==================================================================
%----------------Debug logging to command window------------------
% uncomment each line to get specific verbose logging from each of these
% components; you can also set verbose in the opticka GUI to enable all of
% these...
%sM.verbose					= true;		%==print out stateMachine info for debugging
%stims.verbose				= true;		%==print out metaStimulus info for debugging
%io.verbose					= true;		%==print out io commands for debugging
%tM.verbose					= true;		%==print out touchManager commands for debugging
%rM.verbose					= true;		%==print out reward commands for debugging
%task.verbose				= true;		%==print out task info for debugging
%uF.verbose					= true;		%==print out user function log for debugging

%==================================================================
%-----------------INITIAL Touch Window Settings--------------------
% These settings define the initial fixation touch window and target
% touch window. They may be modified during the task (e.g. moving the
% touch window to the saccade target after fixation is acquired).
%
% IMPORTANT: the global state time must be larger than the touch timers
% specified here. Each state has a global timer, so if the state timer is
% 5s but your touch timer is 6s, the state will end before the touch was
% completed.

% initial fixation X position in degrees (0° is screen centre)
tS.fixX						= 0;
% initial fixation Y position in degrees
tS.fixY						= 0;
% time to search and touch the fixation window
tS.firstFixInit				= 3;
% time to maintain initial touch within window, can be single value or a
% range to randomise between
tS.firstFixTime				= [0.8 1.2];
% circular fixation window radius in degrees
tS.firstFixRadius			= 1.25;
% do we enforce strict hold within the touch window?
tS.strict					= true;
% time to find the saccade target touch window after fixation offset
tS.targetFixInit			= 0.5;
% time to maintain touch on the saccade target
tS.targetFixTime			= 0.5;
% radius of the saccade target touch window in degrees
tS.targetRadius				= 8;
% negation buffer: degrees of margin around the target window outside
% which a deliberate touch returns -100 (incorrect). Only active when
% tS.useNegation is true.
tS.negationBuffer			= 4;

% Initialise the touchManager with the initial fixation window.
% Arguments: X, Y, radius, doNegation, negationBuffer, strict, init, hold, release
updateWindow(tM, tS.fixX, tS.fixY, tS.firstFixRadius, false, tS.negationBuffer, ...
	tS.strict, tS.firstFixInit, tS.firstFixTime, NaN);

%==================================================================
%-----------------BEHAVIOURAL PLOT CONFIGURATION------------------
%--WHICH states assigned correct / incorrect for the online plot?--
bR.correctStateName			= "correct";
bR.breakStateName			= ["breakfix","incorrect"];

%======================================================================
% N x 2 cell array of regexpi strings, list to skip the current -> next
% state's exit functions; for example skipExitStates =
% {'fixate','incorrect|breakfix'}; means that if the currentstate is
% 'fixate' and the next state is either incorrect OR breakfix, then skip
% the FIXATE exit state.
sM.skipExitStates			= {'fixate','incorrect|breakfix'};

%==================================================================
% which stimulus in the list is used for a fixation target? For this
% protocol it means the subject must touch this stimulus (the saccade
% target is #1 in the list) to get the reward.
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
% jump to another state ['transitionFcn'], and at exit ['exitFcn']. Remember
% these {sets} access the objects that are available within the
% runExperiment context. You can add custom functions and properties using
% userFunctions.m file.
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
	@()flush(tM);  % clear any pending touch events
	@()reset(tM);  % reset touch hold state machine
	@()needFlip(me, false, 0); % no need to flip the PTB screen
};

%--------------------pause exit
pauseExitFn = {
	@()flush(tM);  % clear any touch events that accumulated during pause
};

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%==============================================================PRE-FIXATION
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

pfEntryFn = {
	@()needFlip(me, true, 1); % start PTB screen flips
	@()getStimulusPositions(stims,true); % build struct for drawing stim positions
	@()hide(stims);
	% reset touch state and flush queued events for new trial
	@()flush(tM);
	@()reset(tM);
	% set touch window back to fixation cross position for this trial
	@()updateWindow(tM, tS.fixX, tS.fixY, tS.firstFixRadius, false, tS.negationBuffer, ...
		tS.strict, tS.firstFixInit, tS.firstFixTime, NaN);
	@()trackerTrialStart(eT, getTaskIndex(me)); % log trial start (no-op if no eyetracker)
	@()trackerMessage(eT,['UUID ' UUID(sM)]);
};

pfWithinFn = {
	@()drawBackground(s);
};

pfExitFn = {
	@()logRun(me,'INITFIX');
};

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%==================================================================FIXATION
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%--------------------fixate entry
fixEntryFn = {
	% show stimulus 3 = fixation cross
	@()show(stims, 3);
};

%--------------------fix within
fixWithinFn = {
	@()draw(stims); %draw stimulus
	@()animate(stims); % animate stimuli for subsequent draw
};

%--------------------test we are touching and holding the fixation window
initFixFn = {
	% testHold polls the touchManager hold state machine each frame.
	% Returns 'stimulus' when hold time is met, 'breakfix' when failed or
	% timed out. If neither condition is met the state timer governs exit.
	@()testHold(tM,'stimulus','breakfix')
};

%--------------------exit fixation — move touch window to the saccade target
% me.lastXPosition / me.lastYPosition are set by getStimulusPositions() in
% pfEntryFn and reflect the live position of stims.fixationChoice (stims{1}).
if strcmpi(tS.type,'saccade')
	fixExitFn = {
		@()show(stims, [1 3]);
		@()edit(stims,1,'alphaOut',tS.targetAlpha1);
		% move touch window to saccade target; enable negation if configured
		@()updateWindow(tM, me.lastXPosition, me.lastYPosition, tS.targetRadius, ...
			tS.useNegation, tS.negationBuffer, tS.strict, tS.targetFixInit, tS.targetFixTime, NaN);
		@()flush(tM);      % flush events — new touch window context
		@()reset(tM, true); % soft reset: keep lastPressed state, reset hold timers
	};
else
	fixExitFn = {
		@()show(stims, [1 2 3]);
		@()edit(stims,1,'alphaOut',tS.targetAlpha1);
		@()edit(stims,2,'alphaOut',tS.antitargetAlpha1);
		% move touch window to saccade target (stims{1}); enable negation if configured
		@()updateWindow(tM, me.lastXPosition, me.lastYPosition, tS.targetRadius, ...
			tS.useNegation, tS.negationBuffer, tS.strict, tS.targetFixInit, tS.targetFixTime, NaN);
		@()flush(tM);      % flush events — new touch window context
		@()reset(tM, true); % soft reset: keep lastPressed state, reset hold timers
	};
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%==================================================================STIMULUS
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% what to run when we enter the stim presentation state
stimEntryFn = {
	% send a sync message (resets relative time to 0 after next flip)
	@()doSyncTime(me);
	% send stimulus value strobe (value already set by updateVariables(me))
	@()doStrobe(me,true);
	% hide fixation cross
	@()hide(stims, 3);
};

if strcmpi(tS.type,'saccade')
	stimEntryFn = [stimEntryFn; {
		@()show(stims, 1);
		@()edit(stims,1,'alphaOut',tS.targetAlpha2);
	}];
else
	stimEntryFn = [stimEntryFn; {
		@()show(stims, [1 2]);
		@()edit(stims,1,'alphaOut',tS.targetAlpha2);
		@()edit(stims,2,'alphaOut',tS.antitargetAlpha2);
	}];
end

% what to run while showing stimuli
stimWithinFn = {
	@()draw(stims);
	@()animate(stims); % animate stimuli for subsequent draw
};

% test the subject is touching and holding the saccade target window.
% doNegation=true (set in fixExitFn) means touching far from the target
% returns -100 which testHold maps to noString -> 'incorrect'.
targetFixFn = {
	@()testHold(tM,'correct','incorrect');
};

% as we exit the stim presentation state
stimExitFn = {
	@()setStrobeValue(me, me.strobe.stimOFFValue);
	@()doStrobe(me,true);
};

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%==================================================================DECISION
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%--------------------CORRECT
correctEntryFn = {
	@()trackerTrialEnd(eT, tS.CORRECT); % send end trial messages (no-op if no eyetracker)
	@()hide(stims); % hide all stims
	@()reset(tM);   % reset touch state for next trial
};

correctWithinFn = {

};

% when we exit the correct state
correctExitFn = {
	@()giveReward(rM); % send a reward
	@()beep(aM, tS.correctSound); % correct beep
	@()logRun(me,'CORRECT'); % print current trial info
	@()updatePlot(bR, me); %update behavioural plot; must come before updateTask()/updateVariables()
	@()updateTask(me,tS.CORRECT); %move taskSequence to the next trial
	@()updateVariables(me); %randomise our stimuli, and set strobe value too
	@()update(stims); %update the stimuli ready for display
	@()getStimulusPositions(stims,true); %update cached stimulus positions
	@()plot(bR, 1); % draw behaviour record
	@()checkTaskEnded(me); %check if task is finished
	@()needFlip(me, false, 0);
};

%--------------------INCORRECT
incEntryFn = {
	@()trackerTrialEnd(eT, tS.INCORRECT); % send end trial messages (no-op if no eyetracker)
	@()hide(stims);
	@()reset(tM);
};

incWithinFn = {

};

exitFn = {
	% tS.includeErrors will prepend some code here...
	@()beep(aM, tS.errorSound);
	@()updateVariables(me); % randomise our stimuli, set strobe value too
	@()update(stims); % update our stimuli ready for display
	@()getStimulusPositions(stims,true); %update cached stimulus positions
	@()plot(bR, 1); % actually do our drawing
	@()checkTaskEnded(me); %check if task is finished
	@()needFlip(me, false, 0);
};

if tS.includeErrors % do we allow incorrect trials to move to the next trial
	incExitFn = [ {
		@()logRun(me,'INCORRECT');
		@()updatePlot(bR, me);
		@()updateTask(me,tS.INCORRECT)};
		exitFn ];
else
	incExitFn = [ {
		@()logRun(me,'INCORRECT');
		@()updatePlot(bR, me);
		@()resetRun(task)};
		exitFn ]; % randomise the run within this block to make it harder to guess next trial
end

%--------------------BREAK FIX
breakEntryFn = {
	@()trackerTrialEnd(eT, tS.BREAKFIX); % send end trial messages (no-op if no eyetracker)
	@()hide(stims);
	@()reset(tM);
};

if tS.includeErrors
	breakExitFn = [ {
		@()logRun(me,'BREAKFIX');
		@()updatePlot(bR, me);
		@()updateTask(me,tS.BREAKFIX)};
		exitFn ];
else
	breakExitFn = [ {
		@()logRun(me,'BREAKFIX');
		@()updatePlot(bR, me);
		@()resetRun(task)};
		exitFn ];
end

%--------------------TIMEOUT
toEntryFn = { @()fprintf('\nTIME OUT!\n'); };

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%==================================================================GENERAL
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%--------------------DEBUGGER override
overrideFn = { @()keyOverride(me) }; %enter a matlab debug state to manually edit object values

%--------------------screenflash
flashFn = { @()flashScreen(s, 0.2) }; % fullscreen flash for visual background detection

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
'stimulus'	'incorrect'	10		stimEntryFn		stimWithinFn	targetFixFn		stimExitFn;
'correct'	'prefix'	0.1		correctEntryFn	correctWithinFn	{}				correctExitFn;
'incorrect'	'timeout'	0.1		incEntryFn		incWithinFn		{}				incExitFn;
'breakfix'	'timeout'	0.1		breakEntryFn	incWithinFn		{}				breakExitFn;
'timeout'	'prefix'	tS.tOut	toEntryFn		{}				{}				{};
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

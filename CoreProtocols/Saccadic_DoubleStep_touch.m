% DOUBLESTEP SACCADE task (TOUCH SCREEN VERSION)
% Based on Thakkar et al., 2015 Brain & Cognition
%
% This paradigm should be more sensitive to online inhibition than
% anti-saccade.
%
% In nostep trials (60%), after 500-1000ms of initial fixation, a saccade
% target (target one) is flashed for 100ms in one of 8 equidistant
% positions. In step trials (40%) after target one flashes, after a delay
% (target step delay, TSD) a second target (target two) flashes 90deg away
% and the subject must touch target two for a successful trial. Subjects
% are not punished for reorienting from target one to target two. TSD is
% modified using a 1U/1D staircase, and nostep/step trial assignment uses
% taskSequence.trialVar.
%
% TOUCH VERSION: this protocol replaces the eyetracker (eT) with the
% touchManager (tM). Touch windows are used instead of gaze windows:
%   - tM.updateWindow sets the circular touch window position and size
%   - testHold(tM,...) is used as the transitionFcn in all fixation and
%     stimulus states (replaces testSearchHoldFixation)
%   - needEyeSample, trackerDraw*, trackerMessage, calibrate/drift/offset
%     states are removed
%   - In step trials the target-two touch window has doNegation=true so
%     that touching near target one (wrong direction) counts as incorrect

%=========================================================================
%-------------------------------Task Settings-----------------------------
% name
tS.name						= 'Saccadic DoubleStep Touch'; %==name of this protocol
% we use a up/down staircase to control the TSD (delay in seconds)
assert(exist('PAL_AMUD_setupUD','file'),'MUST Install Palamedes Toolbox: https://www.palamedestoolbox.org')

% See Palamedes toolbox for the PAL_AM methods.
% 1up / 1down staircase starts at 225ms and steps at 34ms between 100 and
% 600ms
task.staircase = [];
task.staircase(1).type = 'UD';
task.staircase(1).sc = PAL_AMUD_setupUD('up',1,'down',1,'stepSizeUp',0.034,'stepSizeDown',0.034,...
				'stopRule',64,'startValue',0.225,'xMin',0.1,'xMax',0.6);
task.staircase(1).invert = true; % a correct increases value.
% we use taskSequence to randomise which state to switch to (independent
% trial-level factor). We call @()updateNextState(me,'trial') in the
% prefixation state; this sets one of these two trialVar.values as the next
% state. The nostepfix and stepfix states will call nostep or step
% stimulus states respectively.
% These are actually set by the opticka GUI, but this is the task code to
% set this:
%     task.trialVar.comment       = 'nostep or step trial based on 60:40 probability';
%     task.trialVar.values        = {'nostepfix','stepfix'};
%     task.trialVar.probability   = [0.6 0.4];
% tell timeLog which states are "stimulus" states
tL.stimStateNames			= ["nostep","step"];

% update the trial number for incorrect responses: if true then we call
% updateTask for both correct and incorrect trials, otherwise we only call
% updateTask() for correct responses.
tS.includeErrors			= false;

%==================================================================
%----------------------General Settings----------------------------
tS.useTask					= true;		%==use taskSequence (randomises stimulus variables)
tS.saveData					= true;		%==save behavioural data?
tS.showBehaviourPlot		= true;		%==open the behaviourPlot figure?
tS.keyExclusionPattern		= ["nostepfix","nostep","stepfix","step"]; %==which states to skip keyboard checking
tS.nStims					= stims.n;	%==number of stimuli, taken from metaStimulus object
tS.tOut						= 1;		%==timeout if breakfix/incorrect response
tS.CORRECT					= 1;		%==the code to send for correct trials
tS.BREAKFIX					= -1;		%==the code to send for break fix trials
tS.INCORRECT				= -5;		%==the code to send for incorrect trials
tS.correctSound				= [2000, 0.1, 0.1]; %==freq,length,volume
tS.errorSound				= [300,  1.0, 1.0]; %==freq,length,volume

%=========================================================================
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
% **IMPORTANT**: the global state time must be larger than the touch timers
% specified here. Each state has a timer, so if the state timer is 5s but
% your touch timer is 6s, the state will end before the touch was completed.

tS.fixX						= 0; % initial fixation X position in degrees (0° is screen centre)
tS.fixY						= 0; % initial fixation Y position in degrees (0° is screen centre)
tS.firstFixInit				= 3; % time to search and touch the fixation window
tS.firstFixTime				= [0.5 1.0]; % time to maintain initial touch within window
tS.firstFixRadius			= 2; % fixation touch window radius in degrees
tS.strict					= true; % do we enforce strict hold within the touch window?
% ---------------------------------------------------
% after initial fixation a target appears
tS.targetFixInit			= 3;
tS.targetFixTime			= 1;
tS.targetFixRadius			= 5;
% negation buffer: degrees of margin around target window outside which a
% deliberate touch is treated as incorrect. Used on step trials only.
tS.negationBuffer			= 4;

% Initialise the touchManager with the initial fixation window.
% Arguments: X, Y, radius, doNegation, negationBuffer, strict, init, hold, release
updateWindow(tM, tS.fixX, tS.fixY, tS.firstFixRadius, false, tS.negationBuffer, ...
	tS.strict, tS.firstFixInit, tS.firstFixTime, NaN);

%=========================================================================
%-------------------------ONLINE Behaviour Plot---------------------------
% WHICH states assigned as correct or break for online plot?
bR.correctStateName			= "correct";
bR.breakStateName			= ["breakfix","incorrect"];

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
pauseEntryFcn = {
	@()hide(stims);
	@()drawPhotoDiodeSquare(s,[0 0 0]); %draw black photodiode
	@()drawTextNow(s,'PAUSED, press [p] to resume...');
	@()disp('PAUSED, press [p] to resume...');
	@()flush(tM);  % clear any pending touch events
	@()reset(tM);  % reset touch hold state machine
	@()needFlip(me, false, 0); % no need to flip the PTB screen
};

%--------------------pause exit
pauseExitFcn = {
	@()flush(tM);  % clear any touch events that accumulated during pause
};

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%==============================================================PRE-FIXATION
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

prefixEntryFcn = {
	@()needFlip(me, true, 2); % start PTB screen flips
	@()hide(stims); % hide all stimuli
	% reset touch state and flush queued events for new trial
	@()flush(tM);
	@()reset(tM);
	% set touch window back to fixation cross position for this trial
	@()updateWindow(tM, tS.fixX, tS.fixY, tS.firstFixRadius, false, tS.negationBuffer, ...
		tS.strict, tS.firstFixInit, tS.firstFixTime, NaN);
	@()getStimulusPositions(stims,true); % build struct for drawing stim positions
	@()trackerTrialStart(eT, getTaskIndex(me)); % no-op if no eyetracker
	@()trackerMessage(eT,['UUID ' UUID(sM)]);
	% updateNextState reads the trial factor from taskSequence and sets
	% the next state to either 'nostepfix' or 'stepfix'
	@()updateNextState(me,'trial');
};

prefixFcn = {
	@()drawPhotoDiodeSquare(s,[0 0 0]);
};

prefixExitFcn = {
	@()show(stims, 3); % show fixation cross ready for nostepfix / stepfix
	@()logRun(me,'PREFIX');
};

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%=======================================================NOSTEP FIX + STIMULATION
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%--------------------nostep fixation entry
nsfEntryFcn = {
	@()edit(stims,1,'offTime',0.1); % reset offTime just in case
	@()resetTicks(stims); % regenerate delay/off timers for stimulus drawing
	@()logRun(me,'Nostep Fix'); %fprintf current trial info to command window
};

%--------------------nostep fix within
nsfFcn = {
	@()draw(stims, 3); %draw fixation cross
};

%--------------------test we are touching and holding fixation
nsfTestFcn = {
	% returns 'nostep' when hold time is met, 'breakfix' when failed/timeout
	@()testHold(tM,'nostep','breakfix');
};

%--------------------exit nostep fixation — move touch window to target 1
nsfExitFcn = {
	@()hide(stims, 3);
	@()show(stims, 1);
	% move touch window to stims{1} (target one) position.
	% no negation on nostep trials: subjects may briefly look at target one
	% before it extinguishes; we just want them to touch the correct location.
	@()updateWindow(tM, me.lastXPosition, me.lastYPosition, tS.targetFixRadius, ...
		false, tS.negationBuffer, tS.strict, tS.targetFixInit, tS.targetFixTime, NaN);
	@()flush(tM);
	@()reset(tM, true); % soft reset: keep lastPressed, reset hold timers
};

%--------------------nostep stimulus entry
nsEntryFcn = {
	@()doStrobe(me,true);
};

%--------------------nostep stimulus within
nsFcn = {
	@()draw(stims, 1);
};

%--------------------test subject touches target 1
nsTestFcn = {
	% returns 'correct' when held, 'incorrect' when failed/timeout
	@()testHold(tM,'correct','incorrect');
};

%--------------------exit nostep stimulus
nsExitFcn = {
	@()setStrobeValue(me, me.strobe.stimOFFValue);
	@()doStrobe(me,true);
};

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%=========================================================STEP FIX + STIMULATION
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%--------------------step fixation entry
sfEntryFcn = {
	@()edit(stims,1,'offTime',0.1); % reset offTime just in case
	@()logRun(me,'Step Fix'); %fprintf current trial info to command window
};

%--------------------step fix within
sfFcn = {
	@()draw(stims, 3); %draw fixation cross
};

%--------------------test we are touching and holding fixation
sfTestFcn = {
	% returns 'step' when hold time is met, 'breakfix' when failed/timeout
	@()testHold(tM,'step','breakfix');
};

%--------------------exit step fixation — move touch window to target 2
sfExitFcn = {
	@()hide(stims, 3);
	@()show(stims, [1 2]);
	% set TSD delay on stim 2 (the step target) using current staircase value
	@()setDelayTimeWithStaircase(uF, 2, 0.1);
	@()resetTicks(stims);
	% move touch window to stims{2} (target two) position.
	% doNegation=true: touching near target one (the initial target direction)
	% returns -100 and is treated as incorrect by testHold.
	@()updateWindow(tM, me.lastXPosition, me.lastYPosition, tS.targetFixRadius, ...
		true, tS.negationBuffer, tS.strict, tS.targetFixInit, tS.targetFixTime, NaN);
	@()flush(tM);
	@()reset(tM, true); % soft reset: keep lastPressed, reset hold timers
};

%--------------------step stimulus entry
sEntryFcn = {
	@()doStrobe(me,true);
};

%--------------------step stimulus within
sFcn = {
	@()draw(stims,[1 2]);
};

%--------------------test subject touches target 2
sTestFcn = {
	% returns 'correct' when held, 'incorrect' when failed/timeout or negation
	@()testHold(tM,'correct','incorrect');
};

%--------------------exit step stimulus
sExitFcn = {
	@()setStrobeValue(me, me.strobe.stimOFFValue);
	@()doStrobe(me,true);
};

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%=======================================================================DECISION
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%--------------------CORRECT
correctEntryFcn = {
	@()giveReward(rM); % send a reward TTL
	@()beep(aM,tS.correctSound); % correct beep
	@()trackerTrialEnd(eT, tS.CORRECT); % no-op if no eyetracker
	@()hide(stims);
	@()reset(tM); % reset touch state for next trial
	@()logRun(me,'CORRECT'); %fprintf current trial info
};

%--------------------correct within
correctFcn = {
	@()drawBackground(s);
};

%--------------------exit correct state
correctExitFcn = {
	@()updatePlot(bR, me); %update our behavioural plot
	@()updateTask(me,tS.CORRECT); %move taskSequence to the next trial
	@()updateStaircaseAfterState(me, tS.CORRECT,'step'); % only update staircase after a step trial
	@()updateVariables(me); %randomise our stimuli, and set strobe value too
	@()update(stims); %update our stimuli ready for display
	@()getStimulusPositions(stims,true); %update cached stimulus positions
	@()plot(bR, 1); % actually do our behaviour record drawing
	@()checkTaskEnded(me); %check if task is finished
};

%--------------------INCORRECT entry
incEntryFcn = {
	@()beep(aM, tS.errorSound);
	@()trackerTrialEnd(eT, tS.INCORRECT); % no-op if no eyetracker
	@()hide(stims);
	@()reset(tM); % reset touch state
	@()logRun(me,'INCORRECT'); %fprintf current trial info
};

%--------------------incorrect within
incFcn = {
	@()drawBackground(s);
};

%--------------------incorrect / break shared exit
incExitFcn = {
	@()updateStaircaseAfterState(me,tS.BREAKFIX,'step'); % only update staircase after a step trial
	@()updateVariables(me); %randomise our stimuli, set strobe value too
	@()update(stims); %update our stimuli ready for display
	@()getStimulusPositions(stims,true); %update cached stimulus positions
	@()plot(bR, 1); % actually do our behaviour record drawing
	@()checkTaskEnded(me); %check if task is finished
};

%--------------------BREAKFIX entry
breakEntryFcn = {
	@()beep(aM, tS.errorSound);
	@()trackerTrialEnd(eT, tS.BREAKFIX); % no-op if no eyetracker
	@()hide(stims);
	@()reset(tM); % reset touch state
	@()logRun(me,'BREAKFIX'); %fprintf current trial info
};

breakExitFcn = incExitFcn;

if tS.includeErrors
	incExitFcn   = [ {@()updatePlot(bR, me);@()updateTask(me,tS.INCORRECT)}; incExitFcn ];
	breakExitFcn = [ {@()updatePlot(bR, me);@()updateTask(me,tS.BREAKFIX)};  incExitFcn ];
else
	incExitFcn   = [ {@()updatePlot(bR, me);@()resetRun(task)}; incExitFcn ]; % randomise within block
	breakExitFcn = [ {@()updatePlot(bR, me);@()resetRun(task)}; incExitFcn ]; % randomise within block
end

%======================================================================
%======================================================================GENERAL
%======================================================================
%--------------------DEBUGGER override
overrideFcn = { @()keyOverride(me) }; %enter a matlab debug state to manually edit object values

%--------------------screenflash
flashFcn = { @()flashScreen(s, 0.2) }; % fullscreen flash for visual background detection

%--------------------show 1deg size grid
gridFcn = { @()drawGrid(s) };

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%------------------------------------------------------------------------%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%==========================================================================
%==========================================================================
%==========================================================================
%--------------------------State Machine Table-----------------------------
% specify our cell array that is read by the stateMachine
stateInfoTmp = {
'name'      'next'		'time'  'entryFcn'		'withinFcn'		'transitionFcn'	'exitFcn';
%---------------------------------------------------------------------------------------------
'pause'		'prefix'	inf		pauseEntryFcn	{}				{}				pauseExitFcn;
'prefix'	'breakfix'	0.5		prefixEntryFcn	prefixFcn		{}				prefixExitFcn;
%---------------------------------------------------------------------------------------------
'nostepfix'	'breakfix'	5		nsfEntryFcn		nsfFcn			nsfTestFcn		nsfExitFcn;
'nostep'	'breakfix'	5		nsEntryFcn		nsFcn			nsTestFcn		nsExitFcn;
'stepfix'	'breakfix'	5		sfEntryFcn		sfFcn			sfTestFcn		sfExitFcn;
'step'		'breakfix'	5		sEntryFcn		sFcn			sTestFcn		sExitFcn;
%---------------------------------------------------------------------------------------------
'breakfix'	'timeout'	0.5		breakEntryFcn	incFcn			{}				breakExitFcn;
'incorrect'	'timeout'	0.5		incEntryFcn		incFcn			{}				incExitFcn;
'correct'	'prefix'	0.5		correctEntryFcn	correctFcn		{}				correctExitFcn;
'timeout'	'prefix'	tS.tOut	{}				{}				{}				{};
%---------------------------------------------------------------------------------------------
'override'	'pause'		0.5		overrideFcn		{}				{}				{};
'flash'		'pause'		0.5		flashFcn		{}				{}				{};
'showgrid'	'pause'		10		{}				gridFcn			{}				{};
};
%--------------------------State Machine Table-----------------------------
%==========================================================================

disp('=================>> Built state info file <<==================')
disp(stateInfoTmp)
disp('=================>> Built state info file <<=================')
clearvars -regexp '.+Fcn$' % clear the cell array Fcns in the current workspace

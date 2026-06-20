%> HSMTEST state configuration file for runExperiment.runTask — a
%> hierarchical (nested) version of DefaultStateInfo.m demonstrating
%> parent/child states via the `parent` column.
%>
%> Hierarchy:
%>
%>   trial (parent)            one entry/exit per trial
%>   ├── fixate                acquire fixation (inFixFcn -> stimulus | breakfix)
%>   ├── stimulus              show stimulus, maintain fixation (-> feedback | timeout)
%>   └── feedback              deliver reward / error feedback (-> timeout)
%>   breakfix (root)           break-fix feedback (exits trial subtree)
%>   timeout  (root)           inter-trial interval (-> trial)
%>   pause / calibrate / drift / offset / flash / showgrid / override (root)
%>
%> The HSM organisation lets "trial" entry (flip enable, eye sample,
%> hide stims, reset fixation, tracker trial start) and "trial" exit
%> (hide stims, tracker trial end) run once per trial, wrapping the
%> fixate -> stimulus -> feedback sub-states. breakfix and timeout are
%> outside the trial subtree, so transitioning to them exits the whole
%> trial chain (external transition to LCA = root).
%>
%> This file follows the same StateInfo contract as DefaultStateInfo.m:
%> it runs in runExperiment.runTask() scope and builds `stateInfoTmp`,
%> a cell array with an extra `parent` column. Use it with:
%>   o = opticka; o.r.stateMachineClass = 'stateMachineHSM';
%> (or 'stateMachineTree'). With the flat 'stateMachine' class the
%> `parent` column is ignored and every state is a root.
%>
%> The following class objects are available (see DefaultStateInfo.m):
%> me, tS, s, sM, task, stims, aM, eT, tM, io, rM, bR, tL, uF

%=========================================================================
%-----------------------------General Settings----------------------------
tS.name						= 'HSM Test Protocol';
tS.saveData					= true;
tS.showBehaviourPlot		= true;
tS.useTask					= true;
tS.keyExclusionPattern		= ["fixate","stimulus"];
tS.enableTrainingKeys		= false;
tS.recordEyePosition		= false;
tS.includeErrors			= false;
tS.nStims					= stims.n;
tS.timeOut					= 2;
tS.CORRECT					= 1;
tS.BREAKFIX					= -1;
tS.INCORRECT				= -5;
tS.correctSound				= [2000, 0.1, 0.1];
tS.errorSound				= [300, 1, 1];

%==================================================================
%-----------------INITIAL Eyetracker Settings----------------------
tS.fixX						= 0;
tS.fixY						= 0;
tS.fixWindow				= 2;
tS.firstFixTime			= 0.3;
tS.stimulusFixTime		= 0.3;

%==================================================================
%-----------------State functions (entry/within/transition/exit)----
% These mirror DefaultStateInfo.m but are reorganised into a hierarchy.

%==================== TRIAL parent (per-trial setup/teardown) =======
% entry: everything that was in prefixEntryFcn — runs once per trial
trialEntryFcn = {
	@()needFlip(me, true, 4);            % enable screen + tracker flip
	@()needEyeSample(me, true);          % start measuring eye position
	@()getStimulusPositions(stims);      % stim positions struct for eT
	@()hide(stims);                      % hide all stimuli
	@()resetAll(eT);                     % reset fixation markers
	@()updateFixationValues(eT,tS.fixX,tS.fixY,[],tS.firstFixTime);
	@()trackerTrialStart(eT, getTaskIndex(me));
	@()trackerMessage(eT,['UUID ' UUID(sM)]);
};
trialWithinFcn = {
	@()drawPhotoDiodeSquare(s,[0 0 0]);
};
% trial-level transition: returns '' so child transitions win. A real
% protocol could catch a global abort here (leaf->root eval order).
trialTransFcn = { @()sprintf('') };
trialExitFcn = {
	@()hide(stims);                      % hide all stimuli on trial exit
	@()trackerMessage(eT,'MSG:TrialEnd');
};

%==================== FIXATE child (acquire fixation) ===============
fixEntryFcn = {
	@()show(stims{tS.nStims});           % show fixation cross
	@()trackerMessage(eT,'MSG:Start Fix');
	@()trackerDrawStatus(eT,'Start trial...', stims.stimulusPositions, 0, false);
};
fixFcn = {
	@()draw(stims);
	@()drawPhotoDiodeSquare(s,[0 0 0]);
	@()animate(stims);
};
% inFixFcn: return 'stimulus' when fixated, 'breakfix' if broken, else ''
inFixFcn = { @()testSearchHoldFixation(eT,'stimulus','breakfix') };
fixExitFcn = {
	@()updateFixationValues(eT,[],[],[],tS.stimulusFixTime);
	@()show(stims);                      % show all stims
	@()trackerMessage(eT,'END_FIX');
};

%==================== STIMULUS child (show stimulus) ================
stimEntryFcn = {
	@()doSyncTime(me);
	@()doStrobe(me,true);
};
stimFcn = {
	@()draw(stims);
	@()drawPhotoDiodeSquare(s,[1 1 1]);
	@()animate(stims);
};
% maintainFixFcn: return 'feedback' when maintain time elapsed, 'timeout' if broken
stimTransFcn = { @()testHoldFixation(eT,'feedback','timeout') };
stimExitFcn = {
	@()setStrobeValue(me, 255);
	@()doStrobe(me, true);
};

%==================== FEEDBACK child (reward / error) ===============
% feedback logic branches on task outcome. We use two feedback states
% (correctFeedback / incorrectFeedback) as children of trial so the
% trial exit chain still runs after feedback.
correctEntryFcn = {
	@()logRun(me,'CORRECT');
	@()trackerDrawStatus(eT,'CORRECT! :-)', stims.stimulusPositions, 0, false);
	@()updatePlot(bR, me);
	@()updateTask(me,tS.CORRECT);
	@()sendReward(rM);
	@()playSound(aM, tS.correctSound);
};
correctFcn = { @()draw(stims); @()animate(stims); };
correctExitFcn = { @()checkTaskEnded(me); };

incEntryFcn = {
	@()logRun(me,'INCORRECT');
	@()trackerDrawStatus(eT,'INCORRECT! :-(', stims.stimulusPositions, 0, false);
	@()updatePlot(bR, me);
	@()resetRun(task);
};
incFcn = { @()draw(stims); @()animate(stims); };
incExitFcn = {};

%==================== BREAKFIX (root — exits trial subtree) =========
breakEntryFcn = {
	@()logRun(me,'BREAK_FIX');
	@()trackerDrawStatus(eT,'BREAK_FIX! :-(', stims.stimulusPositions, 0, false);
	@()updatePlot(bR, me);
	@()resetRun(task);
};
breakExitFcn = {};

%==================== TIMEOUT (root — inter-trial interval) =========
% within runs the photo diode square; no entry/exit
timeoutFcn = { @()drawPhotoDiodeSquare(s,[0 0 0]); };

%==================== CONTROL states (root) =========================
pauseEntryFcn = {
	@()hide(stims);
	@()stopRecording(eT);
	@()setOffline(eT);
};
pauseExitFcn = { @()startRecording(eT, true); };
calibrateFcn = {
	@()drawBackground(s);
	@()stopRecording(eT);
	@()setOffline(eT);
	@()trackerSetup(eT);
};
driftFcn = {
	@()drawBackground(s);
	@()stopRecording(eT);
	@()setOffline(eT);
	@()driftCorrection(eT);
};
offsetFcn = {
	@()drawBackground(s);
	@()stopRecording(eT);
	@()setOffline(eT);
	@()driftOffset(eT);
};
overrideFcn = { @()keyOverride(me); };
flashFcn = { @()flashScreen(s, 0.2); };
gridFcn = { @()drawGrid(s); };

%==================================================================
%--------------------------State Machine Table---------------------
% Note the `parent` column: empty = root, a name = child of that state.
% Children share the trial-level entry/exit via the HSM entry/exit chain.
stateInfoTmp = {
'name'				'next'			'time'	'parent'	'entryFcn'		'withinFcn'		'transitionFcn'	'exitFcn';
%----------------------------------------------------------------------------------------
'pause'				'trial'			inf		''			pauseEntryFcn	{}				{}				pauseExitFcn;
%--- trial subtree (parent: per-trial setup/teardown) ------------------
'trial'				''				10		''			trialEntryFcn	trialWithinFcn	trialTransFcn	trialExitFcn;
'fixate'			'stimulus'		10		'trial'		fixEntryFcn		fixFcn			inFixFcn		fixExitFcn;
'stimulus'			'feedback'		10		'trial'		stimEntryFcn	stimFcn			stimTransFcn	stimExitFcn;
'feedback'			'timeout'		0.1		'trial'		correctEntryFcn	correctFcn		{}				correctExitFcn;
%--- root outcome states (external transitions exit the trial chain) ---
'breakfix'			'timeout'		0.1		''			breakEntryFcn	incFcn			{}				breakExitFcn;
'timeout'			'trial'			tS.timeOut ''		{}				timeoutFcn		{}				{};
%--- control states (root) ---------------------------------------------
'calibrate'			'pause'			0.5		''			calibrateFcn	{}				{}				{};
'drift'				'pause'			0.5		''			driftFcn		{}				{}				{};
'offset'			'pause'			0.5		''			offsetFcn		{}				{}				{};
'override'			'pause'			0.5		''			overrideFcn		{}				{}				{};
'flash'				'pause'			0.5		''			flashFcn		{}				{}				{};
'showgrid'			'pause'			10		''			{}				gridFcn			{}				{};
};
%--------------------------State Machine Table---------------------
%==================================================================

% skipExitStates: when fixate transitions to breakfix, skip fixate's exit
% (the trial exit chain still runs). Mirrors DefaultStateInfo behaviour.
sM.skipExitStates = {'fixate','breakfix|timeout'};

disp('=================>> Built HSM state info file <<==================')
disp(stateInfoTmp)
disp('=================>> Built HSM state info file <<=================')
clearvars -regexp '.+Fn$'
clearvars -regexp '.+Fcn$'

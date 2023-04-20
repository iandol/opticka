% SACCADE COUNTERMANDING TASK - See Thakkar et al., 2011 | Hanes & Schall 1995
% A fixation cross appears and after a delay it disappears and a saccade
% target appears. On 70% of trials a speeded saccade in <500ms is rewarded.
% In 30% of trials, the fixation cross reappears (STOP signal) after a
% delay and the subject MUST maintain fixation. The stop signal delay (SSD)
% is controlled by a staircase, and the percentage choice of STOP / NOSTOP
% trial is controlled by taskSequence.trialVar

%=========================================================================
%-------------------------------Task Settings-----------------------------
% we use a up/down staircase to control the SSD (delay in seconds)
assert(exist('PAL_AMUD_setupUD','file'),'MUST Install Palamedes Toolbox: https://www.palamedestoolbox.org')
% Note this is managed by taskSequence, See Palamedes toolbox for the
% PAL_AM methods. 1up / 1down staircase starts at 225ms and steps at 32ms
task.staircase = [];
task.staircase.type = 'UD';
task.staircase.sc = PAL_AMUD_setupUD('up',1,'down',1,'stepSizeUp',0.05,'stepSizeDown',0.05,...
					'stopRule',64,'startValue',0.25,'xMin',0.015,'xMax',0.5);
task.staircase.invert = true; % a correct increases value.
% we use taskSequence to randomise which state to switch to (independent
% trial-level factor). We call @()updateNextState(me,'trial') in the
% prefixation state; this sets one of these two trialVar.values as the next
% state. The nostopfix and stopfix states will then call nostop or stop
% stimulus states.
% These are actually set by the opticka GUI, but this is the task code
%    task.trialVar.values		= {'nostopfix','stopfix'};
%    task.trialVar.probability	= [0.6 0.4];
%    task.trialVar.comment		= 'nostep or step trial based on 60:40 probability';
% tell timeLog which states are "stimulus" states
tL.stimStateNames			= ["nostop","stop"];

%=========================================================================
%-----------------------------General Settings----------------------------
% These settings are make changing the behaviour of the protocol easier. tS
% is just a struct(), so you can add your own switches or values here and
% use them lower down. Some basic switches like saveData, useTask,
% checkKeysDuringstimulus will influence the runeExperiment.runTask()
% functionality, not just the state machine. Other switches like
% includeErrors are referenced in this state machine file to change with
% functions are added to the state machine states…
tS.useTask					= true;		%==use taskSequence (randomises stimulus variables)
tS.rewardTime				= 250;		%==TTL time in milliseconds
tS.rewardPin				= 2;		%==Output pin, 2 by default with Arduino.
tS.keyExclusionPattern		= ["nostopfix","nostop","stopfix","stop"]; %==which states to skip keyboard checking (slightly improve performance)
tS.enableTrainingKeys		= false;	%==enable keys useful during task training, but not for data recording
tS.recordEyePosition		= false;	%==record a local copy of eye position, **in addition** to the eyetracker?
tS.askForComments			= false;	%==UI requestor asks for comments before/after run
tS.saveData					= true;		%==save behavioural and eye movement data?
tS.showBehaviourPlot		= true;		%==open the behaviourPlot figure? Can cause more memory use…
tS.name						= 'Saccadic Countermanding'; %==name of this protocol
tS.nStims					= stims.n;	%==number of stimuli, taken from metaStimulus object
tS.tOut						= 1;		%==if wrong response, how long to time out before next trial
tS.CORRECT					= 1;		%==the code to send eyetracker for correct trials
tS.BREAKFIX					= -1;		%==the code to send eyetracker for break fix trials
tS.INCORRECT				= -5;		%==the code to send eyetracker for incorrect trials
tS.correctSound				= [2000, 0.1, 0.1]; %==freq,length,volume
tS.errorSound				= [300,  1.0, 1.0]; %==freq,length,volume

%=========================================================================
%----------------Debug logging to command window------------------
% uncomment each line to get specific verbose logging from each of these
% components; you can also set verbose in the opticka GUI to enable all of
% these…
%sM.verbose					= true;		%==print out stateMachine info for debugging
%stims.verbose				= true;		%==print out metaStimulus info for debugging
%io.verbose					= true;		%==print out io commands for debugging
%eT.verbose					= true;		%==print out eyelink commands for debugging
%rM.verbose					= true;		%==print out reward commands for debugging
task.verbose				= true;		%==print out task info for debugging
uF.verbose					= true;		%==print out user function logg for debugging

%=========================================================================
%-----------------INITIAL Eyetracker Settings----------------------
% These settings define the initial fixation window and set up for the
% eyetracker. They may be modified during the task (i.e. moving the fixation
% window towards a target, enabling an exclusion window to stop the subject
% entering a specific set of display areas etc.)
%
% **IMPORTANT**: you need to make sure that the global state time is larger than
% any fixation timers specified here. Each state has a global timer, so if the
% state timer is 5 seconds but your fixation timer is 6 seconds, then the state
% will finish before the fixation time was completed!
%------------------------------------------------------------------
% initial fixation X position in degrees (0° is screen centre). 
tS.fixX						= 0;
% initial fixation Y position in degrees  (0° is screen centre). 
tS.fixY						= 0;
% time to search and enter fixation window (Initiate fixation)
tS.firstFixInit				= 3;
% time to maintain initial fixation within window, can be single value or a
% range to randomise between
tS.firstFixTime				= [0.5 1.0];
% fixation window radius in degrees; if you enter [x y] the window will be
% rectangular.
tS.firstFixRadius			= 2;
% do we forbid eye to enter-exit-reenter fixation window?
tS.strict					= true;
% ---------------------------------------------------
% in this task after iitial fixation a target appears
tS.targetFixInit			= 3;
tS.targetFixTime			= 1;
tS.targetFixRadius			= 5;

%=========================================================================
%-------------------------------Eyetracker setup--------------------------
% NOTE: the opticka GUI sets eyetracker options, you can override them here if
% you need...
eT.name						= tS.name;
if me.eyetracker.dummy;		eT.isDummy = true; end %===use dummy or real eyetracker? 
if tS.saveData;				eT.recordData = true; end %===save Eyetracker data?					
% Initialise eyetracker with X, Y, FixInitTime, FixTime, Radius, StrictFix
% values
updateFixationValues(eT, tS.fixX, tS.fixY, tS.firstFixInit, tS.firstFixTime, tS.firstFixRadius, tS.strict);

%=========================================================================
%-------------------------ONLINE Behaviour Plot---------------------------
% WHICH states assigned as correct or break for online plot?
bR.correctStateName				= "correct";
bR.breakStateName				= ["breakfix","incorrect"];

%=========================================================================
% which stimulus in the list is used for a fixation target? For this
% protocol it means the subject must saccade to this stimulus (the saccade
% target is #1 in the list) to get the reward.
stims.fixationChoice		= 1;

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

%==============================================================
%========================================================PAUSE
%==============================================================

%--------------------pause entry
pauseEntryFcn = {
	@()hide(stims);
	@()drawPhotoDiode(s,[0 0 0]); %draw black photodiode
	@()drawTextNow(s,'PAUSED, press [p] to resume...');
	@()disp('PAUSED, press [p] to resume...');
	@()trackerDrawStatus(eT,'PAUSED, press [p] to resume');
	@()trackerMessage(eT,'TRIAL_RESULT -100'); %store message in EDF
	@()resetAll(eT); % reset all fixation markers to initial state
	@()setOffline(eT); % set eyelink offline [tobii ignores this]
	@()stopRecording(eT, true); %stop recording eye position data, true=both eyelink & tobii
	@()needFlip(me, false); % no need to flip the PTB screen
	@()needEyeSample(me, false); % no need to check eye position
};

%--------------------pause exit
pauseExitFcn = {
	%start recording eye position data again, note true is required here as
	%the eyelink is started and stopped on each trial, but the tobii runs
	%continuously, so @()startRecording(eT) only affects eyelink but
	%@()startRecording(eT, true) affects both eyelink and tobii...
	@()startRecording(eT, true); 
}; 

%==============================================================
%====================================================PRE-FIXATION
%==============================================================
%--------------------prefixate entry
prefixEntryFcn = { 
	@()setOffline(eT); % set eyelink offline [tobii/irec ignores this]
	@()needFlip(me, true, 2); % enable the screen and trackerscreen flip
	@()needEyeSample(me, true); % make sure we start measuring eye position
	@()hide(stims); % hide all stimuli
	@()resetAll(eT); % reset the recent eye position history
	@()updateFixationValues(eT,tS.fixX,tS.fixY,tS.firstFixInit,tS.firstFixTime,tS.firstFixRadius,tS.strict); %reset fixation window
	@()getStimulusPositions(stims); %make a struct the eT can use for drawing stim positions
	% tracker messages that define a trial start
	@()trackerMessage(eT,'V_RT MESSAGE END_FIX END_RT'); % Eyelink commands
	@()trackerMessage(eT,sprintf('TRIALID %i',getTaskIndex(me))); %Eyelink start trial marker
	@()trackerMessage(eT,['UUID ' UUID(sM)]); %add in the uuid of the current state for good measure
	@()startRecording(eT); % start eyelink recording for this trial (tobii/irec ignore this)
	@()trackerDrawStatus(eT,'PREFIX', stims.stimulusPositions);
	% updateNextState method is critical, it reads the independent trial factor in
	% taskSequence to select state to transition to next. This sets
	% stateMachine.tempNextState.
	@()updateNextState(me,'trial'); 
};

%--------------------prefixate within
prefixFcn = {
	@()drawPhotoDiode(s,[0 0 0]);
};

%--------------------prefixate exit
prefixExitFcn = {
	@()resetDelayTime(uF, 2, 0); % reset the delay time for stim 2 to 0;
	@()show(stims{2});
};

%========================================================
%========================================================NOSTOP
%========================================================

nsEntryFcn = { 
	@()trackerDrawStatus(eT,'NOSTOP', stims.stimulusPositions);
	@()logRun(me,'NOSTOP-FIXATE');
};

%--------------------fix within
nsFcn = {
	@()draw(stims{2}); %draw stimuli
	@()trackerDrawEyePosition(eT);
	@()drawPhotoDiode(s,[0 0 0]);
};

%--------------------test we are fixated for a certain length of time
nsFixFcn = {
	% this command performs the logic to search and then maintain fixation
	% inside the fixation window. The eyetracker parameters are defined above.
	% If the subject does initiate and then maintain fixation, then 'correct'
	% is returned and the state machine will jump to the correct state,
	% otherwise 'breakfix' is returned and the state machine will jump to the
	% breakfix state. If neither condition matches, then the state table below
	% defines that after 5 seconds we will switch to the incorrect state.
	@()testSearchHoldFixation(eT,'nostop','breakfix')
};

%--------------------exit fixation phase
nsExitFcn = {
	@()updateFixationTarget(me, true, tS.targetFixInit, tS.targetFixTime, tS.targetFixRadius, tS.strict);
	@()hide(stims{2});
	@()show(stims{1});
}; 

ns2EntryFcn = { @()doStrobe(me,true); };

%--------------------fix within
ns2Fcn = {
	@()draw(stims{1}); %draw stimuli
	@()trackerDrawEyePosition(eT);
	@()drawPhotoDiode(s,[1 1 1]);
};

%--------------------test we are fixated for a certain length of time
ns2FixFcn = {
	% this command performs the logic to search and then maintain fixation
	% inside the fixation window. The eyetracker parameters are defined above.
	% If the subject does initiate and then maintain fixation, then 'correct'
	% is returned and the state machine will jump to the correct state,
	% otherwise 'breakfix' is returned and the state machine will jump to the
	% breakfix state. If neither condition matches, then the state table below
	% defines that after 5 seconds we will switch to the incorrect state.
	@()testSearchHoldFixation(eT,'correct','incorrect')
};

%--------------------exit fixation phase
ns2ExitFcn = { 
	@()setStrobeValue(me,255); 
	@()doStrobe(me,true);
}; 

%========================================================
%========================================================STOPSIGNAL
%========================================================

sfEntryFcn = {
	@()trackerDrawStatus(eT,'STOP', stims.stimulusPositions);
	@()logRun(me,'STOP-FIXATE');
};

sfFcn =  {
	@()draw(stims{2});
	@()trackerDrawEyePosition(eT);
	@()drawPhotoDiode(s,[0 0 0]);
};

sfFixFcn = {
	% this command performs the logic to search and then maintain fixation
	% inside the fixation window. 
	@()testSearchHoldFixation(eT,'stop','breakfix'); 
};

%as we exit stim presentation state
sfExitFcn = {
	@()show(stims);
	@()updateFixationValues(eT,[],[], 0.5, 1, tS.targetFixRadius);
	@()setDelayTimeWithStaircase(uF,2); %sets the delayTime for fixation cross to reappear
};

sEntryFcn = {
	@()doStrobe(me,true);
};

sFcn =  {
	@()draw(stims);
	@()trackerDrawEyePosition(eT);
	@()drawPhotoDiode(s,[1 1 1]);
};

sFixFcn = {
	% this command performs the logic to maintain fixation
	% inside the fixation window. 
	@()testHoldFixation(eT,'correct','incorrect'); 
};

%as we exit stim presentation state
sExitFcn = {
	@()setStrobeValue(me,255); 
	@()doStrobe(me,true);
};

%========================================================
%========================================================DECISIONS
%========================================================

%========================================================CORRECT
%--------------------if the subject is correct (small reward)
correctEntryFcn = {
	@()timedTTL(rM, tS.rewardPin, tS.rewardTime); % send a reward TTL
	@()beep(aM, tS.correctSound);
	@()trackerMessage(eT,'END_RT'); %send END_RT message to tracker
	@()trackerMessage(eT,sprintf('TRIAL_RESULT %i',tS.CORRECT)); %send TRIAL_RESULT message to tracker
	@()trackerDrawStatus(eT, 'CORRECT! :-)');
	@()needEyeSample(me,false); % no need to collect eye data until we start the next trial
	@()hide(stims); % hide all stims
	@()logRun(me,'CORRECT'); % print current trial info
};

%--------------------correct stimulus
correctFcn = {
	@()drawPhotoDiode(s,[0 0 0]);
};

%--------------------when we exit the correct state
correctExitFcn = {
	@()stopRecording(eT); % stop recording in eyelink [tobii ignores this]
	@()setOffline(eT); % set eyelink offline [tobii ignores this]
	@()updatePlot(bR, me); % update our behavioural record, MUST be done before we update variables
	@()updateTask(me,tS.CORRECT); % make sure our taskSequence is moved to the next trial
	@()updateStaircaseAfterState(me,tS.CORRECT,'stop'); % only update staircase after a stop trial
	@()updateVariables(me); % randomise our stimuli, and set strobe value too
	@()update(stims); % update our stimuli ready for display
	@()checkTaskEnded(me); % check if task is finished
	@()plot(bR, 1); % actually do our behaviour record drawing
};

%========================================================INCORRECT
%--------------------incorrect entry
incEntryFcn = {
	@()beep(aM, tS.errorSound);
	@()trackerMessage(eT,'END_RT');
	@()trackerMessage(eT,sprintf('TRIAL_RESULT %i',tS.INCORRECT));
	@()trackerDrawStatus(eT,'INCORRECT! :-(', stims.stimulusPositions, 0);
	@()stopRecording(eT); % stop recording in eyelink [tobii ignores this]
	@()setOffline(eT); % set eyelink offline [tobii ignores this]
	@()needEyeSample(me,false);
	@()hide(stims);
	@()logRun(me,'INCORRECT'); %fprintf current trial info
};

%--------------------our incorrect/breakfix stimulus
incFcn = {
	@()drawPhotoDiode(s,[0 0 0]);
};

%--------------------incorrect exit
incExitFcn = {
	@()updatePlot(bR, me); % update our behavioural plot, must come before updateTask() / updateVariables()
	@()updateTask(me,tS.BREAKFIX); % make sure our taskSequence is moved to the next trial
	@()updateStaircaseAfterState(me,tS.BREAKFIX,'stop'); % only update staircase after a stop trial
	@()updateVariables(me); % randomise our stimuli, set strobe value too
	@()update(stims); % update our stimuli ready for display
	@()plot(bR, 1); % actually do our behavioural record drawing
};

%--------------------break entry
breakEntryFcn = {
	@()beep(aM, tS.errorSound);
	@()trackerMessage(eT,'END_RT');
	@()trackerMessage(eT,sprintf('TRIAL_RESULT %i',tS.BREAKFIX));
	@()trackerDrawStatus(eT,'BREAKFIX before complete trial! :-(', stims.stimulusPositions, 0);
	@()stopRecording(eT);
	@()setOffline(eT); % set eyelink offline [tobii ignores this]
	@()needEyeSample(me,false);
	@()hide(stims);
	@()logRun(me,'BREAKFIX'); %fprintf current trial info
};


%--------------------break exit
breakExitFcn = {
	@()updatePlot(bR, me); % update our behavioural plot, must come before updateTask() / updateVariables()
	@()updateVariables(me); % randomise our stimuli, set strobe value too
	@()update(stims); % update our stimuli ready for display
	@()plot(bR, 1); % actually do our behavioural record drawing
};

%--------------------change functions based on tS settings
% this shows an example of how to use tS options to change the function
% lists run by the state machine. We can prepend or append new functions to
% the cell arrays.
if tS.useTask %we are using task
	correctExitFcn = [ correctExitFcn; {@()checkTaskEnded(me)} ];
	incExitFcn = [ incExitFcn; {@()checkTaskEnded(me)} ];
	breakExitFcn = [ breakExitFcn; {@()checkTaskEnded(me)} ];
end

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
'pause'		'prefix'	inf		pauseEntryFcn	{}				{}				pauseExitFcn;
%---------------------------------------------------------------------------------------------
'prefix'	'nostop'	1		prefixEntryFcn	prefixFcn		{}				prefixExitFcn;
%---------------------------------------------------------------------------------------------
'nostopfix'	'breakfix'	8		nsEntryFcn		nsFcn			nsFixFcn		nsExitFcn;
'nostop'	'breakfix'	8		ns2EntryFcn		ns2Fcn			ns2FixFcn		ns2ExitFcn;
'stopfix'	'breakfix'	8		sEntryFcn		sFcn			sFixFcn			sExitFcn;
'stop'		'breakfix'	8		s2EntryFcn		s2Fcn			s2FixFcn		s2ExitFcn;
%---------------------------------------------------------------------------------------------
'breakfix'	'timeout'	0.5		breakEntryFcn	incFcn			{}				breakExitFcn;
'incorrect'	'timeout'	0.5		incEntryFcn		incFcn			{}				incExitFcn;
'correct'	'prefix'	0.5		correctEntryFcn	correctFcn		{}				correctExitFcn;
'timeout'	'prefix'	tS.timeOut	{}				incFcn			{}				{};
%---------------------------------------------------------------------------------------------
'calibrate'	'pause'		0.5		calibrateFcn	{}				{}				{};
'drift'		'pause'		0.5		driftFcn		{}				{}				{};
'offset'	'pause'		0.5		offsetFcn		{}				{}				{};
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

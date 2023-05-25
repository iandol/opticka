% DOUBLESTEP SACCADE task, Thakkar et al., 2015 Brain & Cognition 
% In nostep trials (60%), after 500-1000ms intial fixation, a saccade target
% (target one) is flashed for 100ms in one of 8 equidistant positions. In
% step trials (40%) after taget one flashes after a delay (target step
% delay, TSD) a second target (target two) flashes 90deg away and subject must saccade
% to target two for succesful trial. Subjects are not punished for
% reorienting from target one to target two.  TSD is modified using a
% 1U/1D staircase, and nostep / step trial assignment use taskSequence.trialVar

%=========================================================================
%-------------------------------Task Settings-----------------------------
% we use a up/down staircase to control the SSD (delay in seconds)
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
% state. The nostopfix and stopfix states will call nostep or step
% stimulus states respectively.
% These are actually set by the opticka GUI, but this is the task code do
% set this:
%     task.trialVar.comment		= 'nostep or step trial based on 60:40 probability';
%     task.trialVar.values		= {'nostepfix','stepfix'};
%     task.trialVar.probability	= [0.6 0.4];
% tell timeLog which states are "stimulus" states
tL.stimStateNames			= ["nostep","step"];

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
tS.includeErrors			= true;		%==do incorrect error trials count to move taskSequence forward
tS.rewardTime				= 250;		%==TTL time in milliseconds
tS.rewardPin				= 2;		%==Output pin, 2 by default with Arduino.
tS.keyExclusionPattern		= ["nostepfix","nostep","stepfix","step"]; %==which states to skip keyboard checking (slightly improve performance)
tS.enableTrainingKeys		= false;	%==enable keys useful during task training, but not for data recording
tS.recordEyePosition		= false;	%==record a local copy of eye position, **in addition** to the eyetracker?
tS.askForComments			= false;	%==UI requestor asks for comments before/after run
tS.saveData					= true;		%==save behavioural and eye movement data?
tS.showBehaviourPlot		= true;		%==open the behaviourPlot figure? Can cause more memory use…
tS.name						= 'Saccadic DoubleStep'; %==name of this protocol
tS.nStims					= stims.n;	%==number of stimuli, taken from metaStimulus object
tS.tOut						= 1;		%==timeout if breakfix/incorrect response
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
%---------------INITIAL Eyetracker Fixation Settings----------------------
% These settings define the initial fixation window and set up for the
% eyetracker. They may be modified during the task (i.e. moving the fixation
% window towards a target, enabling an exclusion window to stop the subject
% entering a specific set of display areas etc.)
%
% **IMPORTANT**: you need to make sure that the overall state time is larger than
% any fixation timers specified here. Each state has a timer, so if the
% state timer is 5 seconds but your fixation timer is 6 seconds, then the state
% will finish before the fixation time was completed!
%------------------------------------------------------------------
tS.fixX						= 0; % initial fixation X position in degrees (0° is screen centre). 
tS.fixY						= 0; % initial fixation Y position in degrees (0° is screen centre). 
tS.firstFixInit				= 3; % time to search and enter fixation window (Initiate fixation)
tS.firstFixTime				= [0.5 1.0]; % time to maintain initial fixation within window
tS.firstFixRadius			= 2; % fixation window radius in degrees
tS.strict					= true; % do we forbid eye to enter-exit-reenter fixation window?
% ---------------------------------------------------
% in this task after initial fixation a target appears
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
updateFixationValues(eT, tS.fixX, tS.fixY, tS.firstFixInit, tS.firstFixTime, tS.firstFixRadius, tS.strict);

%=========================================================================
%-------------------------ONLINE Behaviour Plot---------------------------
% WHICH states assigned as correct or break for online plot?
bR.correctStateName				= "correct";
bR.breakStateName				= ["breakfix","incorrect"];

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
pauseEntryFcn = {
	@()hide(stims);
	@()drawPhotoDiode(s,[0 0 0]); %draw black photodiode
	@()drawTextNow(s,'PAUSED, press [p] to resume...');
	@()disp('PAUSED, press [p] to resume...');
	@()trackerDrawStatus(eT,'PAUSED, press [p] to resume');
	@()trackerMessage(eT,'TRIAL_RESULT -100'); %store message in EDF
	@()resetAll(eT); % reset all fixation markers to initial state
	@()setOffline(eT); % set eyelink offline [tobii/irec ignores this]
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

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%==============================================================PRE-FIXATION
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%--------------------prefixate entry
prefixEntryFcn = {
	@()setOffline(eT); % set eyelink offline [tobii/irec ignores this]
	@()needFlip(me, true, 2); % enable the screen and trackerscreen flip
	@()needEyeSample(me, true); % make sure we start measuring eye position
	@()hide(stims); % hide all stimuli
	@()resetAll(eT); % reset the recent eye position history
	@()updateFixationValues(eT,tS.fixX,tS.fixY,tS.firstFixInit,tS.firstFixTime,tS.firstFixRadius); %reset fixation window to initial values
	@()getStimulusPositions(stims); %make a struct the eT can use for drawing stim positions
	% tracker messages that define a trial start
	@()trackerMessage(eT,'V_RT MESSAGE END_FIX END_RT'); % Eyelink commands
	@()trackerMessage(eT,sprintf('TRIALID %i',getTaskIndex(me))); %Eyelink start trial marker
	@()trackerMessage(eT,['UUID ' UUID(sM)]); %add in the uuid of the current state for good measure
	@()trackerDrawStatus(eT,'PREFIX', stims.stimulusPositions);
	@()startRecording(eT); % start eyelink recording for this trial (tobii/irec ignore this)
	% updateNextState method is critical, it reads the independent trial factor in
	% taskSequence to select state to transition to next. This sets
	% stateMachine.tempNextState to override the state table's default next
	% field. In this protocol that means we will move to either nostepfix
	% or stepfix states
	@()updateNextState(me,'trial');
};

prefixFcn = {
	@()trackerDrawFixation(eT);
	@()drawPhotoDiode(s,[0 0 0]);
};

prefixExitFcn = {
	@()show(stims, 3);
};

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%=======================================================NOSTEP FIX + STIMULATION
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%fixate entry
nsfEntryFcn = {
	@()edit(stims,1,'offTime',0.1); % make sure we reset this just in case
	@()resetTicks(stims); % this function regenerates the delay / off timers for stimulus drawing
	@()trackerDrawFixation(eT);
	@()logRun(me,'Nostep Fix'); %fprintf current trial info to command window
};

%fix within
nsfFcn = {
	@()trackerDrawEyePosition(eT);
	@()draw(stims, 3); %draw stimulus
};

%test we are fixated for a certain length of time
nsfTestFcn = { 
	% if subject found and held fixation, go to 'nostep' state, otherwise 'breakfix'
	@()testSearchHoldFixation(eT,'nostep','breakfix');
};

%exit fixation phase
nsfExitFcn = {
	@()hide(stims, 3);
	@()show(stims, 1);
	@()updateFixationTarget(me, 1, tS.targetFixInit, ...
		tS.targetFixTime, tS.targetFixRadius);
	@()trackerMessage(eT,'END_FIX');
}; 

%what to run when we enter the stim presentation state
nsEntryFcn = {
	@()trackerDrawFixation(eT);
	@()doStrobe(me,true);
};

%what to run when we are showing stimuli
nsFcn =  {
	@()draw(stims, 1);
	@()trackerDrawEyePosition(eT);
};

%test we are maintaining fixation
nsTestFcn = {
	% if subject found and held target, go to 'correct' state, otherwise 'incorrect'
	@()testSearchHoldFixation(eT,'correct','incorrect'); 
};

%as we exit stim presentation state
nsExitFcn = {
	@()setStrobeValue(me,255); 
	@()doStrobe(me,true);
};

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%=========================================================STEP FIX + STIMULATION
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

sfEntryFcn = { 
	@()edit(stims,1,'offTime',0.1);
	@()trackerDrawFixation(eT);
	@()logRun(me,'Step Fix'); %fprintf current trial info to command window
};

sfFcn = {
	@()draw(stims, 3); %draw stimulus
	@()trackerDrawEyePosition(eT);
};

sfTestFcn = { 
	% if subject found and held fixation, go to 'step' state, otherwise 'breakfix'
	@()testSearchHoldFixation(eT,'step','breakfix'); 
};

sfExitFcn = { 
	@()hide(stims, 3);
	@()show(stims, [1 2]);
	@()setDelayTimeWithStaircase(uF, 2, 0.1);
	@()resetTicks(stims);
	@()updateFixationTarget(me, 2, tS.targetFixInit, ...
		tS.targetFixTime, tS.targetFixRadius);
	@()trackerMessage(eT,'END_FIX');
}; 

%what to run when we enter the stim presentation state
sEntryFcn = {
	@()trackerDrawFixation(eT);
	@()doStrobe(me,true);
};

%test we are fixated for a certain length of time
sTestFcn = { 
	% if subject found and held fixation, go to 'correct' state, otherwise 'incorrect'
	@()testSearchHoldFixation(eT,'correct','incorrect'); 
};

%what to run when we are showing stimuli
sFcn =  { 
	@()trackerDrawEyePosition(eT);
	@()draw(stims,[1 2]);
};

sExitFcn = { 
	@()setStrobeValue(me,255); 
	@()doStrobe(me,true);	
};

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%=======================================================================DECISION
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

correctEntryFcn = { 
	@()giveReward(rM); % send a reward TTL
	@()beep(aM,tS.correctSound); % correct beep
	@()trackerMessage(eT,'END_RT');
	@()trackerMessage(eT,sprintf('TRIAL_RESULT %i',tS.CORRECT)); %send TRIAL_RESULT message to tracker
	@()trackerDrawStatus(eT, 'CORRECT! :-)');
	@()needEyeSample(me,false); % no need to collect eye data until we start the next trial
	@()hide(stims);
	@()logRun(me,'CORRECT'); %fprintf current trial info
};

%correct stimulus
correctFcn = { 
	@()drawBackground(s);
};

%when we exit the correct state
correctExitFcn = {
	@()stopRecording(eT); % stop recording in eyelink [tobii ignores this]
	@()setOffline(eT); % set eyelink offline [tobii ignores this]
	@()updatePlot(bR, me); %update our behavioural plot
	@()updateTask(me,tS.CORRECT); %make sure our taskSequence is moved to the next trial
	@()updateStaircaseAfterState(me, tS.CORRECT,'step'); % only update staircase after a stop trial
	@()updateVariables(me); %randomise our stimuli, and set strobe value too
	@()update(stims); %update our stimuli ready for display
	@()plot(bR, 1); % actually do our behaviour record drawing
	@()checkTaskEnded(me); %check if task is finished
};

%incorrect entry
incEntryFcn = { 
	@()beep(aM, tS.errorSound);
	@()trackerMessage(eT,'END_RT');
	@()trackerMessage(eT,['TRIAL_RESULT ' str2double(tS.INCORRECT)]);
	@()trackerMessage(eT,sprintf('TRIAL_RESULT %i',tS.INCORRECT));
	@()trackerDrawStatus(eT,'INCORRECT! :-(', stims.stimulusPositions, 0);
	@()stopRecording(eT); % stop recording in eyelink [tobii ignores this]
	@()setOffline(eT); % set eyelink offline [tobii ignores this]
	@()needEyeSample(me,false);
	@()hide(stims);
	@()logRun(me,'INCORRECT'); %fprintf current trial info
}; 

%our incorrect stimulus
incFcn = {
	@()drawBackground(s);
};

%incorrect / break exit
incExitFcn = {
	@()updateStaircaseAfterState(me,tS.BREAKFIX,'step'); % only update staircase after a stop trial
	@()updateVariables(me); %randomise our stimuli, don't run updateTask(task), and set strobe value too
	@()update(stims); %update our stimuli ready for display
	@()plot(bR, 1); % actually do our behaviour record drawing
	@()checkTaskEnded(me); %check if task is finished
};

%break entry
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

breakExitFcn = incExitFcn;

if tS.includeErrors
	incExitFcn   = [ {@()updatePlot(bR, me);@()updateTask(me,tS.INCORRECT)}; incExitFcn ]; 
	breakExitFcn = [ {@()updatePlot(bR, me);@()updateTask(me,tS.BREAKFIX)}; incExitFcn ]; 

else 
	incExitFcn   = [ {@()updatePlot(bR, me);@()resetRun(task)}; incExitFcn ]; % we randomise the run within this block to make it harder to guess next trial
	breakExitFcn = [ {@()updatePlot(bR, me);@()resetRun(task)}; incExitFcn ]; % we randomise the run within this block to make it harder to guess next trial
end


%==================================================================EXPERIMENTAL CONTROL

%==================================================================
%==================================================================EYETRACKER
%==================================================================
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

%======================================================================
%======================================================================GENERAL
%======================================================================
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
'name'      'next'		'time'  'entryFcn'		'withinFcn'		'transitionFcn'	'exitFcn';
%---------------------------------------------------------------------------------------------
'pause'		'prefix'	inf		pauseEntryFcn	{}				{}				pauseExitFcn;
'prefix'	'breakfix'	0.5		prefixEntryFcn	prefixFcn		{}				prefixExitFcn;
%---------------------------------------------------------------------------------------------
'nostepfix'	'breakfix'	5	 	nsfEntryFcn		nsfFcn			nsfTestFcn		nsfExitFcn;
'nostep'	'breakfix'	5	 	nsEntryFcn		nsFcn			nsTestFcn		nsExitFcn;
'stepfix'	'breakfix'	5		sfEntryFcn		sfFcn			sfTestFcn		sfExitFcn;
'step'		'breakfix'	5		sEntryFcn		sFcn			sTestFcn		sExitFcn;
%---------------------------------------------------------------------------------------------
'breakfix'	'timeout'	0.5		breakEntryFcn	incFcn			{}				breakExitFcn;
'incorrect'	'timeout'	0.5		incEntryFcn		incFcn			{}				incExitFcn;
'correct'	'prefix'	0.5		correctEntryFcn	correctFcn		{}				correctExitFcn;
'timeout'	'prefix'	tS.tOut	{}				{}				{}				{};
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

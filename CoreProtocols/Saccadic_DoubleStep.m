%> DOUBLESTEP SACCADE task, Thakkar et al., 2015 Brain & Cognition
%> 

%=========================================================================
%-------------------------------Task Settings-----------------------------
% we use a up/down staircase to control the SSD (delay in seconds)
assert(exist('PAL_AMUD_setupUD','file'),'MUST Install Palamedes Toolbox: https://www.palamedestoolbox.org')
% Note this is managed by taskSequence, See Palamedes toolbox for the
% PAL_AM methods. 1up / 1down staircase starts at 225ms and steps at 32ms
task.staircaseType = 'UD';
task.staircase = PAL_AMUD_setupUD('up',1,'down',1,'stepSizeUp',0.05,'stepSizeDown',0.05,...
					'stopRule',64,'startValue',0.25,'xMin',0.015,'xMax',0.5);
task.staircaseInvert = true; % a correct increases value.
% we use taskSequence to randomise which state to switch to (independent
% trial-level factor). We call @()updateNextState(me,'trial') in the
% prefixation state; this sets one of these two trialVar.values as the next
% state. The nostopfix and stopfix states will then call nostop or stop
% stimulus states.
% These are actually set by the opticka GUI
%task.trialVar.values		= {'nostep','step'};
%task.trialVar.probability	= [0.6 0.4];
%task.trialVar.comment		= 'nostep or step trial based on 60:40 probability';
tL.stimStateNames			= ["onestep","twostep"];

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
tS.timeOut					= 1;		%==if wrong response, how long to time out before next trial
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
%task.verbose				= true;		%==print out task info for debugging

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
tS.firstFixTime				= [0.9 1.1];
% fixation window radius in degrees; if you enter [x y] the window will be
% rectangular.
tS.firstFixRadius			= 2;
% do we forbid eye to enter-exit-reenter fixation window?
tS.strict					= true;
% ---------------------------------------------------
% in this task after iitial fixation a target appears
tS.targetFixInit			= 3;
tS.targetFixTime			= 1;
tS.targetFixRadius			= 4;

%=========================================================================
%-------------------------------Eyetracker setup--------------------------
% NOTE: the opticka GUI sets eyetracker options, you can override them here if
% you need...
eT.name				= tS.name;
if me.eyetracker.dummy;	eT.isDummy = true; end %===use dummy or real eyetracker? 
if tS.saveData;		eT.recordData = true; end %===save Eyetracker data?					
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
% protocol it means the subject must fixate this stimulus (the saccade
% target is #1 in the list) to get the reward. Also which stimulus to set
% an exclusion zone around (where a saccade into this area causes an
% immediate break fixation).
stims.fixationChoice = [1 2];
stims.exclusionChoice = [];

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
	@()needFlip(me, true, 1); % enable the screen and trackerscreen flip
	@()needEyeSample(me, true); % make sure we start measuring eye position
	@()hide(stims); % hide all stimuli
	@()edit(stims,3,'alphaOut',0.5); 
	@()edit(stims,3,'alpha2Out',1);
	@()resetAll(eT); % reset the recent eye position history
	@()updateFixationValues(eT,tS.fixX,tS.fixY,[],tS.firstFixTime); %reset fixation window to initial values
	@()startRecording(eT); % start eyelink recording for this trial (tobii/irec ignore this)
	% tracker messages that define a trial start
	@()trackerMessage(eT,'V_RT MESSAGE END_FIX END_RT'); % Eyelink commands
	@()trackerMessage(eT,sprintf('TRIALID %i',getTaskIndex(me))); %Eyelink start trial marker
	@()trackerMessage(eT,['UUID ' UUID(sM)]); %add in the uuid of the current state for good measure
	@()trackerDrawStatus(eT,'PREFIX', stims.stimulusPositions);
	% updateNextState method is critical, it reads the independent trial factor in
	% taskSequence to select state to transition to next. This sets
	% stateMachine.tempNextState to override the state table's default next field.
	@()updateNextState(me,'trial'); 
};

prefixFcn = {
	@()drawPhotoDiode(s,[0 0 0]);
};

prefixExitFcn = { 
	
};

%====================================================ONESTEP FIXATION + STIMULATION

%fixate entry
fixOSEntryFcn = { 
	@()show(stims, 3);
	@()logRun(me,'INITFIXOneStep'); %fprintf current trial info to command window
};

%fix within
fixOSFcn = {
	@()draw(stims, 3); %draw stimulus
};

%test we are fixated for a certain length of time
inFixOSFcn = { 
	% if subject found and held fixation, go to 'onestep' state, otherwise 'incorrect'
	@()testSearchHoldFixation(eT,'onestep','incorrect');
};

%exit fixation phase
fixOSExitFcn = {
	@()resetTicks(stims);
	@()show(stims, 1);
	@()hide(stims, 2);
	@()edit(stims,1,'offTime',0.1);
	@()set(stims,'fixationChoice',1);  % choose stim 1 as fixation target
	@()updateFixationTarget(me, tS.useTask, tS.targetFixInit, ...
		tS.targetFixTime, tS.targetRadius, false);
	@()trackerMessage(eT,'END_FIX');
}; 

%what to run when we enter the stim presentation state
osEntryFcn = {
	@()doStrobe(me,true);
	@()logRun(me,'ONESTEP'); %fprintf current trial info to command window
};

%what to run when we are showing stimuli
osFcn =  {
	@()draw(stims, 1);
	@()drawText(s,'ONESTEP');
	@()animate(stims); % animate stimuli for subsequent draw
};

%test we are maintaining fixation
maintainFixFcn = {
	% if subject found and held fixation, go to 'onestep' state, otherwise 'incorrect'
	@()testSearchHoldFixation(eT,'correct','breakfix'); 
};

%as we exit stim presentation state
sExitFcn = {
	@()setStrobeValue(me,255); 
	@()doStrobe(me,true);
};

%====================================================TWOSTEP FIXATION + STIMULATION

%fixate entry
fixTSEntryFcn = { 
	@()show(stims, 3);
	@()logRun(me,'INITFIXTwoStep'); %fprintf current trial info to command window
};

%fix within
fixTSFcn = {
	@()draw(stims, 3); %draw stimulus
};

%test we are fixated for a certain length of time
inFixTSFcn = { 
	% if subject found and held fixation, go to 'twostep' state, otherwise 'incorrect'
	@()testSearchHoldFixation(eT,'twostep','incorrect'); 
};

%exit fixation phase
fixTSExitFcn = { 
	@()resetTicks(stims);
	@()edit(stims,1,'offTime',0.1);
	@()edit(stims,2,'delayTime',0.1);
	@()edit(stims,2,'offTime',0.2);
	@()show(stims);
	@()set(stims,'fixationChoice',2); % choose stim 2 as fixation target
	@()updateFixationTarget(me, tS.useTask, tS.targetFixInit, ...
		tS.targetFixTime, tS.targetRadius, false);
	@()trackerMessage(eT,'END_FIX');
}; 

%what to run when we enter the stim presentation state
tsEntryFcn = {
	@()doStrobe(me,true);
	@()logRun(me,'TWOSTEP'); %fprintf current trial info to command window
};

%what to run when we are showing stimuli
tsFcn =  { 
	@()draw(stims,[1 2]);
	@()drawText(s,'TWOSTEP');
	@()animate(stims); % animate stimuli for subsequent draw	
};

%====================================================DECISION

%if the subject is correct (small reward)
correctEntryFcn = { 
	@()timedTTL(rM, tS.rewardPin, tS.rewardTime); % send a reward TTL
	@()beep(aM,2000); % correct beep
	@()trackerMessage(eT,'END_RT');
	@()trackerMessage(eT,['TRIAL_RESULT ' str2double(tS.CORRECT)]);
	@()trackerClearScreen(eT);
	@()trackerDrawText(eT,'Correct! :-)');
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
	@()updatePlot(bR, me); %update our behavioural plot
	@()updateTask(me,tS.CORRECT); %make sure our taskSequence is moved to the next trial
	@()updateVariables(me); %randomise our stimuli, and set strobe value too
	@()update(stims); %update our stimuli ready for display
	@()getStimulusPositions(stims); %make a struct the eT can use for drawing stim positions
	@()resetExclusionZones(eT); %reset the exclusion zones
	@()drawnow;
	@()checkTaskEnded(me); %check if task is finished
};

%incorrect entry
incEntryFcn = { 
	@()beep(aM,400,0.5,1);
	@()trackerMessage(eT,'END_RT');
	@()trackerMessage(eT,['TRIAL_RESULT ' str2double(tS.INCORRECT)]);
	@()trackerClearScreen(eT);
	@()trackerDrawText(eT,'Incorrect! :-(');
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
	@()updatePlot(bR, me); %update our behavioural plot, must come before updateTask() / updateVariables()
	@()updateVariables(me); %randomise our stimuli, don't run updateTask(task), and set strobe value too
	@()update(stims); %update our stimuli ready for display
	@()getStimulusPositions(stims); %make a struct the eT can use for drawing stim positions
	@()resetExclusionZones(eT); %reset the exclusion zones
	@()drawnow;
	@()checkTaskEnded(me); %check if task is finished
};
if tS.includeErrors
	incExitFcn = [ {@()updateTask(me,tS.BREAKFIX)}; incExitFcn ]; % make sure our taskSequence is moved to the next trial
else 
	incExitFcn = [ {@()resetRun(task)}; incExitFcn ]; % we randomise the run within this block to make it harder to guess next trial
end

%break entry
breakEntryFcn = {
	@()beep(aM,400,0.5,1);
	@()trackerMessage(eT,'END_RT');
	@()trackerMessage(eT,['TRIAL_RESULT ' str2double(tS.BREAKFIX)]);
	@()trackerClearScreen(eT);
	@()trackerDrawText(eT,'Broke maintain fix! :-(');
	@()needEyeSample(me,false);
	@()hide(stims);
	@()logRun(me,'BREAKFIX'); %fprintf current trial info
};

exclEntryFcn = {
	@()beep(aM,400,0.5,1);
	@()trackerMessage(eT,'END_RT');
	@()trackerMessage(eT,['TRIAL_RESULT ' str2double(tS.BREAKFIX)]);
	@()trackerClearScreen(eT);
	@()trackerDrawText(eT,'Exclusion Zone entered! :-(');
	@()needEyeSample(me,false);
	@()hide(stims);
	@()logRun(me,'EXCLUSION'); %fprintf current trial info
};

%====================================================EXPERIMENTAL CONTROL

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
'name'      'next'		'time'  'entryFcn'		'withinFcn'		'transitionFcn'	'exitFcn';
%---------------------------------------------------------------------------------------------
'pause'		'prefix'	inf		pauseEntryFcn	{}				{}				pauseExitFcn;
'prefix'	'UseTemp'	2		prefixEntryFcn	prefixFcn		{}				prefixExitFcn;
%---------------------------------------------------------------------------------------------
'fix1step'	'incorrect'	5	 	fixOSEntryFcn	fixOSFcn		inFixOSFcn		fixOSExitFcn;
'fix2step'	'incorrect'	5	 	fixTSEntryFcn	fixTSFcn		inFixTSFcn		fixTSExitFcn;
'onestep'	'incorrect'	5		osEntryFcn		osFcn			maintainFixFcn	sExitFcn;
'twostep'	'incorrect'	5		tsEntryFcn		tsFcn			maintainFixFcn	sExitFcn;
%---------------------------------------------------------------------------------------------
'incorrect'	'timeout'	0.5		incEntryFcn		incFcn			{}				incExitFcn;
'breakfix'	'timeout'	0.5		breakEntryFcn	incFcn			{}				incExitFcn;
'exclusion'	'timeout'	0.5		exclEntryFcn	incFcn			{}				incExitFcn;
'correct'	'prefix'	0.5		correctEntryFcn	correctFcn		{}				correctExitFcn;
'useTemp'	'prefix'	0.5		{}				{}				{}				{};
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

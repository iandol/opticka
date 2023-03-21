% SACCADE PHOSPHENE TASK: See Chen et al., 2020 From Methods:
% Prior to surgical implantation of the electrode arrays, the monkeys were
% trained on a saccade task, in which they reported the location of a visually
% presented dot on a grey screen (with a background luminance of 16.6 cd/m2)
% with an eye movement. This task consisted of %visual trials  and ‘catch
% trials,’ in equal proportion. During visual trials, the animal maintained
% fixation for 300 to 900 ms after fixation onset (uniform distribution). At the
% end of this interval, a circular visual target that varied in colour and had a
% diameter ranging from 0.2° to 0.6° appeared in the bottom-right quadrant of
% the screen, for 120-150 ms (uniform distribution). The animal had to make a
% saccade to the visual target within 250 ms of the onset of the visual target
% for a fluid reward. We used a large target window that spanned the lower right
% quadrant of the computer screen and a portion of the upper right and lower
% left quadrants to study the relation between the RF of stimulated neurons and
% the saccadic endpoint, preventing biases to visual field regions through the
% reward contingency. To calculate the saccadic end point, we calculated the eye
% velocity and determined the mean eye position in a time window when the eye
% was stationary (50-100 ms after the peak velocity). During catch trials, no
% visual target was presented, and the animal maintained fixation. On both
% visual trials and catch trials, reward delivery occurred at 1200 ms after
% fixation onset
%
% me		= runExperiment class object
% s			= screenManager class object
% aM		= audioManager class object
% stims		= our list of stimuli (metaStimulus class)
% sM		= State Machine (stateMachine class)
% task		= task sequence (taskSequence class)
% eT		= eyetracker manager
% io		= digital I/O to recording system
% rM		= Reward Manager (LabJack or Arduino TTL trigger to reward system/Magstim)
% bR		= behavioural record plot (on-screen GUI during a task run)
% tS		= structure to hold general variables, will be saved as part of the data
% uF		= user functions - add your own functions to this class

%=========================================================================
%----------------------General Settings----------------------------
tS.name						= 'saccade-to-phosphene';
% if 'training' then show the saccade target and don't stimuluate, if
% 'stimulate' then we hide the saccade target and stimulate:
tS.type						= 'training';
% which pin to use for stimulation
tS.stimPin					= 11;
% includeErrors: update the trial number for incorrect saccades: if true then we
% call updateTask for both correct and incorrect trials, otherwise we only call
% updateTask() for correct responses. 'false' is useful during training.
tS.includeErrors			= false; 
tS.useTask					= true;		%==use taskSequence (randomises stimulus variables)
tS.rewardTime				= 250;		%==TTL time in milliseconds
tS.rewardPin				= 2;		%==Output pin, 2 by default with Arduino.
tS.checkKeysDuringStimulus  = false;	%==allow keyboard control within stimulus state? Slight drop in performance…
tS.recordEyePosition		= false;	%==record local copy of eye position, **in addition** to the eyetracker?
tS.askForComments			= false;	%==UI requestor asks for comments before/after run
tS.saveData					= true;		%==save behavioural and eye movement data?
tS.showBehaviourPlot		= true;		%==open the behaviourPlot figure? Can cause more memory use
tS.nStims					= stims.n;	%==number of stimuli, taken from metaStimulus object
tS.tOut						= 5;		%==if wrong response, how long to time out before next trial
tS.CORRECT					= 1;		%==the code to send eyetracker for correct trials
tS.BREAKFIX					= -1;		%==the code to send eyetracker for break fix trials
tS.INCORRECT				= -5;		%==the code to send eyetracker for incorrect trials

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
% initial fixation X position in degrees (0° is screen centre)
tS.fixX						= 0;
% initial fixation Y position in degrees  (0° is screen centre)
tS.fixY						= 0;
% time to search and enter fixation window (Initiate fixation)
tS.firstFixInit				= 3;
% time to maintain initial fixation within window, can be single value or a
% range to randomise between
tS.firstFixTime				= [0.3 0.9];
% circular fixation window radius in degrees
tS.firstFixRadius			= 2;
% do we forbid eye to enter-exit-reenter fixation window?
tS.strict					= true;
% CATCH TRIAL TIME:
ts.catchTrialTime			= 1;
% visual target
tS.targetFixInit			= 0.5; % time to find the target
tS.targetFixTime			= 0.75; % to to maintain fixation on target 
tS.targetRadius				= [8 15]; %radius widthxheight to fix within.
% initial values for historical log of X / Y position and exclusion zone
me.lastXPosition			= tS.fixX;
me.lastYPosition			= tS.fixY;
me.lastXExclusion			= [];
me.lastYExclusion			= [];

%=========================================================================
%---------------------------Eyetracker setup-----------------------
% NOTE: the opticka GUI can set eyetracker options too; me.eyetracker.esettings
% and me.eyetracker.tsettings contain the GUI settings. We test if they are
% empty or not and set general values based on that...
eT.name				= tS.name;
if me.eyetracker.dummy;	eT.isDummy = true; end %===use dummy or real eyetracker? 
if tS.saveData;		eT.recordData = true; end %===save Eyetracker data?					
% Initialise the eyeTracker object with X, Y, FixInitTime, FixTime, Radius, StrictFix
updateFixationValues(eT, tS.fixX, tS.fixY, tS.firstFixInit, tS.firstFixTime, tS.firstFixRadius, tS.strict);
% Ensure we don't start with any exclusion zones etc. set up
resetAll(eT);

%=========================================================================
%----------------------ONLINE Behaviour Plot-----------------------
% WHICH states assigned as correct or break for online plot?
% You need to use regex patterns for the match (doc regexp).
bR.correctStateName				= "correct";
bR.breakStateName				= ["breakfix","incorrect"];

%=========================================================================
%--------------Randomise stimulus variables every trial?-----------
% If you want to have some randomisation of stimuls variables WITHOUT using
% taskSequence task. Remember this will not be "Saved" for later use, if you
% want to do controlled experiments use taskSequence to define proper randomised
% and balanced variable sets and triggers to send to recording equipment etc...
% Good for training tasks, or stimulus variability irrelevant to the task.
n								= 1;
in(n).name						= 'size';
in(n).values					= [0.4 0.6 0.8];
in(n).stimuli					= 1;
in(n).offset					= [];
n								= n + 1;
in(n).name						= 'colour';
in(n).values					= {[0.8 0.3 0.3],[0.3 0.8 0.3],[0.8 0.8 0.3],[0.3 0.3 0.8],[0.3 0.8 0.8]};
in(n).stimuli					= 1;
in(n).offset					= [];
stims.stimulusTable				= in;

%=========================================================================
%-------------allows using arrow keys to control variables?-------------
% another option is to enable manual control of a table of variables
% this is useful to probe RF properties or other features while still
% allowing for fixation or other behavioural control.
% Use arrow keys <- -> to control value and ↑ ↓ to control variable.
stims.controlTable			= [];
stims.tableChoice			= 1;

%=========================================================================
% this allows us to enable subsets from our stimulus list
% 1 = saccade target | 2 = anti-saccade target | 3 = fixation cross
stims.stimulusSets			= {2, [1 2]};
stims.setChoice				= 1;
hide(stims);

%=========================================================================
% N x 2 cell array of regexpi strings, list to skip the current -> next
% state's exit functions; for example skipExitStates =
% {'fixate','incorrect|breakfix'}; means that if the currentstate is
% 'fixate' and the next state is either incorrect OR breakfix, then skip
% the FIXATE exit state. Add multiple rows for skipping multiple state's
% exit states.
sM.skipExitStates			= {'fixate','incorrect|breakfix'};

%=========================================================================
% which stimulus in the list is used for a fixation target? For this
% protocol it means the subject must saccade this stimulus (the saccade
% target is #1 in the list) to get the reward. Also which stimulus to set an
% exclusion zone around (where a saccade into this area causes an immediate
% break fixation).
stims.fixationChoice		= 1;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%------------------------------------------------------------------------%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%=========================================================================
%------------------State Machine Task Functions---------------------
% Each cell {array} holds a set of anonymous function handles which are
% executed by the state machine to control the experiment. The state
% machine can run sets at entry ['entryFn'], during ['withinFn'], to
% trigger a transition jump to another state ['transitionFn'], and at exit
% ['exitFn'. Remember these {sets} need to access the objects that are
% available within the runExperiment context (see top of file). You can
% also add global variables/objects then use these. The values entered here
% are set on load, if you want up-to-date values then you need to use
% methods/function wrappers to retrieve/set them.
%=========================================================================

%==============================================================
%========================================================PAUSE
%==============================================================

%--------------------pause entry
pauseEntry = { 
	@()hide(stims);
	@()drawBackground(s); %blank the subject display
	@()drawTextNow(s,'PAUSED, press [p] to resume...');
	@()disp('PAUSED, press [p] to resume...');
	@()trackerClearScreen(eT);
	@()trackerDrawText(eT,'PAUSED, press [p] to resume');
	@()statusMessage(eT,'PAUSED');
	@()trackerMessage(eT,'TRIAL_RESULT -100'); %store message in EDF
	@()resetAll(eT); % reset all fixation markers to initial state
	@()setOffline(eT); % set eyelink offline [tobii ignores this]
	@()stopRecording(eT, true); %stop recording eye position data, true=both eyelink & tobii
	@()needFlip(me, false); % no need to flip the PTB screen
	@()needEyeSample(me,false); % no need to check eye position
};

%--------------------pause exit
pauseExit = {
	@()startRecording(eT, true); %start recording eye position data again
}; 

%==============================================================
%====================================================PRE-FIXATION
%==============================================================
pfEntry = { 
	@()needEyeSample(me,true); % make sure we start measuring eye position
	@()needFlip(me, true);
	@()needFlipTracker(me, 2); % eyetracker operator screen flip
	@()getStimulusPositions(stims,true); %make a struct the eT can use for drawing stim positions
	@()updateFixationValues(eT,tS.fixX,tS.fixY,tS.firstFixInit,tS.firstFixTime,tS.firstFixRadius,tS.strict); %reset fixation window
	@()resetFixationHistory(eT); % reset the recent eye position history
	@()resetExclusionZones(eT); % reset the exclusion zones on eyetracker
	@()trackerMessage(eT,'V_RT MESSAGE END_FIX END_RT');
	@()trackerMessage(eT,sprintf('TRIALID %i',getTaskIndex(me))); %Eyelink start trial marker
	@()startRecording(eT);
	@()trackerMessage(eT,['UUID ' UUID(sM)]); %add in the uuid of the current state for good measure
	% draw general state to the eyetracker display (eyelink or tobii)
	@()trackerClearScreen(eT);
	@()trackerDrawText(eT,'Pre-fixation');
};

pfWithin = {
	@()drawPhotoDiode(s,[0 0 0]);
};

pfExit = {
	
};

%==============================================================
%====================================================FIXATION
%==============================================================
%--------------------fixate entry
fixEntry = { 
	% show stimulus 3 = fixation cross
	@()show(stims, 2);
	@()trackerDrawStatus(eT,'Fixation...');
	@()statusMessage(eT,'FIXATE');
	@()logRun(me,'INITFIX'); %fprintf current trial info to command window
	@()updateNextState(me,'trial'); %use taskSequence.trialVar for the next state
};

%--------------------fix within
fixWithin = {
	@()draw(stims); %draw stimulus
	@()drawPhotoDiode(s,[0 0 0]);
};

%--------------------test we are fixated for a certain length of time
initFix = { 
	% this command performs the logic to search and then maintain fixation
	% inside the fixation window. The eyetracker parameters are defined above.
	% If the subject does initiate and then maintain fixation, then sM.tempNextState
	% is returned and the state machine will jump to that state,
	% otherwise 'incorrect' is returned and the state machine will jump there. 
	% sM.tempNextState is set using @()updateNextState(me,'trial') above.
	% If neither condition matches, then the state table below
	% defines that after 5 seconds we will switch to the incorrect state.
	@()testSearchHoldFixation(eT, sM.tempNextState, 'incorrect')
};

fixExit = { };

%==============================================================
%====================================================CATCH TRIAL
%==============================================================
% what to run when we enter the stim presentation state
catchEntry = {
	@()updateFixationValues(eT,[],[],[],ts.catchTrialTime); %reset fixation window
	@()trackerClearScreen(eT);
	@()trackerDrawFixation(eT);
	@()doStrobe(me,true);
	@()statusMessage(eT,'CATCH TRIAL');
};

% what to run when we are showing stimuli
catchWithin = { 
	@()draw(stims);
	@()drawPhotoDiode(s, [1 1 1]);
};

% test we are finding the new target (stimulus 1, the saccade target)
catchFix = {
	@()testHoldFixation(eT,'correct','breakfix'); % tests finding and maintaining fixation
};

%as we exit catch trial
catchExit = { 
	@()setStrobeValue(me,255); 
	@()doStrobe(me,true);
};

%==============================================================
%====================================================TARGET STIMULUS ALONE
%==============================================================
% what to run when we enter the stim presentation state
stimEntry = {
	% use our saccade target stimulus for next fix X and Y, see
	% stims.fixationChoice above
	@()updateFixationTarget(me, tS.useTask, tS.targetFixInit, tS.targetFixTime, tS.targetRadius);
	@()trackerClearScreen(eT);
	@()trackerDrawFixation(eT);
	@()statusMessage(eT,'SACCADE');
	@()doStrobe(me, true);
};
if matches(tS.type,'training')
	stimEntry = [ {@()show(stims)}; stimEntry ]; % make sure our taskSequence is moved to the next trial
else
	stimEntry = [ {@()timedTTL(rM,tS.stimPin,2)}; stimEntry ]; % we randomise the run within this block to make it harder to guess next trial
end

% what to run when we are showing stimuli
stimWithin = { 
	@()draw(stims);
	@()drawPhotoDiode(s,[1 1 1]);
};

% test we are finding the new target (stimulus 1, the saccade target)
targetFix = {
	@()testSearchHoldFixation(eT,'correct','breakfix'); % tests finding and maintaining fixation
};

%as we exit stim presentation state
stimExit = { 
	@()setStrobeValue(me,255); 
	@()doStrobe(me,true);
};

%==============================================================
%====================================================DECISION
%==============================================================

%====================================================CORRECT
%if the subject is correct (small reward)
correctEntry = { 
	@()timedTTL(rM, tS.rewardPin, tS.rewardTime); % send a reward TTL
	@()beep(aM, 2000, 0.1, 0.1); % correct beep
	@()trackerMessage(eT,'END_RT'); %send END_RT message to tracker
	@()trackerMessage(eT,sprintf('TRIAL_RESULT %i',tS.CORRECT)); %send TRIAL_RESULT message to tracker
	@()trackerDrawStatus(eT,'Correct! :-)',[]);
	@()statusMessage(eT,'CORRECT');
	@()needFlipTracker(me, 0); % eyetracker operator screen flip
	@()stopRecording(eT); % stop recording in eyelink [tobii ignores this]
	@()setOffline(eT); % set eyelink offline [tobii ignores this]
	@()needEyeSample(me,false); % no need to collect eye data until we start the next trial
	@()hide(stims); % hide all stims
	@()logRun(me,'CORRECT'); % print current trial info
};

%correct stimulus
correctWithin = { };

%when we exit the correct state
correctExit = {
	@()updatePlot(bR, me); %update our behavioural plot, must come before updateTask() / updateVariables()
	@()updateTask(me,tS.CORRECT); %make sure our taskSequence is moved to the next trial
	@()updateVariables(me); %update independent variables, and set strobe value too
	@()randomise(stims); %this uses metaStimulus.stimulusTable for stim changes 
	@()update(stims); %update the stimuli ready for display
	@()resetExclusionZones(eT); %reset the exclusion zones
	@()checkTaskEnded(me); %check if task is finished
	@()plot(bR, 1); % actually do our behaviour record drawing
};

%========================================================INCORRECT
%--------------------incorrect entry
incEntry = {
	@()beep(aM,400,0.5,1);
	@()trackerMessage(eT,'END_RT');
	@()trackerMessage(eT,sprintf('TRIAL_RESULT %i',tS.INCORRECT));
	@()trackerDrawStatus(eT,'INCORRECT! :-(');
	@()statusMessage(eT,'INCORRECT');
	@()needFlipTracker(me, 0); % eyetracker operator screen flip
	@()stopRecording(eT); % stop recording in eyelink [tobii ignores this]
	@()setOffline(eT); % set eyelink offline [tobii ignores this]
	@()needEyeSample(me,false);
	@()hide(stims);
	@()logRun(me,'INCORRECT'); %fprintf current trial info
};

%our incorrect stimulus
incWithin = { };

%incorrect / break exit
incExit = {
	@()updatePlot(bR, me); %update our behavioural plot, must come before updateTask() / updateVariables()
	@()updateVariables(me); %randomise our stimuli, set strobe value too
	@()randomise(stims); %this uses metaStimulus.stimulusTable for stim changes 
	@()update(stims); %update our stimuli ready for display
	@()resetExclusionZones(eT); %reset the exclusion zones
	@()checkTaskEnded(me); %check if task is finished
	@()plot(bR, 1); % actually do our drawing
};
if tS.includeErrors
	incExit = [ {@()updateTask(me,tS.BREAKFIX)}; incExit ]; % make sure our taskSequence is moved to the next trial
else
	incExit = [ {@()resetRun(task)}; incExit ]; % we randomise the run within this block to make it harder to guess next trial
end

%break entry
breakEntry = {
	@()beep(aM, 400, 0.5, 1);
	@()trackerMessage(eT,'END_RT');
	@()trackerMessage(eT,sprintf('TRIAL_RESULT %i',tS.BREAKFIX));
	@()trackerDrawStatus(eT,'Fail to Saccade to Target! :-(');
	@()statusMessage(eT,'BREAKFIX');
	@()needFlipTracker(me, 0); % eyetracker operator screen flip
	@()needEyeSample(me,false);
	@()stopRecording(eT); % stop recording in eyelink [tobii ignores this]
	@()setOffline(eT); % set eyelink offline [tobii ignores this]
	@()hide(stims);
	@()logRun(me,'BREAKFIX'); %fprintf current trial info
};

exclEntry = {
	@()beep(aM, 400, 0.5, 1);
	@()trackerMessage(eT,'END_RT');
	@()trackerMessage(eT,['TRIAL_RESULT ' str2double(tS.BREAKFIX)]);
	@()trackerDrawStatus(eT,'Exclusion Zone entered! :-(', [],true);
	@()statusMessage(eT,'EXCLUSION');
	@()needEyeSample(me,false);
	@()stopRecording(eT); % stop recording in eyelink [tobii ignores this]
	@()setOffline(eT); % set eyelink offline [tobii ignores this]
	@()hide(stims);
	@()logRun(me,'EXCLUSION'); %fprintf current trial info
};

%==============================================================
%========================================================EYETRACKER
%==============================================================

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
offsetFcn = {
	@()drawBackground(s); %blank the display
	@()stopRecording(eT); % stop recording in eyelink [tobii ignores this]
	@()setOffline(eT); % set eyelink offline [tobii ignores this]
	@()driftOffset(eT) % enter drift offset (works on tobii & eyelink)
};

%==============================================================
%========================================================GENERAL
%==============================================================

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
'pause'		'prefix'	inf		pauseEntry		{}				{}				pauseExit;
'prefix'	'fixate'	0.5		pfEntry			pfWithin		{}				pfExit;
'fixate'	'incorrect'	5		fixEntry		fixWithin		initFix			fixExit;
'catchtrial' 'incorrect' 5		catchEntry		catchWithin		catchFix		catchExit
'stimulus'	'incorrect'	5		stimEntry		stimWithin		targetFix		stimExit;
'correct'	'prefix'	0.25	correctEntry	correctWithin	{}				correctExit;
'incorrect'	'timeout'	0.25	incEntry		incWithin		{}				incExit;
'breakfix'	'timeout'	0.25	breakEntry		incWithin		{}				incExit;
'exclusion'	'timeout'	0.25	exclEntry		incWithin		{}				incExit;
'timeout'	'prefix'	tS.tOut	{}				{}				{}				{};
%---------------------------------------------------------------------------------------------
'calibrate'	'pause'		0.5		calibrateFn		{}				{}				{};
'drift'		'pause'		0.5		driftFn			{}				{}				{};
'offset'	'pause'		0.5		offsetFcn		{}				{}				{};
%---------------------------------------------------------------------------------------------
'override'	'pause'		0.5		overrideFn		{}				{}				{};
'flash'		'pause'		0.5		flashFn			{}				{}				{};
'showgrid'	'pause'		10		{}				gridFn			{}				{};
};
%-------------------------State Machine Table------------------------------
%==========================================================================

disp('================>> Building state info file <<================')
disp(stateInfoTmp)
disp('=================>> Loaded state info file <<=================')

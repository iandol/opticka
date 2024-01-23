%> DEFAULT state configuration file for runExperiment.runTask (full
%> behavioural task design). This state file has a [prefix] state (a blank before
%> fixation starts), then a [fixate] state for the subject to initiate fixation.
%> If the subject fails initial fixation, an [breakfix] state is called. If the
%> subject fails fixation DURING [stimulus] presentation, a [incorrect] state is
%> called. It assumes there are TWO stimuli in the stims object, the first
%> (stims{1}) is any type of visual stimulus and the second is a fixation cross
%> (stims{2}). For this task most state transitions are deterministic, but for
%> [fixate] there is a transitionFcn that checks if the subject initiates fixation
%> [inFixFcn], and for [stimulus] there is a check if the subject maintains
%> fixation for an additional time [maintainFixFcn].
%>
%>                                                       ┌───────────────────┐
%>                                                       │      prefix       │
%>  ┌──────────────────────────────────────────────────▶ │    hide(stims)    │ ◀┐
%>  │                                                    └───────────────────┘  │
%>  │                                                      │                    │
%>  │                                                      ▼                    │
%>  │                         ┌───────────┐  inFixFcn:   ┌───────────────────┐  │
%>  │                         │ breakfix  │  breakfix   │      fixate       │  │
%>  │                         │           │ ◀─────────── │   show(stims,2)   │  │
%>  │                         └───────────┘              └───────────────────┘  │
%>  │                           │                          │ inFixFcn:          │
%>  │ reward!                   │                          │ stimulus           │
%>  │                           │                          ▼                    │
%>┌─────────┐  maintainFixFcn:  │                        ┌───────────────────┐  │
%>│ correct │  correct          │                        │     stimulus      │  │
%>│         │ ◀─────────────────┼─────────────────────── │ show(stims,[1 2]) │  │
%>└─────────┘                   │                        └───────────────────┘  │
%>                              │                          │ maintainFixFcn:    │
%>                              │                          │ incorrect          │
%>                              │                          ▼                    │
%>                              │                        ┌───────────────────┐  │
%>                              │                        │     incorrect     │  │
%>                              │                        └───────────────────┘  │
%>                              │                          │                    │
%>                              │                          ▼                    │
%>                              │                        ┌───────────────────┐  │
%>                              │                        │      timeout      │  │
%>                              └──────────────────────▶ │      tS.tOut      │ ─┘
%>                                                       └───────────────────┘
%>
%> This state control file will usually be run in the scope of the calling
%> runExperiment.runTask() method and other objects will be available at run time
%> (with easy to use names listed below). The following class objects are already
%> loaded by runTask() and available to use; each object has methods (functions)
%> useful for running the task:
%>
%> me		= runExperiment object ('self' in OOP terminology) 
%> s		= screenManager object
%> aM		= audioManager object
%> stims	= our list of stimuli (metaStimulus class)
%> sM		= State Machine (stateMachine class)
%> task		= task sequence (taskSequence class)
%> eT		= eyetracker manager
%> io		= digital I/O to recording system
%> rM		= Reward Manager (LabJack or Arduino TTL trigger to reward system/Magstim)
%> bR		= behavioural record plot (on-screen GUI during a task run)
%> uF       = user functions - add your own functions to this class
%> tS		= structure to hold general variables, will be saved as part of the data

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
rM.reward.time				= 250;		%==TTL time in milliseconds
rM.reward.pin				= 2;		%==Output pin, 2 by default with Arduino.
tS.keyExclusionPattern		= ["fixate","stimulus"]; %==which states to skip keyboard checking
tS.enableTrainingKeys		= false;	%==enable keys useful during task training, but not for data recording
tS.recordEyePosition		= false;	%==record local copy of eye position, **in addition** to the eyetracker?
tS.askForComments			= false;	%==UI requestor asks for comments before/after run
tS.saveData					= false;	%==save behavioural and eye movement data?
tS.showBehaviourPlot		= true;		%==open the behaviourPlot figure? Can cause more memory use…
tS.includeErrors			= false;	%==do we update the trial number even for incorrect saccade/fixate, if true then we call updateTask for both correct and incorrect, otherwise we only call updateTask() for correct responses
tS.name						= 'default protocol'; %==name of this protocol
tS.nStims					= stims.n;	%==number of stimuli, taken from metaStimulus object
tS.tOut						= 2;		%==if wrong response, how long to time out before next trial
tS.CORRECT					= 1;		%==the code to send eyetracker for correct trials
tS.BREAKFIX					= -1;		%==the code to send eyetracker for break fix trials
tS.INCORRECT				= -5;		%==the code to send eyetracker for incorrect trials
tS.correctSound				= [2000, 0.1, 0.1]; %==freq,length,volume
tS.errorSound				= [300, 1, 1];		%==freq,length,volume


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
% initial fixation X position in degrees (0° is screen centre). Multiple windows
% can be entered using an array.
tS.fixX						= 0;
% initial fixation Y position in degrees  (0° is screen centre). Multiple windows
% can be entered using an array.
tS.fixY						= 0;
% time to search and enter fixation window (Initiate fixation)
tS.firstFixInit				= 3;
% time to maintain initial fixation within window, can be single value or a
% range to randomise between
tS.firstFixTime				= [0.25 0.75];
% fixation window radius in degrees; if you enter [x y] the window will be
% rectangular.
tS.firstFixRadius			= 2;
% do we forbid eye to enter-exit-reenter fixation window?
tS.strict					= true;
% add an exclusion zone where subject cannot saccade to?
tS.exclusionZone			= [];
% time to maintain fixation during stimulus state
tS.stimulusFixTime			= 1;		
% Initialise eyetracker with X, Y, FixInitTime, FixTime, Radius, StrictFix values
updateFixationValues(eT, tS.fixX, tS.fixY, tS.firstFixInit, tS.firstFixTime, tS.firstFixRadius, tS.strict);

%=========================================================================
%-------------------------ONLINE Behaviour Plot---------------------------
% WHICH states assigned as correct or break for online plot?
bR.correctStateName			= "correct";
bR.breakStateName			= ["breakfix","incorrect"];

%=========================================================================
%--------------Randomise stimulus variables every trial?-----------
% If you want to have some randomisation of stimuls variables WITHOUT using
% taskSequence task. Remember this will not be "Saved" for later use, if you
% want to do controlled experiments use taskSequence to define proper randomised
% and balanced variable sets and triggers to send to recording equipment etc...
% Good for training tasks, or stimulus variability irrelevant to the task.
% n							= 1;
% in(n).name				= 'xyPosition';
% in(n).values				= [6 6; 6 -6; -6 6; -6 -6; -6 0; 6 0];
% in(n).stimuli				= 1;
% in(n).offset				= [];
% stims.stimulusTable		= in;
stims.choice				= [];
stims.stimulusTable			= [];

%=========================================================================
%-------------allows using arrow keys to control variables?-------------
% another option is to enable manual control of a table of variables
% this is useful to probe RF properties or other features while still
% allowing for fixation or other behavioural control.
% Use arrow keys <- -> to control value and ↑ ↓ to control variable.
stims.controlTable			= [];
stims.tableChoice			= 1;

%======================================================================
% this allows us to enable subsets from our stimulus list
% 1 = grating | 2 = fixation cross
stims.stimulusSets			= {[1,2],[1]};
stims.setChoice				= 1;

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
	@()hide(stims); % hide all stimuli
	@()drawBackground(s); % blank the subject display
	@()drawPhotoDiodeSquare(s,[0 0 0]); % draw black photodiode
	@()drawTextNow(s,'PAUSED, press [p] to resume...');
	@()disp('PAUSED, press [p] to resume...');
	@()trackerDrawStatus(eT,'PAUSED, press [p] to resume', stims.stimulusPositions);
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
	% update the fixation window to initial values
	@()updateFixationValues(eT,tS.fixX,tS.fixY,[],tS.firstFixTime); %reset fixation window
	@()startRecording(eT); % start eyelink recording for this trial (tobii ignores this)
	% tracker messages that define a trial start
	% you can add any other messages, such as stimulus values as needed,
	% e.g. @()trackerMessage(eT,['MSG:ANGLE' num2str(stims{1}.angleOut)]) etc.
	@()trackerMessage(eT,'V_RT MESSAGE END_FIX END_RT'); % Eyelink commands
	@()trackerMessage(eT,sprintf('TRIALID %i',getTaskIndex(me))); %Eyelink start trial marker
	@()trackerMessage(eT,['UUID ' UUID(sM)]); %add in the uuid of the current state for good measure
};

%--------------------prefixate within
prefixFcn = {
	@()drawPhotoDiodeSquare(s,[0 0 0]);
};

%--------------------prefixate exit
prefixExitFcn = {
	@()trackerDrawStatus(eT,'Start trial...', stims.stimulusPositions);
};

%==============================================================
%====================================================FIXATION
%==============================================================
%--------------------fixate entry
fixEntryFcn = { 
	@()show(stims{tS.nStims});
	@()logRun(me,'INITFIX');
};

%--------------------fix within
fixFcn = {
	@()draw(stims); %draw stimuli
	@()drawPhotoDiodeSquare(s,[0 0 0]);
};

%--------------------test we are fixated for a certain length of time
inFixFcn = {
	% this command performs the logic to search and then maintain fixation
	% inside the fixation window. The eyetracker parameters are defined above.
	% If the subject does initiate and then maintain fixation, then 'correct'
	% is returned and the state machine will jump to the correct state,
	% otherwise 'breakfix' is returned and the state machine will jump to the
	% breakfix state. If neither condition matches, then the state table below
	% defines that after 5 seconds we will switch to the incorrect state.
	@()testSearchHoldFixation(eT,'stimulus','breakfix')
};

%--------------------exit fixation phase
fixExitFcn = { 
	@()updateFixationValues(eT,[],[],[],tS.stimulusFixTime); 
	@()show(stims); % show all stims
	@()trackerMessage(eT,'END_FIX'); %eyetracker message saved to data stream
}; 

%========================================================
%========================================================STIMULUS
%========================================================

stimEntryFcn = {
	% send stimulus value strobe (value set by updateVariables(me) function)
	@()doStrobe(me,true);
};

%--------------------what to run when we are showing stimuli
stimFcn =  {
	@()draw(stims);
	@()drawPhotoDiodeSquare(s,[1 1 1]);
	@()animate(stims); % animate stimuli for subsequent draw
};

%-----------------------test we are maintaining fixation
maintainFixFcn = {
	% this command performs the logic to search and then maintain fixation
	% inside the fixation window. The eyetracker parameters are defined above.
	% If the subject does initiate and then maintain fixation, then 'correct'
	% is returned and the state machine will jump to the correct state,
	% otherwise 'breakfix' is returned and the state machine will jump to the
	% breakfix state. If neither condition matches, then the state table below
	% defines that after 5 seconds we will switch to the incorrect state.
	@()testHoldFixation(eT,'correct','incorrect'); 
};

%as we exit stim presentation state
stimExitFcn = {
	@()setStrobeValue(me, 255); % 255 indicates stimulus OFF
	@()doStrobe(me, true);
};

%========================================================
%========================================================DECISIONS
%========================================================

%========================================================CORRECT
%--------------------if the subject is correct (small reward)
correctEntryFcn = {
	@()trackerMessage(eT,'END_RT'); %send END_RT message to tracker
	@()trackerMessage(eT,sprintf('TRIAL_RESULT %i',tS.CORRECT)); %send TRIAL_RESULT message to tracker
	@()stopRecording(eT); % stop recording in eyelink [tobii ignores this]
	@()setOffline(eT); % set eyelink offline [tobii ignores this]
	@()needEyeSample(me,false); % no need to collect eye data until we start the next trial
	@()hide(stims); % hide all stims
};

%--------------------correct stimulus
correctFcn = {
	@()drawPhotoDiodeSquare(s,[0 0 0]);
};

%--------------------when we exit the correct state
correctExitFcn = {
	@()giveReward(rM); % send a reward
	@()beep(aM, tS.correctSound); % correct beep
	@()logRun(me,'CORRECT'); % print current trial info
	@()trackerDrawStatus(eT, 'CORRECT! :-)');
	@()needFlipTracker(me, 0); %for operator screen stop flip
	@()updatePlot(bR, me); % must run before updateTask
	@()updateTask(me,tS.CORRECT); % make sure our taskSequence is moved to the next trial
	@()updateVariables(me); % randomise our stimuli, and set strobe value too
	@()update(stims); % update our stimuli ready for display
	@()getStimulusPositions(stims); % make a struct the eT can use for drawing stim positions
	@()resetAll(eT); % resets the fixation state timers	
	@()plot(bR, 1); % actually do our behaviour record drawing
};

%========================================================INCORRECT/BREAKFIX
%--------------------incorrect entry
incEntryFcn = {
	@()trackerMessage(eT,'END_RT');
	@()trackerMessage(eT,sprintf('TRIAL_RESULT %i',tS.INCORRECT));
	@()stopRecording(eT); % stop recording in eyelink [tobii ignores this]
	@()setOffline(eT); % set eyelink offline [tobii ignores this]
	@()needEyeSample(me,false);
	@()hide(stims);
};
%--------------------break entry
breakEntryFcn = {
	@()trackerMessage(eT,'END_RT');
	@()trackerMessage(eT,sprintf('TRIAL_RESULT %i',tS.BREAKFIX));
	@()stopRecording(eT);
	@()setOffline(eT); % set eyelink offline [tobii ignores this]
	@()needEyeSample(me,false);
	@()hide(stims);
};

%--------------------our incorrect/breakfix stimulus
incFcn = {
	@()drawPhotoDiodeSquare(s,[0 0 0]);
};

%--------------------incorrect exit
incExitFcn = {
	@()beep(aM, tS.errorSound);
	@()logRun(me,'INCORRECT'); %fprintf current trial info
	@()trackerDrawStatus(eT,'INCORRECT! :-(', stims.stimulusPositions, 0);
	@()needFlipTracker(me, 0); %for operator screen stop flip
	@()updateVariables(me); % randomise our stimuli, set strobe value too
	@()update(stims); % update our stimuli ready for display
	@()getStimulusPositions(stims); % make a struct the eT can use for drawing stim positions
	@()resetAll(eT); % resets the fixation state timers
	@()plot(bR, 1); % actually do our drawing
};
%--------------------break exit
breakExitFcn = {
	@()beep(aM, tS.errorSound);
	@()logRun(me,'BREAK_FIX'); %fprintf current trial info
	@()trackerDrawStatus(eT,'BREAK_FIX! :-(', stims.stimulusPositions, 0);
	@()needFlipTracker(me, 0); %for operator screen stop flip
	@()updateVariables(me); % randomise our stimuli, set strobe value too
	@()update(stims); % update our stimuli ready for display
	@()getStimulusPositions(stims); % make a struct the eT can use for drawing stim positions
	@()resetAll(eT); % resets the fixation state timers
	@()plot(bR, 1); % actually do our drawing
};

%--------------------change functions based on tS settings
% this shows an example of how to use tS options to change the function
% lists run by the state machine. We can prepend or append new functions to
% the cell arrays.
% updateTask = updates task object
% resetRun = randomise current trial within the block
% checkTaskEnded = see if taskSequence has finished
if tS.includeErrors % we want to update our task even if there were errors
	incExitFcn = [ {@()updatePlot(bR, me); @()updateTask(me,tS.INCORRECT)}; incExitFcn ]; %update our taskSequence 
	breakExitFcn = [ {@()updatePlot(bR, me); @()updateTask(me,tS.BREAKFIX)}; breakExitFcn ]; %update our taskSequence 
else
	incExitFcn = [ {@()updatePlot(bR, me); @()resetRun(task)}; incExitFcn ]; 
	breakExitFcn = [ {@()updatePlot(bR, me); @()resetRun(task)}; breakExitFcn ];
end
if tS.useTask || task.nBlocks > 0
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
'prefix'	'fixate'	0.75	prefixEntryFcn	prefixFcn		{}				{};
'fixate'	'incorrect'	10		fixEntryFcn		fixFcn			inFixFcn		fixExitFcn;
'stimulus'	'incorrect'	10		stimEntryFcn	stimFcn			maintainFixFcn	stimExitFcn;
'correct'	'prefix'	0.1		correctEntryFcn	correctFcn		{}				correctExitFcn;
'incorrect'	'timeout'	0.1		incEntryFcn		incFcn			{}				incExitFcn;
'breakfix'	'timeout'	0.1		breakEntryFcn	incFcn			{}				breakExitFcn;
'timeout'	'prefix'	tS.tOut	{}				incFcn			{}				{};
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

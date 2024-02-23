%> BACK-PROPAGATION -- fast full-screen receptive field mapping for many
%> channels.

%==================================================================
%------------------------General Settings--------------------------
% These settings are make changing the behaviour of the protocol easier. tS
% is just a struct(), so you can add your own switches or values here and
% use them lower down. Some basic switches like saveData, useTask,
% checkKeysDuringstimulus will influence the runeExperiment.runTask()
% functionality, not just the state machine. Other switches like
% includeErrors are referenced in this state machine file to change with
% functions are added to the state machine states…
tS.name						= 'Back-Propagation'; %==name of this protocol
tS.useTask					= true;		%==use taskSequence (randomises stimulus variables)
tS.rewardTime				= 250;		%==TTL time in milliseconds
tS.rewardPin				= 2;		%==Output pin, 2 by default with Arduino.
tS.keyExclusionPattern		= ["fixate","stimulus"]; %==which states to skip keyboard checking
tS.enableTrainingKeys		= false;		%==enable keys useful during task training, but not for data recording
tS.recordEyePosition		= false;	%==record local copy of eye position, **in addition** to the eyetracker?
tS.askForComments			= true;		%==UI requestor asks for comments before/after run
tS.saveData					= true;		%==save behavioural and eye movement data?
tS.showBehaviourPlot		= true;		%==open the behaviourPlot figure? Can cause more memory use…
tS.includeErrors			= false;	%==do we update the trial number even for incorrect saccade/fixate, if true then we call updateTask for both correct and incorrect, otherwise we only call updateTask() for correct responses
tS.nStims					= stims.n;	%==number of stimuli, taken from metaStimulus object
tS.tOut						= 4;		%==if wrong response, how long to time out before next trial
tS.CORRECT					= 1;		%==the code to send eyetracker for correct trials
tS.BREAKFIX					= -1;		%==the code to send eyetracker for break fix trials
tS.INCORRECT				= -5;		%==the code to send eyetracker for incorrect trials
tS.correctSound				= [2000, 0.1, 0.1]; %==freq,length,volume
tS.errorSound				= [300, 1, 1];		%==freq,length,volume

%=================================================================
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
tS.firstFixTime				= 0.25;
% circular fixation window radius in degrees
tS.firstFixRadius			= 2;
% do we forbid eye to enter-exit-reenter fixation window?
tS.strict					= true;
% do we add an exclusion zone where subject cannot saccade to...
tS.exclusionZone			= [];
% time to fix on the stimulus
tS.stimulusFixTime			= 4;
%Initialise the eyeTracker object with X, Y, FixInitTime, FixTime, Radius, StrictFix
updateFixationValues(eT, tS.fixX, tS.fixY, tS.firstFixInit, tS.firstFixTime, tS.firstFixRadius, tS.strict);
%Ensure we don't start with any exclusion zones set up
resetAll(eT);

%==================================================================
%----WHICH states assigned as correct or break for online plot?----
%----You need to use regex patterns for the match (doc regexp)-----
bR.correctStateName				= "correct";
bR.breakStateName				= ["breakfix","incorrect"];

%==================================================================
%--------------randomise stimulus variables every trial?-----------
% if you want to have some randomisation of stimuls variables without using
% taskSequence task (i.e. general training tasks), you can uncomment this
% and runExperiment can use this structure to change e.g. X or Y position,
% size, angle see metaStimulus for more details. Remember this will not be
% "Saved" for later use, if you want to do controlled methods of constants
% experiments use taskSequence to define proper randomised and balanced
% variable sets and triggers to send to recording equipment etc...
%
% stims.choice					= [];
% n								= 1;
% in(n).name					= 'xyPosition';
% in(n).values					= [6 6; 6 -6; -6 6; -6 -6; -6 0; 6 0];
% in(n).stimuli					= 1;
% in(n).offset					= [];
% stims.stimulusTable			= in;
stims.choice					= [];
stims.stimulusTable				= [];

%=======================================================================
%-------------allows using arrow keys to control variables?-------------
% another option is to enable manual control of a table of variables
% this is useful to probe RF properties or other features while still
% allowing for fixation or other behavioural control.
% Use arrow keys <- -> to control value and ↑ ↓ to control variable.
stims.controlTable			= [];
stims.tableChoice			= 1;

%======================================================================
%this allows us to enable subsets from our stimulus list
% 1 = grating | 2 = fixation cross
stims.stimulusSets				= {[1,2],[1]};
stims.setChoice					= 1;
hide(stims);

%======================================================================
% N x 2 cell array of regexpi strings, list to skip the current -> next
% state's exit functions; for example skipExitStates =
% {'fixate','incorrect|breakfix'}; means that if the currentstate is
% 'fixate' and the next state is either incorrect OR breakfix, then skip
% the FIXATE exit state. Add multiple rows for skipping multiple state's
% exit states.
sM.skipExitStates			= {'fixate','incorrect|breakfix'};

%===================================================================
%===================================================================
%===================================================================
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
%===================================================================
%===================================================================
%===================================================================

%========================================================
%========================================================PAUSE
%========================================================

%--------------------pause entry
pauseEntryFn = {
	@()hide(stims);
	@()drawBackground(s); %blank the subject display
	@()drawPhotoDiodeSquare(s,[0 0 0]); %draw black photodiode
	@()drawTextNow(s,'PAUSED, press [p] to resume...');
	@()disp('PAUSED, press [p] to resume...');
	@()trackerDrawStatus(eT,'PAUSED, press [p] to resume', stims.stimulusPositions);
	@()trackerMessage(eT,'TRIAL_RESULT -100'); %store message in EDF
	@()resetAll(eT); % reset all fixation markers to initial state
	@()setOffline(eT); % set eyelink offline [tobii ignores this]
	@()stopRecording(eT, true); %stop recording eye position data, true=both eyelink & tobii
	@()needFlip(me, false); % no need to flip the PTB screen
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

%========================================================
%========================================================PREFIXATE
%========================================================
%--------------------prefixate entry
prefixEntryFn = { 
	@()needFlip(me, true, 1); 
	@()needEyeSample(me, true); % make sure we start measuring eye position
	@()hide(stims); % hide all stimuli
	% update the fixation window to initial values
	@()updateFixationValues(eT,tS.fixX,tS.fixY,[],tS.firstFixTime); %reset fixation window
	% send the trial start messages to the eyetracker
	@()trackerTrialStart(eT, getTaskIndex(me));
	@()trackerMessage(eT,['UUID ' UUID(sM)]); %add in the uuid of the current state for good measure
	% you can add any other messages, such as stimulus values as needed,
	% e.g. @()trackerMessage(eT,['MSG:ANGLE' num2str(stims{1}.angleOut)])
	% draw to the eyetracker display
};

%--------------------prefixate within
prefixFn = {
	@()drawPhotoDiodeSquare(s,[0 0 0]);
};

prefixExitFn = {
	@()trackerMessage(eT,'MSG:Start Fix');
	@()trackerDrawStatus(eT, 'Init Fix...', stims.stimulusPositions, 0);
};

%========================================================
%========================================================FIXATE
%========================================================
%--------------------fixate entry
fixEntryFn = { 
	@()show(stims{tS.nStims});
	@()logRun(me,'INITFIX');
};

%--------------------fix within
fixFn = {
	@()draw(stims); %draw stimuli
	@()drawPhotoDiodeSquare(s,[0 0 0]);
};

%--------------------test we are fixated for a certain length of time
inFixFn = {
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
fixExitFn = { 
	% reset fixation timers to maintain fixation for tS.stimulusFixTime seconds
	@()updateFixationValues(eT,[],[],[],tS.stimulusFixTime); 
	@()show(stims); % show all stims
	@()trackerMessage(eT,'END_FIX'); %eyetracker message saved to data stream
}; 

%========================================================
%========================================================STIMULUS
%========================================================

stimEntryFn = {
	% send an eyeTracker sync message (reset relative time to 0 after next flip)
	@()doSyncTime(me);
	% send stimulus value strobe (value alreadyset by updateVariables(me) function)
	@()doStrobe(me,true);
};

%--------------------what to run when we are showing stimuli
stimFn =  {
	@()draw(stims);
	@()drawPhotoDiodeSquare(s,[1 1 1]);
	@()animate(stims); % animate stimuli for subsequent draw
};

%-----------------------test we are maintaining fixation
maintainFixFn = {
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
stimExitFn = {
	@()setStrobeValue(me, 255); % 255 indicates stimulus OFF
	@()doStrobe(me, true);
};

%========================================================
%========================================================DECISIONS
%========================================================

%========================================================CORRECT
%--------------------if the subject is correct (small reward)
correctEntryFn = {
	@()trackerMessage(eT,'END_RT'); %send END_RT message to tracker
	@()trackerMessage(eT,sprintf('TRIAL_RESULT %i',tS.CORRECT)); %send TRIAL_RESULT message to tracker
	@()stopRecording(eT); % stop recording in eyelink [tobii ignores this]
	@()setOffline(eT); % set eyelink offline [tobii ignores this]
	@()needEyeSample(me,false); % no need to collect eye data until we start the next trial
	@()hide(stims); % hide all stims
	@()logRun(me,'CORRECT'); % print current trial info
};

%--------------------correct stimulus
correctFn = {
	@()drawPhotoDiodeSquare(s,[0 0 0]);
};

%--------------------when we exit the correct state
correctExitFn = {
	@()giveReward(rM); % send a reward TTL
	@()beep(aM, tS.correctSound); % correct beep
	@()trackerDrawStatus(eT, 'CORRECT! :-)');
	@()updatePlot(bR, me);
	@()updateTask(me,tS.CORRECT); %make sure our taskSequence is moved to the next trial
	@()updateVariables(me); %randomise our stimuli, and set strobe value too
	@()update(stims); %update our stimuli ready for display
	@()getStimulusPositions(stims); %make a struct the eT can use for drawing stim positions
	@()resetAll(eT); %resets the fixation state timers	
	@()plot(bR, 1); % actually do our behaviour record drawing
};

%========================================================INCORRECT
%--------------------incorrect entry
incEntryFn = { 
	@()trackerMessage(eT,'END_RT');
	@()trackerMessage(eT,sprintf('TRIAL_RESULT %i',tS.INCORRECT));
	@()stopRecording(eT); % stop recording in eyelink [tobii ignores this]
	@()setOffline(eT); % set eyelink offline [tobii ignores this]
	@()needEyeSample(me,false);
	@()hide(stims);
	@()logRun(me,'INCORRECT'); %fprintf current trial info
};

%--------------------our incorrect/breakfix stimulus
incFn = {
	@()drawPhotoDiodeSquare(s,[0 0 0]);
};

%--------------------incorrect exit
incExitFn = {
	@()beep(aM,tS.errorSound);
	@()trackerDrawStatus(eT,'INCORRECT! :-(', stims.stimulusPositions, 0);
	@()needFlipTracker(me, 0); %for operator screen stop flip
	@()updateVariables(me); %randomise our stimuli, set strobe value too
	@()update(stims); %update our stimuli ready for display
	@()getStimulusPositions(stims); %make a struct the eT can use for drawing stim positions
	@()resetAll(eT); %resets the fixation state timers
	@()plot(bR, 1); % actually do our drawing
};

%--------------------break entry
breakEntryFn = {
	@()edfMessage(eT,'END_RT');
	@()edfMessage(eT,['TRIAL_RESULT ' num2str(tS.BREAKFIX)]);
	@()stopRecording(eT);
	@()setOffline(eT); % set eyelink offline [tobii ignores this]
	@()needEyeSample(me,false);
	@()sendStrobe(io,252);
	@()hide(stims);
	@()logRun(me,'BREAKFIX'); %fprintf current trial info
};

%--------------------break exit
breakExitFn = {
	@()beep(aM,tS.errorSound);
	@()trackerDrawStatus(eT,'BREAKFIX! :-(', stims.stimulusPositions, 0);
	@()needFlipTracker(me, 0); %for operator screen stop flip
	@()updateVariables(me); %randomise our stimuli, set strobe value too
	@()update(stims); %update our stimuli ready for display
	@()getStimulusPositions(stims); %make a struct the eT can use for drawing stim positions
	@()resetAll(eT); %resets the fixation state timers
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
	incExitFn = [ {@()updatePlot(bR, me); @()updateTask(me,tS.INCORRECT)}; incExitFn ]; %update our taskSequence 
	breakExitFn = [ {@()updatePlot(bR, me); @()updateTask(me,tS.BREAKFIX)}; breakExitFn ]; %update our taskSequence 
else
	incExitFn = [ {@()updatePlot(bR, me); @()resetRun(task)}; incExitFn ]; 
	breakExitFn = [ {@()updatePlot(bR, me); @()resetRun(task)}; breakExitFn ];
end
if tS.useTask || task.nBlocks > 0 % we are using a task or repeat blocks
	correctExitFn = [ correctExitFn; {@()checkTaskEnded(me)} ];
	incExitFn = [ incExitFn; {@()checkTaskEnded(me)} ];
	breakExitFn = [ breakExitFn; {@()checkTaskEnded(me)} ];
end

%========================================================
%========================================================EYETRACKER
%========================================================
%--------------------calibration function
calibrateFn = {
	@()drawBackground(s); %blank the display
	@()stopRecording(eT); % stop recording in eyelink [tobii ignores this]
	@()setOffline(eT); % set eyelink offline [tobii ignores this]
	@()rstop(io); 
	@()trackerSetup(eT);  %enter tracker calibrate/validate setup mode
};

%--------------------drift correction function
driftFn = { 
	@()drawBackground(s); %blank the display
	@()stopRecording(eT); % stop recording in eyelink [tobii ignores this]
	@()setOffline(eT); % set eyelink offline [tobii ignores this]
	@()driftCorrection(eT) % enter drift correct (only eyelink) (only eyelink)
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
overrideFn = { @()keyOverride(me) }; %a special mode which enters a matlab debug state so we can manually edit object values

%--------------------screenflash
flashFn = { @()flashScreen(s, 0.2) }; % fullscreen flash mode for visual background activity detection

%--------------------show 1deg size grid
gridFn = { @()drawGrid(s) };

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
'prefix'	'fixate'	0.5		prefixEntryFn	{}				{}				{};
'fixate'	'incorrect'	10		fixEntryFn		fixFn			inFixFn			fixExitFn;
'stimulus'	'incorrect'	10		stimEntryFn		stimFn			maintainFixFn	stimExitFn;
'correct'	'prefix'	0.1		correctEntryFn	correctFn		{}				correctExitFn;
'incorrect'	'timeout'	0.1		incEntryFn		incFn			{}				incExitFn;
'breakfix'	'timeout'	0.1		breakEntryFn	incFn			{}				breakExitFn;
'timeout'	'prefix'	tS.tOut	{}				incFn			{}				{};
%---------------------------------------------------------------------------------------------
'calibrate'	'pause'		0.5		calibrateFn		{}				{}				{};
'drift'		'pause'		0.5		driftFn			{}				{}				{};
'offset'	'pause'		0.5		offsetFcn		{}				{}				{};
%---------------------------------------------------------------------------------------------
'override'	'pause'		0.5		overrideFn		{}				{}				{};
'flash'		'pause'		0.5		flashFn			{}				{}				{};
'showgrid'	'pause'		10		{}				gridFn			{}				{};
};
%--------------------------State Machine Table-----------------------------
%==========================================================================

disp('=================>> Built state info file <<==================')
disp(stateInfoTmp)
disp('=================>> Built state info file <<=================')
clearvars -regexp '.+Fn$' % clear the cell array Fns in the current workspace

%> REVERSE CORRELATION PROTOCOL
% The following class objects are already loaded by runTask() and available
% to use; each object has methods (functions) useful for running the task:
%
% me		= runExperiment object ('self' in OOP terminology) 
% s		= screenManager object
% aM		= audioManager object
% stims	= our list of stimuli (metaStimulus class)
% sM		= State Machine (stateMachine class)
% task		= task sequence (taskSequence class)
% eT		= eyetracker manager
% io		= digital I/O to recording system
% rM		= Reward Manager (LabJack or Arduino TTL trigger to reward system/Magstim)
% bR		= behavioural record plot (on-screen GUI during a task run)
% uF       = user functions - add your own functions to this class
% tS		= structure to hold general variables, will be saved as part of the data

%==================================================================
%------------------------General Settings--------------------------
% These settings are make changing the behaviour of the protocol easier. tS
% is just a struct(), so you can add your own switches or values here and
% use them lower down. Some basic switches like saveData, useTask,
% checkKeysDuringstimulus will influence the runeExperiment.runTask()
% functionality, not just the state machine. Other switches like
% includeErrors are referenced in this state machine file to change with
% functions are added to the state machine states…
tS.useTask					= false;		%==use taskSequence (randomises stimulus variables)
tS.rewardTime				= 250;		%==TTL time in milliseconds
tS.rewardPin				= 2;		%==Output pin, 2 by default with Arduino.
tS.keyExclusionPattern		= ["fixate","stimulus"]; %==which states to skip keyboard checking
tS.enableTrainingKeys		= true;		%==enable keys useful during task training, but not for data recording
tS.recordEyePosition		= false;	%==record local copy of eye position, **in addition** to the eyetracker?
tS.askForComments			= false;	%==UI requestor asks for comments before/after run
tS.saveData					= true;		%==save behavioural and eye movement data?
tS.showBehaviourPlot		= true;		%==open the behaviourPlot figure? Can cause more memory use…
tS.includeErrors			= false;	%==do we update the trial number even for incorrect saccade/fixate, if true then we call updateTask for both correct and incorrect, otherwise we only call updateTask() for correct responses
tS.name						= 'REVCOR'; %==name of this protocol
tS.nStims					= stims.n;	%==number of stimuli, taken from metaStimulus object
tS.tOut						= 2;		%==if wrong response, how long to time out before next trial
tS.CORRECT					= 1;		%==the code to send eyetracker for correct trials
tS.BREAKFIX					= -1;		%==the code to send eyetracker for break fix trials
tS.INCORRECT				= -5;		%==the code to send eyetracker for incorrect trials

%=================================================================
%----------------Debug logging to command window------------------ging the behaviour of the protocol easier. tS
% is just a struct(), so you c
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
tS.firstFixTime				= 0.5;
% circular fixation window radius in degrees
tS.firstFixRadius			= 2;
% do we forbid eye to enter-exit-reenter fixation window?
tS.strict					= true;
% do we add an exclusion zone where subject cannot saccade to...
tS.exclusionZone			= [];
% time to fix on the stimulus
tS.stimulusFixTime			= 2;
% log of recent X and Y position, and exclusion zone, here set ti initial
% values
me.lastXPosition			= tS.fixX;
me.lastYPosition			= tS.fixY;
me.lastXExclusion			= [];
me.lastYExclusion			= [];

%=========================================================================
%-------------------------------Eyetracker setup--------------------------
% NOTE: the opticka GUI can set eyetracker options too; me.eyetracker.esettings
% and me.eyetracker.tsettings contain the GUI settings. We test if they are
% empty or not and set general values based on that...

eT.name				= tS.name;
if me.eyetracker.dummy == true;	eT.isDummy = true; end %===use dummy or real eyetracker? 
if tS.saveData;		eT.recordData = true; end %===save ET data?					
switch me.eyetracker.device
	case 'eyelink'
	if isempty(me.eyetracker.esettings)		%==check if GUI settings are empty
		eT.sampleRate				= 250;		%==sampling rate
		eT.calibrationStyle			= 'HV5';	%==calibration style
		eT.calibrationProportion	= [0.4 0.4]; %==the proportion of the screen occupied by the calibration stimuli
		%-----------------------
		% remote calibration enables manual control and selection of each
		% fixation this is useful for a baby or monkey who has not been trained
		% for fixation use 1-9 to show each dot, space to select fix as valid,
		% INS key ON EYELINK KEYBOARD to accept calibration!
		eT.remoteCalibration				= false; 
		%-----------------------
		eT.modify.calibrationtargetcolour	= [1 1 1]; %==calibration target colour
		eT.modify.calibrationtargetsize		= 2;		%==size of calibration target as percentage of screen
		eT.modify.calibrationtargetwidth	= 0.15;	%==width of calibration target's border as percentage of screen
		eT.modify.waitformodereadytime		= 500;
		eT.modify.devicenumber				= -1;		%==-1 = use any attachedkeyboard
		eT.modify.targetbeep				= 1;		%==beep during calibration
	end
case 'tobii'
	if isempty(me.eyetracker.tsettings)	%==check if GUI settings are empty
		eT.model					= 'Tobii Pro Spectrum';
		eT.sampleRate				= 300;
		eT.trackingMode				= 'human';
		eT.calibrationStimulus		= 'animated';
		eT.autoPace					= true;
		%-----------------------
		% remote calibration enables manual control and selection of each
		% fixation this is useful for a baby or monkey who has not been trained
		% for fixation
		eT.manualCalibration		= false;
		%-----------------------
		eT.calPositions				= [ .2 .5; .5 .5; .8 .5];
		eT.valPositions				= [ .5 .5 ];
	end
end
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
	@()needFlip(me, true); 
	@()needEyeSample(me, true); % make sure we start measuring eye position
	@()hide(stims); % hide all stimuli
	% update the fixation window to initial values
	@()updateFixationValues(eT,tS.fixX,tS.fixY,[],tS.firstFixTime); %reset fixation window
	@()startRecording(eT); % start eyelink recording for this trial (tobii ignores this)
	% tracker messages that define a trial start
	@()trackerMessage(eT,'V_RT MESSAGE END_FIX END_RT'); % Eyelink commands
	@()trackerMessage(eT,sprintf('TRIALID %i',getTaskIndex(me))); %Eyelink start trial marker
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
	@()trackerDrawStatus(eT,'Init Fix...', stims.stimulusPositions);
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
	@()testSearchHoldFixation(eT,'stimulus','incorrect')
};

%--------------------exit fixation phase
fixExitFn = { 
	@()statusMessage(eT,'Show Stimulus...');
	% reset fixation timers to maintain fixation for tS.stimulusFixTime seconds
	@()updateFixationValues(eT,[],[],[],tS.stimulusFixTime); 
	@()show(stims); % show all stims
	@()trackerMessage(eT,'END_FIX'); %eyetracker message saved to data stream
}; 

%========================================================
%========================================================STIMULUS
%========================================================

stimEntryFn = {
	% send an eyeTracker sync message (reset relative time to 0 after first flip of this state)
	@()doSyncTime(me);
	% send stimulus value strobe (value set by updateVariables(me) function)
	@()doStrobe(me,true);
};

%--------------------what to run when we are showing stimuli
stimFn =  {
	@()draw(stims);
	@()drawPhotoDiodeSquare(s,[1 1 1]);
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
	@()testSearchHoldFixation(eT, 'correct', 'breakfix');
};

%as we exit stim presentation state
stimExitFn = {
	@()sendStrobe(io, 255);
	@()addTag(stims{1}, sM.currentUUID); % this adds stateMachine UUID to revcor stimulus frameLog
};

%========================================================
%========================================================DECISIONS
%========================================================

%========================================================CORRECT
%--------------------if the subject is correct (small reward)
correctEntryFn = {
	@()giveReward(rM); % send a reward TTL
	@()beep(aM, tS.correctSound); % correct beep
	@()trackerMessage(eT,'END_RT'); %send END_RT message to tracker
	@()trackerMessage(eT,sprintf('TRIAL_RESULT %i',tS.CORRECT)); %send TRIAL_RESULT message to tracker
	@()trackerClearScreen(eT);
	@()trackerDrawText(eT,'Correct! :-)');
	@()stopRecording(eT); % stop recording in eyelink [tobii ignores this]
	@()setOffline(eT); % set eyelink offline [tobii ignores this]
	@()needEyeSample(me,false); % no need to collect eye data until we start the next trial
	@()hide(stims); % hide all stims
	@()logRun(me,'CORRECT'); % print current trial info
};

%--------------------correct stimulus
correctFn = {
	@()drawPhotoDiodeSquare(s, [0 0 0]);
};

%--------------------when we exit the correct state
correctExitFn = {
	@()updatePlot(bR, me); %update our behavioural record, MUST be done before we update variables
	@()updateTask(me, tS.CORRECT); %make sure our taskSequence is moved to the next trial
	@()updateVariables(me); %randomise our stimuli, and set strobe value too
	@()update(stims); %update our stimuli ready for display
	@()getStimulusPositions(stims); %make a struct the eT can use for drawing stim positions
	@()trackerClearScreen(eT); 
	@()resetFixation(eT); %resets the fixation state timers	
	@()resetFixationHistory(eT); % reset the recent eye position history
	@()resetExclusionZones(eT); % reset the exclusion zones on eyetracker
	@()checkTaskEnded(me); %check if task is finished
	@()plot(bR, 1); % actually do our behaviour record drawing
};

%========================================================INCORRECT
%--------------------incorrect entry
incEntryFn = { 
	@()beep(aM, 400, 0.5, 1);
	@()trackerMessage(eT, 'END_RT');
	@()trackerMessage(eT, sprintf('TRIAL_RESULT %i', tS.INCORRECT));
	@()trackerDrawStatus(eT, 'INCORRECT! :-(', stims.stimulusPositions, 0);
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
	@()updatePlot(bR, me); %update our behavioural plot, must come before updateTask() / updateVariables()
	@()updateVariables(me); %randomise our stimuli, set strobe value too
	@()update(stims); %update our stimuli ready for display
	@()getStimulusPositions(stims); %make a struct the eT can use for drawing stim positions
	@()trackerClearScreen(eT); 
	@()resetFixation(eT); %resets the fixation state timers
	@()resetFixationHistory(eT); %reset the stored X and Y values
	@()plot(bR, 1); % actually do our drawing
};

%--------------------break entry
breakEntryFn = {
	@()beep(aM,tS.errorSound);
	@()edfMessage(eT,'END_RT');
	@()edfMessage(eT,['TRIAL_RESULT ' num2str(tS.BREAKFIX)]);
	@()trackerDrawStatus(eT,'BREAKFIX! :-(', stims.stimulusPositions, 0);
	@()stopRecording(eT);
	@()setOffline(eT); % set eyelink offline [tobii ignores this]
	@()needEyeSample(me,false);
	@()sendStrobe(io,252);
	@()hide(stims);
	@()logRun(me,'BREAKFIX'); %fprintf current trial info
};

%--------------------break exit
breakExitFn = incExitFn; % we copy the incorrect exit functions

%--------------------change functions based on tS settings
% this shows an example of how to use tS options to change the function
% lists run by the state machine. We can prepend or append new functions to
% the cell arrays.
% updateTask = updates task object
% resetRun = randomise current trial within the block
% checkTaskEnded = see if taskSequence has finished
if tS.useTask %we are using task
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
'prefix'	'fixate'	0.5		prefixEntryFn	prefixFn		{}				{};
'fixate'	'incorrect'	10		fixEntryFn		fixFn			inFixFn			fixExitFn;
'stimulus'	'incorrect'	10		stimEntryFn		stimFn			maintainFixFn	stimExitFn;
'incorrect'	'timeout'	0.5		incEntryFn		incFn			{}				incExitFn;
'breakfix'	'timeout'	0.5		breakEntryFn	incFn			{}				breakExitFn;
'correct'	'prefix'	0.5		correctEntryFn	correctFn		{}				correctExitFn;
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

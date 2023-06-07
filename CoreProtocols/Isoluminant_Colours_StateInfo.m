%> ISOLUMINANT COLOUR Task, shows how to randomise different colours using a
%> disc (100°=full screen).
%> This is a state configuration file for runExperiment.runTask (full
%> behavioural task design). This state file has a [prefix] state, a
%> [fixate] state for the subject to initiate fixation. If the subject fails
%> initial fixation, an [incorrect] state is called. If the subject fails
%> fixation DURING [stimulus] presentation, a [breakfix] state is called. It
%> assumes there are TWO stimuli in the stims object, the first (stims{1})
%> is any type of visual stimulus and the second is a fixation cross
%> (stims{2}). For this task most state transitions are deterministic, but
%> for fixate there is a transitionFcn that checks if the subject initiates
%> fixation [inFixFcn], and for stimulus there is a check if the subject
%> maintains fixation for an additional time [maintainFixfcn].
%>
%>    ┌───────────────────────────────────────┐
%>    │                                       ▼
%>    │                                     ┌───────────────────────────┐
%> ┌──┼───────────────────────────────────▶ │          prefix           │ ◀┐
%> │  │                                     └───────────────────────────┘  │
%> │  │                                       │                            │
%> │  │                                       ▼                            │
%> │┌───────────┐ Transition                ┌───────────────────────────┐  │
%> ││ incorrect │ inFixFcn=>incorrect       │          fixate           │  │
%> ││           │◀───────────────────────── │ show(stims, 2)            │  │
%> │└───────────┘                           └───────────────────────────┘  │
%> │                                          │                            │
%> │                                          │ Transition                 │
%> └──┐                                       │ inFixFcn=>stimulus         │
%>    │                                       ▼                            │
%>  ┌───────────┐ Transition                ┌───────────────────────────┐  │
%>  │  CORRECT  │ maintainFixFcn=>correct   │         stimulus          │  │
%>  │           │◀───────────────────────── │ show(stims, [1 2])        │  │
%>  └───────────┘                           └───────────────────────────┘  │
%>                                            │                            │
%>                                            │ Transition                 │
%>                                            │ maintainFixFcn=>breakfix   │
%>                                            ▼                            │
%>                                          ┌───────────────────────────┐  │
%>                                          │         BREAKFIX          │ ─┘
%>                                          └───────────────────────────┘
%>
%> State files control the logic of a behavioural task, switching between
%> states and executing functions on ENTER, WITHIN and on EXIT of states. In
%> addition there are TRANSITION function sets which can test things like
%> eye position to conditionally jump to another state. This state control
%> file will usually be run in the scope of the calling
%> runExperiment.runTask() method and other objects will be available at run
%> time (with easy to use names listed below). The following class objects
%> are already loaded by runTask() and available to use; each object has
%> methods (functions) useful for running the task:
%>
%> me		= runExperiment object ('self' in OOP terminology) 
%> s			= screenManager object
%> aM		= audioManager object
%> stims		= our list of stimuli (metaStimulus class)
%> sM		= State Machine (stateMachine class)
%> task		= task sequence (taskSequence class)
%> eT		= eyetracker manager
%> io		= digital I/O to recording system
%> rM		= Reward Manager (LabJack or Arduino TTL trigger to reward system/Magstim)
%> bR		= behavioural record plot (on-screen GUI during a task run)
%> tS		= structure to hold general variables, will be saved as part of the data

%==================================================================
%------------------------General Settings--------------------------
tS.useTask					= true;		%==use taskSequence (randomises stimulus variables)
tS.rewardTime				= 250;		%==TTL time in milliseconds
tS.rewardPin				= 2;		%==Output pin, 2 by default with Arduino.
tS.checkKeysDuringStimulus  = true;		%==allow keyboard control within stimulus state? Slight drop in performance…
tS.recordEyePosition		= false;	%==record local copy of eye position, **in addition** to the eyetracker?
tS.askForComments			= false;	%==UI requestor asks for comments before/after run
tS.saveData					= false;	%==save behavioural and eye movement data?
tS.includeErrors			= false;	%==do we update the trial number even for incorrect saccade/fixate, if true then we call updateTask for both correct and incorrect, otherwise we only call updateTask() for correct responses
tS.name						= 'isoluminant'; %==name of this protocol
tS.nStims					= stims.n;	%==number of stimuli, taken from metaStimulus object
tS.tOut						= 5;		%==if wrong response, how long to time out before next trial
tS.CORRECT 					= 1;		%==the code to send eyetracker for correct trials
tS.BREAKFIX 				= -1;		%==the code to send eyetracker for break fix trials
tS.INCORRECT 				= -5;		%==the code to send eyetracker for incorrect trials

%==================================================================
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
% initial fixation X position in degrees (0° is screen centre)
tS.fixX						= 0;	
% initial fixation Y position in degrees
tS.fixY						= 0;
% time to search and enter fixation window
tS.firstFixInit				= 3;
% time to maintain fixation within window, can be single value or a range
% to randomise between
tS.firstFixTime				= [0.5 0.9];
% circular fixation window radius in degrees
tS.firstFixRadius			= 2;
% do we forbid eye to enter-exit-reenter fixation window?
tS.strict					= true;
% do we add an exclusion zone where subject cannot saccade to...
tS.exclusionZone			= [];
% time to fix on the stimulus
tS.stimulusFixTime			= 0.5;
% historical log of X and Y position, and exclusion zone
me.lastXPosition			= tS.fixX;
me.lastYPosition			= tS.fixY;
me.lastXExclusion			= [];
me.lastYExclusion			= [];


%=========================================================================
%-------------------------------Eyetracker setup--------------------------
% NOTE: the opticka GUI can set eyetracker options too; me.eyetracker.esettings
% and me.eyetracker.tsettings contain the GUI settings. We test if they are
% empty or not and set general values based on that...

eT.name 					= tS.name;
if tS.saveData == true;		eT.recordData = true; end %===save ET data?					
switch me.eyetracker.device
	case 'eyelink'
	eT.name 						= tS.name;
	if me.eyetracker.dummy == true;				eT.isDummy = true; end %===use dummy or real eyetracker? 
	if tS.saveData == true;			eT.recordData = true; end %===save EDF file?
	if isempty(me.eyetracker.esettings)		%==check if GUI settings are empty
		eT.sampleRate				= 250;		%==sampling rate
		eT.calibrationStyle			= 'HV5';	%==calibration style
		eT.calibrationProportion	= [0.4 0.4]; %==the proportion of the screen occupied by the calibration stimuli
		%-----------------------
		% remote calibration enables manual control and selection of each
		% fixation this is useful for a baby or monkey who has not been trained
		% for fixation use 1-9 to show each dot, space to select fix as valid,
		% INS key ON EYELINK KEYBOARD to accept calibration!
		eT.remoteCalibration		= false; 
		%-----------------------
		eT.modify.calibrationtargetcolour = [1 1 1]; %==calibration target colour
		eT.modify.calibrationtargetsize = 2;		%==size of calibration target as percentage of screen
		eT.modify.calibrationtargetwidth = 0.15;	%==width of calibration target's border as percentage of screen
		eT.modify.waitformodereadytime	= 500;
		eT.modify.devicenumber 			= -1;		%==-1 = use any attachedkeyboard
		eT.modify.targetbeep 			= 1;		%==beep during calibration
	end
case 'tobii'
	eT.name 						= tS.name;
	if me.eyetracker.dummy == true;				eT.isDummy = true; end %===use dummy or real eyetracker? 
	if isempty(me.eyetracker.tsettings) 	%==check if GUI settings are empty
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
eT.updateFixationValues(tS.fixX, tS.fixY, tS.firstFixInit, tS.firstFixTime, tS.firstFixRadius, tS.strict);
%Ensure we don't start with any exclusion zones set up
eT.resetExclusionZones();

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

%==================================================================
%this allows us to enable subsets from our stimulus list
% 1 = grating | 2 = fixation cross
stims.stimulusSets				= {[1,2],[1]};
stims.setChoice					= 1;
hide(stims);

%==================================================================
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
%-----------------State Machine Task Functions---------------------
% Each cell {array} holds a set of anonymous function handles which are
% executed by the state machine to control the experiment. The state
% machine can run sets at entry ['entryFcn'], during ['withinFcn'], to
% trigger a transition jump to another state ['transitionFcn'], and at exit
% ['exitFcn'. Remember these {sets} need to access the objects that are
% available within the runExperiment context (see top of file). You can
% also add global variables/objects then use these. The values entered here
% are set on load, if you want up-to-date values then you need to use
% methods/function wrappers to retrieve/set them.

%====================================================PAUSE
%--------------------pause entry
pauseEntryFcn = { 
	@()hide(stims);
	@()drawBackground(s); %blank the subject display
	@()drawTextNow(s,'PAUSED, press [p] to resume...');
	@()disp('PAUSED, press [p] to resume...');
	@()trackerClearScreen(eT); % blank the eyelink screen
	@()trackerDrawText(eT,'PAUSED, press [P] to resume...');
	@()trackerMessage(eT,'TRIAL_RESULT -100'); %store message in EDF
	@()setOffline(eT); % set eyelink offline [tobii ignores this]
	@()stopRecording(eT, true); %stop recording eye position data
	@()needFlip(me, false); % no need to flip the PTB screen
	@()needEyeSample(me,false); % no need to check eye position
};

%pause exit
pauseExitFcn = {
	%start recording eye position data again, note true is required here as
	%the eyelink is started and stopped on each trial, but the tobii runs
	%continuously, so @()startRecording(eT) only affects eyelink but
	%@()startRecording(eT, true) affects both eyelink and tobii...
	@()startRecording(eT, true); 
}; 

%====================================================PREFIXATION
prefixEntryFcn = { 
	@()needFlip(me, true); 
	@()needEyeSample(me, true); % make sure we start measuring eye position
	@()hide(stims);
};

prefixFcn = {
	@()drawBackground(s);
};

%--------------------fixate entry
fixEntryFcn = { 
	@()updateFixationValues(eT,tS.fixX,tS.fixY,[],tS.firstFixTime); %reset fixation window
	@()startRecording(eT); % start eyelink recording for this trial
	@()trackerMessage(eT,'V_RT MESSAGE END_FIX END_RT'); % Eyelink commands
	@()trackerMessage(eT,sprintf('TRIALID %i',getTaskIndex(me))); %Eyelink start trial marker
	@()trackerMessage(eT,['UUID ' UUID(sM)]); %add in the uuid of the current state for good measure
	@()trackerClearScreen(eT); % blank the eyelink screen
	@()trackerDrawFixation(eT); %draw fixation window on eyelink computer
	@()trackerDrawStimuli(eT,stims.stimulusPositions); %draw location of stimulus on eyelink
	@()statusMessage(eT,'Initiate Fixation...'); %status text on the eyelink
	@()show(stims{tS.nStims}); % show only last stim in list (fix cross)
	@()logRun(me,'INITFIX'); %fprintf current trial info to command window
};

%--------------------fix within
fixFcn = {
	@()draw(stims); %draw stimuli
	@()drawPhotoDiodeSquare(s,[0 0 0]);
	@()animate(stims); % animate stimuli for subsequent draw
};

%--------------------test we are fixated for a certain length of time
initFixFcn = { 
	@()testSearchHoldFixation(eT,'stimulus','incorrect'); 
};

%--------------------exit fixation phase
fixExitFcn = { 
	@()statusMessage(eT,'Show Stimulus...');
	@()updateFixationValues(eT,[],[],[],tS.stimulusFixTime); %reset a maintained fixation of 1 second
	@()show(stims); % show all stims)
    @()trackerMessage(eT,'END_FIX');
}; 

%--------------------what to run when we enter the stim presentation state
stimEntryFcn = { 
	@()doSyncTime(me); %EDF sync message
	@()doStrobe(me,true)
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
	@()testSearchHoldFixation(eT,'correct','breakfix'); 
};

%as we exit stim presentation state
stimExitFcn = { 
	@()sendStrobe(io,255);
};

%if the subject is correct (small reward)
correctEntryFcn = {
	@()giveReward(rM); % send a reward TTL
	@()beep(aM,2000); % correct beep
	@()trackerMessage(eT,'END_RT'); %send END_RT message to tracker
	@()trackerMessage(eT,['TRIAL_RESULT ' str2double(tS.CORRECT)]); %send TRIAL_RESULT message to tracker
	@()trackerDrawText(eT,'Correct! :-)');
	@()stopRecording(eT); % stop recording in eyelink [tobii ignores this]
	@()setOffline(eT); % set eyelink offline [tobii ignores this]
	@()needEyeSample(me,false); % no need to collect eye data until we start the next trial
	@()hide(stims); %hide all stims
	@()logRun(me,'CORRECT'); %fprintf current trial info
};

%correct stimulus
correctFcn = { 
	@()drawBackground(s);
};

%when we exit the correct state
correctExitFcn = {
	@()updateTask(me,tS.CORRECT); %make sure our taskSequence is moved to the next trial
	@()updateVariables(me); %randomise our stimuli, and set strobe value too
	@()update(me.stimuli); %update our stimuli ready for display
	@()getStimulusPositions(stims); %make a struct the eT can use for drawing stim positions
	@()trackerClearScreen(eT); 
	@()updatePlot(bR, me); %update our behavioural plot
	@()checkTaskEnded(me); %check if task is finished
	@()resetFixation(eT); %resets the fixation state timers	
	@()resetFixationHistory(eT); %reset the stored X and Y values
	@()drawnow;
};

%incorrect entry
incEntryFcn = { 
	@()beep(aM,tS.errorSound);
	@()trackerClearScreen(eT);
	@()trackerDrawText(eT,'Incorrect! :-(');
	@()trackerMessage(eT,'END_RT');
	@()trackerMessage(eT,['TRIAL_RESULT ' str2double(tS.INCORRECT)]);
	@()needEyeSample(me,false);
	@()hide(stims);
	@()logRun(me,'INCORRECT'); %fprintf current trial info
}; 

%our incorrect/breakfix stimulus
incFcn = {
	@()drawBackground(s);
};

%--------------------incorrect exit
incExitFcn = { 
	@()updateVariables(me); %randomise our stimuli, set strobe value too
	@()update(stims); %update our stimuli ready for display
	@()getStimulusPositions(stims); %make a struct the eT can use for drawing stim positions
	@()trackerClearScreen(eT); 
	@()updatePlot(bR, me); %update our behavioural plot, must come before updateTask() / updateVariables()
	@()resetFixation(eT); %resets the fixation state timers
	@()resetFixationHistory(eT); %reset the stored X and Y values
	@()drawnow;
};

%--------------------break entry
breakEntryFcn = {
	@()beep(aM,tS.errorSound);
	@()edfMessage(eT,'END_RT');
	@()edfMessage(eT,['TRIAL_RESULT ' num2str(tS.BREAKFIX)]);
	@()trackerClearScreen(eT);
	@()trackerDrawText(eT,'Broke maintain fix! :-(');
	@()stopRecording(eT);
	@()setOffline(eT); % set eyelink offline [tobii ignores this]
	@()needEyeSample(me,false);
	@()sendStrobe(io,252);
	@()hide(stims);
	@()logRun(me,'BREAKFIX'); %fprintf current trial info
};

%--------------------break exit
breakExitFcn = incExitFcn; % we copy the incorrect exit functions

%--------------------change functions based on tS settings
% this shows an example of how to use tS options to change the function
% lists run by the state machine. We can prepend or append new functions to
% the cell arrays...
if tS.includeErrors % we want to update our task even if there were errors
	incExitFcn = [ {@()updateTask(me,tS.INCORRECT)}; incExitFcn ]; %update our taskSequence 
	breakExitFcn = [ {@()updateTask(me,tS.BREAKFIX)}; breakExitFcn ]; %update our taskSequence 
end
if tS.useTask %we are using task
	correctExitFcn = [ correctExitFcn; {@()checkTaskEnded(me)} ];
	incExitFcn = [ incExitFcn; {@()checkTaskEnded(me)} ];
	breakExitFcn = [ breakExitFcn; {@()checkTaskEnded(me)} ];
	if ~tS.includeErrors % using task but don't include errors 
		incExitFcn = [ {@()resetRun(task)}; incExitFcn ]; %we randomise the run within this block to make it harder to guess next trial
		breakExitFcn = [ {@()resetRun(task)}; breakExitFcn ]; %we randomise the run within this block to make it harder to guess next trial
	end
end

%--------------------enter tracker calibrate/validate setup mode
calibrateFcn = { 
	@()drawBackground(s); %blank the display
	@()setOffline(eT);
	%@()pauseRecording(io);
	@()trackerSetup(eT);
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

%--------------------debug override special mode which enters a matlab debug state so we can manually edit object values
overrideFcn = { 
	%@()pauseRecording(io);
	@()setOffline(eT);
	@()keyOverride(me);
};

%--------------------screenflash
flashFcn = {
	@()drawBackground(s);
	@()flashScreen(s, 0.2);% fullscreen flash mode for visual background activity detection
};

%--------------------show 1deg size grid
gridFcn = { 
	@()drawGrid(s); 
};

% N x 2 cell array of regexpi strings, list to skip the current -> next state's exit functions; for example
% skipExitStates = {'fixate',{'incorrect','breakfix'}}; means that if the currentstate is
% 'fixate' and the next state is either incorrect OR breakfix, then skip the FIXATE exit
% state. Add multiple rows for skipping multiple state's exit states.
sM.skipExitStates = {'fixate',{'incorrect','breakfix'}};

%==================================================================
%----------------------State Machine Table-------------------------
%specify our cell array that is read by the stateMachine
stateInfoTmp = {
'name'		'next'		'time'  'entryFcn'		'withinFcn'		'transitionFcn'	'exitFcn';
%---------------------------------------------------------------------------------------------
'pause'		'prefix'	inf		pauseEntryFcn	{}				{}				pauseExitFcn;
%---------------------------------------------------------------------------------------------
'prefix'	'fixate'	2		prefixEntryFcn	{}				{}				{};
'fixate'	'incorrect'	2	 	fixEntryFcn		fixFcn			initFixFcn		fixExitFcn;
'stimulus'	'incorrect'	2		stimEntryFcn	stimFcn			maintainFixFcn	stimExitFcn;
'correct'	'prefix'	1		correctEntryFcn	correctFcn		{}				correctExitFcn;
'incorrect'	'prefix'	1		incEntryFcn		incFcn			{}				incExitFcn;
'breakfix'	'prefix'	1		breakEntryFcn	incFcn			{}				breakExitFcn;
%---------------------------------------------------------------------------------------------
'calibrate'	'pause'		0.5		calibrateFcn	{}				{}				{};
'drift'		'pause'		0.5		driftFcn		{}				{}				{};
'offset'	'pause'		0.5		offsetFcn		{}				{}				{};
%---------------------------------------------------------------------------------------------
'override'	'pause'		0.5		overrideFcn		{}				{}				{};
'flash'		'pause'		0.5		flashFcn		{}				{}				{};
'showgrid'	'pause'		10		{}				gridFcn			{}				{};
};
%----------------------State Machine Table-------------------------
%==================================================================

disp('=================>> Built state info file <<==================')
disp(stateInfoTmp)
disp('=================>> Built state info file <<=================')
clearvars -regexp '.+Fn$' % clear the cell array Fns in the current workspace

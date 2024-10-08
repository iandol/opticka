%DOT COLOUR state configuration file, this gets loaded by opticka via runExperiment class

% The following class objects (easily named handle copies) are already 
% loaded and available to use. Each class has methods useful for running the task: 
%
% me		= runExperiment object
% s			= screenManager
% aM		= audioManager
% sM		= State Machine
% task		= task sequence (taskSequence class)
% eT		= eyetracker manager
% io		= digital I/O to recording system
% rM		= Reward Manager (LabJack or Arduino TTL trigger to reward system/Magstim)
% bR		= behavioural record plot (on screen GUI during task run)
% stims		= our list of stimuli
% tS		= general structure to hold general variables, will be saved as part of the data

%==================================================================
%------------General Settings-----------------
tS.useTask					= true;		%==use taskSequence (randomised variable task object)
tS.rewardTime				= 250;		%==TTL time in milliseconds
tS.rewardPin				= 2;		%==Output pin, 2 by default with Arduino.
tS.checkKeysDuringStimulus	= true;		%==allow keyboard control during all states? Slight drop in performance
tS.recordEyePosition		= false;	%==record eye position within PTB, **in addition** to the EDF?
tS.askForComments			= false;	%==little UI requestor asks for comments before/after run
tS.saveData					= true;		%==save behavioural and eye movement data?
tS.name						= 'dot-direction'; %==name of this protocol
tS.nStims					= stims.n;	%==number of stimuli
tS.tOut						= 5;		%==if wrong response, how long to time out before next trial
tS.CORRECT 					= 1;		%==the code to send eyetracker for correct trials
tS.BREAKFIX 				= -1;		%==the code to send eyetracker for break fix trials
tS.INCORRECT 				= -5;		%==the code to send eyetracker for incorrect trials

%==================================================================
%------------Debug logging to command window-----------------
%io.verbose					= true;	%==print out io commands for debugging
%eT.verbose					= true;	%==print out eyelink commands for debugging
%rM.verbose					= true;	%==print out reward commands for debugging

%==================================================================
%-----------------INITIAL Eyetracker Settings----------------------
tS.fixX						= 0;		% X position in degrees
tS.fixY						= 0;		% X position in degrees
tS.firstFixInit				= 3;		% time to search and enter fixation window
tS.firstFixTime				= 0.5;		% time to maintain fixation within windo
tS.firstFixRadius			= 2;		% radius in degrees
tS.strict					= true;		% do we forbid eye to enter-exit-reenter fixation window?
tS.exclusionZone			= [];		% do we add an exclusion zone where subject cannot saccade to...
tS.stimulusFixTime			= 1;		% time to fix on the stimulus
eT.updateFixationValues(tS.fixX, tS.fixY, tS.firstFixInit, tS.firstFixTime, tS.firstFixRadius, tS.strict);

%==================================================================
%----which states assigned as correct or break for online plot?----
bR.correctStateName				= "correct";
bR.breakStateName				= ["breakfix","incorrect"];

%==================================================================
%-------------------randomise stimulus variables every trial?-----------
% if you want to have some randomisation of stimuls variables without
% using taskSequence task, you can uncomment this and runExperiment can
% use this structure to change e.g. X or Y position, size, angle
% see metaStimulus for more details. Remember this will not be "Saved" for
% later use, if you want to do controlled methods of constants experiments
% use taskSequence to define proper randomised and balanced variable
% sets and triggers to send to recording equipment etc...
%
% stims.choice				= [];
% n							= 1;
% in(n).name				= 'xyPosition';
% in(n).values				= [6 6; 6 -6; -6 6; -6 -6; -6 0; 6 0];
% in(n).stimuli				= 1;
% in(n).offset				= [];
% stims.stimulusTable		= in;
stims.choice 				= [];
stims.stimulusTable 		= [];

%==================================================================
%-------------allows using arrow keys to control variables?-------------
% another option is to enable manual control of a table of variables
% this is useful to probe RF properties or other features while still
% allowing for fixation or other behavioural control.
% Use arrow keys <- -> to control value and up/down to control variable
stims.controlTable			= [];
stims.tableChoice			= 1;

%==================================================================
%this allows us to enable subsets from our stimulus list
% 1 = grating | 2 = fixation cross
stims.stimulusSets			= {[2],[1,2]};
stims.setChoice				= 1;
hide(stims);

%==================================================================
% N x 2 cell array of regexpi strings, list to skip the current -> next state's exit functions; for example
% skipExitStates = {'fixate','incorrect|breakfix'}; means that if the currentstate is
% 'fixate' and the next state is either incorrect OR breakfix, then skip the FIXATE exit
% state. Add multiple rows for skipping multiple state's exit states.
sM.skipExitStates			= {'fixate','incorrect|breakfix'};

%===================================================================
%-----------------State Machine State Functions---------------------
% each cell {array} holds a set of anonymous function handles which are executed by the
% state machine to control the experiment. The state machine can run sets
% at entry, during, to trigger a transition, and at exit. Remember these
% {sets} need to access the objects that are available within the
% runExperiment context (see top of file). You can also add global
% variables/objects then use these. The values entered here are set on
% load, if you want up-to-date values then you need to use methods/function
% wrappers to retrieve/set them.

%pause entry
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
	@()disp('Leaving paused state...');
	@()startRecording(eT, true); %start recording eye position data again
}; 

prefixEntryFcn = { 
	@()needFlip(me, true, 1); % enable the screen and trackerscreen flip
	@()needEyeSample(me, true); % make sure we start measuring eye position
	@()getStimulusPositions(stims); % make a struct eT can use for drawing stim positions
	@()hide(stims); % hide all stimuli
	% update the fixation window to initial values
	@()resetFixationHistory(eT); % reset the recent eye position history
	@()resetExclusionZones(eT); % reset the exclusion zones on eyetracker
	@()updateFixationValues(eT,tS.fixX,tS.fixY,[],tS.firstFixTime); %reset fixation window
	% send the trial start messages to the eyetracker
	@()trackerTrialStart(eT, getTaskIndex(me));
	@()trackerMessage(eT,['UUID ' UUID(sM)]); %add in the uuid of the current state for good measure
};

prefixFcn = {
	@()drawBackground(s);
	@()drawPhotoDiodeSquare(s,[0 0 0]);
};

prefixExitFcn = {
	@()trackerDrawStatus(eT,'Start fix...', stims.stimulusPositions);
};

%fixate entry
fixEntryFcn = { 
	@()show(stims{2});
	@()logRun(me,'INITFIX'); %fprintf current trial info to command window
};

%fix within
fixFcn = {
	@()draw(stims); %draw stimulus
	@()drawPhotoDiodeSquare(s,[0 0 0]);
};

%test we are fixated for a certain length of time
inFixFcn = { 
	@()testSearchHoldFixation(eT,'stimulus','incorrect')
};

%exit fixation phase
fixExitFcn = { 
	@()statusMessage(eT,'Show Stimulus...');
	@()updateFixationValues(eT,[],[],[],tS.stimulusFixTime); %reset a maintained fixation of 1 second
	@()show(stims{1});
	@()trackerMessage(eT,'END_FIX');
}; 

%what to run when we enter the stim presentation state
stimEntryFcn = { 
	@()doSyncTime(me); %eyetracker sync time=0 message
	@()doStrobe(me,true);
};

%what to run when we are showing stimuli
stimFcn = {
	@()draw(stims);
	@()drawPhotoDiodeSquare(s,[1 1 1]);
	@()animate(stims); % animate stimuli for subsequent draw
};

%test we are maintaining fixation
maintainFixFcn = {
	@()testHoldFixation(eT,'correct','breakfix')
};

%as we exit stim presentation state
stimExitFcn = { 
	@()setStrobeValue(me,255); 
	@()doStrobe(me,true);
};

%if the subject is correct (small reward)
correctEntryFcn = {
	@()giveReward(rM); % send a reward TTL
	@()beep(aM,2000); % correct beep
	@()trackerMessage(eT,'END_RT');
	@()trackerMessage(eT,'TRIAL_RESULT 1');
	@()trackerClearScreen(eT);
	@()trackerDrawText(eT,'Correct! :-)');
	@()stopRecording(eT);
	@()setOffline(eT); % set eyelink offline [tobii ignores this]
	@()needEyeSample(me,false); % no need to collect eye data until we start the next trial
	@()hide(stims);
	@()logRun(me,'CORRECT'); %fprintf current trial info
};

%correct stimulus
correctFcn = { 
	@()drawPhotoDiodeSquare(s,[0 0 0]);
};

%when we exit the correct state
correctExitFcn = {
	@()updateTask(me,tS.CORRECT); %make sure our taskSequence is moved to the next trial
	@()updateVariables(me); %randomise our stimuli, and set strobe value too
	@()update(stims); %update our stimuli ready for display
	@()drawTimedSpot(s, 0.5, [0 1 0 1], 0.2, true); %reset the timer on the green spot
	@()updatePlot(bR, me); %update our behavioural plot
	@()drawnow;
	@()checkTaskEnded(me); %check if task is finished
};

%incorrect entry
incEntryFcn = { 
	@()beep(aM,tS.errorSound);
	@()trackerMessage(eT,'END_RT');
	@()trackerMessage(eT,'TRIAL_RESULT -5');
	@()trackerClearScreen(eT);
	@()trackerDrawText(eT,'Incorrect! :-(');
	@()stopRecording(eT);
	@()setOffline(eT); % set eyelink offline [tobii ignores this]
	@()needEyeSample(me,false);
	@()sendTTL(io,6);
	@()hide(stims);
	@()logRun(me,'INCORRECT'); %fprintf current trial info
}; 

%our incorrect stimulus
incFcn = {
	@()drawBackground(s);
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
	@()resetAll(eT); % resets the fixation state timers
	@()plot(bR, 1); % actually do our drawing
};

%break entry
breakEntryFcn = {
	@()beep(aM,tS.errorSound);
	@()trackerMessage(eT,'END_RT');
	@()trackerMessage(eT,'TRIAL_RESULT -1');
	@()trackerClearScreen(eT);
	@()trackerDrawText(eT,'Broke maintain fix! :-(');
	@()stopRecording(eT);
	@()setOffline(eT); % set eyelink offline [tobii ignores this]
	@()needEyeSample(me,false);
	@()sendTTL(io,5);
	@()hide(stims);
	@()logRun(me,'BREAKFIX'); %fprintf current trial info
};

%calibration function
calibrateFcn = { 
	@()setOffline(eT); % set eyelink offline [tobii ignores this]
	@()rstop(io); 
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

%debug override
overrideFcn = { @()keyOverride(me) }; %a special mode which enters a matlab debug state so we can manually edit object values

%screenflash
flashFcn = { @()flashScreen(s, 0.2) }; % fullscreen flash mode for visual background activity detection

%magstim
magstimFcn = { 
	@()drawBackground(s);
	@()stimulate(mS); % run the magstim
};

%show 1deg size grid
gridFcn = {@()drawGrid(s)};

%----------------------State Machine Table-------------------------
disp('================>> Building state info file <<================')
%specify our cell array that is read by the stateMachine
stateInfoTmp = {
'name'		'next'		'time'	'entryFcn'		'withinFcn'		'transitionFcn'	'exitFcn';
'pause'		'prefix'	inf		pauseEntryFcn	[]				[]				pauseExitFcn;
'prefix'	'fixate'	0.5		prefixEntryFcn	prefixFcn		[]				prefixExitFcn;
'fixate'	'incorrect'	5		fixEntryFcn		fixFcn			inFixFcn		fixExitFcn;
'stimulus'	'incorrect'	5		stimEntryFcn	stimFcn			maintainFixFcn	stimExitFcn;
'incorrect'	'prefix'	3		incEntryFcn		incFcn			[]				incExitFcn;
'breakfix'	'prefix'	tS.tOut	breakEntryFcn	incFcn			[]				incExitFcn;
'correct'	'prefix'	0.5		correctEntryFcn	correctFcn		[]				correctExitFcn;
'calibrate' 'pause'		0.5		calibrateFcn	[]				[]				[];
'drift'		'pause'		0.5		driftFcn		[]				[]				[];
'override'	'pause'		0.5		overrideFcn		[]				[]				[];
'flash'		'pause'		0.5		flashFcn		[]				[]				[];
'magstim'	'prefix'	0.5		[]				magstimFcn		[]				[];
'showgrid'	'pause'		10		[]				gridFcn			[]				[];
};

disp(stateInfoTmp)
disp('================>> Loaded state info file  <<================')
clear pauseEntryFcn fixEntryFcn fixFcn inFixFcn fixExitFcn stimFcn maintainFixFcn incEntryFcn ...
	incFcn incExitFcn breakEntryFcn breakFcn correctEntryFcn correctFcn correctExitFcn ...
	calibrateFcn overrideFcn flashFcn gridFcn

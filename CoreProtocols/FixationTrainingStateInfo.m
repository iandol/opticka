%FIXATION TRAINING state configuration file
%
% This presents a fixation cross with a stimulus in a loop to train for
% fixation. stims should contain 2 stimuli: stims{1} is a attention
% grabber, stims{2} is the fixation cross. Adjust stimulus sizes and
% eyetracker setting values over training to refine behaviour The following
% class objects are already loaded and available to use:
% 
%
% me		= runExperiment object ('self' in OOP terminology) 
% s			= screenManager object
% aM		= audioManager object
% stims		= our list of stimuli (metaStimulus class)
% sM		= State Machine (stateMachine class)
% task		= task sequence (taskSequence class)
% eT		= eyetracker manager
% io		= digital I/O to recording system
% rM		= Reward Manager (LabJack or Arduino TTL trigger to reward system/Magstim)
% bR		= behavioural record plot (on-screen GUI during a task run)
% uF		= user defined functions
% tS		= structure to hold general variables, will be saved as part of the data

%==================================================================
%----------------------General Settings----------------------------
tS.useTask					= true;	%==use taskSequence (randomises stimulus variables)
tS.rewardTime				= 250;		%==TTL time in milliseconds
tS.rewardPin				= 2;		%==Output pin, 2 by default with Arduino.
tS.checkKeysDuringStimulus  = true;		%==allow keyboard control within stimulus state? Slight drop in performance…
tS.recordEyePosition		= true;		%==record local copy of eye position, **in addition** to the eyetracker?
tS.askForComments			= false;	%==UI requestor asks for comments before/after run
tS.saveData					= true;		%==save behavioural and eye movement data?
tS.name						= 'fixation training'; %==name of this protocol
tS.nStims					= stims.n;	%==number of stimuli, taken from metaStimulus object
tS.tOut						= 5;		%==if wrong response, how long to time out before next trial
tS.CORRECT					= 1;		%==the code to send eyetracker for correct trials
tS.BREAKFIX					= -1;		%==the code to send eyetracker for break fix trials
tS.INCORRECT				= -5;		%==the code to send eyetracker for incorrect trials

%==================================================================
%----------------Debug logging to command window------------------
% uncomment each line to get specific verbose logging from each of these
% components; you can also set verbose in the opticka GUI to enable all of
% these…
%sM.verbose					= true;		%==print out stateMachine info for debugging
%stims.verbose				= true;		%==print out metaStimulus info for debugging
%io.verbose					= true;		%==print out io commands for debugging
eT.verbose					= true;		%==print out eyelink commands for debugging
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
tS.firstFixTime				= 0.5;
% circular fixation window radius in degrees
tS.firstFixRadius			= 5;
% do we forbid eye to enter-exit-reenter fixation window?
tS.strict					= false;
% do we add an exclusion zone where subject cannot saccade to...
tS.exclusionZone			= [];
%tS.stimulusFixTime			= 0.5;		%==time to fix on the stimulus
% historical log of X and Y position, and exclusion zone
me.lastXPosition			= tS.fixX;
me.lastYPosition			= tS.fixY;
me.lastXExclusion			= [];
me.lastYExclusion			= [];

%==================================================================
%---------------------------Eyetracker setup-----------------------
% NOTE: the opticka GUI can set eyetracker options too, if you set options here
% they will OVERRIDE the GUI ones; if they are commented then the GUI options
% are used. runExperiment.elsettings and runExperiment.tobiisettings
% contain the GUI settings; we test if they are empty or not and set
% defaults based on that...
eT.name 					= tS.name;
if tS.saveData == true;	eT.recordData = true; end %===save ET data?					
switch me.eyetracker.device
	case 'eyelink'
	if isempty(me.eyetracker.esettings)
		eT.sampleRate 				= 250; % sampling rate
		eT.calibrationStyle 		= 'HV5'; % calibration style
		eT.calibrationProportion	= [0.4 0.4]; %the proportion of the screen occupied by the calibration stimuli
		%-----------------------
		% remote calibration enables manual control and selection of each fixation
		% this is useful for a baby or monkey who has not been trained for fixation
		% use 1-9 to show each dot, space to select fix as valid, INS key ON EYELINK KEYBOARD to
		% accept calibration!
		eT.remoteCalibration		= false; 
		%-----------------------
		eT.modify.calibrationtargetcolour = [1 1 1]; % calibration target colour
		eT.modify.calibrationtargetsize = 2; % size of calibration target as percentage of screen
		eT.modify.calibrationtargetwidth = 0.15; % width of calibration target's border as percentage of screen
		eT.modify.waitformodereadytime	= 500;
		eT.modify.devicenumber 			= -1; % -1 = use any attachedkeyboard
		eT.modify.targetbeep 			= 1; % beep during calibration
	end
case 'tobii'
	if isempty(me.eyetracker.tsettings)
		eT.model					= 'Tobii Pro Spectrum';
		eT.sampleRate				= 300;
		eT.trackingMode				= 'human';
		eT.calibrationStimulus		= 'animated';
		eT.autoPace					= true;
		%-----------------------
		% remote calibration enables manual control and selection of each fixation
		% this is useful for a baby or monkey who has not been trained for fixation
		eT.manualCalibration		= false;
		%-----------------------
		eT.calPositions				= [ .2 .5; .5 .5; .8 .5 ];
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
% n								= 1;
% in(n).name						= 'xyPosition';
% in(n).values					= [6 6; 6 -6; -6 6; -6 -6; -6 0; 6 0];
% in(n).stimuli					= 1;
% in(n).offset					= [];
% stims.stimulusTable				= in;
stims.stimulusTable				= [];
stims.choice					= [];

%==================================================================
%-------------allows using arrow keys to control variables?-------------
% another option is to enable manual control of a table of variables
% this is useful to probe RF properties or other features while still
% allowing for fixation or other behavioural control.
stims.tableChoice				= 1;
n								= 1;
stims.controlTable(n).variable	= 'size';
stims.controlTable(n).delta		= 0.5;
stims.controlTable(n).stimuli	= [1 2];
stims.controlTable(n).limits	= [0.5 20];
n								= n + 1;
stims.controlTable(n).variable	= 'xPosition';
stims.controlTable(n).delta		= 1;
stims.controlTable(n).stimuli	= [1 2];
stims.controlTable(n).limits	= [-15 15];
n								= n + 1;
stims.controlTable(n).variable	= 'yPosition';
stims.controlTable(n).delta		= 1;
stims.controlTable(n).stimuli	= [1 2];
stims.controlTable(n).limits	= [-15 15];

%==================================================================
%this allows us to enable subsets from our stimulus list
stims.stimulusSets			= {[1,2]};
stims.setChoice				= 1;
hide(stims);

%==================================================================
% which stimulus in the list is used for a fixation target? For this
% protocol it means the subject must fixate this stimulus (the saccade
% target is #1 in the list) to get the reward. Also which stimulus to set
% an exclusion zone around (where a saccade into this area causes an
% immediate break fixation).
stims.fixationChoice = 2;
stims.exclusionChoice = [];

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
%--------------------enter pause state
pauseEntryFn = {
	@()hide(stims);
	@()drawBackground(s); %blank the subject display
	@()drawTextNow(s,'PAUSED, press [p] to resume...');
	@()disp('PAUSED, press [p] to resume...');
	@()trackerClearScreen(eT); % blank the eyelink screen
	@()trackerDrawText(eT,'PAUSED, press [P] to resume...');
	@()trackerFlip(eT); %for tobii show info if operator screen enabled
	@()trackerMessage(eT,'TRIAL_RESULT -100'); %store message in EDF
	@()setOffline(eT); % set eyelink offline [tobii ignores this]
	@()stopRecording(eT, true); %stop recording eye position data
	@()needFlip(me, false); % no need to flip the PTB screen
	@()needEyeSample(me,false); % no need to check eye position
};

%--------------------exit pause state
pauseExitFn = {
	@()fprintf('\n===>>>EXIT PAUSE STATE\n')
	@()needFlip(me, true); % start PTB screen flips
	@()startRecording(eT, true); % start eyetracker recording for this trial
};

%---------------------prestim entry
psEntryFn = {
	@()resetFixation(eT); %reset the fixation counters ready for a new trial
	@()resetFixationHistory(eT); %reset the fixation counters ready for a new trial
	@()startRecording(eT); % start eyelink recording for this trial
	@()trackerMessage(eT,'V_RT MESSAGE END_FIX END_RT'); % Eyelink commands
	@()trackerMessage(eT,sprintf('TRIALID %i',getTaskIndex(me))); %Eyelink start trial marker
	@()trackerMessage(eT,['UUID ' UUID(sM)]); %add in the uuid of the current state for good measure
	@()statusMessage(eT,'Pre-fixation...'); %status text on the eyelink
	@()trackerClearScreen(eT); % blank the eyelink screen
	@()trackerDrawFixation(eT); % draw the fixation window
	@()trackerFlip(eT,1); %for tobii show info if operator screen enabled
	@()needEyeSample(me,true); % make sure we start measuring eye position
	@()logRun(me,'PREFIX'); %fprintf current trial info to command window
};

%---------------------prestimulus blank
prestimulusFn = {
	@()drawBackground(s); % only draw a background colour to the PTB screen
	@()trackerDrawEyePosition(eT); % draw the fixation window
	@()trackerFlip(eT,1); %for tobii show info if operator screen enabled
};

%---------------------exiting prestimulus state
psExitFn = {
	@()show(stims); % make sure we prepare to show the stimulus set
	@()statusMessage(eT,'Stimulus...'); % show eyetracker status message
};

%---------------------stimulus entry state
stimEntryFn = {
	@()logRun(me,'SHOW Fixation Spot'); % log start to command window
};

%---------------------stimulus within state
stimFn = {
	@()draw(stims); % draw the stimuli
	@()animate(stims); % animate stimuli for subsequent draw
	@()trackerDrawEyePosition(eT); % draw the fixation window
	@()trackerFlip(eT,1); %for tobii show info if operator screen enabled
};

%-----------------------test we are maintaining fixation
maintainFixFn = {
	% this command performs the logic to search and then maintain fixation
	% inside the fixation window. The eyetracker parameters are defined above.
	% If the subject does initiate and then maintain fixation, then 'correct'
	% is returned and the state machine will move to the correct state,
	% otherwise 'breakfix' is returned and the state machine will move to the
	% breakfix state. If neither condition matches, then the state table below
	% defines that after 5 seconds we will switch to the incorrect state.
	@()testSearchHoldFixation(eT,'correct','breakfix'); 
};

%-----------------------as we exit stim presentation state
stimExitFn = {
	@()trackerMessage(eT,'END_FIX'); % tell EDF we finish fix
	@()trackerMessage(eT,'END_RT'); % tell EDF we finish reaction time
};

%-----------------------if the subject is correct (small reward)
correctEntryFn = {
	@()timedTTL(rM, tS.rewardPin, tS.rewardTime); % send a reward TTL
	@()beep(aM,2000); % correct beep
	@()trackerMessage(eT,['TRIAL_RESULT ' num2str(tS.CORRECT)]); % tell EDF trial was a correct
	@()statusMessage(eT,'Correct! :-)'); %show it on the eyelink screen
	@()trackerClearScreen(eT);
	@()trackerDrawText(eT,'Correct! :-)');
	@()trackerDrawEyePositions(eT); % draw the fixation window
	@()trackerFlip(eT); %for tobii show info if operator screen enabled
	@()stopRecording(eT); % stop recording in eyelink [tobii ignores this]
	@()setOffline(eT); % set eyelink offline [tobii ignores this]
	@()needEyeSample(me,false); % no need to collect eye data until we start the next trial
	@()logRun(me,'CORRECT'); %fprintf current trial info
};

%-----------------------correct stimulus
correctFn = {
	@()drawBackground(s); % draw background colour
	@()drawText(s,'Correct! :-)'); % draw text
};

%----------------------when we exit the correct state
correctExitFn = {
	@()updatePlot(bR, me); % update the behavioural report plot
	@()updateVariables(me,[],[],true); ... %update the task variables
	@()update(stims); ... %update our stimuli ready for display
	@()checkTaskEnded(me);
	@()drawnow; % ensure we update the figure
};

%----------------------break entry
breakEntryFn = {
	@()beep(aM,200,0.5,1);
	@()trackerClearScreen(eT);
	@()trackerDrawText(eT,'Broke fix! :-(');
	@()trackerDrawEyePositions(eT); % draw the fixation window
	@()trackerFlip(eT); %for tobii show info if operator screen enabled
	@()trackerMessage(eT,['TRIAL_RESULT ' num2str(tS.BREAKFIX)]); %trial incorrect message
	@()stopRecording(eT); % stop recording in eyelink [tobii ignores this]
	@()setOffline(eT); % set eyelink offline [tobii ignores this]
	@()needEyeSample(me,false);
	@()logRun(me,'BREAKFIX'); %fprintf current trial info
};

%----------------------inc entry
incEntryFn = { 
	@()beep(aM,200,0.5,1);
	@()trackerMessage(eT,['TRIAL_RESULT ' num2str(tS.INCORRECT)]); %trial incorrect message
	@()trackerDrawStatus(eT,'Incorrect! :-(', stims.stimulusPositions);
	@()stopRecording(eT); % stop recording in eyelink [tobii ignores this]
	@()setOffline(eT); % set eyelink offline [tobii ignores this]
	@()needEyeSample(me,false);
	@()logRun(me,'INCORRECT'); %fprintf current trial info
};

%----------------------our incorrect stimulus
breakFn =  {
	@()drawBackground(s);
	@()drawText(s,'Wrong');
};

%----------------------break exit
breakExitFn = { 
	@()updatePlot(bR, me);
	@()updateVariables(me,[],[],false); ... %update the task variables
	@()update(stims); %update our stimuli ready for display
	@()checkTaskEnded(me);
	@()drawnow;
};

%--------------------calibration function
calibrateFn = { 
	@()drawBackground(s); %blank the display
	@()stopRecording(eT); % stop recording in eyelink [tobii ignores this]
	@()setOffline(eT); % set eyelink offline [tobii ignores this]
	@()trackerSetup(eT) % enter tracker calibrate/validate setup mode
};

%--------------------drift offset function
offsetFn = { 
	@()drawBackground(s); %blank the display
	@()stopRecording(eT); % stop recording in eyelink [tobii ignores this]
	@()setOffline(eT); % set eyelink offline [tobii ignores this]
	@()driftOffset(eT) % enter tracker offset
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

%--------------------screenflash
flashFn = { 
	@()drawBackground(s);
	@()flashScreen(s, 0.2); % fullscreen flash mode for visual background activity detection
};

%----------------------allow override
overrideFn = { 
	@()keyOverride(me); 
};

%----------------------show 1deg size grid
gridFn = { 
	@()drawGrid(s); 
	@()drawScreenCenter(s);
};

% N x 2 cell array of regexpi strings, list to skip the current -> next
% state's exit functions; for example skipExitStates =
% {'fixate','incorrect|breakfix'}; means that if the currentstate is
% 'fixate' and the next state is either incorrect OR breakfix, then skip
% the FIXATE exit state. Add multiple rows for skipping multiple state's
% exit states.
sM.skipExitStates = {'fixate','incorrect|breakfix'};

%==================================================================
%----------------------State Machine Table-------------------------
% this table defines the states and relationships and function sets
%==================================================================
stateInfoTmp = {
'name'		'next'		'time' 'entryFcn'		'withinFcn'		'transitionFcn'	'exitFcn';
%---------------------------------------------------------------------------------------------
'pause'		'blank'		inf		pauseEntryFn	{}				{}				pauseExitFn;
'blank'		'stimulus'	0.5		psEntryFn		prestimulusFn	{}				psExitFn;
'stimulus'	'incorrect'	5		stimEntryFn		stimFn			maintainFixFn	stimExitFn;
'incorrect'	'timeout'	2		incEntryFn		breakFn			{}				breakExitFn;
'breakfix'	'timeout'	2		breakEntryFn	breakFn			{}				breakExitFn;
'correct'	'blank'		0.5		correctEntryFn	correctFn		{}				correctExitFn;
'timeout'	'blank'		tS.tOut	{}				{}				{}				{};
'calibrate' 'pause'		0.5		calibrateFn		{}				{}				{};
'offset'	'pause'		0.5		offsetFn		{}				{}				{};
'drift'		'pause'		0.5		driftFn			{}				{}					{};
'offset'	'pause'		0.5		offsetFcn		{}				{}					{};
'flash'		'pause'		0.5		{}				flashFn			{}				{};
'override'	'pause'		0.5		{}				overrideFn		{}				{};
'showgrid'	'pause'		1		{}				gridFn			{}				{};
};
%----------------------State Machine Table-------------------------
%==================================================================
disp('================>> Building state info file <<================')
disp(stateInfoTmp)
disp('=================>> Loaded state info file <<=================')

clearvars -regexp '.+Fn'


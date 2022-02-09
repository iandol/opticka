% FIGURE GROUND state configuration file, this gets loaded by opticka via
% runExperiment class. See Jones et al., 2015 PNAS for the description of
% this task
% 
% State files control the logic of a behavioural task, switching between
% states and executing functions on ENTER, WITHIN and on EXIT of states. In
% addition there are TRANSITION function sets which can test things like eye
% position to conditionally jump to another state. This state control file
% will usually be run in the scope of the calling runExperiment.runTask()
% method and other objects will be available at run time (with easy to use
% names listed below). The following class objects are already loaded by
% runTask() and available to use; each object has methods (functions) useful
% for running the task:
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
% tS		= structure to hold general variables, will be saved as part of the data

%==================================================================
%------------------------General Settings--------------------------
tS.useTask					= true;		%==use taskSequence (randomises stimulus variables)
tS.rewardTime				= 250;		%==TTL time in milliseconds
tS.rewardPin				= 2;		%==Output pin, 2 by default with Arduino.
tS.checkKeysDuringStimulus  = false;		%==allow keyboard control within stimulus state? Slight drop in performance…
tS.recordEyePosition		= false;	%==record local copy of eye position, **in addition** to the eyetracker?
tS.askForComments			= true;	%==UI requestor asks for comments before/after run
tS.saveData					= true;	%==save behavioural and eye movement data?
tS.includeErrors			= false;	%==do we update the trial number even for incorrect saccade/fixate, if true then we call updateTask for both correct and incorrect, otherwise we only call updateTask() for correct responses
tS.name						= 'figure-ground'; %==name of this protocol
tS.nStims					= stims.n;	%==number of stimuli, taken from metaStimulus object
tS.tOut						= 5;		%==if wrong response, how long to time out before next trial
tS.CORRECT 					= 1;		%==the code to send eyetracker for correct trials
tS.BREAKFIX 				= -1;		%==the code to send eyetracker for break fix trials
tS.INCORRECT 				= -5;		%==the code to send eyetracker for incorrect trials
tS.luminancePedestal 		= [0.5 0.5 0.5]; %used during training, it sets the clip behind the figure to a different luminance which makes the figure more salient and thus easier to train to.

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
%-----enable the magstimManager which uses FOI2 of the LabJack
if tS.useMagStim
	mS = magstimManager('lJ',rM,'defaultTTL',2);
	mS.stimulateTime	= 240;
	mS.frequency		= 0.7;
	mS.rewardTime		= 25;
	open(mS);
end

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
tS.firstFixInit				= 1;
% time to maintain fixation within window, can be single value or a range
% to randomise between
tS.firstFixTime				= [0.7 1];
% circular fixation window radius in degrees
tS.firstFixRadius			= 1;
% do we forbid eye to enter-exit-reenter fixation window?
tS.strict					= true;
% do we add an exclusion zone where subject cannot saccade to...
tS.exclusionZone			= [];
% historical log of X and Y position, and exclusion zone
me.lastXPosition			= tS.fixX;
me.lastYPosition			= tS.fixY;
me.lastXExclusion			= [];
me.lastYExclusion			= [];

% target fixation parameters
tS.targetFixInit = 1;
tS.targetFixTime = [0.5 0.7];
tS.targetRadius = 5;

%==================================================================
%---------------------------Eyetracker setup-----------------------
% NOTE: the opticka GUI can set eyetracker options too, if you set options
% here they will OVERRIDE the GUI ones; if they are commented then the GUI
% options are used. me.elsettings and me.tobiisettings contain the GUI
% settings you can test if they are empty or not and set them based on
% that...
eT.name 					= tS.name;
if tS.saveData == true;		eT.recordData = true; end %===save ET data?					
if me.useEyeLink
	eT.name 						= tS.name;
	if me.dummyMode;				eT.isDummy = true; end %===use dummy or real eyetracker? 
	if tS.saveData == true;			eT.recordData = true; end %===save EDF file?
	if isempty(me.elsettings)		%==check if GUI settings are empty
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
elseif me.useTobii
	eT.name 						= tS.name;
	if me.dummyMode;				eT.isDummy = true; end %===use dummy or real eyetracker? 
	if isempty(me.tobiisettings) 	%==check if GUI settings are empty
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
bR.correctStateName				= '^correct';
bR.breakStateName				= '^(breakfix|incorrect)';

%randomise stimulus variables every trial? useful during initial training but not for
%data collection.
stims.choice = [];
stims.stimulusTable = [];

% allows using arrow keys to control this table during the main loop
% ideal for mapping receptive fields so we can twiddle parameters, normally not used
% for normal tasks
stims.controlTable = [];
stims.tableChoice = 1;

% this allows us to enable subsets from our stimulus list. So each set is a
% particular display like fixation spot only, background. During the trial you can
% use the showSet method of stims to change to a particular stimulus set.
% numbers are the stimuli in the opticka UI
stims.stimulusSets = {[1 2 3 4],[1,4]};
stims.setChoice = 1;
hide(stims);

%which stimulus in the list is used for a fixation target? For this protocol it means
%the subject must fixate this stimulus (the figure is #3 in the list) to get the
%reward.
stims.fixationChoice = 3;

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
%pause entry
pauseEntryFcn = { 
	% hide all our stimuli
	@()hide(stims);
	% blank the subject display
	@()drawBackground(s); 
	@()drawTextNow(s,'PAUSED, press [p] to resume...');
	@()disp('PAUSED, press [p] to resume...');
	% blank the eyetracker screen
	@()trackerClearScreen(eT);
	@()trackerDrawText(eT,'PAUSED, press [P] to resume...');
	% send message to eyetracker data stream
	@()trackerMessage(eT,'TRIAL_RESULT -100');
	% make sure we set offline (only for eyelink, ignored by tobii)
	@()setOffline(eT);
	% stop recording eye position data (true means tobii also stops)
	@()stopRecording(eT, true);
	 % no need to flip the PTB screen
	@()disableFlip(me);
	% no need to check eye position
	@()needEyeSample(me,false);
};

%--------------------pause exit
pauseExitFcn = { 
	@()enableFlip(me);
	@()resumeRecording(io); %for plexon
};

%--------------------prefixate entry
prefixEntryFcn = { 
	% make sure we set offline (only for eyelink, ignored by tobii)
	@()setOffline(eT);
	%reset all fixation counters ready for a new trial
	@()resetFixation(eT);
	@()updateFixationValues(eT,tS.fixX,tS.fixY,tS.firstFixInit,tS.firstFixTime,tS.firstFixRadius);
	@()show(stims);
	@()getStimulusPositions(stims); %make a struct the eT can use for drawing stim positions
	@()trackerClearScreen(eT);
	@()trackerDrawFixation(eT); %draw fixation window on eyelink computer
	@()trackerDrawStimuli(eT,stims.stimulusPositions); %draw location of stimulus on eyelink
	@()edit(stims,4,'colourOut',[0.5 0.5 0.5]); %dim fix spot
	@()logRun(me,'PREFIX'); %fprintf current trial info
};

%--------------------prefixate
prefixFcn = { @()draw(stims); };

%--------------------prefixate exit
prefixExitFcn = {
	% messages that define trial start for eyetracker
	@()trackerMessage(eT,'V_RT MESSAGE END_FIX END_RT');
	@()trackerMessage(eT,sprintf('TRIALID %i',getTaskIndex(me)));
	@()trackerMessage(eT,['UUID ' UUID(sM)]); %add in the uuid of the current state for good measure
	%start eyelink recording eye data
	@()startRecording(eT);
	%status text on the eyetracker display
	@()statusMessage(eT,'Get Fixation...');
	@()needEyeSample(me,true);
};

%--------------------fixate entry
fixEntryFcn = { 
	% edit fixation cross to have a yellow background
	@()edit(stims,4,'colourOut',[1 1 0]); %edit fixation spot to be yellow
	% send I/O strobe for start of fixation
	@()startFixation(io);
};

%--------------------fix within
fixFcn = { 
	@()draw(stims); 
	@()drawPhotoDiode(s,[0 0 0]) 
};

%--------------------test we are fixated for a certain length of time
initFixFcn = { 
	@()testSearchHoldFixation(eT,'stimulus','incorrect');
};

%--------------------exit fixation phase
fixExitFcn = { 
	@()updateFixationTarget(me, true, tS.targetFixInit, tS.targetFixTime, tS.targetRadius); %use our stimuli values for next fix X and Y
	@()edit(stims,4,'colourOut',[0.6 0.6 0.5 0.5]); %dim fix spot
	@()trackerDrawFixation(eT);
	@()trackerMessage(eT,'END_FIX');
};

%--------------------what to run when we enter the stim presentation state
stimEntryFcn = { 
	@()doStrobe(me,true);
	@()doSyncTime(me);
};

%--------------------what to run when we are showing stimuli
stimFcn =  { 
	@()draw(stims);
	@()drawPhotoDiode(s,[1 1 1]);
	@()animate(stims); % animate stimuli for subsequent draw
};

%--------------------test we are finding target
testFixFcn = { 
	@()testSearchHoldFixation(eT,'correct','breakfix');
};

%--------------------as we exit stim presentation state
stimExitFcn = { 
	@()sendStrobe(io,255);
};

%--------------------if the subject is correct (small reward)
correctEntryFcn = { 
	@()trackerMessage(eT,'END_RT');
	@()timedTTL(rM,0,tS.rewardTime); % labjack sends a TTL to Crist reward system
	@()beep(aM,2000); % correct beep
	@()statusMessage(eT,'Correct! :-)');
	@()hide(stims{4});
	@()needEyeSample(me,false);
	@()logRun(me,'CORRECT'); %fprintf current trial info
};

%--------------------correct stimulus
correctFcn = { 
	@()draw(stims); 
	@()drawTimedSpot(s, 0.5, [0 1 0 1]);
};

%--------------------when we exit the correct state
correctExitFcn = {
	%send correct value via I/O
	@()correct(io);
	@()trackerMessage(eT,['TRIAL_RESULT ' num2str(tS.CORRECT)]);
	@()stopRecording(eT); %stops recording (eyelink, tobii ignores this)
	% tell taskSequence to update to the next trial.
	@()updateTask(task, tS.CORRECT);
	% modify our stimuli based on updated trial (find the values from
	% taskSequence and set them on metaStimulus), sets strobe value for new
	% trial (but doesn't trigger it)
	@()updateVariables(me);
	% trigger update() for each stimulus in metaStimulus to calculate
	% stimuli based on updated variables
	@()update(stims);
	@()drawTimedSpot(s, 0.5, [0 1 0 1], 0.2, true); %reset the timer on the green spot
	@()updatePlot(bR, eT, sM); %update our behavioural plot
	@()checkTaskEnded(me); %check if task is finished
	@()drawnow;
};

%--------------------incorrect entry
incEntryFcn = { 
	% send END_RT message to eyetracker
	@()trackerMessage(eT,'END_RT'); 
	@()trackerDrawText(eT,'Incorrect! :-(');
	@()beep(aM,400,0.5,1);
	% hide fixation spot
	@()hide(stims{4});
	@()needEyeSample(me,false);
	@()logRun(me,'INCORRECT'); %fprintf current trial info
}; 

%--------------------our incorrect stimulus
incFcn = { @()draw(stims); };

%--------------------incorrect / break exit
incExitFcn = { 
	@()incorrect(io);
	@()trackerMessage(eT,['TRIAL_RESULT ' num2str(tS.INCORRECT)]); %trial incorrect message
	@()stopRecording(eT); %stop eyelink recording data
	@()setOffline(eT); %set eyelink offline
	@()resetRun(task);... %we randomise the run within this block to make it harder to guess next trial
	@()updateVariables(me,[],true,false); %update the variables
	@()update(stims); %update our stimuli ready for display
	@()updatePlot(bR, eT, sM); %update our behavioural plot;
	@()checkTaskEnded(me); %check if task is finished
	@()drawnow;
};

%--------------------break entry
breakEntryFcn = { 
	@()trackerMessage(eT,'END_RT');
	@()trackerDrawText(eT,'Broke Fixation!');
	@()beep(aM,400,0.5,1);
	@()hide(stims{4});
	@()needEyeSample(me,false);
	@()logRun(me,'BREAKFIX'); %fprintf current trial info
};

%--------------------incorrect / break exit
breakExitFcn = { 
	@()breakFixation(io);
	@()trackerMessage(eT,['TRIAL_RESULT ' num2str(tS.BREAKFIX)]);
	@()stopRecording(eT);
	@()setOffline(eT); %set eyelink offline
	@()resetRun(task);... %we randomise the run within this block to make it harder to guess next trial
	@()updateVariables(me,[],true,false); %update the variables
	@()update(stims); %update our stimuli ready for display
	@()updatePlot(bR, eT, sM); %update our behavioural plot;
	@()checkTaskEnded(me); %check if task is finished
	@()drawnow;
};

%--------------------calibration function
calibrateFcn = {
	@()drawBackground(s); %blank the display
	@()stopRecording(eT); % stop eyelink recording data
	@()setOffline(eT); 
	@()rstop(io); 
	@()trackerSetup(eT);  %enter tracker calibrate/validate setup mode
};

%--------------------drift correction function
driftFcn = { 
	@()drawBackground(s); %blank the display
	@()stopRecording(eT); % stop eyelink recording data
	@()setOffline(eT); % set eyelink offline
	@()rstop(io); 
	@()driftCorrection(eT) % enter drift correct
};

%--------------------debug override
overrideFcn = { @()keyOverride(me); }; %a special mode which enters a matlab debug state so we can manually edit object values

%--------------------screenflash
flashFcn = { 
	@()drawBackground(s);
	@()flashScreen(s, 0.2); % fullscreen flash mode for visual background activity detection
};

%--------------------run magstim
magstimFcn = { 
	@()drawBackground(s);
	@()stimulate(mS); % run the magstim
};

%--------------------show 1deg size grid
gridFcn = { @()drawGrid(s); };

% N x 2 cell array of regexpi strings, list to skip the current -> next state's exit functions; for example
% skipExitStates = {'fixate',{'incorrect','breakfix'}}; means that if the currentstate is
% 'fixate' and the next state is either incorrect OR breakfix, then skip the FIXATE exit
% state. Add multiple rows for skipping multiple state's exit states.
sM.skipExitStates = {'fixate',{'incorrect','breakfix'}};

%==================================================================
%----------------------State Machine Table-------------------------
disp('================>> Building state info file <<================')
%specify our cell array that is read by the stateMachine
stateInfoTmp = {
'name'		'next'		'time'	'entryFcn'		'withinFcn'		'transitionFcn'	'exitFcn';
'pause'		'prefix'	inf		pauseEntryFcn	{}				{}				pauseExitFcn;
'prefix'	'fixate'	2		prefixEntryFcn	prefixFcn		{}				prefixExitFcn;
'fixate'	'incorrect'	2		fixEntryFcn		fixFcn			initFixFcn		fixExitFcn;
'stimulus'  'incorrect'	2		stimEntryFcn	stimFcn			testFixFcn		stimExitFcn;
'incorrect'	'prefix'	1.25	incEntryFcn		incFcn			{}				incExitFcn;
'breakfix'	'prefix'	tS.tOut	breakEntryFcn	incFcn			{}				breakExitFcn;
'correct'	'prefix'	0.5		correctEntryFcn correctFcn		{}				correctExitFcn;
'calibrate' 'pause'		0.5		calibrateFcn	{}				{}				{};
'drift'		'pause'		0.5		driftFcn		[]				[]				[];
'override'	'pause'		0.5		overrideFcn		{}				{}				{};
'flash'		'pause'		0.5		flashFcn		{}				{}				{};
'magstim'	'prefix'	0.5		{}				magstimFcn		{}				{};
'showgrid'	'pause'		10		{}				gridFcn			{}				{};
};
%----------------------State Machine Table-------------------------
%==================================================================

disp(stateInfoTmp)
disp('================>> Loaded state info file  <<================')
clear pauseEntryFcn fixEntryFcn fixFcn initFixFcn fixExitFcn stimFcn maintainFixFcn incEntryFcn ...
	incFcn incExitFcn breakEntryFcn breakFcn correctEntryFcn correctFcn correctExitFcn ...
	calibrateFcn overrideFcn flashFcn gridFcn

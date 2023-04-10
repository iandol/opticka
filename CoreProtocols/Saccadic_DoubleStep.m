%> TWOSTEP SACCADE state file, this gets loaded by opticka via 
%> runExperiment class. You can set up any state and define the logic of
%> which functions to run when you enter, are within, or exit a state.
%> Objects provide many methods you can run, like sending triggers, showing
%> stimuli, controlling the eyetracker etc.
%
%> This state file is loaded by the runExperiment class. runExperiment
%> initialises other classes that are used to control the experiment. The
%> following class objects are already loaded and available to use:
%
%> me		= runExperiment object
%> s		= screenManager
%> sM		= State Machine
%> eT		= eyetracker manager
%> task		= task sequence (taskSequence class)
%> stims	= our list of stimuli
%> io		= digital I/O to recording system
%> aM		= audioManager
%> rM		= Reward Manager (LabJack or Arduino TTL trigger to reward system/Magstim)
%> bR		= behavioural record plot (on screen GUI of trial performance during task run)
%> tL		= timeLog that records the timing of experiment
%> tS		= general struct to hold variables for this run, will be saved as part of the data

%==================================================================
%---------------------------TASK CONFIG----------------------------
% we use a up/down staircase to control the SSD, note this is controlled by
% taskSequence, so when we run task.updateTask it also updates the
% staircase for us. See Palamedes toolbox for the PAL_AM methods.
% 1up / 1down staircase starts at 225ms and steps at 47ms
assert(exist('PAL_AMUD_setupUD','file'),'MUST Install Palamedes Toolbox: https://www.palamedestoolbox.org')
task.staircase = PAL_AMUD_setupUD('down',1,'stepSizeUp',47,'stepSizeDown',47,...
					'startValue',225,'xMin',25,'xMax',475);
task.staircaseType = 'UD';
task.staircaseInvert = false; % a correct decreases value.
%do we update the trial number even for incorrect saccades, if true then we
%call updateTask for both correct and incorrect, otherwise we only call
%updateTask() for correct responses
tS.includeErrors			= false; 
% we use taskSequence to randomise which state to switch to (independent
% trial-level factor). The idea is we we call
% @()updateNextState(me,'trial') in the prefixation state; this sets one of
% these two trialVar.values as the next state. The fix1Step and fix2Step
% states will then call onestep or twostep stimulus states. Therefore we can
% call different experiment structures based on this trial-level factor.
%task.trialVar.values		= {'fix1Step','fix2Step'};
%task.trialVar.probability	= [0.6 0.4];
task.trialVar.comment		= 'one or twostep trial based on 60:40 probability';
tL.stimStateNames			= ["onestep","twostep"];

%==================================================================
%----------------------General Settings----------------------------
tS.useTask					= true; %==use taskSequence (randomises stimulus variables)
tS.rewardTime				= 250; %==TTL time in milliseconds
tS.rewardPin				= 2; %==Output pin, 2 by default with Arduino.
tS.recordEyePosition		= false; %==record eye position within PTB, **in addition** to the EDF?
tS.askForComments			= false; %==little UI requestor asks for comments before/after run
tS.saveData					= true; %==save behavioural and eye movement data?
tS.name						= 'doublestep-saccade'; %==name of this protocol
tS.nStims					= stims.n;	%==number of stimuli
tS.tOut						= 1; %if wrong response, how long to time out before next trial
tS.CORRECT 					= 1; %==the code to send eyetracker for correct trials
tS.BREAKFIX 				= -1; %==the code to send eyetracker for break fix trials
tS.INCORRECT 				= -5; %==the code to send eyetracker for incorrect trials
tS.keyExclusionPattern		= ["fixate","onestep","twostep"]; % avoid keyboard commands for these states
tS.correctSound				= [2000, 0.1, 0.1]; %==freq,length,volume
tS.errorSound				= [300, 1, 1]; %==freq,length,volume

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

%==================================================================
%-----------------INITIAL Eyetracker Settings----------------------
tS.fixX						= 0; % X position in degrees (screen center)
tS.fixY						= 0; % X position in degrees (screen center)
tS.firstFixInit				= 3; % time to search and enter fixation window
tS.firstFixTime				= [0.5 1.25]; % time to maintain fixation within window
tS.firstFixRadius			= 3; % radius in degrees
tS.strict					= true; % do we forbid eye to enter-exit-reenter fixation window?
tS.exclusionRadius			= 5; % radius of the exclusion zone...
tS.targetFixInit			= 3; % time to find the target
tS.targetFixTime			= 0.25; % to to maintain fixation on target 
tS.targetRadius				= 6; %radius to fix within.

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


%==================================================================
%----WHICH states assigned as correct or break for online plot?----
%----You need to use regex patterns for the match (doc regexp)-----
bR.correctStateName				= "correct";
bR.breakStateName				= ["breakfix","incorrect"];

%==================================================================
% N x 2 cell array of regexpi strings, list to skip the current -> next
% state's exit functions; for example skipExitStates =
% {'fixate','incorrect|breakfix'}; means that if the currentstate is
% 'fixate' and the next state is either incorrect OR breakfix, then skip
% the FIXATE exit state. Add multiple rows for skipping multiple state's
% exit states.
sM.skipExitStates			= {'fixate','incorrect|breakfix'};

%==================================================================
% which stimulus in the list is used for a fixation target? For this
% protocol it means the subject must fixate this stimulus (the saccade
% target is #1 in the list) to get the reward. Also which stimulus to set
% an exclusion zone around (where a saccade into this area causes an
% immediate break fixation).
stims.fixationChoice = [1 2];
stims.exclusionChoice = [];

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
	@()hide(stims);
	@()drawBackground(s); %blank the subject display
	@()drawText(s,'PAUSED, press [p] to resume...');
	@()flip(s);
	@()trackerClearScreen(eT); % blank the eyelink screen
	@()trackerDrawText(eT,'PAUSED, press [p] to resume...');
	@()trackerMessage(eT,'TRIAL_RESULT -100'); %store message in EDF
	@()stopRecording(eT, true); %stop recording eye position data
	@()needFlip(me, false); % no need to flip the PTB screen
	@()needEyeSample(me,false); % no need to check eye position
	@()fprintf('\n\nPAUSED, press [p] to resume...\n\n'); 
};

%pause exit
pauseExitFcn = {
	@()startRecording(eT, true); %start recording eye position data again
}; 

%====================================================PREFIXATION
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

%calibration function, can only be triggered from keyboard
calibrateFcn = { 
	@()drawBackground(s); %blank the display
	@()flip(s);
	@()trackerMessage(eT,'TRIAL_RESULT -100');
	@()stopRecording(eT, true); % stop eyelink recording data
	@()setOffline(eT); % set eyelink offline [tobii ignores this]
	@()trackerSetup(eT);  %enter tracker calibrate/validate setup mode
};

%--------------------drift correction function, can only be triggered from keyboard
driftFcn = {
	@()drawBackground(s); %blank the display
	@()flip(s);
	@()trackerMessage(eT,'TRIAL_RESULT -100');
	@()stopRecording(eT, true); % stop eyelink recording data
	@()setOffline(eT); % set eyelink offline [tobii ignores this]
	@()driftCorrection(eT) % enter drift correct (only eyelink)
};
offsetFcn = {
	@()drawBackground(s); %blank the display
	@()stopRecording(eT); % stop recording in eyelink [tobii ignores this]
	@()setOffline(eT); % set eyelink offline [tobii ignores this]
	@()driftOffset(eT) % enter drift offset (works on tobii & eyelink)
};

%debug override, can only be triggered from keyboard
overrideFcn = { @()keyOverride(me) }; %a special mode which enters a matlab debug state so we can manually inspect object values

%screenflash, can only be triggered from keyboard
flashFcn = { 
	@()drawBackground(s); %blank the display
	@()flip(s);
	@()trackerMessage(eT,'TRIAL_RESULT -100');
	@()stopRecording(eT, true); % stop eyelink recording data
	@()setOffline(eT); % set eyelink offline [tobii ignores this]
	@()flashScreen(s, 0.2) % fullscreen flash mode for visual background activity detection
};

%show 1deg size grid
gridFcn = { 
	@()drawBackground(s); %blank the display
	@()flip(s);
	@()trackerMessage(eT,'TRIAL_RESULT -100');
	@()stopRecording(eT, true); % stop eyelink recording data
	@()setOffline(eT); % set eyelink offline [tobii ignores this]
	@()drawGrid(s);
};

%==============================================================================
%----------------------State Machine Table-------------------------
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
'calibrate' 'pause'		0.5		calibrateFcn	{}				{}				{};
'drift'		'pause'		0.5		driftFcn		{}				{}				{};
'override'	'pause'		0.5		overrideFcn		{}				{}				{};
%---------------------------------------------------------------------------------------------
'flash'		'pause'		0.5		flashFcn		{}				{}				{};
'showgrid'	'pause'		10		{}				gridFcn			{}				{};
};
%----------------------State Machine Table-------------------------
%==============================================================================
disp('================>> Building state info file <<================')
disp(stateInfoTmp)
disp('=================>> Loaded state info file <<=================')
clearvars -regexp '.+Fcn$' % clear the cell array Fcns in the current workspace

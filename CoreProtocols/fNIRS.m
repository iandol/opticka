% FNIRS protocol. Doesn't use the eyetracker, runs a polar grating with
% different conditions, but we do present a fixation cross to keep the
% subject's eye's stable.
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

%=========================================================================
%-----------------------------General Settings----------------------------
% These settings make changing the behaviour of the protocol easier. tS
% is just a struct(), so you can add your own switches or values here and
% use them lower down. Some basic switches like saveData, useTask,
% enableTrainingKeys will influence the runeExperiment.runTask()
% functionality, not just the state machine. Other switches like
% includeErrors are referenced in this state machine file to change which
% functions are added to the state machine states…
tS.name						= 'FNIRS';	%==name of this protocol
tS.saveData					= true;		%==save behavioural and eye movement data?
tS.showBehaviourPlot		= true;		%==open the behaviourPlot figure? Can cause more memory use…
tS.useTask					= true;		%==use taskSequence (randomises stimulus variables)
tS.keyExclusionPattern		= ["fixate","stimulus"]; %==which states to skip keyboard checking
tS.enableTrainingKeys		= false;	%==enable keys useful during task training, but not for data recording
tS.recordEyePosition		= false;	%==record local copy of eye position, **in addition** to the eyetracker?
tS.askForComments			= false;	%==UI requestor asks for comments before/after run
tS.includeErrors			= false;	%==do we update the trial number even for incorrect saccade/fixate, if true then we call updateTask for both correct and incorrect, otherwise we only call updateTask() for correct responses
tS.nStims					= stims.n;	%==number of stimuli, taken from metaStimulus object
tS.timeOut					= 2;		%==if wrong response, how long to time out before next trial
tS.CORRECT					= 1;		%==the code to send eyetracker for correct trials
tS.BREAKFIX					= -1;		%==the code to send eyetracker for break fix trials
tS.INCORRECT				= -5;		%==the code to send eyetracker for incorrect trials
tS.correctSound				= [2000, 0.1, 0.1]; %==freq,length,volume
tS.errorSound				= [300, 1, 1];		%==freq,length,volume
% reward system values, set by GUI, but could be overridden here
%rM.reward.time				= 250;		%==TTL time in milliseconds
%rM.reward.pin				= 2;		%==Output pin, 2 by default with Arduino.

%==================================================================
%------------ ----DEBUG LOGGING to command window------------------
% uncomment each line to get specific verbose logging from each of these
% components; you can also set verbose in the opticka GUI to enable all of
% these…
%sM.verbose					= true;	%==print out stateMachine info for debugging
%stims.verbose				= true;	%==print out metaStimulus info for debugging
io.verbose					= true;	%==print out io commands for debugging
%eT.verbose					= true;	%==print out eyelink commands for debugging
%rM.verbose					= true;	%==print out reward commands for debugging
%task.verbose				= true;	%==print out task info for debugging

%==================================================================
%-----------------BEAVIOURAL PLOT CONFIGURATION--------------------
%--WHICH states assigned correct / incorrect for the online plot?--
bR.correctStateName			= "correct";
bR.breakStateName			= ["breakfix","incorrect"];

%=========================================================================
%------------------Randomise stimulus variables every trial?--------------
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
%--------------allows using arrow keys to control variables?--------------
% another option is to enable manual control of a table of variables
% in-task. This is useful to dynamically probe RF properties or other
% features while still allowing for fixation or other behavioural control.
% Use arrow keys <- -> to control value and ↑ ↓ to control variable.
stims.controlTable			= [];
stims.tableChoice			= 1;

%======================================================================
% this allows us to enable subsets from our stimulus list
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
	@()needFlip(me, false, 0); % no need to flip the PTB screen or tracker
	@()needEyeSample(me, false); % no need to check eye position
};

%--------------------pause exit
pauseExitFcn = {
	
}; 

%==============================================================
%====================================================PRE-FIXATION
%==============================================================
%--------------------prefixate entry
prefixEntryFcn = { 
	@()needFlip(me, true, 1); % enable the screen and trackerscreen flip
	@()needEyeSample(me, true); % make sure we start measuring eye position
	@()getStimulusPositions(stims); % make a struct eT can use for drawing stim positions
	@()hide(stims); % hide all stimuli
};

%--------------------prefixate within
prefixFcn = {
	@()drawPhotoDiodeSquare(s,[0 0 0]);
};

%--------------------prefixate exit
prefixExitFcn = {
	@()logRun(me,'INITFIX');
};

%==============================================================
%====================================================FIXATION
%==============================================================
%--------------------fixate entry
fixEntryFcn = { 
	@()show(stims{tS.nStims}); % show last stim which is usually fixation cross
};

%--------------------fix within
fixFcn = {
	@()draw(stims); %draw stimuli
	@()drawPhotoDiodeSquare(s,[0 0 0]);
};

%--------------------exit fixation phase
fixExitFcn = { 
	@()show(stims); % show all stims
}; 

%========================================================
%========================================================STIMULUS
%========================================================

stimEntryFcn = {
	% send stimulus value strobe (value alreadyset by updateVariables(me) function)
	@()doStrobe(me,true);
};

%--------------------what to run when we are showing stimuli
stimFcn =  {
	@()draw(stims);
	@()drawPhotoDiodeSquare(s,[1 1 1]);
	@()animate(stims); % animate stimuli for subsequent draw
};

%as we exit stim presentation state
stimExitFcn = {
	@()sendStrobe(me, 255);
};

%========================================================
%========================================================DECISIONS
%========================================================

%========================================================CORRECT
%--------------------if the subject is correct (small reward)
correctEntryFcn = {
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
	@()updatePlot(bR, me); % must run before updateTask
	@()updateTask(me, tS.CORRECT); % make sure our taskSequence is moved to the next trial
	@()updateVariables(me); % randomise our stimuli, and set strobe value too
	@()update(stims); % update our stimuli ready for display
	@()plot(bR, 1); % actually do our behaviour record drawing
};

%========================================================INCORRECT/BREAKFIX
%--------------------incorrect entry
incEntryFcn = {
	@()hide(stims);
};
%--------------------break entry
breakEntryFcn = {
	@()hide(stims);
};

%--------------------our incorrect/breakfix stimulus
incFcn = {
	@()drawPhotoDiodeSquare(s,[0 0 0]);
};

%--------------------generic exit
exitFcn = {
	% tS.includeErrors will prepend some code here...
	@()beep(aM, tS.errorSound);
	@()updateVariables(me); % randomise our stimuli, set strobe value too
	@()update(stims); % update our stimuli ready for display
	@()resetAll(eT); % resets the fixation state timers
	@()plot(bR, 1); % actually do our drawing
};

%--------------------change functions based on tS settings
% we use tS options to change the function lists run by the state machine.
% We can prepend or append new functions to the cell arrays.
%
% logRun = add current info to behaviural record
% updatePlot = updates the behavioural record
% updateTask = updates task object
% resetRun = randomise current trial within the block (makes it harder for
%            subject to guess based on previous failed trial.
% checkTaskEnded = see if taskSequence has finished
if tS.includeErrors % we want to update our task even if there were errors
	incExitFcn = [ {
		@()logRun(me,'INCORRECT');
		@()updatePlot(bR, me); 
		@()updateTask(me,tS.INCORRECT)}; 
		exitFcn ]; %update our taskSequence 
	breakExitFcn = [ {
		@()logRun(me,'BREAK_FIX'); 
		@()updatePlot(bR, me); 
		@()updateTask(me,tS.BREAKFIX)}; 
		exitFcn ]; %update our taskSequence 
else
	incExitFcn = [ {
		@()logRun(me,'INCORRECT'); 
		@()updatePlot(bR, me); 
		@()resetRun(task)}; 
		exitFcn ]; 
	breakExitFcn = [ {
		@()logRun(me,'BREAK_FIX'); 
		@()updatePlot(bR, me); 
		@()resetRun(task)}; 
		exitFcn ];
end
if tS.useTask || task.nBlocks > 0
	correctExitFcn = [ correctExitFcn; {@()checkTaskEnded(me)} ];
	incExitFcn = [ incExitFcn; {@()checkTaskEnded(me)} ];
	breakExitFcn = [ breakExitFcn; {@()checkTaskEnded(me)} ];
end

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
'prefix'	'fixate'	10		prefixEntryFcn	prefixFcn		{}				{};
'fixate'	'stimulus'	0.75	fixEntryFcn		fixFcn			{}				fixExitFcn;
'stimulus'	'correct'	10		stimEntryFcn	stimFcn			{}				stimExitFcn;
'correct'	'prefix'	0.1		correctEntryFcn	correctFcn		{}				correctExitFcn;
'incorrect'	'timeout'	0.1		incEntryFcn		incFcn			{}				incExitFcn;
'breakfix'	'timeout'	0.1		breakEntryFcn	incFcn			{}				breakExitFcn;
'timeout'	'prefix'	tS.timeOut	{}			incFcn			{}				{};
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

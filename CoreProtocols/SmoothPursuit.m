%SMOOTH PURSUIT state configuration file, loaded by runExperiment
%
% The subject fixates a central cross, then a target appears at the start of
% a Lissajous path and is animated for ~10 seconds while the subject tracks
% it with smooth pursuit eye movements. The fixation window is moved with the
% target every frame (radius ~4 deg) so that small pursuit errors are
% tolerated. Correct trials are those in which the eye spends at least
% tS.pursuitHoldTime seconds inside the moving window during the trial.
%
% The protocol expects 2 stimuli in the .mat protocol file:
%   1. the pursuit target (a small, high-contrast disc/spot works best)
%   2. the fixation cross
% SmoothPursuit.mat is provided; it was built from DotDirection.mat with
% stimulus 1 replaced by a 0.8 deg red disc and stimulus 2 kept as the
% fixation cross. Its state file is set to this file (SmoothPursuit.m).
%
% The following class objects are already loaded and available to use:
%
% me        = runExperiment object
% s         = screenManager
% aM        = audioManager
% sM        = State Machine
% task      = task sequence (taskSequence class)
% eT        = eyetracker manager
% io        = digital I/O to recording system
% rM        = Reward Manager
% bR        = behavioural record plot (on screen GUI during task run)
% stims     = our list of stimuli
% tS        = general structure to hold general variables, saved with the data

%==================================================================
%------------------------General Settings--------------------------
tS.useTask                    = false;   %==task variables are not used for this protocol
tS.rewardTime                 = 250;     %==TTL time in milliseconds
tS.rewardPin                  = 2;       %==output pin, 2 by default with Arduino
tS.keyExclusionPattern        = ["fixate","stimulus"]; %==states where keyboard control is skipped
tS.enableTrainingKeys         = true;    %==set false for actual data recording
tS.recordEyePosition          = false;   %==record local copy of eye position, in addition to the EDF
tS.askForComments             = false;   %==UI requestor asks for comments before/after run
tS.saveData                   = true;    %==save behavioural and eye movement data
tS.showBehaviourPlot          = true;    %==open the behaviourPlot figure?
tS.name                       = 'smooth pursuit'; %==name of this protocol
tS.nStims                     = stims.n; %==number of stimuli
tS.tOut                       = 1;       %==time out before the next trial after an error
tS.CORRECT                    = 1;       %==eyetracker code for correct trials
tS.BREAKFIX                   = -1;      %==eyetracker code for break fix trials
tS.INCORRECT                  = -5;      %==eyetracker code for incorrect trials
tS.correctSound               = [2000, 0.1, 0.1]; %==freq,length,volume
tS.errorSound                 = [300, 1, 1];      %==freq,length,volume

%==================================================================
%-----------------Pursuit / Lissajous parameters-------------------
% The target follows x(tau) = x0 + A.sin(a.tau + delta)
%                        y(tau) = y0 - B.sin(b.tau)
% at a constant tangential speed. With delta = 0 the target starts at the
% fixation point, so the fixation-to-pursuit transition is seamless.
tS.pursuitDuration            = 20;      %==pursuit/trial duration in seconds
tS.pursuitSpeed               = 10;      %==tangential target speed in deg/s
tS.pursuitSize                = 20;      %==peak-to-peak size of the figure in degrees
tS.pursuitA                   = 2;       %==horizontal frequency coefficient
tS.pursuitB                   = 3;       %==vertical frequency coefficient
tS.pursuitDelta               = 0;       %==phase offset in radians (0 starts at fixation)
tS.pursuitRadius              = 5;       %==moving fixation window radius in degrees
tS.pursuitHoldTime            = 9;       %==cumulative time inside the window needed for reward
tS.pursuitTimeout             = tS.pursuitDuration; %==maximum stimulus state duration

%==================================================================
%----------------Debug logging to command window-------------------
%sM.verbose                   = true;   %==print stateMachine info
%stims.verbose                = true;   %==print metaStimulus info
%eT.verbose                   = true;   %==print eyelink commands
%rM.verbose                   = true;   %==print reward commands

%==================================================================
%-----------------INITIAL Eyetracker Settings----------------------
tS.fixX                       = 0;       %==X position in degrees
tS.fixY                       = 0;       %==Y position in degrees
tS.firstFixInit               = 3;       %==time to search and enter fixation window
tS.firstFixTime               = 0.5;     %==time to maintain fixation within window
tS.firstFixRadius             = 2;       %==radius in degrees
tS.strict                     = true;    %==forbid enter-exit-re-enter during initial fixation
tS.exclusionZone              = [];      %==optional exclusion zone
eT.updateFixationValues(tS.fixX, tS.fixY, tS.firstFixInit, tS.firstFixTime, tS.firstFixRadius, tS.strict);

%==================================================================
%----which states assigned as correct or break for online plot?----
bR.correctStateName           = "correct";
bR.breakStateName             = ["breakfix","incorrect"];

%==================================================================
%-------------------randomise stimulus variables-------------------
% No randomisation is used here; the Lissajous path is fixed and configured
% by the animation manager below. Randomise tS.pursuitDelta/a/b/speed via a
% taskSequence if you want different paths across trials.
stims.choice                  = [];
stims.stimulusTable           = [];

%==================================================================
%-----------------manual control of stimulus variables-------------
stims.controlTable            = [];
stims.tableChoice             = 1;

%==================================================================
%this allows us to enable subsets from our stimulus list
% 1 = fixation cross | 2 = pursuit target
stims.stimulusSets            = {[2],[1]};
stims.setChoice               = 1;
stims.fixationChoice          = 2;       %==stimulus used as the initial fixation target
stims.exclusionChoice         = [];
hide(stims);

%==================================================================
%--------ANIMATION MANAGER: configure the Lissajous path------------
% This is the key part of the protocol: the animationManager owns the path,
% not the stimulus. Set its lissajous sub-object, then setup() generates one
% frame per display refresh at the screen frame rate. The stimulus state calls
% step(pM) each frame and copies pM.x / pM.y to the target and to the
% eyetracker fixation window.
pM = animationManager('type','lissajous', 'verbose', false, 'name', 'Smooth Pursuit');
pM.orientToPath               = false;   %==target is a disc, no need to rotate it
pM.lissajous.a                = tS.pursuitA;
pM.lissajous.b                = tS.pursuitB;
pM.lissajous.delta            = tS.pursuitDelta;
pM.lissajous.size             = tS.pursuitSize;
pM.lissajous.speed            = tS.pursuitSpeed;
pM.lissajous.totalTime        = tS.pursuitDuration;
pM.lissajous.xPosition        = 0;
pM.lissajous.yPosition        = 0;
pM.lissajous.flipY            = true;    %==standard mathematical orientation (+Y up)
pM.lissajous.useScreenFPS     = true;    %==read frame rate from the screenManager
setup(pM, s);                            %==generate the per-frame path at screen fps
fprintf('≣≣≣≣⊱ SMOOTH PURSUIT: %g:%g Lissajous, %g° path, %g°/s, %i frames (%.2fs)\n',...
	tS.pursuitA, tS.pursuitB, tS.pursuitSize, tS.pursuitSpeed, pM.nFrames, pM.lissajous.duration);

%==================================================================
% N x 2 cell array of regexpi strings, list to skip the current -> next
% state's exit functions; if the current state is 'fixate' and the next is
% 'incorrect' or 'breakfix', skip the FIXATE exit state.
sM.skipExitStates             = {'fixate','incorrect|breakfix'};

%===================================================================
%-----------------State Machine State Functions---------------------
% Each cell {array} holds anonymous functions executed by the state machine
% at entry, during, to trigger a transition, and at exit.

%pause entry
pauseEntryFcn = {
	@()hide(stims);
	@()drawBackground(s);
	@()drawTextNow(s,'PAUSED, press [p] to resume...');
	@()disp('PAUSED, press [p] to resume...');
	@()trackerClearScreen(eT);
	@()trackerDrawText(eT,'PAUSED, press [P] to resume...');
	@()trackerMessage(eT,'TRIAL_RESULT -100');
	@()setOffline(eT);
	@()stopRecording(eT, true);
	@()needFlip(me, false);
	@()needEyeSample(me,false);
};

%pause exit
pauseExitFcn = {
	@()disp('Leaving paused state...');
	@()startRecording(eT, true);
};

%prefix entry
prefixEntryFcn = {
	@()needFlip(me, true, 1);
	@()needEyeSample(me, true);
	@()startRecording(eT);
	@()getStimulusPositions(stims);
	@()hide(stims);
	@()resetAll(eT);
	@()eT.updateFixationValues(tS.fixX,tS.fixY,tS.firstFixInit,tS.firstFixTime,tS.firstFixRadius,tS.strict);
	@()trackerTrialStart(eT, getTaskIndex(me));
	@()trackerMessage(eT,['UUID ' UUID(sM)]);
	@()logRun(me,'PREFIX');
};

%prefix within
prefixFcn = {
	@()drawBackground(s);
	@()drawPhotoDiodeSquare(s,[0 0 0]);
};

%prefix exit
prefixExitFcn = {
	@()trackerDrawStatus(eT,'Start fix...', stims.stimulusPositions);
};

%fixate entry: show the fixation cross only
fixEntryFcn = {
	@()show(stims{2});
	@()hide(stims{1});
	@()logRun(me,'INITFIX');
};

%fixate within
fixFcn = {
	@()draw(stims);
	@()drawPhotoDiodeSquare(s,[0 0 0]);
};

%test we are fixated for a certain length of time
inFixFcn = {
	@()testSearchHoldFixation(eT,'stimulus','incorrect')
};

%exit fixation phase, ready for pursuit
fixExitFcn = {
	@()statusMessage(eT,'Show pursuit target...');
	@()trackerMessage(eT,'END_FIX');
	@()hide(stims);
};

%stimulus entry: rewind the path, place the target at its first point and
%initialise the moving fixation window there
stimEntryFcn = {
	@()rewind(pM);
	@()updateXY(stims{1}, pM.x, pM.y, true);
	@()eT.updateFixationValues(pM.x, pM.y, [], tS.pursuitHoldTime, tS.pursuitRadius, false);
	@()show(stims{1});
	@()hide(stims{2});
	@()doSyncTime(me);
	@()doStrobe(me,true);
	@()trackerMessage(eT,'PURSUIT_START');
};

%stimulus within: advance the Lissajous path, move the target and the
%fixation window together, then draw
stimFcn = {
	@()step(pM);
	@()updateXY(stims{1}, pM.x, pM.y, true);
	@()eT.moveFixationWindow(pM.x, pM.y);
	@()draw(stims);
	@()drawPhotoDiodeSquare(s,[1 1 1]);
	@()trackerDrawEyePosition(eT);
};

%test we are maintaining fixation inside the moving window; with
%strict = false the time inside the window accumulates across brief errors,
%and 'correct' fires when tS.pursuitHoldTime is reached
maintainFixFcn = {
	@()testHoldFixation(eT,'correct','breakfix')
};

%as we exit the stimulus state
stimExitFcn = {
	@()setStrobeValue(me,255);
	@()doStrobe(me,true);
	@()trackerMessage(eT,'PURSUIT_END');
};

%if the subject is correct (small reward)
correctEntryFcn = {
	@()giveReward(rM);
	@()beep(aM,tS.correctSound);
	@()trackerMessage(eT,'END_RT');
	@()trackerMessage(eT,['TRIAL_RESULT ' num2str(tS.CORRECT)]);
	@()trackerClearScreen(eT);
	@()trackerDrawText(eT,'Correct! :-)');
	@()trackerDrawStatus(eT,'CORRECT! :-)', stims.stimulusPositions);
	@()stopRecording(eT);
	@()setOffline(eT);
	@()needEyeSample(me,false);
	@()hide(stims);
	@()logRun(me,'CORRECT');
};

%correct stimulus
correctFcn = {
	@()drawPhotoDiodeSquare(s,[0 0 0]);
};

%when we exit the correct state
correctExitFcn = {
	@()updatePlot(bR, me);
	@()updateTask(me,tS.CORRECT);
	@()updateVariables(me);
	@()update(stims);
	@()checkTaskEnded(me);
	@()needFlip(me, false, 0);
	@()plot(bR, 1);
};

%incorrect entry
incEntryFcn = {
	@()beep(aM,tS.errorSound);
	@()trackerMessage(eT,'END_RT');
	@()trackerMessage(eT,['TRIAL_RESULT ' num2str(tS.INCORRECT)]);
	@()trackerClearScreen(eT);
	@()trackerDrawText(eT,'Incorrect! :-(');
	@()trackerDrawStatus(eT,'INCORRECT! :-(', stims.stimulusPositions, 0);
	@()stopRecording(eT);
	@()setOffline(eT);
	@()needEyeSample(me,false);
	@()hide(stims);
	@()logRun(me,'INCORRECT');
};

%our incorrect stimulus
incFcn = {
	@()drawBackground(s);
	@()drawPhotoDiodeSquare(s,[0 0 0]);
};

%incorrect exit
incExitFcn = {
	@()beep(aM,tS.errorSound);
	@()logRun(me,'INCORRECT');
	@()needFlipTracker(me, 0);
	@()updatePlot(bR, me);
	@()updateTask(me,tS.INCORRECT);
	@()updateVariables(me);
	@()update(stims);
	@()resetAll(eT);
	@()checkTaskEnded(me);
	@()plot(bR, 1);
};

%break entry
breakEntryFcn = {
	@()beep(aM,tS.errorSound);
	@()trackerMessage(eT,'END_RT');
	@()trackerMessage(eT,['TRIAL_RESULT ' num2str(tS.BREAKFIX)]);
	@()trackerClearScreen(eT);
	@()trackerDrawText(eT,'Broke fixation! :-(');
	@()trackerDrawStatus(eT,'BREAK_FIX! :-(', stims.stimulusPositions, 0);
	@()stopRecording(eT);
	@()setOffline(eT);
	@()needEyeSample(me,false);
	@()hide(stims);
	@()logRun(me,'BREAKFIX');
};

%break exit
breakExitFcn = {
	@()beep(aM,tS.errorSound);
	@()logRun(me,'BREAKFIX');
	@()needFlipTracker(me, 0);
	@()updatePlot(bR, me);
	@()updateTask(me,tS.BREAKFIX);
	@()updateVariables(me);
	@()update(stims);
	@()resetAll(eT);
	@()checkTaskEnded(me);
	@()plot(bR, 1);
};

%calibration function
calibrateFcn = {
	@()setOffline(eT);
	@()rstop(io);
	@()trackerSetup(eT);
};

%drift correction function
driftFcn = {
	@()drawBackground(s);
	@()stopRecording(eT);
	@()setOffline(eT);
	@()driftCorrection(eT);
};

%drift offset function
offsetFcn = {
	@()drawBackground(s);
	@()stopRecording(eT);
	@()setOffline(eT);
	@()driftOffset(eT);
};

%debug override
overrideFcn = { @()keyOverride(me) };

%screenflash
flashFcn = { @()flashScreen(s, 0.2) };

%show 1deg size grid
gridFcn = { @()drawGrid(s) };

%----------------------State Machine Table-------------------------
disp('================>> Building state info file <<================')
stateInfoTmp = {
'name'        'next'      'time'              'entryFcn'      'withinFcn'     'transitionFcn'     'exitFcn';
'pause'       'prefix'    inf                 pauseEntryFcn   []              []                  pauseExitFcn;
'prefix'      'fixate'    0.5                 prefixEntryFcn  prefixFcn       []                  prefixExitFcn;
'fixate'      'incorrect' 5                   fixEntryFcn     fixFcn          inFixFcn            fixExitFcn;
'stimulus'    'incorrect' tS.pursuitTimeout  stimEntryFcn    stimFcn         maintainFixFcn      stimExitFcn;
'incorrect'   'timeout'   0.25                incEntryFcn     incFcn          []                  incExitFcn;
'breakfix'    'timeout'   0.25                breakEntryFcn   incFcn          []                  breakExitFcn;
'correct'     'timeout'   0.25                correctEntryFcn correctFcn      []                  correctExitFcn;
'timeout'     'prefix'    tS.tOut             []              []              []                  [];
'calibrate'   'pause'     0.5                 calibrateFcn    []              []                  [];
'drift'       'pause'     0.5                 driftFcn        []              []                  [];
'offset'      'pause'     0.5                 offsetFcn       []              []                  [];
'override'    'pause'     0.5                 overrideFcn     []              []                  [];
'flash'       'pause'     0.5                 []              flashFcn        []                  [];
'showgrid'    'pause'     10                  []              gridFcn         []                  [];
};

disp(stateInfoTmp)
disp('================>> Loaded state info file  <<================')
clearvars -regexp '.+Fcn'

%% Demonstration of a manual state-machine-driven Opticka Behavioural Experiment. 
% Opticka is an object oriented framework/GUI for the Psychophysics
% toolbox, allowing randomised interleaved presentation of parameter
% varying stimuli specified in experimenter-relevant values. It is designed
% to work on Linux, macOS & Windows, and can interface via strobed words
% (using a cheap and very reliable LabJack), or TTLs via an Arduino, and
% ethernet with external harware for recording neurophysiological data.
%
% In this example, Stimulus objects (myStims class cell array), task
% sequence variables (myTask object), and screenManager (myScreen object)
% are passed to the runExperiment object for final display. A dummy
% eyetracker object (where the mouse input transparently replaces the eye
% movements), is used to allow behavioural control of the paradigm.
% 
% Opticka also has a UI (type `opticka` in the command window), which is a
% visual manager of the objects introduced here. The UI also controls other
% functions such as screen calibration, protocol loading/saving and
% managing communication with neurophysiological equipment via LabJack,
% Arduino and ethernet.
%
% The source of this file can be found at:
% <https://github.com/iandol/opticka/blob/master/optickaBehaviourTest.m>

%% Initial clear up of previous runs
% Make sure we start in a clean environment, not essential
clear myStims myTask myExp myScreen
sca %PTB screen clear all

%% Setup our visual stimuli
% First we use the metaStimulus class to create a stimulus manager object
% that collects and handles groups of stimuli as if they were a single
% 'thing', so for example when you use the draw method myStims.draw(), it
% tells each of its child stimuli to draw in order. You can show and hide
% each stimulus in the group and only thoses set to draw will do so. Note
% you can control each stimulus yourself (each stimulus has its own set of
% control functions), but using metaStimulus makes the code simpler...
myStims		= metaStimulus();

%%
% first stimulus is a smoothed 5° red disc
myStims{1}	= discStimulus('colour', [0.7 0 0], 'size', 5, 'sigma', 25);

%%
% second stimulus is an optimised 0.8° fixation cross from Thaler et al., 2013
myStims{2}	= fixationCrossStimulus('size', 0.8);

%% Task Initialisation
% The taskSequence class defines a stimulus sequence (task) which is
% composed of randomised stimulus parameter changes (called variables)
% repeated over a set of blocks. A trial is an individual stimulus
% presentation. This
%
% For behavioural tasks, several of the parameters like myTask.trialTime
% are not used as the state machine takes over the job of task timing, but
% the stimulus randomisation is still useful for such tasks. In this case
% the state info file can use taskSequence to deterimine the next stimulus
% value. There are functions to handle what happens if the subject responds
% incorrectly, where we can re-randomise the next value within the block.

myTask					= taskSequence('nBlocks', 3); %new taskSequence object instance

%%
% Our variable is xPosition, applied to stimulus 1 only.
myTask.nVar(1).name		= 'xPosition';
myTask.nVar(1).stimulus	= 1;
myTask.nVar(1).values	= [-10 0 10];

%%
% We call the method to randomise the trials in a block structure
randomiseTask(myTask);

%%
% Lets print out a table of the stimulus values for every trial
showLog(myTask);

%% Setup screenManager Object
% screenManager controls the PTB Screen(). We initialise the object with
% parameters to open the PTB screen with. Note distance and pixels
% per cm define the resultant geometry > pixel mappings. You can set
% several screen parameters, windowing, blending etc.
myScreen = screenManager('distance', 57.3,... %display distance from observer
	'pixelsPerCm', 32,... %calibration value for pixel density, measure using calibrateSize()
	'windowed', [900 700],... % use fullscreen [] or window [X Y]?
	'backgroundColour', [0.5 0.5 0.5],... %initial background colour
	'blend', true,... %enable OpenGL blending, you can also set blend modes when needed
	'bitDepth', '8bit'); %FloatingPoint32bit, 8bit, FloatingPoint16bit etc.

%% Setup runExperiment Object
% We now pass our stimulus, screen and task objects to the runExperiment
% class. runExperiment contains the runTask() method that actually runs the
% behavioural task.
%
% Importantly, the stateInfoFile 'FixationTrainingStateInfo.m' determines
% the behavioural protocol that the state machine will run. The state
% machine is available as myExp.stateMachine. Read through that StateInfo
% file to better understand what is being done. stateInfoFiles contain some
% general configuration, then a set of cell-arrays of functions, and a
% table of states which run these function arrays as the states are entered
% and exited. For this simple task, it starts in a paused state, then
% transitions to a blank period, then the stimulus presentation, where
% initiating and maintaining fixation on the cross leads to a correct state
% or breaking fixation leads to breakFix state, then the state machine loops
% back to blank etc. using the myTask object to set variable values on each
% trial.
myExp = runExperiment('stimuli', myStims,... %stimulus objects
	'screen', myScreen,... %screen manager object
	'task', myTask,... % task randomised stimulus sequence
	'stateInfoFile', 'DefaultStateInfo.m', ... % state info file
	'debug', true,... % enable debug mode for testing
	'verbose', false, ... % disable verbose output in the command window
	'useEyeLink', true, ... %use the eyelink manager
	'dummyMode', true, ... % use dummy mode so the mouse replaces eye movements for testing
	'comment', 'This is a test behavioural run', ... % comment
	'subjectName', 'Simulcra', ... % subject name
	'researcherName', 'Joanna Doe');

%% Run the behavioural task
%
runTask(myExp);

%% Plot a timing log of every frame against the stimulus on/off times
%
showTimingLog(myExp);

%% Plot a timing log of all states and their function evaluation transition times
%
showLog(myExp.stateMachine);
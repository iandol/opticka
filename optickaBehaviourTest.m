%% Demo of a state-machine-driven Opticka Behavioural Experiment. 
% Opticka is an object-oriented framework for the Psychophysics toolbox
% (PTB), allowing randomised interleaved presentation of parameter varying
% stimuli specified in experimenter-relevant values. It operates under
% Linux (PTB's preferred OS), macOS & Windows, and can interface via
% strobed words (using  Display++, VPixx or a cheap and very reliable
% LabJack), or TTLs via low-cost Arduino. It uses ethernet to connect with
% Tobii or Eyelink eyetrackers and with with external harware for recording
% neurophysiological data.
%
% In this demo, two stimulus objects (wrapped in a myStims manager object),
% task sequence variables (myTask object), and a screenManager (myScreen
% object) are passed to the runExperiment class. runExperiment uses the
% stateMachine class object which loads the experiment specification  (for
% this demo it uses DefaultStateInfo.m)
%
% DefaultStateInfo.m specifies the following experiment with six states
% (prefix, fixate, stimulus, correct, incorrect, breakfix), and uses the
% eyetracker (here using the mouse functions to transition from fixate.
%  
%     ┌───────────────────────────────────────┐
%     │                                       ▼
%     │                                     ┌───────────────────────────┐
%  ┌──┼───────────────────────────────────▶ │          (1) prefix       │ ◀┐
%  │  │                                     └───────────────────────────┘  │
%  │  │                                       │                            │
%  │  │                                       ▼                            │
%  │┌───────────┐ Transition                ┌───────────────────────────┐  │
%  ││ incorrect │ inFixFcn=>incorrect       │          fixate           │  │
%  ││           │◀───────────────────────── │ show(stims, 2)            │  │
%  │└───────────┘                           └───────────────────────────┘  │
%  │                                          │                            │
%  │                                          │ Transition                 │
%  └──┐                                       │ inFixFcn=>stimulus         │
%     │                                       ▼                            │
%   ┌───────────┐ Transition                ┌───────────────────────────┐  │
%   │  CORRECT  │ maintainFixFcn=>correct   │         stimulus          │  │
%   │           │◀───────────────────────── │ show(stims, [1 2])        │  │
%   └───────────┘                           └───────────────────────────┘  │
%                                             │                            │
%                                             │ Transition                 │
%                                             │ maintainFixFcn=>breakfix   │
%                                             ▼                            │
%                                           ┌───────────────────────────┐  │
%                                           │         BREAKFIX          │ ─┘
%                                           └───────────────────────────┘
%  
% For this demo a dummy eyetracker object (where the mouse input
% transparently replaces the eye movements), is used to demonstrate
% behavioural control of the paradigm.
% 
% Opticka also offers an optional GUI (type `opticka` in the command window),
% which is a visual manager of the objects introduced here. The UI also
% controls other functions such as screen calibration, protocol
% loading/saving and managing communication with neurophysiological
% equipment via LabJack, Arduino and ethernet.
%
% *The source of this file can be found at* :
% <https://github.com/iandol/opticka/blob/master/optickaBehaviourTest.m>

%% Initial clear up of any previous objects
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
myStims			= metaStimulus();

%%
% first stimulus is a smoothed 5° red disc
myStims{1}		= discStimulus('colour', [0.7 0.2 0], 'size', 5, 'sigma', 20);

%%
% second stimulus is an optimised 0.8° fixation cross from Thaler et al., 2013
myStims{2}		= fixationCrossStimulus('size', 0.8);

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
myTask					= taskSequence(); %new taskSequence object instance

%%
% Our variable is xPosition, applied to stimulus 1 only. 3 different
% position values so 3 trials per block...
myTask.nVar(1).name		= 'xPosition';
myTask.nVar(1).stimulus	= 1;
myTask.nVar(1).values	= [-10 0 10];

%%
% We call the method to randomise the trials into a block (3 blocks, 3
% trials) structure.
myTask.nBlocks			= 3;
randomiseTask(myTask);

%%
% Lets print out a table of the stimulus values for every trial to be run
showLog(myTask);

%% Setup screenManager Object
% screenManager controls the PTB Screen(). We initialise the object with
% parameters to open the PTB screen with. Note distance and pixels
% per cm define the resultant geometry > pixel mappings. You can set
% several screen parameters, windowing, blending etc.
myScreen = screenManager('distance', 57.3,... % display distance from observer
	'pixelsPerCm', 27,... % calibration value for pixel density, measure using calibrateSize()
	'windowed', [],... % use fullscreen [] or window [X Y]?
	'backgroundColour', [0.5 0.5 0.5],... % initial background colour
	'blend', true,... % enable OpenGL blending, you can also set blend modes when needed
	'bitDepth', '8bit'); % FloatingPoint32bit, 8bit, FloatingPoint16bit etc.
% use retina mode for macOS
if ismac; myScreen.useRetina = true; end

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
	'stateInfoFile', 'DefaultStateInfo.m', ... % use the default state info file
	'debug', false,... % debug mode for testing?
	'useEyeLink', true, ... % use the eyelink manager
	'dummyMode', true, ... % use dummy mode so the mouse replaces eye movements for testing
	'subjectName', 'Simulcra', ...
	'researcherName', 'Joanna Doe');

%% Run the full behavioural task
% 
runTask(myExp);

%% Plot a timing log of every frame against the stimulus on/off times
% PTB has the most reliable and precise timing control of any experimental
% control system, and we therefore log every flip time alongside the stimulus
% transitions. The timing log shows every recorded frame in relation to the
% stimulus transitions.
showTimingLog(myExp);

%% Plot a timing log of all states and their function evaluation transition times
% The state machine also records the timestamps when states are entered and
% exited. In addition, it times how long each cell array of functions take
% to run on enter/within/exit, to check for any potential timing problems
% (you do not want enter/within states to take too long in case it causes
% frame drops, this can be seen via these plots).
showLog(myExp.stateMachine);
% Demonstration of a command-driven setup of an Opticka Behavioural Experiment.
% Opticka is an object oriented framework/GUI for the
% Psychophysics toolbox, allowing randomised interleaved presentation of 
% parameter varying stimuli specified in experimenter-relevant values. 
% It is designed to work on OS X, Windows (currently no digital I/O) 
% or Linux, and can interface via strobed words (using a cheap and 
% very reliable LabJack) and ethernet with external harware for 
% recording neurophysiological data.
% In this example, Stimulus objects (myStims class cell array), 
% stimulus sequence variables (myTask object), and 
% screenManager (myScreen object) are passed to the
% runExperiment object for final display. Opticka also has a UI (type
% opticka in the command window), which is a visual manager of the objects
% introduced here. The UI also controls other functions such as
% calibration, protocol loading/saving and communication with
% neurophysiological equipment via LabJack and ethernet. There is also an
% independent receptive field mapper (rfMapper) that uses mouse control to probe
% receptive fields and generate drawn hand maps.
%
% The source of this file can be found at:
% <https://github.com/iandol/opticka/blob/master/optickaBehaviourTest.m>

%% Initial clear up of previous runs
% Make sure we start in a clean environment, not essential
clear myStims myTask rExp myScreen
sca %PTB screen clear all

% First we create a stimulus manager object that collects and handles groups of
% stimuli as if they were a single 'thing', so for example when you use the
% draw method on a metaStimulus myStims.draw(), it tells each of its child stimuli to draw in order
myStims = metaStimulus();

myStims{1}=discStimulus

myStims{2}=spotStimulus

%% Setup screenManager Object
% we initialise the object with parameter options to open the PTB screen
% with. Note distance and pixels per cm define the resultant geometry >
% pixel mappings. You can set several screen parameters, windowing,
% blending etc. hideFlash uses a trick from Mario to set the CLqUT to the
% task background colour so you don't see the black flash on PTB screen
% initialisation.
myScreen = screenManager('distance', 57.3,... %display distance from observer
	'pixelsPerCm', 32,... %calibration value for pixel density, measure using calibrateSize()
	'backgroundColour', [0.5 0.5 0.5],... %initial background colour
	'blend', true,... %enable OpenGL blending, you can also set blend modes when needed
	'srcMode', 'GL_ONE',... %src blend mode
	'dstMode', 'GL_ZERO',... %dst blend mode
	'windowed', [],... %set to a widthxheight for debugging i.e. [800 600]; set to empty for fullscreen
	'antiAlias', 0,... %can be set to 4 or 8x oversampling with no dropped frames on macOS ATI 5870
	'bitDepth', 'FloatingPoint32bitIfPossible',... %8bit, FloatingPoint16bit FloatingPoint32bit etc.
	'displayPPRefresh', 120); %ensure refresh is 120Hz if a Display++ is attached

%% Setup runExperiment Object
% We now pass our stimulus screen and sequence objects to the
% runExperiment class. runExperiment contains the run() method that actually
% runs the task.
rExp = runExperiment('stimuli', myStims,... %stimulus objects
	'screen', myScreen,... %screen manager object
	'stateInfoFile', '~/Code/opticka/CoreProtocols/FixationTrainingStateInfo.m', ...
	'debug', false,... %disable debug mode
	'verbose', false, ...
	'useEyelink', true, ...
	'dummyMode', true, ...
); %minimal verbosity

runTask(rExp);

% Plot a timing log of every frame against the stimulus on/off times:
getRunLog(rExp);
%% Demonstration of a command-driven setup of an Opticka Experiment.
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
% <https://github.com/iandol/opticka/blob/master/optickatest.m>

%% Initial clear up of previous runs
% Make sure we start in a clean environment, not essential
clear myStims myTask myScreen rExp
sca %PTB screen clear all

%% Stimulus Initialisation
% These set up the 10 different stimuli. Please note that values are in
% degrees, cycles/deg, deg/s etc. Colour is repestend using floating point
% values from 0 - 1 and all objects accept an opacity (alpha) value.
% Each stimulus is a class object with a series of properties ('sf',
% 'colour' etc.) that you can set up by simply passing property name : value pairs 
% into the stimulus class. You can also pass these in as a structure if you prefer. 
% If you do not pass any properties, default values will be used without problems.

%%
% First we create a stimulus manager that collects and handles groups of
% stimuli as if they were a single 'thing', so for example when you use the
% draw method on a stimulus manager, it tells each of its child stimuli to
% draw in turn
myStims = metaStimulus();

%%
% The first six stimuli are gratings / gabors of varying kinds.
myStims{1}=gratingStimulus('sf',1,'contrast',1,'size',1,'tf',0,'angle',30,...
	'gabor', false, 'mask', true);

myStims{2}=gratingStimulus('sf',3,'contrast',0.5,'tf',1,'size',3,'xPosition',-3,...
	'yPosition',-4,'gabor', false,'mask', false);

myStims{3}=gratingStimulus('sf',1,'contrast',1,'size',3,'angle',45,'xPosition',5,...
	'yPosition',5,'mask', true, 'sigma', 30);

myStims{4}=gratingStimulus('sf',1,'contrast',0.5,'tf',0,'size',2,'xPosition',-3,...
	'yPosition',-3,'gabor',false,'mask',true,'speed',2);

myStims{5}=gratingStimulus('sf',1,'contrast',0.25,'colour',[0.6 0.3 0.3],'tf',0.1,...
	'size',2,'xPosition',3,'yPosition',0);

%%
% This is a color grating where two colours can be specified
myStims{6}=colourGratingStimulus('sf',1,'contrast',0.75,'colour',[1 0 0],'colour2',[0 1 0],...
	'tf',1,'size',3,'xPosition',4,'yPosition',-4);

%%
% A simple bar: bars can be solid in colour or have random texture 
% (try setting 'type' to 'random'). This is an opaque solid yellow bar 
% moving at 4deg/s. Notice the startPosition is -4; 
% this means start -4 degrees "behind" start X and Y position, as
% the stimulus is displayed for 2 seconds the bar therefore traverses
% 4degrees behind then 4 degrees past the X and Y position. Also note as we
% will change the angle of this stimulus the geometry is calculated for you
% automatically!
myStims{7}=barStimulus('type','solid','barWidth',1,'barLength',4,'speed',4,'xPosition',0,...
	'yPosition',0,'startPosition',-4,'colour',[.9 .7 .5]);

%%
% coherent dot stimulus; 200 dots moving at 1deg/s with coherence set to 0.5
myStims{8}=dotsStimulus('density',50,'speed',1,'coherence',0.5,'xPosition',4,...
	'yPosition',6,'colour',[1 1 1],'dotType',3,'dotSize',0.1,'colorType','randomBW');

%%
% a simple circular spot, spots can also flash if needed
myStims{9}=discStimulus('speed',2,'xPosition',4,'type','flash',...
	'yPosition',4,'colour',[1 1 0],'size',2,'flashTime',[0.2 0.2]);

%%
% a texture stimulus, by default this loads a picture from the opticka
% stimulus directory; you can rotate it, scale it etc and drift it across screen as
% in this case. Size is in degrees, scaling the whole picture
myStims{10}=textureStimulus('speed',2,'xPosition',-10,...
	'yPosition',10,'size',1);

%%
% a movie stimulus, by default this loads a movie from the opticka
% stimulus directory; you can rotate it, scale it etc and drift it across screen as
% in this case. Size is in degrees, scaling the whole movie
myStims{11}=movieStimulus('speed',2,'xPosition',10,'yPosition',10,...
	'mask',[0 0 0],'size',1);

%% Task Initialisation
% The stimulusSequence class defines a stimulus sequence (task) which is composed
% of randomised stimulus parameter changes (called variables) repeated over
% a set of blocks. A trial is an individual stimulus presentation. This
% example has three different variables changing over 3*2*2 values (12 unique trials) which is
% then repeated over 2 blocks for 24 trials in total
myTask = stimulusSequence; %new stimulusSequence object instance
myTask.nBlocks = 2; %number of blocks
myTask.trialTime = 2; %time of stimulus display: 2 seconds
myTask.isTime = 0.25; %inter trial time: 0.25 seconds
myTask.ibTime=0.5; %inter block time: 1 second
myTask.realTime = false; %we use real time for switching trials, false uses a tick timer updated every flip

%% Variable 1
% Our first variable is angle, applied to stimulus 1 3 7 and 10, randomly
% selected from values of 0 45 and 90 degrees
myTask.nVar(1).name = 'angle';
myTask.nVar(1).stimulus = [1 3 7 10];
myTask.nVar(1).values = [0 45 90];

%% Variable 2
% Our second variable is contrast, applied to stimulus 2 and 3, randomly
% selected from values of 0.025 and 0.1
myTask.nVar(2).name = 'contrast';
myTask.nVar(2).stimulus = [2 3];
myTask.nVar(2).values = [0.1 0.4];

%% Variable 3
% Our third variable is X position, applied to stimulus 2 and 8, randomly
% selected from values of -3 and 3 degrees from visual center of screen
myTask.nVar(3).name = 'xPosition';
myTask.nVar(3).stimulus = [2 8];
myTask.nVar(3).values = [-5 5];
% the next two parameters allow us to link a stimulus with
% an offset; for example you could set stimulus 1 to values [1 2 3]
% and if offsetvalue was 2 and offsetstimulus was 2 then the second
% stimulus would change through [3 4 5]; in this case we offset stimulus 10
% to +1 the values above i.e. [-2 4]
myTask.nVar(3).offsetstimulus = [10];
myTask.nVar(3).offsetvalue = [1];

%% Randomisation
% We call the method to randomise the trials in a block structure
randomiseStimuli(myTask);

%% Visual Trial List
% Lets print out a table of the stimulus properties for every trial
showLog(myTask);

%% Setup screenManager Object
% we initialise the object with parameter options to open the PTB screen
% with. Note distance and pixels per cm define the resultant geometry >
% pixel mappings. You can set several screen parameters, windowing,
% blending etc. hideFlash uses a trick from Mario to set the CLUT to the
% task background colour so you don't see the black flash on PTB screen
% initialisation.
myScreen = screenManager('distance', 57.3,... %display distance from observer
	'pixelsPerCm', 27.5,... %calibration value for screen size/pixel density, see calibrateSize()
	'srcMode', 'GL_ONE',...
	'dstMode', 'GL_ONE',...
	'blend', false,... %enable OpenGL blending, you can also set blend modes when needed
	'windowed', [ ],... %set to a widthxheight for debugging i.e. [800 600]; set to false for fullscreen
	'antiAlias', 0,... %can be set to 4 or 8x oversampling with no dropped frames on OS X ATI 5870
	'bitDepth', 'FloatingPoint32bitIfPossible',... %8bit, FloatingPoint16bit FloatingPoint32bit etc.
	'displayPPRefresh', 100, ... %set refresh to 100Hz only if Dispay++ attached
	'hideFlash', false); %mario's gamma trick

%% Setup runExperiment Object
% We now pass our stimulus screen and sequence objects to the
% runExperiment class. runExperiment contains the run() method that actually
% runs the task.
rExp = runExperiment('stimuli', myStims,... %stimulus objects
	'task', myTask,... %task design object
	'screen', myScreen,... %screen manager object
	'debug', false,... %setup screen to complain about sync errors etc.
	'verbose', false); %minimal verbosity

%%
% run our experiment, to exit early, press [q] during the blank period.
run(rExp);

%%
% Plot a timing log of every frame against the stimulus on/off times:
getRunLog(rExp);

%%
% The image above is a graphical timing plot of every frame and whether any frames
% were dropped during stimulus presentation. This will not consider
% dropped frames during the GPU warming or inter trial time as dropped as the display is
% blank and we are using absolute time values for our trial transitions.
% Opticka actually resets and updates the stimulus objects on the second
% and subsequent frames of the inter trial blank, this forces any computation of
% stimulus parameter to when it doesn't matter; but note
% for complex stimuli a frame or two may be dropped during the blank and so
% ensure you set the inter trial time > than the dropped frame delay!
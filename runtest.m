%% Demonstration of a command-driven setup of an Opticka Experiment.
% Opticka is an object oriented framework/GUI for the
% Psychophysics toolbox, allowing randomised interleaved presentation of 
% parameter varying stimuli specified in experimenter-relevant values. 
% It is designed to work on OS X, Windows (currently no digital I/O) 
% or Linux, and can interface via strobed words (using a cheap and 
% very reliable LabJack) and ethernet with external harware for 
% recording neurophysiological data.
% In this example, Stimulus objects (myStim class cell array), 
% stimulus sequence variables (myTask object), and 
% screenManager (myScreen object) are passed to the
% runExperiment object for final display. Opticka also has a UI (type
% opticka in the command window), which is a visual manager of the objects
% introduced here. The UI also controls other functions such as
% calibration, protocol loading/saving and communication with
% neurophysiological equipment via LabJack and ethernet.
% The source of this file can be found at:
% <http://bazaar.launchpad.net/~iandol/opticka/master/view/head:/runtest.m>

%% Initial clear up of previous runs
% Make sure we start in a clean environment, not essential
clear myStim myTask myScreen rExp

%% Stimulus Initialisation
% These set up the 10 different stimuli. Please note that values are in
% degrees, cycles/deg, deg/s etc. Colour is repestend using floating point
% values from 0 - 1 and all objects accept an opacity (alpha) value.
% Each stimulus is a class object with a series of properties ('sf',
% 'colour' etc.) that you can set up by simply passing property name : value pairs 
% into the stimulus class. You can also pass these in as a structure if you prefer. 
% If you do not pass any properties, default values will be used without problems.

%%
% The first six stimuli are gratings / gabors of varying kinds.
myStim{1}=gratingStimulus('sf',1,'contrast',0.5,'size',1,'tf',0,'angle',30,...
	'gabor', 0, 'mask', 1);

myStim{2}=gratingStimulus('sf',3,'contrast',0.5,'tf',1,'size',3,'xPosition',-3,...
	'yPosition',-3,'gabor',1,'mask',0);

myStim{3}=gratingStimulus('sf',1,'contrast',0.5,'size',3,'angle',45,'xPosition',-2,...
	'yPosition',2,'gabor',0,'mask',1,'speed',2);

myStim{4}=gratingStimulus('sf',1,'contrast',0.5,'tf',0,'size',2,'xPosition',-3,...
	'yPosition',-3,'gabor',0,'mask',1,'speed',2);

myStim{5}=gratingStimulus('sf',1,'contrast',0.25,'colour',[0.6 0.3 0.3],'tf',0.1,...
	'size',2,'xPosition',3,'yPosition',0,'gabor',0,'mask',0);

myStim{6}=gratingStimulus('sf',1,'contrast',0.5,'colour',[0.4 0.4 0.6],'tf',1,...
	'driftDirection',-1,'size',2,'xPosition',4,'yPosition',-4,'gabor',0,'mask',1);

%%
% A simple bar: bars can be solid in colour or have random texture. This
% is an opaque solid yellow bar moving at 4deg/s. Notice the startPosition
% is -4; this means start -4 degrees "behind" start X and Y position, as
% the stimulus is displayed for 2 seconds the bar therefore traverses
% 4degrees behind then 4 degrees past the X and Y position. Also note as we
% will change the angle of this stimulus the geometry is calculated for you
% automatically!
myStim{7}=barStimulus('type','solid','barWidth',1,'barLength',4,'speed',4,'xPosition',0,...
	'yPosition',0,'startPosition',-4,'colour',[.7 .7 .7]);

%%
% coherent dot stimulus; 200 dots moving at 1deg/s with coherence set to 0.5
myStim{8}=dotsStimulus('nDots',200,'speed',1,'coherence',0.5,'xPosition',4,...
	'yPosition',-6,'colour',[1 1 1],'dotSize',0.1,'colorType','randomBW');

%%
% a simple circular spot, spots can also flash if needed
myStim{9}=spotStimulus('speed',2,'xPosition',4,'type','flash',...
	'yPosition',4,'colour',[1 1 0],'size',1,'flashTime',[0.2 0.2]);

%%
% a texture stimulus, by default this loads a picture from the opticka
% stimulus directory; you can rotate it, scale it etc and drift it across screen as
% in this case
myStim{10}=textureStimulus('speed',2,'xPosition',-6,...
	'yPosition',6,'size',0.5);

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
myTask.ibTime=1; %inter block time: 1 second

%% Variable 1
% Our first variable is angle, applied to stimulus 1 3 7 and 10, randomly
% selected from values of 0 45 and 90 degrees
myTask.nVar(1).name = 'angle';
myTask.nVar(1).stimulus = [1 3 7 10];
myTask.nVar(1).values = [0 45 90];
myTask.nVar(1).offsetstimulus = [];
myTask.nVar(1).offsetvalue = [];

%% Variable 2
% Our second variable is contrast, applied to stimulus 2 and 3, randomly
% selected from values of 0.025 and 0.1
myTask.nVar(2).name = 'contrast';
myTask.nVar(2).stimulus = [2 3];
myTask.nVar(2).values = [0.1 0.4];
myTask.nVar(2).offsetstimulus = [];
myTask.nVar(2).offsetvalue = [];

%% Variable 3
% Our third variable is X position, applied to stimulus 2 and 8, randomly
% selected from values of -3 and 3 degrees from visual center of screen
myTask.nVar(3).name = 'xPosition';
myTask.nVar(3).stimulus = [2 8];
myTask.nVar(3).values = [-3 3];
% the next two parameters allow us to link a stimulus with
% an offset; for example you could set stimulus 1 to values [1 2 3]
% and if offsetvalue was 2 and offsetstimulus was 2 then the second
% stimulus would change through [3 4 5]; in this case we offset stimulus 10
% to +1 the values above i.e. [-2 4]
myTask.nVar(3).offsetstimulus = [10];
myTask.nVar(3).offsetvalue = [1];

%% Randomisation
% We call the method to randomise the trials in a block structure
myTask.randomiseStimuli();

%% Visual Trial List
% Lets print out a log of the stimulus properties for every trial
myTask.showLog();

%% Setup screenManager Object
% we initialise the object with parameter options to open the PTB screen
% with. Note distance and pixels per cm define the resultant geometry >
% pixel mappings. You can set several screen parameters, windowing,
% blending etc. hideFlash uses a trick from Mario to set the CLUT to the
% task background colour so you don't see the black flash on PTB screen
% initialisation.
myScreen = screenManager('distance', 57.3, 'pixelsPerCm', 44, 'blend', true,...
	'windowed', 0, 'antiAlias', 0, 'bitDepth', '8bit', 'hideFlash', true);

%% Setup runExperiment Object
% We now pass our stimulus screen and sequence objects to the
% runExperiment class. runExperinet contains the run class that actually
% runs the task.
rExp = runExperiment('stimulus', myStim, 'task', myTask, 'screen', myScreen,...
	'debug', false, 'verbose', true);

%%
% previous screens should have closed automatically, but just in case!
Screen('CloseAll')

%%
% run our experiment, to exit early, press the right (OS X) or middle (Win/Linux) mouse
% button
rExp.run();

%%
% Note after this is run, because 'verbose' property of runExperient was
% true we automatically will get a graphical timing plot of every frame and whether any frames
% were dropped during stimulus presentation. This will not consider
% dropped frames during the GPU warming or inter trial time as dropped as the display is
% blank and we are using absolute time values for our trial transitions.
% Opticka actually resets and updates the stimulus objects on the second
% and subsequent frames of the inter trial blank, this forces any computation of
% stimulus parameter to when it doesn't matter; but note
% for complex stimuli a frame or two may be dropped during the blank and so
% ensure you set the inter trial time > than the dropped frame delay!
%% Demonstration of a command-driven setup of an Opticka MOC Experiment.
% Opticka is an object-oriented framework plus optional GUI for the
% Psychophysics toolbox, allowing randomised interleaved presentation of
% parameter-varying stimuli specified in experimenter-relevant values. It
% is designed to work on Linux, macOS or Windows and can interface via
% strobed words and ethernet with external harware for recording
% neurophysiological data.
%
% In this example of a Methods of Constants (MOC) experiment, stimulus
% objects (myStims object), stimulus sequence (myTask object), and
% screenManager (myScreen object) are passed to the runExperiment class to
% run the experiment.
% 
% Opticka also has a UI (type opticka in the command window), which is a
% visual manager of the objects introduced here. The UI also controls other
% functions such as calibration, protocol loading/saving and communication
% with neurophysiological equipment via LabJack and ethernet. There is also
% an independent receptive field mapper (rfMapper) that uses mouse control
% to probe receptive fields for vision experiments and generates drawn hand
% maps.
%
% The source of this file can be found at:
% <https://github.com/iandol/opticka/blob/master/optickatest.m>

%% Initial clear up of previous runs
% Make sure we start in a clean environment, not essential
clear myStims myTask myExp myScreen
sca %PTB screen clear all

%% Stimulus Initialisation
% Set up 11 different stimuli. Values are in
% degrees, cycles/deg, deg/s etc. Colour is represented using floating point
% values from 0 - 1 and all objects accept an opacity (alpha) value.
% Each stimulus is a class object with a series of properties ('sf',
% 'colour' etc.) that you can set up by simply passing property name : value pairs 
% into the stimulus class. You can also pass these in as a structure if you prefer. 
% If you do not pass any properties, default values will be used without problems.

%%
% First we create a stimulus manager object that collects and handles groups of
% stimuli as if they were a single 'thing', so for example when you use the
% draw method on a metaStimulus myStims.draw(), it tells each of its child stimuli to draw in order
myStims = metaStimulus();

%%
% Stimului are made using stimulus classes. Each class inherits from
% baseStimulus, which has 5 abstract classes ALL stimuli must implement:
% [1] SETUP(screenManager) - takes a screenManager and sets up the
% stimulus properties ready for display.
% [2] DRAW() - draws the stimulus
% [3] ANIMATE() - for each stimulus class, animate takes speed, tf etc. and
% updates the position onscreen for the next flip.
% [4] UPDATE() - if any parameters have changed (size, position, colour
% etc.), then update ensures all properties are properly updated.
% [5] RESET() - returns the object back to its pre-setup state.
%
%The first few stimuli are gratings / gabors of varying kinds.
myStims{1}=gratingStimulus('sf', 1, 'tf', 0, 'phase', 90, 'contrast', 0.7, ...
	'size', 2, 'angle', -45, 'mask', false, ...
	'name', 'Standard grating');

myStims{2}=gaborStimulus('sf', 1, 'contrast', 0.75, 'tf', 3, 'size', 3, 'angle', -70,...
	'aspectRatio', 0.5, 'xPosition', 5, 'yPosition', -5,...
	'name', 'Gabor');

myStims{3}=gratingStimulus('sf', 2, 'tf', 4, 'contrast', 0.7, 'size', 3, 'angle', 45,...
	'xPosition', 0, 'yPosition', -10, 'mask', true, 'sigma', 30,...
	'name', 'Edge-smoothed grating');

myStims{4}=gratingStimulus('type', 'square', 'sf', 1, 'contrast', 1, ...
	'colour', [0.5 0.5 0.5], 'tf', 0,...
	'size', 3, 'xPosition', 6, 'yPosition', 0, ...
	'phaseReverseTime',0.33, ...
	'name', 'Squarewave grating');

%%
% This is log gabor filtered noise, based on code shared by Steve Dakin
% You can control the orientation / SF filtering, and pass an image
% through it, or let it create a random texture. It can phase reverse using
% an invert GLSL shader on the texture.
myStims{5}=logGaborStimulus('size', 3, 'xPosition', 0,'yPosition', -5,...
	'sfPeak', 3, 'sfSigma', 0.05, 'angleSigma', 20, 'seed', 5,...
	'phaseReverseTime',0.33, ...
	'name', 'Log Gabor Filtered Noise');

%%
% This is a colour grating where two independant colours can be modulated
% relative to a base colour, in this case this is a red/green grating
% modulating from 0.5 background grey.
myStims{6}=colourGratingStimulus('colour', [1 0 0 1], 'colour2', [0 1 0 1],...
	'baseColour', [0.5 0.5 0.5], 'tf', 1, 'size', 3, 'xPosition', -6, 'yPosition', 0,...
	'name', 'Red/green grating');

%%
% coherent dot stimulus; 200 dots moving at 2deg/s with coherence set to 0.25
myStims{7}=dotsStimulus('density',50,'coherence',0.25,'xPosition',4,...
	'yPosition',6,'dotType',3,'dotSize',0.1,'colorType','randomBW','mask',true,...
	'name','Coherent dots');

%%
% A simple bar: bars can be solid in colour or have checkerboard/random texture 
% (try setting 'type' to 'random' etc.). This is a bar moving at 4deg/s. 
% Notice the startPosition is -4; this means start -4 degrees "behind" X and Y position, as
% the stimulus is displayed for 2 seconds the bar therefore traverses
% 4 degrees behind then 4 degrees past the X and Y position (i.e. drift a bar over a RF location)
% Also note as we will change the angle of this stimulus the geometry is calculated for you
% automatically!
myStims{8}=barStimulus('type','checkerboard','sf',2,'barWidth',1,'barHeight',4,...
	'speed',4,'xPosition',0,'yPosition',0,'startPosition',-4,'phaseReverseTime',0.33,...
	'name','Checkerboard bar');

%%
% an edge-smoothed spot; spots can also flash if needed
myStims{9}=discStimulus('type','flash','speed',2,'xPosition',4,'sigma',40,...
	'yPosition',4,'colour',[1 1 0],'flashColour',[0 0 1],'size',3,'flashTime',[0.2 0.15],...
	'name','Flashing disc');

%%
% a picture stimulus, by default this loads a picture from the opticka
% stimulus directory; you can rotate it, scale it etc and drift it across screen as
% in this case. Size is in degrees, scaling the whole picture
myStims{10}=imageStimulus('speed',2,'xPosition',-10,'yPosition',10,'size',4,...
	'name','Image');

%%
% a movie stimulus, by default this loads a movie from the opticka
% stimulus directory; you can rotate it, scale it etc and drift it across screen as
% in this case. Size is in degrees, scaling the whole movie
myStims{11}=movieStimulus('speed', 1, 'xPosition', -7, 'yPosition', -10,...
	'size', 4, 'enforceBlending', true,...
	'name', 'AVI transparent movie');

%% Task Initialisation
% The taskSequence class defines a stimulus sequence (task) which is composed
% of randomised stimulus parameter changes (called variables) repeated over
% a set of blocks. A trial is an individual stimulus presentation. This
% example has three different variables changing over 3*2*2 values (12 unique trials) which is
% then repeated over 2 blocks for 24 trials in total.
%
% NOTE: for more complex behavioural tasks, Opticka uses a finite state machine to generate flexible
% experimental protocols, see stateMachine() for more details.
myTask = taskSequence(); %new taskSequence object instance
myTask.nBlocks = 2; %number of blocks
myTask.trialTime = 2; %time of stimulus display: 2 seconds
myTask.isTime = 0.25; %inter-trial time: 0.25 seconds
myTask.ibTime=0.5; %inter-block time: 1 second
myTask.realTime = true; %we use real time for switching trials, false uses a tick timer updated every flip

%% Variable 1
% Our first variable is angle, applied to 4 stimuli, randomly
% selected from values of 0 45 and 90 degrees
myTask.nVar(1).name = 'angle';
myTask.nVar(1).stimulus = [1 3 8 10 11];
myTask.nVar(1).values = [0 45 90];
% the next two parameters allow us to link a stimulus with
% an offset; for example you could set stimulus 1 to values [1 2 3]
% and if offsetvalue was 2 and offsetstimulus was 2 then the second
% stimulus would change through [3 4 5]; 
myTask.nVar(1).offsetstimulus = [5 6];
myTask.nVar(1).offsetvalue = 90;

%% Variable 2
% Our second variable is contrast, applied to stimuli 2 / 3 / 5, randomly
% selected from values of 0.025 and 0.1
myTask.nVar(2).name = 'contrast';
myTask.nVar(2).stimulus = [2 3 5];
myTask.nVar(2).values = [0.15 0.55];

%% Variable 3
% Our third variable is X position, applied to stimulus 2 and 7, randomly
% selected from values of -3 and 3 degrees from visual center of screen
myTask.nVar(3).name = 'xPosition';
myTask.nVar(3).stimulus = [2 7];
myTask.nVar(3).values = [-6 6];
% the next two parameters allow us to link a stimulus with
% an offset; for example you could set stimulus 1 to values [1 2 3]
% and if offsetvalue was 2 and offsetstimulus was 2 then the second
% stimulus would change through [3 4 5]; in this case we offset stimulus 10
% to +1 the values above i.e. [-4 8]
myTask.nVar(3).offsetstimulus = 10;
myTask.nVar(3).offsetvalue = 2;

%% Randomisation
% We call the method to randomise the trials in a block structure
randomiseTask(myTask);

%% Setup screenManager Object
% we initialise the object with parameter options to open the PTB screen
% with. Note distance and pixels per cm define the resultant geometry >
% pixel mappings. You can set several screen parameters, windowing,
% blending etc. hideFlash uses a trick from Mario to set the CLqUT to the
% task background colour so you don't see the black flash on PTB screen
% initialisation.
myScreen = screenManager('distance', 57.3,... %display distance from observer
	'pixelsPerCm', 36,... %calibration value for pixel density, measure using calibrateSize()
	'backgroundColour', [0.5 0.5 0.5],... %initial background colour
	'blend', true,... %enable OpenGL blending, you can also set blend modes when needed
	'debug', false,... %enable debug mode?
	'windowed', [],... %set to a widthxheight for debugging i.e. [800 600]; set to empty for fullscreen
	'bitDepth', '8bit');
if ismac; myScreen.useRetina = true; end

%% Setup runExperiment Object
% We now pass our stimulus screen and sequence objects to the
% runExperiment class. runExperiment contains the runMOC() method that actually
% runs the task.
myExp = runExperiment('stimuli', myStims,... %stimulus objects
	'task', myTask,... %task design object
	'screen', myScreen,... %screen manager object
	'debug', false,... %use debug mode?
	'verbose', false); %minimal verbosity

%%
% run our method of constants (MOC) experiment; 
% to exit early, press [q] during the interstimulus period.
opts.askForComments = false;
runMOC(myExp, opts);

%% Visual Trial List
% Lets print out a table of the stimulus properties for every trial
showLog(myTask);

%%
% Plot a timing log of every frame against the stimulus on/off times:
showTimingLog(myExp);

%%
% The image above is a graphical timing plot of every frame and whether any frames
% were dropped during stimulus presentation. This will not consider
% dropped frames during the GPU warming or inter trial time as dropped as the display is
% blank and we are using absolute time values for our trial transitions.
% Opticka actually resets and updates the stimulus objects on the second
% and subsequent frames of the inter trial blank, this forces any computation of
% stimulus parameter to when it doesn't matter; but note
% for complex stimuli a frame or two may be dropped during the blank and so
% ensure you set the inter trial time > than the dropped frames!

%% Manual control
% You don't need to use opticka's stimuli via runExperiment(), you can
% use them in your own experiments, lets have a quick look here, set
% runThis to true to run the following code:

runThis = false;
if ~runThis; return; end

% We'll use the movie stimulus, and run it on its own, using its methods
% to draw() and animate() in a standard PTB loop
WaitSecs('YieldSecs',2);
reset(myStims); % reset them back to their defaults

%stimulus
myMovie = myStims{11}; % the movie stimulus from above
myMovie.xPosition = 0; myMovie.yPosition = 0;
myMovie.speed = 5;
myMovie.size = 0; %if size is zero, then native dimensions are used.
myMovie.direction = 45; %you can specify the motion direction seperate from texture angle
myMovie.enforceBlending = false; %not needed as screen will use correct blending mode

% screen settings
myScreen.backgroundColour = [1 0 0];
myScreen.srcMode = 'GL_SRC_ALPHA';
myScreen.dstMode = 'GL_ONE_MINUS_SRC_ALPHA';
open(myScreen); %open a screen
setup(myMovie, myScreen); %setup the stimulus with the screen configuration
for i = 1:myScreen.screenVals.fps*2
	draw(myMovie);
	finishDrawing(myScreen);
	animate(myMovie);
	flip(myScreen);
end
reset(myMovie);
close(myScreen);
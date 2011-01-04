%make sure we start in a clean environment, not essential
Screen('CloseAll')
clear stim s r
WaitSecs(0.2);

%These set up the stimuli, values in degrees, cycles/deg, deg/s etc.
stim.g(1)=gratingStimulus(struct('sf',1,'contrast',0.6,'size',1,'tf',0,'gabor',0,...
	'mask',1,'verbose',0));

stim.g(2)=gratingStimulus(struct('sf',1,'contrast',0.5,'size',3,'angle',45,'xPosition',-2,...
	'yPosition',2,'gabor',0,'mask',1,'speed',2));

stim.g(3)=gratingStimulus(struct('sf',3,'contrast',0.6,'tf',1,'colour',[0.5 0.5 0.5 1],'size',3,'xPosition',-2,...
	'yPosition',-4,'gabor',1,'mask',0));

stim.g(4)=gratingStimulus(struct('sf',1,'contrast',0.6,'tf',0,'size',1,'xPosition',-3,...
	'yPosition',3,'gabor',0,'mask',0,'speed',2));

stim.g(5)=gratingStimulus(struct('sf',1,'contrast',0.4,'colour',[0.6 0.3 0.3 1],'tf',0.1,...
	'size',2,'xPosition',3,'yPosition',0,'gabor',0,'mask',0));

stim.g(6)=gratingStimulus(struct('sf',1,'contrast',0.5,'colour',[0.6 0.4 0.4 0.5],'tf',1,...
	'driftDirection',-1,'size',2,'xPosition',4,'yPosition',4,'gabor',0,'mask',1));

stim.b(1)=barStimulus(struct('type','solid','barWidth',1,'barLength',4,'speed',2,'xPosition',0,...
	'yPosition',0,'startPosition',-2,'colour',[1 1 0 1]));

stim.d(1)=dotsStimulus(struct('nDots',200,'speed',1,'coherence',0.5,'xPosition',4,...
	'yPosition',-4,'colour',[1 1 1 1],'dotSize',0.1,'colorType','randomBW'));

stim.s(1)=spotStimulus(struct('speed',2,'xPosition',4,...
	'yPosition',4,'colour',[1 1 0 1],'size',1));

%stimulus sequence allows us to vary parameters and run blocks of trials
s = stimulusSequence;
s.nTrials = 2;
s.nSegments = 1;
s.trialTime = 2;
s.isTime = 0.25;
s.itTime=1;
s.nVar(1).name = 'angle';
s.nVar(1).stimulus = [1 3 7];
s.nVar(1).values = [0 45 90];
s.nVar(2).name = 'contrast';
s.nVar(2).stimulus = [2 3];
s.nVar(2).values = [0.025 0.1];
s.nVar(3).name = 'xPosition';
s.nVar(3).stimulus = [2 8];
s.nVar(3).values = [-3 3];

%we call the routine to randomise trials in a block structure
s.randomiseStimuli;

%% ss is the object which interfaces with the screen and runs our
%% experiment
r=runExperiment(struct('distance',57.3,'pixelsPerCm',44,'blend',1,...
	'stimulus',stim,'task',s,'windowed',1,'antiAlias',4,'debug',1,'hideFlash',0,'verbose',1));
%r.run
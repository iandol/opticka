%An example state configuration file  for runExperiment.runTrainingSession. 
%This controls a stateMachine instance, switching between these states and 
%executing functions. This will be run in the scope of the calling
%runTrainingSession function and thus obj.screen and obj.metaStimulus will
%be present.
disp('================>> Loading state info file <<================')

%obj.screen is the screenManager the opens the PTB screen
blankFcn = {{@drawBackground, obj.screen};{@drawFixationPoint, obj.screen}};
%obj.metaStimulus is the stimuli loaded into opticka
stimFcn = {@draw, obj.metaStimulus};
stimEntry = {@update, obj.metaStimulus};
correctFcn = {{@draw, obj.metaStimulus}; {@drawGreenSpot, obj.screen}};
incorrectFcn = {{@drawBackground, obj.screen}; {@drawRedSpot, obj.screen}};

stateInfoTmp = { ...
	'name'      'next'		'time'  'entryFcn'	'withinFcn'		'exitFcn'; ...
	'pause'		'preblank'	inf		[]			[]				[]; ...
	'preblank'  'stimulus'  2		[]			blankFcn		[]; ...
	'stimulus'  'incorrect'	3		stimEntry	stimFcn			[]; ...
	'incorrect' 'preblank'	0.75    []			incorrectFcn	[]; ...
	'correct'	'preblank'  1.5		stimEntry	correctFcn		[]; ...
};

disp(stateInfoTmp)
disp('================>> Loaded state info file  <<================')
clear blankFcn stimFcn stimEntry correctFcn incorrectFcn
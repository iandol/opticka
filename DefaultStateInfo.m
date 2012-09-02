%An example state configuration file  for runExperiment.runTrainingSession. 
%This controls a stateMachine instance, switching between these states and 
%executing functions. This will be run in the scope of the calling
%runTrainingSession function and thus obj.screen and obj.metaStimulus will
%be present.
disp('================>> Loading state info file <<================')

prestimulusFcn = { @()drawBackground(obj.screen) ; @()drawFixationPoint(obj.screen) }; %obj.screen is the screenManager the opens the PTB screen
stimFcn = @() draw(obj.stimuli); %obj.stimuli is the stimuli loaded into opticka
stimEntry = @() update(obj.stimuli);
correctFcn = { @() draw(obj.stimuli) ; @() drawGreenSpot(obj.screen) };
incorrectFcn = { @() drawBackground(obj.screen) ; @() drawRedSpot(obj.screen) };

stateInfoTmp = { ...
	'name'      'next'			'time'  'entryFcn'	'withinFcn'		'exitFcn'; ...
	'pause'		'prestimulus'	inf		[]			[]				[]; ...
	'prestimulus' 'stimulus'	2		[]			prestimulusFcn	[]; ...
	'stimulus'  'incorrect'		3		stimEntry	stimFcn			[]; ...
	'incorrect' 'prestimulus'	0.75    []			incorrectFcn	[]; ...
	'correct'	'prestimulus'	1.5		stimEntry	correctFcn		[]; ...
};

disp(stateInfoTmp)
disp('================>> Loaded state info file  <<================')
clear preblankFcn stimFcn stimEntry correctFcn incorrectFcn
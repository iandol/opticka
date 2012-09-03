%An example state configuration file  for runExperiment.runTrainingSession. 
%This controls a stateMachine instance, switching between these states and 
%executing functions. This will be run in the scope of the calling
%runTrainingSession function and thus obj.screen and obj.metaStimulus will
%be present.
disp('================>> Loading state info file <<================')

singleStimulus = true;

if singleStimulus == true
	obj.stimList = 1:obj.stimuli.n;
	obj.thisStim = 1;
else
	obj.stimList = [];
	obj.thisStim = [];
end

prestimulusFcn = { @()drawBackground(obj.screen) ; @()drawFixationPoint(obj.screen) }; %obj.screen is the screenManager the opens the PTB screen
stimFcn = @() draw(obj.stimuli); %obj.stimuli is the stimuli loaded into opticka
stimEntry = @() update(obj.stimuli);
correct1Fcn = { @() timedTTL(obj.lJack,0,100); @() draw(obj.stimuli) ; @() drawGreenSpot(obj.screen) };
correct2Fcn = { @() timedTTL(obj.lJack,0,500); @() draw(obj.stimuli) ; @() drawGreenSpot(obj.screen) };
incorrectFcn = { @() drawBackground(obj.screen) ; @() drawRedSpot(obj.screen) };

singleStimulus = true;

stateInfoTmp = { ...
	'name'      'next'			'time'  'entryFcn'	'withinFcn'		'exitFcn'; ...
	'pause'		'prestimulus'	inf		[]			[]				[]; ...
	'prestimulus' 'stimulus'	2		[]			prestimulusFcn	[]; ...
	'stimulus'  'incorrect'		3		stimEntry	stimFcn			[]; ...
	'incorrect' 'prestimulus'	0.75    []			incorrectFcn	[]; ...
	'correct1'	'prestimulus'	1.5		stimEntry	correct1Fcn		[]; ...
	'correct2'	'prestimulus'	1.5		stimEntry	correct2Fcn		[]; ...
};

disp(stateInfoTmp)
disp('================>> Loaded state info file  <<================')
clear preblankFcn stimFcn stimEntry correctFcn incorrectFcn
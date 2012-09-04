%An example state configuration file  for runExperiment.runTrainingSession. 
%This controls a stateMachine instance, switching between these states and 
%executing functions. This will be run in the scope of the calling
%runTrainingSession function and thus obj.screen and obj.metaStimulus will
%be present.
disp('================>> Loading state info file <<================')

% do we want to present a single stimulus at a time?
singleStimulus = true;

if singleStimulus == true
	obj.stimList = 1:obj.stimuli.n;
	obj.thisStim = 1;
else
	obj.stimList = [];
	obj.thisStim = [];
end
obj.stimuli.choice = obj.thisStim;

%these are our functions that will execute as the stateMachine runs
prestimulusFcn = { @()drawBackground(obj.screen) ; @()drawFixationPoint(obj.screen) }; %obj.screen is the screenManager the opens the PTB screen
stimFcn = @() draw(obj.stimuli); %obj.stimuli is the stimuli loaded into opticka
stimEntry = {@() printChoice(obj.stimuli); @() update(obj.stimuli)};
stimExit = { @() printChoice(obj.stimuli)};
correctEntry1 = { @() printChoice(obj.stimuli); @() timedTTL(obj.lJack,0,100) };
correctEntry2 = { @() printChoice(obj.stimuli); @() timedTTL(obj.lJack,0,500) };
correctWithin = {@() draw(obj.stimuli) ; @() drawGreenSpot(obj.screen) };
correctExit = @() randomiseTrainingList(obj); 
incorrectFcn = { @() drawBackground(obj.screen) ; @() drawRedSpot(obj.screen) };


%specify our cell array that is read by the stateMachine
stateInfoTmp = { ...
	'name'      'next'			'time'  'entryFcn'		'withinFcn'		'exitFcn'; ...
	'pause'		'prestimulus'	inf		[]				[]				[]; ...
	'prestimulus' 'stimulus'	2		[]				prestimulusFcn	[]; ...
	'stimulus'  'incorrect'		3		stimEntry		stimFcn			stimExit; ...
	'incorrect' 'prestimulus'	0.75    []				incorrectFcn	[]; ...
	'correct1'	'prestimulus'	1.5		correctEntry1	correctWithin	correctExit; ...
	'correct2'	'prestimulus'	1.5		correctEntry2	correctWithin	correctExit; ...
};

disp(stateInfoTmp)
disp('================>> Loaded state info file  <<================')
clear singleStimulus preblankFcn stimFcn stimEntry correct1Fcn correct2Fcn incorrectFcn
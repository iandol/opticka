%Fixation Training state configuration file 
%This controls a stateMachine instance, switching between these states and 
%executing functions. This will be run in the scope of the calling
%runFixationSession function and thus obj.screen and friends will be
%available at run time.

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

obj.eyeLink.fixationX = 0;
obj.eyeLink.fixationX = 0;
obj.eyeLink.fixationTime = 0.1;
obj.eyeLink.fixationRadius = 2;
obj.eyeLink.fixationInitTime = 1;

Beeper();

%these are our functions that will execute as the stateMachine runs
%prestimulus blank
prestimulusFcn = @()drawBackground(obj.screen);
%what to run when we enter the stim presentation state
stimEntryFcn = { @()update(obj.stimuli); @()resetFixation(obj.eyeLink); };
%what to run when we are showing stimuli
stimFcn = @()draw(obj.stimuli); %obj.stimuli is the stimuli loaded into opticka
%test we are maintaining fixation
maintainFixFcn = @()testSearchHoldFixation(obj.eyeLink,'correct','breakfix');
%as we exit stim presentation state
stimExitFcn = { @()printChoice(obj.stimuli); @()resetFixation(obj.eyeLink) };
%if the subject is correct (small reward)
correctEntry = { @()draw(obj.stimuli); @()timedTTL(obj.lJack,0,400); @()Beeper; };
%correct stimulus
correctWithin = @()draw(obj.stimuli);
%when we exit the correct state
correctExit = @()randomiseTrainingList(obj);
%our incorrect stimulus
incorrectFcn = @()drawBackground(obj.screen);

disp('================>> Loading state info file <<================')
%specify our cell array that is read by the stateMachine
stateInfoTmp = { ...
'name'      'next'			'time'  'entryFcn'		'withinFcn'		'transitionFcn'	'exitFcn'; ...
'pause'		'prestimulus'	inf		[]				[]				[]				[]; ...
'prestimulus' 'stimulus'	5		[]				prestimulusFcn	[]				[]; ...
'stimulus'  'breakfix'		3		stimEntryFcn	stimFcn			maintainFixFcn	stimExitFcn; ...
'breakfix'	'prestimulus'	1.5		[]				incorrectFcn	[]				[]; ...
'correct'	'prestimulus'	1.5		correctEntry	correctWithin	[]				correctExit; ...
};

disp(stateInfoTmp)
disp('================>> Loaded state info file  <<================')
clear initFixFcn maintainFixFcn prestimulusFcn singleStimulus ...
	preblankFcn stimFcn stimEntry correct1Fcn correct2Fcn ...
	incorrectFcn
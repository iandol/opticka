%Default state configuration file for runExperiment.runTrainingSession. 
%This controls a stateMachine instance, switching between these states and 
%executing functions. This will be run in the scope of the calling
%runTrainingSession function and thus obj.screen and friends will be
%available at run time.
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

obj.useEyeLink = true;

%these are our functions that will execute as the stateMachine runs
%prestimulus blank
preFcn = { @()drawBackground(obj.screen); ...
	@()drawFixationPoint(obj.screen) }; 
%reset the fixation time values
preEntryFcn = @()resetFixation(obj.eyeLink);
%exit prestimulus
preExit = @()update(obj.stimuli);
%what to run when we are showing stimuli
stimFcn = {@()draw(obj.stimuli); @()drawEyePosition(obj.eyeLink) }; %obj.stimuli is the stimuli loaded into opticka
%what to run when we enter the stim presentation state
stimEntryFcn = [];
%as we exit stim presentation state
stimExitFcn = { @()printChoice(obj.stimuli); @()resetFixation(obj.eyeLink) };
%if the subject is correct (small reward)
correctEntry1 = @()timedTTL(obj.lJack,0,100);
%if the subject is correct (big reward)
correctEntry2 = @()timedTTL(obj.lJack,0,500);
%correct stimulus
correctWithin = { @()draw(obj.stimuli); @()drawGreenSpot(obj.screen,1) };
%when we exit the correct state
correctExit = { @()randomiseTrainingList(obj); };
%our incorrect stimulus
incorrectFcn = { @()drawBackground(obj.screen) ; @()drawRedSpot(obj.screen,1) };
%test we are maintaining fixation
maintainFixFcn = @()testWithinFixationWindow(obj.eyeLink,'','breakfix');
%test we are fixated for a certain length of time
initFixFcn = @()testFixationTime(obj.eyeLink,'stimulus','');

%specify our cell array that is read by the stateMachine
stateInfoTmp = { ...
'name'      'next'			'time'  'entryFcn'		'withinFcn'		'transitionFcn'	'exitFcn'; ...
'pause'		'prestimulus'	inf		[]				[]				[]				[]; ...
'prestimulus' 'incorrect'	3		[]				preFcn			initFixFcn		[]; ...
'stimulus'  'correct1'		3		stimEntryFcn	stimFcn			maintainFixFcn	stimExitFcn; ...
'incorrect' 'prestimulus'	1	    []				incorrectFcn	[]				[]; ...
'breakfix'	'prestimulus'	1		[]				incorrectFcn	[]				[]; ...
'correct1'	'prestimulus'	1.5		correctEntry1	correctWithin	[]				correctExit; ...
'correct2'	'prestimulus'	1.5		correctEntry2	correctWithin	[]				correctExit; ...
};

disp(stateInfoTmp)
disp('================>> Loaded state info file  <<================')
clear initFixFcn maintainFixFcn prestimulusFcn singleStimulus ...
	preblankFcn stimFcn stimEntry correct1Fcn correct2Fcn ...
	incorrectFcn
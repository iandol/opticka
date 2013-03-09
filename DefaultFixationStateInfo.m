%DEFAULT Fixation Training state configuration file, this gets loaded by opticka via runExperiment class
% io = datapixx (digital I/O to plexon)
% s = screenManager
% sM = State Machine
% eL = eyelink manager
% lJ = LabJack (reward trigger to Crist reward system)
% bR = behavioural record plot
% obj.stimuli = our list of stimuli
%
%------------General Settings-----------------
rewardTime = 200; %TTL time in milliseconds

luminancePedestal = [0.6 0.6 0.6];
fixX = 0;
fixY = 0;
firstFixInit = 0.6;
firstFixTime = [0.4 0.7];
firstFixRadius = 1.4;

targetFixInit = 0.5;
targetFixTime = 0.3;
targetRadius = 15;

eL.name = 'figure-ground';
eL.isDummy = false; %use dummy or real eyelink?
eL.sampleRate = 250;
eL.remoteCalibration = true; % manual calibration?
eL.calibrationStyle = 'HV9'; % calibration style
eL.recordData = false; % save EDF file?
eL.modify.calibrationtargetcolour = [1 1 0];
eL.modify.calibrationtargetsize = 1;
eL.modify.calibrationtargetwidth = 0.01;
eL.modify.waitformodereadytime = 500;
eL.modify.devicenumber = -1; % -1 = use any keyboard

% X, Y, FixInitTime, FixTime, Radius, StrictFix
eL.updateFixationValues(fixX, fixY, firstFixInit, firstFixTime, firstFixRadius, true);

%randomise stimulus variables every trial?
obj.stimuli.choice = [];
n = 1;
in(n).name = 'xyPosition';
in(n).values = [10 10; 10 -10; -10 10; -10 -10; -10 0; 10 0];
in(n).stimuli = [2 3];
in(n).offset = [3; 180];
n = n + 1;
in(n).name = 'angle';
in(n).values = [0 180];
in(n).stimuli = [1];
in(n).offset = [3; 180];

obj.stimuli.stimulusTable = in;
clear in

% allows using arrow keys to control this table during the main loop
% ideal for mapping receptive fields so we can twiddle parameters
n = 1;
in(n).variable = 'angle';
in(n).delta = 15;
in(n).stimuli = [1 2];
in(n).limits = [0 360];
n = n + 1;
in(n).variable = 'size';
in(n).delta = 1;
in(n).stimuli = [1 2];
in(n).limits = [1 60];
n = n + 1;
in(n).variable = 'barLength';
in(n).delta = 0.5;
in(n).stimuli = [2];
in(n).limits = [1 30];

obj.stimuli.controlTable = in;
obj.stimuli.tableChoice = 1;
clear in

% this allows us to enable subsets from our stimulus list
% numbers are the stimuli in the opticka UI
obj.stimuli.stimulusSets = {[1 2 3 4],[1 2 4],[1 3 4]};
obj.stimuli.setChoice = 1;
showSet(obj.stimuli);

%----------------------State Machine States-------------------------
% these are our functions that will execute as the stateMachine runs,
% in the scope of the runExperiemnt object.

%pause entry
pauseEntryFcn = @()setOffline(eL); %set eyelink offline

prefixFcn = @()draw(obj.stimuli); ... %draw stimuli but no animation yet

%fixate entry
fixEntryFcn = { @()setOffline(eL); ... %set eyelink offline
	@()statusMessage(eL,'Initiate Fixation...'); ... %status text on the eyelink
	@()startRecording(eL); ... %fire up eyelink
	@()edit(obj.stimuli,4,'colourOut',[1 1 0]); ...
	@()show(obj.stimuli{4}); ...
	@()draw(obj.stimuli); ... %draw them
	}; 

%fix within
fixFcn = { @()draw(obj.stimuli); ... %draw stimuli but no animation yet	@()drawEyePosition(eL); ...
	@()finishDrawing(s); ...
	};

%test we are fixated for a certain length of time
initFixFcn = @()testSearchHoldFixation(eL,'stimulus','breakfix');

%exit fixation phase
fixExitFcn = { @()updateFixationTarget(obj); ... %use our stimuli values for next fix X and Y
	@()updateFixationValues(eL, [], [], targetFixInit, targetFixTime, targetRadius, true); ... %set target fix window
	@()statusMessage(eL,'Show Stimulus...'); ...
	@()edit(obj.stimuli,4,'colourOut',[0.65 0.65 0.45]); ... %dim fix spot
	@()edit(obj.stimuli,2,'modulateColourOut',luminancePedestal); ... %pump up background
	}; 

%what to run when we enter the stim presentation state
stimEntryFcn = [];

%what to run when we are showing stimuli
stimFcn =  { @()draw(obj.stimuli); ...	@()drawEyePosition(eL); ...
	@()finishDrawing(s); ...
	@()animate(obj.stimuli) };%draw each stimulus to screen

%test we are maintaining fixation
maintainFixFcn = @()testSearchHoldFixation(eL,'correct','breakfix');

%as we exit stim presentation state
stimExitFcn = [];

%if the subject is correct (small reward)
correctEntryFcn = { @()timedTTL(lJ,0,rewardTime); ... % labjack sends a TTL to Crist reward system
	@()drawTimedSpot(s, 0.5, [0 1 0 1]); ...
	@()statusMessage(eL,'Correct! :-)'); ...
	@()randomise(obj.stimuli); ... %randomise our stimuli
	@()updateStimFixTarget(obj); ... %this takes the randomised X and Y so we can send to eyetracker
	@()updateFixationValues(eL, fixX, fixY, firstFixInit, firstFixInit, firstFixRadius, true); ...
	@()trackerDrawFixation(eL); ... %draw fixation window on eyelink computer
	@()trackerDrawStimuli(eL); ... %draw location of stimulus on eyelink
	@()edit(obj.stimuli,2,'modulateColourOut',s.backgroundColour); ... %pump down background
	@()hide(obj.stimuli{4}); ...
	};

%correct stimulus
correctFcn = { @()draw(obj.stimuli); 
	@()drawTimedSpot(s, 0.5, [0 1 0 1]); ...
	};

%when we exit the correct state
correctExitFcn = { @()drawTimedSpot(s, 0.5, [0 1 0 1], 0.2, true); ... %reset the timer on the green spot
	@()updatePlot(bR, eL, sM); ... %update our behavioural plot
	@()update(obj.stimuli); ... %update our stimuli ready for display
	};
%incorrect entry
incEntryFcn = { @()statusMessage(eL,'Incorrect :-('); ... %status message on eyelink
	@()randomise(obj.stimuli); ... %randomise our stimuli
	@()updateStimFixTarget(obj); ... %this takes the randomised X and Y so we can send to eyetracker
	@()updateFixationValues(eL, fixX, fixY, firstFixInit, firstFixInit, firstFixRadius, true); ...
	@()trackerDrawFixation(eL); ... %draw fixation window on eyelink computer
	@()trackerDrawStimuli(eL); ... %draw location of stimulus on eyelink
	@()edit(obj.stimuli,2,'modulateColourOut',s.backgroundColour); ... %pump down background
	@()hide(obj.stimuli{4}); ...
	}; 

%our incorrect stimulus
incFcn =  @()draw(obj.stimuli);

%incorrect / break exit
incExitFcn = { @()updatePlot(bR, eL, sM); ... %update our behavioural plot;
	@()update(obj.stimuli); ... %update our stimuli ready for display
	};

%break entry
breakEntryFcn = { @()statusMessage(eL,'Broke Fixation :-('); ...%status message on eyelink
	@()randomise(obj.stimuli); ... %randomise our stimuli
	@()updateStimFixTarget(obj); ... %this takes the randomised X and Y so we can send to eyetracker
	@()updateFixationValues(eL, fixX, fixY, firstFixInit, firstFixTime, firstFixRadius, true); ...
	@()trackerDrawFixation(eL); ... %draw fixation window on eyelink computer
	@()trackerDrawStimuli(eL); ... %draw location of stimulus on eyelink
	@()edit(obj.stimuli,2,'modulateColourOut',s.backgroundColour); ... %pump down background
	@()hide(obj.stimuli{4}); ...
	@()update(obj.stimuli); ... %update our stimuli ready for display
	};

%calibration function
calibrateFcn = { @()setOffline(eL); @()trackerSetup(eL) }; %enter tracker calibrate/validate setup mode

%debug override
overrideFcn = @()keyOverride(obj); %a special mode which enters a matlab debug state so we can manually edit object values

%screenflash
flashFcn = @()flashScreen(s, 0.25); % fullscreen flash mode for visual background activity detection

%show 1deg size grid
gridFcn = @()drawGrid(s);

%----------------------State Machine Table-------------------------
disp('================>> Building state info file <<================')
%specify our cell array that is read by the stateMachine
stateInfoTmp = { ...
'name'      'next'		'time'  'entryFcn'		'withinFcn'		'transitionFcn'	'exitFcn'; ...
'pause'		'fixate'	inf		pauseEntryFcn	[]				[]				[]; ...
'prefix'	'fixate'	0.2		[]				prefixFcn		[]				[]; ...
'fixate'	'incorrect'	1.4	 	fixEntryFcn		fixFcn			initFixFcn		fixExitFcn; ...
'stimulus'  'incorrect'	2		[]				stimFcn			maintainFixFcn	[]; ...
'incorrect'	'prefix'	2		incEntryFcn		incFcn			[]				incExitFcn; ...
'breakfix'	'prefix'	2		breakEntryFcn	incFcn			[]				incExitFcn; ...
'correct'	'prefix'	1		correctEntryFcn	correctFcn		[]				correctExitFcn; ...
'calibrate' 'pause'		0.5		calibrateFcn	[]				[]				[]; ...
'override'	'pause'		0.5		overrideFcn		[]				[]				[]; ...
'flash'		'pause'		0.5		flashFcn		[]				[]				[]; ...
'showgrid'	'pause'		1		[]				gridFcn			[]				[]; ...
};

disp(stateInfoTmp)
disp('================>> Loaded state info file  <<================')
clear pauseEntryFcn fixEntryFcn fixFcn initFixFcn fixExitFcn stimFcn maintainFixFcn incEntryFcn ...
	incFcn incExitFcn breakEntryFcn breakFcn correctEntryFcn correctFcn correctExitFcn ...
	calibrateFcn overrideFcn flashFcn gridFcn
%DEFAULT Fixation Training state configuration file, this gets loaded by opticka via runExperiment class

%------------General Settings-----------------
rewardTime = 200; %TTL time in milliseconds

el.isDummy = true; %use dummy or real eyelink?
el.sampleRate = 250;
el.remoteCalibration = true; % manual calibration?
el.calibrationStyle = 'HV9'; % calibration style
el.recordData = false; % save EDF file?
el.modify.calibrationtargetcolour = [1 1 0];
el.modify.calibrationtargetsize = 1;
el.modify.calibrationtargetwidth = 0.01;
el.modify.waitformodereadytime = 500;
el.modify.devicenumber = -1; % -1 = use any keyboard
el.fixationX = 0; % X position on screen in degrees
el.fixationY = 0; % Y position on screen in degrees
el.fixationRadius = 1.5; % Fixation Radius in degrees
el.fixationInitTime = 1.0; % Time to enter fixation window
el.fixationTime = 1.0; % Time to hold within fixation window
el.strictFixation = true; % Force that once we are in Fix window, can't leave

%randomise stimulus variables during run?
obj.stimuli.choice = [];
in(1).name = 'xyPosition';
in(1).values = [8 8; 8 -8; -8 8; -8 -8];
in(1).stimuli = [1 3];
in(2).name = 'angle';
in(2).values = [0 180];
in(2).stimuli = [1 3];
% in(3).name = 'contrast';
% in(3).values = [0.2 0.8];
% in(3).stimuli = [2];
obj.stimuli.stimulusTable = in;

% allows using arrow keys to control this table during the main loop
% ideal for mapping receptive fields
n=1;
obj.stimuli.controlTable(n).variable = 'angle';
obj.stimuli.controlTable(n).delta = 15;
obj.stimuli.controlTable(n).stimuli = [1 2];
obj.stimuli.controlTable(n).limits = [0 360];
n=n+1;
obj.stimuli.controlTable(n).variable = 'size';
obj.stimuli.controlTable(n).delta = 1;
obj.stimuli.controlTable(n).stimuli = [1 2];
obj.stimuli.controlTable(n).limits = [1 60];
n=n+1;
obj.stimuli.controlTable(n).variable = 'barLength';
obj.stimuli.controlTable(n).delta = 0.5;
obj.stimuli.controlTable(n).stimuli = [2];
obj.stimuli.controlTable(n).limits = [1 30];
obj.stimuli.tableChoice = 1;

% this allows us to enable subsets from our stimulus list
% numbers are the stimuli in the opticka UI
obj.stimuli.stimulusSets = {[1 2 3],[1 2],[1 3]};
obj.stimuli.setChoice = 1;
showSet(obj.stimuli);

%----------------------State Machine States-------------------------
% io = datapixx (digital I/O to plexon)
% s = screenManager
% sm = State Machine
% el = eyelink manager
% lj = LabJack (reward trigger to Crist reward system)
% bR = behavioural record plot
% obj.stimuli = our list of stimuli
%
% these are our functions that will execute as the stateMachine runs,
% in the scope of the runExperiemnt object.

%pause entry
pauseEntryFcn = @()setOffline(el);

%fixate entry
fixEntryFcn = { @()resetFixation(el); ... %reset our fixation variables
	@()updateFixationValues(el, 0, 0, 0.5, 0.5); ...
	@()setOffline(el); ... %set eyelink offline
	@()trackerDrawFixation(el); ... %draw fixation window on eyelink computer
	@()randomise(obj.stimuli); ... %randomise our stimuli
	@()statusMessage(el,'Running Trial...'); ... %status text on the eyelink
	@()startRecording(el); ...
	@()draw(obj.stimuli) }; 

%fix within
fixFcn = @()disableFlip(obj); 

%test we are fixated for a certain length of time
initFixFcn = @()testSearchHoldFixation(el,'stimulus','');

%
fixExitFcn = { @()updateFixationTarget(obj); ... 
	@()updateFixationValues(el, [], [], 0.5, 0.3, 5); ...
	@()update(obj.stimuli); ... %update our stimuli ready for display
	}; %start it recording this trial

%what to run when we enter the stim presentation state
stimEntryFcn = [];

%what to run when we are showing stimuli
stimFcn = @()draw(obj.stimuli); %draw each stimulus to screen

%test we are maintaining fixation
maintainFixFcn = @()testSearchHoldFixation(el,'correct','breakfix');

%as we exit stim presentation state
stimExitFcn = [];

%if the subject is correct (small reward)
correctEntryFcn = { @()timedTTL(lj,0,rewardTime); ... % labjack sends a TTL to Crist reward system
	@()updatePlot(bR, el, sm); ... %update our behavioural plot
	@()statusMessage(el,'Correct! :-)')}; %status message on eyelink

%correct stimulus
correctFcn = { @()draw(obj.stimuli); @()drawGreenSpot(s,1) };

%when we exit the correct state
correctExitFcn = [];

%break entry
breakEntryFcn = { @()updatePlot(bR, el, sm); ... %update our behavioural plot
	@()statusMessage(el,'Broke Fixation :-(') }; %status message on eyelink

%our incorrect stimulus
breakFcn =  @()drawBackground(s);

%calibration function
calibrateFcn = { @()setOffline(el); @()trackerSetup(el) }; %enter tracker calibrate/validate setup mode

overrideFcn = @()keyOverride(obj); %a special mode which enters a matlab debug state so we can manually edit object values

flashFcn = @()flashScreen(s, 0.25); % fullscreen flash mode for visual background activity detection

%show 1deg size grid
gridFcn = @()drawGrid(s);

%----------------------State Machine Table-------------------------
disp('================>> Building state info file <<================')
%specify our cell array that is read by the stateMachine
stateInfoTmp = { ...
'name'      'next'		'time'  'entryFcn'		'withinFcn'		'transitionFcn'	'exitFcn'; ...
'pause'		'fixate'	inf		pauseEntryFcn	[]				[]				[]; ...
'fixate'	'breakfix'	[0.5 1]	fixEntryFcn		fixFcn			initFixFcn		fixExitFcn; ...
'stimulus'  'incorrect'	2		stimEntryFcn	stimFcn			maintainFixFcn	stimExitFcn; ...
'breakfix'	'fixate'	0.5		breakEntryFcn	breakFcn		[]				[]; ...
'correct'	'fixate'	0.5		correctEntryFcn	correctFcn		[]				correctExitFcn; ...
'calibrate' 'pause'		0.5		calibrateFcn	[]				[]				[]; ...
'override'	'pause'		0.5		overrideFcn		[]				[]				[]; ...
'flash'		'pause'		0.5		flashFcn		[]				[]				[]; ...
'showgrid'	'pause'		1		[]				gridFcn			[]				[]; ...
};

disp(stateInfoTmp)
disp('================>> Loaded state info file  <<================')
clear maintainFixFcn psFcn stimFcn stimEntryFcn stimExitfcn correctEntry correctWithin correctExit ...
	incorrectFcn calibrateFcn
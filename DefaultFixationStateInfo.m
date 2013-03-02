%DEFAULT Fixation Training state configuration file
% This gets loaded by opticka via runExperiment class

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
in(1).stimuli = [1 2];
in(2).name = 'angle';
in(2).values = [0 22.5 45 67.5 90];
in(2).stimuli = [1 2];
in(3).name = 'contrast';
in(3).values = [0.2 0.8];
in(3).stimuli = [2];
obj.stimuli.stimulusTable = in;

% allows using arrow keys to control this table during the main loop
% ideal for mapping receptive fields
obj.stimuli.controlTable(1).variable = 'angle';
obj.stimuli.controlTable(1).delta = 15;
obj.stimuli.controlTable(1).stimuli = [1 2];
obj.stimuli.controlTable(1).limits = [0 360];
obj.stimuli.controlTable(2).variable = 'size';
obj.stimuli.controlTable(2).delta = 1;
obj.stimuli.controlTable(2).stimuli = [1 2];
obj.stimuli.controlTable(2).limits = [1 60];
obj.stimuli.controlTable(3).variable = 'barLength';
obj.stimuli.controlTable(3).delta = 0.5;
obj.stimuli.controlTable(3).stimuli = [2];
obj.stimuli.controlTable(3).limits = [1 30];
obj.stimuli.tableChoice = 1;

% this allows us to enable subsets from our stimulus list
% numbers are the stimuli in the opticka UI
obj.stimuli.stimulusSets = {[1 2 3],[3],[1 3]};
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

%pause entry
psEntryFcn = { @()setOffline(el); ... %set eyelink offline
	@()trackerDrawFixation(el); ... %draw fixation window on eyelink computer
	@()resetFixation(el); ... %reset our fixation variables
	@()randomise(obj.stimuli) }; %randomise our stimuli

%pause within
psFcn = @()drawBackground(s); %draw background only

%
psExitFcn = { @()update(obj.stimuli); ... %update our stimuli ready for display
	@()statusMessage(el,'Showing Fixation Spot...'); ... %status text on the eyelink
	@()startRecording(el) }; %start it recording this trial

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
correctFcn = { @()drawBackground(s); @()drawGreenSpot(s,1) };

%when we exit the correct state
correctExitFcn = [];

%break entry
breakEntryFcn = { @()updatePlot(bR, el, sm); ... %update our behavioural plot
	@()statusMessage(el,'Broke Fixation :-(') }; %status message on eyelink

%our incorrect stimulus
breakFcn =  @()drawBackground(s);

%calibration function
calibrateFcn = @()trackerSetup(el); %enter tracker calibrate/validate setup mode

overrideFcn = @()keyOverride(obj); %a special mode which enters a matlab debug state so we can manually edit object values

flashFcn = @()flashScreen(s, 0.25); % fullscreen flash mode for visual background activity detection

disp('================>> Loading state info file <<================')
%specify our cell array that is read by the stateMachine
stateInfoTmp = { ...
'name'      'next'			'time'  'entryFcn'		'withinFcn'		'transitionFcn'	'exitFcn'; ...
'pause'		'prestimulus'	inf		pauseEntryFcn	[]				[]				[]; ...
'prestimulus' 'stimulus'	[0.5 1]	psEntryFcn		psFcn			[]				psExitFcn; ...
'stimulus'  'breakfix'		4		stimEntryFcn	stimFcn			maintainFixFcn	stimExitFcn; ...
'breakfix'	'prestimulus'	0.5		breakEntryFcn	breakFcn		[]				[]; ...
'correct'	'prestimulus'	0.5		correctEntryFcn	correctFcn		[]				correctExitFcn; ...
'calibrate' 'prestimulus'	0.5		calibrateFcn	[]				[]				[]; ...
'override'	'prestimulus'	0.5		overrideFcn		[]				[]				[]; ...
'flash'		'prestimulus'	0.5		flashFcn		[]				[]				[]; ...
};

disp(stateInfoTmp)
disp('================>> Loaded state info file  <<================')
clear maintainFixFcn psFcn stimFcn stimEntryFcn stimExitfcn correctEntry correctWithin correctExit ...
	incorrectFcn calibrateFcn
clear
sca
global rM
if ~exist('rM','var') || isempty(rM)
	 rM = arduinoManager;
end
open(rM) %open our reward manager

DEBUGlevel              = 0;
fixClrs                 = [0 255];
bgClr                   = 127;
eyeColors               = {[255 127 0],[0 95 191]}; % for live data view on operator screen
useAnimatedCalibration  = true;
doBimonocularCalibration= false;
% task parameters
fixTime                 = .5;
imageTime               = 4;
if IsWin
	scrPresenter            = 2;
	scrOperator             = 1;
else
	scrPresenter            = 1;
	scrOperator             = 0;
end
rTime = 200;

addpath(genpath(fullfile(fileparts(mfilename('fullpath')),'..')));
Screen('Preference', 'SkipSyncTests', 2);
try
	eyeColors = cellfun(@color2RGBA,eyeColors,'uni',false);
	
	% get setup struct (can edit that of course):
	settings = Titta.getDefaults('Tobii Pro Spectrum');
	settings.debugMode				= false;	
	settings.freq					= 150;
	settings.trackingMode			= 'macaque';
	settings.cal.autoPace            = 0;
	settings.cal.doRandomPointOrder  = false;
	settings.cal.pointNotifyFunction = @tittaCalCallback;
	settings.val.pointNotifyFunction = @tittaCalCallback;
	% customize colors of setup and calibration interface (yes, colors of
	% everything can be set, so there is a lot here).
	% 1. setup screen
	settings.UI.setup.bgColor       = bgClr;
	settings.UI.setup.instruct.color= fixClrs(1);
	settings.UI.setup.fixBackColor  = fixClrs(1);
	settings.UI.setup.fixFrontColor = fixClrs(2);
	% override the instruction shown on the setup screen, don't need that
	% much detail when you have a separate operator screen
	settings.UI.setup.instruct.strFun   = @(x,y,z,rx,ry,rz) 'Position yourself such that the two circles overlap.';
	% 2. validation result screen
	settings.UI.val.bgColor                 = bgClr;
	settings.UI.val.avg.text.color          = fixClrs(1);
	settings.UI.val.fixBackColor            = fixClrs(1);
	settings.UI.val.fixFrontColor           = fixClrs(2);
	settings.UI.val.onlineGaze.fixBackColor = fixClrs(1);
	settings.UI.val.onlineGaze.fixFrontColor= fixClrs(2);
	% calibration display
	if useAnimatedCalibration
		% custom calibration drawer
		calViz                      = AnimatedCalibrationDisplay();
		settings.cal.drawFunction   = @calViz.doDraw;
		calViz.bgColor              = bgClr;
		calViz.fixBackColor         = fixClrs(1);
		calViz.fixFrontColor        = fixClrs(2);
	else
		% set color of built-in fixation points
		settings.cal.bgColor        = bgClr;
		settings.cal.fixBackColor   = fixClrs(1);
		settings.cal.fixFrontColor  = fixClrs(2);
	end
	
	% init
	EThndl          = Titta(settings);
	% EThndl        = EThndl.setDummyMode();    % just for internal testing, enabling dummy mode for this readme makes little sense as a demo
	EThndl.init();
	
	if DEBUGlevel>1
		% make screen partially transparent on OSX and windows vista or
		% higher, so we can debug.
		%PsychDebugWindowConfiguration;
	end
	if DEBUGlevel
		% Be pretty verbose about information and hints to optimize your code and system.
		Screen('Preference', 'Verbosity', 4);
	else
		% Only output critical errors and warnings.
		Screen('Preference', 'Verbosity', 2);
	end
	Screen('Preference', 'SyncTestSettings', 0.002);    % the systems are a little noisy, give the test a little more leeway
	[wpntP,winRectP] = PsychImaging('OpenWindow', scrPresenter, bgClr, [], [], [], [], 4);
	[wpntO,winRectO] = PsychImaging('OpenWindow', scrOperator , bgClr, [0 0 1920 1080], [], [], [], 4);
	hz=Screen('NominalFrameRate', wpntP);
	Priority(1);
	Screen('BlendFunction', wpntP, GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
	Screen('Preference', 'TextAlphaBlending', 1);
	Screen('Preference', 'TextAntiAliasing', 2);
	% This preference setting selects the high quality text renderer on
	% each operating system: It is not really needed, as the high quality
	% renderer is the default on all operating systems, so this is more of
	% a "better safe than sorry" setting.
	Screen('Preference', 'TextRenderer', 1);
	KbName('UnifyKeyNames');    % for correct operation of the setup/calibration interface, calling this is required
	
	% do calibration
	if doBimonocularCalibration
		% do sequential monocular calibrations for the two eyes
		settings                = EThndl.getOptions();
		settings.calibrateEye   = 'left';
		settings.UI.button.setup.cal.string = 'calibrate left eye (<i>spacebar<i>)';
		str = settings.UI.button.val.continue.string;
		settings.UI.button.val.continue.string = 'calibrate other eye (<i>spacebar<i>)';
		EThndl.setOptions(settings);
		tobii.calVal{1}         = EThndl.calibrate([wpntP wpntO],1);
		if ~tobii.calVal{1}.wasSkipped
			settings.calibrateEye   = 'right';
			settings.UI.button.setup.cal.string = 'calibrate right eye (<i>spacebar<i>)';
			settings.UI.button.val.continue.string = str;
			EThndl.setOptions(settings);
			tobii.calVal{2}         = EThndl.calibrate([wpntP wpntO],2);
		end
	else
		tobii.calVal{1}         = EThndl.calibrate([wpntP wpntO]);
	end
	
	i = 1;
	breakLoop = false;
	% later:
	EThndl.buffer.start('gaze');
	WaitSecs(.8);   % wait for eye tracker to start and gaze to be picked up
	
	% send message into ET data file
	EThndl.sendMessage('test');
	
	
	while ~breakLoop
		% First draw a fixation point
		Screen('gluDisk',wpntP,fixClrs(1),winRectP(3)/2,winRectP(4)/2,round(winRectP(3)/100));
		startT = Screen('Flip',wpntP);
		% log when fixation dot appeared in eye-tracker time. NB:
		% system_timestamp of the Tobii data uses the same clock as
		% PsychToolbox, so startT as returned by Screen('Flip') can be used
		% directly to segment eye tracking data
		EThndl.sendMessage('FIX ON',startT);
		
		% read in konijntjes image (may want to preload this before the trial
		% to ensure good timing)
		stimFName   = ['th' num2str(randi(28)) '.jpg'];
		stimDir		= '/media/cog1/Main_Data/Monkey_Images/';
		stimFullName= fullfile(stimDir,stimFName);
		im          = imread(stimFullName);
		tex         = Screen('MakeTexture',wpntP,im);
		nextFlipT   = startT+fixTime-1/hz/2;
		
		% now update also operator screen, once timing critical bit is done
		% if we still have enough time till next flipT, update operator display
		while nextFlipT-GetSecs()>.08   % arbitrarily decide 80ms is enough headway
			Screen('gluDisk',wpntO,fixClrs(1),winRectO(3)/2,winRectO(4)/2,round(winRectO(3)/100));
			drawLiveData(wpntO,EThndl.buffer,500,settings.freq,eyeColors{:},4,winRectO(3:4));
			Screen('Flip',wpntO);
		end
		
		% show on screen and log when it was shown in eye-tracker time.
		% NB: by setting a deadline for the flip, we ensure that the previous
		% screen (fixation point) stays visible for the indicated amount of
		% time. See PsychToolbox demos for further elaboration on this way of
		% timing your script.
		Screen('DrawTexture',wpntP,tex);                    % draw centered on the screen
		imgT = Screen('Flip',wpntP,nextFlipT);   % bit of slack to make sure requested presentation time can be achieved
		EThndl.sendMessage(sprintf('STIM ON: %s',stimFName),imgT);
		nextFlipT = imgT+imageTime-1/hz/2;
		rM.timedTTL(2,rTime);Beeper(600,0.1,0.2)
		
		% now update also operator screen, once timing critical bit is done
		% if we still have enough time till next flipT, update operator display
		while nextFlipT-GetSecs()>.08   % arbitrarily decide 80ms is enough headway
			Screen('DrawTexture',wpntO,tex);
			drawLiveData(wpntO,EThndl.buffer,500,settings.freq,eyeColors{:},4,winRectO(3:4));
			Screen('Flip',wpntO);
		end
		rM.timedTTL(2,rTime);Beeper(600,0.1,0.2)
		
		% record x seconds of data, then clear screen. Indicate stimulus
		% removed, clean up
		endT = Screen('Flip',wpntP,nextFlipT);
		EThndl.sendMessage(sprintf('STIM OFF: %s',stimFName),endT);
		Screen('Close',tex);
		nextFlipT = endT+1; % lees precise, about 1s give or take a frame, is fine
		
		% now update also operator screen, once timing critical bit is done
		% if we still have enough time till next flipT, update operator display
		while nextFlipT-GetSecs()>.08   % arbitrarily decide 80ms is enough headway
			drawLiveData(wpntO,EThndl.buffer,500,settings.freq,eyeColors{:},4,winRectO(3:4));
			Screen('Flip',wpntO);
		end
		
		[keyIsDown, ~, keyCode] = KbCheck(-1);
		if keyIsDown == 1
			rchar = KbName(keyCode); if iscell(rchar);rchar=rchar{1};end
			switch lower(rchar)
				case {'q'}
					fprintf('===>>> runEquiMotion Q pressed!!!\n');
					breakLoop = true;
			end
		end
		
		i = i + 1;
		fprintf('Run %i\n',i);
		WaitSecs(2)
		
	end
	
	% 3. end recording after x seconds of data again, clear screen.
	endT = Screen('Flip',wpntP,nextFlipT);
	EThndl.sendMessage(sprintf('STIM OFF: %s',stimFNameBlur),endT);
	Screen('Close',tex);
	Screen('Flip',wpntO);
	
	% stop recording
	if EThndl.buffer.hasStream('eyeImage')
		EThndl.buffer.stop('eyeImage');
	end
	EThndl.buffer.stop('gaze');
	
	% save data to mat file, adding info about the experiment
	dat = EThndl.collectSessionData();
	dat.expt.winRect = winRectP;
	dat.expt.stimDir = stimDir;
	save(EThndl.getFileName(fullfile(cd,'t'), true),'-struct','dat');
	% NB: if you don't want to add anything to the saved data, you can use
	% EThndl.saveData directly
	
	% shut down
	EThndl.deInit();
catch me
	sca
	rethrow(me)
end
sca
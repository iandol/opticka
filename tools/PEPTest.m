function [offsetX, offsetY, out] = PEPTest(opts)
%PEPTEST  Dichoptic alignment ("PEP") task using Opticka classes.
%
%   The left eye sees an empty circle (annulus) and the right eye sees a
%   cross. The subject moves the cross with the keyboard arrow keys until it
%   looks centred inside the circle. The final offset of the cross relative to
%   the circle is returned in visual degrees.
%
%   USAGE
%       PEPTest                              % run with the defaults below
%       PEPTest('stereoMode',1)              % override any parameter
%       PEPTest(stereoMode=5, circleEye="right")
%       [x, y] = PEPTest(...)                % offset in degrees
%       [x, y, out] = PEPTest(...)           % plus a results structure
%
%   KEYS
%       left / right / up / down arrows .... move the cross
%       (hold) left shift ................. fine movement
%       space or return ................... accept and exit
%       escape ............................ exit
%
%   OUTPUT
%       offsetX, offsetY  cross position minus circle position, in visual
%                         degrees. +X is rightwards; +Y is DOWNWARDS on the
%                         screen (Opticka/PTB convention).
%       out               struct with .offset, .crossPosition,
%                         .circlePosition, .exitReason, .nFrames, .duration,
%                         .fps, .log (time,X,Y per adjustment),
%                         .parameters and .dateStamp.
%
%   DICHOPTIC DISPLAY
%       The stereo mode is passed straight to screenManager('stereoMode',...).
%       Common choices: 4 = split-screen/haploscope (left view in the left
%       half, right view in the right half), 5 = same but eyes exchanged,
%       1 = quad-buffered (shutter glasses/passive monitor), 6-9 = anaglyph,
%       11 = PTB frame-sequential. Use 0 for a mono debug view in which both
%       eyes see both stimuli.
%
%   See also ANNULUSSTIMULUS, FIXATIONCROSSSTIMULUS, SCREENMANAGER, OPTICKA.
%
%   Copyright ©2014-2026 Ian Max Andolina — released: LGPL3, see LICENCE.md
% ========================================================================

	% ====================================================================
	% ======================== PARAMETERS (edit here) ====================
	% ====================================================================
	arguments
		%> ---- DISPLAY ---------------------------------------------------
		%> stereo/dichoptic mode passed to screenManager (see header above)
		opts.stereoMode (1,1) double {mustBeInteger, mustBeInRange(opts.stereoMode,0,12)} = 8
		%> PTB screen number, [] = highest numbered (usually the display)
		opts.screen = []
		%> [] or false = fullscreen; true = 800x600 window; or [x y w h]
		opts.windowed = []
		%> screen geometry for the degree conversion
		opts.pixelsPerCm (1,1) double {mustBePositive} = 38
		opts.distance (1,1) double {mustBePositive} = 57.3
		%> skip PTB sync tests (development only, never on the rig)
		opts.skipSyncTests (1,1) logical = false
		%> ---- STIMULI ---------------------------------------------------
		%> background grey, 0.5 = mid grey
		opts.bgColour (1,3) double {mustBeInRange(opts.bgColour,0,1)} = [0 0 0]
		%> colour of circle and cross: [0 0 0] = black, [1 1 1] = white
		opts.stimColour (1,3) double {mustBeInRange(opts.stimColour,0,1)} = [1 1 1]
		%> outer diameter of the empty circle in degrees
		opts.circleSize (1,1) double {mustBePositive} = 4
		%> thickness of the circle outline in degrees
		opts.circleLineWidth (1,1) double {mustBePositive} = 0.2
		%> total arm span of the cross in degrees
		opts.crossSize (1,1) double {mustBePositive} = 4
		%> thickness of the cross lines in degrees
		opts.crossLineWidth (1,1) double {mustBePositive} = 0.2
		%> which eye sees the circle: 'left' or 'right' (cross gets the other)
		opts.circleEye char {mustBeMember(opts.circleEye,{'left','right'})} = 'right'
		%> ---- TASK ------------------------------------------------------
		%> initial cross offset from the circle in degrees [x y]
		opts.startOffset (1,2) double = [0 0]
		%> degrees moved per discrete key press
		opts.stepSize (1,1) double {mustBePositive} = 0.075
		%> degrees per second while a key is held down
		opts.holdSpeed (1,1) double {mustBeNonnegative} = 1
		%> seconds a key must be held before continuous movement starts
		opts.holdDelay (1,1) double {mustBeNonnegative} = 0.3
		%> multiplier for stepSize/holdSpeed while shift is held
		opts.fineScale (1,1) double {mustBePositive} = 0.1
		%> maximum absolute offset in degrees (safety clamp)
		opts.maxOffset (1,1) double {mustBePositive} = 15
		%> abort automatically after this many seconds (Inf = no limit)
		opts.maxDuration (1,1) double = Inf
		%> show a start/instruction screen in both eyes
		opts.showInstructions (1,1) logical = true
		%> optional override for keyboard polling; must behave like
		%> [keyIsDown, secs, keyCode] = KbCheck(-1). Useful for simulated
		%> input, response boxes or automated testing.
		opts.keyFcn = []
		%> extra command window output
		opts.verbose (1,1) logical = false
	end
	% ====================================================================

	if isempty(opts.keyFcn); opts.keyFcn = @() KbCheck(-1); end
	if isempty(opts.screen); opts.screen = max(Screen('Screens')); end

	%% ---- open the dichoptic screen ----------------------------------
	sM = screenManager('screen', opts.screen, ...
		'stereoMode', opts.stereoMode, ...
		'backgroundColour', [opts.bgColour 1], ...
		'pixelsPerCm', opts.pixelsPerCm, ...
		'distance', opts.distance, ...
		'windowed', opts.windowed, ...
		'disableSyncTests', opts.skipSyncTests, ...
		'bitDepth', '8bit', ...
		'verbose', opts.verbose);

	% guaranteed cleanup (close screen, priority, keyboard, cursor)
	cleaner = onCleanup(@() cleanupTask(sM)); %#ok<NASGU>

	open(sM);

	%% ---- build the two monocular stimuli -----------------------------
	circle = annulusStimulus('name', 'PEPcircle', ...
		'size', opts.circleSize, ...
		'lineWidth', opts.circleLineWidth, ...
		'colour', opts.stimColour, ...
		'verbose', opts.verbose);

	cross = fixationCrossStimulus('name', 'PEPcross', ...
		'size', opts.crossSize, ...
		'lineWidth', opts.crossLineWidth, ...
		'colour2', opts.stimColour, ...		% cross lines
		'colour', opts.stimColour, ...		% centre junction dot (disk is off)
		'showDisk', false, ...
		'alpha2', 1, ...
		'verbose', opts.verbose);

	setup(circle, sM);
	setup(cross, sM);

	%% ---- eye / channel mapping --------------------------------------
	% PTB stereo draw buffer 0 = left eye, 1 = right eye
	if strcmpi(opts.circleEye, 'left')
		circleChannel = 0; crossChannel = 1;
	else
		circleChannel = 1; crossChannel = 0;
	end

	%% ---- initial positions ------------------------------------------
	circleX = 0; circleY = 0;						% circle stays at screen centre
	crossX = opts.startOffset(1);
	crossY = opts.startOffset(2);
	circle.updateXY(circleX, circleY, true);
	cross.updateXY(crossX, crossY, true);

	%% ---- keyboard ----------------------------------------------------
	KbName('UnifyKeyNames');
	moveKeys = [KbName('LeftArrow') KbName('RightArrow') ...
		KbName('UpArrow') KbName('DownArrow')];
	shiftKeys = [KbName('LeftShift') KbName('RightShift')];
	acceptKeys = [KbName('space') KbName('Return')];
	exitKeys = KbName('ESCAPE');
	keyList = unique([moveKeys shiftKeys acceptKeys exitKeys]);

	RestrictKeysForKbCheck(keyList);
	ListenChar(-1);
	HideCursor;
	Priority(MaxPriority(sM.win));

	if opts.showInstructions
		waitForStart(sM, opts.keyFcn, ...
			"Align the cross inside the circle", ...
			"Arrows = move    Shift = fine    SPACE = accept    ESC = quit");
	end

	%% ---- main loop ---------------------------------------------------
	ifi = sM.screenVals.ifi;
	if opts.verbose
		fprintf('PEPTest: screen %d, stereoMode %d, ppd %.2f, %dx%d px\n', ...
			sM.screen, sM.stereoMode, sM.ppd, sM.screenVals.screenWidth, sM.screenVals.screenHeight);
	end

	vbl = flip(sM);
	startTime = vbl;
	lastTime = startTime;

	prevKeys = false(1, 256);
	held = zeros(1, 4);				% seconds each arrow has been held
	nFrames = 0; nMissed = 0;
	moveLog = zeros(20000, 3);		% [time x y] whenever the cross moves
	nLog = 0;
	exitReason = 'maxDuration';

	while true

		now = GetSecs();
		dt = now - lastTime;
		if dt <= 0 || dt > 1; dt = ifi; end		% guard against stalls
		lastTime = now;

		%% ---- keys
		[isDown, ~, keyCode] = opts.keyFcn(); %#ok<ASGLU>
		keyCode = logical(keyCode(:)');
		if numel(keyCode) < 256; keyCode(256) = false; end

		if keyCode(exitKeys)
			exitReason = 'escape'; break
		end
		if any(keyCode(acceptKeys))
			exitReason = 'accept'; break
		end

		if any(keyCode(shiftKeys)); scale = opts.fineScale; else; scale = 1; end

		dx = 0; dy = 0;
		for k = 1:4
			kk = moveKeys(k);
			if keyCode(kk)
				if ~prevKeys(kk)			% fresh press -> one discrete step
					held(k) = 0;
					step = opts.stepSize * scale;
				elseif held(k) >= opts.holdDelay
					step = opts.holdSpeed * scale * dt;	% continuous movement
				else
					step = 0;				% waiting out holdDelay
				end
				held(k) = held(k) + dt;
				switch k
					case 1; dx = dx - step;		% left
					case 2; dx = dx + step;		% right
					case 3; dy = dy - step;		% up
					case 4; dy = dy + step;		% down
				end
			else
				held(k) = 0;
			end
		end
		prevKeys = keyCode;

		%% ---- move the cross (offset clamped relative to the circle)
		if dx ~= 0 || dy ~= 0
			crossX = crossX + dx;
			crossY = crossY + dy;
			crossX = circleX + min(opts.maxOffset, max(-opts.maxOffset, crossX - circleX));
			crossY = circleY + min(opts.maxOffset, max(-opts.maxOffset, crossY - circleY));
			cross.updateXY(crossX, crossY, true);	% degrees -> pixels
			if nLog < size(moveLog, 1)
				nLog = nLog + 1;
				moveLog(nLog, :) = [now - startTime, crossX, crossY];
			end
		end

		%% ---- draw: background and one stimulus per eye
		if sM.stereoMode > 0
			%each eye has its own back buffer, so clear both
			sM.switchChannel(0); sM.drawBackground();
			sM.switchChannel(1); sM.drawBackground();
		else
			%mono debug view: both eyes share one buffer, a second fill
			%would erase the circle drawn below
			sM.drawBackground();
		end
		sM.switchChannel(circleChannel); circle.draw(); drawScreenCenter(sM,8);
		sM.switchChannel(crossChannel); cross.draw();   
		sM.finishDrawing();

		[vbl, ~, ~, missed] = flip(sM, vbl + ifi * 0.5);
		nFrames = nFrames + 1;
		if ~isempty(missed); nMissed = nMissed + missed; end

		if (vbl - startTime) >= opts.maxDuration
			exitReason = 'maxDuration'; break
		end
	end

	duration = vbl - startTime;

	%% ---- tidy up before reporting ------------------------------------
	close(sM);

	%% ---- results ------------------------------------------------------
	offsetX = crossX - circleX;
	offsetY = crossY - circleY;			% +Y is down the screen

	out = struct();
	out.offset = [offsetX offsetY];
	out.offsetX = offsetX;
	out.offsetY = offsetY;
	out.crossPosition = [crossX crossY];
	out.circlePosition = [circleX circleY];
	out.circleEye = opts.circleEye;
	out.stereoMode = opts.stereoMode;
	out.exitReason = exitReason;
	out.nFrames = nFrames;
	out.nMissedFrames = nMissed;
	out.duration = duration;
	out.fps = nFrames / max(duration, eps);
	out.log = moveLog(1:nLog, :);
	out.parameters = opts;
	out.dateStamp = char(datetime('now'));

	fprintf('\n==== PEPTest finished (%s) ====\n', exitReason);
	fprintf('circle eye = %s | stereoMode = %d | colour = [%g %g %g] | background = [%g %g %g]\n', ...
		opts.circleEye, opts.stereoMode, opts.stimColour, opts.bgColour);
	fprintf('cross offset: X = %+0.3f deg, Y = %+0.3f deg  (+X right, +Y down)\n', offsetX, offsetY);
	fprintf('duration %.2f s | %d frames | %.1f fps | %d missed\n\n', ...
		duration, nFrames, out.fps, nMissed);

end

% ========================================================================
% ============================ LOCAL FUNCTIONS ===========================
% ========================================================================

function waitForStart(sM, keyFcn, txt1, txt2)
%> draw an instruction screen to BOTH eyes, then wait for a fresh key press
%> and its release so the press cannot leak into the task loop.
	for ch = 0:1
		sM.switchChannel(ch);
		sM.drawBackground();
		sM.drawText(txt1, -8, -1.5);
		sM.drawText(txt2, -8, 0.5);
	end
	sM.finishDrawing();
	flip(sM);

	while true
		[down, ~, ~] = keyFcn();
		if down; break; end
		WaitSecs(0.016);
	end
	while true
		[down, ~, ~] = keyFcn();
		if ~down; break; end
		WaitSecs(0.016);
	end
end

function cleanupTask(sM)
%> restore PTB/MATLAB state no matter how the task ended
	try Priority(0); end %#ok<*TRYNC>
	try ListenChar(0); end
	try ShowCursor; end
	try RestrictKeysForKbCheck([]); end
	try
		if isa(sM, 'screenManager') && sM.isOpen
			close(sM);
		end
	end
end

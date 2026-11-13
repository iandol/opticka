function [offsetX, offsetY, out] = PEPTest(opts)
%PEPTEST  Dichoptic ("PEP") task using Opticka classes: alignment or gratings.
%
%   Two presentation modes, selected with mode="align" (default) or
%   mode="grating".
%
%   ALIGN MODE
%   The left eye sees an empty circle (annulus) and the right eye sees a
%   cross. The subject moves the cross with the keyboard arrow keys until it
%   looks centred inside the circle. The final offset of the cross relative to
%   the circle is returned in visual degrees.
%
%   GRATING MODE
%   Each eye sees one grating patch at the screen centre, built with
%   gratingStimulus, so sf, tf, contrast, phase, mask smoothing etc. behave
%   exactly as in a normal Opticka protocol. Give the two eyes the same
%   orientation (binocular fusion / summation) or different orientations
%   (interocular orientation difference, e.g. binocular rivalry). The arrow
%   keys move the grating(s) exactly as they move the cross in align mode, so
%   a dichoptic position offset can be pre-set with startOffset and nulled by
%   the subject; gratingMove decides whether both eyes move together or only
%   one eye, and space/return stops.
%
%   USAGE
%       PEPTest                              % alignment task, defaults below
%       PEPTest('stereoMode',1)              % override any parameter
%       PEPTest(stereoMode=5, circleEye="right")
%       PEPTest(mode="grating")              % both eyes 0 deg, static
%       PEPTest(mode="grating", gratingAngleLeft=0, gratingAngleRight=90)
%       PEPTest(mode="grating", gratingSF=2, gratingTF=2, ...
%           gratingContrast=0.8, gratingSize=8, showBorder=true)
%       PEPTest(mode="grating", gratingArgs={"sigma",20,"correctPhase",true})
%       PEPTest(mode="grating", gratingMove="right", startOffset=[0.5 0])
%       [x, y] = PEPTest(...)                % offset in degrees
%       [x, y, out] = PEPTest(...)           % plus a results structure
%
%   KEYS
%       align mode
%           left / right / up / down arrows .... move the cross
%           (hold) left shift ................. fine movement
%           space or return ................... accept and exit
%           escape ............................ exit
%       grating mode
%           left / right / up / down arrows .... move the grating(s)
%           (hold) left shift ................. fine movement
%           space or return ................... stop and exit
%           escape ............................ exit
%
%   OUTPUT
%       offsetX, offsetY  align mode: cross position minus circle position.
%                         grating mode: right grating position minus left
%                         grating position (the dichoptic offset between the
%                         patches, zero when gratingMove="both" and no
%                         single-eye startOffset was used). In visual degrees;
%                         +X is rightwards, +Y is DOWNWARDS on the screen
%                         (Opticka/PTB convention).
%       out               struct with .mode, .offset, .crossPosition,
%                         .circlePosition, .circleEye, .stereoMode,
%                         .gratingAngles, .gratingPhases, .gratingPositions,
%                         .gratingMove, .borderColours, .exitReason,
%                         .nFrames, .duration, .fps, .log (time,X,Y per
%                         adjustment of the adjusted stimulus), .parameters
%                         and .dateStamp.
%
%   EYE BORDER
%       showBorder=true (the default) draws a frame around the edge of each
%       eye's viewport: RED for the left eye (PTB draw buffer 0) and GREEN for
%       the right eye (draw buffer 1), with the line width set by borderWidth
%       in degrees.
%       Use it to confirm which eye sees which stimulus, or as a fixation
%       frame for the subject. In any stereo mode each buffer gets its own
%       colour; in the mono debug view (stereoMode 0) both eyes share one
%       buffer, so the left colour is drawn as the outer frame and the right
%       colour as a frame just inside it.
%
%   DICHOPTIC DISPLAY
%       The stereo mode is passed straight to screenManager('stereoMode',...).
%       Common choices: 4 = split-screen/haploscope (left view in the left
%       half, right view in the right half), 5 = same but eyes exchanged,
%       1 = quad-buffered (shutter glasses/passive monitor), 6-9 = anaglyph,
%       11 = PTB frame-sequential. Use 0 for a mono debug view in which both
%       eyes see both stimuli; note that in mono the two gratings of grating
%       mode share one buffer, so only the second (right eye) grating is
%       visible - use mode 4 to check a dichoptic grating pair on one screen.
%
%   See also GRATINGSTIMULUS, ANNULUSSTIMULUS, FIXATIONCROSSSTIMULUS,
%   SCREENMANAGER, OPTICKA.
%
%   Copyright ©2014-2026 Ian Max Andolina — released: LGPL3, see LICENCE.md
% ========================================================================

	% ====================================================================
	% ======================== PARAMETERS (edit here) ====================
	% ====================================================================
	arguments
		%> ---- PRESENTATION ----------------------------------------------
		%> what to present: 'align' = dichoptic circle (one eye) vs cross
		%> (other eye) alignment task, which the subject adjusts with the
		%> arrows; 'grating' = one grating per eye, same or different
		%> orientation, presented until a key is pressed
		opts.mode char {mustBeMember(opts.mode,{'align','grating'})} = 'align'
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
		opts.bgColour (1,3) double {mustBeInRange(opts.bgColour,0,1)} = [0.5 0.5 0.5]
		%> colour of circle and cross: [0 0 0] = black, [1 1 1] = white
		opts.stimColour (1,3) double {mustBeInRange(opts.stimColour,0,1)} = [0.75 0.75 0.75]
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
		%> ---- DICHOPTIC GRATINGS (mode = 'grating') ----------------------
		%> everything below is handed to gratingStimulus, so the gratings
		%> behave exactly like gratings in a normal Opticka protocol
		%> spatial frequency in cycles per degree
		opts.gratingSF (1,1) double {mustBePositive} = 1
		%> temporal frequency in Hz; 0 = static (no drift)
		opts.gratingTF (1,1) double {mustBeNonnegative} = 0
		%> gratingStimulus contrast 0-1 (the shader scales it by
		%> contrastMult = 0.5, so 1 = full black-white modulation)
		opts.gratingContrast (1,1) double {mustBeInRange(opts.gratingContrast,0,1)} = 0.5
		%> diameter of the circular grating patch in degrees
		opts.gratingSize (1,1) double {mustBePositive} = 6
		%> orientation in degrees for each eye; equal = same orientation,
		%> different = an interocular orientation difference (e.g. 90 for
		%> orthogonal rivalling gratings)
		opts.gratingAngleLeft (1,1) double = 0
		opts.gratingAngleRight (1,1) double = 0
		%> phase in degrees for each eye (set them 180 apart to see a
		%> phase disparity)
		opts.gratingPhaseLeft (1,1) double = 0
		opts.gratingPhaseRight (1,1) double = 0
		%> waveform: 'sinusoid' or 'square'
		opts.gratingType char {mustBeMember(opts.gratingType,{'sinusoid','square'})} = 'sinusoid'
		%> use a circular mask for the grating patch
		opts.gratingMask (1,1) logical = true
		%> cosine smoothing sigma in pixels for the mask edge (0 = hard)
		opts.gratingSigma (1,1) double {mustBeNonnegative} = 21
		%> grating mean colour; [0.5 0.5 0.5] = mid grey, as in
		%> gratingStimulus' own default
		opts.gratingColour (1,3) double {mustBeInRange(opts.gratingColour,0,1)} = [0.5 0.5 0.5]
		%> extra name-value pairs passed to BOTH gratings for anything not
		%> exposed above, e.g. {'correctPhase',true,'aspectRatio',2}
		opts.gratingArgs cell = {}
		%> which grating the arrow keys move: 'both' moves the two eyes
		%> together, 'left'/'right' moves only that eye so an interocular
		%> position offset can be set or nulled
		opts.gratingMove char {mustBeMember(opts.gratingMove,{'both','left','right'})} = 'right'
		%> ---- EYE BORDER ------------------------------------------------
		%> draw a frame around the edge of each eye's viewport (see header);
		%> red = left eye draw buffer, green = right eye draw buffer
		opts.showBorder (1,1) logical = true
		%> thickness of the border in degrees
		opts.borderWidth (1,1) double {mustBePositive} = 0.2
		%> colour of the left eye border (red)
		opts.borderColourLeft (1,3) double {mustBeInRange(opts.borderColourLeft,0,1)} = [1 0 0]
		%> colour of the right eye border (green)
		opts.borderColourRight (1,3) double {mustBeInRange(opts.borderColourRight,0,1)} = [0 1 0]
		%> ---- TASK ------------------------------------------------------
		%> initial offset in degrees [x y]: the cross from the circle in
		%> align mode, or the movable grating(s) from the centre in grating
		%> mode (set it on one eye only to start with a dichoptic offset)
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
	if mod(numel(opts.gratingArgs), 2) ~= 0
		error('PEPTest:gratingArgs', 'opts.gratingArgs must be name-value pairs');
	end

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
	sM.font.TextSize = 35;

	%% ---- build the stimuli for the selected mode ---------------------
	% PTB stereo draw buffer 0 = left eye, 1 = right eye
	circle = []; cross = [];					% align mode only
	leftGrating = []; rightGrating = [];		% grating mode only
	circleX = 0; circleY = 0;					% circle stays at screen centre
	crossX = 0; crossY = 0;
	leftX = 0; leftY = 0;						% grating positions, degrees
	rightX = 0; rightY = 0;
	circleChannel = 0; crossChannel = 1;

	switch opts.mode

		case 'align'
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

			%> eye / channel mapping, the circle gets the chosen eye
			if strcmpi(opts.circleEye, 'left')
				circleChannel = 0; crossChannel = 1;
			else
				circleChannel = 1; crossChannel = 0;
			end

			crossX = opts.startOffset(1);
			crossY = opts.startOffset(2);
			circle.updateXY(circleX, circleY, true);
			cross.updateXY(crossX, crossY, true);

		case 'grating'
			leftGrating = makeGrating(opts, sM, 'left', ...
				opts.gratingAngleLeft, opts.gratingPhaseLeft);
			rightGrating = makeGrating(opts, sM, 'right', ...
				opts.gratingAngleRight, opts.gratingPhaseRight);
			%> only the movable grating(s) take the start offset, so a
			%> dichoptic offset can be presented for the subject to null
			if any(strcmpi(opts.gratingMove, {'both','left'}))
				leftX = opts.startOffset(1); leftY = opts.startOffset(2);
			end
			if any(strcmpi(opts.gratingMove, {'both','right'}))
				rightX = opts.startOffset(1); rightY = opts.startOffset(2);
			end
			leftGrating.updateXY(leftX, leftY, true);
			rightGrating.updateXY(rightX, rightY, true);

	end

	%% ---- instruction screen ------------------------------------------
	KbName('UnifyKeyNames');
	moveKeys = [KbName('LeftArrow') KbName('RightArrow') ...
		KbName('UpArrow') KbName('DownArrow')];
	shiftKeys = [KbName('LeftShift') KbName('RightShift')];
	acceptKeys = [KbName('space') KbName('Return')];
	exitKeys = KbName('ESCAPE');
	% arrows move the cross (align) or the grating(s) (grating)
	keyList = unique([moveKeys shiftKeys acceptKeys exitKeys]);

	RestrictKeysForKbCheck(keyList);
	ListenChar(-1);
	HideCursor;
	Priority(MaxPriority(sM.win));

	borderPx = max(1, round(opts.borderWidth * sM.ppd));

	if opts.showInstructions
		if strcmpi(opts.mode, 'grating')
			waitForStart(sM, opts.keyFcn, opts, borderPx, ...
				"Gratings: L " + string(opts.gratingAngleLeft) + ...
				" deg | R " + string(opts.gratingAngleRight) + " deg", ...
				"Arrows = move (" + string(opts.gratingMove) + ...
				")    Shift = fine    SPACE = stop    ESC = quit");
		else
			waitForStart(sM, opts.keyFcn, opts, borderPx, ...
				"Align the cross inside the circle", ...
				"Arrows = move    Shift = fine    SPACE = accept    ESC = quit");
		end
	end

	%% ---- main loop ---------------------------------------------------
	ifi = sM.screenVals.ifi;
	if opts.verbose
		fprintf('PEPTest: screen %d, stereoMode %d, ppd %.2f, %dx%d px\n', ...
			sM.screen, sM.stereoMode, sM.ppd, sM.screenVals.screenWidth, sM.screenVals.screenHeight);
		fprintf('PEPTest: mode %s | border %d | grating [sf %.2f tf %.2f contrast %.2f size %.2f]\n', ...
			opts.mode, opts.showBorder, opts.gratingSF, opts.gratingTF, ...
			opts.gratingContrast, opts.gratingSize);
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
			if strcmpi(opts.mode, 'grating')
				exitReason = 'key';		% nothing to accept in grating mode
			else
				exitReason = 'accept';
			end
			break
		end

		%% ---- arrow keys: one discrete step, then continuous when held
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

		%% ---- apply the movement to the adjustable stimulus
		if dx ~= 0 || dy ~= 0
			switch opts.mode

				case 'align'
					%% ---- move the cross (offset clamped relative to the circle)
					[cx, cy] = clampOffset(crossX + dx - circleX, ...
						crossY + dy - circleY, opts.maxOffset);
					crossX = circleX + cx;
					crossY = circleY + cy;
					cross.updateXY(crossX, crossY, true);	% degrees -> pixels
					logPos = [crossX crossY];

				case 'grating'
					%% ---- move the grating(s), clamped about the centre
					switch opts.gratingMove
						case 'both'
							[leftX, leftY] = clampOffset(leftX + dx, leftY + dy, opts.maxOffset);
							rightX = leftX; rightY = leftY;
						case 'left'
							[leftX, leftY] = clampOffset(leftX + dx, leftY + dy, opts.maxOffset);
						case 'right'
							[rightX, rightY] = clampOffset(rightX + dx, rightY + dy, opts.maxOffset);
					end
					leftGrating.updateXY(leftX, leftY, true);
					rightGrating.updateXY(rightX, rightY, true);
					if strcmpi(opts.gratingMove, 'right')
						logPos = [rightX rightY];
					else
						logPos = [leftX leftY];
					end
			end

			if nLog < size(moveLog, 1)
				nLog = nLog + 1;
				moveLog(nLog, :) = [now - startTime, logPos];
			end
		end

		%% ---- draw: background and one stimulus per eye
		if sM.stereoMode > 0
			%each eye has its own back buffer, so clear both
			sM.switchChannel(0); sM.drawBackground();
			sM.switchChannel(1); sM.drawBackground();
		else
			%mono debug view: both eyes share one buffer, a second fill
			%would erase the stimuli drawn below
			sM.drawBackground();
		end

		%% ---- per eye stimuli
		switch opts.mode
			case 'align'
				sM.switchChannel(circleChannel); circle.draw(); drawScreenCenter(sM,8);
				sM.switchChannel(crossChannel); cross.draw();
			case 'grating'
				%buffer 0 = left eye, buffer 1 = right eye; animate() advances
				%the drift phase for the next frame when tf > 0
				sM.switchChannel(0); leftGrating.draw(); animate(leftGrating);
				sM.switchChannel(1); rightGrating.draw(); animate(rightGrating);
		end

		%% ---- eye borders drawn last so they always frame the display
		drawEyeBorders(sM, opts, borderPx);

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
	switch opts.mode
		case 'align'
			offsetX = crossX - circleX;
			offsetY = crossY - circleY;		% +Y is down the screen
			gratingPositions = [];
		case 'grating'
			%> offset of the right eye grating relative to the left one
			offsetX = rightX - leftX;
			offsetY = rightY - leftY;
			crossX = NaN; crossY = NaN;
			gratingPositions = [leftX leftY; rightX rightY];
	end

	out = struct();
	out.mode = opts.mode;
	out.offset = [offsetX offsetY];
	out.offsetX = offsetX;
	out.offsetY = offsetY;
	out.crossPosition = [crossX crossY];
	out.circlePosition = [circleX circleY];
	out.circleEye = opts.circleEye;
	out.stereoMode = opts.stereoMode;
	out.gratingAngles = [opts.gratingAngleLeft opts.gratingAngleRight];
	out.gratingPhases = [opts.gratingPhaseLeft opts.gratingPhaseRight];
	out.gratingPositions = gratingPositions;
	out.gratingMove = opts.gratingMove;
	out.borderColours = [opts.borderColourLeft; opts.borderColourRight];
	out.exitReason = exitReason;
	out.nFrames = nFrames;
	out.nMissedFrames = nMissed;
	out.duration = duration;
	out.fps = nFrames / max(duration, eps);
	out.log = moveLog(1:nLog, :);
	out.parameters = opts;
	out.dateStamp = char(datetime('now'));

	fprintf('\n==== PEPTest finished (%s) ====\n', exitReason);
	fprintf('mode = %s | stereoMode = %d | background = [%g %g %g]\n', ...
		opts.mode, opts.stereoMode, opts.bgColour);
	switch opts.mode
		case 'align'
			fprintf('circle eye = %s | colour = [%g %g %g]\n', ...
				opts.circleEye, opts.stimColour);
			fprintf('cross offset: X = %+0.3f deg, Y = %+0.3f deg  (+X right, +Y down)\n', ...
				offsetX, offsetY);
		case 'grating'
			fprintf('gratings: sf %.2f c/deg | tf %.2f Hz | contrast %.2f | size %.2f deg\n', ...
				opts.gratingSF, opts.gratingTF, opts.gratingContrast, opts.gratingSize);
			if opts.gratingAngleLeft == opts.gratingAngleRight
				orient = 'same';
			else
				orient = 'different';
			end
			fprintf('orientation: left %+0.1f deg | right %+0.1f deg (%s)\n', ...
				opts.gratingAngleLeft, opts.gratingAngleRight, orient);
			fprintf('position: left [%+0.3f %+0.3f] | right [%+0.3f %+0.3f] deg (moved: %s)\n', ...
				leftX, leftY, rightX, rightY, opts.gratingMove);
			fprintf('interocular offset (right - left): X = %+0.3f deg, Y = %+0.3f deg\n', ...
				offsetX, offsetY);
	end
	if opts.showBorder
		fprintf('eye border %d px: left = [%g %g %g] | right = [%g %g %g]\n', ...
			borderPx, opts.borderColourLeft, opts.borderColourRight);
	end
	fprintf('duration %.2f s | %d frames | %.1f fps | %d missed\n\n', ...
		duration, nFrames, out.fps, nMissed);

end

% ========================================================================
% ============================ LOCAL FUNCTIONS ===========================
% ========================================================================

function [x, y] = clampOffset(x, y, maxOffset)
%> clamp a degree offset to +/- maxOffset on each axis
	x = min(maxOffset, max(-maxOffset, x));
	y = min(maxOffset, max(-maxOffset, y));
end

function g = makeGrating(opts, sM, eyeName, angle, phase)
%> build, setup and centre one gratingStimulus for a single eye, passing
%> every grating option straight through to gratingStimulus
	args = {'name', ['PEPgrating-' eyeName], ...
		'size', opts.gratingSize, ...
		'colour', opts.gratingColour, ...
		'angle', angle, ...
		'phase', phase, ...
		'sf', opts.gratingSF, ...
		'tf', opts.gratingTF, ...
		'contrast', opts.gratingContrast, ...
		'type', opts.gratingType, ...
		'mask', opts.gratingMask, ...
		'sigma', opts.gratingSigma, ...
		'verbose', opts.verbose};
	if ~isempty(opts.gratingArgs)
		%> gratingArgs wins over the dedicated options above, so drop any
		%> duplicated name-value PAIR before merging: makeArgs uses
		%> cell2struct, which errors on repeated field names
		given = opts.gratingArgs(1:2:end);
		keep = repelem(~ismember(args(1:2:end), given), 2);
		args = [args(keep) opts.gratingArgs(:)'];
	end
	g = gratingStimulus(args{:});
	setup(g, sM);
end

function drawEyeBorders(sM, opts, borderPx)
%> frame each eye's viewport: red for the left eye draw buffer, green for
%> the right. In mono both eyes share one buffer, so the right eye colour is
%> drawn as a frame just inside the left eye colour.
	if ~opts.showBorder; return; end
	if sM.stereoMode > 0
		sM.switchChannel(0);
		drawEyeBorder(sM, opts.borderColourLeft, borderPx, 0);
		sM.switchChannel(1);
		drawEyeBorder(sM, opts.borderColourRight, borderPx, 0);
	else
		sM.switchChannel(0);
		drawEyeBorder(sM, opts.borderColourLeft, borderPx, 0);
		sM.switchChannel(1);
		drawEyeBorder(sM, opts.borderColourRight, borderPx, borderPx);
	end
end

function drawEyeBorder(sM, colour, widthPx, insetPx)
%> draw one frame around the per-eye viewport, inset by insetPx pixels
	r = InsetRect(sM.winRect, insetPx, insetPx);
	Screen('FrameRect', sM.win, [colour 1], r, widthPx);
end

function waitForStart(sM, keyFcn, opts, borderPx, txt1, txt2)
%> draw an instruction screen to BOTH eyes, then wait for a fresh key press
%> and its release so the press cannot leak into the task loop.
	xLeft = sM.screenVals.leftInDegrees + 0.5;	% start at this eye's left edge
	for ch = 0:1
		sM.switchChannel(ch);
		sM.drawBackground();
		sM.drawText(txt1, xLeft, -1.5);
		sM.drawText(txt2, xLeft, 0.5);
	end
	drawEyeBorders(sM, opts, borderPx);
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

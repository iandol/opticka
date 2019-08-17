sca;
close all;
clearvars;

PsychDefaultSetup(2);

Tobii = EyeTrackingOperations();

eyetrackers = Tobii.find_all_eyetrackers();

if isempty(eyetrackers);disp('No eyetrackers are connected!');return;end

eyetracker = Tobii.get_eyetracker(eyetrackers(1).Address);
eyetracker.stop_gaze_data();
if isa(eyetracker,'EyeTracker')
	disp(['Address:',eyetracker.Address]);
	disp(['Name:',eyetracker.Name]);
	disp(['Serial Number:',eyetracker.SerialNumber]);
	disp(['Model:',eyetracker.Model]);
	disp(['Firmware Version:',eyetracker.FirmwareVersion]);
	disp(['Runtime Version:',eyetracker.RuntimeVersion]);
else
	disp('Eye tracker not found!');
end

sM = screenManager('debug',false,'blend',true,'screen',2);
Screen('Preference', 'SkipSyncTests', 0)
screenVals = sM.open();
window = sM.win;
white = sM.screenVals.white;
black = sM.screenVals.black;
[width, height] = Screen('WindowSize', window);
screen_pixels = [width height];
[xCenter, yCenter] = RectCenter(sM.winRect);
% Dot size in pixels
dotSizePix = 15;

Screen('TextSize', window, 20);

% Start collecting data
% The subsequent calls return the current values in the stream buffer.
% If a flat structure is prefered just use an extra input 'flat'.
% i.e. gaze_data = eyetracker.get_gaze_data('flat');
eyetracker.get_gaze_data();

while ~KbCheck
	
	DrawFormattedText(window, 'When correctly positioned press any key to start the calibration.', 'center', height * 0.1, white);
	
	distance = [];
	
	gaze_data = eyetracker.get_gaze_data();
	
	if ~isempty(gaze_data)
		last_gaze = gaze_data(end);
		
		validityColor = [1 0 0];
		
		% Check if user has both eyes inside a reasonable tacking area.
		if last_gaze.LeftEye.GazeOrigin.Validity.Valid && last_gaze.RightEye.GazeOrigin.Validity.Valid
			left_validity = all(last_gaze.LeftEye.GazeOrigin.InTrackBoxCoordinateSystem(1:2) < 0.85) ...
				&& all(last_gaze.LeftEye.GazeOrigin.InTrackBoxCoordinateSystem(1:2) > 0.15);
			right_validity = all(last_gaze.RightEye.GazeOrigin.InTrackBoxCoordinateSystem(1:2) < 0.85) ...
				&& all(last_gaze.RightEye.GazeOrigin.InTrackBoxCoordinateSystem(1:2) > 0.15);
			if left_validity && right_validity
				validityColor = [0 1 0];
			end
		end
		
		origin = [width/4 height/4];
		tsize = [width/2 height/2];
		
		penWidthPixels = 3;
		baseRect = [0 0 tsize(1) tsize(2)];
		frame = CenterRectOnPointd(baseRect, width/2, yCenter);
		
		Screen('FrameRect', window, validityColor, frame, penWidthPixels);
		
		% Left Eye
		if last_gaze.LeftEye.GazeOrigin.Validity.Valid
			distance = [distance; round(last_gaze.LeftEye.GazeOrigin.InUserCoordinateSystem(3)/10,1)];
			left_eye_pos_x = double(1-last_gaze.LeftEye.GazeOrigin.InTrackBoxCoordinateSystem(1))*tsize(1) + origin(1);
			left_eye_pos_y = double(last_gaze.LeftEye.GazeOrigin.InTrackBoxCoordinateSystem(2))*tsize(2) + origin(2);
			Screen('DrawDots', window, [left_eye_pos_x left_eye_pos_y], dotSizePix, validityColor, [], 2);
		end
		
		% Right Eye
		if last_gaze.RightEye.GazeOrigin.Validity.Valid
			distance = [distance;round(last_gaze.RightEye.GazeOrigin.InUserCoordinateSystem(3)/10,1)];
			right_eye_pos_x = double(1-last_gaze.RightEye.GazeOrigin.InTrackBoxCoordinateSystem(1))*tsize(1) + origin(1);
			right_eye_pos_y = double(last_gaze.RightEye.GazeOrigin.InTrackBoxCoordinateSystem(2))*tsize(2) + origin(2);
			Screen('DrawDots', window, [right_eye_pos_x right_eye_pos_y], dotSizePix, validityColor, [], 2);
		end
		
		
	end
	
	DrawFormattedText(window, sprintf('Current distance to the eye tracker: %.2f cm.',mean(distance)), 'center', height * 0.85, white);
	
	sM.flip();
	
end

eyetracker.stop_gaze_data();

spaceKey = KbName('Space');
RKey = KbName('R');

dotSizePix = 20;

dotColor = [[1 0 0];[1 1 1]]; % Red and white

leftColor = [1 0 0]; % Red
rightColor = [0 0 1]; % Bluesss

% Calibration points
lb = 0.1;  % left bound
xc = 0.5;  % horizontal center
rb = 0.9;  % right bound
ub = 0.1;  % upper bound
yc = 0.5;  % vertical center
bb = 0.9;  % bottom bound

points_to_calibrate = [[xc,yc];[lb,ub];[rb,ub];[lb,bb];[rb,bb]];

% Create calibration object
calib = ScreenBasedCalibration(eyetracker);
calibrating = true;

while calibrating
	% Enter calibration mode
	calib.enter_calibration_mode();
	
	for i=1:length(points_to_calibrate)
		
		Screen('DrawDots', window, points_to_calibrate(i,:).*screen_pixels, dotSizePix, dotColor(1,:), [], 2);
		Screen('DrawDots', window, points_to_calibrate(i,:).*screen_pixels, dotSizePix*0.3, dotColor(2,:), [], 2);
		
		Screen('Flip', window);
		
		% Wait a moment to allow the user to focus on the point
		WaitSecs(1);
		
		if calib.collect_data(points_to_calibrate(i,:)) ~= CalibrationStatus.Success
			% Try again if it didn't go well the first time.
			% Not all eye tracker models will fail at this point, but instead fail on ComputeAndApply.
			calib.collect_data(points_to_calibrate(i,:));
		end
		
	end
	
	DrawFormattedText(window, 'Calculating calibration result....', 'center', 'center', white);
	
	Screen('Flip', window);
	
	% Blocking call that returns the calibration result
	calibration_result = calib.compute_and_apply();
	
	calib.leave_calibration_mode();
	
	if calibration_result.Status ~= CalibrationStatus.Success
		break
	end
	
	% Calibration Result
	
	points = calibration_result.CalibrationPoints;
	
	for i=1:length(points)
		Screen('DrawDots', window, points(i).PositionOnDisplayArea.*screen_pixels, dotSizePix*0.5, dotColor(2,:), [], 2);
		for j=1:length(points(i).RightEye)
			if points(i).LeftEye(j).Validity == CalibrationEyeValidity.ValidAndUsed
				Screen('DrawDots', window, points(i).LeftEye(j).PositionOnDisplayArea.*screen_pixels, dotSizePix*0.3, leftColor, [], 2);
				Screen('DrawLines', window, ([points(i).LeftEye(j).PositionOnDisplayArea; points(i).PositionOnDisplayArea].*screen_pixels)', 2, leftColor, [0 0], 2);
			end
			if points(i).RightEye(j).Validity == CalibrationEyeValidity.ValidAndUsed
				Screen('DrawDots', window, points(i).RightEye(j).PositionOnDisplayArea.*screen_pixels, dotSizePix*0.3, rightColor, [], 2);
				Screen('DrawLines', window, ([points(i).RightEye(j).PositionOnDisplayArea; points(i).PositionOnDisplayArea].*screen_pixels)', 2, rightColor, [0 0], 2);
			end
		end
		
	end
	
	DrawFormattedText(window, 'Press the ''R'' key to recalibrate or ''Space'' to continue....', 'center', height * 0.95, white)
	
	Screen('Flip', window);
	
	while true
		[ keyIsDown, seconds, keyCode ] = KbCheck;
		keyCode = find(keyCode, 1);
		
		if keyIsDown
			if keyCode == spaceKey
				calibrating = false;
				break;
			elseif keyCode == RKey
				break;
			end
			KbReleaseWait;
		end
	end
end

pointCount = 8;

% Generate an array with coordinates of random points on the display area
rng;
points = rand(pointCount,2);

% Start to collect data
eyetracker.get_gaze_data();

collection_time_s = 2; % seconds

% Cell array to store events
events = cell(2, pointCount);
k = {};
tt=[];
sz = [];
t2 = [];
vbl = Screen('Flip', window);
for i=1:pointCount
	events{1,i} = {Tobii.get_system_time_stamp, points(i,:)};
	tlen = randi(8)+1;
	for j = 1:(screenVals.fps * randi(8))
		Screen('DrawDots', window, points(i,:).*screen_pixels, dotSizePix/2, dotColor(2,:), [], 3);
		if i > 3
			t1=tic;
			k{j} = eyetracker.get_gaze_data('flat');
			tt(end+1) = toc(t1)*1e3;
			if ~isempty(k{j}(end)) && isa(k{j}(end),'GazeData')
				posl = double(k{j}(end).LeftEye.GazePoint.OnDisplayArea);
				posr = double(k{j}(end).RightEye.GazePoint.OnDisplayArea);				
				if ~isempty(posl) && ~isempty(posr)
					Screen('DrawDots', window, [[posl(1)*width;posl(2)*height],[posr(1)*width;posr(2)*height]], 10, [1 1 0; 1 0 1]', [], 3);
				end
			elseif isfield(k{j},'left_gaze_point_on_display_area') && ~isempty(k{j}.left_gaze_point_on_display_area)
				posl = double(k{j}.left_gaze_point_on_display_area(end,:));
				posr = double(k{j}.right_gaze_point_on_display_area(end,:));
				if ~isempty(posl) && ~isempty(posr)
					Screen('DrawDots', window, [[posl(1)*width;posl(2)*height],[posr(1)*width;posr(2)*height]], 10, [1 1 0; 1 0 1]', [], 3);
				end
			end
		end
		vbl = Screen('Flip', window, vbl + screenVals.halfisi);
	end
	if i > 3 
		data{i} = k;
		fprintf('Mean loop = %.5g +- %.5g ms for %i samples\n', mean(tt), analysisCore.stderr(tt,'SE',true),length(tt));
	else
		t=tic;
		data{i} = eyetracker.get_gaze_data('flat');
		t2(end+1) = toc(t)*1e3;
		if isa(data{i},'GazeData')
			sz(end+1) = length(data{i});
		else
			sz(end+1) = size(data{i}.device_time_stamp,1);
		end
		fprintf('Trial %i Time %i to collect %i samples: %.5g ms\n', i, tlen, sz(end), t2(end));
	end
	% Event when stopping to show the stimulus
	events{2,i} = {Tobii.get_system_time_stamp, points(i,:)};
end
Screen('DrawText', window, 'Finished...')
Screen('Flip', window')
WaitSecs(1);

% Retreive data collected during experiment
collected_gaze_data = eyetracker.get_gaze_data();

eyetracker.stop_gaze_data();

Priority(0);ShowCursor;ListenChar(0)
close(sM);







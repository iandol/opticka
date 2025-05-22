% Functions used from iViewX toolbox:
% iView('initialize', ivx) - Initializes the connection to the iView X system.
% iViewX_vk('calibrate', ivx) - Runs the eye tracker calibration procedure.
% iViewX_vk('openconnection', ivx) - Opens the data connection for streaming eye data.
% iViewX_vk('setscreensize', ivx) - Informs the iView X system about the display size.
% iViewX_vk('startrecording', ivx) - Begins recording eye movement data.
% iViewX_vk('message', ivx, '...') - Sends a message to be logged in the iView X data file.
% iViewX_vk('receivelast', ivx) - Retrieves the most recent eye gaze data sample.
% iViewX_vk('stoprecording', ivx) - Stops the eye movement recording.
% iViewX_vk('datafile', ivx, '...') - Saves the recorded data to a specified file path on the iView workstation.
% initIViewXDefaults_vk([], [], '100.1.1.1', []) - Initializes the iViewX structure with default settings and IP.


% Short MATLAB example program using iViewX and Psychophysics Toolboxes
% for a simple eyetracking experiment.

% STEP 1: Initialize iViewX defaults and environment
% Get default iViewX settings, specify IP address.
ivx = initIViewXDefaults_vk([], [], '100.1.1.1', []);

% Unify key names for cross-platform compatibility with Psychtoolbox.
KbName('UnifyKeyNames');
stopkey = KbName('ESCAPE');
startkey = KbName('space');

% STEP 2: Initialize connection with iViewX
% Connect to the iView X tracker. Exit if connection fails.
if iView('initialize', ivx) ~= 1
    return % Exit program on failure
end


% STEP 3: Open graphics window
% Open a Psychtoolbox window on the main screen.
ScreenNumber = 1; % Main screen
[window, screenRect] = Screen('OpenWindow', ScreenNumber, 0); % Open window, get handle and rect

% Get screen center coordinates.
[xCenter, yCenter] = RectCenter(screenRect);
gray = GrayIndex(window);
white = WhiteIndex(window);
Screen('FillRect', window, gray);
Screen('Flip', window);

% Store window handle in ivx structure.
ivx.window = window;

% Wait for space key press to start calibration.
while 1
    [keyIsDown, secs, keyCode] = KbCheck;
    if keyCode(startkey) % Check if start key is pressed
       break;
    end
end
WaitSecs(0.1); % Short pause
fprintf('start run the calibrate\n'); % Indicate calibration start

% Set the data format for eye tracking output from iView X.
% Defines the format string for gaze and pupil data.
result = iViewXComm('send', ivx, 'ET_FRM "%TS: %SX,%SY,%DX,%DY" ');%TS: timestamp, SX SY: gaze X Y, DX DY: pupil diameter;X Y(PIXEL)
%ET_FRM: sets format for data output (check help"remote command reference")

% STEP 4: Calibrate eye tracker
% Run the standard iView X calibration procedure.
iViewX_vk('calibrate', ivx);

% Optional: Perform drift correction (fixation check at screen center).
% iViewX_vk('driftcorrection',ivx);

% STEP 5: Start eye position recording
% Open data connection and start recording.
[success, ivx] = iViewX_vk('openconnection', ivx); % Open data stream
[success, ivx] = iViewX_vk('setscreensize', ivx); % Inform iView X about screen size
iViewX_vk('startrecording', ivx); % Begin recording

%% STEP 6: Main measurement loop (Fixation check example)
% Set experiment parameters.
waitDuration = 1; % Duration for fixation check
ifi = Screen('GetFlipInterval', window); 
numWaitFrames = round(waitDuration / ifi); 
numFixFrames = numWaitFrames / 2; % Frames required for successful fixation

% Define fixation window properties.
fixationWindowCenter = [xCenter, yCenter];
fixationWindowSize = 60;

% Define coordinates for drawing a fixation cross.
xCoords = [-10, 10, 0, 0];
yCoords = [0, 0, -10, 10];
allCoords = [xCoords; yCoords];
lineWidthPix = 5; 

% Fixation state variables.
subjectFixState = 0; % 0: not fixating, 1: fixating
frames_in_window = 0; % Counter for frames inside fixation window
frames_out_of_window = 0; % Counter for frames outside fixation window (while in state 1)

% Baseline fixation loop: Wait for subject to fixate.
waitflipstamp = Screen('Flip', window);

for waitcontrolframe = 1:numWaitFrames
    % Send message to iView X data file.
    iViewX_vk('message', ivx, 'CheckFix');

    % Draw fixation cross.
    Screen('DrawLines', window, allCoords,...
        lineWidthPix, white, [xCenter, yCenter], 2);

    % Get latest eye gaze data.
    [iviewdata, ivx] = iViewX_vk('receivelast', ivx);

    % Parse gaze X and Y coordinates from the received string.
    tokens = regexp(iviewdata, ':\s*(\d+),(\d+)', 'tokens');
    x = str2double(tokens{1}{1});
    y = str2double(tokens{1}{2});

    % Check and update subject's fixation state.
    is_gaze_in_window = (x >= fixationWindowCenter(1) - fixationWindowSize / 2) && ...
                        (x <= fixationWindowCenter(1) + fixationWindowSize / 2) && ...
                        (y >= fixationWindowCenter(2) - fixationWindowSize / 2) && ...
                        (y <= fixationWindowCenter(2) + fixationWindowSize / 2);

    if subjectFixState == 0 && is_gaze_in_window
        subjectFixState = 1; % Transition to fixating state
    end

    if subjectFixState == 1
        frames_in_window = frames_in_window + 1;
        if ~is_gaze_in_window
            frames_out_of_window = frames_out_of_window + 1;
        end

        % Reset if fixation is lost for too many frames.
        if frames_out_of_window >= 9
            subjectFixState = 0;
            frames_in_window = 0;
            frames_out_of_window = 0;
        end

        % If fixation maintained for required frames, break loop.
        if frames_in_window >= numFixFrames
            iViewX_vk('message', ivx, 'FixSuccess'); % Mark fixation success
            break;
        end
    end

    % Flip the screen to update display.
    waitflipstamp = Screen('Flip', window, waitflipstamp + 0.5 * ifi);
end

% STEP 7: Finish experiment
% Stop recording, save data, and close window.
iViewX_vk('stoprecording', ivx); % Stop eye tracking recording
iViewX_vk('datafile', ivx, 'D:\wqc\cwj.idf'); % Save data file on iView workstation
Screen('close', window); 

% Note: Depending on the iViewX_vk implementation



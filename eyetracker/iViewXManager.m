% ========================================================================
classdef iViewXManager < eyetrackerCore & eyetrackerSmooth
%> @class iViewXManager
%> @brief Manages the SMI iViewX eyetrackers using the iViewX Toolbox for Psychtoolbox.
%>
%> Copyright ©2023 Your Name/Institution — released: LGPL3, see LICENCE.md
% ========================================================================

    properties (SetAccess = protected, GetAccess = public)
        %> type of eyetracker
        type = 'iViewX'
        %> iViewX SDK connection object or structure
        ivx % This will store connection details or the SDK object
    end

    properties
        %> initial setup and calibration values
        calibration = struct(...
            'ip', '127.0.0.1',... % Default IP for iViewX server
            'port', 4444,... % Default port for iViewX server (example, check demo)
            'monitorDevice', 'PRIMARY',... % Monitor device for calibration
            'autoAccept', 1,... % Auto accept calibration points (0 or 1)
            'pacing', 1000,... % Time in ms to display calibration point
            'calPositions', [-12 0; 0 -12; 0 0; 0 12; 12 0],... % Default 5-point calibration
            'valPositions', [-12 0; 0 -12; 0 0; 0 12; 12 0],... % Default 5-point validation
            'screenNumber', [],... % Will be set from screenManager
            'window', [], ... % Will be set from screenManager
            'windowRect', [], ... % Will be set from screenManager
            'units', 'deg', ... % Units for position, 'deg' or 'px'
            'targetSize', 0.5, ... % Default target size in degrees
            'targetShape', 'circle', ... % 'circle', 'cross', or path to image
            'targetColor', [255 0 0] ... % Default target color
        );
        
        %> data storage options (if any specific to iViewX)
        dataOptions = struct();
    end

    properties (Hidden = true)
        % Any hidden properties needed
    end

    properties (SetAccess = protected, GetAccess = protected)
        %> allowed properties passed to object upon construction
        allowedProperties = {'calibration', 'dataOptions'} % Add other iViewX specific ones
    end

    methods %------------------PUBLIC METHODS
        % ===================================================================
        function me = iViewXManager(varargin)
            args = optickaCore.addDefaults(varargin, struct('name', 'iViewXManager', ...
                                                            'useOperatorScreen', true, ...
                                                            'sampleRate', 250)); % Default sample rate, adjust as needed
            me = me@eyetrackerCore(args);
            me = me@eyetrackerSmooth(); % Call superclass constructor for eyetrackerSmooth
            me.parseArgs(args, me.allowedProperties);
            if isprop(me, 'sampleRate') % Ensure smoothing knows the sample rate
                me.smoothing.sampleRate = me.sampleRate;
            end
            me.ivx = struct(); 
        end

        % ===================================================================
        % BEGIN ABSTRACT METHOD IMPLEMENTATIONS
        % ===================================================================

        function success = initialise(me, sM, sM2)
            success = false;
            if me.isOff; me.isConnected = false; success = true; return; end

            me.screen = sM;
            if ~isempty(me.screen) && isvalid(me.screen) && me.screen.isOpen
                me.ppd_ = me.screen.ppd;
                me.win = me.screen.win;
            else
                % This case should ideally be handled by ensuring sM is always valid and open
                % or by erroring out if a valid screen is essential.
                warning('iViewXManager: Main screen (sM) is not valid or not open during initialise.');
                me.ppd_ = [NaN NaN]; % Default to NaN if screen is not available
            end


            if me.isDummy
                me.salutation('Initialise', 'Running iViewX in Dummy Mode (as specified).', true);
                me.isConnected = true; 
                if isprop(me, 'sampleRate') && ~isempty(me.sampleRate)
                    me.smoothing.sampleRate = me.sampleRate;
                else
                    me.sampleRate = 250; 
                    me.smoothing.sampleRate = me.sampleRate;
                    fprintf('iViewXManager.initialise: sampleRate not specified, defaulting to %d Hz for dummy mode.\n', me.sampleRate);
                end
                success = true;
                % Operator screen setup for dummy mode
                if me.useOperatorScreen
                    if exist('sM2','var') && ~isempty(sM2) && isa(sM2, 'screenManager') && sM2.isOpen
                        me.operatorScreen = sM2;
                    else 
                        opScreenNumber = [];
                        if ~isempty(me.screen) && isvalid(me.screen); opScreenNumber = me.screen.screenNumber; end
                        me.operatorScreen = screenManager('isDummy',true,'screenNumber',opScreenNumber,'displayName','Operator Screen (Dummy)');
                        me.operatorScreen.debug = me.debug;
                        me.operatorScreen.verbose = me.verbose;
                        if ~me.operatorScreen.isOpen; me.operatorScreen.open(); end
                    end
                    if ~isempty(me.operatorScreen) && me.operatorScreen.isOpen
                        me.operatorScreen.setColour([0 0 0]); 
                        me.operatorScreen.drawText('iViewX Operator Display (Dummy Mode)', [], me.operatorScreen.ppd*0.5, [255 255 255]);
                        me.operatorScreen.flip();
                    end
                end
                return;
            end
            
            fprintf('iViewXManager.initialise(): Attempting to connect to iViewX server...\n');
            ip = me.calibration.ip;
            port = me.calibration.port;

            try
                connectionAttempt = iViewX('openconnection', ip, port); % Invented SDK call
                if ~isempty(connectionAttempt) && (isstruct(connectionAttempt) || (isnumeric(connectionAttempt) && connectionAttempt ~= 0))
                    me.ivx.connection = connectionAttempt; 
                    me.isConnected = true;
                    me.isDummy = false;
                    if isempty(me.sampleRate); me.sampleRate = 250; fprintf('iViewXManager.initialise: sampleRate not set, defaulting to %d Hz.\n', me.sampleRate); end
                    me.smoothing.sampleRate = me.sampleRate;
                    me.salutation('Initialise', sprintf('iViewX Connected to %s:%d.', ip, port), true);
                else
                    me.isConnected = false;
                    me.isDummy = true; 
                    me.salutation('Initialise', sprintf('Failed to connect to iViewX at %s:%d. Running in Dummy Mode.', ip, port), true);
                    if isempty(me.sampleRate); me.sampleRate = 250; end
                    me.smoothing.sampleRate = me.sampleRate;
                end
            catch ME_connect
                me.isConnected = false;
                me.isDummy = true; 
                me.salutation('Initialise', sprintf('Error connecting to iViewX at %s:%d: %s. Running in Dummy Mode.', ip, port, ME_connect.message), true);
                if isempty(me.sampleRate); me.sampleRate = 250; end
                me.smoothing.sampleRate = me.sampleRate;
            end

            if me.useOperatorScreen
                if exist('sM2','var') && ~isempty(sM2) && isa(sM2, 'screenManager') && sM2.isOpen
                    me.operatorScreen = sM2;
                else
                    availableScreens = Screen('Screens');
                    opScreenNumber = []; 
                    if ~isempty(me.screen) && isvalid(me.screen); opScreenNumber = me.screen.screenNumber + 1; end

                    if isempty(opScreenNumber) || ~ismember(opScreenNumber, availableScreens)
                        if length(availableScreens) > 1 && ~isempty(me.screen) && isvalid(me.screen)
                            opScreenNumber = availableScreens(find(availableScreens ~= me.screen.screenNumber, 1, 'first'));
                        elseif ~isempty(me.screen) && isvalid(me.screen)
                            opScreenNumber = me.screen.screenNumber; 
                        else % Fallback if me.screen is also problematic
                            opScreenNumber = max(availableScreens);
                        end
                    end
                    
                    if isempty(me.operatorScreen) || ~isvalid(me.operatorScreen) || ~me.operatorScreen.isOpen || me.operatorScreen.screenNumber ~= opScreenNumber
                         if ~isempty(me.operatorScreen) && isvalid(me.operatorScreen) && me.operatorScreen.isOpen; me.operatorScreen.close(); end
                         me.operatorScreen = screenManager('screenNumber',opScreenNumber, 'debug', me.debug, 'verbose', me.verbose, 'displayName','iViewX Operator Screen');
                         if ~me.operatorScreen.isOpen; me.operatorScreen.open(); end % Ensure it's open
                    end
                end
                if ~isempty(me.operatorScreen) && me.operatorScreen.isOpen
                    me.operatorScreen.setColour([0 0 0]); 
                    me.operatorScreen.drawText('iViewX Operator Display', [], me.operatorScreen.ppd*0.5, [255 255 255]);
                    me.operatorScreen.flip();
                end
            else % if not using operator screen, ensure it's cleared if it was previously set
                 if ~isempty(me.operatorScreen) && isvalid(me.operatorScreen) && me.operatorScreen.isOpen; me.operatorScreen.close(); end
                 me.operatorScreen = [];
            end
            success = me.isConnected;
        end

        function close(me)
            fprintf('iViewXManager.close(): Closing iViewX connection...\n');
            if me.isConnected && ~me.isDummy && isfield(me.ivx, 'connection') && ~isempty(me.ivx.connection)
                try
                    iViewX('closeconnection', me.ivx.connection); % Invented SDK call
                    fprintf('iViewXManager.close(): Called iViewX(''closeconnection'').\n');
                catch ME_close
                    fprintf('iViewXManager.close(): Error during iViewX disconnection: %s\n', ME_close.message);
                end
            end
            me.isConnected = false;
            me.isRecording = false;
            if ~isempty(me.operatorScreen) && isvalid(me.operatorScreen) && me.operatorScreen.isOpen
                me.operatorScreen.close();
            end
            me.salutation('Close', 'iViewX connection closed.', true);
        end

        function connected = checkConnection(me)
            if me.isDummy
                connected = true; me.isConnected = true; return;
            end
            if ~isfield(me.ivx, 'connection') || isempty(me.ivx.connection)
                me.isConnected = false; connected = false; 
                if me.verbose; fprintf('iViewXManager.checkConnection: No connection handle.\n'); end
                return;
            end
            try
                status = iViewX('getstatus', me.ivx.connection); % Invented SDK call, assuming 1 for connected
                me.isConnected = (status == 1);
                 if me.verbose; fprintf('iViewXManager.checkConnection: SDK status %d, me.isConnected %d.\n',status,me.isConnected); end
            catch ME_status
                fprintf('iViewXManager.checkConnection(): Error checking iViewX status: %s. Assuming disconnected.\n', ME_status.message);
                me.isConnected = false;
            end
            connected = me.isConnected;
        end
        
        function statusMessage(me, message)
            if me.verbose
                fprintf('iViewXManager Status: %s\n', message);
            end
            % Optional: Send status message to iViewX host software display
            % if isfield(me.ivx, 'connection') && ~isempty(me.ivx.connection) && ~me.isDummy
            %     try
            %         % Invented SDK call for host display
            %         % iViewX('sethoststatus', me.ivx.connection, message); 
            %     catch ME_hoststatus
            %         % warning('iViewXManager: Could not send status to host: %s', ME_hoststatus.message);
            %     end
            % end
        end

        function updateDefaults(me)
            if me.verbose; fprintf('iViewXManager.updateDefaults(): Called.\n'); end
            % This method is called if properties of the manager are changed after initialization.
            % Example: If me.sampleRate can be changed and the iViewX system needs to be updated:
            % if ~me.isDummy && me.isConnected && isfield(me.ivx, 'connection')
            %     try
            %         currentSDKRate = iViewX('getsystemparameter', me.ivx.connection, 'samplerate'); % Invented
            %         if currentSDKRate ~= me.sampleRate
            %             status = iViewX('setsystemparameter', me.ivx.connection, 'samplerate', me.sampleRate); % Invented
            %             if status == 1 % Success
            %                 if me.verbose
            %                    fprintf('iViewXManager.updateDefaults(): Sample rate updated to %d Hz in SDK.\n', me.sampleRate);
            %                 end
            %                 me.smoothing.sampleRate = me.sampleRate; 
            %             else
            %                 warning('iViewXManager.updateDefaults(): Failed to update sample rate in SDK.');
            %             end
            %         end
            %     catch ME_updateSR
            %         warning('iViewXManager.updateDefaults(): Error trying to update sample rate: %s\n', ME_updateSR.message);
            %     end
            % end
            if isprop(me, 'sampleRate') && ~isempty(me.sampleRate) && isfield(me,'smoothing') && isa(me.smoothing,'eyetrackerSmooth')
                me.smoothing.sampleRate = me.sampleRate;
            end
        end

        function cal = trackerSetup(me, varargin)
            cal = struct('quality', -1, 'details', 'Calibration not performed');
            if me.isOff || (~me.isConnected && ~me.isDummy)
                warning('iViewXManager: Eyetracker not connected or is off, cannot calibrate!'); return;
            end
            if me.isDummy
                fprintf('iViewXManager.trackerSetup(): Dummy mode, skipping actual calibration.\n');
                me.statusMessage('Dummy calibration completed.');
                cal.quality = 0; cal.details = 'Dummy calibration successful'; return;
            end

            me.salutation('TrackerSetup', 'Starting iViewX Calibration Procedure.', true);
            try
                if isempty(me.screen) || ~isvalid(me.screen) || ~me.screen.isOpen; error('Subject screen not open/valid.'); end
                if me.useOperatorScreen && (isempty(me.operatorScreen) || ~isvalid(me.operatorScreen) || ~me.operatorScreen.isOpen); error('Operator screen enabled but not open/valid.'); end
                
                if me.useOperatorScreen
                    me.operatorScreen.setColour([0 0 0]);
                    me.operatorScreen.drawText('iViewX Operator Display - CALIBRATION', [], me.operatorScreen.ppd*0.5, [255 255 255]);
                    me.operatorScreen.flip();
                end

                calParams = me.calibration; 
                calParams.connectionHandle = me.ivx.connection;
                calParams.windowHandle = me.screen.win;
                calParams.screenWidthPx = me.screen.screenVals.width;
                calParams.screenHeightPx = me.screen.screenVals.height;
                calParams.screenNumberForSDK = me.screen.screenNumber; % Pass screen number if SDK needs it
                
                if strcmpi(calParams.units, 'deg') && ismethod(me,'deg2pix') % Check for deg2pix
                    calParams.calibrationPoints = me.deg2pix(calParams.calPositions);
                    calParams.validationPoints = me.deg2pix(calParams.valPositions);
                else % Assume pixels or SDK handles units
                    calParams.calibrationPoints = calParams.calPositions;
                    calParams.validationPoints = calParams.valPositions;
                end
                
                calResultStruct = iViewX('dotraining', me.ivx.connection, calParams); % Invented SDK call
                
                if isstruct(calResultStruct) && isfield(calResultStruct, 'status') && calResultStruct.status == 1
                    cal.quality = calResultStruct.quality; cal.details = calResultStruct.details;
                    me.calibrationData = calResultStruct;
                    me.statusMessage('iViewX calibration successful.');
                    if ~isempty(calParams.validationPoints) && (~isfield(calResultStruct,'needsValidation') || calResultStruct.needsValidation == true)
                        valResultStruct = iViewX('validate', me.ivx.connection, calParams); % Invented SDK call
                        if isstruct(valResultStruct) && isfield(valResultStruct, 'status') && valResultStruct.status == 1
                             me.validationData = valResultStruct; cal.validationQuality = valResultStruct.quality;
                             me.statusMessage('iViewX validation successful.');
                        else; warning('iViewXManager: Validation failed or was skipped by SDK.'); end
                    end
                else
                    warning('iViewXManager: Calibration failed or was cancelled.');
                    if isstruct(calResultStruct) && isfield(calResultStruct, 'message'); cal.details = ['Calibration failed: ', calResultStruct.message];
                    else; cal.details = 'Calibration failed: No details from SDK.'; end
                    me.statusMessage('iViewX calibration failed.');
                end
            catch ME_cal
                warning('iViewXManager.trackerSetup(): Error during iViewX calibration: %s', ME_cal.message);
                cal.details = sprintf('Calibration error: %s', ME_cal.message);
                me.statusMessage('iViewX calibration error.');
            end
            if ~isempty(me.operatorScreen) && me.operatorScreen.isOpen && me.useOperatorScreen
                me.operatorScreen.setColour([0 0 0]);
                me.operatorScreen.drawText('iViewX Operator Display', [], me.operatorScreen.ppd*0.5, [255 255 255]);
                me.operatorScreen.flip();
            end
            me.salutation('TrackerSetup', 'iViewX Calibration Procedure Finished.', true);
        end

        function startRecording(me, override)
            if me.isOff; return; end
            if me.isDummy; me.isRecording = true; if me.verbose; fprintf('iViewXManager: Dummy recording started.\n'); end; return; end
            if me.isConnected
                try
                    status = iViewX('startrecording', me.ivx.connection); % Invented SDK call
                    if status == 1; me.isRecording = true; me.statusMessage('iViewX data recording started.');
                    else; me.isRecording = false; warning('iViewXManager: Failed to start recording (SDK status: %d).', status); end
                catch ME_startRec
                    me.isRecording = false; warning('iViewXManager.startRecording(): Error: %s', ME_startRec.message);
                end
            else
                me.isRecording = false; warning('iViewXManager.startRecording(): Not connected to iViewX.');
            end
        end

        function stopRecording(me, override)
            if me.isOff; return; end
            if me.isDummy; me.isRecording = false; if me.verbose; fprintf('iViewXManager: Dummy recording stopped.\n'); end; return; end
            if me.isConnected && me.isRecording % Only try to stop if it was actually recording
                try
                    status = iViewX('stoprecording', me.ivx.connection); % Invented SDK call
                    if status == 1; me.statusMessage('iViewX data recording stopped.');
                    else; warning('iViewXManager: Failed to stop recording (SDK status: %d).', status); end
                catch ME_stopRec
                    warning('iViewXManager.stopRecording(): Error: %s', ME_stopRec.message);
                end
            elseif me.isConnected && ~me.isRecording && me.verbose
                fprintf('iViewXManager.stopRecording(): Was not recording.\n');
            end
            me.isRecording = false; 
        end

        function sample = getSample(me)
            sample = me.sampleTemplate; raw_gaze = [NaN; NaN]; pupilVal = NaN;
            if me.isOff; me.currentSample = sample; return; end
            if me.isDummy
                sample = getMouseSample(me); 
                if sample.valid; me.x=sample.gx; me.y=sample.gy; me.pupil=sample.pa; else; me.x=NaN;me.y=NaN;me.pupil=NaN; end
                me.xAllRaw=[me.xAllRaw me.x]; me.yAllRaw=[me.yAllRaw me.y]; % Store raw (same as processed for dummy)
                me.xAll=[me.xAll me.x]; me.yAll=[me.yAll me.y]; me.pupilAll=[me.pupilAll me.pupil];
                me.currentSample = sample; 
                return; 
            end

            if me.isConnected && me.isRecording
                try
                    [ivxData, sdk_status] = iViewX('getsample', me.ivx.connection); % Invented SDK call
                    if sdk_status == 1 
                        sample.raw = ivxData;
                        if isfield(ivxData, 'timestamp'); sample.time = double(ivxData.timestamp) / 1e6; else; sample.time = me.getTime(); end
                        if isfield(ivxData, 'deviceTimestamp'); sample.timeD = double(ivxData.deviceTimestamp) / 1e6; else; sample.timeD = NaN; end
                        
                        hasL = all(isfield(ivxData,{'gazeX_left','gazeY_left','pupil_left','valid_left'}));
                        hasR = all(isfield(ivxData,{'gazeX_right','gazeY_right','pupil_right','valid_right'}));
                        valid_L = hasL && ivxData.valid_left; valid_R = hasR && ivxData.valid_right;
                        
                        if strcmpi(me.smoothing.eyes, 'left')
                            if valid_L; raw_gaze = [ivxData.gazeX_left; ivxData.gazeY_left]; pupilVal = ivxData.pupil_left; sample.valid = true; else; sample.valid = false; end
                        elseif strcmpi(me.smoothing.eyes, 'right')
                            if valid_R; raw_gaze = [ivxData.gazeX_right; ivxData.gazeY_right]; pupilVal = ivxData.pupil_right; sample.valid = true; else; sample.valid = false; end
                        elseif strcmpi(me.smoothing.eyes, 'both')
                            if valid_L && valid_R
                                raw_gaze = mean([[ivxData.gazeX_left; ivxData.gazeY_left], [ivxData.gazeX_right; ivxData.gazeY_right]], 2);
                                pupilVal = mean([ivxData.pupil_left, ivxData.pupil_right]); sample.valid = true;
                            elseif valid_L; raw_gaze = [ivxData.gazeX_left; ivxData.gazeY_left]; pupilVal = ivxData.pupil_left; sample.valid = true;
                            elseif valid_R; raw_gaze = [ivxData.gazeX_right; ivxData.gazeY_right]; pupilVal = ivxData.pupil_right; sample.valid = true;
                            else; sample.valid = false; end
                        else; sample.valid = false; end 

                        me.xAllRaw = [me.xAllRaw raw_gaze(1)]; me.yAllRaw = [me.yAllRaw raw_gaze(2)];

                        if sample.valid
                            me.isBlink = false; % Assume SDK provides explicit blink flag or use pupil size for this
                            if isfield(ivxData, 'blink_left') && isfield(ivxData, 'blink_right') % Invented blink field
                                if strcmpi(me.smoothing.eyes, 'left'); me.isBlink = ivxData.blink_left; end
                                if strcmpi(me.smoothing.eyes, 'right'); me.isBlink = ivxData.blink_right; end
                                if strcmpi(me.smoothing.eyes, 'both'); me.isBlink = ivxData.blink_left || ivxData.blink_right; end
                            elseif pupilVal <= me.blinkSettings.pupilThreshold; me.isBlink = true; end % Basic blink from pupil
                            if me.isBlink; pupilVal = 0; end

                            smoothed_gaze_px = me.doSmoothing(raw_gaze);
                            sample.gx = smoothed_gaze_px(1); sample.gy = smoothed_gaze_px(2); sample.pa = pupilVal;
                            me.x = me.toDegrees(smoothed_gaze_px(1), 'x', 'pixels');
                            me.y = me.toDegrees(smoothed_gaze_px(2), 'y', 'pixels');
                            me.pupil = sample.pa;
                        else
                            me.isBlink = true; me.x=NaN; me.y=NaN; me.pupil=NaN; sample.gx=NaN; sample.gy=NaN; sample.pa=NaN;
                        end
                    elseif sdk_status == 0 
                        sample.valid = false; if ~me.ignoreBlinks; me.x=NaN; me.y=NaN; me.pupil=NaN; me.isBlink=true; end
                        me.xAllRaw=[me.xAllRaw NaN]; me.yAllRaw=[me.yAllRaw NaN];
                    else 
                        sample.valid = false; me.x=NaN; me.y=NaN; me.pupil=NaN;  me.isBlink=true;
                        me.xAllRaw=[me.xAllRaw NaN]; me.yAllRaw=[me.yAllRaw NaN];
                        warning('iViewXManager.getSample(): Error reported by iViewX SDK.');
                    end
                    me.xAll=[me.xAll me.x]; me.yAll=[me.yAll me.y]; me.pupilAll=[me.pupilAll me.pupil];
                    if me.debug; fprintf('iViewX Sample: X: %.2f deg, Y: %.2f deg, P: %.2f | Valid: %d\n',me.x,me.y,me.pupil,sample.valid); end
                catch ME_getSample
                    warning('iViewXManager.getSample(): Error during sample retrieval: %s', ME_getSample.message);
                    sample.valid=false; me.x=NaN; me.y=NaN; me.pupil=NaN; me.isBlink=true;
                    me.xAllRaw=[me.xAllRaw NaN]; me.yAllRaw=[me.yAllRaw NaN];
                    me.xAll=[me.xAll me.x]; me.yAll=[me.yAll me.y]; me.pupilAll=[me.pupilAll me.pupil];
                end
            else
                sample.valid=false; me.x=NaN; me.y=NaN; me.pupil=NaN; me.isBlink=true;
                me.xAllRaw=[me.xAllRaw NaN]; me.yAllRaw=[me.yAllRaw NaN];
                me.xAll=[me.xAll NaN]; me.yAll=[me.yAll NaN]; me.pupilAll=[me.pupilAll NaN];
                 if me.verbose && ~me.isConnected; fprintf('iViewXManager.getSample(): Not connected.\n'); end
                 if me.verbose && ~me.isRecording; fprintf('iViewXManager.getSample(): Not recording.\n'); end
            end
            me.currentSample = sample;
        end

        function trackerMessage(me, message, timestamp)
            if me.isOff || ~me.isConnected || me.isDummy; return; end
            try
                % Invented SDK calls: iViewX('sendmessage', ...) or iViewX('sendtrigger', ...)
                % The iViewX toolbox might expect numeric triggers or string messages.
                if isnumeric(message)
                    status = iViewX('sendtrigger', me.ivx.connection, message); 
                elseif ischar(message)
                    status = iViewX('sendmessage', me.ivx.connection, message);
                else
                    warning('iViewXManager.trackerMessage(): Message must be numeric or string.'); return;
                end
                if exist('timestamp','var') && ~isempty(timestamp) && me.verbose % Timestamps might not be supported by all message types
                    fprintf('iViewXManager.trackerMessage(): Timestamp provided but SDK might not support timed messages for this type.\n');
                end
                if status == 1 % Assuming 1 means success
                    if me.verbose; fprintf('iViewX Message/Trigger sent: %s (Status: %d)\n', num2str(message), status); end
                else
                    warning('iViewXManager.trackerMessage(): Failed to send message "%s" to iViewX (SDK Status: %d).', num2str(message), status);
                end
            catch ME_message
                warning('iViewXManager.trackerMessage(): Error sending message to iViewX: %s', ME_message.message);
            end
        end

        function runDemo(me, forcescreen)
            me.salutation('runDemo', 'Starting iViewX Demo', true);
            % Store original settings carefully, handling potential object copies
            originalSettings = struct();
            propsToSave = {'name', 'fixation', 'exclusionZone', 'useOperatorScreen', 'debug', 'screen', 'operatorScreen', 'smoothing'};
            for p_idx = 1:length(propsToSave)
                propName = propsToSave{p_idx};
                if isprop(me, propName)
                    if isobject(me.(propName)) && ismethod(me.(propName),'copy')
                        originalSettings.(propName) = copy(me.(propName));
                    else
                        originalSettings.(propName) = me.(propName);
                    end
                end
            end

            KbName('UnifyKeyNames'); stopKey=KbName('ESCAPE'); calibKey=KbName('c'); spaceKey=KbName('space'); upKey=KbName('UpArrow'); downKey=KbName('DownArrow');
            s=[]; s2=[]; % Screen handles

            try
                me.name = 'iViewXDemo'; me.debug = true;
                
                % --- Screen Setup ---
                if ~isfield(originalSettings,'screen') || ~isa(originalSettings.screen, 'screenManager') || ~isvalid(originalSettings.screen)
                    me.screen = screenManager('verbose',me.verbose,'debug',me.debug);
                else
                    me.screen = originalSettings.screen; % Use original if valid
                end
                s=me.screen; 
                if exist('forcescreen','var')&&~isempty(forcescreen); s.screenNumber=forcescreen; end
                if ~s.isOpen; s.open(); end
                
                % Operator Screen Setup
                if me.useOperatorScreen
                    opScreenWasOpen = false;
                    if isfield(originalSettings, 'operatorScreen') && isa(originalSettings.operatorScreen, 'screenManager') && isvalid(originalSettings.operatorScreen)
                        me.operatorScreen = originalSettings.operatorScreen;
                        opScreenWasOpen = me.operatorScreen.isOpen;
                    else
                        me.operatorScreen = []; % Ensure it's empty if not valid from original
                    end

                    availableScreens = Screen('Screens'); opScreenNumber = s.screenNumber+1;
                    if ~ismember(opScreenNumber,availableScreens)
                        if length(availableScreens)>1; opScreenNumber=availableScreens(find(availableScreens~=s.screenNumber,1,'first'));
                        else; opScreenNumber=s.screenNumber; fprintf('iViewXManager.runDemo: Warning: Operator screen forced to same as subject screen.\n'); end
                    end
                    
                    if isempty(me.operatorScreen) || ~isvalid(me.operatorScreen) || me.operatorScreen.screenNumber ~= opScreenNumber
                         if ~isempty(me.operatorScreen) && isvalid(me.operatorScreen) && me.operatorScreen.isOpen; me.operatorScreen.close(); end
                         me.operatorScreen = screenManager('screenNumber',opScreenNumber,'verbose',me.verbose,'debug',me.debug,'displayName','iViewX Operator Screen');
                    end
                    if ~me.operatorScreen.isOpen; me.operatorScreen.open(); end % Ensure it's open
                    s2=me.operatorScreen;
                else
                    s2=[]; 
                    if ~isempty(me.operatorScreen) && isvalid(me.operatorScreen) && me.operatorScreen.isOpen; me.operatorScreen.close(); end
                    me.operatorScreen = []; 
                end
                
                if ~me.initialise(s,s2); error('iViewXManager: Failed to initialise for demo.'); end
                cal=me.trackerSetup(); if isempty(cal)||(isfield(cal,'quality')&&cal.quality==-1); fprintf('Calibration failed/skipped.\n'); end
                WaitSecs(0.5); s.setMouse(); ShowCursor('Arrow');

                fixCross=fixationCrossStimulus('size',0.8,'colourIn',[200 0 0]); fixCross.setup(s);
                fixWindow=discStimulus('size',1,'colour',[0 255 0 100]); fixWindow.setup(s); 
                me.exclusionZone=struct('shape','rectangle','X',0,'Y',0,'size',[5 5],'units','deg');
                if ~isempty(me.exclusionZone); exZoneStim=rectangleStimulus('size',me.exclusionZone.size,'colour',[255 0 0 100]); exZoneStim.setup(s); else; exZoneStim=[]; end

                numTrials=5; trialDuration=5;
                s.drawText('Press Space to start, ESC to quit.',[],s.ppd*0.5,[255 255 255]); s.flip(); KbWait([],2);
                me.startRecording(true); keyCode=[]; initFail = false; % Initialize initFail

                for trial=1:numTrials
                    me.statusMessage(sprintf('Trial %d/%d',trial,numTrials)); me.resetFixation();
                    newFixX_deg=(rand-0.5)*(s.winRect(3)/s.ppd/3); newFixY_deg=(rand-0.5)*(s.winRect(4)/s.ppd/3);
                    me.fixation.X=newFixX_deg; me.fixation.Y=newFixY_deg; me.fixation.radius=2; % degrees
                    
                    fixCross.X=s.deg2pix(newFixX_deg,'x'); fixCross.Y=s.deg2pix(newFixY_deg,'y');
                    fixWindow.X=s.deg2pix(newFixX_deg,'x'); fixWindow.Y=s.deg2pix(newFixY_deg,'y');
                    fixWindow.size=s.deg2pix(me.fixation.radius*2); 

                    startTime=GetSecs();
                    while(GetSecs()-startTime)<trialDuration
                        me.getSample();
                        [isFix,fixTime,isSearching,isInWindow,isInExclusion,initFail]=me.isFixated();
                        s.setColour(s.backgroundColour);
                        if ~isempty(exZoneStim) && isfield(me.exclusionZone,'X') && isfield(me.exclusionZone,'Y'); exZoneStim.X=s.deg2pix(me.exclusionZone.X,'x'); exZoneStim.Y=s.deg2pix(me.exclusionZone.Y,'y'); exZoneStim.draw(); end
                        fixWindow.draw(); fixCross.draw(); me.drawEyePosition(s.win);
                        statusText=sprintf('T%d %.1fs Fix:%d(%.2fs) Srch:%d Win:%d Excl:%d InitFail:%d',trial,(GetSecs()-startTime),isFix,fixTime,isSearching,isInWindow,isInExclusion,initFail);
                        s.drawText(statusText,10,s.screenVals.heightPix-s.ppd*1-10,[255 255 255]); % Adjusted Y position
                        s.drawText('ESC=Quit,C=Calib,Up/Down=Smooth',10,s.screenVals.heightPix-s.ppd*0.5-10,[200 200 200]); % Adjusted Y position

                        if ~isempty(s2)&&s2.isOpen
                            s2.setColour(s2.backgroundColour);
                            me.trackerDrawFixation(s2,me.fixation); 
                            if ~isempty(me.exclusionZone); me.trackerDrawExclusion(s2,me.exclusionZone); end 
                            me.trackerDrawEyePosition(s2); 
                            s2.drawText(statusText,10,s2.screenVals.heightPix-s2.ppd*0.5-10,[255 255 255]); s2.flip(); % Adjusted Y
                        end
                        s.flip();
                        [keyIsDown,~,keyCode]=KbCheck();
                        if keyIsDown
                            if keyCode(stopKey); me.statusMessage('Stop key. End demo.'); break; end
                            if keyCode(calibKey); me.statusMessage('Recalibrating...'); me.stopRecording(true);me.trackerSetup();me.startRecording(true);startTime=GetSecs();me.resetFixation(); end
                            if keyCode(upKey); me.smoothing.window=min(me.smoothing.window+1,20); fprintf('Smooth win:%d\n',me.smoothing.window);WaitSecs(0.1);end
                            if keyCode(downKey); me.smoothing.window=max(me.smoothing.window-1,1); fprintf('Smooth win:%d\n',me.smoothing.window);WaitSecs(0.1);end
                        end
                    end
                    if ~isempty(keyCode)&&keyCode(stopKey); break; end
                    me.trackerMessage(sprintf('TRIAL_END %d',trial)); WaitSecs(0.2);
                end
            catch ME
                fprintf('CRITICAL ERROR in iViewXManager.runDemo(): %s\n',ME.message);
                for i=1:length(ME.stack); fprintf('File:%s Name:%s Line:%d\n',ME.stack(i).file,ME.stack(i).name,ME.stack(i).line); end
                me.salutation('runDemo','--- Cleaning up after CRITICAL error ---',true);
                % Fallback cleanup
                try; ListenChar(0); Priority(0); ShowCursor(); Screen('CloseAll'); catch; end
                 % Restore original settings
                fieldsToRestoreOnError = fieldnames(originalSettings);
                for f_idx = 1:length(fieldsToRestoreOnError)
                    fieldName = fieldsToRestoreOnError{f_idx};
                    try
                        if isprop(me, fieldName) && isfield(originalSettings, fieldName)
                            me.(fieldName) = originalSettings.(fieldName);
                        end
                    catch e_restore_err
                        fprintf('Could not restore (on error) %s: %s\n', fieldName, e_restore_err.message);
                    end
                end
                rethrow(ME);
            end

            % --- Normal Cleanup ---
            me.salutation('runDemo','--- Cleaning up demo ---',true);
            try; if isobject(me)&&isvalid(me)&&isprop(me,'isRecording')&&me.isRecording; me.stopRecording(true); end; catch e; fprintf('StopRecErr:%s\n',e.message);end
            try; if isobject(me)&&isvalid(me)&&isprop(me,'isConnected')&&me.isConnected; me.close(); end; catch e; fprintf('CloseErr:%s\n',e.message);end
            % s and s2 are me.screen and me.operatorScreen, me.close() should handle operatorScreen. me.screen is restored.
            try; if isa(originalSettings.screen, 'screenManager') && isvalid(originalSettings.screen) && originalSettings.screen.isOpen && originalSettings.screen ~= me.screen; originalSettings.screen.close(); end; catch; end
            try; ListenChar(0); Priority(0); ShowCursor(); Screen('CloseAll'); catch; end % Final PTB reset
            
            % Restore original settings
            fieldsToRestoreFinal = fieldnames(originalSettings);
            for f_idx = 1:length(fieldsToRestoreFinal)
                fieldName = fieldsToRestoreFinal{f_idx};
                try
                     if isprop(me, fieldName) && isfield(originalSettings, fieldName)
                        me.(fieldName) = originalSettings.(fieldName);
                     end
                catch e_restore_final
                    fprintf('Could not restore (final) %s: %s\n', fieldName, e_restore_final.message);
                end
            end
            if isfield(originalSettings,'screen'); me.screen = originalSettings.screen; end
            if isfield(originalSettings,'operatorScreen'); me.operatorScreen = originalSettings.operatorScreen; end


            me.salutation('runDemo','Demo Finished.',true);
        end
        % ===================================================================
        % END ABSTRACT METHOD IMPLEMENTATIONS
        % ===================================================================

    end %-------------------------END PUBLIC METHODS--------------------------------%

    methods (Access = protected)
        % Any protected methods specific to iViewX
    end
    
    methods (Hidden = true)
        % Any hidden methods (e.g., for compatibility or internal use)
    end

end

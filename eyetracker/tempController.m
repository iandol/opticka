classdef tempController < handle
	% [WIP] this is temporary code
	properties (Constant)
		stateEnum = struct('cal_positioning', 0, 'cal_gazing',1, 'cal_calibrating',2, 'cal_done',3, ...
			'val_validating' ,12, 'val_done'  ,13)
		pointStateEnum = struct('nothing',0, 'showing',1, 'collecting',2, 'discarding',3, 'collected', 4);
	end
	properties (SetAccess=private)
		% state
		stage

		gazeOnScreen                               % true if we have gaze for both eyes and the average position is on screen
		leftGaze
		rightGaze
		meanGaze
		onScreenTimestamp                          % time of start of episode of gaze on screen
		offScreenTimestamp                         % time of start of episode of gaze off screen
		onVideoTimestamp                           % time of start of episode of gaze on video (for calibration)
		latestTimestamp                            % latest gaze timestamp

		onScreenTimeThresh;
		videoSize;

		calPoint;
		calPoints                   = []           % ID of calibration points to run by the controller, in provided order
		calPoss                     = []           % corresponding positions
		calPointsState              = []

		valPoint;
		valPoints                   = []           % ID of calibration points to run by the controller, in provided order
		valPoss                     = []           % corresponding positions
		valPointsState              = []
	end
	properties
		% comms
		EThndl
		calDisplay                                  % expected to be a VideoCalibrationDisplay instance
		rewardProvider
		audioProvider
		rewardPacing				= 1000;
		forceRewardButton           = 'j'           % if provided, when key press on this button is detected, reward is forced on

		gazeFetchDur                = 100          % duration of gaze samples to peek on each iteration (ms, e.g., last 100 ms of gaze)
		gazeAggregationMethod       = 1            % 1: use mean of all samples during last gazeFetchDur ms, 2: use mean of last valid sample during last gazeFetchDur ms
		minValidGazeFrac            = .5
		scrRes;

		maxOffScreenTime            = 40/60*1000
		onScreenTimeThreshCap       = 400          % maximum time animal will be required to keep gaze onscreen for rewards
		onScreenTimeThreshIncRate   = 0.01         % chance to increase onscreen time threshold

		videoShrinkTime             = 1000         % how long eyes on video before video shrinks
		videoShrinkRate             = 0.01         % chance to decrease video size

		videoSizes                  = [
			1600 1600;
			1200 1200;
			800 800;
			600 600;
			500 500;
			400 400;
			200 200;
			]
		calVideoSize                = [200 200]
		calShowVideoWhenDone        = true
		calVideoSizeWhenDone        = [200 200]
		calWhenDoneRewardDistFac    = .5;           % fraction of video width (so 0.5 means gaze anywhere on video, since distance is from center)
		calWhenDoneRewardTime       = 500;          % ms

		valVideoSize                = [200 200];
		valShowVideoWhenDone        = true;
		valVideoSizeWhenDone        = [600 600];
		valWhenDoneRewardDistFac    = .5;           % fraction of video width (so 0.5 means gaze anywhere on video, since distance is from center)
		valWhenDoneRewardTime       = 500;          % ms

		calOnTargetTime             = 500;          % ms
		calOnTargetDistFac          = 1/3;          % max gaze distance to be considered close enough to a point to attempt calibration (factor of vertical size of screen)
		calAfterFirstCollected      = false;        % if true, a calibration compute_and_apply command will be given after the first calibration point is successfully collected, before continueing to collect the next calibration point

		valOnTargetDist             = 150;          % pixels
		valOnTargetTime             = 500;          % ms
		valRandomizeTargets         = true;

		reEntryStateCal             = tempController.stateEnum.cal_calibrating;    % when reactivating controller, discard state up to beginning of this state
		reEntryStateVal             = tempController.stateEnum.val_validating;     % when reactivating controller, discard state up to beginning of this state

		showGazeToOperator          = true;         % if true, aggregated gaze as used by the controller is drawn as a crosshair on the operator screen
		logTypes                    = 0;            % bitmask: if 0, no logging. bit 1: print basic messages about what its up to. bit 2: print each command received in receiveUpdate(), bit 3: print messages about rewards (many!)
		logReceiver                 = 0;            % if 0: matlab command line. if 1: Titta
	end
	properties (Access=private,Hidden=true)
		lastRewardTime				= 0;
		isActive                    = false;
		isNonActiveShowingVideo     = false;
		isShowingPointManually      = false;
		dispensingReward            = false;
		dispensingForcedReward      = false;
		controlState                = tempController.stateEnum.cal_positioning;
		shouldRewindState           = false;
		shouldClearCal              = false;
		clearCalNow                 = false;
		clearValNow                 = false;
		activationCount             = struct('cal',0, 'val',0);
		shouldUpdateStatusText;
		trackerFrequency;                           % calling me.EThndl.frequency is blocking when a calibration action is ongoing, so cache the value

		awaitingPointResult         = 0;            % 0: not awaiting anything; 1: awaiting point collect result; 2: awaiting point discard result; 3: awaiting compute and apply result; 4: calibration clearing result
		lastUpdate                  = {};

		drawState                   = 0;            % 0: don't issue draws from here; 1: new command should be given to drawer; 2: regular draw command should be given
		drawExtraFrame              = false;        % because command in tick() is only processed in Titta after fixation point is drawn, we need to draw one extra frame here to avoid flashing when starting calibration point collection

		backupPaceDuration          = struct('cal',[],'val',[]);
	end


	methods
		function me = tempController(EThndl,calDisplay,scrRes,rewardProvider,audioProvider)
			me.setCleanState();
			me.EThndl = EThndl;
			me.calDisplay = calDisplay;
			if nargin>2 && ~isempty(scrRes)
				me.scrRes = scrRes;
			end
			if nargin>3 && ~isempty(rewardProvider)
				me.rewardProvider = rewardProvider;
			end
			if nargin>4 && ~isempty(audioProvider)
				me.audioProvider = audioProvider;
			end
		end

		function setCalPoints(me, calPoints,calPoss)
			assert(ismember(me.controlState,[me.stateEnum.cal_positioning me.stateEnum.cal_gazing]),'cannot set calibration points when already calibrating or calibrated')
			assert(length(unique(calPoints))==length(calPoints),'At least one calibration point ID is specified more than once. Specify each calibration point only once.')
			me.calPoints       = calPoints;                % ID of calibration points to run by the controller, in provided order
			me.calPoss         = calPoss;                  % corresponding positions
			me.calPointsState  = repmat(me.pointStateEnum.nothing, 1, size(me.calPoss,1));
		end

		function setValPoints(me, valPoints,valPoss)
			assert(me.controlState < me.stateEnum.val_validating,'cannot set validation points when already validating or validated')
			assert(length(unique(valPoints))==length(valPoints),'At least one validation point ID is specified more than once. Specify each validation point only once.')
			me.valPoints       = valPoints;                % ID of calibration points to run by the controller, in provided order
			me.valPoss         = valPoss;                  % corresponding positions
			me.valPointsState  = repmat(me.pointStateEnum.nothing, 1, size(me.valPoss,1));
		end

		function commands = tick(me)
			commands = {};
			if ~isempty(me.forceRewardButton) && ~isempty(me.rewardProvider)
				[~,~,keyCode] = KbCheck();
				if any(keyCode) && any(ismember(KbName(keyCode),{me.forceRewardButton}))
					me.reward(true);
				elseif me.dispensingForcedReward
					me.dispensingForcedReward = false;
				end
			end
			if ~isempty(me.rewardProvider)
				%me.rewardProvider.tick();
			end
			if ~me.isActive && ~me.isNonActiveShowingVideo && ~me.isShowingPointManually
				return;
			end
			me.updateGaze();
			offScreenTime = me.latestTimestamp-me.offScreenTimestamp;
			if ~me.isActive && (me.isNonActiveShowingVideo || me.isShowingPointManually)     % check like this: this logic should only kick in when controller is not active
				% check if should be giving reward: when gaze on/near video
				me.determineNonActiveReward();
				return
			end

			% normal controller active mode
			if strcmp(me.stage,'cal')
				if offScreenTime > me.maxOffScreenTime
					me.reward(false);
				end
				if me.clearCalNow
					if me.awaitingPointResult~=4
						commands = {{'cal','clear'}};
						me.awaitingPointResult = 4;
						if bitget(me.logTypes,1)
							me.log_to_cmd('calibration state is not clean upon controller activation. Requesting to clear it first');
						end
					elseif me.awaitingPointResult==4 && ~isempty(me.lastUpdate) && strcmp(me.lastUpdate{1},'cal_cleared')
						me.awaitingPointResult = 0;
						me.clearCalNow = false;
						me.lastUpdate = {};
						if bitget(me.logTypes,1)
							me.log_to_cmd('calibration data cleared, starting controller');
						end
					end
				else
					switch me.controlState
						case me.stateEnum.cal_positioning
							if me.shouldRewindState
								me.onScreenTimeThresh = 1;
								me.shouldRewindState = false;
								me.drawState = 1;
								me.shouldUpdateStatusText = true;
								if bitget(me.logTypes,1)
									me.log_to_cmd('rewinding state: reset looking threshold');
								end
							elseif me.onScreenTimeThresh < me.onScreenTimeThreshCap
								% training to position and look at screen
								me.trainLookScreen();
							else
								me.controlState = me.stateEnum.cal_gazing;
								me.drawState = 1;
								me.shouldUpdateStatusText = true;
								if bitget(me.logTypes,1)
									me.log_to_cmd('training to look at video');
								end
							end
						case me.stateEnum.cal_gazing
							if me.shouldRewindState
								me.videoSize = 1;
								me.drawState = 1;
								me.shouldUpdateStatusText = true;
								if me.reEntryStateCal<me.stateEnum.cal_gazing
									me.controlState = me.stateEnum.cal_positioning;
								else
									me.shouldRewindState = false;
								end
								if bitget(me.logTypes,1)
									me.log_to_cmd('rewinding state: reset video size');
								end
							elseif me.videoSize < size(me.videoSizes,1)
								% training to look at video
								me.trainLookVideo();
							else
								me.controlState = me.stateEnum.cal_calibrating;
								me.drawState = 1;
								me.calDisplay.videoSize = me.calVideoSize;
								me.shouldUpdateStatusText = true;
								if bitget(me.logTypes,1)
									me.log_to_cmd('calibrating');
								end
							end
						case me.stateEnum.cal_calibrating
							% calibrating
							commands = me.calibrate();
						case me.stateEnum.cal_done
							% procedure is done: nothing to do
					end
				end
			else
				% validation
				if me.clearValNow
					if me.awaitingPointResult~=2
						me.valPoint = 1;
						if me.valRandomizeTargets
							order = randperm(length(me.valPoints));
							me.valPoints = me.valPoints(order);
							me.valPoss   = me.valPoss(order,:);
						end
						% ensure we're in clean state
						for p=length(me.valPoints):-1:1    % reverse so we can set cal state back to first point and await discard of that first point, will arrive last
							commands = [commands {{'val','discard_point', me.valPoints(p), me.valPoss(p,:)}}]; %#ok<AGROW>
						end
						me.awaitingPointResult = 2;
						if bitget(me.logTypes,1)
							me.log_to_cmd('clearing validation state to be sure its clean upon controller activation');
						end
					elseif me.awaitingPointResult==2 && ~isempty(me.lastUpdate) && strcmp(me.lastUpdate{1},'val_discard')
						% check this is for the expected point
						if me.lastUpdate{2}==me.valPoints(me.valPoint) && all(me.lastUpdate{3}==me.valPoss(me.valPoint,:))
							me.awaitingPointResult = 0;
							me.clearValNow = false;
							me.shouldUpdateStatusText = true;
							me.lastUpdate = {};
							me.drawState = 1;
							if bitget(me.logTypes,1)
								me.log_to_cmd('validation data cleared, starting controller');
							end
						end
					end
				else
					switch me.controlState
						case me.stateEnum.val_validating
							% validating
							commands = me.validate();
						case me.stateEnum.val_done
							% procedure is done: nothing to do
					end
				end
			end
		end

		function receiveUpdate(me,~,currentPoint,posNorm,~,~,type,callResult)
			% event communicated to the controller:
			if bitget(me.logTypes,2)
				me.log_to_cmd('received update of type: %s',type);
			end
			switch type
				case {'cal_activate','val_activate'}
					mode = type(1:3);
					isCal = strcmpi(mode,'cal');
					me.activationCount.(mode) = me.activationCount.(mode)+1;
					if isCal
						if me.activationCount.cal>1 && me.controlState>=me.reEntryStateCal
							me.shouldRewindState = true;
							if me.controlState>me.reEntryStateCal
								if me.controlState > me.stateEnum.cal_done
									me.controlState = me.stateEnum.cal_done;
								end
								me.controlState = me.controlState-1;
							end
						elseif me.shouldClearCal
							me.clearCalNow = true;
						end
						if me.activationCount.cal==1 && me.controlState>me.stateEnum.cal_done
							me.controlState = me.stateEnum.cal_positioning;
						end
					else
						me.clearValNow = true; % always issue a validation clear, in case there is any data
						me.controlState = me.stateEnum.val_validating;
						me.shouldUpdateStatusText = true;
						me.calDisplay.videoSize = me.valVideoSize;
					end
					me.lastUpdate = {};
					me.awaitingPointResult = 0;
					me.isActive = true;
					me.shouldUpdateStatusText = true;
					me.isNonActiveShowingVideo = false;
					me.onVideoTimestamp = nan;
					% backup Titta pacing duration and set to 0, since the
					% controller controls when data should be collected
					me.setTittaPacing(type(1:3),'');
					if bitget(me.logTypes,1)
						if isCal
							me.log_to_cmd('controller activated for calibration. Activation #%d',me.activationCount.(mode));
						else
							me.log_to_cmd('controller activated for validation. Activation #%d',me.activationCount.(mode));
						end
					end
				case {'cal_deactivate','val_deactivate'}
					me.isActive = false;
					me.shouldUpdateStatusText = true;
					% backup Titta pacing duration and set to 0, since the
					% controller controls when data should be collected
					me.setTittaPacing('',type(1:3));
					if bitget(me.logTypes,1)
						me.log_to_cmd('controller deactivated for %s',ternary(startsWith(type,'cal'),'calibration','validation'));
					end
					% cal/val mode switches
				case 'cal_enter'
					me.stage = 'cal';
					if me.isActive
						me.setTittaPacing('cal','val');
					elseif me.isNonActiveShowingVideo
						me.setupNonActiveVideo();
					end
					if bitget(me.logTypes,2)
						me.log_to_cmd('calibration mode entered');
					end
				case 'val_enter'
					me.stage = 'val';
					if me.isActive
						me.setTittaPacing('val','cal');
					elseif me.isNonActiveShowingVideo
						me.setupNonActiveVideo();
					end
					if bitget(me.logTypes,2)
						me.log_to_cmd('validation mode entered');
					end
				case 'cal_collect_started'
					me.calDisplay.videoSize = me.calVideoSize;
					me.isShowingPointManually = ~me.isActive;
					me.shouldUpdateStatusText = me.shouldUpdateStatusText || me.isShowingPointManually;
				case 'val_collect_started'
					me.calDisplay.videoSize = me.valVideoSize;
					me.isShowingPointManually = ~me.isActive;
					me.shouldUpdateStatusText = me.shouldUpdateStatusText || me.isShowingPointManually;
					% calibration point collected
				case 'cal_collect_done'
					me.lastUpdate = {type,currentPoint,posNorm,callResult};
					if bitget(me.logTypes,2)
						success = callResult.status==0;     % TOBII_RESEARCH_STATUS_OK
						me.log_to_cmd('calibration point collect: %s',ternary(success,'success','failed'));
					end
					me.lastRewardTime = 0;
					me.reward(true);
					% update point status
					iPoint = find(me.calPoints==currentPoint);
					if ~isempty(iPoint) && all(posNorm==me.calPoss(iPoint,:))
						me.calPointsState(iPoint) = me.pointStateEnum.collected;
					end
					me.shouldClearCal = true;  % mark that we need to clear calibration if controller is activated
					me.shouldUpdateStatusText = me.shouldUpdateStatusText || me.isShowingPointManually;
					me.isShowingPointManually = false;
					if me.isNonActiveShowingVideo
						me.setupNonActiveVideo();
					end
					% validation point collected
				case 'val_collect_done'
					me.lastUpdate = {type,currentPoint,posNorm,callResult};
					if bitget(me.logTypes,2)
						me.log_to_cmd('validation point collect: success');
					end
					me.lastRewardTime = 0;
					me.reward(true);
					% update point status
					iPoint = find(me.valPoints==currentPoint);
					if ~isempty(iPoint) && all(posNorm==me.valPoss(iPoint,:))
						me.valPointsState(iPoint) = me.pointStateEnum.collected;
					end
					me.shouldUpdateStatusText = me.shouldUpdateStatusText || me.isShowingPointManually;
					me.isShowingPointManually = false;
					if me.isNonActiveShowingVideo
						me.setupNonActiveVideo();
					end
					% calibration point discarded
				case 'cal_discard'
					me.lastUpdate = {type,currentPoint,posNorm,callResult};
					if bitget(me.logTypes,2)
						success = callResult.status==0;     % TOBII_RESEARCH_STATUS_OK
						me.log_to_cmd('calibration point discard: %s',ternary(success,'success','failed'));
					end
					% update point status
					iPoint = find(me.calPoints==currentPoint);
					if ~isempty(iPoint) && all(posNorm==me.calPoss(iPoint,:))
						me.calPointsState(iPoint) = me.pointStateEnum.nothing;
					end
					% validation point discarded
				case 'val_discard'
					me.lastUpdate = {type,currentPoint,posNorm,callResult};
					if bitget(me.logTypes,2)
						me.log_to_cmd('validation point discard: success');
					end
					% update point status
					iPoint = find(me.valPoints==currentPoint);
					if ~isempty(iPoint) && all(posNorm==me.valPoss(iPoint,:))
						me.valPointsState(iPoint) = me.pointStateEnum.nothing;
					end
					% new calibration computed (may have failed) or loaded
				case 'cal_compute_and_apply'
					me.lastUpdate = {type,callResult};
					if bitget(me.logTypes,2)
						success = callResult.status==0 && strcmpi(callResult.calibrationResult.status,'success');
						me.log_to_cmd('calibration compute and apply result received: %s',ternary(success,'success','failed'));
					end
					% a calibration was loaded
				case 'cal_load'
					% mark that we need to clear calibration if controller is activated
					me.shouldClearCal = true;
					% calibration was cleared: now at a blank slate
				case 'cal_cleared'
					me.lastUpdate = {type};
					if bitget(me.logTypes,2)
						me.log_to_cmd('calibration clear result received');
					end
					me.shouldClearCal = false;
					% interface exited from calibration or validation screen
				case {'cal_finished','val_finished'}
					% we're done according to operator, clean up
					me.setTittaPacing('',type(1:3));
					me.reward(false);
					me.setCleanState();
			end
		end

		function txt = getStatusText(me,force)
			% return '!!clear_status' if you want to remove the status text
			if nargin<2
				force = false;
			end
			txt = '';
			if ~me.shouldUpdateStatusText && ~force
				return
			end
			if ~me.isActive
				txt = 'Inactive';
				if me.isShowingPointManually
					txt = [txt ', showing point manually'];
				end
			else
				switch me.controlState
					case me.stateEnum.cal_positioning
						txt = sprintf('Positioning %d/%d',me.onScreenTimeThresh, me.onScreenTimeThreshCap);
					case me.stateEnum.cal_gazing
						% draw video rect
						txt = sprintf('Gaze training\nvideo size %d/%d',me.videoSize,size(me.videoSizes,1));
					case me.stateEnum.cal_calibrating
						txt = sprintf('Calibrating %d/%d',me.calPoint,length(me.calPoints));
					case me.stateEnum.cal_done
						txt = 'Calibration done';

					case me.stateEnum.val_validating
						txt = sprintf('Validating %d/%d',me.valPoint,length(me.valPoints));
					case me.stateEnum.val_done
						txt = 'Validation done';
				end
			end
			txt = sprintf('%s\nReward: %s',txt,ternary(me.dispensingReward,'on','off'));
			me.shouldUpdateStatusText = false;
		end

		function draw(me,wpnts,tick,sFac,offset)
			% wpnts: two window pointers. first is for participant screen,
			% second for operator
			% sFac and offset are used to scale from participant screen to
			% operator screen, in case they have different resolutions
			if ~me.isActive && ~me.isNonActiveShowingVideo && ~me.isShowingPointManually
				return;
			end
			if me.drawState>0 && ~me.isShowingPointManually
				drawCmd = 'draw';
				if me.drawState==1
					drawCmd = 'new';
					if me.controlState == me.stateEnum.cal_positioning
						me.calDisplay.videoSize = me.videoSizes(1,:);
					end
				end
				pos = [nan nan];
				if ~me.isActive && me.isNonActiveShowingVideo
					pos = me.scrRes/2;
				elseif ismember(me.controlState, [me.stateEnum.cal_positioning me.stateEnum.cal_gazing])
					pos = me.scrRes/2;
				elseif me.controlState == me.stateEnum.cal_calibrating
					calPos = me.calPoss(me.calPoint,:).*me.scrRes(:).';
					pos = calPos;
				elseif me.controlState == me.stateEnum.val_validating
					valPos = me.valPoss(me.valPoint,:).*me.scrRes(:).';
					pos = valPos;
				end
				% Don't call draw here if we've issued a command to collect
				% calibration data for a point and haven't gotten a status
				% update yet, then Titta is showing the point for us
				if me.awaitingPointResult~=1 || me.drawExtraFrame
					me.calDisplay.doDraw(wpnts(1),drawCmd,nan,pos,tick,me.stage);
				end
				if ~isnan(pos(1))
					me.drawState = 2;
				end

				if me.awaitingPointResult~=1 && me.drawExtraFrame
					me.drawExtraFrame = false;
				end
			end

			% draw video rect for operator
			if (~me.isActive && (me.isNonActiveShowingVideo || me.isShowingPointManually)) || ...
					ismember(me.controlState, [me.stateEnum.cal_gazing me.stateEnum.cal_calibrating me.stateEnum.val_validating])
				pos = me.calDisplay.pos;
				sz = me.calDisplay.videoSize;
				rect = CenterRectOnPointd([0 0 sz*sFac],pos(1)*sFac+offset(1),pos(2)*sFac+offset(2));
				Screen('FrameRect',wpnts(end),0,rect,4);
			end

			% draw gaze if wanted
			if me.showGazeToOperator
				sz = [1/40 1/120]*me.scrRes(2);
				for p=1:3
					switch p
						case 1
							pos = me.leftGaze;
							clr = [255 0 0];
						case 2
							pos = me.rightGaze;
							clr = [0 0 255];
						case 3
							pos = me.meanGaze;
							clr = 0;
					end
					rectH = CenterRectOnPointd([0 0        sz ], pos(1)*sFac+offset(1), pos(2)*sFac+offset(2));
					rectV = CenterRectOnPointd([0 0 fliplr(sz)], pos(1)*sFac+offset(1), pos(2)*sFac+offset(2));
					Screen('FillRect',wpnts(end), clr, rectH);
					Screen('FillRect',wpnts(end), clr, rectV);
				end
			end
		end
	end

	methods (Static)
		function canDo = canControl(type)
			switch type
				case 'calibration'
					canDo = true;
				case 'validation'
					canDo = true;
				otherwise
					error('tempController: controller capability "%s" not understood',type)
			end
		end
	end

	methods (Access = private, Hidden)
		function setCleanState(me)
			if bitget(me.logTypes,1)
				me.log_to_cmd('cleanup state');
			end
			me.isActive            = false;
			me.isNonActiveShowingVideo = false;
			me.isShowingPointManually  = false;
			me.dispensingReward        = false;
			me.dispensingForcedReward  = false;
			me.controlState        = me.stateEnum.cal_positioning;
			me.shouldRewindState   = false;
			me.shouldClearCal      = false;
			me.clearCalNow         = false;
			me.clearValNow         = false;
			me.activationCount.cal = 0;
			me.activationCount.val = 0;
			me.shouldUpdateStatusText = true;

			me.stage               = '';
			me.gazeOnScreen        = false;
			me.leftGaze            = [nan nan].';
			me.rightGaze           = [nan nan].';
			me.meanGaze            = [nan nan].';
			me.onScreenTimestamp   = nan;
			me.offScreenTimestamp  = nan;
			me.onVideoTimestamp    = nan;
			me.latestTimestamp     = nan;
			me.lastRewardTime	   = 0;

			me.onScreenTimeThresh  = 1;
			me.videoSize           = 1;

			me.calPoint            = 1;
			me.calPoints           = [];
			me.calPoss             = [];
			me.calPointsState      = [];

			me.valPoint            = 1;
			me.valPoints           = [];
			me.valPoss             = [];
			me.valPointsState      = [];

			me.awaitingPointResult = 0;

			me.drawState           = 1;
			me.drawExtraFrame      = false;
			me.backupPaceDuration  = struct('cal',[],'val',[]);
		end

		function updateGaze(me)
			if isempty(me.trackerFrequency)
				me.trackerFrequency = me.EThndl.frequency;
			end
			gaze = me.EThndl.buffer.peekN('gaze',round(me.gazeFetchDur/1000*me.trackerFrequency));
			if isempty(gaze)
				me.meanGaze = nan;
				return
			end

			me.latestTimestamp = double(gaze.systemTimeStamp(end))/1000;   % us -> ms
			fValid = mean([gaze.left.gazePoint.valid; gaze.right.gazePoint.valid],2);
			if any(fValid>me.minValidGazeFrac)
				switch me.gazeAggregationMethod
					case 1
						% take mean of valid samples
						me.leftGaze = mean(gaze. left.gazePoint.onDisplayArea(:,gaze. left.gazePoint.valid),2,'omitnan').*me.scrRes(:);
						me.rightGaze= mean(gaze.right.gazePoint.onDisplayArea(:,gaze.right.gazePoint.valid),2,'omitnan').*me.scrRes(:);
					case 2
						% use last valid sample
						qValid = all([gaze.left.gazePoint.valid; gaze.right.gazePoint.valid],1);
						iSamp = find(qValid,1,'last');
						me.leftGaze = gaze. left.gazePoint.onDisplayArea(:,iSamp).*me.scrRes(:);
						me.rightGaze= gaze.right.gazePoint.onDisplayArea(:,iSamp).*me.scrRes(:);
				end
				me.meanGaze = mean([me.leftGaze me.rightGaze],2);

				me.gazeOnScreen = me.meanGaze(1) > 0 && me.meanGaze(1)<me.scrRes(1) && ...
					me.meanGaze(2) > 0 && me.meanGaze(2)<me.scrRes(2);
				if me.gazeOnScreen
					me.offScreenTimestamp = nan;
					if isnan(me.onScreenTimestamp)
						iSamp = find(any([gaze.left.gazePoint.valid; gaze.right.gazePoint.valid],1),1,'last');
						me.onScreenTimestamp = double(gaze.systemTimeStamp(iSamp))/1000;   % us -> ms
					end
				end
			else
				me.gazeOnScreen = false;
				me.leftGaze = [nan nan].';
				me.rightGaze= [nan nan].';
				me.meanGaze = [nan nan].';
				me.onScreenTimestamp = nan;
				if isnan(me.offScreenTimestamp)
					me.offScreenTimestamp = double(gaze.systemTimeStamp(1))/1000;  % us -> ms
				end
			end
		end

		function reward(me, on)
			if on
				if me.latestTimestamp > me.lastRewardTime + me.rewardPacing
					me.lastRewardTime = me.latestTimestamp;
					if ~isempty(me.rewardProvider);giveReward(me.rewardProvider);end
					if ~isempty(me.audioProvider);beep(me.audioProvider,2000,0.1,0.1);end
					fprintf('--->>>controller reward sent @ %.2f',me.lastRewardTime);
				end
			end
		end

		function trainLookScreen(me)
			onScreenTime = me.latestTimestamp-me.onScreenTimestamp;
			% looking long enough on the screen, provide reward
			if onScreenTime > me.onScreenTimeThresh
				me.reward(true);
			end
			% if looking much longer than current looking threshold,
			% possibly increase threshold
			if onScreenTime > me.onScreenTimeThresh*2
				if rand()<=me.onScreenTimeThreshIncRate
					me.onScreenTimeThresh = min(me.onScreenTimeThresh*2,me.onScreenTimeThreshCap);   % limit to onScreenTimeThreshCap
					me.shouldUpdateStatusText = true;
					if bitget(me.logTypes,1)
						me.log_to_cmd('on-screen looking time threshold increased to %d',me.onScreenTimeThresh);
					end
				end
			end
		end

		function trainLookVideo(me)
			onScreenTime = me.latestTimestamp-me.onScreenTimestamp;
			if onScreenTime > me.onScreenTimeThresh
				% check distance to center of video (which is always at
				% center of screen)
				dist = hypot(me.meanGaze(1)-me.scrRes(1)/2,me.meanGaze(2)-me.scrRes(2)/2);
				% if looking close enough to video, provide reward and
				% possibly decrease video size
				if dist < me.videoSizes(me.videoSize,2)*2
					me.reward(true);
					if onScreenTime > me.videoShrinkTime && rand()<=me.videoShrinkRate
						me.videoSize = min(me.videoSize+1,size(me.videoSizes,1));
						me.calDisplay.videoSize = me.videoSizes(me.videoSize,:);
						me.shouldUpdateStatusText = true;
						if bitget(me.logTypes,1)
							me.log_to_cmd('video size decreased to %dx%d',me.videoSizes(me.videoSize,:));
						end
					end
				else
					me.reward(false);
				end
			end
		end

		function commands = calibrate(me)
			commands = {};
			calPos = me.calPoss(me.calPoint,:).*me.scrRes(:).';
			dist = hypot(me.meanGaze(1)-calPos(1),me.meanGaze(2)-calPos(2));
			if me.shouldRewindState
				if me.awaitingPointResult~=4
					% clear calibration
					commands = {{'cal','clear'}};
					me.calPoint = 1;
					me.drawState = 1;
					me.awaitingPointResult = 4;
					me.shouldUpdateStatusText = true;
					if bitget(me.logTypes,1)
						me.log_to_cmd('rewinding state: clearing the calibration');
					end
				elseif me.awaitingPointResult==4 && ~isempty(me.lastUpdate) && strcmp(me.lastUpdate{1},'cal_cleared')
					me.awaitingPointResult = 0;
					if me.reEntryStateCal<me.stateEnum.cal_calibrating
						me.controlState = me.stateEnum.cal_gazing;
						if bitget(me.logTypes,1)
							me.log_to_cmd('calibration cleared, continue state rewind');
						end
					else
						me.shouldRewindState = false;
						if bitget(me.logTypes,1)
							me.log_to_cmd('calibration cleared, restarting collection');
						end
						me.calDisplay.videoSize = me.calVideoSize;
					end
					me.shouldUpdateStatusText = true;
				end
				me.lastUpdate = {};
			elseif me.awaitingPointResult>0
				% we're waiting for the result of an action. Those are all
				% blocking in the Python code, but not here. For identical
				% behavior (and easier logic), we put all the response
				% waiting logic here, short-circuiting the below logic that
				% depends on where the subject looks
				if isempty(me.lastUpdate)
					return;
				end
				if me.awaitingPointResult==1 && strcmp(me.lastUpdate{1},'cal_collect_done')
					% check this is for the expected point
					if me.lastUpdate{2}==me.calPoints(me.calPoint) && all(me.lastUpdate{3}==me.calPoss(me.calPoint,:))
						% check result
						if me.lastUpdate{4}.status==0     % TOBII_RESEARCH_STATUS_OK
							% success, decide next action
							if me.calPoint<length(me.calPoints) && ~(me.calPoint==1 && me.calAfterFirstCollected)
								% calibrate next point
								me.calPoint = me.calPoint+1;
								me.awaitingPointResult = 0;
								me.shouldUpdateStatusText = true;
								me.onVideoTimestamp = nan;
								me.drawState = 1;
								if bitget(me.logTypes,1)
									me.log_to_cmd('successfully collected calibration point %d, continue with collection of point %d', me.calPoints(me.calPoint-1), me.calPoints(me.calPoint));
								end
							else
								% all collected or first collected and calibration wanted after first -> attempt calibration
								commands = {{'cal','compute_and_apply'}};
								me.awaitingPointResult = 3;
								me.shouldUpdateStatusText = true;
								if bitget(me.logTypes,1)
									if me.calPoint==1 && me.calAfterFirstCollected
										me.log_to_cmd('first calibration point successfully collected, requesting computing and applying calibration before continuing collection of other points');
									else
										me.log_to_cmd('all calibration points successfully collected, requesting computing and applying calibration');
									end
								end
							end
						else
							% failed collecting calibration point, discard
							% (to be safe its really gone from state,
							% overkill i think but doesn't hurt)
							commands = {{'cal','discard_point', me.calPoints(me.calPoint), me.calPoss(me.calPoint,:)}};
							me.awaitingPointResult = 2;
							me.drawState = 1;  % Titta calibration logic tells drawer to clean up upon failed point. Reshow point here
							if bitget(me.logTypes,1)
								me.log_to_cmd('failed to collect calibration point %d, requesting to discard it', me.calPoints(me.calPoint));
							end
						end
					end
					me.lastUpdate = {};
				elseif me.awaitingPointResult==2 && strcmp(me.lastUpdate{1},'cal_discard')
					% check this is for the expected point
					if me.lastUpdate{2}==me.calPoints(me.calPoint) && all(me.lastUpdate{3}==me.calPoss(me.calPoint,:))
						if me.lastUpdate{4}.status==0     % TOBII_RESEARCH_STATUS_OK
							me.awaitingPointResult = 0;
							if bitget(me.logTypes,1)
								me.log_to_cmd('successfully discarded calibration point %d', me.calPoints(me.calPoint));
							end
						else
							error('can''t discard point, something seriously wrong')
						end
					end
					me.lastUpdate = {};
				elseif me.awaitingPointResult==3 && strcmp(me.lastUpdate{1},'cal_compute_and_apply')
					if me.lastUpdate{2}.status==0 && strcmpi(me.lastUpdate{2}.calibrationResult.status,'success')
						% successful calibration
						if me.calPoint==1 && me.calAfterFirstCollected
							me.calPoint = me.calPoint+1;
							me.awaitingPointResult = 0;
							me.shouldUpdateStatusText = true;
							me.onVideoTimestamp = nan;
							me.drawState = 1;
							if bitget(me.logTypes,1)
								me.log_to_cmd('calibration successfully applied, continuing calibration. Continue with collection of point %d', me.calPoints(me.calPoint));
							end
						else
							me.awaitingPointResult = 0;
							me.reward(false);
							me.controlState = me.stateEnum.cal_done;
							me.shouldUpdateStatusText = true;
							commands = {{'cal','disable_controller'}};
							me.drawState = 0;
							if me.calShowVideoWhenDone
								me.setupNonActiveVideo();
							end
							if bitget(me.logTypes,1)
								me.log_to_cmd('calibration successfully applied, disabling controller');
							end
						end
					else
						% failed, start over
						for p=length(me.calPoints):-1:1    % reverse so we can set cal state back to first point and await discard of that first point, will arrive last
							commands = [commands {{'cal','discard_point', me.calPoints(p), me.calPoss(p,:)}}]; %#ok<AGROW>
						end
						me.awaitingPointResult = 2;
						me.calPoint = 1;
						me.drawState = 1;
						if bitget(me.logTypes,1)
							me.log_to_cmd('calibration failed discarding all points and starting over');
						end
					end
					me.lastUpdate = {};
				elseif ~isempty(me.lastUpdate)
					% unexpected (perhaps stale, e.g. from before auto was switched on) update, discard
					if bitget(me.logTypes,1)
						me.log_to_cmd('unexpected update from Titta during calibration: %s, discarding',me.lastUpdate{1});
					end
					me.lastUpdate = {};
				end
			elseif dist < me.calOnTargetDistFac*me.scrRes(2)
				me.reward(true);
				if me.onVideoTimestamp<0 || isnan(me.onVideoTimestamp)
					me.onVideoTimestamp = me.latestTimestamp;
				end
				onDur = me.latestTimestamp-me.onVideoTimestamp;
				if onDur > me.calOnTargetTime && me.awaitingPointResult==0
					% request calibration point collection
					commands = {{'cal','collect_point', me.calPoints(me.calPoint), me.calPoss(me.calPoint,:)}};
					me.awaitingPointResult = 1;
					me.calPointsState(me.calPoint) = me.pointStateEnum.collecting;
					me.drawExtraFrame = true;
					if bitget(me.logTypes,1)
						me.log_to_cmd('request calibration of point %d @ (%.3f,%.3f)', me.calPoints(me.calPoint), me.calPoss(me.calPoint,:));
					end
				end
			else
				if me.onVideoTimestamp>0 || isnan(me.onVideoTimestamp)
					me.onVideoTimestamp = -me.latestTimestamp;
				end
				offDur = me.latestTimestamp--me.onVideoTimestamp;
				if offDur > me.maxOffScreenTime
					me.reward(false);
					% request discarding data for this point if its being
					% collected
					if me.calPointsState(me.calPoint)==me.pointStateEnum.collecting || me.awaitingPointResult~=0
						commands = {{'cal','discard_point', me.calPoints(me.calPoint), me.calPoss(me.calPoint,:)}};
						me.awaitingPointResult = 2;
						me.calPointsState(me.calPoint) = me.pointStateEnum.discarding;
						if bitget(me.logTypes,1)
							me.log_to_cmd('request discarding calibration point %d @ (%.3f,%.3f)',me.calPoints(me.calPoint), me.calPoss(me.calPoint,:));
						end
					end
				end
			end
		end


		function commands = validate(me)
			commands = {};
			if me.awaitingPointResult>0
				% we're waiting for the result of an action. Check if there
				% is a result and process. Unlike calibration, this does
				% not short-circuit the logic below, as we may wish to
				% abort collection of a validation point
				if me.awaitingPointResult==1 && ~isempty(me.lastUpdate) && strcmp(me.lastUpdate{1},'val_collect_done')
					% check this is for the expected point
					if me.lastUpdate{2}==me.valPoints(me.valPoint) && all(me.lastUpdate{3}==me.valPoss(me.valPoint,:))
						% validation points always succeed, decide next
						% action
						if me.valPoint<length(me.valPoints)
							me.valPoint = me.valPoint+1;
							me.awaitingPointResult = 0;
							me.shouldUpdateStatusText = true;
							me.onVideoTimestamp = nan;
							me.drawState = 1;
							if bitget(me.logTypes,1)
								me.log_to_cmd('successfully collected validation point %d, continue with collection of point %d', me.valPoints(me.valPoint-1), me.valPoints(me.valPoint));
							end
						else
							% done validating
							me.awaitingPointResult = 0;
							me.reward(false);
							me.controlState = me.stateEnum.val_done;
							me.shouldUpdateStatusText = true;
							me.onVideoTimestamp = nan;
							commands = {{'val','disable_controller'}};
							me.drawState = 0;
							if me.valShowVideoWhenDone
								me.setupNonActiveVideo();
							end
							if bitget(me.logTypes,1)
								me.log_to_cmd('validation finished, disabling controller');
							end
							return
						end
					end
					me.lastUpdate = {};
				elseif me.awaitingPointResult==2 && ~isempty(me.lastUpdate) && strcmp(me.lastUpdate{1},'val_discard')
					% check this is for the expected point
					if me.lastUpdate{2}==me.valPoints(me.valPoint) && all(me.lastUpdate{3}==me.valPoss(me.valPoint,:))
						me.awaitingPointResult = 0;
					end
					me.lastUpdate = {};
				elseif ~isempty(me.lastUpdate)
					% unexpected (perhaps stale, e.g. from before auto was switched on) update, discard
					if bitget(me.logTypes,1)
						me.log_to_cmd('unexpected update from Titta during validation: %s, discarding',me.lastUpdate{1});
					end
					me.lastUpdate = {};
				end
			end

			valPos = me.valPoss(me.valPoint,:).*me.scrRes(:).';
			distL  = hypot(me. leftGaze(1)-valPos(1), me. leftGaze(2)-valPos(2));
			distR  = hypot(me.rightGaze(1)-valPos(1), me.rightGaze(2)-valPos(2));
			distM  = hypot(me. meanGaze(1)-valPos(1), me. meanGaze(2)-valPos(2));
			minDist = min([distM, distL, distR]);
			if minDist<me.valOnTargetDist
				if me.onVideoTimestamp<0 || isnan(me.onVideoTimestamp)
					me.onVideoTimestamp = me.latestTimestamp;
				end
				onDur = me.latestTimestamp-me.onVideoTimestamp;
				if onDur > me.valOnTargetTime && me.awaitingPointResult==0
					me.reward(true)
					% request validation point collection
					commands = {{'val','collect_point', me.valPoints(me.valPoint), me.valPoss(me.valPoint,:)}};
					me.awaitingPointResult = 1;
					me.valPointsState(me.valPoint) = me.pointStateEnum.collecting;
					me.drawExtraFrame = true;
					if bitget(me.logTypes,1)
						me.log_to_cmd('request collection of validation data for point %d @ (%.3f,%.3f)', me.valPoints(me.valPoint), me.valPoss(me.valPoint,:));
					end
				end
			else
				me.reward(false)
				% request discarding data for this point if its being
				% collected
				if me.valPointsState(me.valPoint)==me.pointStateEnum.collecting || me.awaitingPointResult~=0
					commands = {{'val','discard_point', me.valPoints(me.valPoint), me.valPoss(me.valPoint,:)}};
					me.awaitingPointResult = 2;
					me.valPointsState(me.valPoint) = me.pointStateEnum.discarding;
					if bitget(me.logTypes,1)
						me.log_to_cmd('request discarding validation point %d @ (%.3f,%.3f)',me.valPoints(me.valPoint), me.valPoss(me.valPoint,:));
					end
				end
			end
		end

		function setTittaPacing(me,set,reset)
			settings = me.EThndl.getOptions();
			if ~isempty(set)
				me.backupPaceDuration.(set) = settings.advcal.(set).paceDuration;
				settings.advcal.(set).paceDuration = 0;
				if bitget(me.logTypes,1)
					me.log_to_cmd('setting Titta pacing duration for %s to 0',ternary(strcmpi(set,'cal'),'calibration','validation'));
				end
			end
			if ~isempty(reset) && ~isempty(me.backupPaceDuration.(reset))
				settings.advcal.(reset).paceDuration = me.backupPaceDuration.(reset);
				me.backupPaceDuration.(reset) = [];
				if bitget(me.logTypes,1)
					me.log_to_cmd('resetting Titta pacing duration for %s',ternary(strcmpi(reset,'cal'),'calibration','validation'));
				end
			end
			me.EThndl.setOptions(settings);
		end

		function setupNonActiveVideo(me)
			if strcmp(me.stage,'cal')
				me.calDisplay.videoSize = me.calVideoSizeWhenDone;
			else
				me.calDisplay.videoSize = me.valVideoSizeWhenDone;
			end
			me.drawState = 1;
			me.isNonActiveShowingVideo = true;
			me.onVideoTimestamp = nan;
		end

		function determineNonActiveReward(me)
			% for during manual calibration points and when showing video
			% after a calibration or validation
			vidPos = me.calDisplay.pos;
			distL  = hypot(me. leftGaze(1)-vidPos(1), me. leftGaze(2)-vidPos(2));
			distR  = hypot(me.rightGaze(1)-vidPos(1), me.rightGaze(2)-vidPos(2));
			distM  = hypot(me. meanGaze(1)-vidPos(1), me. meanGaze(2)-vidPos(2));
			minDist = min([distM, distL, distR]);

			if strcmp(me.stage,'cal')
				distFac = me.calWhenDoneRewardDistFac;
				dur     = me.calWhenDoneRewardTime;
			else
				distFac = me.valWhenDoneRewardDistFac;
				dur     = me.valWhenDoneRewardTime;
			end
			sz = me.calDisplay.videoSize;
			dist = sz(1)*distFac;

			if minDist < dist
				if me.onVideoTimestamp<0 || isnan(me.onVideoTimestamp)
					me.onVideoTimestamp = me.latestTimestamp;
				end
				onDur = me.latestTimestamp-me.onVideoTimestamp;
				if onDur > dur
					me.reward(true)
				end
			end
		end

		function log_to_cmd(me,msg,varargin)
			message = sprintf(['%s: ' msg],mfilename('class'),varargin{:});
			switch me.logReceiver
				case 0
					fprintf('%s\n',message);
				case 1
					me.EThndl.sendMessage(message);
				otherwise
					error('logReceived %d unknown',me.logReceiver);
			end
		end
	end
end

%% helpers
function out = ternary(cond, a, b)
out = subsref({b; a}, substruct('{}', {cond + 1}));
end
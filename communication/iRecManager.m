% ========================================================================
classdef iRecManager < eyetrackerCore
%> @class irecManager
%> @brief Manages the iRec eyetrackers
%>
%> The core methods enable the user to test for common behavioural eye
%> tracking tasks with single commands. For example, to initiate a task we
%> normally place a fixation cross on the screen and ask the subject to
%> saccade to the cross and maintain fixation for a particular duration. This
%> is achieved using testSearchHoldFixation('yes','no'), using the properties:
%> fixation.initTime to time how long the subject has to saccade into the
%> window, fixation.time for how long they must maintain fixation,
%> fixation.radius for the radius around fixation.X and fixation.Y
%> position. The method returns the 'yes' string if the rules are matched, 
%> and 'no' if they are not, thus enabling experiment code to simply define what 
%> happened. Other methods include isFixated(), testFixationTime(),
%> testHoldFixation(). 
%>
%> Multiple fixation windows can be assigned, and in addition exclusion
%> windows can ensure a subject doesn't saccade to particular parts of the
%> screen. fixInit allows you to define a minimum time with which the subject
%> must initiate a saccade away from a position (which stops a subject cheating).
%>
%> @todo refactor this and eyelinkManager to inherit from a common eyelinkManager
%> @todo handle new eye-openness signals in new SDK https://developer.tobiipro.com/commonconcepts/eyeopenness.html
%>
%> Copyright ©2014-2023 Ian Max Andolina — released: LGPL3, see LICENCE.md
% ========================================================================
	
	properties (SetAccess = protected, GetAccess = public)
		%> type of eyetracker
		type							= 'iRec'
		%> TCP interface
		tcp
		%> udp interface
		udp
	end

	properties
		%> setup and calibration values
		calibration		= struct('ip','127.0.0.1','udpport',35000,'tcpport',35001,...
						'stimulus','animated','CalPositions',[-15 0; 0 -15; 0 0; 0 15; 15 0],...
						'valPositions',[-15 0; 0 -15; 0 0; 0 15; 15 0],...
						'manual', false, 'movie', [])
		%> options for online smoothing of peeked data {'median','heuristic','savitsky-golay'}
		smoothing		= struct('nSamples',8,'method','median','window',3,...
						'eyes','both')
	end
	
	properties (Hidden = true)

	end
	
	properties (SetAccess = protected, GetAccess = public, Dependent = true)
		% calculates the smoothing in ms
		smoothingTime double
	end
	
	properties (SetAccess = protected, GetAccess = protected)
		%> tracker time stamp
		systemTime						= 0
		calibData
		calStim
		%> currentSample template
		sampleTemplate struct			= struct('raw',[],'time',NaN,'timeD',NaN,'gx',NaN,'gy',NaN,...
											'pa',NaN,'valid',false)
		%> allowed properties passed to object upon construction
		allowedProperties	= {'calibration', 'smoothing'}
	end
	
	%=======================================================================
	methods %------------------PUBLIC METHODS
	%=======================================================================
	
		% ===================================================================
		function me = iRecManager(varargin)
		%> @fn iRecManager
		%>
		%> iRecManager CONSTRUCTOR
		%>
		%> @param varargin can be passed as a structure or name,arg pairs
		%> @return instance of the class.
		% ===================================================================
			args = optickaCore.addDefaults(varargin,struct('name','iRec','sampleRate',500));
			me=me@eyetrackerCore(args); %we call the superclass constructor first
			me.parseArgs(args, me.allowedProperties);
			
			p = fileparts(me.saveFile);
			if isempty(p)
				me.saveFile = [me.paths.savedData filesep me.saveFile];
			end
		end
		
		% ===================================================================
		%> @brief initialise 
		%>
		%> @param sM - screenManager object we will use
		%> @param sM2 - a second screenManager used during calibration
		% ===================================================================
		function success = initialise(me,sM,sM2)
			if ~exist('sM','var') || isempty(sM)
				if isempty(me.screen) || ~isa(me.screen,'screenManager')
					me.screen		= screenManager();
				end
			else
				me.screen			= sM;
			end
			me.ppd_					= me.screen.ppd;
			if me.screen.isOpen
				me.win				= me.screen.win;
			end
			if me.useOperatorScreen && ~exist('sM2','var')
				sM2 = screenManager('pixelsPerCm',20,...
					'disableSyncTests',true,'backgroundColour',sM.backgroundColour,...
					'screen', me.screen.screen - 1, 'specialFlags', kPsychGUIWindow);
					[w,h]			= Screen('WindowSize',sM2.screen);
					sM2.windowed	= [0 0 round(w/2) round(h/2)];
			end
			if ~exist('sM2','var') || ~isa(sM2,'screenManager')
				me.secondScreen		= false;
			else
				me.operatorScreen	= sM2;
				me.secondScreen		= true;
			end
			
			if me.isDummy
				me.salutation('Initialise', 'Running in Dummy Mode', true);
			else
				if isempty(me.tcp)
					me.tcp = dataConnection('rAddress', me.calibration.ip,'rPort',...
					me.calibration.tcpport);
				end
				if isempty(me.udp)
					me.udp = dataConnection('rAddress', me.calibration.ip,'rPort',...
					me.calibration.udpport,'protocol','udp');
				end
				try 
					open(me.tcp);
					open(me.udp);
					me.udp.write(int32(1e6));
					me.isConnected = true;
					me.salutation('Initialise', ...
						sprintf('Running on a iRec | Screen %i %i x %i @ %iHz', ...
						me.screen.screen,...
						me.screen.winRect(3),...
						me.screen.winRect(4),...
						me.screen.screenVals.fps),true);
				catch
					me.salutation('Initialise', 'Cannot connect, running in Dummy Mode', true);
					me.isConnected = false;
					me.isDummy = true;
				end

			end
			success = true;
		end

		% ===================================================================
		%> @brief check the connection with the tobii
		%>
		% ===================================================================
		function connected = checkConnection(me)
			connected = me.isConnected;
		end
		
		% ===================================================================
		%> @brief sets up the calibration and validation
		%>
		% ===================================================================
		function cal = trackerSetup(me,incal)
			cal = [];
			if ~me.isConnected 
				warning('Eyetracker not connected, cannot calibrate!');
				return
			end
			if me.useOperatorScreen && isa(me.operatorScreen,'screenManager'); open(me.operatorScreen); end
			if me.isDummy
				disp('--->>> iRec Dummy Mode: calibration skipped')
				return;
			end
			if ~me.screen.isOpen 
				open(me.screen);
			end
			fprintf('\n===>>> CALIBRATING IREC... <<<===\n');
			
			RestrictKeysForKbCheck([27 48:57]);

			f = fixationCrossStimulus();
			f.size = 2;
			hide(f);
			
			setup(f, me.screen);
			
			pos = [-15 0; 0 -15; 0 0; 0 15; 15 0];
			nPositions = size(pos,1);
			
			f.xPositionOut = pos(1,1);
			f.yPositionOut = pos(1,2);
			update(f);
			loop = true;
			thisPos = 0;
			
			while loop
			
				[pressed,~,keys] = KbCheck(-1);
				if pressed
					k = lower(KbName(keys));
					if matches(k,'escape'); loop = false; end
					if length(k) == 2; k = k(1); end
					k = str2double(k);
					if k == 0
						hide(f);
					elseif k > 0 && k <= nPositions
						show(f);
						f.xPositionOut = pos(k,1);
						f.yPositionOut = pos(k,2);
						update(f);
						disp('Change Calibration Position...');
					end
				end
				drawGrid(s);
				draw(f);
				flip(s);
			
			end


			resetAll(me);
			RestrictKeysForKbCheck([]);
		end
		
		% ===================================================================
		%> @brief get a sample from the tracker, if dummymode=true then use
		%> the mouse as an eye signal
		%>
		% ===================================================================
		function sample = getSample(me)
			sample				= me.sampleTemplate;
			if me.isDummy %lets use a mouse to simulate the eye signal
				if ~isempty(me.win)
					[mx, my]	= GetMouse(me.win);
				else
					[mx, my]	= GetMouse([]);
				end
				sample.valid	= true;
				me.pupil		= 5 + randn;
				sample.gx		= mx;
				sample.gy		= my;
				sample.pa		= me.pupil;
				sample.time		= GetSecs * 1e6;
				me.x			= me.toDegrees(sample.gx,'x');
				me.y			= me.toDegrees(sample.gy,'y');
				me.xAll			= [me.xAll me.x];
				me.yAll			= [me.yAll me.y];
				me.pupilAll		= [me.pupilAll me.pupil];
				%if me.verbose;fprintf('>>X: %.2f | Y: %.2f | P: %.2f\n',me.x,me.y,me.pupil);end
			elseif me.isConnected && me.isRecording
				xy				= [];
				td				= me.tcp.readLines(me.smoothing.nSamples,'last');
				if isempty(td);me.currentSample=sample;return;end
				td				= str2num(td); %#ok<*ST2NM> 
				sample.raw		= td;
				sample.time		= td(end,1);
				sample.timeD	= GetSecs * 1e6;
				xy(1,:)			=  td(:,2)';
				xy(2,:)			= -td(:,3)';
				if ~isempty(xy)
					sample.valid = true;
					xy			= doSmoothing(me,xy);
					sample.gx	= xy(1);
					sample.gy	= xy(2);
					sample.pa	= median(td(:,4));
					me.x		= xy(1);
					me.y		= xy(2);
					me.pupil	= sample.pa;
					if me.verbose;fprintf('>>X: %2.2f | Y: %2.2f | P: %.2f\n',me.x,me.y,me.pupil);end
				else
					sample.gx	= NaN;
					sample.gy	= NaN;
					sample.pa	= NaN;
					me.x		= NaN;
					me.y		= NaN;
					me.pupil	= NaN;
				end
				me.xAll			= [me.xAll me.x];
				me.yAll			= [me.yAll me.y];
				me.pupilAll		= [me.pupilAll me.pupil];
			else
				if me.verbose;fprintf('-+-+-> tobiiManager.getSample(): are you sure you are recording?\n');end
			end
			me.currentSample	= sample;
		end
		
		% ===================================================================
		%> @brief draw N last eye position on the PTB display
		%>
		% ===================================================================
		function drawEyePositions(me,dataDur)
			if (~me.isDummy || me.isConnected) && me.screen.isOpen
				nDataPoint  = ceil(dataDur/1000*fs);
				eyeData     = me.tobii.buffer.peekN('gaze',nDataPoint);
				pointSz		= 3;
				point       = pointSz.*[0 0 1 1];
				if ~isempty(eyeData.systemTimeStamp)
					age=double(abs(eyeData.systemTimeStamp-eyeData.systemTimeStamp(end)))/1000;
					if qShowLeft
						qValid = eyeData.left.gazePoint.valid;
						lE = bsxfun(@times,eyeData.left.gazePoint.onDisplayArea(:,qValid),me.screen.screenVals.winRect(3:4));
						if ~isempty(lE)
							clrs = interp1([0;dataDur],[1 0 1 1],age(qValid)).';
							lE = CenterRectOnPointd(point,lE(1,:).',lE(2,:).');
							Screen('FillOval', me.win, clrs, lE.', 2*pi*pointSz);
						end
					end
					if qShowRight
						qValid = eyeData.right.gazePoint.valid;
						rE = bsxfun(@times,eyeData.right.gazePoint.onDisplayArea(:,qValid),me.screen.screenVals.winRect(3:4));
						if ~isempty(rE)
							clrs = interp1([0;dataDur],[1 1 0 1],age(qValid)).';
							rE = CenterRectOnPointd(point,rE(1,:).',rE(2,:).');
							Screen('FillOval', me.win, clrs, rE.', 2*pi*pointSz);
						end
					end
				end
			end
		end
		
		% ===================================================================
		%> @brief send message to store in tracker data
		%>
		%>
		% ===================================================================
		function trackerMessage(me, message, varargin)
			if me.isConnected
				me.udp.write(int32(message));
				if me.verbose; fprintf('-+-+->IREC Message: %s\n',message);end
			end
		end

		% ===================================================================
		%> @brief close the tobii and cleanup
		%> is enabled
		%>
		% ===================================================================
		function close(me)
			try
				try stopRecording(me); end
				me.isConnected = false;
				me.isRecording_ = false;
				resetAll(me);
				if me.secondScreen && ~isempty(me.operatorScreen) && isa(me.operatorScreen,'screenManager')
					try close(me.operatorScreen); end
				end
			catch ME
				me.salutation('Close Method','Couldn''t stop recording, forcing shutdown...',true)
				me.isConnected = false;
				me.isRecording = false;
				resetAll(me);
				if me.secondScreen && ~isempty(me.operatorScreen) && isa(me.operatorScreen,'screenManager')
					me.operatorScreen.close;
				end
				getReport(ME);
			end
		end
		
		% ===================================================================
		%> @brief runs a demo of the workflow, testing this class
		%>
		% ===================================================================
		function runDemo(me,forcescreen)
			KbName('UnifyKeyNames')
			stopkey				= KbName('q');
			upKey				= KbName('uparrow');
			downKey				= KbName('downarrow');
			leftKey				= KbName('leftarrow');
			rightKey			= KbName('rightarrow');
			calibkey			= KbName('c');
			ofixation			= me.fixation; 
			osmoothing			= me.smoothing;
			ofilename			= me.saveFile;
			oldexc				= me.exclusionZone;
			oldfixinit			= me.fixInit;
			me.initialiseSaveFile();
			[p,~,e]				= fileparts(me.saveFile);
			me.saveFile			= [p filesep 'iRecRunDemo-' me.savePrefix e];
			useS2				= false;
			try
				if isa(me.screen,'screenManager') && ~isempty(me.screen)
					s = me.screen;
				else
					s = screenManager('blend',true,'pixelsPerCm',36,'distance',57.3);
				end
				s.disableSyncTests		= true;
				if exist('forcescreen','var'); s.screen = forcescreen; end
				if me.secondScreen || (length(Screen('Screens'))>1 && s.screen - 1 >= 0)
					useS2				= true;
					if isa(me.operatorScreen,'screenManager')
						s2 = me.operatorScreen;
					else
						s2					= screenManager;
						s2.pixelsPerCm		= 15;
						s2.screen			= s.screen - 1;
						s2.backgroundColour	= s.backgroundColour;
						[w,h]				= Screen('WindowSize',s2.screen);
						s2.windowed			= [0 0 round(w/2) round(h/2)];
					end
					s2.bitDepth			= '8bit';
					s2.blend			= true;
					s2.disableSyncTests	= true;
				end
			
				sv=open(s); %open our screen
				
				if useS2
					initialise(me, s, s2); %initialise with our screen
					s2.open();
				else
					initialise(me, s); %initialise with our screen
				end
				trackerSetup(me);
				ShowCursor; %titta fails to show cursor so we must do it
				drawPhotoDiodeSquare(s,[0 0 0 1]); flip(s); %make sure our photodiode patch is black
				
				% set up the size and position of the stimulus
				o = dotsStimulus('size',me.fixation.radius(1)*2,'speed',2,'mask',true,'density',50); %test stimulus
				if length(me.fixation.radius) == 1
					f = discStimulus('size',me.fixation.radius(1)*2,'colour',[0 0 0],'alpha',0.25);
				else
					f = barStimulus('barWidth',me.fixation.radius(1)*2,'barHeight',me.fixation.radius(2)*2,...
						'colour',[0 0 0],'alpha',0.25);
				end
				setup(o,s); %setup our stimulus with open screen
				setup(f,s); %setup our stimulus with open screen
				o.xPositionOut = me.fixation.X;
				o.yPositionOut = me.fixation.Y;
				f.alpha
				f.xPositionOut = me.fixation.X;
				f.xPositionOut = me.fixation.X;
				
				% set up an exclusion zone where eye is not allowed
				me.exclusionZone = [8 12 9 12];
				exc = me.toPixels(me.exclusionZone);
				exc = [exc(1) exc(3) exc(2) exc(4)]; %psychrect=[left,top,right,bottom] 

				% warm up
				fprintf('\n===>>> Warming up the GPU, Eyetracker etc... <<<===\n')
				Priority(MaxPriority(s.win));
				HideCursor(s.win);
				endExp = 0;
				trialn = 1;
				maxTrials = 10;
				psn = cell(maxTrials,1);
				m=1; n=1;
				methods={'median','heuristic1','heuristic2','sg','simple'};
				eyes={'both','left','right'};
				if ispc; Screen('TextFont',s.win,'Consolas'); end
				sgolayfilt(rand(10,1),1,3); %warm it up
				me.heuristicFilter(rand(10,1), 2);
				startRecording(me, true);
				WaitSecs('YieldSecs',1);
				for i = 1 : s.screenVals.fps
					draw(o);draw(f);
					drawBackground(s);
					drawPhotoDiodeSquare(s,[0 0 0 1]);
					Screen('DrawText',s.win,['Warm up frame: ' num2str(i)],65,10);
					finishDrawing(s);
					animate(o);
					getSample(me); isFixated(me); resetFixation(me);
					flip(s);
				end
				drawPhotoDiodeSquare(s,[0 0 0 1]);
				flip(s);
				if useS2;flip(s2);end
				ListenChar(-1);
				update(o); %make sure stimuli are set back to their start state
				update(f);
				WaitSecs('YieldSecs',0.5);
				trackerMessage(me,0)
				while trialn <= maxTrials && endExp == 0
					trialtick = 1;
					trackerMessage(me,1)
					drawPhotoDiodeSquare(s,[0 0 0 1]);
					flip(s2,[],[],2);
					vbl = flip(s); tstart=vbl+sv.ifi;
					trackerMessage(me,1);
					while vbl < tstart + 6
						Screen('FillRect',s.win,[0.7 0.7 0.7 0.5],exc); Screen('DrawText',s.win,'Exclusion Zone',exc(1),exc(2),[0.8 0.8 0.8]);
						draw(o); draw(f);
						drawGrid(s);
						drawCross(s,0.5,[1 1 0],me.fixation.X,me.fixation.Y);
						drawPhotoDiodeSquare(s,[1 1 1 1]);
						
						getSample(me); isFixated(me);
						
						if ~isempty(me.currentSample)
							txt = sprintf('Q = finish. X: %3.1f / %2.2f | Y: %3.1f / %2.2f | # = %2i %s %s | RADIUS = %s | TIME = %.2f | FIXATION = %.2f | EXC = %i | INIT FAIL = %i',...
								me.currentSample.gx, me.x, me.currentSample.gy, me.y, me.smoothing.nSamples,...
								me.smoothing.method, me.smoothing.eyes, sprintf('%1.1f ',me.fixation.radius), ...
								me.fixTotal,me.fixLength,me.isExclusion,me.isInitFail);
							Screen('DrawText', s.win, txt, 10, 10,[1 1 1]);
							drawEyePosition(me,true);
						end
						if useS2
							drawGrid(s2);
							trackerDrawExclusion(me);
							trackerDrawFixation(me);
						end
						finishDrawing(s);
						animate(o);
						
						vbl(end+1) = Screen('Flip', s.win, vbl(end) + s.screenVals.halfifi);
						if useS2; flip(s2,[],[],2); end
						[keyDown, ~, keyCode] = KbCheck(-1);
						if keyDown
							if keyCode(stopkey); endExp = 1; break;
							elseif keyCode(calibkey); me.doCalibration;
							elseif keyCode(upKey); me.smoothing.nSamples = me.smoothing.nSamples + 1; if me.smoothing.nSamples > 400; me.smoothing.nSamples=400;end
							elseif keyCode(downKey); me.smoothing.nSamples = me.smoothing.nSamples - 1; if me.smoothing.nSamples < 1; me.smoothing.nSamples=1;end
							elseif keyCode(leftKey); m=m+1; if m>5;m=1;end; me.smoothing.method=methods{m};
							elseif keyCode(rightKey); n=n+1; if n>3;n=1;end; me.smoothing.eyes=eyes{n};
							end
						end
						trialtick=trialtick+1;
					end
					if endExp == 0
						drawPhotoDiodeSquare(s,[0 0 0 1]);
						vbl = flip(s);
						if useS2; flip(s2,[],[],2); end
						trackerMessage(me,-1);
						resetFixation(me);
						me.fixation.X = randi([-7 7]);
						me.fixation.Y = randi([-7 7]);
						if length(me.fixation.radius) == 1
							me.fixation.radius = randi([1 3]);
							o.sizeOut = me.fixation.radius * 2;
							f.sizeOut = me.fixation.radius * 2;
						else
							me.fixation.radius = [randi([1 3]) randi([1 3])];
							o.sizeOut = mean(me.fixation.radius) * 2;
							f.barWidthOut = me.fixation.radius(1) * 2;
							f.barHeightOut = me.fixation.radius(2) * 2;
						end
						o.xPositionOut = me.fixation.X;
						o.yPositionOut = me.fixation.Y;
						f.xPositionOut = me.fixation.X;
						f.yPositionOut = me.fixation.Y;
						update(o);update(f);
						WaitSecs(0.3);
						trialn = trialn + 1;
					else
						drawPhotoDiodeSquare(s,[0 0 0 1]);
						vbl = flip(s);
						trackerMessage(me,-100);
					end
				end
				stopRecording(me);
				ListenChar(0); Priority(0); ShowCursor;
				try close(s); close(s2);end %#ok<*TRYNC>
				saveData(me);
				assignin('base','psn',psn);
				assignin('base','data',me.data);
				close(me);
				me.fixation = ofixation;
				me.saveFile = ofilename;
				me.smoothing = osmoothing;
				me.exclusionZone = oldexc;
				me.fixInit = oldfixinit;
				clear s s2 o
			catch ME
				stopRecording(me);
				me.fixation = ofixation;
				me.saveFile = ofilename;
				me.smoothing = osmoothing;
				me.exclusionZone = oldexc;
				me.fixInit = oldfixinit;
				ListenChar(0);Priority(0);ShowCursor;
				getReport(ME)
				try close(s); end
				try close(s2); end
				sca;
				try close(me); end
				clear s s2 o
				rethrow(ME)
			end
			
		end
		
		% ===================================================================
		%> @brief smooth data in M x N where M = 2 (x&y trace) or M = 4 is x&y
		%> for both eyes. Output is 2 x 1 x&y averages position
		%>
		% ===================================================================
		function out = doSmoothing(me,in)
			if size(in,2) > me.smoothing.window * 2
				switch me.smoothing.method
					case 'median'
						out = movmedian(in,me.smoothing.window,2);
						out = median(out, 2);
					case {'heuristic','heuristic1'}
						out = me.heuristicFilter(in,1);
						out = median(out, 2);
					case 'heuristic2'
						out = me.heuristicFilter(in,2);
						out = median(out, 2);
					case {'sg','savitzky-golay'}
						out = sgolayfilt(in,1,me.smoothing.window,[],2);
						out = median(out, 2);
					otherwise
						out = median(in, 2);
				end
			elseif size(in, 2) > 1
				out = median(in, 2);
			else
				out = in;
			end
			if size(out,1)==4 % XY for both eyes, combine together.
				out = [mean([out(1) out(3)]); mean([out(2) out(4)])];
			end
			if length(out) ~= 2
				out = [NaN NaN];
			end
		end
		
		% ===================================================================
		%> @brief
		%>
		% ===================================================================
		function value = checkRecording(me)
			if me.isConnected
				value = true;
			else
				value = false;
			end
		end
		
		% ===================================================================
		%> @brief
		%>
		% ===================================================================
		function value = get.smoothingTime(me)
			value = (1000 / me.sampleRate) * me.smoothing.nSamples;
		end
		
	end%-------------------------END PUBLIC METHODS--------------------------------%
	
	%============================================================================
	methods (Hidden = true) %--HIDDEN METHODS (compatibility with eyelinkManager)
		%============================================================================
		

		% ===================================================================
		%> @brief wrapper for StartRecording
		%>
		%> @param override - to keep compatibility with the eyelinkManager
		%> API we need to only start and stop recording using a passed
		%> parameter, as the eyelink requires start and stop on every trial
		%> but the does not. So by default without override==true this
		%> will just return.
		% ===================================================================
		function startRecording(me, ~)
			me.tcp.write(int8('start'));
			me.isRecording = true;
		end
		
		% ===================================================================
		%> @brief wrapper for StopRecording
		%>
		%> @param override - to keep compatibility with the eyelinkManager
		%> API we need to only start and stop recording using a passed
		%> parameter, as the eyelink requires start and stop on every trial
		%> but the does not. So by default without override==true this
		%> will just return.
		% ===================================================================
		function stopRecording(me, ~)
			me.tcp.write(int8('stop'));
			me.isRecording = true;
		end

		% ===================================================================
		%> @brief Sync time with tracker
		%>
		% ===================================================================
		function syncTrackerTime(me)
			
		end

		% ===================================================================
		%> @brief
		%>
		% ===================================================================
		function doCalibration(me)
			if me.isConnected
				me.trackerSetup();
			end
		end

		% ===================================================================
		%> @brief Save the data
		%>
		% ===================================================================
		function saveData(me,tofile)
			
		end
		% ===================================================================
		%> @brief
		%>
		% ===================================================================
		function updateDefaults(me)
			
		end

		% ===================================================================
		%> @brief checks which eye is available, force left eye if
		%> binocular is enabled
		%>
		% ===================================================================
		function eyeUsed = checkEye(me)
			if me.isConnected
				eyeUsed = me.eyeUsed;
			end
		end
		
		% ===================================================================
		%> @brief displays status message on tracker, only sets it if
		%> message is not the previous message, so loop safe.
		%>
		% ===================================================================
		function statusMessage(me,message)
			if me.isConnected
				if me.verbose; fprintf('-+-+->Tobii status message: %s\n',message);end
			end
		end
		
		% ===================================================================
		%> @brief send message to store in tracker data (compatibility)
		%>
		%>
		% ===================================================================
		function edfMessage(me, message)
			trackerMessage(me,message)
		end
		
		% ===================================================================
		%> @brief
		%>
		% ===================================================================
		function setup(me)
			updateDefaults(me)
		end
		
		% ===================================================================
		%> @brief set into offline / idle mode
		%>
		% ===================================================================
		function setOffline(me)
			
		end
		
		% ===================================================================
		%> @brief wrapper for EyelinkDoDriftCorrection
		%>
		% ===================================================================
		function success = driftCorrection(me)
			success = driftOffset(me);
		end
		
		% ===================================================================
		%> @brief check what mode the is in
		%>
		% ========================a===========================================
		function mode = currentMode(me)
			if me.isConnected
				mode = 0;
			end
		end
		
		% ===================================================================
		%> @brief Sync time with tracker
		%>
		% ===================================================================
		function syncTime(me)
			trackerMessage(me,'SYNCTIME');
		end
		
		
		% ===================================================================
		%> @brief Get offset between tracker and display computers
		%>
		% ===================================================================
		function offset = getTimeOffset(me)
			offset = 0;
		end
		
		% ===================================================================
		%> @brief Get tracker time
		%>
		% ===================================================================
		function [trackertime, systemtime] = getTrackerTime(me)
			if me.isConnected
				trackertime = 0;
				systemtime = 0;
			end
		end
		
		% ===================================================================
		%> @brief TODO
		%>
		% ===================================================================
		function evt = getEvent(me)
			
		end
		
	end%-------------------------END HIDDEN METHODS--------------------------------%
	
	%=======================================================================
	methods (Access = private) %------------------PRIVATE METHODS
		%=======================================================================
		
		% ===================================================================
		%> @brief Stampe 1993 heuristic filter as used by Eyelink
		%>
		%> @param indata - input data
		%> @param level - 1 = filter level 1, 2 = filter level 1+2
		%> @param steps - we step every # steps along the in data, changes the filter characteristics, 3 is the default (filter 2 is #+1)
		%> @out out - smoothed data
		% ===================================================================
		function out = heuristicFilter(~,indata,level,steps)
			if ~exist('level','var'); level = 1; end %filter level 1 [std] or 2 [extra]
			if ~exist('steps','var'); steps = 3; end %step along the data every n steps
			out=zeros(size(indata));
			for k = 1:2 % x (row1) and y (row2) eye samples
				in = indata(k,:);
				%filter 1 from Stampe 1993, see Fig. 2a
				if level > 0
					for i = 1:steps:length(in)-2
						x = in(i); x1 = in(i+1); x2 = in(i+2); %#ok<*PROPLC>
						if ((x2 > x1) && (x1 < x)) || ((x2 < x1) && (x1 > x))
							if abs(x1-x) < abs(x2-x1) %i is closest
								x1 = x;
							else
								x1 = x2;
							end
						end
						x2 = x1;
						x1 = x;
						in(i)=x; in(i+1) = x1; in(i+2) = x2;
					end
				end
				%filter2 from Stampe 1993, see Fig. 2b
				if level > 1
					for i = 1:steps+1:length(in)-3
						x = in(i); x1 = in(i+1); x2 = in(i+2); x3 = in(i+3);
						if x2 == x1 && (x == x1 || x2 == x3)
							x3 = x2;
							x2 = x1;
							x1 = x;
						else %x2 and x1 are the same, find closest of x2 or x
							if abs(x1 - x3) < abs(x1 - x)
								x2 = x3;
								x1 = x3;
							else
								x2 = x;
								x1 = x;
							end
						end
						in(i)=x; in(i+1) = x1; in(i+2) = x2; in(i+3) = x3;
					end
				end
				out(k,:) = in;
			end
		end
		
	end %------------------END PRIVATE METHODS
end

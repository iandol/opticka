% ========================================================================
classdef pupilCoreManager < eyetrackerCore & eyetrackerSmooth
%> @class pupilCoreManager
%> @brief Manages the Pupil Labs Core
%>
%> The eyetrackerCore methods enable the user to test for common behavioural
%> eye tracking tasks with single commands.
%>
%> Multiple fixation windows can be assigned, the windows can be either
%> circular or rectangular. In addition rectangular exclusion windows can ensure a
%> subject doesn't saccade to particular parts of the screen. fixInit allows
%> you to define a minimum time with which the subject must initiate a
%> saccade away from a position (which stops a subject cheating in a trial).
%>
%> To initiate a task we normally place a fixation cross on the screen and
%> ask the subject to saccade to the cross and maintain fixation for a
%> particular duration. This is achieved using
%> testSearchHoldFixation('yes','no'), using the properties:
%> fixation.initTime to time how long the subject has to saccade into the
%> window, fixation.time for how long they must maintain fixation,
%> fixation.radius for the radius around fixation.X and fixation.Y position.
%> The method returns the 'yes' string if the rules are matched, and 'no' if
%> they are not, thus enabling experiment code to simply define what
%> happened. Other methods include isFixated(), testFixationTime(),
%> testHoldFixation().
%>
%> Copyright ©2014-2023 Ian Max Andolina — released: LGPL3, see LICENCE.md
% ========================================================================
	
	%-----------------CONTROLLED PROPERTIES-------------%
	properties (SetAccess = protected, GetAccess = public)
		%> type of eyetracker
		type			= 'pupil'
	end

	%---------------PUBLIC PROPERTIES---------------%
	properties
		%> initial setup and calibration values
		calibration		= struct(...
						'ip', '127.0.0.1',...
						'port', 50020,... % used to send messages
						'stimulus','animated',... % calibration stimulus can be animated, movie
						'movie', [],... % if movie pass a movieStimulus 
						'calPositions', [-12 0; 0 -12; 0 0; 0 12; 12 0],...
						'valPositions', [-12 0; 0 -12; 0 0; 0 12; 12 0],...
						'size', 2,... % size of calibration cross in degrees
						'doBeep',true,... % beep for calibration reward
						'manual', false,...
						'timeout', 1000)
		%> WIP we can optionally drive physical LEDs for calibration, each LED
		%> is triggered by the me.calibration.calPositions order.
		useLEDs			= false
	end

	%-----------------CONTROLLED PROPERTIES-------------%
	properties (SetAccess = protected, GetAccess = public)
		%> communication socket 
		socket
		%> subscription socket
		sub
		%> publishing socket
		pub
	end

	properties (Hidden = true)
		% for led calibration, which arduino pin to start from
		startPin		= 3
	end
	
	%--------------------PROTECTED PROPERTIES----------%
	properties (SetAccess = protected, GetAccess = protected)
		rawSamples		= []
		% zmq context
		ctx
		%> endpoint
		endpoint
		%> subscribe endpoint
		subEndpoint
		%> subscribe endpoint
		pubEndpoint
		% screen values taken from screenManager
		sv				= []
		%> tracker time stamp
		systemTime		= 0
		% stimulus used for calibration
		calStim			= []
		%> allowed properties passed to object upon construction
		allowedProperties	= {'calibration', 'useLEDs', 'smoothing'}
	end
	
	%=======================================================================
	methods %------------------PUBLIC METHODS
	%=======================================================================
	
		% ===================================================================
		function me = pupilCoreManager(varargin)
		%> @fn pupilCoreManager(varargin)
		%>
		%> pupilCoreManager CONSTRUCTOR
		%>
		%> @param varargin can be passed as a structure, or name+arg pairs
		%> @return instance of the class.
		% ===================================================================
			args = optickaCore.addDefaults(varargin,struct('name','PupilLabs',...
				'useOperatorScreen',true,'sampleRate',120));
			me=me@eyetrackerCore(args); %we call the superclass constructor first
			me.parseArgs(args, me.allowedProperties);
			me.smoothing.sampleRate = me.sampleRate;

			if ~exist('zmq.Context','class')
				warning('Please install matlab-zmq package via https://github.com/iandol/matlab-zmq!!!')
			else
				fprintf('--->>> Pupil Labs core using %s', zmq.core.version);
			end
		end
		
		% ===================================================================
		function success = initialise(me, sM, sM2)
		%> @fn initialise(me, sM, sM2)
		%> @brief initialise 
		%>
		%> @param sM - screenManager for the subject
		%> @param sM2 - a second screenManager used for operator, if
		%>  none is provided a default will be made.
		% ===================================================================
			
			[rM, aM] = initialiseGlobals(me, false, true);

			if ~exist('sM','var') || isempty(sM)
				if isempty(me.screen) || ~isa(me.screen,'screenManager')
					me.screen		= screenManager;
				end
			else
					me.screen			= sM;
			end
			me.ppd_					= me.screen.ppd;
			if me.screen.isOpen; me.win	= me.screen.win; end

			me.rawSamples = round( 0.2 / ( 1 / me.sampleRate ) );

			if me.screen.screen > 0
				oscreen = me.screen.screen - 1;
			else
				oscreen = 0;
			end
			if exist('sM2','var')
				me.operatorScreen = sM2;
			elseif isempty(me.operatorScreen)
				me.operatorScreen = screenManager('pixelsPerCm',24,...
					'disableSyncTests',true,'backgroundColour',me.screen.backgroundColour,...
					'screen', oscreen, 'specialFlags', kPsychGUIWindow);
				[w,h]			= Screen('WindowSize',me.operatorScreen.screen);
				me.operatorScreen.windowed	= [20 20 round(w/1.6) round(h/1.8)];
			end
			me.secondScreen		= true;
			if ismac; me.operatorScreen.useRetina = true; end

			me.smoothing.sampleRate = me.sampleRate;
			
			if me.isDummy
				me.salutation('Initialise', 'Running Pupil Labs in Dummy Mode', true);
				me.isConnected = false;
			else
				me.endpoint = ['tcp://' me.calibration.ip ':' num2str(me.calibration.port)];
				me.ctx = zmq.core.ctx_new();
				me.socket = zmq.core.socket(me.ctx, 'ZMQ_REQ');
				zmq.core.setsockopt(me.socket, 'ZMQ_RCVTIMEO', me.calibration.timeout);
				fprintf('--->>> pupilLabsManager: Connecting to %s\n', me.endpoint);
				err = zmq.core.connect(me.socket, me.endpoint);
				if err == -1
					warning('Cannot Connect to Pupil Core!!!');
					close(me);
					me.isDummy = true;
					me.isConnected = false;
				else
					subscribe(me);
					checkRoundTrip(me);
					SetPupilTime(me);
					me.isConnected = true;
				end
			end

			if me.useLEDs
				if ~rM.isOpen; open(rM); end
				try
					for i = 1:length(me.calibration.calPositions)
						me.turnOnLED(i, rM);
						WaitSecs(0.02);
					end
					for i = 1:length(me.calibration.calPositions)
						me.turnOffLED(i, rM);
						WaitSecs(0.02);
					end
				end
			end
			success = true;
		end


		% ===================================================================
		function cal = trackerSetup(me,varargin)
		%> @fn trackerSetup(me, varargin)
		%> @brief calibration + validation
		%>
		% ===================================================================
            [rM, aM] = initialiseGlobals(me);

			cal = [];
			if ~me.isConnected && ~me.isDummy
				warning('Eyetracker not connected, cannot calibrate!');
				return
			end

			if ~isempty(me.screen) && isa(me.screen,'screenManager'); open(me.screen); end
			if me.useOperatorScreen && isa(me.operatorScreen,'screenManager'); open(me.operatorScreen); end
			s = me.screen;
			if me.useOperatorScreen; s2 = me.operatorScreen; end
			me.win = me.screen.win;
			me.ppd_ = me.screen.ppd;

			if ischar(me.calibration.calPositions); me.calibration.calPositions = str2num(me.calibration.calPositions); end
			if ischar(me.calibration.valPositions); me.calibration.valPositions = str2num(me.calibration.valPositions); end

			fprintf('\n===>>> CALIBRATING PUPIL CORE... <<<===\n');
			
			if strcmp(me.calibration.stimulus,'movie')
				if isempty(me.stimulus.movie) || ~isa(me.stimulus.movie,'movieStimulus')
					me.calStim = movieStimulus('size',me.calibration.size);
				else
					if ~isempty(me.calStim); try me.calStim.reset; end; end
					me.calStim = me.movie.movie;
					me.calStim.size = me.calibration.size;
				end
			else
				if ~isempty(me.calStim); try me.calStim.reset; end; end
				me.calStim = fixationCrossStimulus('size',me.calibration.size,'lineWidth',me.calibration.size/8,'type','pulse');
			end

			f = me.calStim;

			if true; return; end

			hide(f);
			setup(f, me.screen);

			startRecording(me);
			
			KbName('UnifyKeyNames');
			one = KbName('1!'); two = KbName('2@'); three = KbName('3#');
			four = KbName('4$'); five = KbName('5%'); six = KbName('6^');
			seven = KbName('7&'); eight = KbName('8*'); nine = KbName('9(');
			zero = KbName('0)'); esc = KbName('escape'); cal = KbName('c');
			val = KbName('v'); dr = KbName('d'); menu = KbName('LeftShift');
			sample = KbName('RightShift'); shot = KbName('F1');
			oldr = RestrictKeysForKbCheck([one two three four five six seven ...
				eight nine zero esc cal val dr menu sample shot]);

			cpos = me.calibration.calPositions;
			vpos = me.calibration.valPositions;
			
			me.validationData = struct();
			me.validationData(1).collected = false;
			me.validationData(1).vpos = vpos;
			me.validationData(1).time = datetime('now');
			me.validationData(1).data = cell(size(vpos,1),1);
			me.validationData(1).dataS = me.validationData(1).data;
			
			loop = true;
			ref = s.screenVals.fps;
			a = -1;
			mode = 'menu';
			
			while loop
				
				switch mode

					case 'menu'
						cloop = true;
						resetAll(me);
						while cloop
							a = a + 1;
							me.getSample();
							s.drawText('MENU: esc = exit | c = calibrate | v = validate | d = drift offset | F1 = screenshot');
							s.flip();
							if me.useOperatorScreen
								s2.drawText('MENU: esc = exit | c = calibrate | v = validate | d = drift offset | F1 = screenshot');
								if ~isempty(me.x);s2.drawSpot(0.75,[0 1 0.25 0.2],me.x,me.y);end
								drawValidationResults(me);
								if mod(a,ref) == 0
									trackerFlip(me,0,true);
								else
									trackerFlip(me,1);
								end
							end

							[pressed,~,keys] = optickaCore.getKeys();
							if pressed
								if keys(esc)
									cloop = false; loop = false;
								elseif keys(cal)
									mode = 'calibrate'; cloop = false;
								elseif keys(val)
									mode = 'validate'; cloop = false;
								elseif keys(dr)
									mode = 'driftoffset'; cloop = false;
								elseif keys(shot)
									filename=[me.paths.parent filesep me.name '_' datestr(now,'YYYY-mm-DD-HH-MM-SS') '.png'];
									captureScreen(s2, filename);
								end
							end
						end

					case 'driftoffset'
						trackerFlip(me,0,true);
						oldrr = RestrictKeysForKbCheck([]);
						driftOffset(me);
						RestrictKeysForKbCheck(oldrr);
						mode = 'menu';
						WaitSecs(0.5);

					case 'calibrate'
						cloop = true;
						thisX = 0;
						thisY = 0;
						lastK = 0;
						thisPos = 1;

						me.validationData = struct();
						me.validationData(1).collected = false;

						f.xPositionOut = cpos(thisPos,1);
						f.yPositionOut = cpos(thisPos,2);
						update(f);
						nPositions = size(cpos,1);
						resetAll(me);
						while cloop
							a = a + 1;
							me.getSample();
							drawGrid(s);
							draw(f);
							animate(f);
							flip(s);
							if me.useOperatorScreen
								s2.drawText ('CALIBRATE: lshift = exit | # = point');
								s2.drawCross(1,[],thisX,thisY);
								if ~isempty(me.x);s2.drawSpot(0.75,[0 1 0.25 0.1],me.x,me.y);end
								if mod(a,ref) == 0
									trackerFlip(me,0,true);
								else
									trackerFlip(me,1);
								end
							end

							[pressed,name,keys] = optickaCore.getKeys();
							if pressed
								fprintf('key: %s\n',name);
								if length(name)==2 % assume a number
									k = str2double(name(1));
									if k == 0 
										hide(f);
										for ii=1:length(cpos);me.turnOffLED(ii,rM);end
										trackerFlip(me,0,true);
									elseif k > 0 && k <= nPositions
										thisPos = k;
										if k == lastK && f.isVisible
											f.isVisible = false;
											me.turnOffLED(k,rM);
											thisPos = 0;
										elseif ~f.isVisible
											f.isVisible = true;
											me.turnOnLED(k,rM);
										end
										lastK = k;
										if thisPos > 0
											thisX = vpos(thisPos,1);
											thisY = vpos(thisPos,2);
											f.xPositionOut = thisX;
											f.yPositionOut = thisY;
											update(f);
										end
										trackerFlip(me,0,true);
									end
								elseif keys(sample)
									hide(f);
									for ii=1:length(cpos);me.turnOffLED(ii,rM);end
									trackerFlip(me,0,true);
									rM.timedTTL;
								elseif keys(menu)
									trackerFlip(me,0,true);
									mode = 'menu'; cloop = false;
								elseif keys(val)
									mode = 'validate'; cloop = false;
								end
							end
						end

					case 'validate'
						cloop = true;
						thisPos = 1; lastK = thisPos;
						thisX = vpos(thisPos,1);
						thisY = vpos(thisPos,2);
						f.xPositionOut = thisX;
						f.yPositionOut = thisY;
						update(f);

						if me.validationData(end).collected == false
							me.validationData(end).collected = true;
						else
							me.validationData(end+1).collected = true;
						end
						me.validationData(end).vpos = vpos;
						me.validationData(end).time = datetime('now');
						me.validationData(end).data = cell(size(vpos,1),1);
						me.validationData(end).dataS = cell(size(vpos,1),1);

						resetFixationHistory(me);
						nPositions = size(vpos,1);
						while cloop
							a = a + 1;
							me.getSample();
							drawGrid(s);
							draw(f);
							animate(f);
							flip(s);
							if me.useOperatorScreen
								s2.drawText('VALIDATE: lshift = exit | rshift = sample | # = point');
								if ~isempty(me.x); s2.drawSpot(0.75,[0 1 0.25 0.25],me.x,me.y); end
								drawValidationResults(me);
								if mod(a,ref) == 0
									trackerFlip(me,0,true);
								else
									trackerFlip(me,1);
								end
							end

							[pressed,name,keys] = optickaCore.getKeys();
							if pressed
								fprintf('key: %s\n',name);
								if length(name)==2 % assume a number
									k = str2double(name(1));
									if k == 0
										resetFixationHistory(me);
										thisPos = 0;
										hide(f);
										for ii=1:length(cpos);me.turnOffLED(ii,rM);end
										trackerFlip(me,0,true);
									elseif k > 0 && k <= nPositions
										thisPos = k;
										if k == lastK && f.isVisible
											f.isVisible = false;
											me.turnOffLED(k,rM);
											thisPos = 0;
										elseif ~f.isVisible
											f.isVisible = true;
											me.turnOnLED(k,rM);
										end
										lastK = k;
										if thisPos > 0
											thisX = vpos(thisPos,1);
											thisY = vpos(thisPos,2);
											f.xPositionOut = thisX;
											f.yPositionOut = thisY;
											update(f);
										end
										trackerFlip(me,0,true);
									end
								elseif keys(sample)
									if ~isempty(me.xAllRaw)
										ld = length(me.xAllRaw);
										sd = ld - me.rawSamples;
										if sd < 1; sd = 1; end
										me.validationData(end).data{lastK} = [me.xAllRaw(sd:ld); me.yAllRaw(sd:ld)];
										l=length(me.xAll);
										if l > 5; l = 5; end
										me.validationData(end).dataS{lastK} = [me.xAll(end-l:end); me.yAll(end-l:end)];
									end
									rM.giveReward;
									f.isVisible = false;
									for ii=1:length(cpos);me.turnOffLED(ii,rM);end
									thisPos = 0;
									resetFixationHistory(me);
									trackerFlip(me,0,true);
								elseif keys(menu)
									mode = 'menu'; cloop = false;
								end
							end
						end
				end
			end
			s.drawText('Calibration finished...');
			s2.drawText('Calibration finished...')
			s.flip(); s2.flip(); s2.drawBackground; s2.flip();
			reset(f);
			resetAll(me);
			RestrictKeysForKbCheck(oldr);
			stopRecording(me);
			WaitSecs(0.25);
			fprintf('===>>> CALIBRATING CORE FINISHED... <<<===\n');
		end

		% ===================================================================
		function startRecording(me, ~)
		%> @fn startRecording(me,~)
		%> @brief startRecording - for iRec this just starts TCP online
		%> access, all data is saved to CSV irrespective of this
		%>
		% ===================================================================
			if me.isDummy; return; end
			if me.isConnected 
				zmq.core.send(me.socket, uint8('R'));
				result = zmq.core.recv(me.socket);
				fprintf('Recording should start: %s\n', char(result));
				me.isRecording = true;
			end
		end
		
		% ===================================================================
		function stopRecording(me, ~)
		%> @fn stopRecording(me,~)
		%> @brief stopRecording - for iRec this just stops TCP online
		%> access, all data is saved to CSV irrespective of this
		%>
		% ===================================================================
			if me.isDummy; return; end
			if me.isConnected 
				zmq.core.send(me.socket, uint8('R'));
				result = zmq.core.recv(me.socket);
				fprintf('Recording stopped: %s\n', char(result));
				me.isRecording = false;
			end
		end
		
		% ===================================================================
		function sample = getSample(me)
		%> @fn getSample()
		%> @brief get latest sample from the tracker, if dummymode=true then use
		%> the mouse as an eye signal
		%>
		% ===================================================================
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
				sample.time		= GetSecs;
				me.x			= me.toDegrees(sample.gx,'x');
				me.y			= me.toDegrees(sample.gy,'y');
				me.xAll			= [me.xAll me.x];
				me.xAllRaw		= me.xAll;
				me.yAll			= [me.yAll me.y];
				me.yAllRaw		= me.yAll;
				me.pupilAll		= [me.pupilAll me.pupil];
				%if me.verbose;fprintf('>>X: %.2f | Y: %.2f | P: %.2f\n',me.x,me.y,me.pupil);end
			elseif me.isConnected && me.isRecording
				xy				= [];
				td				= me.tcp.readLines(me.smoothing.nSamples,'last');
				if isempty(td); me.currentSample=sample; return; end
				td				= str2num(td); %#ok<*ST2NM> 
				sample.raw		= td;
				sample.time		= td(end,1);
				sample.timeD	= GetSecs;
				xy(1,:)			=  td(:,2)';
				xy(2,:)			= -td(:,3)';
				if ~isempty(xy)
					me.xAllRaw	= [me.xAllRaw xy(1,:)];
					me.yAllRaw	= [me.yAllRaw xy(2,:)];
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
				me.x = []; me.y = []; me.pupil = []; 
				if me.verbose;fprintf('-+-+-> pupilCore.getSample(): are you sure you are recording?\n');end
			end
			me.currentSample	= sample;
		end
		
		% ===================================================================
		function trackerMessage(me, message, ~)
		%> @fn trackerMessage(me, message)
		%> @brief Send message to store in tracker data, for iRec this can
		%> only be a single 32bit signed integer.
		%>
		%> As we do send strings to eyelink / tobii, we process string messages
		%> TRIALID and TRIALRESULT we extract the integer value, END_FIX becomes
		%> -1500 and END_RT becomes -1501
		% ===================================================================
			
			if me.verbose; fprintf('-+-+->pupilCore: %i\n', message);end
			
		end

		% ===================================================================
		function close(me)
		%> @fn close(me)
		%> @brief close the iRec and cleanup, call after experiment finishes
		%>
		% ===================================================================
			try 
				try stopRecording(me); end
				try unsubscribe(me); end
				try zmq.core.disconnect(me.socket, me.endpoint); end
				try zmq.core.close(me.socket); end
				try zmq.core.ctx_shutdown(me.ctx); end
				try zmq.core.ctx_term(me.ctx); end

				me.socket = [];
				me.sub = []; me.pub = [];
				me.subEndpoint = []; me.pubEndpoint = [];
				me.ctx = [];

				me.isConnected = false;
				me.isRecording = false;
				resetAll(me);
				if ~isempty(me.operatorScreen) && isa(me.operatorScreen,'screenManager')
					try close(me.operatorScreen); end
				end
			catch ME
				me.salutation('Close Method','Couldn''t stop recording, forcing shutdown...',true)
				me.isConnected = false;
				me.isRecording = false;
				try stopRecording(me); end
				try unsubscribe(me); end
				try zmq.core.disconnect(me.socket, me.endpoint); end
				try zmq.core.close(me.socket); end
				try zmq.core.ctx_shutdown(me.ctx); end
				try zmq.core.ctx_term(me.ctx); end
				try resetAll(me); end
				if me.secondScreen && ~isempty(me.operatorScreen) && isa(me.operatorScreen,'screenManager')
					try me.operatorScreen.close; end
				end
				getReport(ME);
			end
		end
		
		% ===================================================================
		function runDemo(me, forcescreen)
		%> @fn runDemo(me, forceScreen)
		%> @brief runs a demo of this class, useful for testing
		%>
		%> @param forcescreen forces to use a specific screen number
		% ===================================================================
			KbName('UnifyKeyNames')
			stopkey				= KbName('q');
			upKey				= KbName('uparrow');
			downKey				= KbName('downarrow');
			leftKey				= KbName('leftarrow');
			rightKey			= KbName('rightarrow');
			calibkey			= KbName('c');
			driftkey			= KbName('d');
			ofixation			= me.fixation; 
			osmoothing			= me.smoothing;
			oldexc				= me.exclusionZone;
			oldfixinit			= me.fixInit;
			oldname				= me.name;
			me.name				= 'pupilLabs-runDemo';
			try
				if ~me.isConnected; initialise(me);end
				s = me.screen; s2 = me.operatorScreen;
				s.font.FontName = me.monoFont;
				if exist('forcescreen','var'); close(s); s.screen = forcescreen; end
				s.disableSyncTests = true; s2.disableSyncTests = true;
				if ~s.isOpen; open(s); end
				if me.useOperatorScreen && ~s2.isOpen; s2.open(); end
				sv = s.screenVals;
				
				trackerSetup(me);

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

				methodl={'median','heuristic1','heuristic2','sg','simple'};
				eyel={'both','left','right'};
				m = 1; n = 1;
				trialn = 1;
				maxTrials = 5;
				endExp = false;
				
				% set up an exclusion zone where eye is not allowed
				me.exclusionZone = [8 10 8 10];
				exc = me.toPixels(me.exclusionZone);
				exc = [exc(1) exc(3) exc(2) exc(4)]; %psychrect=[left,top,right,bottom] 

				startRecording(me);
				WaitSecs('YieldSecs',0.5);
				
				trackerMessage(me,0)
				while trialn <= maxTrials && ~endExp 
					trialtick = 1;
					drawPhotoDiodeSquare(s,[0 0 0 1]);
					trackerDrawStatus(me,'Start Trial');
					resetFixation(me);
					vbl = flip(s); tstart = vbl + sv.ifi;
					trackerMessage(me, trialn);
					while vbl < tstart + 6
						Screen('FillRect', s.win, [0.7 0.7 0.7 0.5],exc); Screen('DrawText',s.win,'Exclusion Zone',exc(1),exc(2),[0.8 0.8 0.8]);
						drawGrid(s); draw(o); draw(f);
						drawCross(s, 0.5, [1 1 0], me.fixation.X, me.fixation.Y);
						drawPhotoDiodeSquare(s, [1 1 1 1]);
						
						getSample(me); isFixated(me);
						
						if ~isempty(me.currentSample)
							txt = sprintf('Q = finish. X: %3.1f / %2.2f | Y: %3.1f / %2.2f | # = %2i %s %s | RADIUS = %s | TIME = %.2f | FIXATION = %.2f | EXC = %i | INIT FAIL = %i',...
								me.currentSample.gx, me.x, me.currentSample.gy, me.y, me.smoothing.nSamples,...
								me.smoothing.method, me.smoothing.eyes, sprintf('%1.1f ',me.fixation.radius), ...
								me.fixTotal,me.fixLength,me.isExclusion,me.isInitFail);
							Screen('DrawText', s.win, txt, 10, 10,[1 1 1]);
							if ~me.useOperatorScreen;drawEyePosition(me,true);end
						end
						animate(o);

						if me.useOperatorScreen
							trackerDrawExclusion(me);
							trackerDrawFixation(me);
							trackerDrawEyePosition(me);
						end
						
						vbl(end+1) = Screen('Flip', s.win, vbl(end) + s.screenVals.halfifi);
						if me.useOperatorScreen; trackerFlip(me); end

						[keyDown, ~, keyCode] = optickaCore.getKeys();
						if keyDown
							if keyCode(stopkey); endExp = true; break;
							elseif keyCode(calibkey); me.trackerSetup;
							elseif keyCode(upKey); me.smoothing.nSamples = me.smoothing.nSamples + 1; if me.smoothing.nSamples > 400; me.smoothing.nSamples=400;end
							elseif keyCode(downKey); me.smoothing.nSamples = me.smoothing.nSamples - 1; if me.smoothing.nSamples < 1; me.smoothing.nSamples=1;end
							elseif keyCode(leftKey); m=m+1; if m>5;m=1;end; me.smoothing.method = methodl{m};
							end
						end

						trialtick=trialtick+1;
					end
					if endExp == false
						drawPhotoDiodeSquare(s,[0 0 0 1]);
						vbl = flip(s);
						trackerMessage(me,-1);
		
						if me.useOperatorScreen; trackerDrawStatus(me,'Finished Trial'); end
					
						resetAll(me);

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
						WaitSecs(0.5);
						trialn = trialn + 1;
					else
						drawPhotoDiodeSquare(s,[0 0 0 1]);
						vbl = flip(s);
						trackerMessage(me,-100);
					end
				end
				WaitSecs(0.5);
				stopRecording(me);
				ListenChar(0); Priority(0); ShowCursor;
				try close(s); close(s2); reset(o); reset(f); end %#ok<*TRYNC>
				close(me);
				me.fixation = ofixation;
				me.smoothing = osmoothing;
				me.exclusionZone = oldexc;
				me.fixInit = oldfixinit;
				me.name = oldname;
				clear s s2 o
			catch ME
				stopRecording(me);
				me.fixation = ofixation;
				me.smoothing = osmoothing;
				me.exclusionZone = oldexc;
				me.fixInit = oldfixinit;
				me.name = oldname;
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
		
	end%-------------------------END PUBLIC METHODS--------------------------------%
	
	%============================================================================
	methods (Hidden = true) %--HIDDEN METHODS (compatibility with eyelinkManager)
	%============================================================================
		
		function result = remoteCommand(me, cmd)
			if ~me.isConnected; result = []; return; end
			zmq.core.send(me.socket, uint8(cmd));
			result = zmq.core.recv(me.socket);
			fprintf('--->>> setPupilTime: %s\n', char(result));
		end

		function checkRoundTrip(me)
			tt=tic; % Measure round trip delay
			result = remoteCommand('t');
			tx=toc(tt);
			fprintf('--->>> Round trip command delay: %.2f\n', str2num(tx*1000));
			fprintf('--->>> Returned: %s\n', char(result));
		end

		function SetPupilTime(me)
			result = remoteCommand(me,'T 0.0');
			fprintf('--->>> setPupilTime: %s\n', char(result));
		end

		% ===================================================================
		%> @brief Sync time with tracker
		%>
		% ===================================================================
		function syncTrackerTime(varargin)
			
		end

		% ===================================================================
		%> @brief Save the data
		%>
		% ===================================================================
		function saveData(varargin)
			
		end
		% ===================================================================
		%> @brief
		%>
		% ===================================================================
		function updateDefaults(varargin)
			
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
				if me.verbose; fprintf('-+-+->iRec status message: %s\n',message);end
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
			initialise(me)
		end
		
		% ===================================================================
		%> @brief set into offline / idle mode
		%>
		% ===================================================================
		function setOffline(me)
			
		end

		% ===================================================================
		%> @brief check the connection with the tobii
		%>
		% ===================================================================
		function connected = checkConnection(me)
			connected = me.isConnected;
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
			mode = 0;
		end
		
		% ===================================================================
		%> @brief Sync time with tracker: send int32(-1000)
		%>
		% ===================================================================
		function syncTime(me)
			
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
			trackertime = 0;
			systemtime = 0;
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
		
	end%-------------------------END HIDDEN METHODS--------------------------------%
	
	%=======================================================================
	methods (Access = private) %------------------PRIVATE METHODS
	%=======================================================================
		
		function subscribe(me)
			if ~me.isConnected; return; end
			subPort = remoteCommand(me,'SUB_PORT');
			pubPort = = remoteCommand(me,'PUB_PORT');
			me.subEndpoint = ['tcp://' me.calibration.ip ':' subPort];
			me.pubEndpoint = ['tcp://' me.calibration.ip ':' pubPort];
			fprintf('--->>> Received sub/pub port: %s/s\n', subPort, pubPort);
			me.sub = zmq.core.socket(me.ctx, 'ZMQ_SUB');
			me.pub = zmq.core.socket(me.ctx, 'ZMQ_PUB');
			zmq.core.setsockopt(me.sub, 'ZMQ_RCVTIMEO', me.calibration.timeout);
			zmq.core.setsockopt(me.pub, 'ZMQ_RCVTIMEO', me.calibration.timeout);
			
			err = zmq.core.connect(me.sub, me.subEndpoint);
			assert(err==0,'--->>> PupilLabs: Cannot subscribe to data stream!');

			zmq.core.setsockopt(me.sub, 'ZMQ_SUBSCRIBE', 'pupil.');
			zmq.core.setsockopt(me.sub, 'ZMQ_SUBSCRIBE', 'gaze.');
			zmq.core.setsockopt(me.sub, 'ZMQ_SUBSCRIBE', 'notify.');

			err = zmq.core.connect(me.pub, me.pubEndpoint);
			assert(err==0,'--->>> PupilLabs: Cannot subscribe to Publish stream!');
		end


		function unsubscribe(me)
			try
				zmq.core.disconnect(me.sub, me.subEndpoint);
				zmq.core.close(me.sub);
				fprintf('--->>> PupilLabs: Disconnected from SUB: %s\n', me.subEndpoint);
			end
			try
				zmq.core.disconnect(me.pub, me.pubEndpoint);
				zmq.core.close(me.psub);
				fprintf('--->>> PupilLabs: Disconnected from PUB: %s\n', me.pubEndpoint);
			end
		end

		function [topic, payload] = receiveMessage(me)
			% Use socket to receive topics and their messages
			% Messages are 2-frame zmq messages that include the topic
			% and the message payload as a msgpack encoded string.
			topic = []; payload = [];
			topic = char(zmq.core.recv(me.sub), 255, 'ZMQ_DONTWAIT');
			lastwarn('');  % reset last warning
			payload = zmq.core.recv(me.sub, 1024, 'ZMQ_DONTWAIT');  % receive payload
			[~, warnId] = lastwarn;  % fetch possible buffer length warning
			if isequal(warnId, 'zmq:core:recv:bufferTooSmall')
    			payload = false;  % set payload to false since it is incomplete
				disp('Buffer too small');
			else
    			payload = parsemsgpack(payload);  % parse payload
			end
		end

		function [ ] = sendNotification(me, notification )
			%NOTIFY Use socket to send notification
			%   Notifications are container.Map objects that contain
			%   at least the key 'subject'.
			topic = strcat('notify.', notification('subject'));
			payload = dumpmsgpack(notification);
			zmq.core.send(me.pub, uint8(topic), 'ZMQ_SNDMORE');
			zmq.core.send(me.pub, payload);
		end

		function msgs = flushBuffer(me)
			topic
		end

		function turnOnLED(me, val, rM)
			if me.useLEDs
				rM.digitalWrite(val-1 + me.startPin,1);
			end
		end

		function turnOffLED(me, val, rM)
			if me.useLEDs
				rM.digitalWrite(val-1 + me.startPin,0);
			end
		end
		
	end %------------------END PRIVATE METHODS
end

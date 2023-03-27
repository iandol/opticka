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
						'stimulus','animated','calPositions',[-12 0; 0 -12; 0 0; 0 12; 12 0],...
						'valPositions',[-12 0; 0 -12; 0 0; 0 12; 12 0],...
						'size',2,'manual', false, 'movie', [])
		%> options for online smoothing of peeked data {'median','heuristic','savitsky-golay'}
		smoothing		= struct('nSamples',8,'method','median','window',3,...
						'eyes','both')
		%> we can optionally drive physical LEDs for calibration, each LED
		%> is triggered by the me.calibration.calPositions order
		useLEDs			= false
	end
	
	properties (SetAccess = protected, GetAccess = public, Dependent = true)
		% calculates the smoothing in ms
		smoothingTime double
	end
	
	properties (SetAccess = protected, GetAccess = protected)
		sv					= []
		fInc				= 8
		%> tracker time stamp
		systemTime			= 0
		calibData
		calStim
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
			args = optickaCore.addDefaults(varargin,struct('name','iRec',...
				'useOperatorScreen',true,'sampleRate',500));
			me=me@eyetrackerCore(args); %we call the superclass constructor first
			me.parseArgs(args, me.allowedProperties);
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
					me.screen		= screenManager;
				end
			elseif isa(me.screen,'screenManager') || ~strcmp(me.screen.uuid, sM.uuid)
					me.screen			= sM;
			end
			me.ppd_					= me.screen.ppd;
			if me.screen.isOpen
				me.win				= me.screen.win;
			end
			if me.screen.screen > 0
				oscreen = me.screen.screen - 1;
			else
				oscreen = 0;
			end
			if me.useOperatorScreen && exist('sM2','var')
				if isempty(me.operatorScreen) || (isa(me.operatorScreen,'screenManager') && ~strcmp(me.operatorScreen.uuid,sM2.uuid))
					me.operatorScreen = sM2;
				end
				me.secondScreen		= true;
				if ismac; me.operatorScreen.useRetina = true; end
			elseif me.useOperatorScreen && isempty(me.operatorScreen)
				me.operatorScreen = screenManager('pixelsPerCm',20,...
					'disableSyncTests',true,'backgroundColour',me.screen.backgroundColour,...
					'screen', oscreen, 'specialFlags', kPsychGUIWindow);
				[w,h]			= Screen('WindowSize',me.operatorScreen.screen);
				me.operatorScreen.windowed	= [0 0 round(w/2) round(h/2)];
				me.secondScreen		= true;
				if ismac; me.operatorScreen.useRetina = true; end
			end
			
			if me.isDummy
				me.salutation('Initialise', 'Running iRecH2 in Dummy Mode', true);
				me.isConnected = false;
			else
				if isempty(me.tcp) || ~isa(me.tcp,'dataConnection')
					me.tcp = dataConnection('rAddress', me.calibration.ip,'rPort',...
					me.calibration.tcpport,'protocol','tcp');
				else
					me.tcp.close();
					me.tcp.rAddress = me.calibration.ip;
					me.tcp.rPort = me.calibration.tcpport;
				end
				if isempty(me.udp) || ~isa(me.udp,'dataConnection')
					me.udp = dataConnection('rAddress', me.calibration.ip,'rPort',...
					me.calibration.udpport,'protocol','udp');
				else 
					me.udp.close();
					me.udp.rAddress = me.calibration.ip;
					me.udp.rPort = me.calibration.udpport;
				end
				try 
					open(me.tcp);
					if ~me.tcp.isOpen; warning('Cannot Connect to TCP');error('Cannot connect to TCP'); end
					open(me.udp);
					me.udp.write(intmax('int32'));
					me.isConnected = true;
					me.salutation('Initialise', ...
						sprintf('Running on a iRecH2 | Screen %i %i x %i @ %iHz', ...
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
		function cal = trackerSetup(me,varargin)
			cal = [];
			if ~me.isConnected && ~me.isDummy
				warning('Eyetracker not connected, cannot calibrate!');
				return
			end

			if ~isempty(me.screen) && isa(me.screen,'screenManager'); open(me.screen); end
			if me.useOperatorScreen && isa(me.operatorScreen,'screenManager'); open(me.operatorScreen); end
			s = me.screen;
			if me.useOperatorScreen; s2 = me.operatorScreen; end
			me.fInc = round(s.screenVals.fps/6);
			me.win = me.screen.win;
			me.ppd_ = me.screen.ppd;

			fprintf('\n===>>> CALIBRATING IREC... <<<===\n');
			
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

			hide(f);
			setup(f, me.screen);

			startRecording(me);
			
			KbName('UnifyKeyNames');
			one = KbName('1!'); two = KbName('2@'); three = KbName('3#');
			four = KbName('4$'); five = KbName('5%'); six = KbName('6^');
			seven = KbName('7&'); eight = KbName('8*'); nine = KbName('9(');
			zero = KbName('0)'); esc = KbName('escape'); cal = KbName('c');
			val = KbName('v'); dr = KbName('d'); menu = KbName('LeftShift');
			sample = KbName('RightShift');
			oldr = RestrictKeysForKbCheck([one two three four five six seven ...
				eight nine zero esc cal val dr menu sample]);

			cpos = me.calibration.calPositions;
			vpos = me.calibration.valPositions;
			vdata = cell(size(vpos,1),1);

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
							s.drawText('MENU: esc = exit | c = calibrate | v = validate | d = drift offset');
							s.flip();
							if me.useOperatorScreen
								s2.drawText ('MENU: esc = exit | c = calibrate | v = validate | d = drift offset');
								if ~isempty(me.x);s2.drawSpot(0.75,[0 1 0.25 0.2],me.x,me.y);end
								for j = 1:length(vdata)
									s2.drawCross(1,[],vpos(j,1),vpos(j,2));
									if ~isempty(vdata{j}) && size(vdata{j},1)==2
										try drawDotsDegs(s2,vdata{j},0.3,[1 0.5 0 0.25]); end
									end
								end
								if mod(a,ref) == 0
									trackerFlip(me,0,true);
								else
									trackerFlip(me,1);
								end
							end

							[pressed,~,keys] = getKeys(me);
							if pressed
								if keys(esc)
									cloop = false; loop = false; break;
								elseif keys(cal)
									mode = 'calibrate'; cloop = false; break;
								elseif keys(val)
									mode = 'validate'; cloop = false; break;
								elseif keys(dr)
									mode = 'driftoffset'; cloop = false; break;
								end
							end
						end

					case 'driftoffset'
						trackerFlip(me,0,true);
						oldrr = RestrictKeysForKbCheck([]);
						me.driftOffset();
						RestrictKeysForKbCheck(oldrr);
						WaitSecs(0.5);

					case 'calibrate'
						cloop = true;
						thisX = 0;
						thisY = 0;
						lastK = 0;
						thisPos = 1;
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

							[pressed,name,keys] = getKeys(me);
							if pressed
								fprintf('key: %s\n',name);
								if length(name)==2 % assume a number
									k = str2double(name(1));
									if k == 0 
										hide(f);
										trackerFlip(me,0,true);
									elseif k > 0 && k <= nPositions
										thisPos = k;
										if k == lastK && f.isVisible
											f.isVisible = false;
											thisPos = 0;
										elseif ~f.isVisible
											f.isVisible = true;
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
								elseif keys(menu)
									trackerFlip(me,0,true);
									mode = 'menu'; cloop = false;
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
						vdata = cell(size(vpos,1),1);
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
								for j = 1:nPositions
									s2.drawCross(1,[],vpos(j,1),vpos(j,2));
									if ~isempty(vdata{j}) && size(vdata{j},1)==2
										try drawDotsDegs(s2,vdata{j},0.3,[1 0.5 0 0.25]); end
									end
								end
								if mod(a,ref) == 0
									trackerFlip(me,0,true);
								else
									trackerFlip(me,1);
								end
							end

							[pressed,name,keys] = getKeys(me);
							if pressed
								fprintf('key: %s\n',name);
								if length(name)==2 % assume a number
									k = str2double(name(1));
									if k == 0
										resetFixationHistory(me);
										thisPos = 0;
										hide(f);
										trackerFlip(me,0,true);
									elseif k > 0 && k <= nPositions
										thisPos = k;
										if k == lastK && f.isVisible
											f.isVisible = false;
											thisPos = 0;
										elseif ~f.isVisible
											f.isVisible = true;
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
									if length(me.xAll) > 20 && lastK > 0 && lastK <= length(vdata)
										 vdata{lastK} = [me.xAll(end-19:end); me.yAll(end-19:end)];
									elseif ~isempty(me.xAll) && lastK > 0 && lastK <= length(vdata)
										vdata{lastK} = [me.xAll; me.yAll];
									end
									f.isVisible = false;
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
			fprintf('===>>> CALIBRATING IREC FINISHED... <<<===\n');
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
				me.x = []; me.y = []; me.pupil = []; 
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
				try me.tcp.close; end
				try me.udp.close; end
				me.isConnected = false;
				me.isRecording = false;
				resetAll(me);
				if me.secondScreen && ~isempty(me.operatorScreen) && isa(me.operatorScreen,'screenManager')
					try close(me.operatorScreen); end
				end
			catch ME
				me.salutation('Close Method','Couldn''t stop recording, forcing shutdown...',true)
				me.isConnected = false;
				me.isRecording = false;
				try me.tcp.close; end
				try me.udp.close; end
				try resetAll(me); end
				if me.secondScreen && ~isempty(me.operatorScreen) && isa(me.operatorScreen,'screenManager')
					try me.operatorScreen.close; end
				end
				getReport(ME);
			end
		end
		
		% ===================================================================
		%> @brief runs a demo of the workflow, testing this class
		%>
		% ===================================================================
		function runDemo(me, forcescreen)
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
			try
				if ~me.isConnected; initialise(me);end
				s = me.screen; s2 = me.operatorScreen;
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
					trackerFlip(me,0,true);
					resetAll(me);
					vbl = flip(s); tstart=vbl+sv.ifi;
					trackerMessage(me,trialn);
					while vbl < tstart + 6
						Screen('FillRect',s.win,[0.7 0.7 0.7 0.5],exc); Screen('DrawText',s.win,'Exclusion Zone',exc(1),exc(2),[0.8 0.8 0.8]);
						drawGrid(s); draw(o); draw(f);
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
						animate(o);

						if me.useOperatorScreen
							drawGrid(s2);
							trackerDrawExclusion(me);
							trackerDrawFixation(me);
							trackerDrawEyePosition(me);
						end
						
						vbl(end+1) = Screen('Flip', s.win, vbl(end) + s.screenVals.halfifi);
						if me.useOperatorScreen; trackerFlip(me,0,true); end

						[keyDown, ~, keyCode] = KbCheck(-1);
						if keyDown
							if keyCode(stopkey); endExp = true; break;
							elseif keyCode(calibkey); me.doCalibration;
							elseif keyCode(upKey); me.smoothing.nSamples = me.smoothing.nSamples + 1; if me.smoothing.nSamples > 400; me.smoothing.nSamples=400;end
							elseif keyCode(downKey); me.smoothing.nSamples = me.smoothing.nSamples - 1; if me.smoothing.nSamples < 1; me.smoothing.nSamples=1;end
							elseif keyCode(leftKey); m=m+1; if m>5;m=1;end; me.smoothing.method = methodl{m};
							end
						end

						trialtick=trialtick+1;
					end
					if endExp == 0
						drawPhotoDiodeSquare(s,[0 0 0 1]);
						vbl = flip(s);
						trackerMessage(me,-1);
		
						if me.useOperatorScreen; trackerDrawStatus(me,'Finished Trial'); trackerFlip(me,0,true); end
					
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
				clear s s2 o
			catch ME
				stopRecording(me);
				me.fixation = ofixation;
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
			if me.isDummy; return; end
			if me.tcp.isOpen; me.tcp.write(int8('start')); end
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
			if me.isDummy; return; end
			if me.tcp.isOpen; me.tcp.write(int8('stop')); end
			me.isRecording = false;
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
			initialise(me)
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
			trackerMessage(me,int32(-1000));
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
		%> @brief Get Key
		% ===================================================================
		function [pressed, name, keys] = getKeys(me)
			persistent keyTick keyTok
			if isempty(keyTick); keyTick = 0; keyTok = 0; end
			keyTick = keyTick + 1;
			if keyTick > keyTok
				[pressed, ~, keys] = KbCheck();
				name = KbName(keys);
				keyTok = keyTick + me.fInc;
			else
				pressed = false; name = []; keys = [];
			end
		end

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

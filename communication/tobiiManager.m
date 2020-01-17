% ========================================================================
%> @brief tobiiManager wraps around the Titta toolbox functions
%> offering a interface consistent with the previous eyelinkManager, offering
%> methods to check and change fixation windows gaze contingent tasks easily.
%>
% ========================================================================
classdef tobiiManager < optickaCore
	
	properties
		%> model of eyetracker, Spectrum Pro default
		model char = 'Tobii Pro Spectrum'
		%> tracker update speed (Hz) 
		%> Spectrum Pro: [60, 120, 150, 300, 600 or 1200]
		%> 4C: 90
		sampleRate double {mustBeMember(sampleRate,[60 90 120 150 300 600 1200])} = 600
		%> use human or macaque tracking mode
		trackingMode char {mustBeMember(trackingMode,{'human','macaque'})} = 'human'
		%> fixation window details
		fixation struct = struct('X',0,'Y',0,'Radius',1,'InitTime',1,...
			'Time',1,'strictFixation',true)
		%> options for online smoothing of peeked data {'median','heuristic','savitsky-golay'}
		smoothing struct = struct('nSamples',8,'method','median','window',3,...
			'eyes','both')
		%> type of calibration stimulus
		calibrationStimulus char = 'animated'
		%> main tobii (Titta) object
		tobii Titta
		%> the PTB screen to work on, passed in during initialise
		screen screenManager
		%> Titta settings
		settings struct = []
		%> name of eyetracker file
		saveFile char = 'tobiiData.mat'
		%> start eyetracker in dummy mode?
		isDummy logical = false
	end
	
	properties (Hidden = true)
		%> do we log messages to the command window?
		verbose = true
		%> stimulus positions to draw on screen
		stimulusPositions = []
		%> exclusion zone no eye movement allowed inside
		exclusionZone = []
		sampletime = []
		screen2 screenManager
	end
	
	properties (SetAccess = private, GetAccess = public, Dependent = true)
		% are we recording to matrix?
		isRecording logical
		% calculates the smoothing in ms
		smoothingTime double
	end
	
	properties (SetAccess = private, GetAccess = public)
		% are we connected to Tobii?
		isConnected logical = false
		%> data streamed out from the Tobii
		data struct = struct()
		%> calibration data
		calibration = []
		%> Last gaze X position in degrees
		x = []
		%> Last gaze Y position in degrees
		y = []
		%> pupil size
		pupil = []
		%current sample taken from tobii
		currentSample struct
		%current event taken from tobii
		currentEvent struct
		%> Initiate fixation length
		fixInitLength = 0
		%how long have we been fixated?
		fixLength = 0
		%> Initiate fixation time
		fixInitStartTime = 0
		%the first timestamp fixation was true
		fixStartTime = 0
		%> total time searching and holding fixation
		fixInitTotal = 0
		%> total time searching and holding fixation
		fixTotal = 0
		%> last time offset betweeen tracker and display computers
		currentOffset = 0
		%> tracker time stamp
		trackerTime = 0
		%> tracker time stamp
		systemTime = 0
		% which eye is the tracker using?
		eyeUsed char {mustBeMember(eyeUsed,{'both','left','right'})}= 'both'
	end
	
	properties (SetAccess = private, GetAccess = private)
		calStim
		secondScreen logical = false;
		%> currentSample template
		sampleTemplate struct = struct('raw',[],'time',NaN,'timeD',NaN,'gx',NaN,'gy',NaN,'pa',NaN)
		%> the PTB screen handle, normally set by screenManager but can force it to use another screen
		win = []
		ppd_ double = 36
		fixN double = 0
		fixSelection = []
		%> event N
		eventN = 1
		%> previous message sent to tobii
		previousMessage char = ''
		%> allowed properties passed to object upon construction
		allowedProperties char = 'model|IP|fixation|sampleRate|name|verbose|isDummy'
	end
	
	methods
		% ===================================================================
		%> @brief This is the constructor for this class
		%>
		% ===================================================================
		function me = tobiiManager(varargin)
			if nargin == 0; varargin.name = ''; end
			me=me@optickaCore(varargin); %superclass constructor
			if nargin>0
				me.parseArgs(varargin,me.allowedProperties);
			end
			try % is tobii working?
				assert(exist('Titta','class')==8,'TOBIIMANAGER:NO-TITTA','Cannot find Titta toolbox, please install instead of Tobii SDK; exiting...');
				initTracker(me);
				assert(isa(me.tobii,'Titta'),'TOBIIMANAGER:INIT-ERROR','Cannot Initialise...')
			catch ME
				ME.getReport
				fprintf('!!! Error initialising Tobii: %s\n\t going into Dummy mode...\n',ME.message);
				me.tobii = [];
				me.isDummy = true;
			end
			p = fileparts(me.saveFile);
			if isempty(p)
				me.saveFile = [me.paths.savedData filesep me.saveFile];
			end
		end
		
		% ===================================================================
		%> @brief initialise the tobii.
		%>
		%> @param sM - screenManager object we will use
		%> @param sM2 - a second screenManager used during calibration
		% ===================================================================
		function initialise(me,sM,sM2)
			if ~exist('sM','var') || isempty(sM)
				if isempty(me.screen) || ~isa(me.screen,'screenManager')
					me.screen		= screenManager();
				end
			else
				me.screen			= sM;
			end
			if ~exist('sM2','var') || ~isa(sM2,'screenManager')
				me.secondScreen		= false;
			else
				me.screen2			= sM2;
				me.secondScreen		= true;
			end
			if ~isa(me.tobii, 'Titta') || isempty(me.tobii); initTracker(me); end
			assert(isa(me.tobii,'Titta'),'TOBIIMANAGER:INIT-ERROR','Cannot Initialise...')
			
			if me.isDummy
				me.tobii			= me.tobii.setDummyMode();
			end
			
			me.settings						= Titta.getDefaults(me.model);
			me.settings.freq				= me.sampleRate;
			me.settings.trackingMode		= me.trackingMode;
			me.settings.cal.bgColor			= floor(me.screen.backgroundColour*255);
			me.settings.UI.setup.bgColor	= me.settings.cal.bgColor;
			if IsLinux
				me.settings.UI.setup.instruct.font		= 'Liberation Sans';
				me.settings.UI.button.setup.text.font	= 'Liberation Sans';
				me.settings.UI.button.val.text.font		= 'Liberation Sans';
				me.settings.UI.cal.errMsg.font			= 'Liberation Sans';
				me.settings.UI.val.waitMsg.font			= 'Liberation Sans';
				me.settings.UI.val.menu.text.font		= 'Liberation Sans';
				me.settings.UI.val.avg.text.font		= 'Liberation Mono';
				me.settings.UI.val.hover.text.font		= 'Liberation Mono';
				me.settings.UI.val.avg.text.color		= 200;
			end
			if strcmpi(me.calibrationStimulus,'animated')
				me.calStim							= AnimatedCalibrationDisplay();
				me.calStim.moveTime					= 0.75;
				me.calStim.oscillatePeriod			= 1;
				me.calStim.blinkCount				= 4;
				me.calStim.bgColor					= me.settings.cal.bgColor;
				me.calStim.fixBackColor             = 0;
				me.calStim.fixFrontColor			= 255;
				me.settings.cal.drawFunction    = @(a,b,c,d,e,f) me.calStim.doDraw(a,b,c,d,e,f);
			elseif strcmpi(me.calibrationStimulus,'movie')
				me.calStim							= tittaCalMovieStimulus();
				me.calStim.moveTime					= 0.75;
				me.calStim.oscillatePeriod			= 1;
				me.calStim.blinkCount				= 4;
				if isempty(me.screen.audio)
					me.screen.audio = audioManager();
				end
				m								= movieStimulus;
				m.mask							= [0 0 0];
				m.size							= 4;
				m.setup(me.screen);
				me.calStim.initialise(m); 
				me.settings.cal.drawFunction    = @(a,b,c,d,e,f) me.calStim.doDraw(a,b,c,d,e,f);
			end
			me.settings.cal.autoPace            = 1;
			me.settings.cal.doRandomPointOrder  = true;
			me.settings.val.pointPos			= [.15 .15; .15 .85; .5 .5; .85 .15; .85 .85];
			%me.settings.val.pointPos			= [.1 .1;.1 .9;.5 .5;.9 .1;.9 .9];
			me.settings.UI.setup.eyeClr         = 255;
			me.settings.cal.pointNotifyFunction = @tittaCalCallback;
			me.settings.val.pointNotifyFunction = @tittaCalCallback;
			updateDefaults(me);
			me.tobii.init();
			me.isConnected						= true;
			me.systemTime						= me.tobii.getTimeAsSystemTime;
			me.ppd_								= me.screen.ppd;
			if me.screen.isOpen == true
				me.win							= me.screen.win;
			end
			
			
			if ~me.isDummy
				me.salutation('Initialise', ...
				sprintf('Running on a %s (%s) @ %iHz mode:%s | Screen %i %i x %i @ %iHz', ...
				me.tobii.systemInfo.model, me.tobii.systemInfo.deviceName,...
				me.tobii.systemInfo.frequency,...
				me.tobii.systemInfo.trackingMode,...
				me.screen.screen,me.screen.winRect(3),me.screen.winRect(4),...
				me.screen.screenVals.fps),true);
			else
				me.salutation('Initialise', 'Running in Dummy Mode', true);
			end
		end
		
		% ===================================================================
		%> @brief
		%>
		% ===================================================================
		function updateDefaults(me)
			if isa(me.tobii, 'Titta')
				me.tobii.setOptions(me.settings);
			end
		end
		
		% ===================================================================
		%> @brief reset the fixation counters ready for a new trial
		%>
		% ===================================================================
		function resetFixation(me)
			me.fixStartTime		= 0;
			me.fixLength		= 0;
			me.fixInitStartTime	= 0;
			me.fixInitLength	= 0;
			me.fixInitTotal		= 0;
			me.fixTotal			= 0;
			me.fixN				= 0;
			me.fixSelection		= 0;
		end
		
		% ===================================================================
		%> @brief check the connection with the tobii
		%>
		% ===================================================================
		function connected = checkConnection(me)
			connected = false;
			if isa(me.tobii,'Titta')
				connected = true;
			end
		end
		
		% ===================================================================
		%> @brief sets up the calibration and validation
		%>
		% ===================================================================
		function trackerSetup(me)
			if me.isConnected && me.screen.isOpen
				updateDefaults(me); % make sure we send any other settings changes
				if me.secondScreen
					if ~me.screen2.isOpen
						me.screen2.open();
					end
					me.calibration = me.tobii.calibrate([me.screen.win me.screen2.win]); %start calibration
				else
					me.calibration = me.tobii.calibrate(me.screen.win); %start calibration
				end
				if strcmpi(me.calibrationStimulus,'movie');me.calStim.movie.reset();end
				disp(me.calibration);
				resetFixation(me);
			end
		end
		
		% ===================================================================
		%> @brief wrapper for StartRecording
		%>
		% ===================================================================
		function startRecording(me)
			if me.isConnected && ~me.isRecording
				success = me.tobii.buffer.start('gaze');
				if success
					me.statusMessage('Starting to record gaze...');
				else
					warning('Can''t START buffer() gazerecording!!!')
				end
				
				success = me.tobii.buffer.start('externalSignal');
				if success
					me.statusMessage('Starting to record TTLs...');
				else
					warning('Can''t START buffer() TTL recording!!!')
				end
				
				success = me.tobii.buffer.start('timeSync');
				if success
					me.statusMessage('Starting to record timeSync...');
				else
					warning('Can''t START buffer() timeSync recording!!!')
				end
			end
		end
		
		% ===================================================================
		%> @brief wrapper for StopRecording
		%>
		% ===================================================================
		function stopRecording(me)
			if me.isConnected && me.isRecording
				success = me.tobii.buffer.stop('gaze');
				if success
					me.statusMessage('Stopping to record Gaze...');
				else
					warning('Can''t STOP buffer() recording!!!')
				end
				
				success = me.tobii.buffer.stop('externalSignal');
				if success
					me.statusMessage('Stopping to record TTLs...');
				else
					warning('Can''t STOP buffer() recording!!!')
				end
				
				success = me.tobii.buffer.stop('timeSync');
				if success
					me.statusMessage('Stopping to record timeSync...');
				else
					warning('Can''t STOP buffer() recording!!!')
				end
			end
		end
		
		% ===================================================================
		%> @brief Save the data
		%>
		% ===================================================================
		function saveData(me,tofile)
			if ~exist('tofile','var') || isempty(tofile); tofile = true; end
			ts = tic;
			me.data = [];
			if me.isConnected
				me.data = me.tobii.collectSessionData();
			end
			me.initialiseSaveFile();
			if ~isempty(me.data) && tofile
				tobii = me;
				if exist(me.saveFile,'file')
					[p,f,e] = fileparts(me.saveFile);
					me.saveFile = [p filesep f me.savePrefix e];
				end
				save(me.saveFile,'tobii')
				disp('===========================')
				me.salutation('saveData',sprintf('Save: %s in %.1fms\n',strrep(me.saveFile,'\','/'),toc(ts)*1e3),true);
				disp('===========================')
				clear tobii
			else
				me.salutation('saveData',sprintf('NO data available: %s (%.1fms)...\n',strrep(me.saveFile,'\','/'),toc(ts)*1e3),true);
			end
		end
		
		% ===================================================================
		%> @brief get a sample from the tracker, if dummymode=true then use
		%> the mouse as an eye signal
		%>
		% ===================================================================
		function sample = getSample(me)
			sample = me.sampleTemplate;
			if me.isConnected && me.isRecording
				td = me.tobii.buffer.peekN('gaze',me.smoothing.nSamples);
				if isempty(td);me.currentSample=sample;return;end
				sample.raw	= td;
				sample.time	= double(td.systemTimeStamp(end)); %remember these are in microseconds
				sample.timeD	= double(td.deviceTimeStamp(end));
				if td.left.gazePoint.valid(end) || td.right.gazePoint.valid(end)
					switch me.smoothing.eyes
						case 'left'
							xy = td.left.gazePoint.onDisplayArea(:,td.left.gazePoint.valid);
						case 'right'
							xy = td.right.gazePoint.onDisplayArea(:,td.right.gazePoint.valid);
						otherwise
							ll=td.left.gazePoint.onDisplayArea(:,td.left.gazePoint.valid);
							rr=td.right.gazePoint.onDisplayArea(:,td.right.gazePoint.valid);
							if size(ll,2) == size(rr,2)
								xy = [ll;rr];
							else
								xy = ll; %switch temporarily to left eye only
							end
					end
					xy			= doSmoothing(me,xy);
					xy			= toPixels(me, xy,'','relative');
					sample.gx	= xy(1);
					sample.gy	= xy(2);
					sample.pa	= nanmean(td.left.pupil.diameter);
					xy			= me.toDegrees(xy);
					me.x		= xy(1);
					me.y		= xy(2);
					me.pupil	= sample.pa;
					%if me.verbose;fprintf('>>X: %2.2f | Y: %2.2f | P: %.2f\n',me.x,me.y,me.pupil);end
				else
					sample.gx	= NaN;
					sample.gy	= NaN;
					sample.pa	= NaN;
					me.x		= NaN;
					me.y		= NaN;
					me.pupil	= NaN;
				end
			elseif me.isDummy %lets use a mouse to simulate the eye signal
				if ~isempty(me.win)
					[mx, my] = GetMouse(me.win);
				else
					[mx, my] = GetMouse([]);
				end
				me.pupil		= 5 + randn;
				sample.gx		= mx;
				sample.gy		= my;
				sample.pa		= me.pupil;
				sample.time		= GetSecs * 1000;
				me.x			= me.toDegrees(sample.gx,'x');
				me.y			= me.toDegrees(sample.gy,'y');
				%if me.verbose;fprintf('>>X: %.2f | Y: %.2f | P: %.2f\n',me.x,me.y,me.pupil);end
			end
			me.currentSample = sample;
		end
		
		% ===================================================================
		%> @brief Method to update the fixation parameters
		%>
		% ===================================================================
		function updateFixationValues(me,x,y,inittime,fixtime,radius,strict)
			%tic
			resetFixation(me)
			if nargin > 1 && ~isempty(x)
				if isinf(x)
					me.fixation.X = me.screen.screenXOffset;
				else
					me.fixation.X = x;
				end
			end
			if nargin > 2 && ~isempty(y)
				if isinf(y)
					me.fixation.Y = me.screen.screenYOffset;
				else
					me.fixation.Y = y;
				end
			end
			if nargin > 3 && ~isempty(inittime)
				if iscell(inittime) && length(inittime)==4
					me.fixation.InitTime = inittime{1};
					me.fixation.Time = inittime{2};
					me.fixation.Radius = inittime{3};
					me.fixation.strictFixation = inittime{4};
				elseif length(inittime) == 2
					me.fixation.InitTime = randi(inittime.*1000)/1000;
				elseif length(inittime)==1
					me.fixation.InitTime = inittime;
				end
			end
			if nargin > 4 && ~isempty(fixtime)
				if length(fixtime) == 2
					me.fixation.Time = randi(fixtime.*1000)/1000;
				elseif length(fixtime) == 1
					me.fixation.Time = fixtime;
				end
			end
			if nargin > 5 && ~isempty(radius); me.fixation.Radius = radius; end
			if nargin > 6 && ~isempty(strict); me.fixation.strictFixation = strict; end
			if me.verbose
				fprintf('-+-+-> eyelinkManager:updateFixationValues: X=%g | Y=%g | IT=%s | FT=%s | R=%g\n', ...
					me.fixation.X, me.fixation.Y, num2str(me.fixation.InitTime), num2str(me.fixation.Time), ...
					me.fixation.Radius);
			end
		end
		
		% ===================================================================
		%> @brief isFixated tests for fixation and updates the fixLength time
		%>
		%> @return fixated boolean if we are fixated
		%> @return fixtime boolean if we're fixed for fixation time
		%> @return searching boolean for if we are still searching for fixation
		% ===================================================================
		function [fixated, fixtime, searching, window, exclusion] = isFixated(me)
			fixated = false; fixtime = false; searching = true; window = []; exclusion = false;
			if (me.isConnected || me.isDummy) && ~isempty(me.currentSample)
				if me.fixInitTotal == 0
					me.fixInitTotal = me.currentSample.time;
				end
				if ~isempty(me.exclusionZone)
					eZ = me.exclusionZone; xe = me.x; ye = me.y;
					if (xe >= eZ(1) && xe <= eZ(2)) && (ye <= eZ(3) && ye >= eZ(4))
						fixated = false; fixtime = false; searching = false; exclusion = true;
						fprintf(' ==> EXCLUSION ZONE ENTERED!\n');
						return
					end
				end
				r = sqrt((me.x - me.fixation.X).^2 + (me.y - me.fixation.Y).^2); %fprintf('x: %g-%g y: %g-%g r: %g-%g\n',me.x, me.fixationX, me.y, me.fixationY,r,me.fixation.Radius);
				window = find(r < me.fixation.Radius);
				if any(window)
					if me.fixN == 0
						me.fixN = 1;
						me.fixSelection = window(1);
					end
					if me.fixSelection == window(1)
						if me.fixStartTime == 0
							me.fixStartTime = me.currentSample.time;
						end
						me.fixLength = (me.currentSample.time - me.fixStartTime) / 1e6;
						if me.fixLength > me.fixation.Time
							fixtime = true;
						end
						me.fixInitStartTime = 0;
						searching = false;
						fixated = true;
						me.fixTotal = me.currentSample.time - me.fixInitTotal;
						%if me.verbose;fprintf(' | %g:%g LENGTH: %g/%g TOTAL: %g/%g | ',fixated,fixtime, me.fixLength, me.fixation.Time, me.fixTotal, me.fixInitTotal);end
						return
					else
						fixated = false;
						fixtime = false;
						searching = false;
					end
				else
					if me.fixN == 1
						me.fixN = -100;
					end
					if me.fixInitStartTime == 0
						me.fixInitStartTime = me.currentSample.time;
					end
					me.fixInitLength = (me.currentSample.time - me.fixInitStartTime) / 1e6;
					if me.fixInitLength <= me.fixation.InitTime
						searching = true;
					else
						searching = false;
					end
					me.fixStartTime = 0;
					me.fixLength = 0;
					me.fixTotal = me.currentSample.time - me.fixInitTotal;
					return
				end
			end
		end
		
		% ===================================================================
		%> @brief testFixation returns input yes or no strings based on
		%> fixation state, useful for using via stateMachine
		%>
		% ===================================================================
		function out = testExclusion(me)
			out = false;
			if (me.isConnected || me.isDummy) && ~isempty(me.currentSample) && ~isempty(me.exclusionZone)
				eZ = me.exclusionZone; xe = me.x; ye = me.y;
				if (xe >= eZ(1) && xe <= eZ(2)) && (ye <= eZ(3) && ye >= eZ(4))
					out = true;
					fprintf(' ==> EXCLUSION ZONE ENTERED!\n');
					return
				end
			end
		end
		
		% ===================================================================
		%> @brief testFixation returns input yes or no strings based on
		%> fixation state, useful for using via stateMachine
		%>
		% ===================================================================
		function out = testWithinFixationWindow(me, yesString, noString)
			if isFixated(me)
				out = yesString;
			else
				out = noString;
			end
		end
		
		% ===================================================================
		%> @brief Checks if we've maintained fixation for correct time, if
		%> true return yesString, if not return noString. This allows an
		%> external code to quickly select a string based on this.
		%>
		% ===================================================================
		function out = testFixationTime(me, yesString, noString)
			[fix,fixtime] = isFixated(me);
			if fix && fixtime
				out = yesString; %me.salutation(sprintf('Fixation Time: %g',me.fixLength),'TESTFIXTIME');
			else
				out = noString;
			end
		end
		
		% ===================================================================
		%> @brief Checks if we're looking for fixation a set time. Input is
		%> 2 strings, either one is returned depending on success or
		%> failure, 'searching' may also be returned meaning the fixation
		%> window hasn't been entered yet, and 'fixing' means the fixation
		%> time is not yet met...
		%>
		%> @param yesString if this function succeeds return this string
		%> @param noString if this function fails return this string
		%> @return out the output string which is 'searching' if fixation is
		%>   still being initiated, 'fixing' if the fixation window was entered
		%>   but not for the requisite fixation time, or the yes or no string.
		% ===================================================================
		function [out, window, exclusion] = testSearchHoldFixation(me, yesString, noString)
			[fix, fixtime, searching, window, exclusion] = me.isFixated();
			if exclusion
				fprintf('-+-+-> Tobii:testSearchHoldFixation EXCLUSION ZONE ENTERED!\n')
				out = 'EXCLUDED!'; window = [];
				return
			end
			if searching
				if (me.fixation.strictFixation==true && (me.fixN == 0)) || me.fixation.strictFixation==false
					out = 'searching';
				else
					out = noString;
					if me.verbose; fprintf('-+-+-> Tobii:testSearchHoldFixation STRICT SEARCH FAIL: %s [%g %g %g]\n', out, fix, fixtime, searching);end
				end
				return
			elseif fix
				if (me.fixation.strictFixation==true && ~(me.fixN == -100)) || me.fixation.strictFixation==false
					if fixtime
						out = yesString;
						if me.verbose; fprintf('-+-+-> Tobii:testSearchHoldFixation FIXATION SUCCESSFUL!: %s [%g %g %g]\n', out, fix, fixtime, searching);end
					else
						out = 'fixing';
					end
				else
					out = noString;
					if me.verbose;fprintf('-+-+-> Tobii:testSearchHoldFixation FIX FAIL: %s [%g %g %g]\n', out, fix, fixtime, searching);end
				end
				return
			elseif searching == false
				out = noString;
				if me.verbose;fprintf('-+-+-> Tobii:testSearchHoldFixation SEARCH FAIL: %s [%g %g %g]\n', out, fix, fixtime, searching);end
			else
				out = '';
			end
			return
		end
		
		% ===================================================================
		%> @brief Checks if we're still within fix window. Input is
		%> 2 strings, either one is returned depending on success or
		%> failure, 'fixing' means the fixation time is not yet met...
		%>
		%> @param yesString if this function succeeds return this string
		%> @param noString if this function fails return this string
		%> @return out the output string which is 'fixing' if the fixation window was entered
		%>   but not for the requisite fixation time, or the yes or no string.
		% ===================================================================
		function [out, window, exclusion] = testHoldFixation(me, yesString, noString)
			[fix, fixtime, searching, window, exclusion] = me.isFixated();
			if exclusion
				fprintf('-+-+-> Tobii:testHoldFixation EXCLUSION ZONE ENTERED!\n')
				out = 'EXCLUDED!'; window = [];
				return
			end
			if fix
				if (me.fixation.strictFixation==true && ~(me.fixN == -100)) || me.fixation.strictFixation==false
					if fixtime
						out = yesString;
						if me.verbose; fprintf('-+-+-> Tobii:testHoldFixation FIXATION SUCCESSFUL!: %s [%g %g %g]\n', out, fix, fixtime, searching);end
					else
						out = 'fixing';
					end
				else
					out = noString;
					if me.verbose;fprintf('-+-+-> Tobii:testHoldFixation FIX FAIL: %s [%g %g %g]\n', out, fix, fixtime, searching);end
				end
				return
			else
				out = noString;
				if me.verbose; fprintf('-+-+-> Tobii:testHoldFixation FIX FAIL: %s [%g %g %g]\n', out, fix, fixtime, searching);end
				return
			end
		end
		
		% ===================================================================
		%> @brief draw the current eye position on the PTB display
		%>
		% ===================================================================
		function drawEyePosition(me)
			if (me.isDummy || me.isConnected) && me.screen.isOpen && ~isempty(me.x) && ~isnan(me.x) && ~isempty(me.y) && ~isnan(me.y)
				%xy = toPixels(me,[me.x me.y]);
				xy = [me.currentSample.gx me.currentSample.gy];
				if me.isFixated
					Screen('DrawDots', me.win, xy, me.pupil*5, [1 0.5 1 1], [], 3);
					if me.fixLength > me.fixation.Time
						Screen('DrawText', me.win, 'FIX', xy(1),xy(2), [1 1 1]);
					end
				else
					Screen('DrawDots', me.win, xy, me.pupil*5, [1 0.5 0 1], [], 3);
				end
			end
		end
		
		% ===================================================================
		%> @brief draw N last eye position on the PTB display
		%>
		% ===================================================================
		function drawEyePositions(me,dataDur)
			if (~me.isDummy || me.isConnected) && me.screen.isOpen
				nDataPoint  = ceil(dataDur/1000*fs);
				eyeData     = me.tobii.buffer.peekN('gaze',nDataPoint);
				pointSz		= 4;
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
		function trackerMessage(me, message, vbl)
			if me.isConnected
				if exist('vbl','var')
					me.tobii.sendMessage(message, vbl);
				else
					me.tobii.sendMessage(message);
				end
				if me.verbose; fprintf('-+-+->TOBII Message: %s\n',message);end
			end
		end
		
		% ===================================================================
		%> @brief close the tobii and cleanup
		%> is enabled
		%>
		% ===================================================================
		function close(me)
			try
				stopRecording(me)
			catch ME
				me.salutation('Close Method','Couldn''t stop recording, forcing shutdown...',true)
				getReport(ME)
			end
			me.isConnected = false;
			resetFixation(me);
			me.eyeUsed = 'both';
		end
		
		% ===================================================================
		%> @brief Sync time with tracker
		%>
		% ===================================================================
		function syncTrackerTime(me)
			if me.isConnected
				me.tobii.getSystemTime;
			end
		end
		
		% ===================================================================
		%> @brief Train to use tracker
		%>
		% ===================================================================
		function runTimingTest(me,sRate,interval)
			ofilename = me.saveFile;
			me.initialiseSaveFile();
			[p,~,e]=fileparts(me.saveFile);
			me.saveFile = [p filesep 'tobiiTimingTest-' me.savePrefix e];
			try
				if isa(me.screen,'screenManager')
					s = me.screen;
				else
					s = screenManager('blend',true,'pixelsPerCm',36,'distance',60);
				end
				s.disableSyncTests = false;
				s.backgroundColour = [0.5 0.5 0.5 0];
				me.sampleRate = sRate;
				open(s); %open our screen
				initialise(me,s); %initialise tobii with our screen
				trackerSetup(me);
				ShowCursor; %titta fails to show cursor so we must do it
				Priority(MaxPriority(s.win));
                startRecording(me);
                WaitSecs('YieldSecs',1);
				drawCross(s);
				vbl = flip(s);
				trackerMessage(me,'STARTVBL',vbl);
				sampleInterval = interval;
				nSamples = 2000;
				ti = zeros(nSamples,1) * NaN;
				tx = zeros(nSamples,1) * NaN;
				tj = zeros(nSamples,1);
                for i = 1 : nSamples
					td = me.tobii.buffer.peekN('gaze',1);
					if ~isempty(td)
						ti(i) = double(td.systemTimeStamp); 
						tx(i) = td.left.gazePoint.onDisplayArea(1);
					end
					tj(i) = WaitSecs(sampleInterval);
				end
				vbl=flip(s);
				trackerMessage(me,'ENDVBL',vbl);
				ti = (ti - ti(1)) / 1e3;
				tj = (tj - tj(1)) * 1e3;
				sdi = std(diff(ti));
				sdj = std(diff(tj));
				WaitSecs('YieldSecs',0.5);
				assignin('base','ti',ti);
				assignin('base','tj',tj);
				assignin('base','ti',ti);
				assignin('base','tx',tx);
				figure; 
				subplot(2,1,1);
				plot(diff(tj),'LineWidth',1.5);set(gca,'YScale','linear');ylabel('Time Delta (ms)');xlabel(['PTB Timestamp SD=' num2str(sdj) 'ms']);
				ylim([0 max(diff(ti))]);line([0 nSamples],[sampleInterval*1e3 sampleInterval*1e3],'LineStyle','-.','LineWidth',1,'Color','red');
				title(['Sample Interval: ' num2str(sampleInterval*1e3) 'ms | Tobii Sample Rate: ' num2str(sRate) 'hz']);
				legend('Raw Timestamps','Sample Interval')
				subplot(2,1,2);
				plot(diff(ti),'LineWidth',1.5);set(gca,'YScale','linear');ylabel('Time Delta (ms)');xlabel(['Tobii Timestamp SD=' num2str(sdi) 'ms']);
				ylim([0 max(diff(ti))]);line([0 nSamples],[sampleInterval*1e3 sampleInterval*1e3],'LineStyle','-.','LineWidth',1,'Color','red');
				ListenChar(0); Priority(0); ShowCursor;
				stopRecording(me);
				close(s);
				saveData(me,false);
				close(me);
				me.saveFile = ofilename;
				clear s
			catch ME
				ListenChar(0);Priority(0);ShowCursor;
				me.saveFile = ofilename;
				getReport(ME)
				close(s);
				sca;
				close(me);
				clear s
				rethrow(ME)
			end
		end
		
		% ===================================================================
		%> @brief runs a demo of the tobii workflow, testing this class
		%>
		% ===================================================================
		function runDemo(me,forcescreen)
			KbName('UnifyKeyNames')
			stopkey=KbName('q');
			upKey=KbName('uparrow');
			downKey=KbName('downarrow');
			leftKey=KbName('leftarrow');
			rightKey=KbName('rightarrow');
			calibkey=KbName('c');
			ofixation = me.fixation; me.sampletime = [];
			osmoothing = me.smoothing;
			ofilename = me.saveFile;
			me.initialiseSaveFile();
			[p,~,e]=fileparts(me.saveFile);
			me.saveFile = [p filesep 'tobiiRunDemo-' me.savePrefix e];
			try
				if isa(me.screen,'screenManager') && ~isempty(me.screen)
					s = me.screen;
				else
					s = screenManager('disableSyncTests',false,'blend',true,'pixelsPerCm',36,'distance',60);
				end
				s.disableSyncTests		= false;
				s.audio					= audioManager();
				s.audio.setup();
				if exist('forcescreen','var'); s.screen = forcescreen; end
				s.backgroundColour		= [0.5 0.5 0.5 0];
				if length(Screen('Screens'))>1
					s2					= screenManager;
					s2.screen			= s.screen - 1;
					s2.backgroundColour	= bgColour;
					s2.windowed			= [];
					s2.bitDepth			= '8bit';
					s2.blend			= true;
					s2.disableSyncTests	= true;
				end
				
				o = dotsStimulus('size',me.fixation.Radius*2,'speed',2,'mask',true,'density',50); %test stimulus
				sv=open(s); %open our screen
				setup(o,s); %setup our stimulus with open screen
				
				ListenChar(1);
				if exist('s2','var')
					initialise(me, s, s2); %initialise tobii with our screen
				else
					initialise(me, s); %initialise tobii with our screen
				end
				trackerSetup(me);
				ShowCursor; %titta fails to show cursor so we must do it
				drawPhotoDiodeSquare(s,[0 0 0 1]); flip(s); %make sure our photodiode patch is black
				
				% set up the size and position of the stimulus
				o.sizeOut = me.fixation.Radius*2;
				o.xPositionOut = me.fixation.X;
				o.yPositionOut = me.fixation.Y;
				
				Priority(MaxPriority(s.win));
				endExp = 0;
				trialn = 1;
				maxTrials = 10;
				m=1; n=1;
				methods={'median','heuristic1','heuristic2','sg','simple'};
				eyes={'both','left','right'};
				if ispc; Screen('TextFont',s.win,'Consolas'); end
				fprintf('\n===>>> Warming up the GPU, Eyetracker etc... <<<===\n')
                sgolayfilt(rand(10,1),1,3); %warm it up
                me.heuristicFilter(rand(10,1), 2);
                startRecording(me);
                WaitSecs('YieldSecs',1);
                mc = true;
                for i = 1 : s.screenVals.fps
                    draw(o);
                    drawBackground(s);
                    Screen('DrawText',s.win,['Warming up frame ' num2str(i)],65,10);
                    finishDrawing(s);
                    animate(o);
                    getSample(me);
                    flip(s);
                end
                s.drawPhotoDiodeSquare([0 0 0 1]);
				flip(s);
				update(o); %make sure stimuli are set back to their start state
				WaitSecs('YieldSecs',0.5);
				trackerMessage(me,'!!! Starting Demo...')
				
				while trialn <= maxTrials && endExp == 0
					trialtick = 1;
					trackerMessage(me,sprintf('Settings for Trial %i, X=%.2f Y=%.2f, SZ=%.2f',trialn,me.fixation.X,me.fixation.Y,o.sizeOut))
					getSample(me); isFixated(me); resetFixation(me);
					drawPhotoDiodeSquare(s,[0 0 0 1]);
					vbl = flip(s); tstart=vbl;
					trackerMessage(me,'STARTVBL',vbl);
					while vbl < tstart + 6
						draw(o);
						drawGrid(s);
						drawCross(s,0.5,[1 1 0],me.fixation.X,me.fixation.Y);
						drawPhotoDiodeSquare(s,[1 1 1 1]);
						
						getSample(me);
						if ~isempty(me.currentSample)
							txt = sprintf('Press Q to finish. X = %3.1f / %2.2f | Y = %3.1f / %2.2f | # = %i %s %s | RADIUS = %.1f | FIXATION = %i',...
								me.currentSample.gx, me.x, me.currentSample.gy, me.y, me.smoothing.nSamples,...
								me.smoothing.method, me.smoothing.eyes, me.fixation.Radius, me.fixLength);
							Screen('DrawText', s.win, txt, 10, 10);
							drawEyePosition(me);
						end
						finishDrawing(s);
						animate(o);
						
						[vbl, when] = Screen('Flip', s.win, vbl + s.screenVals.halfifi);
						if trialtick==1; me.tobii.sendMessage('SYNC = 255', vbl);end
						
						[~, ~, keyCode] = KbCheck(-1);
						if keyCode(stopkey); endExp = 1; break;
						elseif keyCode(calibkey); me.doCalibration;
						elseif keyCode(upKey); me.smoothing.nSamples = me.smoothing.nSamples + 1; if me.smoothing.nSamples > 400; me.smoothing.nSamples=400;end
						elseif keyCode(downKey); me.smoothing.nSamples = me.smoothing.nSamples - 1; if me.smoothing.nSamples < 1; me.smoothing.nSamples=1;end
						elseif keyCode(leftKey); m=m+1; if m>5;m=1;end; me.smoothing.method=methods{m};
						elseif keyCode(rightKey); n=n+1; if n>3;n=1;end; me.smoothing.eyes=eyes{n};
						end
						trialtick=trialtick+1;
					end
					if endExp == 0
						drawPhotoDiodeSquare(s,[0 0 0 1]);
						vbl = flip(s);
						trackerMessage(me,'END_RT',vbl);
						trackerMessage(me,'TRIAL_RESULT 1')
						trackerMessage(me,sprintf('Ending trial %i @ %i',trialn,int64(round(vbl*1e6))))
						resetFixation(me);
						me.fixation.X = randi([-7 7]);
						me.fixation.Y = randi([-7 7]);
						me.fixation.Radius = randi([1 3]);
						o.sizeOut = me.fixation.Radius * 2;
						o.xPositionOut = me.fixation.X;
						o.yPositionOut = me.fixation.Y;
						update(o);
						WaitSecs(0.3);
						trialn = trialn + 1;
					else
						drawPhotoDiodeSquare(s,[0 0 0 1]);
						vbl = flip(s);
						trackerMessage(me,'END_RT',vbl);
						trackerMessage(me,'TRIAL_RESULT -10 ABORT')
						trackerMessage(me,sprintf('Aborting %i @ %i', trialn, int64(round(vbl*1e6))))
					end
				end
				stopRecording(me);
				close(s);
				saveData(me);
				close(me);
				ListenChar(0); Priority(0); ShowCursor;
				me.fixation = ofixation;
				me.saveFile = ofilename;
				me.smoothing = osmoothing;
				clear s o
			catch ME
				me.fixation = ofixation;
				me.saveFile = ofilename;
				me.smoothing = osmoothing;
				ListenChar(0);Priority(0);ShowCursor;
				getReport(ME)
				close(s);
				sca;
				close(me);
				clear s o
				rethrow(ME)
			end
			
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
					case 'sg' %savitzky-golay
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
				out = [0.5 0.5];
			end
		end
		
		% ===================================================================
		%> @brief
		%>
		% ===================================================================
		function value = get.isRecording(me)
			if me.isConnected
				value = me.tobii.buffer.isRecording('gaze');
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
			success = true;
		end
		
		% ===================================================================
		%> @brief wrapper for CheckRecording
		%>
		% ===================================================================
		function error = checkRecording(me)
			error = false;
		end
		
		% ===================================================================
		%> @brief draw the background colour
		%>
		% ===================================================================
		function trackerClearScreen(me)
			
		end
		
		% ===================================================================
		%> @brief draw the stimuli boxes on the tracker display
		%>
		% ===================================================================
		function trackerDrawStimuli(me, ts, clearScreen)
			
		end
		
		% ===================================================================
		%> @brief draw the fixation box on the tracker display
		%>
		% ===================================================================
		function trackerDrawFixation(me)
			
		end
		
		% ===================================================================
		%> @brief draw the fixation box on the tracker display
		%>
		% ===================================================================
		function trackerDrawExclusion(me)
			
		end
		
		% ===================================================================
		%> @brief draw the fixation box on the tracker display
		%>
		% ===================================================================
		function trackerDrawText(me,textIn)
			
		end
		
		% ===================================================================
		%> @brief check what mode the tobii is in
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
			
		end
		
		
		% ===================================================================
		%> @brief Get offset between tracker and display computers
		%>
		% ===================================================================
		function offset = getTimeOffset(me)
			
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
		
		% ===================================================================
		%> @brief to pixels from visual degrees / relative
		%>
		% ===================================================================
		function out = toPixels(me,in,axis,inputtype)
			if ~exist('axis','var') || isempty(axis); axis=''; end
			if ~exist('inputtype','var') || isempty(inputtype); inputtype = 'degrees'; end
			out = 0;
			if length(in)>4; return; end
			switch axis
				case 'x'
					switch inputtype
						case 'degrees'
							out = (in * me.ppd_) + me.screen.xCenter;
						case 'relative'
							out = in * me.screen.screenVals.width;
					end
				case 'y'
					switch inputtype
						case 'degrees'
							out = (in * me.ppd_) + me.screen.yCenter;
						case 'relative'
							out = in * me.screen.screenVals.height;
					end
				otherwise
					switch inputtype
						case 'degrees'
							if length(in)==2
								out(1) = (in(1) * me.ppd_) + me.screen.xCenter;
								out(2) = (in(2) * me.ppd_) + me.screen.yCenter;
							elseif length(in)==4
								out(1:2) = (in(1:2) * me.ppd_) + me.screen.xCenter;
								out(3:4) = (in(3:4) * me.ppd_) + me.screen.yCenter;
							end
						case 'relative'
							if length(in)==2
								out(1) = in(1) * me.screen.screenVals.width;
								out(2) = in(2) * me.screen.screenVals.height;
							elseif length(in)==4
								out(1:2) = in(1:2) * me.screen.screenVals.width;
								out(3:4) = in(3:4) * me.screen.screenVals.height;
							end
					end
			end
		end
		
		% ===================================================================
		%> @brief to visual degrees from pixels
		%>
		% ===================================================================
		function out = toDegrees(me,in,axis,inputtype)
			if ~exist('axis','var') || isempty(axis); axis=''; end
			if ~exist('inputtype','var') || isempty(inputtype); inputtype = 'pixels'; end
			out = 0;
			if length(in)>2; return; end
			switch axis
				case 'x'
					in = in(1);
					switch inputtype
						case 'pixels'
							out = (in - me.screen.xCenter) / me.ppd_;
						case 'relative'
							out = (in - 0.5) * (me.screen.screenVals.width /me.ppd_);
					end
				case 'y'
					in = in(1);
					switch inputtype
						case 'pixels'
							out = (in - me.screen.yCenter) / me.ppd_; return
						case 'relative'
							out = (in - 0.5) * (me.screen.screenVals.height /me.ppd_);
					end
				otherwise
					switch inputtype
						case 'pixels'
							out(1) = (in(1) - me.screen.xCenter) / me.ppd_;
							out(2) = (in(2) - me.screen.yCenter) / me.ppd_;
						case 'relative'
							out(1) = (in - 0.5) * (me.screen.screenVals.width /me.ppd_);
							out(2) = (in - 0.5) * (me.screen.screenVals.height /me.ppd_);
					end
			end
		end
		
		% ===================================================================
		%> @brief
		%>
		% ===================================================================
		function initTracker(me)
			me.settings = Titta.getDefaults(me.model);
			me.settings.cal.bgColor = 127;
			me.tobii = Titta(me.settings);
		end
		
		% ===================================================================
		%> @brief original Tobii SDK head pos check
		%>
		% ===================================================================
		function checkHeadPosition(me)
			if ~me.isConnected; return; end
			me.tobii.get_gaze_data();
			while ~KbCheck
				DrawFormattedText(me.screen.win, 'When correctly positioned press any key to start the calibration.', 'center', me.screen.screenVals.height * 0.1, me.screen.screenVals.white);
				distance = [];
				gaze_data = me.tobii.get_gaze_data();
				if ~isempty(gaze_data)
					last_gaze = gaze_data(end);
					validityColor = [0.8 0 0];
					% Check if user has both eyes inside a reasonable tacking area.
					if last_gaze.LeftEye.GazeOrigin.Validity.Valid && last_gaze.RightEye.GazeOrigin.Validity.Valid
						left_validity = all(last_gaze.LeftEye.GazeOrigin.InTrackBoxCoordinateSystem(1:2) < 0.85) ...
							&& all(last_gaze.LeftEye.GazeOrigin.InTrackBoxCoordinateSystem(1:2) > 0.15);
						right_validity = all(last_gaze.RightEye.GazeOrigin.InTrackBoxCoordinateSystem(1:2) < 0.85) ...
							&& all(last_gaze.RightEye.GazeOrigin.InTrackBoxCoordinateSystem(1:2) > 0.15);
						if left_validity && right_validity
							validityColor = [0 0.8 0];
						end
					end
					origin = [me.screen.screenVals.width/4 me.screen.screenVals.height/4];
					size = [me.screen.screenVals.width/2 me.screen.screenVals.height/2];
					
					baseRect = [0 0 size(1) size(2)];
					frame = CenterRectOnPointd(baseRect, me.screen.screenVals.width/2, me.screen.screenVals.height/2);
					
					Screen('FrameRect', me.screen.win, validityColor, frame, 5);
					% Left Eye
					if last_gaze.LeftEye.GazeOrigin.Validity.Valid
						distance = [distance; round(last_gaze.LeftEye.GazeOrigin.InUserCoordinateSystem(3)/10,1)];
						left_eye_pos_x = double(1-last_gaze.LeftEye.GazeOrigin.InTrackBoxCoordinateSystem(1))*size(1) + origin(1);
						left_eye_pos_y = double(last_gaze.LeftEye.GazeOrigin.InTrackBoxCoordinateSystem(2))*size(2) + origin(2);
						Screen('DrawDots', me.screen.win, [left_eye_pos_x left_eye_pos_y], 30, validityColor, [], 2);
					end
					% Right Eye
					if last_gaze.RightEye.GazeOrigin.Validity.Valid
						distance = [distance;round(last_gaze.RightEye.GazeOrigin.InUserCoordinateSystem(3)/10,1)];
						right_eye_pos_x = double(1-last_gaze.RightEye.GazeOrigin.InTrackBoxCoordinateSystem(1))*size(1) + origin(1);
						right_eye_pos_y = double(last_gaze.RightEye.GazeOrigin.InTrackBoxCoordinateSystem(2))*size(2) + origin(2);
						Screen('DrawDots', me.screen.win, [right_eye_pos_x right_eye_pos_y], 30, validityColor, [], 2);
					end
				end
				DrawFormattedText(me.screen.win, sprintf('Current distance to the eye tracker: %.2f cm.',mean(distance)), 'center', me.screen.screenVals.height * 0.85, me.screen.screenVals.white);
				flip(me.screen);
			end
			me.tobii.stop_gaze_data();
		end
		
		% ===================================================================
		%> @brief originl Tobii SDK calibration
		%>
		% ===================================================================
		function simpleCalibration(me)
			spaceKey = KbName('space');
			RKey = KbName('C');
			dotSizePix = 15;
			dotColor = [[1 0 0];[1 1 1]]; % Red and white
			leftColor = [1 0.5 0];
			rightColor = [0 0.4 0.75];
			% Calibration points
			lb = 0.15;  % left bound
			xc = 0.5;  % horizontal center
			rb = 0.85;  % right bound
			ub = 0.15;  % upper bound
			yc = 0.5;  % vertical center
			bb = 0.85;  % bottom bound
			
			points_to_calibrate = [[xc,yc];[lb,ub];[rb,ub];[lb,bb];[rb,bb]];
			
			% Create calibration object
			calib = ScreenBasedCalibration(me.tobii);
			try calib.leave_calibration_mode(); end
			calibrating = true;
			
			DrawFormattedText(me.screen.win, 'Get ready to fixate...', 'center', 'center', me.screen.screenVals.white);
			flip(me.screen);
			WaitSecs(0.5);
			spx = [me.screen.screenVals.width me.screen.screenVals.height];
			
			while calibrating
				% Enter calibration mode
				calib.enter_calibration_mode();
				
				for i=1:length(points_to_calibrate)
					
					Screen('DrawDots', me.screen.win, points_to_calibrate(i,:).*spx, dotSizePix, dotColor(1,:), [], 2);
					Screen('DrawDots', me.screen.win, points_to_calibrate(i,:).*spx, dotSizePix*0.3, dotColor(2,:), [], 2);
					
					Screen('Flip', me.screen.win);
					
					% Wait a moment to allow the user to focus on the point
					WaitSecs(1);
					
					if calib.collect_data(points_to_calibrate(i,:)) ~= CalibrationStatus.Success
						% Try again if it didn't go well the first time.
						% Not all eye tracker models will fail at this point, but instead fail on ComputeAndApply.
						calib.collect_data(points_to_calibrate(i,:));
					end
					
					flip(me.screen);
					WaitSecs(0.2);
					
				end
				
				DrawFormattedText(me.screen.win, 'Calculating calibration result....', 'center', 'center', me.screen.screenVals.white);
				
				flip(me.screen);
				
				% Blocking call that returns the calibration result
				calibration_result = calib.compute_and_apply();
				
				calib.leave_calibration_mode();
				
				if calibration_result.Status ~= CalibrationStatus.Success
					continue
				end
				
				% Calibration Result
				WaitSecs(0.5);
				flip(me.screen);
				points = calibration_result.CalibrationPoints;
				
				for i=1:length(points)
					Screen('DrawDots', me.screen.win, points(i).PositionOnDisplayArea.*spx, dotSizePix*0.5, dotColor(2,:), [], 2);
					for j=1:length(points(i).RightEye)
						if points(i).LeftEye(j).Validity == CalibrationEyeValidity.ValidAndUsed
							Screen('DrawDots', me.screen.win, points(i).LeftEye(j).PositionOnDisplayArea.*spx, dotSizePix*0.3, leftColor, [], 2);
							Screen('DrawLines', me.screen.win, ([points(i).LeftEye(j).PositionOnDisplayArea; points(i).PositionOnDisplayArea].*spx)', 2, leftColor, [0 0], 2);
						end
						if points(i).RightEye(j).Validity == CalibrationEyeValidity.ValidAndUsed
							Screen('DrawDots', me.screen.win, points(i).RightEye(j).PositionOnDisplayArea.*spx, dotSizePix*0.3, rightColor, [], 2);
							Screen('DrawLines', me.screen.win, ([points(i).RightEye(j).PositionOnDisplayArea; points(i).PositionOnDisplayArea].*spx)', 2, rightColor, [0 0], 2);
						end
					end
				end
				
				DrawFormattedText(me.screen.win, 'Press the ''C'' key to recalibrate or ''Space'' to continue....', 'center', me.screen.screenVals.height * 0.95, me.screen.screenVals.white)
				flip(me.screen);
				
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
		end
	end %------------------END PRIVATE METHODS
end

% ========================================================================
%> @class eyetrackerCore -- parent class for all eyetrackers
%> Class methods enable the user to test for common behavioural eye tracking
%> tasks with single commands. For example, to initiate a task we normally
%> place a fixation cross on the screen and ask the subject to saccade to
%> the cross and maintain fixation for a particular duration. This is
%> achieved using testSearchHoldFixation('yes','no'), using the properties:
%> fixation.initTime to time how long the subject has to saccade into the
%> window, fixation.time for how long they must maintain fixation,
%> fixation.radius for the radius around fixation.X and fixation.Y position.
%> The method returns the 'yes' string if the rules are matched, and 'no' if
%> they are not, thus enabling experiment code to simply call this method
%> until it returns 'yes''. Other methods include isFixated(),
%> testFixationTime(), testHoldFixation().
%>
%> This class enables several types of behavioural control:
%>
%> 1. Fixation window: one or more areas where the subject must enter with
%>    their eye position within a certain time and must maintain fixation
%>    for a certain time. Windows can be circular or rectangular.
%> 2. Exclusion zones: one or more rectangular areas that cause failure if
%>    entered.
%> 3. Fix initiation zone: an area the eye must stay with for a certain time
%>    before a saccade. For example if a subect fixates, then must saccade a
%>    time X, do not allow the eye to leave this zone before X + t (t by
%>    default is 100ms). This stops potential cheating by the subject.
%>
%> Try using the demo mode to see it in action (read the runDemo() code to
%> understand how to use the class):
%>
%>```matlab
%> >> eT = eyelinkManager('verbose', true);
%> >> eT.runDemo();
%>```
%>
%> Multiple fixation windows can be assigned (either circular or
%> rectangular), and in addition multiple exclusion windows (exclusionZone)
%> can ensure a subject doesn't saccade to particular parts of the screen.
%> fixInit allows you to define a minimum time with which the subject can
%> initiate a saccade away from a position (which stops a subject cheating
%> by moving the eyes too soon).
%>
%> For the eyelink we also allow the use of remote calibration and can call
%> a reward systems during calibration / validation to improve subject
%> performance compared to the eyelink toolbox alone.
%>
%> Copyright ©2014-2023 Ian Max Andolina — released: LGPL3, see LICENCE.md
% ========================================================================
classdef eyetrackerCore < optickaCore

	properties (Abstract, SetAccess = protected, GetAccess = public)
		%> type of eyetracker
		type
	end
	
	properties
		%> fixation window in deg with 0,0 being the screen center:
		%>
		%> if X and Y have multiple rows, assume each row is a different
		%> fixation window. so that multiple fixtation windows can be used.
		%>
		%> if radius has as single value, assume circular window if radius
		%> has 2 values assume width × height rectangle (not strictly a
		%> radius I know!)
		%>
		%> initTime is the time the subject has to initiate fixation
		%>
		%> time is the time the subject must maintain fixation within the
		%> window
		%>
		%> strict = false allows subject to exit and enter window without
		%> failure, useful during training
		fixation			= struct('X',0,'Y',0,'initTime',1,'time',1,...
								'radius',1,'strict',true)
		%> Use exclusion zones where no eye movement allowed: [-degX +degX -degY
		%> +degY] Add rows to generate multiple exclusion zones.
		exclusionZone		= []
		%> we can define an optional window that the subject must stay
		%> inside before they saccade to other targets. This restricts
		%> guessing and "cheating", by forcing a minimum delay (default =
		%> 100ms / 0.1s) before initiating a saccade. Only used if X
		%> position is not empty.
		fixInit				= struct('X', [],'Y', [],'time', 0.1,'radius', 2)
		%> add a manual offset to the eye position, similar to a drift correction
		%> but handled by the eyelinkManager.
		offset				= struct('X', 0,'Y', 0)
		%> tracker update speed (Hz)
		sampleRate			= 500
		%> start eyetracker in dummy mode?
		isDummy				= false
		%> do we record and/or retrieve eyetracker data with remote interface?
		recordData			= true
		%> use an operator screen for online display etc.
		useOperatorScreen	= false
		%> do we ignore blinks, if true then we do not update X and Y position
		%> from previous eye location, meaning the various methods will maintain
		%> position, e.g. if you are fixated and blink, the within-fixation X
		%> and Y position are retained so that a blink does not "break"
		%> fixation. 
		ignoreBlinks		= false
		%> name of eyetracker EDF file
		saveFile			= 'eyetrackerData'
		%> subject name
		subjectName			= ''
		%> do we log debug messages to the command window?
		verbose					= false
	end

	properties (Abstract)
		%> info for setup / calibration
		calibration
	end
	
	properties (Hidden = true)
		%> stimulus positions to draw on screen
		stimulusPositions		= []
		%> the PTB screen to work on, passed in during initialise
		screen					= []
		%> operator screen used during calibration
		operatorScreen			= []
		%> the PTB screen handle, normally set by screenManager but can force it to use another screen
		win						= []
		%> is operator screen being used?
		secondScreen			= false
		%> size to draw eye position on screen
		eyeSize double			= 10
		%> for trackerFlip, we can only flip every X frames
		skipFlips				= 8
	end
	
	properties (SetAccess = protected, GetAccess = public)
		%> Gaze X position in degrees
		x						= []
		%> Gaze Y position in degrees
		y						= []
		%> pupil size
		pupil					= []
		%> last isFixated true/false result
		isFix					= false
		%> did the fixInit test fail or not?
		isInitFail				= false
		%> are we in a blink?
		isBlink					= false
		%> are we in an exclusion zone?
		isExclusion				= false
		%> total time searching for and holding fixation
		fixTotal				= 0
		%> Initiate fixation length
		fixInitLength			= 0
		%> how long have we been in the fixation window?
		fixLength				= 0
		%> when ~strict, we accumulate the total time in the window
		fixBuffer				= 0
		%> Initiate fixation time
		fixInitStartTime		= 0
		%the first timestamp fixation was true
		fixStartTime			= 0
		%> which fixation window matched the last fixation?
		fixWindow				= 0
		%> last time offset betweeen tracker and display computers
		currentOffset			= 0
		%> tracker time stamp
		trackerTime				= 0
		%current sample taken from eyelink
		currentSample			= []
		%current event taken from eyelink
		currentEvent			= []
		% are we connected to eyelink?
		isConnected				= false
		% are we recording to an EDF file?
		isRecording				= false
		% which eye is the tracker using?
		eyeUsed					= -1
		%version of eyetracker interface
		version					= ''
		%> All gaze X position in degrees reset using resetFixation
		xAll					= []
		%> Last gaze Y position in degrees reset using resetFixation
		yAll					= []
		%> all pupil size reset using resetFixation
		pupilAll				= []
		%> data streamed out from the Tobii
		data					= struct()
		%> validation data
		validationData			= struct()
	end
	
	properties (SetAccess = protected, GetAccess = ?optickaCore)
		% samples before any smoothing
		xAllRaw
		yAllRaw
		%> flipTick
		flipTick				= 0
		%> currentSample template
		sampleTemplate struct	= struct('raw',[],'time',NaN,'timeD',NaN,'gx',NaN,'gy',NaN,...
									'pa',NaN,'valid',false)
		ppd_					= 36
		% these are used to test strict fixation
		fixN double				= 0
		fixSelection			= []
		%> allowed properties passed to object upon construction
		allowedPropertiesBase	= {'useOperatorScreen','fixation', 'exclusionZone', 'fixInit', ...
			'offset', 'sampleRate', 'ignoreBlinks', 'saveData',...
			'recordData', 'verbose', 'isDummy'}
	end

	%> ALL Children must implement these methods!
	%========================================================================
	methods (Abstract) %-----------------ABSTRACT METHODS
	%========================================================================
		out = initialise(in)
		out = close(in)
		out = checkConnection(in)
		out = updateDefaults(in)
		out = trackerSetup(in)
		out = startRecording(in)
		out = stopRecording(in)
		out = getSample(in)
		out = trackerMessage(in)
		out = statusMessage(in)
		out = runDemo(in)
	end %---END ABSTRACT METHODS---%
		
	
	%========================================================================
	methods %----------------------------PUBLIC METHODS
	%========================================================================

		% ===================================================================
		%> @brief This is the constructor for this class
		%>
		% ===================================================================
		function me = eyetrackerCore(varargin)
			args = optickaCore.addDefaults(varargin);
			me=me@optickaCore(args); %we call the superclass constructor first
			me.parseArgs(args, me.allowedPropertiesBase);
		end

		% ===================================================================
		%> @brief reset all fixation/exclusion data
		%>
		% ===================================================================
		function resetAll(me)
			resetExclusionZones(me);
			resetFixInit(me);
			resetOffset(me);
			resetFixation(me, true);
			me.flipTick = 0;
		end
		
		% ===================================================================
		%> @brief reset the fixation counters ready for a new trial
		%>
		%> @param removeHistory remove the history of recent eye position?
		% ===================================================================
		function resetFixation(me, removeHistory)
			if ~exist('removeHistory','var'); removeHistory = false; end
			me.fixStartTime			= 0;
			me.fixLength			= 0;
			me.fixBuffer			= 0;
			me.fixInitStartTime		= 0;
			me.fixInitLength		= 0;
			me.fixTotal				= 0;
			me.fixWindow			= 0;
			me.fixN					= 0;
			me.fixSelection			= 0;
			if removeHistory
				resetFixationHistory(me);
			end
			me.isFix				= false;
			me.isBlink				= false;
			me.isExclusion			= false;
			me.isInitFail			= false;
			me.flipTick				= 0;
			if me.verbose
				fprintf('-+-+-> ET:RESET Fixation: %i %i %i\n',me.fixLength,me.fixTotal,me.fixN);
			end
		end
		
		% ===================================================================
		%> @brief reset the exclusion state ready for a new trial
		%>
		% ===================================================================
		function resetExclusionZones(me)
			me.exclusionZone = [];
		end
		
		% ===================================================================
		%> @brief reset the fixation time ready for a new trial
		%>
		% ===================================================================
		function resetFixationTime(me)
			me.fixStartTime		= 0;
			me.fixLength		= 0;
			me.fixBuffer		= 0;
		end
		
		% ===================================================================
		%> @brief reset the recent fixation history: xAll yAll pupilAll
		%>
		% ===================================================================
		function resetFixationHistory(me)
			me.xAll				= [];
			me.yAll				= [];
			me.pupilAll			= [];
			me.xAllRaw			= [];
			me.yAllRaw			= [];
		end
		
		% ===================================================================
		%> @brief reset the fixation initiation to 0
		%>
		% ===================================================================
		function resetFixInit(me)
			me.fixInit.X = [];
			me.fixInit.Y = [];
		end

		% ===================================================================
		%> @brief reset the fixation offset to 0
		%>
		% ===================================================================
		function resetOffset(me)
			me.offset.X = 0;
			me.offset.Y = 0;
		end
		
		% ===================================================================
		function success = driftOffset(me)
		%> @fn driftOffset
		%> @brief our own version of eyelink's drift correct
		%>
		% ===================================================================
			success = false;
			if ~me.isConnected || ~me.isDummy; return; end
			
			ListenChar(0);
			oldrk = RestrictKeysForKbCheck([]); %just in case someone has restricted keys
			success = false;
			if matches(me.type,'eyelink')
				startRecording(me);
				statusMessage(me,'Drift Offset Initiated');
			end
			trackerMessage(me,'Drift OFFSET');
			trackerDrawStatus(me,'Drift Offset');
			escapeKey			= KbName('ESCAPE');
			stopkey				= KbName('Q');
			nextKey				= KbName('SPACE');
			calibkey			= KbName('C');
			driftkey			= KbName('D');
			x = me.toPixels(me.fixation.X(1),'x'); %#ok<*PROP,*PROPLC>
			y = me.toPixels(me.fixation.Y(1),'y');
			Screen('Flip',me.screen.win);
			breakLoop = false; i = 1; flash = true;
			correct = false;
			xs = [];
			ys = [];
			while ~breakLoop
				getSample(me);
				xs(i) = me.x; %#ok<*AGROW>
				ys(i) = me.y;
				if mod(i,10) == 0
					flash = ~flash;
				end
				drawText(me.screen,'Drift Correction...');
				if flash
					Screen('gluDisk',me.screen.win,[1 0 1 0.75],x,y,10);
					Screen('gluDisk',me.screen.win,[1 1 1 1],x,y,4);
				else
					Screen('gluDisk',me.screen.win,[1 1 0 0.75],x,y,10);
					Screen('gluDisk',me.screen.win,[0 0 0 1],x,y,4);
				end
				me.screen.drawCross(0.6,[0 0 0],x,y,0.1,false);
				Screen('Flip',me.screen.win);
				[~, ~, keyCode] = optickaCore.getKeys;
				if keyCode(stopkey) || keyCode(escapeKey); breakLoop = true; break;	end
				if keyCode(nextKey); correct = true; break; end
				if keyCode(calibkey); trackerSetup(me); break; end
				if keyCode(driftkey); driftCorrection(me); break; end
				i = i + 1;
			end
			if correct && length(xs) > 15 && length(ys) > 15
				success = true;
				me.offset.X = median(xs(end-10:end)) - me.fixation.X(1);
				me.offset.Y = median(ys(end-10:end)) - me.fixation.Y(1);
				t = sprintf('Offset: X = %.2f Y = %.2f\n',me.offset.X,me.offset.Y);
				me.salutation('Drift [SELF]Correct',t,true);
				drawText(me.screen,t);
				flip(me.screen);
			else
				me.offset.X = 0;
				me.offset.Y = 0;
				t = sprintf('Offset: X = %.2f Y = %.2f\n',me.offset.X,me.offset.Y);
				me.salutation('REMOVE Drift [SELF]Offset',t,true);
				drawText(me.screen,'Reset Drift Offset...');
				Screen('Flip',me.screen.win);
			end
			WaitSecs('YieldSecs',1);
			RestrictKeysForKbCheck(oldrk);
		end
		
		
		% ===================================================================
		function updateFixationValues(me,x,y,inittime,fixtime,radius,strict)
		%> @fn updateFixationValues(me,x,y,inittime,fixtime,radius,strict)
		%>
		%> Sinlge method to update the fixation parameters. See property
		%> descriptions for full details. You can pass empty values if you only
		%> need to update one parameter, e.g. me.updateFixationValues([],[],1);
		%>
		%> @param x X position
		%> @param y Y position
		%> @param inittime time to initiate fixation
		%> @param fixtime time to maintain fixation
		%> @paran radius radius of fixation window
		%> @param strict allow or disallow re-entering the fixation window
		% ===================================================================
			resetFixation(me);
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
				if iscell(inittime)
					lst = {'initTime','time','radius','strict'};
					for i = 1:length(inittime)
						if contains(lst{i},'time','ignorecase',true) && length(inittime{i}) == 2
							inittime{i} = randi(inittime{i}.*1000)/1000;
						end
						me.fixation.(lst{i}) = inittime{i}(1);
					end
				elseif length(inittime) == 2
					me.fixation.initTime = randi(inittime.*1000)/1000;
				elseif length(inittime) == 1
					me.fixation.initTime = inittime;
				end
			end
			if nargin > 4 && ~isempty(fixtime)
				if length(fixtime) == 2
					me.fixation.time = randi(fixtime.*1000)/1000;
				elseif length(fixtime) == 1
					me.fixation.time = fixtime;
				end
			end
			if nargin > 5 && ~isempty(radius); me.fixation.radius = radius; end
			if nargin > 6 && ~isempty(strict); me.fixation.strict = strict; end
			if me.verbose 
				fprintf('-+-+-> ET:updateFixationValues: X=%g | Y=%g | IT=%s | FT=%s | R=%g | Strict=%i\n', ... 
				me.fixation.X, me.fixation.Y, num2str(me.fixation.initTime,'%.2f '), num2str(me.fixation.time,'%.2f '), ...
				me.fixation.radius,me.fixation.strict); 
			end
		end
		
		% ===================================================================
		%> @brief Sinlge method to update the exclusion zones, can pass multiple
		%> x & y values for multiple exclusion zones, sharing the same radius
		%>
		%> @param x x position[s] in degrees
		%> @param y y position[s] in degrees
		%> @param radius the radius of the exclusion zone, if length=2 becomes WxH
		% ===================================================================
		function updateExclusionZones(me,x,y,radius)
			resetExclusionZones(me);
			if exist('x','var') && exist('y','var') && ~isempty(x) && ~isempty(y)
				if ~exist('radius','var'); radius = 5; end
				for i = 1:length(x)
					if length(radius) == 2
						me.exclusionZone(i,:) = [x(i)-radius(1) x(i)+radius(1) y(i)-radius(2) y(i)+radius(2)];
					else
						me.exclusionZone(i,:) = [x(i)-radius x(i)+radius y(i)-radius y(i)+radius];
					end
				end
			end
		end
		
		% ===================================================================
		%> @brief isFixated tests for fixation and updates the fixLength time
		%>
		%> @return fixated boolean if we are fixated
		%> @return fixtime boolean if we're fixed for fixation time
		%> @return searching boolean for if we are still searching for fixation
		%> @return window which fixation window matched
		%> @return exclusion was any exclusion window entered?
		%> @return fixinit did subject break fixinit rule?
		% ===================================================================
		function [fixated, fixtime, searching, window, exclusion, fixinit] = isFixated(me)
			fixated = false; fixtime = false; searching = true; 
			exclusion = false; window = []; fixinit = false;
			
			if me.isExclusion || me.isInitFail
				exclusion = me.isExclusion; fixinit = me.isInitFail; searching = false;
				return; % we previously matched either rule, now cannot pass fixation until a reset.
			end

			if isempty(me.currentSample) || ~me.currentSample.valid; return; end

			if me.fixInitStartTime == 0
				me.fixInitStartTime = me.currentSample.time;
				me.fixStartTime = 0;
				me.fixLength = 0;
				me.fixBuffer = 0;
				me.fixTotal = 0;
				me.fixInitLength = 0;
			else
				me.fixTotal = me.currentSample.time - me.fixInitStartTime;
			end
			
			% ---- add any offsets for following calculations
			x = me.x - me.offset.X; y = me.y - me.offset.Y;
			if isempty(x) || isempty(y); return; end
			
			% ---- test for exclusion zones first
			if ~isempty(me.exclusionZone)
				for i = 1:size(me.exclusionZone,1)
					if (x >= me.exclusionZone(i,1) && x <= me.exclusionZone(i,2)) && ...
						(me.y >= me.exclusionZone(i,3) && me.y <= me.exclusionZone(i,4))
						searching = false; exclusion = true; 
						me.isExclusion = true; me.isFix = false;
						return;
					end
				end
			end
			
			% ---- test for fix initiation start window
			if ~isempty(me.fixInit.X) && me.fixTotal <= me.fixInit.time
				r = sqrt((x - me.fixInit.X).^2 + (y - me.fixInit.Y).^2);
				window = find(r < me.fixInit.radius);
				if ~any(window)
					searching = false; fixinit = true;
					me.isInitFail = true; me.isFix = false;
					if me.verbose;fprintf('-+-+-> ET: Eye left fix init window @ %.3f secs!\n',ft);end
					return;
				end
			end
			
			% now test if we are still searching or in fixation window, if
			% radius is single value, assume circular, otherwise assume
			% rectangular
			w = 0;
			if length(me.fixation.radius) == 1 % circular test
				r = sqrt((x - me.fixation.X).^2 + (y - me.fixation.Y).^2); %fprintf('x: %g-%g y: %g-%g r: %g-%g\n',x, me.fixation.X, me.y, me.fixation.Y,r,me.fixation.radius);
				w = find(r < me.fixation.radius);
			else % x y rectangular window test
				for i = 1:length(me.fixation.X)
					if (x >= (me.fixation.X - me.fixation.radius(1))) && (x <= (me.fixation.X + me.fixation.radius(1))) ...
							&& (me.y >= (me.fixation.Y - me.fixation.radius(2))) && (me.y <= (me.fixation.Y + me.fixation.radius(2)))
						w = i; break;
					end
				end
			end
			if ~isempty(w) && w > 0; me.fixWindow = w; else; me.fixWindow = 0; end

			% logic if we are in or not in a fixation window
			if me.fixWindow > 0 % inside fixation window
				if me.fixStartTime == 0
					me.fixN = me.fixN + 1;
					me.fixStartTime = me.currentSample.time;
				end
				if me.fixN == 1
					me.fixSelection = me.fixWindow;
				end
				if me.fixSelection == me.fixWindow
					fixated = true; searching = false;
					me.fixLength = (me.currentSample.time - me.fixStartTime);
					if me.fixLength + me.fixBuffer >= me.fixation.time
						fixtime = true;
					end
				else
					fixated = false; fixtime = false; searching = false;
				end
				me.isFix = fixated; me.fixInitLength = 0;
			else % not inside the fixation window
				me.fixInitLength = (me.currentSample.time - me.fixInitStartTime);
				if me.fixInitLength < me.fixation.initTime
					searching = true;
				else
					searching = false;
				end
				me.isFix = false; 
				if me.fixation.strict
					me.fixLength = 0;
					me.fixBuffer = 0;
				elseif ~me.fixation.strict && me.fixStartTime > 0
					me.fixBuffer = me.fixBuffer + me.fixLength;
				end
				me.fixStartTime = 0;
			end
		end
		
		% ===================================================================
		%> @brief testExclusion 
		%> 
		%>
		% ===================================================================		
		function out = testExclusion(me)
			out = false;
			if (me.isConnected || me.isDummy) && ~isempty(me.currentSample) && ~isempty(me.exclusionZone)
				eZ = me.exclusionZone; x = me.x - me.offset.X; y = me.y - me.offset.Y;
				for i = 1:size(eZ,1)
					if (x >= eZ(i,1) && x <= eZ(i,2)) && (y >= eZ(i,3) && y <= eZ(i,4))
						out = true;
						return
					end
				end
			end
		end
		
		% ===================================================================
		%> @brief Checks for both searching and then maintaining fix. Input is
		%> 2 strings, either one is returned depending on success or
		%> failure, 'searching' may also be returned meaning the fixation
		%> window hasn't been entered yet, and 'fixing' means the fixation
		%> time is not yet met...
		%>
		%> @param yesString if this function succeeds return this string
		%> @param noString if this function fails return this string
		%> @return out the output string which is 'searching' if fixation has
		%>   been initiated, 'fixing' if the fixation window was entered
		%>   but not for the requisite fixation time, 'EXCLUDED!' if an exclusion
		%>   zone was entered or the yesString or noString.
		% ===================================================================
		function [out, window, exclusion, initfail] = testSearchHoldFixation(me, yesString, noString)
			[fix, fixtime, searching, window, exclusion, initfail] = me.isFixated();
			if exclusion
				out = noString;
				if me.verbose; fprintf('-+-+-> ET:testSearchHoldFixation EXCLUSION ZONE ENTERED time:[%.2f %.2f %.2f] f:%i ft:%i s:%i e:%i fi:%i\n', ...
						me.fixTotal, me.fixInitLength, me.fixLength, fix, fixtime, searching, exclusion, initfail); end
				return;
			end
			if initfail
				out = noString;
				if me.verbose; fprintf('-+-+-> ET:testSearchHoldFixation FIX INIT TIME FAIL time:[%.2f %.2f %.2f] f:%i ft:%i s:%i e:%i fi:%i\n', ...
						me.fixTotal, me.fixInitLength, me.fixLength, fix, fixtime, searching, exclusion, initfail); end
				return
			end
			if searching
				if (me.fixation.strict == true && me.fixN == 0) || me.fixation.strict==false
					out = 'searching';
				else
					out = noString;
					if me.verbose; fprintf('-+-+-> ET:testSearchHoldFixation STRICT SEARCH FAIL: %s time:[%.2f %.2f %.2f] f:%i ft:%i s:%i e:%i fi:%i\n', ...
							out, me.fixTotal, me.fixInitLength, me.fixLength, fix, fixtime, searching, exclusion, initfail);end
				end
				return
			elseif fix
				if (me.fixation.strict==true && me.fixN == 1) || me.fixation.strict==false
					if fixtime
						out = yesString;
						if me.verbose; fprintf('-+-+-> ET:testSearchHoldFixation FIXATION SUCCESSFUL!: %s time:[%.2f %.2f %.2f] f:%i ft:%i s:%i e:%i fi:%i\n', ...
								out, me.fixTotal, me.fixInitLength, me.fixLength, fix, fixtime, searching, exclusion, initfail);end
					else
						out = 'fixing';
					end
				else
					out = noString;
					if me.verbose;fprintf('-+-+-> ET:testSearchHoldFixation FIX FAIL: %s time:[%.2f %.2f %.2f] f:%i ft:%i s:%i e:%i fi:%i\n', ...
							out, me.fixTotal, me.fixInitLength, me.fixLength, fix, fixtime, searching, exclusion, initfail);end
				end
				return
			elseif searching == false
				out = noString;
				if me.verbose;fprintf('-+-+-> ET:testSearchHoldFixation SEARCH FAIL: %s time:[%.2f %.2f %.2f] f:%i ft:%i s:%i e:%i fi:%i\n', ...
						out, me.fixTotal, me.fixInitLength, me.fixLength, fix, fixtime, searching, exclusion, initfail);end
			else
				out = '';
			end
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
		function [out, window, exclusion, initfail] = testHoldFixation(me, yesString, noString)
			[fix, fixtime, searching, window, exclusion, initfail] = me.isFixated();
			if exclusion
				out = noString;
				if me.verbose; fprintf('-+-+-> ET:testHoldFixation EXCLUSION ZONE ENTERED time:[%.2f %.2f %.2f] f:%i ft:%i s:%i e:%i fi:%i\n', ...
						me.fixTotal, me.fixInitLength, me.fixLength, fix, fixtime, searching, exclusion, initfail); end
				return;
			end
			if initfail
				out = noString;
				if me.verbose; fprintf('-+-+-> ET:testHoldFixation FIX INIT TIME FAIL time:[%.2f %.2f %.2f] f:%i ft:%i s:%i e:%i fi:%i\n', ...
						me.fixTotal, me.fixInitLength, me.fixLength, fix, fixtime, searching, exclusion, initfail); end
				return
			end
			if fix
				if (me.fixation.strict == true && me.fixN == 1) || me.fixation.strict==false
					if fixtime
						out = yesString;
						if me.verbose; fprintf('-+-+-> ET:testHoldFixation FIXATION SUCCESSFUL!: %s time:[%.2f %.2f %.2f] f:%i ft:%i s:%i e:%i fi:%i\n', ...
							out, me.fixTotal, me.fixInitLength, me.fixLength, fix, fixtime, searching, exclusion, initfail);end
					else
						out = 'fixing';
					end
					return;
				else
					out = noString;
					if me.verbose;fprintf('-+-+-> ET:testHoldFixation FIX FAIL: %s time:[%.2f %.2f %.2f] f:%i ft:%i s:%i e:%i fi:%i\n', ...
							out, me.fixTotal, me.fixInitLength, me.fixLength, fix, fixtime, searching, exclusion, initfail);end
					return;
				end
			else
				out = noString;
				if me.verbose; fprintf('-+-+-> ET:testHoldFixation FIX FAIL: %s time:[%.2f %.2f %.2f] f:%i ft:%i s:%i e:%i fi:%i\n', ...
							out, me.fixTotal, me.fixInitLength, me.fixLength, fix, fixtime, searching, exclusion, initfail);end
				return;
			end
		end

		% ===================================================================
		%> @brief testWithinFixationWindow simply tests we are in fixwindow
		%> 
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
		%> external code to quickly select a string based on this. Use
		% testHoldFixation() if you want to maintain fixation with a window
		% for a certain time...
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
		%> @brief checks which eye is available, force left eye if
		%> binocular is enabled
		%>
		% ===================================================================
		function eyeUsed = checkEye(me)
			eyeUsed = 'both';
		end
		
		% ===================================================================
		%> @brief draw the current eye position on the main PTB display
		%>
		% ===================================================================
		function drawEyePosition(me,varargin)
			if (me.isDummy || me.isConnected) && isa(me.screen,'screenManager') && me.screen.isOpen && ~isempty(me.x) && ~isempty(me.y)
				xy = toPixels(me,[me.x-me.offset.X me.y-me.offset.Y]);
				if me.isFix
					if me.fixLength+me.fixBuffer > me.fixation.time && ~me.isBlink
						Screen('DrawDots', me.screen.win, xy, me.eyeSize, [0 1 0.25 1], [], 3);
					elseif ~me.isBlink
						Screen('DrawDots', me.screen.win, xy, me.eyeSize, [0.75 0 0.75 1], [], 3);
					else
						Screen('DrawDots', me.screen.win, xy, me.eyeSize, [0.75 0 0 1], [], 3);
					end
				else
					if ~me.isBlink
						Screen('DrawDots', me.screen.win, xy, me.eyeSize, [0.75 0.5 0 1], [], 3);
					else
						Screen('DrawDots', me.screen.win, xy, me.eyeSize, [0.75 0 0 1], [], 3);
					end
				end
			end
		end

		% ===================================================================
		%> @brief draw the sampled eye positions in xAll yAll on the subject
		%> screen
		%>
		% ===================================================================
		function drawEyePositions(me)
			if (me.isDummy || me.isConnected) && isa(me.screen,'screenManager') && me.screen.isOpen && ~isempty(me.xAll)
				xy = [me.xAll;me.yAll];
				drawDots(me.operatorScreen, xy, me.eyeSize, [0.5 0.9 0 0.2]);
			end
		end

		% ===================================================================
		%> @brief draw the background colour
		%>
		% ===================================================================
		function trackerClearScreen(me)
			if ~me.isConnected || ~me.operatorScreen.isOpen; return;end
			drawBackground(me.operatorScreen);
		end

		% ===================================================================
		%> @brief draw general status
		%>
		% ===================================================================
		function trackerDrawStatus(me, comment, stimPos, dontClear)
			if ~exist('comment','var'); comment=''; end
			if ~exist('stimPos','var'); stimPos = []; end
			if ~exist('dontClear','var'); dontClear = 0; end
			
			if dontClear==0; trackerFlip(me, 0, true); trackerClearScreen(me); end
			trackerDrawFixation(me);
			drawGrid(me.operatorScreen);
			if ~isempty(me.exclusionZone);trackerDrawExclusion(me);end
			if ~isempty(stimPos); trackerDrawStimuli(me, stimPos, true); end
			if ~isempty(comment);trackerDrawText(me, comment);end
			if ~isempty(me.xAll);trackerDrawEyePositions(me);end
			
			trackerFlip(me, 1, true);
		end

		% ===================================================================
		%> @brief draw the stimuli boxes on the tracker display
		%>
		% ===================================================================
		function trackerDrawStimuli(me, ts, dontClear)
			if exist('ts','var') && isstruct(ts) && isfield(ts,'x')
				me.stimulusPositions = ts;
			else
				return
			end
			if ~exist('dontClear','var');dontClear = true;end
			if dontClear==false; trackerClearScreen(me); end
			for i = 1:length(me.stimulusPositions)
				x = me.stimulusPositions(i).x;
				y = me.stimulusPositions(i).y;
				size = me.stimulusPositions(i).size;
				if isempty(size); size = 1; end
				fprintf('eT Stim: %.2fx %.2fy %.2fsz\n',x,y,size)
				if me.stimulusPositions(i).selected == true
					drawBox(me.operatorScreen,[x; y],size,[0.5 1 0 0.5]);
				else
					drawBox(me.operatorScreen,[x; y],size,[0.6 0.6 0.3 0.5]);
				end
			end			
		end
		
		% ===================================================================
		%> @brief draw the fixation box on the tracker display
		%>
		% ===================================================================
		function trackerDrawFixation(me)
			if length(me.fixation.radius) == 1
				drawSpot(me.operatorScreen,me.fixation.radius,[0.5 0.6 0.5 0.7],me.fixation.X,me.fixation.Y);
			else
				rect = [me.fixation.X - me.fixation.radius(1), ...
					me.fixation.Y - me.fixation.radius(2), ...
					me.fixation.X + me.fixation.radius(1), ...
					me.fixation.Y + me.fixation.radius(2)];
				drawRect(me.operatorScreen,rect,[0.5 0.6 0.5 0.7]);
			end
		end

		% ===================================================================
		%> @brief draw the fixation box on the tracker display
		%>
		% ===================================================================
		function trackerDrawExclusion(me)
			if isempty(me.exclusionZone); return; end
			for i = 1:size(me.exclusionZone,1)
				drawRect(me.operatorScreen, [me.exclusionZone(1), ...
					me.exclusionZone(3), me.exclusionZone(2), ...
					me.exclusionZone(4)],[0.7 0.6 0.6 0.5]);
			end
		end
		
		
		% ===================================================================
		%> @brief draw the fixation position on the tracker display
		%>
		% ===================================================================
		function trackerDrawEyePosition(me)
			if isempty(me.x) || isempty(me.y); return;end
			if me.isFix
				if me.fixLength+me.fixBuffer > me.fixation.time
					drawSpot(me.operatorScreen,0.5,[0 1 0.25 0.7],me.x,me.y);
				else
					drawSpot(me.operatorScreen,0.5,[0.75 0.25 0.75 0.7],me.x,me.y);
				end
			else
				drawSpot(me.operatorScreen,0.5,[0.7 0.5 0 0.5],me.x,me.y);
			end
		end
		
		% ===================================================================
		%> @brief draw the sampled eye positions in xAll yAll
		%>
		% ===================================================================
		function trackerDrawEyePositions(me)
			if ~isempty(me.xAll) && ~isempty(me.yAll) && (length(me.xAll)==length(me.yAll))
				xy = [me.xAll;me.yAll];
				drawDots(me.operatorScreen,xy,0.4,[0.5 0.9 0.2 0.2]);
			end
		end

		% ===================================================================
		%> @brief draw the fixation box on the tracker display
		%>
		% ===================================================================
		function trackerDrawText(me,textIn)
			if ~exist('textIn','var'); return; end
			drawText(me.operatorScreen, textIn);
		end

		% ===================================================================
		%> @brief flip the tracker display
		%>
		%> remember: dontclear affects the NEXT flip, not this one!
		% ===================================================================
		function trackerFlip(me, dontclear, force)
			if ~exist('dontclear','var'); dontclear = 1; end
			if ~exist('force','var'); force = false; end

			me.flipTick = me.flipTick + 1;
			if force || me.flipTick >= me.skipFlips; me.flipTick = 1; end
			if me.flipTick ~=1; return; end

			if dontclear ~= 1; dontclear = 0; end
			% Screen('Flip', windowPtr [, when] [, dontclear] [, dontsync] [, multiflip]);
			me.operatorScreen.flip([], dontclear, 2);
		end
		
	end%-------------------------END PUBLIC METHODS--------------------------------%
	
	%=======================================================================
	methods (Hidden = true) %------------------HIDDEN METHODS
	%=======================================================================
		
		% ===================================================================
		%> @brief send message to store in EDF data
		% ===================================================================
		function edfMessage(me, message)
			me.trackerMessage(message)
		end

		% ===================================================================
		%> @brief TODO
		%>
		% ===================================================================
		function evt = getEvent(me)
			
		end

		% ===================================================================
		%> @brief compatibility with tobiiManager
		%>
		% ===================================================================
		function saveData(me,args)
			
		end
		
	
	end
	
	
	%=======================================================================
	methods (Access = protected) %------------------PROTECTED METHODS
	%=======================================================================

	function drawValidationResults(me, n)
			if isempty(me.validationData); return; end
			try %#ok<*TRYNC>
				if ~exist('n','var') || n > length(me.validationData); n = length(me.validationData); end
				vd = me.validationData(n);
				s = me.operatorScreen;
				for jj = 1:length(vd.vpos)
					if ~strcmpi(vd.type,'sample')
						thisPos = [vd.vpos(jj,1),vd.vpos(jj,2)];
						drawCross(s, 1,[],thisPos(1),thisPos(2));
						if ~isempty(vd.data{jj}) && size(vd.data{jj},1)==2
							x = vd.data{jj}(1,:); y = vd.data{jj}(2,:);
							xm = median(x); ym = median(y);
							xd = abs(vd.vpos(jj,1) - xm);
							yd = abs(vd.vpos(jj,2) - ym);
							xv = rmse( x - xm, 0);
							yv = rmse( y - ym, 0);
							txt = sprintf('A:%.1g %.1g P:%.2g %.2g', xd, yd, xv, yv);
							a = 1;
							xyl = zeros(2,length(vd.data{jj})*2);
							for i = 1:length(vd.data{jj})
								xyl(:,a) = vd.data{jj}(:,i);
								xyl(:,a+1) = thisPos;
								a = a + 2;
							end
							drawLines(s,xyl,0.1,[0.95 0.65 0 0.1]); 
							drawDotsDegs(s,vd.dataS{jj},0.5,[1 1 0 0.35]);
							drawText(s,txt,xm-2.5,ym+0.75);
						end
					else
						vpos = me.calibration.valPositions;
						for kk = 1:length(vpos)
							drawCross(s, 1,[],vpos(kk,1),vpos(kk,2));
						end
						if ~isempty(vd.data{jj}) && size(vd.data{jj},1)==2
							x = vd.data{jj}(1,:); y = vd.data{jj}(2,:);
							xm = median(x); ym = median(y);
							drawDotsDegs(s,vd.data{jj},0.5,[1 0.6 0 0.25]);
							t = sprintf('#%i %.2gx %.2gy',jj,xm,ym);
							try 
								drawText(s,t,xm-2.5,ym+0.75); 
							end
						end
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
		%> @brief to pixels from visual degrees / relative
		%> input can be [x] [y] [-x -y +x +y]('rect') [xy] or [-x +x -y +y]
		% ===================================================================
		function out = toPixels(me, in, axis, inputtype)
			if ~exist('axis','var') || isempty(axis); axis=''; end
			if ~exist('inputtype','var') || isempty(inputtype); inputtype = 'degrees'; end
			out = zeros(size(in));
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
				case 'rect'
					switch inputtype
						case 'degrees'
							w = ([in(1) in(3)] * me.ppd_) + me.screen.xCenter;
							h = ([in(2) in(4)] * me.ppd_) + me.screen.yCenter;
							out = [w(1) h(1) w(2) h(2)];
						case 'relative'
							w = [in(1) in(3)] * me.screen.screenVals.width;
							h = [in(2) in(4)] * me.screen.screenVals.height;
							out = [w(1) h(1) w(2) h(2)];
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
		
		
		
	end
	
end


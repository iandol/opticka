% ========================================================================
%> @class eyeTracker CORE -- parent class for all eyetrackers
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
%> WIP
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
		%> radius!)
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
		fixInit				= struct('X',[],'Y',[],'time',0.1,'radius',2)
		%> add a manual offset to the eye position, similar to a drift correction
		%> but handled by the eyelinkManager.
		offset				= struct('X',0,'Y',0)
		%> tracker update speed (Hz)
		sampleRate			= 300
		%> start eyetracker in dummy mode?
		isDummy				= false
		%> do we record and retrieve eyetracker EDF file?
		recordData			= true
		%> use an operator screen for calibration etc.
		useOperatorScreen	= false
		%> do we ignore blinks, if true then we do not update X and Y position
		%> from previous eye location, meaning the various methods will maintain
		%> position, e.g. if you are fixated and blink, the within-fixation X
		%> and Y position are retained so that a blink does not "break"
		%> fixation. a blink is defined as a state whre gx and gy are MISSING
		%> and pa is 0. Technically we can't really tell if a subject is
		%> blinking or has removed their head using the float data.
		ignoreBlinks		= false
		%> name of eyetracker EDF file
		saveFile			= 'myData'
		%> do we log messages to the command window?
		verbose					= false
	end

	properties (Abstract)
		%> info for calibration
		calibration
	end
	
	properties (Hidden = true)
		%> stimulus positions to draw on screen
		stimulusPositions		= []
		%> the PTB screen to work on, passed in during initialise
		screen					= []
		%> operator screen used during calibration
		operatorScreen			= []
		%> is operator screen being used?
		secondScreen			= false
		%> size to draw eye position on screen
		eyeSize double					= 6
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
		%> total time searching and holding fixation
		fixTotal				= 0
		%> Initiate fixation length
		fixInitLength			= 0
		%how long have we been fixated?
		fixLength				= 0
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
	end
	
	properties (SetAccess = protected, GetAccess = ?optickaCore)
		%> the PTB screen handle, normally set by screenManager but can force it to use another screen
		win						= []
		ppd_					= 36
		% these are used to test strict fixation
		fixN double				= 0
		fixSelection			= []
		%> allowed properties passed to object upon construction
		allowedPropertiesBase	= {'fixation', 'exclusionZone', 'fixInit', ...
			'offset', 'sampleRate', 'ignoreBlinks', 'saveData',...
			'recordData', 'verbose', 'isDummy', 'manualCalibration'}
	end

	%> ALL Children must implement these methods!
	%=======================================================================
	methods (Abstract)%------------------ABSTRACT METHODS
	%=======================================================================
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
		
	
	methods
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
		%> @brief reset the fixation counters ready for a new trial
		%>
		%> @param removeHistory remove the history of recent eye position?
		% ===================================================================
		function resetFixation(me,removeHistory)
			if ~exist('removeHistory','var');removeHistory=false;end
			me.fixStartTime			= 0;
			me.fixLength			= 0;
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
			if me.verbose
				fprintf('-+-+-> Eye Tracker:reset fixation: %i %i %i\n',me.fixLength,me.fixTotal,me.fixN);
			end
		end
		
		% ===================================================================
		%> @brief reset the fixation counters ready for a new trial
		%>
		% ===================================================================
		function resetExclusionZones(me)
			me.exclusionZone = [];
		end
		
		% ===================================================================
		%> @brief reset the fixation counters ready for a new trial
		%>
		% ===================================================================
		function resetFixationTime(me)
			me.fixStartTime		= 0;
			me.fixLength		= 0;
		end
		
		% ===================================================================
		%> @brief reset the fixation history: xAll yAll pupilAll
		%>
		% ===================================================================
		function resetFixationHistory(me)
			me.xAll				= [];
			me.yAll				= [];
			me.pupilAll			= [];
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
		%> @brief reset the fixation offset to 0
		%>
		% ===================================================================
		function resetFixInit(me)
			me.fixInit.X = [];
			me.fixInit.Y = [];
		end
		
		% ===================================================================
		function success = driftOffset(me)
		%> @fn driftOffset
		%> @brief wrapper for EyelinkDoDriftCorrection
		%>
		% ===================================================================
			success = false;
			escapeKey			= KbName('ESCAPE');
			stopkey				= KbName('Q');
			nextKey				= KbName('SPACE');
			calibkey			= KbName('C');
			driftkey			= KbName('D');
			if me.isConnected || me.isDummy
				x = me.toPixels(me.fixation.X,'x'); %#ok<*PROPLC>
				y = me.toPixels(me.fixation.Y,'y');
				Screen('Flip',me.screen.win);
				ifi = me.screen.screenVals.ifi;
				breakLoop = false; i = 1; flash = true;
				correct = false;
				xs = [];
				ys = [];
				while ~breakLoop
					getSample(me);
					xs(i) = me.x;
					ys(i) = me.y;
					if mod(i,10) == 0
						flash = ~flash;
					end
					Screen('DrawText',me.screen.win,'Drift Correction...',10,10,[0.4 0.4 0.4]);
					if flash
						Screen('gluDisk',me.screen.win,[1 0 1 0.75],x,y,10);
						Screen('gluDisk',me.screen.win,[1 1 1 1],x,y,4);
					else
						Screen('gluDisk',me.screen.win,[1 1 0 0.75],x,y,10);
						Screen('gluDisk',me.screen.win,[0 0 0 1],x,y,4);
					end
					me.screen.drawCross(0.6,[0 0 0],x,y,0.1,false);
					Screen('Flip',me.screen.win);
					[~, ~, keyCode] = KbCheck(-1);
					if keyCode(stopkey) || keyCode(escapeKey); breakLoop = true; break;	end
					if keyCode(nextKey); correct = true; break; end
					if keyCode(calibkey); trackerSetup(me); break; end
					if keyCode(driftkey); driftCorrection(me); break; end
					i = i + 1;
				end
				if correct && length(xs) > 5 && length(ys) > 5
					success = true;
					me.offset.X = median(xs) - me.fixation.X;
					me.offset.Y = median(ys) - me.fixation.Y;
					t = sprintf('Offset: X = %.2f Y = %.2f\n',me.offset.X,me.offset.Y);
					me.salutation('Drift [SELF]Correct',t,true);
					Screen('DrawText',me.screen.win,t,10,10,[0.4 0.4 0.4]);
					Screen('Flip',me.screen.win);
				else
					me.offset.X = 0;
					me.offset.Y = 0;
					t = sprintf('Offset: X = %.2f Y = %.2f\n',me.offset.X,me.offset.Y);
					me.salutation('REMOVE Drift [SELF]Offset',t,true);
					Screen('DrawText',me.screen.win,'Reset Drift Offset...',10,10,[0.4 0.4 0.4]);
					Screen('Flip',me.screen.win);
				end
				WaitSecs('YieldSecs',1);
			end
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
				fprintf('-+-+-> eyetrackerManager:updateFixationValues: X=%g | Y=%g | IT=%s | FT=%s | R=%g | Strict=%i\n', ... 
				me.fixation.X, me.fixation.Y, num2str(me.fixation.initTime,'%.2f '), num2str(me.fixation.time,'%.2f '), ...
				me.fixation.radius,me.fixation.strict); 
			end
		end
		
		% ===================================================================
		%> @brief Sinlge method to update the exclusion zones
		%>
		%> @param x x position in degrees
		%> @param y y position in degrees
		%> @param radius the radius of the exclusion zone
		% ===================================================================
		function updateExclusionZones(me,x,y,radius)
			resetExclusionZones(me);
			if exist('x','var') && exist('y','var') && ~isempty(x) && ~isempty(y)
				if ~exist('radius','var'); radius = 5; end
				for i = 1:length(x)
					me.exclusionZone(i,:) = [x(i)-radius x(i)+radius y(i)-radius y(i)+radius];
				end
			end
		end
		
		% ===================================================================
		%> @brief isFixated tests for fixation and updates the fixLength time
		%>
		%> @return fixated boolean if we are fixated
		%> @return fixtime boolean if we're fixed for fixation time
		%> @return searching boolean for if we are still searching for fixation
		% ===================================================================
		function [fixated, fixtime, searching, window, exclusion, fixinit] = isFixated(me)
			fixated = false; fixtime = false; searching = true; 
			exclusion = false; window = []; fixinit = false;
			
			if isempty(me.currentSample); return; end
			
			if me.isExclusion || me.isInitFail
				exclusion = me.isExclusion; fixinit = me.isInitFail; searching = false;
				return; % we previously matched either rule, now cannot pass fixation until a reset.
			end
			if me.fixInitStartTime == 0
				me.fixInitStartTime = me.currentSample.time;
				me.fixTotal = 0;
				me.fixInitLength = 0;
			end
			
			% ---- add any offsets for following calculations
			x = me.x - me.offset.X; y = me.y - me.offset.Y;
			
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
			ft = (me.currentSample.time - me.fixInitStartTime) / 1e3;
			if ~isempty(me.fixInit.X) && ft <= me.fixInit.time
				r = sqrt((x - me.fixInit.X).^2 + (y - me.fixInit.Y).^2);
				window = find(r < me.fixInit.radius);
				if ~any(window)
					searching = false; fixinit = true;
					me.isInitFail = true; me.isFix = false;
					fprintf('-+-+-> eyelinkManager: Eye left fix init window @ %.3f secs!\n',ft);
					return;
				end
			end
			% now test if we are still searching or in fixation window, if
			% radius is single value, assume circular, otherwise assume
			% rectangular
			window = 0;
			if length(me.fixation.radius) == 1 % circular test
				r = sqrt((x - me.fixation.X).^2 + (y - me.fixation.Y).^2); %fprintf('x: %g-%g y: %g-%g r: %g-%g\n',x, me.fixation.X, me.y, me.fixation.Y,r,me.fixation.radius);
				window = find(r < me.fixation.radius);
			else % x y rectangular window test
				for i = 1:length(me.fixation.X)
					if (x >= (me.fixation.X - me.fixation.radius(1))) && (x <= (me.fixation.X + me.fixation.radius(1))) ...
							&& (me.y >= (me.fixation.Y - me.fixation.radius(2))) && (me.y <= (me.fixation.Y + me.fixation.radius(2)))
						window = i;break;
					end
				end
			end
			me.fixWindow = window;
			me.fixTotal = (me.currentSample.time - me.fixInitStartTime) / 1e3;
			if any(window) % inside fixation window
				if me.fixN == 0
					me.fixN = 1;
					me.fixSelection = window(1);
				end
				if me.fixSelection == window(1)
					if me.fixStartTime == 0
						me.fixStartTime = me.currentSample.time;
					end
					fixated = true; searching = false;
					me.fixLength = (me.currentSample.time - me.fixStartTime) / 1e3;
					if me.fixLength >= me.fixation.time
						fixtime = true;
					end
				else
					fixated = false; fixtime = false; searching = false;
				end
				me.isFix = fixated; me.fixInitLength = 0;
			else % not inside the fixation window
				if me.fixN == 1
					me.fixN = -100;
				end
				me.fixInitLength = (me.currentSample.time - me.fixInitStartTime) / 1e3;
				if me.fixInitLength < me.fixation.initTime
					searching = true;
				else
					searching = false;
				end
				me.isFix = false; me.fixLength = 0; me.fixStartTime = 0;
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
				if me.verbose; fprintf('-+-+-> Eyelink:testSearchHoldFixation EXCLUSION ZONE ENTERED time:[%.2f %.2f %.2f] f:%i ft:%i s:%i e:%i fi:%i\n', ...
						me.fixTotal, me.fixInitLength, me.fixLength, fix, fixtime, searching, exclusion, initfail); end
				return;
			end
			if initfail
				out = noString;
				if me.verbose; fprintf('-+-+-> Eyelink:testSearchHoldFixation FIX INIT TIME FAIL time:[%.2f %.2f %.2f] f:%i ft:%i s:%i e:%i fi:%i\n', ...
						me.fixTotal, me.fixInitLength, me.fixLength, fix, fixtime, searching, exclusion, initfail); end
				return
			end
			if searching
				if (me.fixation.strict==true && (me.fixN == 0)) || me.fixation.strict==false
					out = 'searching';
				else
					out = noString;
					if me.verbose; fprintf('-+-+-> Eyelink:testSearchHoldFixation STRICT SEARCH FAIL: %s time:[%.2f %.2f %.2f] f:%i ft:%i s:%i e:%i fi:%i\n', ...
							out, me.fixTotal, me.fixInitLength, me.fixLength, fix, fixtime, searching, exclusion, initfail);end
				end
				return
			elseif fix
				if (me.fixation.strict==true && ~(me.fixN == -100)) || me.fixation.strict==false
					if fixtime
						out = yesString;
						if me.verbose; fprintf('-+-+-> Eyelink:testSearchHoldFixation FIXATION SUCCESSFUL!: %s time:[%.2f %.2f %.2f] f:%i ft:%i s:%i e:%i fi:%i\n', ...
								out, me.fixTotal, me.fixInitLength, me.fixLength, fix, fixtime, searching, exclusion, initfail);end
					else
						out = 'fixing';
					end
				else
					out = noString;
					if me.verbose;fprintf('-+-+-> Eyelink:testSearchHoldFixation FIX FAIL: %s time:[%.2f %.2f %.2f] f:%i ft:%i s:%i e:%i fi:%i\n', ...
							out, me.fixTotal, me.fixInitLength, me.fixLength, fix, fixtime, searching, exclusion, initfail);end
				end
				return
			elseif searching == false
				out = noString;
				if me.verbose;fprintf('-+-+-> Eyelink:testSearchHoldFixation SEARCH FAIL: %s time:[%.2f %.2f %.2f] f:%i ft:%i s:%i e:%i fi:%i\n', ...
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
				if me.verbose; fprintf('-+-+-> Eyelink:testHoldFixation EXCLUSION ZONE ENTERED time:[%.2f %.2f %.2f] f:%i ft:%i s:%i e:%i fi:%i\n', ...
						me.fixTotal, me.fixInitLength, me.fixLength, fix, fixtime, searching, exclusion, initfail); end
				return;
			end
			if initfail
				out = noString;
				if me.verbose; fprintf('-+-+-> Eyelink:testHoldFixation FIX INIT TIME FAIL time:[%.2f %.2f %.2f] f:%i ft:%i s:%i e:%i fi:%i\n', ...
						me.fixTotal, me.fixInitLength, me.fixLength, fix, fixtime, searching, exclusion, initfail); end
				return
			end
			if fix
				if (me.fixation.strict==true && ~(me.fixN == -100)) || me.fixation.strict==false
					if fixtime
						out = yesString;
						if me.verbose; fprintf('-+-+-> Eyelink:testHoldFixation FIXATION SUCCESSFUL!: %s time:[%.2f %.2f %.2f] f:%i ft:%i s:%i e:%i fi:%i\n', ...
							out, me.fixTotal, me.fixInitLength, me.fixLength, fix, fixtime, searching, exclusion, initfail);end
					else
						out = 'fixing';
					end
				else
					out = noString;
					if me.verbose;fprintf('-+-+-> Eyelink:testHoldFixation FIX FAIL: %s time:[%.2f %.2f %.2f] f:%i ft:%i s:%i e:%i fi:%i\n', ...
							out, me.fixTotal, me.fixInitLength, me.fixLength, fix, fixtime, searching, exclusion, initfail);end
				end
				return
			else
				out = noString;
				if me.verbose; fprintf('-+-+-> Eyelink:testHoldFixation FIX FAIL: %s time:[%.2f %.2f %.2f] f:%i ft:%i s:%i e:%i fi:%i\n', ...
							out, me.fixTotal, me.fixInitLength, me.fixLength, fix, fixtime, searching, exclusion, initfail);end
				return
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
			if me.isConnected
				me.eyeUsed = Eyelink('EyeAvailable'); % get eye that's tracked
				if me.eyeUsed == me.defaults.BINOCULAR % if both eyes are tracked
					me.eyeUsed = me.defaults.LEFT_EYE; % use left eye
				end
				eyeUsed = me.eyeUsed;
			else
				me.eyeUsed = -1;
				eyeUsed = me.eyeUsed;
			end
		end
		
		% ===================================================================
		%> @brief draw the current eye position on the PTB display
		%>
		% ===================================================================
		function drawEyePosition(me,varargin)
			if (me.isDummy || me.isConnected) && isa(me.screen,'screenManager') && me.screen.isOpen && ~isempty(me.x) && ~isempty(me.y)
				xy = toPixels(me,[me.x-me.offset.X me.y-me.offset.Y]);
				if me.isFix
					if me.fixLength > me.fixation.time && ~me.isBlink
						Screen('DrawDots', me.win, xy, me.eyeSize, [0 1 0.25 1], [], 3);
					elseif ~me.isBlink
						Screen('DrawDots', me.win, xy, me.eyeSize, [0.75 0 0.75 1], [], 3);
					else
						Screen('DrawDots', me.win, xy, me.eyeSize, [0.75 0 0 1], [], 3);
					end
				else
					if ~me.isBlink
						Screen('DrawDots', me.win, xy, me.eyeSize, [0.75 0.5 0 1], [], 3);
					else
						Screen('DrawDots', me.win, xy, me.eyeSize, [0.75 0 0 1], [], 3);
					end
				end
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
			if ~me.isConnected || ~me.operatorScreen.isOpen; return;end
			if ~exist('comment','var'); comment=''; end
			if ~exist('stimPos','var'); stimPos = struct; end
			if ~exist('dontClear','var'); dontClear = 0; end
			if ~dontClear; trackerClearScreen(me); end
			trackerDrawExclusion(me);
			trackerDrawFixation(me);
			trackerDrawStimuli(me, stimPos);
			trackerDrawEyePositions(me);
			if ~isempty(comment);trackerDrawText(me, comment);end
			trackerFlip(me,dontClear);
		end

		% ===================================================================
		%> @brief draw the stimuli boxes on the tracker display
		%>
		% ===================================================================
		function trackerDrawStimuli(me, ts, dontClear)
			if ~me.isConnected || ~me.operatorScreen.isOpen; return; end
			if exist('ts','var') && isstruct(ts)
				me.stimulusPositions = ts;
			end
			if isempty(me.stimulusPositions) || isempty(fieldnames(me.stimulusPositions));return;end
			if ~exist('dontClear','var');dontClear = true;end
			if dontClear==false; trackerClearScreen(me); end
			for i = 1:length(me.stimulusPositions)
				x = me.stimulusPositions(i).x;
				y = me.stimulusPositions(i).y;
				size = me.stimulusPositions(i).size;
				if isempty(size); size = 1 * me.ppd_; end
				if me.stimulusPositions(i).selected == true
					drawBoxPx(me.operatorScreen,[x; y],size,[0.5 1 0 0.5]);
				else
					drawBoxPx(me.operatorScreen,[x; y],size,[0.6 0.6 0.3]);
				end
			end			
		end
		
		% ===================================================================
		%> @brief draw the fixation box on the tracker display
		%>
		% ===================================================================
		function trackerDrawFixation(me)
			if ~me.isConnected || ~me.operatorScreen.isOpen; return; end
			if length(me.fixation.radius) == 1
				drawSpot(me.operatorScreen,me.fixation.radius,[0.5 0.6 0.5 1],me.fixation.X,me.fixation.Y);
			else
				rect = [me.fixation.X - me.fixation.radius(1), ...
					me.fixation.Y - me.fixation.radius(2), ...
					me.fixation.X + me.fixation.radius(1), ...
					me.fixation.Y + me.fixation.radius(2)];
				drawRect(me.operatorScreen,rect,[0.5 0.6 0.5 1]);
			end
		end

		% ===================================================================
		%> @brief draw the fixation box on the tracker display
		%>
		% ===================================================================
		function trackerDrawExclusion(me)
			if ~me.isConnected || ~me.operatorScreen.isOpen || isempty(me.exclusionZone); return; end
			for i = 1:size(me.exclusionZone,1)
				drawRect(me.operatorScreen, [me.exclusionZone(1), ...
					me.exclusionZone(3), me.exclusionZone(2), ...
					me.exclusionZone(4)],[0.7 0.6 0.6]);
			end
		end
		
		
		% ===================================================================
		%> @brief draw the fixation position on the tracker display
		%>
		% ===================================================================
		function trackerDrawEyePosition(me)
			if ~me.isConnected || ~me.operatorScreen.isOpen; return; end
			if me.isFix
				if me.fixLength > me.fixation.time
					drawSpot(me.operatorScreen,0.3,[0 1 0.25 0.75],me.x,me.y);
				else
					drawSpot(me.operatorScreen,0.3,[0.75 0.25 0.75 0.75],me.x,me.y);
				end
			else
				drawSpot(me.operatorScreen,0.3,[0.7 0.5 0 0.5],me.x,me.y);
			end
		end
		
		% ===================================================================
		%> @brief draw the sampled eye positions in xAll yAll
		%>
		% ===================================================================
		function trackerDrawEyePositions(me)
			if ~me.isConnected || ~me.operatorScreen.isOpen; return; end
			if ~isempty(me.xAll) && ~isempty(me.yAll) && (length(me.xAll)==length(me.yAll))
				xy = [me.xAll;me.yAll];
				drawDots(me.operatorScreen,xy,8,[0.5 1 0 0.2]);
			end
		end

		% ===================================================================
		%> @brief draw the fixation box on the tracker display
		%>
		% ===================================================================
		function trackerDrawText(me,textIn)
			if ~me.isConnected || ~me.operatorScreen.isOpen || ~exist('textIn','var'); return; end
			drawText(me.operatorScreen, textIn);
		end

		% ===================================================================
		%> @brief draw the fixation box on the tracker display
		%>
		% ===================================================================
		function trackerFlip(me,dontclear)
			if ~me.isConnected || ~me.operatorScreen.isOpen; return; end
			if ~exist('dontclear','var');dontclear = 1; end
			me.operatorScreen.flip([], dontclear, 2);
		end
		
		% ===================================================================
		%> @brief automagically turn pixels to degrees
		%>
		% ===================================================================
		function set.x(me,in)
			me.x = toDegrees(me,in,'x'); %#ok<*MCSUP>
		end
		
		% ===================================================================
		%> @brief automagically turn pixels to degrees
		%>
		% ===================================================================
		function set.y(me,in)
			me.y = toDegrees(me,in,'y');
		end
		
	end%-------------------------END PUBLIC METHODS--------------------------------%
	
	%=======================================================================
	methods (Hidden = true) %------------------HIDDEN METHODS
	%=======================================================================
		
		% ===================================================================
		%> @brief send message to store in EDF data
		% ===================================================================
		function edfMessage(me, message)
			
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
	methods (Access = protected) %------------------PRIVATE METHODS
	%=======================================================================
		
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
		
		
		
	end
	
end


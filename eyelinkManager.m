classdef eyelinkManager < optickaCore
	%UNTITLED Summary of this class goes here
	%   Detailed explanation goes here
	
	properties
		screen = []
		defaults = struct()
		isDummy = false
		enableCallbacks = false
		recordData = false;
		verbose = true
		fixationX = 0
		fixationY = 0
		fixationRadius = 1
		fixationTime = 1
	end
	
	properties (SetAccess = private, GetAccess = public)
		x = []
		y = []
		pupil = []
		silentMode = false
		isConnected = false
		isRecording = false
		eyeUsed = -1
		currentEvent = []
		version = ''
		error = []
		fixStartTime = 0
		fixLength = 0
	end
	
	properties (SetAccess = private, GetAccess = private)
		%> allowed properties passed to object upon construction
		allowedProperties = 'name|verbose|isDummy|enableCallbacks'
	end
	
	methods
		% ===================================================================
		%> @brief 
		%>
		% ===================================================================
		function obj = eyelinkManager(varargin)
			if nargin>0
				obj.parseArgs(varargin,obj.allowedProperties);
			end
			obj.defaults = EyelinkInitDefaults();
			try
				Eyelink('GetTrackerVersion');
			catch %#ok<CTCH>
				obj.isDummy = true;
			end
		end
		
		
		% ===================================================================
		%> @brief 
		%>
		% ===================================================================
		function fixated = isFixated(obj)
			fixated = false;
			obj.fixLength = 0;
			if obj.isConnected && ~isempty(obj.currentEvent)
				d = (obj.x - obj.fixationX)^2 + (obj.y - obj.fixationY)^2;
				if d < (obj.fixationRadius);
					if obj.fixStartTime == 0
						obj.fixStartTime = obj.currentEvent.time;
					end
					obj.fixLength = (obj.currentEvent.time - obj.fixStartTime) / 1000;
					fixated = true;
				else
					obj.fixStartTime = 0;
				end
			end
		end
		
		% ===================================================================
		%> @brief 
		%>
		% ===================================================================
		function out = testFixation(obj, yesString, noString)
			if obj.isFixated
				out = yesString;
			else
				out = noString;
			end
		end
		
		% ===================================================================
		%> @brief 
		%>
		% ===================================================================
		function out = testFixationTime(obj, yesString, noString)
			if obj.isFixated && (obj.fixLength > obj.fixationTime)
				obj.salutation(sprintf('Fixation Time: %g',obj.fixLength),'TEST');
				out = yesString;
			else
				out = noString;
			end
		end
		
		% ===================================================================
		%> @brief 
		%>
		% ===================================================================
		function resetFixation(obj)
			obj.salutation(sprintf('Fixation Time was: %g',obj.fixLength),'resetFixation');
			obj.fixStartTime = 0;
			obj.fixLength = 0;
			obj.salutation(sprintf('Fixation Time now: %g',obj.fixLength),'resetFixation');
		end
				
		% ===================================================================
		%> @brief 
		%>
		% ===================================================================
		function initialise(obj,sM)
			if exist('sM','var')
				obj.screen=sM;
			else
				warning('Cannot initialise without a PTB screen')
				return
			end
			
			[result,dummy] = EyelinkInit(obj.isDummy,1);
			
			obj.isConnected = logical(result);
			obj.isDummy = logical(dummy);
			if obj.screen.isOpen == true
				obj.defaults = EyelinkInitDefaults(obj.screen.win);
			end
			[~, obj.version] = Eyelink('GetTrackerVersion');
			obj.salutation(['Running on a ' obj.version]);
			Eyelink('Command', 'link_sample_data = LEFT,RIGHT,GAZE,AREA');
			
			% open file to record data to
			if obj.isConnected == true && obj.recordData == true
				Eyelink('Openfile', 'demo.edf');
				obj.isRecording = true;
			end
			
		end
		
		% ===================================================================
		%> @brief 
		%>
		% ===================================================================
		function setup(obj)
			if obj.isConnected
				% Calibrate the eye tracker
				trackerSetup(obj);
				%driftCorrection(obj);
				checkEye(obj);
				
			end
		end
		
		% ===================================================================
		%> @brief 
		%>
		% ===================================================================
		function trackerSetup(obj)
			if obj.isConnected
				% do a final check of calibration using driftcorrection
				EyelinkDoTrackerSetup(obj.defaults);
			end
		end
		% ===================================================================
		%> @brief 
		%>
		% ===================================================================
		function driftCorrection(obj)
			if obj.isConnected
				% do a final check of calibration using driftcorrection
				EyelinkDoDriftCorrection(obj.defaults);
			end
		end
		
		% ===================================================================
		%> @brief 
		%>
		% ===================================================================
		function error = checkRecording(obj)
			if obj.isConnected
				error=Eyelink('CheckRecording');
			else
				error = -1;
			end
		end
		
		% ===================================================================
		%> @brief 
		%>
		% ===================================================================
		function eyeUsed = checkEye(obj)
			if obj.isConnected
				obj.eyeUsed = Eyelink('EyeAvailable'); % get eye that's tracked
				if obj.eyeUsed == obj.defaults.BINOCULAR; % if both eyes are tracked
					obj.eyeUsed = obj.defaults.LEFT_EYE; % use left eye
				end
				eyeUsed = obj.eyeUsed;
			else
				obj.eyeUsed = -1;
				eyeUsed = obj.eyeUsed;
			end
		end
		
		% ===================================================================
		%> @brief 
		%>
		% ===================================================================
		function close(obj)
			try
				if obj.isRecording == true
					Eyelink('StopRecording');
					obj.isRecording = false;
					Eyelink('CloseFile');
					try
						obj.salutation('Close Method',sprintf('Receiving data file %s', 'demo.edf'));
						status=Eyelink('ReceiveFile');
						if status > 0
							obj.salutation('Close Method',sprintf('ReceiveFile status %d', status));
						end
						if 2==exist('demo.edf', 'file')
							obj.salutation('Close Method',sprintf('Data file ''%s'' can be found in ''%s''', 'demo.edf', pwd));
						end
					catch ME
						obj.salutation('Close Method',sprintf('Problem receiving data file ''%s''', 'demo.edf'));
						disp(ME.message);
					end
				end
				Eyelink('Shutdown');
			catch ME
				obj.salutation('Close Method','Couldn''t stop recording, forcing shutdown...',true)
				obj.isRecording = false;
				Eyelink('Shutdown');
				obj.error = ME;
				obj.salutation(ME.message);
			end
			obj.isConnected = false;
			obj.isDummy = false;
			obj.isRecording = false;
			obj.eyeUsed = -1;
			obj.screen = [];
		end
		
		% ===================================================================
		%> @brief 
		%>
		% ===================================================================
		function evt = getSample(obj)
			obj.currentEvent = [];
			if obj.isConnected && Eyelink('NewFloatSampleAvailable') > 0
				obj.currentEvent = Eyelink('NewestFloatSample');% get the sample in the form of an event structure
				if ~isempty(obj.currentEvent)
					obj.x = obj.currentEvent.gx(obj.eyeUsed+1); % +1 as we're accessing MATLAB array
					obj.y = obj.currentEvent.gy(obj.eyeUsed+1);
					obj.pupil = obj.currentEvent.pa(obj.eyeUsed+1);
				end
			elseif obj.isDummy
				[obj.x, obj.y] = GetMouse([]);
				obj.pupil = 1000;
				obj.currentEvent.gx = obj.x;
				obj.currentEvent.gy = obj.y;
				obj.currentEvent.pa = obj.pupil;
				obj.currentEvent.time = GetSecs*1000;
			end
			evt = obj.currentEvent;
		end
		
		% ===================================================================
		%> @brief 
		%>
		% ===================================================================
		function set.x(obj,in)
			obj.x = (in - obj.screen.xCenter) / obj.screen.ppd;
		end
		
		% ===================================================================
		%> @brief 
		%>
		% ===================================================================
		function set.y(obj,in)
			obj.y = (in - obj.screen.yCenter) / obj.screen.ppd;
		end
		
		% ===================================================================
		%> @brief 
		%>
		% ===================================================================
		function drawPosition(obj)
			if obj.isConnected && obj.screen.isOpen && ~isempty(obj.x) && ~isempty(obj.y)
				x = (obj.x * obj.screen.ppd) + obj.screen.xCenter;
				y = (obj.y * obj.screen.ppd) + obj.screen.yCenter;
				if obj.isFixated
					Screen('DrawDots', obj.screen.win, [x y], 4, [1 1 1 1], [], 1);
				else
					Screen('DrawDots', obj.screen.win, [x y], 4, [1 0.5 1 1], [], 1);
				end
				if obj.fixLength > obj.fixationTime
					Screen('DrawText', obj.screen.win, 'FIX', x, y);
				end		
			end
		end
		
		% ===================================================================
		%> @brief 
		%>
		% ===================================================================
		function startRecording(obj)
			if obj.isConnected
				Eyelink('StartRecording');
				checkEye(obj);
				Eyelink('Message', 'SYNCTIME');
			end
		end
		% ===================================================================
		%> @brief 
		%>
		% ===================================================================
		function runDemo(obj)
			stopkey=KbName('space');
			try
				s = screenManager();
				o = dotsStimulus();
				%s.windowed = [800 600];
				%s.screen = 1;
				open(s);
				setup(o,s);
				
				ListenChar(1); 
				initialise(obj,s);
				setup(obj);
			
				startRecording(obj);
				WaitSecs(0.1);
				while 1
					err = checkRecording(obj);
					if(err~=0); break; end;
						
					[~, ~, keyCode] = KbCheck;
					if keyCode(stopkey); break;	end;
					
					draw(o);
					drawGrid(s);
					drawFixationPoint(s);
					
					getSample(obj);
					
					if ~isempty(obj.currentEvent)
						x = (obj.x * obj.screen.ppd) + obj.screen.xCenter;
						y = (obj.y * obj.screen.ppd) + obj.screen.yCenter;
						txt = sprintf('Press SPACE to finish \n X = %g / %g | Y = %g / %g \n FIXATION = %g', x, obj.x, y, obj.y, obj.fixLength);
						Screen('DrawText', s.win, txt, 10, 10);
						if obj.isFixated
							Screen('DrawDots', s.win, [x y], 8, [1 1 1], [], 2);
						else
							Screen('DrawDots', s.win, [x y], 4, rand(3,1), [], 2)
						end
						if obj.fixLength > obj.fixationTime
							Screen('DrawText', s.win, 'FIX', x, y);
						end
					end
					
					Screen('DrawingFinished', s.win); 
					
					animate(o);
					
					Screen('Flip',s.win);
					
				end
				ListenChar(0);
				close(s);
				close(obj);
				
			catch ME
				ListenChar(0);
				obj.salutation('\nrunDemo ERROR!!!\n')
				Eyelink('Shutdown');
				close(s);
				sca;
				close(obj);
				obj.error = ME;
				obj.salutation(ME.message);
				rethrow(ME);
			end
			
		end
		
	end
	
end


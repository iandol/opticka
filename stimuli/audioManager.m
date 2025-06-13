classdef audioManager < optickaCore
	% AUDIOMANAGER Connects and manages audio playback, set as global aM from runExperiment.runTask()
	properties
		device				= []
		fileName char		= ''
		numChannels double	= 2
		frequency double	= 44100
		lowLatency logical	= false
		latencyLevel		= 1
		%> this allows us to be used even if no sound is attached
		silentMode logical	= false 
		%> chain snd() function to use psychportaudio?
		chainSnd			= false 
		verbose				= true
	end
	
	properties (SetAccess = private, GetAccess = public)
		aHandle
		devices
		status
		isBuffered logical	= false
		fileNames cell		= {};
		isSetup logical		= false
		isOpen logical		= false
		isSample logical	= false
	end
	
	properties (SetAccess = private, GetAccess = private)
		handles				= []
		isFiles logical		= false
		allowedProperties = {'numChannels', 'frequency', 'lowLatency', ...
			'device', 'fileName', 'silentMode', 'verbose'}
	end 
	
	%=======================================================================
	methods     %------------------PUBLIC METHODS--------------%
	%=======================================================================
	
		%==============CONSTRUCTOR============%
		function me = audioManager(varargin)
			
			args = optickaCore.addDefaults(varargin,struct('name','audio-manager'));
			me=me@optickaCore(args); %we call the superclass constructor first
			me.parseArgs(args, me.allowedProperties);
			
			isValid = checkFiles(me);
			if ~isValid
				me.salutation('constructor','Please ensure valid file/dir name');
			end
			if ischar(me.device); me.device = eval(me.device); end
			if ~isempty(me.device) 
				if me.device < 0 || isnan(me.device); me.silentMode = true; end
			end
			try
				PsychPortAudio('Close');
				InitializePsychSound(me.lowLatency);
				me.devices = PsychPortAudio('GetDevices');
				if ~isempty(me.device) && me.verbose
					try disp(me.devices(me.device-1)); end
				end
			catch
				warning('audioManager: Could not initialise audio devices!!!')
			end
			me.salutation('constructor','Audio Manager initialisation complete');
		end
		
		% ===================================================================
		%> @brief open
		%>  
		% ===================================================================
		function open(me)
			if me.silentMode || me.isOpen; return; end
			setup(me);
		end
		
		% ===================================================================
		%> @brief setup
		%>  
		% ===================================================================
		function setup(me)
			if ~isempty(me.device) && me.device < 0; me.silentMode = true; end
			if me.silentMode || me.isOpen; return; end
			isValid = checkFiles(me);
			if ~isValid
				warning('NO valid file/dir name');
			end

			InitializePsychSound(me.lowLatency);
			try PsychPortAudio('Close'); end
			me.devices = PsychPortAudio('GetDevices');

			if me.device > length(me.devices)
				fprintf('You have specified a non-existant device, trying first available device!\n');
				me.device = me.devices(1).DeviceIndex;
				fprintf('Using device %i: %s\n',me.device,me.devices(1).DeviceName);
			end
			try
				PsychPortAudio('Close');
				if isempty(me.aHandle)
					% PsychPortAudio('Open' [, deviceid][, mode][, reqlatencyclass][, freq]
					% [, channels][, buffersize][, suggestedLatency][, selectchannels]
					% [, specialFlags=0]);
					me.aHandle = PsychPortAudio('Open', me.device, 1, me.latencyLevel);
				end
				if me.chainSnd
					Snd('Open',me.aHandle); % chain Snd() to this instance
				end
				PsychPortAudio('Volume', me.aHandle, 1);
				me.status = PsychPortAudio('GetStatus', me.aHandle);
				me.frequency = me.status.SampleRate;
				me.silentMode = false;
				me.isSetup = true;
				me.isOpen = true;
			catch 
				me.reset();
				warning('--->audioManager: setup failed, going into silent mode, note you will have no sound!')
				me.silentMode = true;
			end
		end
		
		% ===================================================================
		%> @brief setup
		%>  
		% ===================================================================
		function loadSamples(me)
			if me.silentMode; return; end
			if me.isFiles
				%TODO
			else
				[audiodata, ~] = psychwavread(me.fileName);
			end
			PsychPortAudio('FillBuffer', me.aHandle, audiodata');
			me.isSample = true;
		end

		% ===================================================================
		%> @brief  
		%>
		% ===================================================================
		function play(me, when)
			if me.silentMode; return; end
			if ~exist('when','var'); when = []; end
			if ~me.isSetup; setup(me);end
			if ~me.isSample; loadSamples(me);end
			if me.isSetup && me.isSample && me.isValid
				PsychPortAudio('Start', me.aHandle, [], when);
			end
		end
		
		% ===================================================================
		%> @brief  
		%>
		% ===================================================================
		function waitUntilStopped(me)
			if me.silentMode; return; end
			if me.isSetup
				PsychPortAudio('Stop', me.aHandle, 1, 1);
			end
		end
		
		% ===================================================================
		%> @brief 
		%>
		% ===================================================================
		function beep(me,freq,durationSec,fVolume)
			if me.silentMode
				if me.verbose;me.logOutput('beep','SilentMode Beep',true);end
				return; 
			end
			if ~me.isSetup; setup(me);end

			if ~exist('freq', 'var');freq = 1000;end
			if isnumeric(freq) && length(freq) == 3; fVolume = freq(3); durationSec=freq(2); freq = freq(1); end
			if ~exist('durationSec', 'var');durationSec = 0.15;	end
			if ~exist('fVolume', 'var'); fVolume = 0.5;
			else
				% Clamp if necessary
				if (fVolume > 1.0)
					fVolume = 1.0;
				elseif (fVolume < 0)
					fVolume = 0;
				end
			end
			if ischar(freq)
				if strcmpi(freq, 'high'); freq = 1000;
				elseif strcmpi(freq, 'med'); freq = 500;
				elseif strcmpi(freq, 'medium'); freq = 500;
				elseif strcmpi(freq, 'low'); freq = 300;
				end
			end
			nSample = me.frequency*durationSec;
			soundVec = sin(2*pi*freq*(1:nSample)/me.frequency);
			soundVec = [soundVec;soundVec];

			% Scale down the volume
			soundVec = soundVec * fVolume;
			PsychPortAudio('FillBuffer', me.aHandle, soundVec);
			PsychPortAudio('Start', me.aHandle);
			if me.verbose; me.logOutput('beep','Beep'); end
		end

		% ===================================================================
		%> @brief  
		%>
		% ===================================================================
		function run(me)
			setup(me)
			play(me);
			waitUntilStopped(me);
			reset(me);
		end

		% ===================================================================
		%> @brief Reset 
		%>
		% ===================================================================
		function reset(me)
			try 
				if ~isempty(me.aHandle)
					PsychPortAudio('Stop', me.aHandle, 0, 1); 
					try PsychPortAudio('DeleteBuffer'); end %#ok<*TRYNC> 
					PsychPortAudio('Close',me.aHandle); 
				else
					try PsychPortAudio('DeleteBuffer'); end %#ok<*TRYNC> 
					PsychPortAudio('Close');
				end
				if isnan(me.device); me.device = []; end
				me.aHandle = [];
				me.status = [];
				me.frequency = [];
				me.isSetup = false; me.isOpen = false; me.isSample = false;
				me.silentMode = false;
			catch ME
				try PsychPortAudio('Close'); end
				me.aHandle = [];
				me.status = [];
				me.frequency = [];
				me.isSetup = false; me.isOpen = false; me.isSample = false;
				warning('audioManager:reset','%s',ME.message);
			end
			try InitializePsychSound(me.lowLatency); end
		end

		% ===================================================================
		%> @brief Close 
		%>
		% ===================================================================
		function close(me)
			reset(me);
		end
		
		% ===================================================================
		%> @brief Close 
		%>
		% ===================================================================
		function delete(me)			
			reset(me);
		end
		
	end %---END PUBLIC METHODS---%
	
	%=======================================================================
	methods ( Access = protected ) %-------PROTECTED METHODS-----%
	%=======================================================================
	
		% ===================================================================
		%> @brief findFiles
		%>  
		% ===================================================================
		function isValid = checkFiles(me)	
			isValid = false;
			if isempty(me.fileName) || ~exist(me.fileName,'file')
				p = mfilename('fullpath');
				p = fileparts(p);
				%me.fileName = [p filesep 'Coo2.wav'];
				%me.fileNames{1} = me.fileName;
			elseif exist(me.fileName,'dir') == 7
				findFiles(me);
			end
			if exist(me.fileName,'file') || ~isempty(me.fileNames)
				isValid = true;
			end			
		end

		% ===================================================================
		%> @brief findFiles
		%>  
		% ===================================================================
		function findFiles(me)	
			if exist(me.fileName,'dir') == 7
				d = dir(me.fileName);
				n = 0;
				for i = 1: length(d)
					if d(i).isdir;continue;end
					[~,f,e]=fileparts(d(i).name);
					if regexpi(e,'wav')
						n = n + 1;
						me.fileNames{n} = [me.fileName filesep f e];
					end
				end
			end
			if ~isempty(me.fileNames); me.isFiles = true; end
		end
		
	end %---END PROTECTED METHODS---%
	
	%=======================================================================
	methods ( Access = private ) %-------PRIVATE METHODS-----%
	%=======================================================================
		
	end %---END PRIVATE METHODS---%
end
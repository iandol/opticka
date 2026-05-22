classdef audioManager < optickaCore
	% AUDIOMANAGER Connects and manages audio playback, set as global aM from runExperiment.runTask()
	properties
		%> device ID as returned from PsychAudio
		device				= []
		fileName char		= ''
		numChannels double	= 2
		frequency double	= 44100
		lowLatency logical	= false
		latencyLevel		= 1
		%> default volume
		volumeLevel double	= 1
		%> for beeps add a linear ramp to reduce clicks, in seconds
		rampDuration double	= 0.0025
		%> this allows us to be used even if no sound is attached
		silentMode logical	= false 
		%> chain snd() function to use psychportaudio?
		chainSnd			= false 
		verbose				= false
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
		beepHandle			= NaN
		sampleHandle		= NaN
		handles				= []
		isFiles logical		= false
		%> cache generated beep vectors by sample rate, frequency and duration
		beepCache dictionary
		allowedProperties = {'numChannels', 'frequency', 'lowLatency', ...
			'device', 'volumeLevel', 'fileName', 'silentMode', 'verbose'}
	end 
	
	%=======================================================================
	methods     %------------------PUBLIC METHODS--------------%
	%=======================================================================
	
		%==============CONSTRUCTOR============%
		function me = audioManager(varargin)
			args = optickaCore.addDefaults(varargin,struct('name','audio-manager'));
			me=me@optickaCore(args); %we call the superclass constructor first
			me.parseArgs(args, me.allowedProperties);
			me.beepCache = configureDictionary("string","cell");
			
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
				if ~isempty(me.device) && me.verbose
					try disp(me.devices(getDevice(me))); end
				else
					me.devices = PsychPortAudio('GetDevices');
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
				%warning('NO valid file/dir name');
			end

			InitializePsychSound(me.lowLatency);
			try PsychPortAudio('Close'); end
			idx = getDeviceIndex(me);
			
			if ~isempty(idx) && (idx < 1 || idx > length(me.devices))
				fprintf('You have specified a non-existant device, trying first available device!\n');
				me.device = [];
				fprintf('Using default device %i\n',me.device);
			else
				fprintf('Using selected device %i with DeviceIndex = %i:\n',idx, me.device);
				disp(me.devices(idx));
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
				PsychPortAudio('Volume', me.aHandle, me.volumeLevel);
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
		%> @brief
		%>  
		% ===================================================================
		function volume(me, value)
			if me.silentMode; return; end
			if ~exist('value','var'); value = me.volumeLevel; end
			% Clamp if necessary
			if (value > 1.0)
				value = 1.0;
			elseif (value < 0)
				value = 0;
			end
			me.volumeLevel = value;
			PsychPortAudio('Volume', me.aHandle, value);
		end
		
		% ===================================================================
		%> @brief
		%>  
		% ===================================================================
		function loadSamples(me)
			if me.silentMode; return; end
			if me.isFiles
				%TODO
			else
				[audiodata, ~] = psychwavread(me.fileName);
			end

			me.sampleHandle = PsychPortAudio('CreateBuffer', me.aHandle, audiodata');
			PsychPortAudio('FillBuffer', me.aHandle, me.sampleHandle);
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
			if me.isSetup && me.isSample && ~isnan(me.sampleHandle) 
				PsychPortAudio('FillBuffer', me.aHandle, me.sampleHandle);
				PsychPortAudio('Start', me.aHandle, [], when);
			end
		end

		% ===================================================================
		%> @brief
		%>
		% ===================================================================
		function stop(me)
			if me.silentMode; return; end
			if me.isSetup
				PsychPortAudio('Stop', me.aHandle, 0, 1);
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
			
			soundVec = getBeepSoundVec(me, freq, durationSec);

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
				me.sampleHandle = NaN;
				me.beepHandle = NaN;
				me.beepCache = configureDictionary("string","cell");
				me.isSetup = false; me.isOpen = false; me.isSample = false;
				me.silentMode = false;
			catch ME
				try PsychPortAudio('Close'); end
				me.aHandle = [];
				me.status = [];
				me.frequency = [];
				me.isSetup = false; me.isOpen = false; me.isSample = false;
				me.sampleHandle = NaN;
				me.beepHandle = NaN;
				warning('audioManager:reset','%s',ME.message);
			end
			me.beepCache = configureDictionary("string","cell");
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

		% ===================================================================
		%> @brief showDevices
		%>
		% ===================================================================
		function showDevices(me)
			for ii=1:length(me.devices)
				disp(['===========================Index: ' num2str(ii)]);
				disp(me.devices(ii));
			end
		end

		% ===================================================================
		%> @brief demo
		%>
		% ===================================================================
		function demo(me)
			beat = 0.11;
			if me.silentMode; return; end
			if ~me.isSetup; setup(me);end
			% J.S. Bach's Prelude in C major (BWV 846)
			song = [
				% Bar 1: C major
				262, 1; 330, 1; 392, 1; 523, 1; 659, 1; 784, 1; 1047, 1; 784, 1;
				659, 1; 523, 1; 392, 1; 330, 1; 262, 1; 330, 1; 392, 1; 523, 1;
				% Bar 2: D minor
				294, 1; 349, 1; 440, 1; 587, 1; 698, 1; 880, 1; 1175, 1; 880, 1;
				698, 1; 587, 1; 440, 1; 349, 1; 294, 1; 349, 1; 440, 1; 587, 1;
				% Bar 3: G7
				392, 1; 494, 1; 587, 1; 698, 1; 784, 1; 988, 1; 1175, 1; 988, 1;
				784, 1; 698, 1; 587, 1; 494, 1; 392, 1; 494, 1; 587, 1; 698, 1;
				% Bar 4: C major
				262, 1; 330, 1; 392, 1; 523, 1; 659, 1; 784, 1; 1047, 1; 784, 1;
				659, 1; 523, 1; 392, 1; 330, 1; 262, 1; 330, 1; 392, 1; 523, 1;
				% Bar 5: C major (repeat)
				262, 1; 330, 1; 392, 1; 523, 1; 659, 1; 784, 1; 1047, 1; 784, 1;
				659, 1; 523, 1; 392, 1; 330, 1; 262, 1; 330, 1; 392, 1; 523, 1;
				% Bar 6: D minor
				294, 1; 349, 1; 440, 1; 587, 1; 698, 1; 880, 1; 1175, 1; 880, 1;
				698, 1; 587, 1; 440, 1; 349, 1; 294, 1; 349, 1; 440, 1; 587, 1;
				% Bar 7: G7
				392, 1; 494, 1; 587, 1; 698, 1; 784, 1; 988, 1; 1175, 1; 988, 1;
				784, 1; 698, 1; 587, 1; 494, 1; 392, 1; 494, 1; 587, 1; 698, 1;
				% Bar 8: C major
				262, 1; 330, 1; 392, 1; 523, 1; 659, 1; 784, 1; 1047, 1; 784, 1;
				659, 1; 523, 1; 392, 1; 330, 1; 262, 1; 330, 2; 392, 2; 523, 4;
				];
			for i = size(song, 1)
				freq = song(i, 1);
				dur  = song(i, 2) * beat;
				if freq > 0
					me.beep(freq,dur);
				end
				WaitSecs(dur);
			end

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

		% ===================================================================
		%> @brief getDeviceIndex
		%>  
		% ===================================================================
		function idx = getDeviceIndex(me)
			idx = [];
			me.devices = PsychPortAudio('GetDevices');
			idxs = [me.devices.DeviceIndex];
			if isempty(me.device) || me.device < min(idxs) || me.device > max(idxs)
				return; 
			end
			idx = find(idxs == me.device);
			if isempty(idxs); warning('Couldn''t find device ID %i...', me.device);end
		end
		
	end %---END PROTECTED METHODS---%
	
	%=======================================================================
	methods ( Access = private ) %-------PRIVATE METHODS-----%
	%=======================================================================

		% ===================================================================
		%> @brief Return a cached beep vector or build it if needed.
		%>
		% ===================================================================
		function soundVec = getBeepSoundVec(me, freq, durationSec)
			cacheKey = string(sprintf('%.12g_%.12g_%.12g', me.frequency, freq, durationSec));
			if ~isKey(me.beepCache, cacheKey)
				nSample = max(1, round(me.frequency * durationSec));
				soundVec = sin(2*pi*freq*(1:nSample)/me.frequency);
				% Apply a short linear attack/release envelope to reduce clicks.
				if me.rampDuration > 0
					rampSamples = max(1, round(me.rampDuration * me.frequency));
					rampSamples = min(rampSamples, floor(nSample / 2));
				else
					rampSamples = 0;
				end
				if rampSamples > 0
					env = ones(1, nSample);
					ramp = linspace(0, 1, rampSamples);
					env(1:rampSamples) = ramp;
					env(end-rampSamples+1:end) = fliplr(ramp);
					soundVec = soundVec .* env;
				end
				soundVec = [soundVec;soundVec];
				insert(me.beepCache, cacheKey, {soundVec});
			else
				soundVec = me.beepCache(cacheKey);
				soundVec = soundVec{1}; % unpack from cell
			end
		end

	end %---END PRIVATE METHODS---%
end

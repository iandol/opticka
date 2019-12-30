classdef audioManager < optickaCore
	%ARDUINOMANAGER Connects and manages arduino communication, uses matlab
	%hardware package
	properties
		device 			= []
		fileName char		= ''
		numChannels double	= 2
		lowLatency logical	= true
		silentMode logical	= false %this allows us to be called even if no arduino is attached
		verbose				= true
	end
	properties (SetAccess = private, GetAccess = public)
		isBuffered logical = false
		aHandle
		status
		frequency
		%> list of names if multipleImages > 0
		fileNames = {};
	end
	properties (SetAccess = private, GetAccess = private)
		handles = []
		isFiles logical = false
		isSetup logical = false
		screen screenManager
		allowedProperties char ='device|fileName|silentMode|verbose'
	end
	
	%=======================================================================
	methods     %------------------PUBLIC METHODS--------------%
	%=======================================================================
	
		%==============CONSTRUCTOR============%
		function me = audioManager(varargin)
			if nargin == 0; varargin.name = ''; end
			me=me@optickaCore(varargin); %superclass constructor
			if nargin>0
				me.parseArgs(varargin,me.allowedProperties);
			end
			isValid = checkFiles(me);
			if ~isValid
				me.salutation('constructor','Please ensure valid file/dir name');
			end
			me.salutation('constructor','Audio Manager initialisation complete');
		end
		
		% ===================================================================
		%> @brief setup
		%>  
		% ===================================================================
		function setup(me)
			isValid = checkFiles(me);
			if ~isValid
				warning('NO valid file/dir name');
			end
			InitializePsychSound(me.lowLatency);
			suggestedLatency = [];
			me.aHandle = PsychPortAudio('Open', me.device);
			me.status = PsychPortAudio('GetStatus', me.aHandle);
			me.frequency = me.status.SampleRate;
			if me.isFiles
				
			else
				[audiodata, infreq] = psychwavread(me.fileName);
			end
			
			PsychPortAudio('FillBuffer', me.aHandle, audiodata');
			me.isSetup = true;
			
		end
		
		function play(me,when)
			if ~me.isSetup
				setup(me);
			end
			if me.isSetup
				PsychPortAudio('Start', me.aHandle);
			end
		end
		
		function run(me)
			tic;setup(me);toc
			play(me);
			tic;reset(me);toc
			
		end
		
		% ===================================================================
		%> @brief Reset 
		%>
		% ===================================================================
		function reset(me)
			try 
				if ~isempty(me.aHandle)
					PsychPortAudio('Stop', me.aHandle, 0, 1); 
				end
				PsychPortAudio('DeleteBuffer');
				PsychPortAudio('Close');
				me.aHandle = [];
				me.status = [];
				me.freq = [];
				me.isSetup = false;
			end
		end
		
		% ===================================================================
		%> @brief Close 
		%>
		% ===================================================================
		function close(me)
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
				me.fileName = [p filesep 'Coo.wav'];
				me.fileNames{1} = me.fileName;
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
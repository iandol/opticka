classdef arduinoManager < optickaCore
	%ARDUINOMANAGER Connects and manages arduino communication, uses matlab
	%hardware package
	properties
		port			= ''
		board			= ''
		silentMode		= false %this allows us to be called even if no arduino is attached
		verbose			= true
		mode			= 'original'
		availablePins = {2,3,4,5,6,7,8,9,10,11,12,13}; %UNO board
	end
	properties (SetAccess = private, GetAccess = public)
		device = []
		deviceID = ''
	end
	properties (SetAccess = private, GetAccess = private)
		allowedProperties='mode|port|silentMode|verbose'
	end
	methods%------------------PUBLIC METHODS--------------%
		
		%==============CONSTRUCTOR============%
		function me = arduinoManager(varargin)
			if nargin>0
				me.parseArgs(varargin,me.allowedProperties);
			end
			if isempty(me.port) && IsWin
				me.port = 'COM4';
            elseif isempty(me.port)
				me.port = '/dev/ttyACM1';
			end
			switch me.mode
				case 'original'
					if ~exist('arduinoLegacy','file')
						me.comment = 'Cannot find arduinoLegacy, check opticka path!';
						warning(me.comment)
						me.silentMode = true;
					end
				otherwise
					if ~exist('arduino','file')
						me.comment = 'You need to Install Arduino Support files!';
						warning(me.comment)
						me.silentMode = true;
					end
			end
		end
		
		%===============OPEN DEVICE================%
		function open(me)
            close(me);
			if me.silentMode==false && isempty(me.device)
				try
					switch me.mode
						case 'original'
							if ~isempty(me.port)
								me.device = arduinoLegacy(me.port);
							else
								error('Please specify the port to use!')
							end
							me.board = 'Generic';
							me.deviceID = me.port;
							me.availablePins = {2,3,4,5,6,7,8,9,10,11,12,13}; %UNO board
							for i = me.availablePins{1} : me.availablePins{end}
								me.device.pinMode(i,'output');
								me.device.digitalWrite(i,0);
							end
						otherwise
							if ~isempty(me.port)
								me.device = arduino(me.port);
							else
								me.device = arduino;
							end
							me.port = me.device.Port;
							me.board = me.device.Board;
							me.deviceID = me.device.Port;
							me.availablePins = me.device.AvailablePins;
							for i = 2:13
								configurePin(me.device,['D' num2str(i)],'unset')
								writeDigitalPin(me.device,['D' num2str(i)],0);
							end
					end
					me.silentMode = false;
				catch ME
					me.silentMode = true;
					fprintf('\n\nCouldn''t open Arduino, try a valid name?')
					getReport(ME)
				end
			end
		end
		
		%===============SEND TTL (legacy)================%
		function sendTTL(me, line, time)
			timedTTL(me, line, time)
		end
		
		%===============TIMED TTL================%
		function timedTTL(me, line, time)
			if me.silentMode==false
				if ~exist('line','var') || isempty(line); line = 2; end
				if ~exist('time','var') || isempty(time); time = 500; end
				if ~strcmp(me.mode,'original')
					time = time - 30; %there is an arduino 30ms delay
				end
				if time < 0; time = 0; warning('Arduino TTLs >= ~30ms!');end
				switch me.mode
					case 'original'
						digitalWrite(me.device, line, 1);
						WaitSecs(time/1e3);
						digitalWrite(me.device, line, 0);
					otherwise
						writeDigitalPin(me.device,['D' num2str(line)],1);
						WaitSecs(time/1e3);
						writeDigitalPin(me.device,['D' num2str(line)],0);
				end
				
				if me.verbose;fprintf('===>>> REWARD GIVEN: pin %i for %i ms\n',line,time);end
			else
				if me.verbose;fprintf('===>>> REWARD GIVEN: Silent Mode\n');end
			end
		end
		
		%===============TEST TTL================%
		function test(me,line)
			if me.silentMode==false && ~isempty(me.device)
				if ~exist('line','var') || isempty(line); line = 2; end
				switch me.mode
					case 'original'
						digitalWrite(me.device, line, 0);
						for ii = 1:20
							digitalWrite(me.device, line, mod(ii,2));
						end
					otherwise
						writeDigitalPin(me.device,['D' num2str(line)],0);
						for ii = 1:20
							writeDigitalPin(me.device,['D' num2str(line)],mod(ii,2));
						end
				end
			end
		end
		
		%===============CLOSE PORT================%
		function close(me)
			me.device = [];
			me.deviceID = '';
			me.availablePins = '';
			me.silentMode = false;
		end
		
	end
	
	methods ( Access = private ) %----------PRIVATE METHODS---------%
		%===========Delete Method==========%
		function delete(me)
			fprintf('arduinoManager Delete method will automagically close connection if open...\n');
			me.close;
		end
		
	end
	
end